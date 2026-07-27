import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/utils/crypto_utils.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

abstract class StreamMediaExplorerProvider {
  Future<void> initialize({bool validateCredentials = true});
  Future<Dio> getDio(
    String url, {
    UserInfo? userInfo,
    bool validateCredentials = true,
  });
  Future<UserInfo> login(Dio dio, String username, String password);
  Future<List<CollectionItem>> getUserViews();
  Future<List<ResumeItem>> getResumeItems({String? parentId, int limit = 12});
  Future<List<MediaItem>> getItems(String parentId, {required Filter filter});
  Future<MediaDetail> getMediaDetail(String itemId);
  Future<List<EpisodeInfo>> getEpisodes(String itemId, MediaType type);
  Future<void> setFavorite(String itemId, bool isFavorite);
  Future<void> setPlayed(String itemId, bool isPlayed);
  Future<PlaybackTarget> getPlaybackTarget(String itemId);
  Map<String, String> get headers;
  String getImageUrl(String itemId, {String tag = 'Primary'});
  String getStreamUrl(String itemId);
  Future<bool> downloadVideo(
    String itemId,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });
  Future<void> reportPlaybackStart(String itemId, int position);
  Future<void> reportPlaybackProgress(
    String itemId,
    int position,
    bool isPaused,
  );
  Future<void> reportPlaybackStopped(String itemId, int position);
  void dispose();
}

Future<StreamMediaExplorerProvider?> createStreamMediaExplorerProvider(
  Storage storage, {
  bool validateCredentials = true,
}) async {
  final StreamMediaExplorerProvider? provider;
  switch (storage.storageType) {
    case StorageType.jellyfin:
      provider = JellyfinStreamMediaExplorerProvider(storage);
      break;
    case StorageType.emby:
      provider = EmbyStreamMediaExplorerProvider(storage);
      break;
    default:
      return null;
  }
  await provider.initialize(validateCredentials: validateCredentials);
  return provider;
}

class Filter {
  String searchTerm = '';
  String years = '';
  String seriesStatus = '';
  String sortBy = 'SortName';
  // true: 升序，false: 降序
  bool sortOrder = true;
  bool isFavorite = false;

  Filter();

  bool isFiltered() {
    return searchTerm.isNotEmpty ||
        years.isNotEmpty ||
        seriesStatus.isNotEmpty ||
        sortBy != 'SortName' ||
        sortOrder != true ||
        isFavorite != false;
  }
}

class StreamMediaExplorerService {
  final Signal<StreamMediaExplorerProvider?> provider = signal(null);
  final Signal<String> libraryId = signal('');
  final AsyncSignal<List<CollectionItem>> libraries = asyncSignal(
    AsyncLoading(),
  );
  Storage? storage;
  void Function()? _reportEffect;
  String? _playbackSeasonId;
  final Map<String, AsyncSignal<List<EpisodeInfo>>> episodeMap = {};
  final _logger = Logger('StreamMediaExplorerService');
  final Signal<Filter> filter = signal(Filter());
  final AsyncSignal<List<MediaItem>> items = asyncSignal(AsyncLoading());
  final historyService = GetIt.I.get<HistoryService>();
  final globalService = GetIt.I.get<GlobalService>();
  bool get useRemoteHistory => storage?.useRemoteHistory == true;
  static void register() {
    final service = StreamMediaExplorerService();
    effect(service._syncLibraryId);
    effect(service.getData);
    GetIt.I.registerSingleton<StreamMediaExplorerService>(service);
  }

  Future<void> getData() async {
    items.value = AsyncLoading();
    if (provider.value == null) {
      items.value = AsyncData([]);
      return;
    }
    try {
      final list = await provider.value!.getItems(
        libraryId.value,
        filter: filter.value,
      );
      items.value = AsyncData(list);
    } catch (e, t) {
      _logger.error('items', '加载媒体列表失败', error: e, stackTrace: t);
      items.value = AsyncError(e, t);
    }
  }

  void setProvider(StreamMediaExplorerProvider newProvider, Storage storage) {
    batch(() {
      filter.value = Filter();
      libraries.value = AsyncLoading();
      items.value = AsyncLoading();
      _playbackSeasonId = null;
      episodeMap.clear();
      this.storage = storage;
      provider.value = newProvider;
      libraryId.value = storage.mediaLibraryId!;
    });
    _logger.info('setProvider', '设置新的媒体库提供者');
  }

