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
  Dio getDio(String url, {UserInfo? userInfo});
  Future<UserInfo> login(Dio dio, String username, String password);
  Future<List<CollectionItem>> getUserViews();
  Future<List<ResumeItem>> getResumeItems({String? parentId, int limit = 12});
  Future<List<MediaItem>> getItems(String parentId, {required Filter filter});
  Future<MediaDetail> getMediaDetail(String itemId);
  Future<PlaybackQueueResult> getPlaybackQueue(String itemId);
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

class Filter {
  String searchTerm = '';
  String years = '';
  String seriesStatus = '';
  String sortBy = 'SortName';
  // true: 升序，false: 降序
  bool sortOrder = true;
  Filter();

  bool isFiltered() {
    return searchTerm.isNotEmpty ||
        years.isNotEmpty ||
        seriesStatus.isNotEmpty ||
        sortBy != 'SortName' ||
        sortOrder != true;
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
  List<EpisodeInfo> episodeList = [];
  final _logger = Logger('StreamMediaExplorerService');
  final Signal<Filter> filter = signal(Filter());
  final AsyncSignal<List<MediaItem>> items = asyncSignal(AsyncLoading());
  final globalService = GetIt.I.get<GlobalService>();

  static void register() {
    final service = StreamMediaExplorerService();
    effect(service._syncLibraryId);
    effect(service.getData);
    GetIt.I.registerSingleton<StreamMediaExplorerService>(service);
  }

  Future<void> getData() async {
    items.value = AsyncLoading();
    if (provider.value == null || libraryId.value.isEmpty) {
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
      episodeList = [];
      this.storage = storage;
      provider.value = newProvider;
      libraryId.value = storage.mediaLibraryId!;
    });
    _logger.info('setProvider', '设置新的媒体库提供者');
  }

