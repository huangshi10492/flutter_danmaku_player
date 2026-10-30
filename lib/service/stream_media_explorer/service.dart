import 'package:dio/dio.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/storage2.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/service/storage.dart';
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
  String getVideoFile(PlaybackInfo playbackInfo);
  Future<String> getVideoUrl(
    PlaybackInfo playbackInfo, {
    TranscodeOptions? options,
  });
  Future<PlaybackInfo> getPlaybackInfo(String itemId);
  Future<bool> downloadVideo(
    String itemId,
    String localPath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });
  Future<bool> downloadSubtitle(
    String subtitleUrl,
    String localPath, {
    CancelToken? cancelToken,
  });
  Future<void> reportPlaybackStart(
    String itemId,
    int position,
    String sessionId,
  );
  Future<void> reportPlaybackProgress(
    String itemId,
    String sessionId,
    int position,
    bool isPaused,
  );
  Future<void> reportPlaybackStopped(
    String itemId,
    String sessionId,
    int position,
  );
  void dispose();
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
  StreamStorage? storage;
  void Function()? _reportEffect;
  String? _seasonId;
  List<MediaStreamInfo> audioStreams = const [];
  List<MediaStreamInfo> subtitleStreams = const [];
  late TranscodeOptions tranOpt = .new('');
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

  void setProvider(
    StreamMediaExplorerProvider newProvider,
    StreamStorage storage,
  ) {
    batch(() {
      filter.value = Filter();
      libraries.value = AsyncLoading();
      items.value = AsyncLoading();
      _seasonId = null;
      tranOpt = .new('');
      audioStreams = const [];
      subtitleStreams = const [];
      episodeMap.clear();
      this.storage = storage;
      provider.value = newProvider;
      libraryId.value = storage.mediaLibraryId ?? '';
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
      final providerViews = await provider.value!.getUserViews();
      final list = useRemoteHistory
          ? [(id: '', name: '收藏'), ...providerViews]
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
    if (provider.value == null || useRemoteHistory != true) return [];
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
    var videoInfo = await getVideoInfo(index);
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
    if (storage == null || storage!.mediaLibraryId == newId) return;
    storage!.mediaLibraryId = newId;
    await GetIt.I<StorageService>().update(storage!);
  }

  List<EpisodeInfo> get playbackEpisodes {
    final seasonId = _seasonId;
    if (seasonId == null) return const [];
    return episodeMap[seasonId]?.value.value ?? const [];
  }

  void selectPlaybackSeason(String seasonId) {
    final episodes = episodeMap[seasonId]?.value.value;
    if (episodes == null) {
      throw AppException('获取播放列表失败', '当前季度尚未加载');
    }
    _seasonId = seasonId;
  }

  Future<VideoInfo> getVideoInfo(int index, {bool isFile = false}) async {
    final episodes = playbackEpisodes;
    final episode = episodes[index];
    final playbackInfo = await provider.value!.getPlaybackInfo(episode.id);
    if (episode.fileName.isEmpty && playbackInfo.fileName.isNotEmpty) {
      episode.fileName = playbackInfo.fileName;
    }
    final directVideoPath = provider.value!.getVideoFile(playbackInfo);
    String videoUrl = '';
    String sessionId = '';
    List<ExternalSubtitle> externalSubtitles = const [];
    Map<String, String> videoHeaders = const {};
    if (isFile) {
      videoUrl = directVideoPath;
      videoHeaders = playbackInfo.headers;
    } else {
      final stream = await _resolveStream(playbackInfo);
      videoUrl = stream.url;
      sessionId = playbackInfo.playSessionId;
      externalSubtitles = stream.subtitles;
      videoHeaders = stream.headers;
    }
    return VideoInfo(
      currentVideoPath: videoUrl,
      directVideoPath: directVideoPath,
      virtualVideoPath: episode.id,
      headers: videoHeaders,
      historiesType: HistoriesType.streamMediaStorage,
      storageKey: storage!.uniqueKey,
      name: episode.name,
      videoName: episode.fileName.isNotEmpty ? episode.fileName : episode.name,
      subtitle: episode.subtitle,
      sessionId: sessionId,
      listLength: episodes.length,
      videoIndex: index,
      canSwitch: true,
      externalSubtitles: externalSubtitles,
      chapters: episode.chapters,
    );
  }

  Future<
    ({
      String url,
      List<ExternalSubtitle> subtitles,
      Map<String, String> headers,
    })
  >
  _resolveStream(PlaybackInfo info) async {
    if (tranOpt.itemId != info.itemId) tranOpt = .fromMediaPlaybackInfo(info);
    if (!info.supportsTranscoding || tranOpt.isOriginal) {
      audioStreams = const [];
      subtitleStreams = info.subtitleStreams
          .where((s) => s.isExternal && s.subtitleUrl != null)
          .toList();
      final url = await provider.value!.getVideoUrl(info);
      return (
        url: url,
        subtitles: const <ExternalSubtitle>[],
        headers: info.headers,
      );
    }
    audioStreams = info.audioStreams;
    subtitleStreams = info.subtitleStreams;
    final embed = GetIt.I.get<ConfigureService>().transEmbedSub.value;
    final url = await provider.value!.getVideoUrl(info, options: tranOpt);
    final subtitles = <ExternalSubtitle>[];
    if (!embed) {
      final subtitle = MediaStreamInfo.findByIndex(
        subtitleStreams,
        tranOpt.subtitleStreamIndex,
      );
      final subtitleUrl = subtitle?.subtitleUrl;
      if (subtitle != null && subtitleUrl != null) {
        subtitles.add(
          ExternalSubtitle(subtitleUrl, subtitle.label, subtitle.language),
        );
      }
    }
    return (url: url, subtitles: subtitles, headers: info.headers);
  }

  Future<VideoInfo> refreshVideoInfo(VideoInfo videoInfo) async {
    final itemId = videoInfo.virtualVideoPath;
    final playbackInfo = await provider.value!.getPlaybackInfo(itemId);
    final stream = await _resolveStream(playbackInfo);
    return videoInfo
      ..sessionId = playbackInfo.playSessionId
      ..currentVideoPath = stream.url
      ..directVideoPath = provider.value!.getVideoFile(playbackInfo)
      ..externalSubtitles = stream.subtitles
      ..headers = stream.headers;
  }

  Future<DanmakuMatchInfo> getDanmakuMatchInfo(String itemId) async {
    final info = await provider.value!.getPlaybackInfo(itemId);
    return .new(
      fileName: info.fileName.isNotEmpty ? info.fileName : itemId,
      currentVideoPath: provider.value!.getVideoFile(info),
      headers: info.headers,
    );
  }

  Future<VideoInfo> getVideoInfoFromHistory(History history) async {
    final itemId = history.url!;
    final playbackInfo = await provider.value!.getPlaybackInfo(itemId);
    final stream = await _resolveStream(playbackInfo);
    final directVideoPath = provider.value!.getVideoFile(playbackInfo);
    return VideoInfo(
      currentVideoPath: stream.url,
      directVideoPath: directVideoPath,
      virtualVideoPath: itemId,
      headers: stream.headers,
      historiesType: HistoriesType.streamMediaStorage,
      storageKey: storage!.uniqueKey,
      name: history.name,
      videoName: playbackInfo.fileName.isNotEmpty
          ? playbackInfo.fileName
          : (history.fileName ?? history.name),
      subtitle: history.subtitle,
      sessionId: playbackInfo.playSessionId,
      videoIndex: -1,
      externalSubtitles: stream.subtitles,
      chapters: playbackInfo.chapters,
    );
  }

  Map<String, String> get headers => provider.value!.headers;

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
    final localHistory = historyService.getHistoryByPath(
      episode.id,
      storageKey: storage?.uniqueKey,
    );
    if (!useRemoteHistory) return localHistory;
    final userData = episode.userData;
    final lastPlayedDate = userData?.lastPlayedDate;
    if (userData == null || lastPlayedDate == null) return localHistory;
    final updateTime = lastPlayedDate.millisecondsSinceEpoch;
    if (localHistory != null && localHistory.updateTime >= updateTime) {
      return localHistory;
    }
    return History(
      uniqueKey: CryptoUtils.generateVideoUniqueKey(
        episode.id,
        storageKey: storage?.uniqueKey,
      ),
      duration: ((episode.runTimeTicks ?? 0) / 10000).round(),
      position: ((userData.playbackPositionTicks ?? 0) / 10000).round(),
      type: HistoriesType.streamMediaStorage,
      updateTime: updateTime,
      name: episode.name,
      url: episode.id,
      storageKey: storage!.uniqueKey,
      subtitle: episode.subtitle,
      fileName: episode.fileName,
    );
  }

  Future<void> removeHistory(String itemId) async {
    final history = historyService.getHistoryByPath(
      itemId,
      storageKey: storage?.uniqueKey,
    );
    if (history != null) historyService.delete(history: history);
    setPlayed(itemId, false);
  }

  Future<void> startPlayback(String itemId, String sessionId) async {
    if (provider.value == null || !useRemoteHistory) return;
    try {
      _reportEffect?.call();
      await provider.value!.reportPlaybackStart(
        itemId,
        globalService.position.value,
        sessionId,
      );
      _reportEffect = effect(() {
        if (provider.value == null) return;
        provider.value!.reportPlaybackProgress(
          itemId,
          sessionId,
          globalService.position.value,
          !globalService.isPlaying.value,
        );
      });
    } catch (e, t) {
      _logger.error('startPlayback', '上报播放开始失败', error: e, stackTrace: t);
    }
  }

  Future<void> stopPlayback(String itemId, String sessionId) async {
    if (provider.value == null || !useRemoteHistory) return;
    final positionTicks = globalService.position.value;
    try {
      _reportEffect?.call();
      _reportEffect = null;
      await provider.value!.reportPlaybackStopped(
        itemId,
        sessionId,
        positionTicks,
      );
    } catch (e, t) {
      _logger.error('stopPlayback', '上报播放停止失败', error: e, stackTrace: t);
    }
  }
}