  Future<void> loadLibraries() async {
    if (provider.value == null) {
      libraries.value = AsyncData([]);
      return;
    }
    libraries.value = AsyncLoading();
    try {
      final bool useRemoteHistory = storage?.useRemoteHistory ?? false;
      final providerViews = await provider.value!.getUserViews();
      final list = useRemoteHistory
          ? [CollectionItem(id: '', name: '收藏'), ...providerViews]
          : providerViews;
      if (list.isEmpty) {
        final error = AppException('当前账号下没有可用媒体库', null);
        libraries.value = AsyncError(error, StackTrace.current);
        throw error;
      }
      libraries.value = AsyncData(list);
      final currentLibraryId = storage?.mediaLibraryId;
      final selectedLibraryId = list.any((item) => item.id == currentLibraryId)
          ? currentLibraryId!
          : list.first.id;
      libraryId.value = selectedLibraryId;
    } catch (e, t) {
      _logger.error('libraries', '加载媒体库列表失败', error: e, stackTrace: t);
      libraries.value = AsyncError(e, t);
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (provider.value == null) {
      items.value = AsyncData([]);
      return;
    }
    await getData();
  }

  Future<List<ResumeItem>> fetchResumeItems({
    String? parentId,
    int limit = 12,
  }) async {
    if (provider.value == null || storage?.useRemoteHistory != true) {
      return [];
    }
    return provider.value!.getResumeItems(parentId: parentId, limit: limit);
  }

  Future<VideoInfo> item2VideoInfo(String itemId) async {
    if (provider.value == null) {
      throw AppException('播放失败', '媒体服务未初始化');
    }
    final target = await provider.value!.getPlaybackTarget(itemId);
    final episodes = await getEpisodes(target.seasonId, target.type);
    if (episodes.isEmpty) {
      throw AppException('播放失败', '播放列表为空');
    }
    final initialIndex = episodes.indexWhere(
      (episode) => episode.id == target.episodeId,
    );
    selectPlaybackSeason(target.seasonId);
    return _prepareVideoInfo(initialIndex >= 0 ? initialIndex : 0);
  }

  Future<VideoInfo> season2VideoInfo(String seasonId, int index) async {
    selectPlaybackSeason(seasonId);
    return _prepareVideoInfo(index);
  }

  Future<VideoInfo> _prepareVideoInfo(int index) async {
    final episodes = playbackEpisodes;
    final videoInfo = getVideoInfo(index);
    final history = getHistory(episodes[index]);
    if (history != null) {
      await GetIt.I.get<HistoryService>().save(history);
    }
    if (GetIt.I.get<ConfigureService>().offlineCacheFirst.value) {
      videoInfo.cached = GetIt.I.get<OfflineCacheService>().isCached(
        videoInfo.uniqueKey,
      );
    }
    return videoInfo;
  }

  Future<void> _syncLibraryId() async {
    final newId = libraryId.value;
    if (storage == null) return;
    if (storage!.mediaLibraryId == newId && newId.isEmpty) {
      return;
    }
    storage!.mediaLibraryId = newId;
    try {
      await storage!.save();
    } catch (e, t) {
      _logger.error('libraryId', '同步媒体库ID失败', error: e, stackTrace: t);
    }
  }

  List<EpisodeInfo> get playbackEpisodes {
    final seasonId = _playbackSeasonId;
    if (seasonId == null) return const [];
    return episodeMap[seasonId]?.value.value ?? const [];
  }

  void selectPlaybackSeason(String seasonId) {
    final episodes = episodeMap[seasonId]?.value.value;
    if (episodes == null) {
      throw AppException('获取播放列表失败', '当前季度尚未加载');
    }
    _playbackSeasonId = seasonId;
  }

  VideoInfo getVideoInfo(int index) {
    final episodes = playbackEpisodes;
    final episode = episodes[index];
    final playbackUrl = getPlaybackUrl(episode.id);
    return VideoInfo(
      currentVideoPath: playbackUrl,
      virtualVideoPath: episode.id,
      headers: headers,
      historiesType: HistoriesType.streamMediaStorage,
      storageKey: storage!.uniqueKey,
      name: episode.name,
      videoName: episode.fileName,
      subtitle: episode.subtitle,
      listLength: episodes.length,
      videoIndex: index,
      canSwitch: true,
    );
  }

  VideoInfo getVideoInfoFromHistory(History history) {
    final playbackUrl = getPlaybackUrl(history.url!);
    return VideoInfo(
      currentVideoPath: playbackUrl,
      virtualVideoPath: history.url!,
      headers: headers,
      historiesType: HistoriesType.streamMediaStorage,
      storageKey: storage!.uniqueKey,
      name: history.name,
      videoName: history.fileName ?? '',
      subtitle: history.subtitle,
    );
  }

  Map<String, String> get headers => provider.value!.headers;

  String getImageUrl(String itemId, {String tag = 'Primary'}) {
    return provider.value!.getImageUrl(itemId, tag: tag);
  }

  String getPlaybackUrl(String itemId) {
    return provider.value!.getStreamUrl(itemId);
  }

  Future<MediaDetail> getMediaDetail(String itemId) async {
    return provider.value!.getMediaDetail(itemId);
  }

  AsyncState<List<EpisodeInfo>> getEpisodeState(String seasonId) {
    return _getEpisodeSignal(seasonId).value;
  }

  Future<List<EpisodeInfo>> getEpisodes(
    String seasonId,
    MediaType type, {
    bool forceRefresh = false,
  }) async {
    final episodeSignal = _getEpisodeSignal(seasonId);
    final currentState = episodeSignal.value;
    if (!forceRefresh && currentState.hasValue) {
      return currentState.requireValue;
    }
    try {
      final currentProvider = provider.value;
      if (currentProvider == null) {
        throw AppException('获取集数信息失败', '媒体服务未初始化');
      }
      final episodes = await currentProvider.getEpisodes(seasonId, type);
      _getEpisodeSignal(seasonId).value = AsyncData(episodes);
      return episodes;
    } catch (e, t) {
      _getEpisodeSignal(seasonId).value = AsyncError(e, t);
      rethrow;
    }
  }

  AsyncSignal<List<EpisodeInfo>> _getEpisodeSignal(String seasonId) {
    return episodeMap.putIfAbsent(seasonId, () => asyncSignal(AsyncLoading()));
  }

  Future<void> setFavorite(String itemId, bool isFavorite) async {
    await provider.value!.setFavorite(itemId, isFavorite);
  }

  Future<void> setPlayed(String itemId, bool isPlayed) async {
    await provider.value!.setPlayed(itemId, isPlayed);
  }

  History? getHistory(EpisodeInfo episode) {
    final localHistory = historyService.getHistoryByPath(episode.id);
    if (storage!.useRemoteHistory != true) return localHistory;
    final userData = episode.userData;
    final lastPlayedDate = userData?.lastPlayedDate;
    if (userData == null || lastPlayedDate == null) return localHistory;
    final updateTime = lastPlayedDate.millisecondsSinceEpoch;
    if (localHistory != null && localHistory.updateTime >= updateTime) {
      return localHistory;
    }
    return History(
      uniqueKey: CryptoUtils.generateVideoUniqueKey(episode.id),
      duration: ((episode.runTimeTicks ?? 0) / 10000).round(),
      position: ((userData.playbackPositionTicks ?? 0) / 10000).round(),
      type: HistoriesType.streamMediaStorage,
      updateTime: updateTime,
      name: episode.name,
      url: episode.id,
      storageKey: storage!.uniqueKey,
      subtitle: '${episode.seriesName} ${episode.indexNumber}',
      fileName: episode.fileName,
    );
  }

  Future<void> removeHistory(String itemId) async {
    final history = historyService.getHistoryByPath(itemId);
    if (history != null) historyService.delete(history: history);
    setPlayed(itemId, false);
  }

  Future<void> startPlayback(String itemId) async {
    if (provider.value == null) return;
    if (storage?.useRemoteHistory != true) return;
    try {
      await provider.value!.reportPlaybackStart(
        itemId,
        globalService.position.value,
      );
      _reportEffect = effect(() {
        if (provider.value == null) return;
        provider.value!.reportPlaybackProgress(
          itemId,
          globalService.position.value,
          !globalService.isPlaying.value,
        );
      });
    } catch (e, t) {
      _logger.error('startPlayback', '上报播放开始失败', error: e, stackTrace: t);
    }
  }

  Future<void> stopPlayback(String itemId) async {
    if (provider.value == null) return;
    if (storage?.useRemoteHistory != true) return;
    final positionTicks = globalService.position.value;
    try {
      _reportEffect?.call();
      _reportEffect = null;
      await provider.value!.reportPlaybackStopped(itemId, positionTicks);
    } catch (e, t) {
      _logger.error('stopPlayback', '上报播放停止失败', error: e, stackTrace: t);
    }
  }
}

class EmbyStreamMediaExplorerProvider implements StreamMediaExplorerProvider {
  final Storage storage;
  late UserInfo _userInfo;
  late Dio dio;
  final Map<String, String> _playSessionIds = {};
  late final Logger _logger = Logger(loggerName);