  Future<List<CollectionItem>> loadLibraries() async {
    if (provider.value == null) {
      libraries.value = AsyncData([]);
      return [];
    }
    libraries.value = AsyncLoading();
    try {
      final list = await provider.value!.getUserViews();
      libraries.value = AsyncData(list);
      if (list.isEmpty) {
        libraryId.value = '';
      } else {
        final currentLibraryId = storage?.mediaLibraryId;
        final selectedLibraryId =
            list.any((item) => item.id == currentLibraryId)
            ? currentLibraryId!
            : list.first.id;
        if (libraryId.value != selectedLibraryId) {
          libraryId.value = selectedLibraryId;
        }
      }
      return list;
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

  Future<VideoInfo> prepareVideoInfoByItemId(String itemId) async {
    if (provider.value == null) {
      throw AppException('播放失败', '媒体服务未初始化');
    }
    final queue = await provider.value!.getPlaybackQueue(itemId);
    return prepareVideoInfoForSeason(queue.season, queue.initialIndex);
  }

  Future<VideoInfo> prepareVideoInfoForSeason(
    SeasonInfo season,
    int index,
  ) async {
    setVideoList(season);
    final videoInfo = getVideoInfo(index);
    final history = getHistory(season.episodes[index]);
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

  void setVideoList(SeasonInfo seasonInfo) {
    episodeList = seasonInfo.episodes;
  }

  VideoInfo getVideoInfo(int index) {
    final episode = episodeList[index];
    final playbackUrl = getPlaybackUrl(episode.id);
    return VideoInfo(
      currentVideoPath: playbackUrl,
      virtualVideoPath: episode.id,
      historiesType: HistoriesType.streamMediaStorage,
      storageKey: storage!.uniqueKey,
      name: episode.name,
      videoName: episode.fileName,
      subtitle: episode.subtitle,
      listLength: episodeList.length,
      videoIndex: index,
      canSwitch: true,
    );
  }

  VideoInfo getVideoInfoFromHistory(History history) {
    final playbackUrl = getPlaybackUrl(history.url!);
    return VideoInfo(
      currentVideoPath: playbackUrl,
      virtualVideoPath: history.url!,
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

  History? getHistory(EpisodeInfo episode) {
    final historyService = GetIt.I.get<HistoryService>();
    final localHistory = historyService.getHistoryByPath(episode.id);
    if (storage!.useRemoteHistory == null ||
        storage!.useRemoteHistory == false) {
      return localHistory;
    }
    if (episode.userData == null || episode.userData!.lastPlayedDate == null) {
      return localHistory;
    }
    History? remoteHistory;
    if (localHistory == null ||
        localHistory.updateTime <
            episode.userData!.lastPlayedDate!.millisecondsSinceEpoch) {
      remoteHistory = History(
        uniqueKey: CryptoUtils.generateVideoUniqueKey(episode.id),
        duration: ((episode.runTimeTicks ?? 0) / 10000).round(),
        position: ((episode.userData!.playbackPositionTicks ?? 0) / 10000)
            .round(),
        type: HistoriesType.streamMediaStorage,
        updateTime: episode.userData!.lastPlayedDate!.millisecondsSinceEpoch,
        name: episode.name,
        url: episode.id,
        storageKey: storage!.uniqueKey,
        subtitle: '${episode.seriesName} ${episode.indexNumber}',
        fileName: episode.fileName,
      );
    }
    return remoteHistory ?? localHistory;
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
  final String url;
  final UserInfo userInfo;
  late String auth;
  late Dio dio;
  final Map<String, String> _playSessionIds = {};
  late final Logger _logger = Logger(loggerName);

  EmbyStreamMediaExplorerProvider(this.url, this.userInfo) {
    final globalService = GetIt.I.get<GlobalService>();
    auth =
        '$authPrefix Client="fldanplay", Device="${globalService.device}", DeviceId="${globalService.deviceId}", Version="0.0.1", Token="${userInfo.token}"';
    dio = getDio(url, userInfo: userInfo);
  }

  String get authPrefix => 'Emby';
  String get authHeaderKey => 'Authorization';
  String get loggerName => 'EmbyStreamMediaExplorerProvider';

  String getItemsPath([String? itemId]) {
    return itemId != null
        ? '/Users/${userInfo.userId}/Items/$itemId'
        : '/Users/${userInfo.userId}/Items';
  }

  @override
  Map<String, String> get headers => {authHeaderKey: auth};

  @override
  Future<List<MediaItem>> getItems(
    String parentId, {
    required Filter filter,
  }) async {
    try {
      final params = <String, dynamic>{
        'parentId': parentId,
        'limit': 300,
        'recursive': true,
        'searchTerm': filter.searchTerm,
        'includeItemTypes': 'Movie,Series',
        'sortBy': filter.sortBy,
        'years': filter.years,
        'sortOrder': filter.sortOrder ? 'Ascending' : 'Descending',
        'seriesStatus': filter.seriesStatus,
        'imageTypeLimit': '1',
        'enableImageTypes': 'Primary',
      };
      final response = await dio.get('/Items', queryParameters: params);
      List<MediaItem> res = [];
      for (var item in response.data['Items']) {
        res.add(MediaItem.fromJson(item));
      }
      return res;
    } on DioException catch (e, t) {
      _logger.dio('getItems', e, t, action: '获取媒体列表');
    } catch (e, t) {
      _logger.error('getItems', '获取媒体列表失败', error: e, stackTrace: t);
      throw AppException('获取媒体列表失败', e);
    }
  }

  @override
  String getImageUrl(String itemId, {String tag = 'Primary'}) {
    return '$url/Items/$itemId/Images/$tag';
  }

  @override
  String getStreamUrl(String itemId) {
    return '$url/Videos/$itemId/stream?static=true&api_key=${userInfo.token}';
  }

  @override
  Future<MediaDetail> getMediaDetail(String itemId) async {
    try {
      final response = await dio.get(getItemsPath(itemId));
      final detail = MediaDetail.fromJson(response.data);

      // 如果是系列，获取季度信息
      if (detail.type == MediaType.series) {
        detail.seasons = await getSeasons(dio, itemId);
      }
      if (detail.type == MediaType.movie) {
        final itemInfo = await getItemInfo(itemId);
        detail.seasons = [
          SeasonInfo(
            id: detail.id,
            name: detail.name,
            episodes: [
              EpisodeInfo(
                id: detail.id,
                name: detail.name,
                seriesName: detail.name,
                runTimeTicks: detail.runTimeTicks,
                fileName: itemInfo.fileName,
                userData: itemInfo.userData,
              ),
            ],
          ),
        ];
      }

      return detail;
    } on DioException catch (e, t) {
      _logger.dio('getMediaDetail', e, t, action: '获取媒体详情');
    } catch (e, t) {
      _logger.error('getMediaDetail', '获取媒体详情失败', error: e, stackTrace: t);
      throw AppException('获取媒体详情失败', e);
    }
  }

  @override
  Future<PlaybackQueueResult> getPlaybackQueue(String itemId) async {
    try {
      final response = await dio.get(getItemsPath(itemId));
      final item = response.data as Map<String, dynamic>;
      final type = item['Type'] as String?;
      if (type == 'Movie') {
        final itemInfo = ItemInfo.fromJson(item);
        return PlaybackQueueResult(
          season: SeasonInfo(
            id: item['Id'] ?? itemId,
            name: item['Name'] ?? '影片',
            episodes: [
              EpisodeInfo(
                id: item['Id'] ?? itemId,
                name: item['Name'] ?? '',
                indexNumber: item['IndexNumber'],
                seriesName: item['Name'] ?? '',
                runTimeTicks: item['RunTimeTicks'],
                fileName: itemInfo.fileName,
                userData: itemInfo.userData,
              ),
            ],
          ),
          initialIndex: 0,
        );
      }
      if (type == 'Episode') {
        final seasonId = item['SeasonId'] ?? item['ParentId'];
        if (seasonId == null || seasonId.toString().isEmpty) {
          throw AppException('获取播放列表失败', '找不到季度信息');
        }
        final episodes = await getEpisodes(dio, seasonId.toString());
        final initialIndex = episodes.indexWhere(
          (episode) => episode.id == itemId,
        );
        return PlaybackQueueResult(
          season: SeasonInfo(
            id: seasonId.toString(),
            name: item['SeasonName'] ?? '当前季度',
            indexNumber: item['ParentIndexNumber'],
            episodes: episodes,
          ),
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        );
      }
      throw AppException('获取播放列表失败', '当前媒体不支持继续播放');
    } on DioException catch (e, t) {
      _logger.dio('getPlaybackQueue', e, t, action: '获取播放列表');
    } catch (e, t) {
      _logger.error('getPlaybackQueue', '获取播放列表失败', error: e, stackTrace: t);
      throw AppException('获取播放列表失败', e);
    }
  }

  @override
  Dio getDio(String url, {UserInfo? userInfo}) {
    final globalService = GetIt.I.get<GlobalService>();
    String auth =
        '$authPrefix Client="fldanplay", Device="${globalService.device}", DeviceId="${globalService.deviceId}", Version="0.0.1"';
    if (userInfo != null) {
      auth += ', Token="${userInfo.token}"';
    }
    return Dio(BaseOptions(baseUrl: url, headers: {authHeaderKey: auth}));
  }

  @override
  Future<UserInfo> login(Dio dio, String username, String password) async {
    try {
      final response = await dio.post(
        '/Users/AuthenticateByName',
        data: {'Username': username, 'Pw': password},
      );
      return UserInfo.fromJson(response.data);
    } on DioException catch (e, t) {
      _logger.dio('login', e, t, action: '登录');
    } catch (e, t) {
      _logger.error('login', '登录失败', error: e, stackTrace: t);
      throw AppException('登录失败', e);
    }
  }

  @override
  Future<List<CollectionItem>> getUserViews() async {
    try {
      final response = await dio.get('/Users/${userInfo.userId}/Views');
      List<CollectionItem> res = [];
      for (var item in response.data['Items']) {
        res.add(CollectionItem.fromJson(item));
      }
      return res;
    } on DioException catch (e, t) {
      _logger.dio('getUserViews', e, t, action: '获取用户视图');
    } catch (e, t) {
      _logger.error('getUserViews', '获取用户视图失败', error: e, stackTrace: t);
      throw AppException('获取用户视图失败', e);
    }
  }

  @override
  Future<List<ResumeItem>> getResumeItems({
    String? parentId,
    int limit = 12,
  }) async {
    try {
      final response = await dio.get(
        '/Users/${userInfo.userId}/Items/Resume',
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
    } on DioException catch (e, t) {
      _logger.dio('getResumeItems', e, t, action: '获取继续观看');
    } catch (e, t) {
      _logger.error('getResumeItems', '获取继续观看失败', error: e, stackTrace: t);
      throw AppException('获取继续观看失败', e);
    }
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

  Future<List<SeasonInfo>> getSeasons(Dio dio, String seriesId) async {
    try {
      final response = await dio.get(
        getItemsPath(),
        queryParameters: {'parentId': seriesId},
      );

      List<SeasonInfo> seasons = [];
      for (var item in response.data['Items']) {
        final season = SeasonInfo.fromJson(item);
        final episodes = await getEpisodes(dio, season.id);
        seasons.add(
          SeasonInfo(
            id: season.id,
            name: season.name,
            indexNumber: season.indexNumber,
            episodes: episodes,
          ),
        );
      }

      // 按季度编号排序
      seasons.sort(
        (a, b) => (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0),
      );
      return seasons;
    } on DioException catch (e, t) {
      _logger.dio('getSeasons', e, t, action: '获取季度信息');
    } catch (e, t) {
      _logger.error('getSeasons', '获取季度信息失败', error: e, stackTrace: t);
      throw AppException('获取季度信息失败', e);
    }
  }

  Future<List<EpisodeInfo>> getEpisodes(Dio dio, String seasonId) async {
    try {
      final response = await dio.get(
        getItemsPath(),
        queryParameters: {'parentId': seasonId},
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
    } on DioException catch (e, t) {
      _logger.dio('getEpisodes', e, t, action: '获取集数信息');
    } catch (e, t) {
      _logger.error('getEpisodes', '获取集数信息失败', error: e, stackTrace: t);
      throw AppException('获取集数信息失败', e);
    }
  }

  Future<ItemInfo> getItemInfo(String itemId) async {
    try {
      final response = await dio.get(getItemsPath(itemId));
      return ItemInfo.fromJson(response.data);
    } on DioException catch (e, t) {
      _logger.dio('getItemInfo', e, t, action: '获取项目信息');
    } catch (e, t) {
      _logger.error('getItemInfo', '获取项目信息失败', error: e, stackTrace: t);
      throw AppException('获取项目信息失败', e);
    }
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
    } on DioException catch (e, t) {
      if (e.type == DioExceptionType.cancel) {
        return false;
      }
      _logger.error('downloadVideo', '下载失败', error: e, stackTrace: t);
      return false;
    } catch (e, t) {
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

  Future<String> _getSessionId(String itemId) async {
    try {
      final response = await dio.post(
        '/Items/$itemId/PlaybackInfo',
        queryParameters: {'UserId': userInfo.userId},
      );
      final playSessionId = response.data['PlaySessionId'] as String;
      _logger.info('getPlaybackInfo', '获取 PlaySessionId: $playSessionId');
      return playSessionId;
    } on DioException catch (e, t) {
      _logger.dio('getPlaybackInfo', e, t, action: '获取播放信息');
    } catch (e, t) {
      _logger.error('getPlaybackInfo', '获取播放信息失败', error: e, stackTrace: t);
      throw AppException('获取播放信息失败', e);
    }
  }

  @override
  Future<void> reportPlaybackStart(String itemId, int position) async {
    try {
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
    } on DioException catch (e, t) {
      _logger.dio('reportPlaybackStart', e, t, action: '上报播放开始');
    } catch (e, t) {
      _logger.error('reportPlaybackStart', '上报播放开始失败', error: e, stackTrace: t);
    }
  }

  @override
  Future<void> reportPlaybackProgress(
    String itemId,
    int position,
    bool isPaused,
  ) async {
    try {
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
    } on DioException catch (e, t) {
      _logger.dio('reportPlaybackProgress', e, t, action: '上报播放进度');
    } catch (e, t) {
      _logger.error(
        'reportPlaybackProgress',
        '上报播放进度失败',
        error: e,
        stackTrace: t,
      );
    }
  }

  @override
  Future<void> reportPlaybackStopped(String itemId, int position) async {
    try {
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
    } on DioException catch (e, t) {
      _logger.dio('reportPlaybackStopped', e, t, action: '上报播放停止');
    } catch (e, t) {
      _logger.error(
        'reportPlaybackStopped',
        '上报播放停止失败',
        error: e,
        stackTrace: t,
      );
    }
  }

  @override
  void dispose() {}
}

class JellyfinStreamMediaExplorerProvider
    extends EmbyStreamMediaExplorerProvider {
  JellyfinStreamMediaExplorerProvider(super.url, super.userInfo);

  @override
  String get loggerName => 'JellyfinStreamMediaExplorerProvider';

  @override
  String get authPrefix => 'MediaBrowser';
}
