import 'package:dio/dio.dart';
import 'package:fldanplay/model/storage2.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/stream_media_explorer/service.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:get_it/get_it.dart';

abstract class _EmbyStreamMediaExplorerProvider<T extends StreamStorage>
    implements StreamMediaExplorerProvider {
  final T storage;
  late UserInfo _userInfo;
  late Dio dio;
  late final Logger _logger = Logger(loggerName);
  final _configure = GetIt.I.get<ConfigureService>();

  _EmbyStreamMediaExplorerProvider(this.storage) {
    _userInfo = (userId: storage.userId, token: storage.token);
  }

  String get authPrefix => 'Emby';
  String get authHeaderKey => 'Authorization';
  String get loggerName => 'EmbyStreamMediaExplorerProvider';
  bool get _useRemoteHistory => storage.useRemoteHistory;
  String get url => storage.url;
  String get _baseUrl => url.replaceFirst(RegExp(r'/+$'), '');

  Future<R> _request<R>(
    String method,
    String action,
    Future<R> Function() callback,
  ) async {
    try {
      return await callback();
    } on DioException catch (e, t) {
      _logger.dio(method, e, t, action: action);
    } on AppException {
      rethrow;
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
        '$authPrefix Client="fldanplay", Device="${globalService.device}", '
        'DeviceId="${globalService.deviceId}", Version="${globalService.packageInfo.version}"';
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
    return _parseUserInfo(response.data);
  }

  Future<void> _loginWithSavedPassword(Dio dio) async {
    final username = storage.account.trim();
    final password = storage.password.trim();
    if (username.isEmpty || password.isEmpty) {
      throw AppException('登录信息无效，请重新编辑媒体库并登录', null);
    }
    await _request('refreshCredentials', '重新登录', () async {
      final newUserInfo = await _authenticate(dio, username, password);
      _userInfo = newUserInfo;
      storage
        ..token = newUserInfo.token
        ..userId = newUserInfo.userId;
      await GetIt.I<StorageService>().update(storage);
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
            (item) => _parseMediaItem(
              item,
              baseUrl: _baseUrl,
              includeUserData: _useRemoteHistory,
            ),
          )
          .toList();
    });
  }

  @override
  String getVideoFile(PlaybackInfo playbackInfo) {
    return playbackInfo.videoUrl ??
        '$url/Videos/${playbackInfo.itemId}/stream?static=true&api_key=${_userInfo.token}';
  }

  @override
  Future<String> getVideoUrl(
    PlaybackInfo playbackInfo, {
    TranscodeOptions? options,
  }) async {
    final itemId = playbackInfo.itemId;
    if (options == null) {
      return '$url/Videos/$itemId/stream?static=true&api_key=${_userInfo.token}&PlaySessionId=${playbackInfo.playSessionId}';
    }
    final subtitleIndex = options.subtitleStreamIndex;
    final embedSubtitle =
        _configure.transEmbedSub.value && subtitleIndex != null;
    final uri = Uri.parse('$url/Videos/$itemId/master.m3u8').replace(
      queryParameters: <String, String>{
        'MediaSourceId': playbackInfo.mediaSourceId,
        'PlaySessionId': playbackInfo.playSessionId,
        'segmentContainer': 'ts',
        'VideoCodec': 'h264',
        'AudioCodec': 'aac',
        'VideoBitRate': options.bitrate.toString(),
        'SubtitleMethod': embedSubtitle ? 'Encode' : 'External',
        'AlwaysBurnInSubtitleWhenTranscoding': embedSubtitle ? 'true' : 'false',
        if (options.audioStreamIndex != null)
          'AudioStreamIndex': options.audioStreamIndex.toString(),
        if (embedSubtitle) 'subtitleStreamIndex': subtitleIndex.toString(),
      },
    );
    return uri.toString();
  }

  @override
  Future<PlaybackInfo> getPlaybackInfo(String itemId) {
    return _request('getPlaybackInfo', '获取播放信息', () async {
      final response = await dio.get(
        '/Items/$itemId/PlaybackInfo',
        queryParameters: {'UserId': _userInfo.userId},
      );
      final data = response.data as Map<String, dynamic>;
      final mediaSources = data['MediaSources'] as List<dynamic>? ?? [];
      if (mediaSources.isEmpty) throw AppException('获取播放信息失败', '服务器未返回媒体源');
      final source = mediaSources.first as Map<String, dynamic>;
      final mediaSourceId = source['Id']?.toString() ?? '';
      final playSessionId = data['PlaySessionId']?.toString() ?? '';
      if (mediaSourceId.isEmpty || playSessionId.isEmpty) {
        throw AppException('获取播放信息失败', '媒体源信息不完整');
      }
      final supportsTranscoding = source['SupportsTranscoding'] == true;
      final bitrate = source['Bitrate'] ?? 0;
      final mediaStreams = (source['MediaStreams'] ?? []) as List<dynamic>;
      final streams = _parseMediaStreams(itemId, mediaSourceId, mediaStreams);
      final audioStreams = streams.audioStreams;
      final subtitleStreams = streams.subtitleStreams;
      final defaultAudioIndex = audioStreams.isEmpty
          ? null
          : audioStreams.first.index;
      final defaultSubtitleIndex = subtitleStreams.isEmpty
          ? null
          : subtitleStreams.first.index;
      final itemInfo = await _getItemInfo(itemId, source);
      return PlaybackInfo(
        itemId: itemId,
        mediaSourceId: mediaSourceId,
        playSessionId: playSessionId,
        supportsTranscoding: supportsTranscoding,
        bitrate: bitrate,
        audioStreams: audioStreams,
        subtitleStreams: subtitleStreams,
        defaultAudio: defaultAudioIndex,
        defaultSubtitle: defaultSubtitleIndex,
        fileName: itemInfo.fileName,
        chapters: itemInfo.chapters,
        headers: headers,
      );
    });
  }

  Future<({String fileName, Map<int, String> chapters})> _getItemInfo(
    String itemId,
    Map<String, dynamic> source,
  ) async {
    final sourceName = (source['Name'] ?? source['Path'] ?? '').toString();
    final chapters = _parseChapters(source['Chapters']);
    if (sourceName.isNotEmpty) {
      return (fileName: sourceName, chapters: chapters);
    }
    try {
      final response = await dio.get(getItemsPath(itemId));
      final data = response.data as Map<String, dynamic>;
      final mediaSources = data['MediaSources'] as List<dynamic>?;
      final sourceFileName = mediaSources == null || mediaSources.isEmpty
          ? ''
          : (mediaSources.first['Name'] ?? '').toString();
      return (
        fileName: sourceFileName.isEmpty ? itemId : sourceFileName,
        chapters: _parseChapters(data['Chapters']),
      );
    } catch (e) {
      _logger.warn('_getItemInfo', '获取文件名失败，使用媒体 ID: $itemId', error: e);
      return (fileName: itemId, chapters: chapters);
    }
  }

  ({List<MediaStreamInfo> audioStreams, List<MediaStreamInfo> subtitleStreams})
  _parseMediaStreams(
    String itemId,
    String mediaSourceId,
    List<dynamic> mediaStreams,
  ) {
    final audioStreams = <MediaStreamInfo>[];
    final subtitleStreams = <MediaStreamInfo>[];
    for (final item in mediaStreams) {
      if (item is! Map) continue;
      final type = item['Type']?.toString();
      if (type == 'Audio') {
        final streams = _parseMediaStreamInfo(item);
        streams.isDefault
            ? audioStreams.insert(0, streams)
            : audioStreams.add(streams);
      } else if (type == 'Subtitle') {
        final index = item['Index'] ?? -1;
        final codec = item['Codec'] ?? '';
        final uri =
            '$url/Videos/$itemId/$mediaSourceId/Subtitles/$index/Stream.$codec?api_key=${_userInfo.token}';
        final streams = _parseMediaStreamInfo(item, subtitleUrl: uri);
        streams.isDefault
            ? subtitleStreams.insert(0, streams)
            : subtitleStreams.add(streams);
      }
    }
    return (audioStreams: audioStreams, subtitleStreams: subtitleStreams);
  }

  @override
  Future<MediaDetail> getMediaDetail(String itemId) {
    return _request('getMediaDetail', '获取媒体详情', () async {
      final response = await dio.get(getItemsPath(itemId));
      final detail = _parseMediaDetail(
        response.data,
        baseUrl: _baseUrl,
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
        return (seasonId: movieId, episodeId: movieId, type: MediaType.movie);
      }
      if (type == 'Episode') {
        final seasonId = item['SeasonId'] ?? item['ParentId'];
        if (seasonId == null || seasonId.toString().isEmpty) {
          throw AppException('获取播放目标失败', '找不到季度信息');
        }
        return (
          seasonId: seasonId.toString(),
          episodeId: (item['Id'] ?? itemId).toString(),
          type: MediaType.series,
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
          .map((item) => _parseCollectionItem(item))
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
      imageUrl: hasPrimary
          ? _itemImageUrl(
              _baseUrl,
              (json['PrimaryImageItemId'] ?? json['Id']).toString(),
            )
          : null,
      fallbackImageUrl:
          hasSeriesPrimary && seriesId != null && seriesId.isNotEmpty
          ? _itemImageUrl(_baseUrl, seriesId)
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
          .map((item) => _parseSeasonInfo(item))
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
        return [
          _parseEpisodeInfo(
            item,
            baseUrl: _baseUrl,
            includeUserData: _useRemoteHistory,
          ),
        ];
      } else if (type == .series) {
        final response = await dio.get(
          getItemsPath(),
          queryParameters: {
            'parentId': itemId,
            'Fields': 'Chapters,MediaSources',
          },
        );
        final episodes = (response.data['Items'] as List).map((item) {
          return _parseEpisodeInfo(
            item as Map<String, dynamic>,
            baseUrl: _baseUrl,
            includeUserData: _useRemoteHistory,
          );
        }).toList();
        episodes.sort(
          (a, b) => (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0),
        );
        return episodes;
      }
      throw AppException('获取播放目标失败', '当前媒体不支持继续播放');
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
      final playbackInfo = await getPlaybackInfo(itemId);
      final streamUrl = getVideoFile(playbackInfo);
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
      rethrow;
    }
  }

  @override
  Future<bool> downloadSubtitle(
    String subtitleUrl,
    String localPath, {
    CancelToken? cancelToken,
  }) async {
    try {
      await dio.download(subtitleUrl, localPath, cancelToken: cancelToken);
      _logger.info('downloadSubtitle', '字幕下载完成: $subtitleUrl');
      return true;
    } catch (e, t) {
      if (e is DioException && e.type == .cancel) return false;
      _logger.error('downloadSubtitle', '字幕下载失败', error: e, stackTrace: t);
      rethrow;
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
      'PlaySessionId': playSessionId,
      'PositionTicks': positionTicks,
    };
  }

  @override
  Future<void> reportPlaybackStart(
    String itemId,
    int position,
    String sessionId,
  ) {
    return _request('reportPlaybackStart', '上报播放开始', () async {
      await dio.post(
        '/Sessions/Playing',
        data: _buildPlaybackBody(
          itemId,
          playSessionId: sessionId,
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
    String sessionId,
    int position,
    bool isPaused,
  ) {
    return _request('reportPlaybackProgress', '上报播放进度', () async {
      await dio.post(
        '/Sessions/Playing/Progress',
        data: _buildPlaybackBody(
          itemId,
          playSessionId: sessionId,
          positionTicks: position * 10000,
          isPaused: isPaused,
        ),
      );
    });
  }

  @override
  Future<void> reportPlaybackStopped(
    String itemId,
    String sessionId,
    int position,
  ) {
    return _request('reportPlaybackStopped', '上报播放停止', () async {
      await dio.post(
        '/Sessions/Playing/Stopped',
        data: _buildPlaybackBody(
          itemId,
          playSessionId: sessionId,
          positionTicks: position * 10000,
          isPaused: true,
        ),
      );
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

class EmbyStreamMediaExplorerProvider
    extends _EmbyStreamMediaExplorerProvider<EmbyMediaStorage> {
  EmbyStreamMediaExplorerProvider(super.storage);
}

class JellyfinStreamMediaExplorerProvider
    extends _EmbyStreamMediaExplorerProvider<JellyfinMediaStorage> {
  JellyfinStreamMediaExplorerProvider(super.storage);

  @override
  String get loggerName => 'JellyfinStreamMediaExplorerProvider';

  @override
  String get authPrefix => 'MediaBrowser';
}

String _itemImageUrl(String baseUrl, String itemId) {
  return '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/Items/$itemId/Images/Primary';
}

String? _primaryImageUrl(Map<String, dynamic> json, String baseUrl) {
  final tags = json['ImageTags'];
  if (tags is Map && tags['Primary'] == null) return null;
  final id = (json['Id'] ?? '').toString();
  return id.isEmpty ? null : _itemImageUrl(baseUrl, id);
}

UserInfo _parseUserInfo(Map<String, dynamic> json) {
  return (userId: json['User']['Id'], token: json['AccessToken']);
}

UserData _parseUserData(Map<String, dynamic> json) {
  return UserData(
    unplayedItemCount: json['UnplayedItemCount'],
    playbackPositionTicks: json['PlaybackPositionTicks'],
    lastPlayedDate: json['LastPlayedDate'] != null
        ? DateTime.parse(json['LastPlayedDate']).toUtc()
        : null,
    played: json['Played'] == true,
  );
}

CollectionItem _parseCollectionItem(Map<String, dynamic> json) {
  return (id: json['Id'], name: json['Name']);
}

MediaItem _parseMediaItem(
  Map<String, dynamic> json, {
  required String baseUrl,
  bool includeUserData = false,
}) {
  return MediaItem(
    name: json['Name'],
    id: json['Id'],
    type: MediaType.values.firstWhere(
      (e) => e.name == json['Type'],
      orElse: () => MediaType.none,
    ),
    userData: includeUserData && json['UserData'] != null
        ? _parseUserData(json['UserData'])
        : null,
    imageUrl: _primaryImageUrl(json, baseUrl),
  );
}

MediaDetail _parseMediaDetail(
  Map<String, dynamic> json, {
  required String baseUrl,
  bool includeUserData = false,
}) {
  double priceAsDouble(dynamic value) {
    if (value is int) {
      return (value).toDouble();
    }
    return value as double;
  }

  final externalUrls = json['ExternalUrls'];
  return MediaDetail(
    id: json['Id'] ?? '',
    name: json['Name'] ?? '',
    overview: json['Overview'],
    genres: (json['Genres'] as List?)?.cast<String>() ?? [],
    productionYear: json['ProductionYear'],
    runTimeTicks: json['RunTimeTicks'],
    type: MediaType.values.firstWhere(
      (e) => e.name == json['Type'],
      orElse: () => MediaType.none,
    ),
    rating: priceAsDouble(json['CommunityRating'] ?? 0.0),
    isFavorite: includeUserData && json['UserData']?['IsFavorite'] == true,
    externalUrls: externalUrls is List
        ? [
            for (final url in externalUrls)
              if (url is Map)
                (
                  name: (url['Name'] ?? '').toString(),
                  url: (url['Url'] ?? '').toString(),
                ),
          ]
        : const [],
    tags: List<String>.from(json['Tags']?.map((x) => x as String) ?? []),
    imageUrl: _primaryImageUrl(json, baseUrl),
  );
}

SeasonInfo _parseSeasonInfo(Map<String, dynamic> json) {
  return SeasonInfo(
    id: json['Id'] ?? '',
    name: json['Name'] ?? '',
    indexNumber: json['IndexNumber'],
  );
}

EpisodeInfo _parseEpisodeInfo(
  Map<String, dynamic> json, {
  required String baseUrl,
  bool includeUserData = false,
}) {
  final List<dynamic>? mediaSources = json['MediaSources'];
  if (mediaSources == null || mediaSources.isEmpty) {
    throw Exception('MediaSources is null');
  }
  return EpisodeInfo(
    id: json['Id'] ?? '',
    name: json['Name'] ?? '',
    indexNumber: json['IndexNumber'],
    parentIndexNumber: json['ParentIndexNumber'],
    seriesName: json['SeriesName'] ?? json['Name'],
    runTimeTicks: json['RunTimeTicks'],
    fileName: mediaSources.first['Name'] ?? '',
    chapters: _parseChapters(json['Chapters']),
    userData: includeUserData && json['UserData'] != null
        ? _parseUserData(json['UserData'])
        : null,
    imageUrl: _primaryImageUrl(json, baseUrl),
  );
}

Map<int, String> _parseChapters(dynamic json) {
  if (json is! List) return const {};
  final entries = <(int, String)>[];
  for (final item in json) {
    if (item is! Map) continue;
    final rawTicks = item['StartPositionTicks'];
    final ticks = rawTicks is num
        ? rawTicks.toInt()
        : int.tryParse(rawTicks?.toString() ?? '');
    if (ticks == null) continue;
    final seconds = ticks ~/ 10000000;
    final name = item['Name']?.toString() ?? '';
    entries.add((
      seconds,
      name.isNotEmpty ? name : Utils.formatDuration(Duration(seconds: seconds)),
    ));
  }
  entries.sort((a, b) => a.$1.compareTo(b.$1));
  return {for (final entry in entries) entry.$1: entry.$2};
}

MediaStreamInfo _parseMediaStreamInfo(
  Map<dynamic, dynamic> json, {
  String? subtitleUrl,
}) {
  final map = Map<String, dynamic>.from(json);
  final rawIndex = map['Index'];
  return MediaStreamInfo(
    index: rawIndex is int
        ? rawIndex
        : int.tryParse(rawIndex?.toString() ?? '') ?? -1,
    language: map['Language']?.toString(),
    title: (map['DisplayTitle'] ?? map['Title'])?.toString(),
    isDefault: map['IsDefault'] == true,
    isExternal: map['IsExternal'] == true,
    subtitleUrl: subtitleUrl,
  );
}