  EmbyStreamMediaExplorerProvider(this.storage) {
    _userInfo = UserInfo(
      userId: storage.userId ?? '',
      token: storage.token ?? '',
    );
  }

  String get authPrefix => 'Emby';
  String get authHeaderKey => 'Authorization';
  String get loggerName => 'EmbyStreamMediaExplorerProvider';
  bool get _useRemoteHistory => storage.useRemoteHistory == true;
  String get url => storage.url;

  Future<T> _request<T>(
    String method,
    String action,
    Future<T> Function() callback,
  ) async {
    try {
      return await callback();
    } on DioException catch (e, t) {
      _logger.dio(method, e, t, action: action);
    } catch (e, t) {
      _logger.error(method, '$action失败', error: e, stackTrace: t);
      throw AppException('$action失败', e);
    }
  }

  String getItemsPath([String? itemId]) {
    return itemId != null
        ? '/Users/${_userInfo.userId}/Items/$itemId'
        : '/Users/${_userInfo.userId}/Items';
  }

  String _buildAuthHeader({UserInfo? userInfo}) {
    final globalService = GetIt.I.get<GlobalService>();
    String auth =
        '$authPrefix Client="fldanplay", Device="${globalService.device}", DeviceId="${globalService.deviceId}", Version="${globalService.version}"';
    final currentUserInfo = userInfo ?? _userInfo;
    if (currentUserInfo.token.isNotEmpty) {
      auth += ', Token="${currentUserInfo.token}"';
    }
    return auth;
  }

