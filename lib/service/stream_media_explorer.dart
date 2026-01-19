import 'package:dio/dio.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

abstract class StreamMediaExplorerProvider {
  Dio getDio(String url, {UserInfo? userInfo});
  Future<UserInfo> login(Dio dio, String username, String password);
  Future<List<CollectionItem>> getUserViews();
  Future<List<MediaItem>> getItems(String parentId, {required Filter filter});
  Future<MediaDetail> getMediaDetail(String itemId);
  Future<String> getFileName(String itemId);
  Map<String, String> get headers;
  String getImageUrl(String itemId, {String tag = 'Primary'});
  String getStreamUrl(String itemId);
  Future<bool> downloadVideo(
    String itemId,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });
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
  Storage? storage;
  List<EpisodeInfo> episodeList = [];
  final _logger = Logger('StreamMediaExplorerService');
  final Signal<Filter> filter = signal(Filter());
  final AsyncSignal<List<MediaItem>> items = asyncSignal(AsyncLoading());

  static void register() {
    final service = StreamMediaExplorerService();
    effect(service.getData);
    GetIt.I.registerSingleton<StreamMediaExplorerService>(service);
  }

  void getData() async {
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
      this.storage = storage;
      provider.value = newProvider;
      libraryId.value = storage.mediaLibraryId!;
    });
    _logger.info('setProvider', '设置新的媒体库提供者');
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
      subtitle: '${episode.seriesName} ${episode.indexNumber}',
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
}

class EmbyStreamMediaExplorerProvider implements StreamMediaExplorerProvider {
  final String url;
  final UserInfo userInfo;
  late String auth;
  late Dio dio;
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
        final fileName = await getFileName(itemId);
        detail.seasons = [
          SeasonInfo(
            id: detail.id,
            name: detail.name,
            episodes: [
              EpisodeInfo(
                id: detail.id,
                name: detail.name,
                indexNumber: 0,
                seriesName: detail.name,
                runTimeTicks: detail.runTimeTicks,
                fileName: fileName,
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
  Future<String> getFileName(String itemId) async {
    try {
      final response = await dio.get(getItemsPath(itemId));
      final List<dynamic>? mediaSources = response.data['MediaSources'];
      if (mediaSources == null || mediaSources.isEmpty) {
        throw Exception('MediaSources is null');
      }
      return mediaSources.first['Name'] as String;
    } on DioException catch (e, t) {
      _logger.dio('getFileName', e, t, action: '获取文件名');
    } catch (e, t) {
      _logger.error('getFileName', '获取文件名失败', error: e, stackTrace: t);
      throw AppException('获取文件名失败', e);
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
        episode.fileName = await getFileName(episode.id);
        episodes.add(episode);
      }

      // 按集数编号排序
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