  Future<UserInfo> _authenticate(
    Dio dio,
    String username,
    String password,
  ) async {
    final response = await dio.post(
      '/Users/AuthenticateByName',
      data: {'Username': username, 'Pw': password},
    );
    return UserInfo.fromJson(response.data);
  }

  Future<void> _loginWithSavedPassword(Dio dio) async {
    final username = storage.account?.trim() ?? '';
    final password = storage.password?.trim() ?? '';
    if (username.isEmpty || password.isEmpty) {
      throw AppException('登录信息无效，请重新编辑媒体库并登录', null);
    }
    await _request('refreshCredentials', '重新登录', () async {
      final newUserInfo = await _authenticate(dio, username, password);
      _userInfo = newUserInfo;
      storage
        ..token = newUserInfo.token
        ..userId = newUserInfo.userId;
      await storage.save();
      _logger.info('refreshCredentials', '登录凭证已刷新');
    });
  }

  Future<void> _ensureCredentials(Dio dio) async {
    final hasToken = _userInfo.token.isNotEmpty && _userInfo.userId.isNotEmpty;
    if (!hasToken) {
      await _loginWithSavedPassword(dio);
      dio.options.headers[authHeaderKey] = _buildAuthHeader();
      return;
    }
    try {
      await dio.get('/Users/${_userInfo.userId}/Views');
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) {
        rethrow;
      }
      await _loginWithSavedPassword(dio);
      dio.options.headers[authHeaderKey] = _buildAuthHeader();
    }
  }

  @override
  Future<void> initialize({bool validateCredentials = true}) async {
    dio = await getDio(
      url,
      userInfo: _userInfo,
      validateCredentials: validateCredentials,
    );
  }

  @override
  Map<String, String> get headers => {authHeaderKey: _buildAuthHeader()};

  @override
  Future<List<MediaItem>> getItems(String parentId, {required Filter filter}) {
    return _request('getItems', '获取媒体列表', () async {
      final params = <String, dynamic>{
        'parentId': parentId,
        'limit': 300,
        'recursive': true,
        'searchTerm': filter.searchTerm,
        'IsFavorite': filter.isFavorite || parentId == '' ? true : null,
        'includeItemTypes': 'Movie,Series',
        'sortBy': filter.sortBy,
        'years': filter.years,
        'sortOrder': filter.sortOrder ? 'Ascending' : 'Descending',
        'seriesStatus': filter.seriesStatus,
        'imageTypeLimit': '1',
        'enableImageTypes': 'Primary',
      };
      final response = await dio.get(getItemsPath(), queryParameters: params);
      return (response.data['Items'] as List)
          .map(
            (item) =>
                MediaItem.fromJson(item, includeUserData: _useRemoteHistory),
          )
          .toList();
    });
  }

  @override
  String getImageUrl(String itemId, {String tag = 'Primary'}) {
    return '$url/Items/$itemId/Images/$tag';
  }

  @override
  String getStreamUrl(String itemId) {
    return '$url/Videos/$itemId/stream?static=true&api_key=${_userInfo.token}';
  }

  @override
  Future<MediaDetail> getMediaDetail(String itemId) {
    return _request('getMediaDetail', '获取媒体详情', () async {
      final response = await dio.get(getItemsPath(itemId));
      final detail = MediaDetail.fromJson(
        response.data,
        includeUserData: _useRemoteHistory,
      );

      // 如果是系列，获取季度信息
      if (detail.type == MediaType.series) {
        detail.seasons = await getSeasons(itemId);
      }
      if (detail.type == MediaType.movie) {
        detail.seasons = [SeasonInfo(id: detail.id, name: detail.name)];
      }

      return detail;
    });
  }

  @override
  Future<void> setFavorite(String itemId, bool isFavorite) {
    final action = isFavorite ? '添加收藏' : '取消收藏';
    return _request('setFavorite', action, () async {
      final path = '/Users/${_userInfo.userId}/FavoriteItems/$itemId';
      if (isFavorite) {
        await dio.post(path);
      } else {
        await dio.delete(path);
      }
    });
  }

  @override
  Future<PlaybackTarget> getPlaybackTarget(String itemId) {
    return _request('getPlaybackTarget', '获取播放目标', () async {
      final response = await dio.get(getItemsPath(itemId));
      final item = response.data as Map<String, dynamic>;
      final type = item['Type'] as String?;
      if (type == 'Movie') {
        final movieId = (item['Id'] ?? itemId).toString();
        return PlaybackTarget(
          seasonId: movieId,
          episodeId: movieId,
          type: .movie,
        );
      }
      if (type == 'Episode') {
        final seasonId = item['SeasonId'] ?? item['ParentId'];
        if (seasonId == null || seasonId.toString().isEmpty) {
          throw AppException('获取播放目标失败', '找不到季度信息');
        }
        return PlaybackTarget(
          seasonId: seasonId.toString(),
          episodeId: (item['Id'] ?? itemId).toString(),
          type: .series,
        );
      }
      throw AppException('获取播放目标失败', '当前媒体不支持继续播放');
    });
  }

  @override
  Future<Dio> getDio(
    String url, {
    UserInfo? userInfo,
    bool validateCredentials = true,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: url,
        headers: {authHeaderKey: _buildAuthHeader(userInfo: userInfo)},
      ),
    );
    if (validateCredentials) {
      await _request('getDio', '校验登录凭证', () => _ensureCredentials(dio));
    }
    return dio;
  }

  @override
  Future<UserInfo> login(Dio dio, String username, String password) {
    return _request(
      'login',
      '登录',
      () => _authenticate(dio, username, password),
    );
  }

  @override
  Future<List<CollectionItem>> getUserViews() {
    return _request('getUserViews', '获取用户视图', () async {
      final response = await dio.get('/Users/${_userInfo.userId}/Views');
      return (response.data['Items'] as List)
          .map((item) => CollectionItem.fromJson(item))
          .toList();
    });
  }

  @override
  Future<List<ResumeItem>> getResumeItems({String? parentId, int limit = 12}) {
    return _request('getResumeItems', '获取继续观看', () async {
      final response = await dio.get(
        '/Users/${_userInfo.userId}/Items/Resume',
        queryParameters: {
          'Limit': limit,
          'Recursive': true,
          'Fields': 'UserData,SeriesName,ParentIndexNumber,IndexNumber',
          'MediaTypes': 'Video',
          if (parentId != null && parentId.isNotEmpty) 'ParentId': parentId,
        },
      );
      final items = response.data['Items'] as List<dynamic>? ?? [];
      return items
          .map((item) => _parseResumeItem(item as Map<String, dynamic>))
          .toList();
    });
  }

  ResumeItem _parseResumeItem(Map<String, dynamic> json) {
    final userData = json['UserData'] as Map<String, dynamic>?;
    final imageTags = json['ImageTags'] as Map<String, dynamic>?;
    final hasPrimary = (imageTags?['Primary'] as String?)?.isNotEmpty == true;
    final hasSeriesPrimary =
        (json['SeriesPrimaryImageTag'] as String?)?.isNotEmpty == true;
    final seriesId = json['SeriesId'] as String?;
    return ResumeItem(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      type: MediaType.values.firstWhere(
        (e) => e.name == json['Type'],
        orElse: () => MediaType.none,
      ),
      seriesName: json['SeriesName'],
      parentIndexNumber: json['ParentIndexNumber'],
      indexNumber: json['IndexNumber'],
      playbackPositionTicks: userData?['PlaybackPositionTicks'] ?? 0,
      runTimeTicks: json['RunTimeTicks'],
      lastPlayedDate: userData?['LastPlayedDate'] != null
          ? DateTime.parse(userData!['LastPlayedDate']).toUtc()
          : null,
      seriesId: json['SeriesId'],
      mainImage: hasPrimary ? (json['PrimaryImageItemId'] ?? json['Id']) : null,
      fallbackImage: hasSeriesPrimary && seriesId != null && seriesId.isNotEmpty
          ? seriesId
          : null,
    );
  }

  Future<List<SeasonInfo>> getSeasons(String seriesId) {
    return _request('getSeasons', '获取季度信息', () async {
      final response = await dio.get(
        getItemsPath(),
        queryParameters: {'parentId': seriesId},
      );

      final seasons = (response.data['Items'] as List)
          .map((item) => SeasonInfo.fromJson(item))
          .toList();
      seasons.sort(
        (a, b) => (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0),
      );
      return seasons;
    });
  }

  @override
  Future<List<EpisodeInfo>> getEpisodes(String itemId, MediaType type) {
    return _request('getEpisodes', '获取集数信息', () async {
      if (type == .movie) {
        final response = await dio.get(getItemsPath(itemId));
        final item = response.data as Map<String, dynamic>;
        final itemInfo = ItemInfo.fromJson(
          item,
          includeUserData: _useRemoteHistory,
        );
        return [
          EpisodeInfo(
            id: item['Id'] ?? itemId,
            name: item['Name'] ?? '',
            indexNumber: item['IndexNumber'],
            seriesName: item['Name'] ?? '',
            overview: item['Overview'],
            runTimeTicks: item['RunTimeTicks'],
            userData: itemInfo.userData,
            fileName: itemInfo.fileName,
          ),
        ];
      } else if (type == .series) {
        final response = await dio.get(
          getItemsPath(),
          queryParameters: {'parentId': itemId},
        );
        List<EpisodeInfo> episodes = [];
        for (var item in response.data['Items']) {
          final episode = EpisodeInfo.fromJson(item);
          final itemInfo = await getItemInfo(episode.id);
          episode.fileName = itemInfo.fileName;
          episode.userData = itemInfo.userData;
          episodes.add(episode);
        }
        episodes.sort(
          (a, b) => (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0),
        );
        return episodes;
      }
      throw AppException('获取播放目标失败', '当前媒体不支持继续播放');
    });
  }

  Future<ItemInfo> getItemInfo(String itemId) {
    return _request('getItemInfo', '获取项目信息', () async {
      final response = await dio.get(getItemsPath(itemId));
      return ItemInfo.fromJson(
        response.data,
        includeUserData: _useRemoteHistory,
      );
    });
  }

  @override
  Future<bool> downloadVideo(
    String itemId,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final streamUrl = getStreamUrl(itemId);
      await dio.download(
        streamUrl,
        localPath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
      _logger.info('downloadVideo', '下载完成: $itemId -> $localPath');
      return true;
    } catch (e, t) {
      if (e is DioException && e.type == DioExceptionType.cancel) return false;
      _logger.error('downloadVideo', '下载失败', error: e, stackTrace: t);
      return false;
    }
  }

  Map<String, dynamic> _buildPlaybackBody(
    String itemId, {
    required String playSessionId,
    required int positionTicks,
    required bool isPaused,
  }) {
    return {
      'ItemId': itemId,
      'CanSeek': true,
      'IsPaused': isPaused,
      'IsMuted': false,
      'PlayMethod': 'DirectPlay',
      'PlaySessionId': playSessionId,
      'PositionTicks': positionTicks,
    };
  }

  Future<String> _getSessionId(String itemId) {
    return _request('getPlaybackInfo', '获取播放信息', () async {
      final response = await dio.post(
        '/Items/$itemId/PlaybackInfo',
        queryParameters: {'UserId': _userInfo.userId},
      );
      final playSessionId = response.data['PlaySessionId'] as String;
      _logger.info('getPlaybackInfo', '获取 PlaySessionId: $playSessionId');
      return playSessionId;
    });
  }

  @override
  Future<void> reportPlaybackStart(String itemId, int position) {
    return _request('reportPlaybackStart', '上报播放开始', () async {
      final playSessionId = await _getSessionId(itemId);
      _playSessionIds[itemId] = playSessionId;
      await dio.post(
        '/Sessions/Playing',
        data: _buildPlaybackBody(
          itemId,
          playSessionId: playSessionId,
          positionTicks: position * 10000,
          isPaused: false,
        ),
      );
      _logger.info('reportPlaybackStart', '上报播放开始: $itemId');
    });
  }

  @override
  Future<void> reportPlaybackProgress(
    String itemId,
    int position,
    bool isPaused,
  ) {
    return _request('reportPlaybackProgress', '上报播放进度', () async {
      final playSessionId = _playSessionIds[itemId];
      if (playSessionId == null) {
        _logger.warn('reportPlaybackProgress', 'PlaySessionId 为空');
        return;
      }
      await dio.post(
        '/Sessions/Playing/Progress',
        data: _buildPlaybackBody(
          itemId,
          playSessionId: playSessionId,
          positionTicks: position * 10000,
          isPaused: isPaused,
        ),
      );
    });
  }

  @override
  Future<void> reportPlaybackStopped(String itemId, int position) {
    return _request('reportPlaybackStopped', '上报播放停止', () async {
      final playSessionId = _playSessionIds[itemId];
      if (playSessionId == null) {
        _logger.warn('reportPlaybackStopped', 'PlaySessionId 为空');
        return;
      }
      await dio.post(
        '/Sessions/Playing/Stopped',
        data: _buildPlaybackBody(
          itemId,
          playSessionId: playSessionId,
          positionTicks: position * 10000,
          isPaused: true,
        ),
      );
      _playSessionIds.remove(itemId);
      _logger.info('reportPlaybackStopped', '上报播放停止: $itemId');
    });
  }

  @override
  Future<void> setPlayed(String itemId, bool isPlayed) {
    final action = isPlayed ? '标记为已观看' : '取消标记为已观看';
    return _request('setPlayed', action, () async {
      final path = '/Users/${_userInfo.userId}/PlayedItems/$itemId';
      if (isPlayed) {
        await dio.post(path);
      } else {
        await dio.delete(path);
      }
    });
  }

  @override
  void dispose() {}
}

class JellyfinStreamMediaExplorerProvider
    extends EmbyStreamMediaExplorerProvider {
  JellyfinStreamMediaExplorerProvider(super.storage);

  @override
  String get loggerName => 'JellyfinStreamMediaExplorerProvider';

  @override
  String get authPrefix => 'MediaBrowser';
}
