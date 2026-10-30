import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fldanplay/model/storage2.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/stream_media_explorer/service.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:get_it/get_it.dart';

class FnysStreamMediaExplorerProvider implements StreamMediaExplorerProvider {
  FnysStreamMediaExplorerProvider(this.storage) {
    _token = storage.token;
  }
  final FnysMediaStorage storage;
  late Dio dio;
  late final Logger _logger = Logger('FnysStreamMediaExplorerProvider');
  final _random = Random();
  String _token = '';
  final Map<String, String> _mediaGuidCache = {};
  static const _apiKey = 'NDzZTVxnRKP8Z0jXg1VAMonaG8akvh';
  static const _apiSecret = '16CCEB3D-AB42-077D-36A1-F355324E4237';
  static const _noAuthHeader = 'x-fnys-no-auth';
  bool get _useRemoteHistory => storage.useRemoteHistory;
  String get url => storage.url;
  String get _baseUrl => url.replaceFirst(RegExp(r'/+$'), '');

  @override
  Map<String, String> get headers => {
    if (_token.isNotEmpty) 'Authorization': _token,
  };

  String _buildAuthx(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) {
    final nonce = (100000 + _random.nextInt(900000)).toString();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final digest = md5
        .convert(
          utf8.encode(
            body != null
                ? jsonEncode(body)
                : query != null && query.isNotEmpty
                ? _sortedQuery(query)
                : '',
          ),
        )
        .toString();
    final sign = md5
        .convert(
          utf8.encode(
            [_apiKey, path, nonce, timestamp, digest, _apiSecret].join('_'),
          ),
        )
        .toString();
    return 'nonce=$nonce&timestamp=$timestamp&sign=$sign';
  }

  String _sortedQuery(Map<String, dynamic> query) {
    final keys = query.keys.where((key) => query[key] != null).toList()..sort();
    return keys.map((key) => '$key=${query[key]}').join('&');
  }

  Future<T> _request<T>(
    String method,
    String action,
    Future<T> Function() callback,
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

  dynamic _unwrap(Response response, String action) {
    final data = response.data;
    if (data is! Map || !data.containsKey('code')) return data;
    final code = data['code'];
    if (code == 0 || code == '0') return data['data'];
    final msg = (data['msg'] ?? data['message'] ?? '').toString();
    throw AppException(msg.isEmpty ? '$action失败($code)' : msg, null);
  }

  bool _requiresAuthx(String path) {
    return !path.startsWith('/v/api/v1/media/range/') &&
        !path.startsWith('/v/api/v1/sys/img') &&
        !path.startsWith('/v/api/v1/subtitle/dl/');
  }

  Dio _createDio(String baseUrl) {
    final client = Dio(BaseOptions(baseUrl: baseUrl));
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final requestUri = options.uri;
          final baseUri = Uri.parse(client.options.baseUrl);
          final isServerRequest = requestUri.origin == baseUri.origin;
          final skipAuth = options.headers.remove(_noAuthHeader) != null;
          if (isServerRequest) {
            if (!skipAuth) options.headers.addAll(headers);
            if (_requiresAuthx(requestUri.path)) {
              final query = requestUri.queryParameters;
              options.headers['Authx'] = _buildAuthx(
                requestUri.path,
                query: query.isEmpty ? null : Map<String, dynamic>.from(query),
                body: options.data is Map
                    ? Map<String, dynamic>.from(options.data as Map)
                    : null,
              );
            }
          }
          handler.next(options);
        },
      ),
    );
    return client;
  }

  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? query,
    required String action,
  }) async {
    final response = await dio.get(path, queryParameters: query);
    return _unwrap(response, action);
  }

  Future<dynamic> _post(
    String path,
    Map<String, dynamic> body, {
    required String action,
  }) async {
    final response = await dio.post(path, data: body);
    return _unwrap(response, action);
  }

  @override
  Future<void> initialize({bool validateCredentials = true}) async {
    dio = await getDio(url, validateCredentials: validateCredentials);
  }

  @override
  Future<Dio> getDio(
    String url, {
    UserInfo? userInfo,
    bool validateCredentials = true,
  }) async {
    if (userInfo != null && userInfo.token.isNotEmpty) _token = userInfo.token;
    final client = _createDio(url.trim().replaceFirst(RegExp(r'/+$'), ''));
    if (validateCredentials) {
      await _request('getDio', '校验登录凭证', () => _ensureCredentials(client));
    }
    return client;
  }

  Future<void> _ensureCredentials(Dio client) async {
    if (_token.isEmpty) {
      await _loginWithSavedPassword(client);
      return;
    }
    try {
      if (await _checkUser(client)) return;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != 401 && status != 403) rethrow;
    }
    await _loginWithSavedPassword(client);
  }

  Future<bool> _checkUser(Dio client) async {
    final response = await client.get('/v/api/v1/user/info');
    final data = response.data;
    if (data is Map && data.containsKey('code')) {
      final code = data['code'];
      if (code != 0 && code != '0') return false;
      return data['data'] is Map;
    }
    return false;
  }

  Future<void> _loginWithSavedPassword(Dio client) async {
    final password = storage.password;
    if (storage.account.isEmpty || password.isEmpty) {
      throw AppException('登录信息无效，请重新编辑媒体库并登录', null);
    }
    await _request('refreshCredentials', '重新登录', () async {
      final token = await _authenticate(client, storage.account, password);
      _token = token;
      storage.token = token;
      await GetIt.I<StorageService>().update(storage);
      _logger.info('refreshCredentials', '登录凭证已刷新');
    });
  }

  Future<String> _authenticate(
    Dio client,
    String username,
    String password,
  ) async {
    try {
      final response = await client.post(
        '/v/api/v1/login',
        data: {
          'username': username,
          'password': password,
          'app_name': 'fldanplay',
        },
        options: Options(headers: {_noAuthHeader: '1'}),
      );
      return _extractToken(_unwrap(response, '登录'));
    } catch (e) {
      _logger.warn('login', 'v1 登录接口失败，尝试 v2 接口', error: e);
      final response = await client.post(
        '/v/api/v2/user/loginByPassword',
        data: {
          'username': username,
          'password': sha256.convert(utf8.encode(password)).toString(),
          'app_name': 'fldanplay',
        },
        options: Options(headers: {_noAuthHeader: '1'}),
      );
      return _extractToken(_unwrap(response, '登录'));
    }
  }

  String _extractToken(dynamic data) {
    final token = data is Map ? (data['token'] ?? '').toString() : '';
    if (token.isEmpty) throw AppException('登录失败', '服务器未返回 Token');
    return token;
  }

  @override
  Future<UserInfo> login(Dio dio, String username, String password) {
    return _request('login', '登录', () async {
      final token = await _authenticate(dio, username, password);
      return (userId: '', token: token);
    });
  }

  @override
  Future<List<CollectionItem>> getUserViews() {
    return _request('getUserViews', '获取媒体库列表', () async {
      final data = await _get('/v/api/v1/mediadb/list', action: '获取媒体库列表');
      final result = <CollectionItem>[];
      for (final item in (data as List? ?? const [])) {
        if (item is! Map) continue;
        final guid = (item['guid'] ?? '').toString();
        if (guid.isEmpty) continue;
        final category = (item['category'] ?? '').toString().toUpperCase();
        if (category == 'IPTV') continue;
        result.add((id: guid, name: (item['title'] ?? '').toString()));
      }
      return result;
    });
  }

  @override
  Future<List<MediaItem>> getItems(String parentId, {required Filter filter}) {
    return _request('getItems', '获取媒体列表', () async {
      final keyword = filter.searchTerm.trim();
      if (keyword.isNotEmpty) return _search(keyword);
      final favoriteOnly = filter.isFavorite || parentId.isEmpty;
      final body = <String, dynamic>{
        if (parentId.isNotEmpty) 'ancestor_guid': parentId,
        'sort_type': filter.sortOrder ? 'ASC' : 'DESC',
        'sort_column': _sortColumn(filter.sortBy),
        'page': 1,
        'page_size': 300,
        'tags': {
          'type': const ['Movie', 'TV'],
        },
      };
      final data = await _post(
        favoriteOnly ? '/v/api/v1/favorite/list' : '/v/api/v1/item/list',
        body,
        action: '获取媒体列表',
      );
      final raw = data is Map ? data['list'] : data;
      final items = <MediaItem>[];
      for (final item in (raw as List? ?? const [])) {
        if (item is! Map) continue;
        final guid = (item['guid'] ?? '').toString();
        if (guid.isEmpty) continue;
        if (!_matchYears(item, filter.years)) continue;
        items.add(
          MediaItem(
            id: guid,
            name: (item['title'] ?? '').toString(),
            type: _mediaType(item['type']?.toString()),
            userData: _useRemoteHistory ? _userDataFrom(item) : null,
            imageUrl: _posterUrlOf(item),
          ),
        );
      }
      return items;
    });
  }

  Future<List<MediaItem>> _search(String keyword) async {
    final data = await _get(
      '/v/api/v1/search/list',
      query: {'q': keyword},
      action: '搜索媒体',
    );
    final raw = data is List ? data : (data is Map ? data['list'] : null);
    final items = <MediaItem>[];
    for (final item in (raw as List? ?? const [])) {
      if (item is! Map) continue;
      final guid = (item['guid'] ?? '').toString();
      final type = _mediaType(item['type']?.toString());
      if (guid.isEmpty || type == MediaType.none) continue;
      items.add(
        MediaItem(
          id: guid,
          name: (item['title'] ?? '').toString(),
          type: type,
          userData: _useRemoteHistory ? _userDataFrom(item) : null,
          imageUrl: _posterUrlOf(item),
        ),
      );
    }
    return items;
  }

  String? _posterUrlOf(Map item) {
    final path = item['poster'];
    if (path == null) return null;
    return '$_baseUrl/v/api/v1/sys/img$path';
  }

  @override
  String getVideoFile(PlaybackInfo playbackInfo) => playbackInfo.videoUrl ?? '';

  @override
  Future<String> getVideoUrl(
    PlaybackInfo playbackInfo, {
    TranscodeOptions? options,
  }) async => playbackInfo.videoUrl ?? '';

  String _directPlayUrl(_FnysStreamInfo stream) {
    final direct = stream.directLinks.firstOrNull;
    if (direct != null) return direct;
    return '$_baseUrl/v/api/v1/media/range/${stream.mediaGuid}';
  }

  Map<String, String> _playbackHeaders(
    String videoUrl,
    Map<String, String> playHeaders,
  ) {
    final videoUri = Uri.tryParse(videoUrl);
    if (videoUri == null ||
        !videoUri.hasAuthority ||
        videoUri.origin != Uri.parse(_baseUrl).origin) {
      return playHeaders;
    }
    return {...headers, ...playHeaders};
  }

  @override
  Future<PlaybackInfo> getPlaybackInfo(String itemId) {
    return _request('getPlaybackInfo', '获取播放信息', () async {
      final playInfo = await _fetchMediaGuid(itemId);
      final stream = await _fetchStream(playInfo);
      final audioStreams = stream.audioStreams;
      final subtitleStreams = stream.subtitleStreams;
      final videoUrl = _directPlayUrl(stream);
      return PlaybackInfo(
        itemId: itemId,
        mediaSourceId: stream.mediaGuid,
        playSessionId: '',
        supportsTranscoding: false,
        bitrate: 0,
        audioStreams: audioStreams,
        subtitleStreams: subtitleStreams,
        defaultAudio: audioStreams.isEmpty ? null : audioStreams.first.index,
        defaultSubtitle: subtitleStreams.isEmpty
            ? null
            : subtitleStreams.first.index,
        fileName: stream.fileName,
        videoUrl: videoUrl,
        headers: _playbackHeaders(videoUrl, stream.playHeaders),
      );
    });
  }

  @override
  Future<MediaDetail> getMediaDetail(String itemId) {
    return _request('getMediaDetail', '获取媒体详情', () async {
      var data = await _itemDetail(itemId);
      var type = (data['type'] ?? '').toString();
      var hops = 0;
      while ((type == 'Episode' || type == 'Season') && hops < 2) {
        final parentGuid = (data['parent_guid'] ?? '').toString();
        if (parentGuid.isEmpty) break;
        data = await _itemDetail(parentGuid);
        type = (data['type'] ?? '').toString();
        hops++;
      }
      final guid = (data['guid'] ?? itemId).toString();
      final mediaType = _mediaType(type);
      final detail = MediaDetail(
        id: guid,
        name: (data['title'] ?? '').toString(),
        overview: data['overview']?.toString(),
        productionYear: _yearOf(data['release_date']),
        runTimeTicks: _secondsToTicks(data['duration']),
        type: mediaType,
        rating: double.tryParse((data['vote_average'] ?? '').toString()) ?? 0,
        isFavorite: _asInt(data['is_favorite']) == 1,
        imageUrl: _posterUrlOf(data),
      );
      if (mediaType == MediaType.series) {
        final seasons = await _getSeasons(guid);
        detail.seasons = seasons.isEmpty
            ? [SeasonInfo(id: guid, name: detail.name)]
            : seasons;
      } else {
        detail.seasons = [SeasonInfo(id: guid, name: detail.name)];
      }
      return detail;
    });
  }

  Future<List<SeasonInfo>> _getSeasons(String seriesGuid) async {
    final data = await _get(
      '/v/api/v1/season/list/$seriesGuid',
      action: '获取季度信息',
    );
    final seasons = <SeasonInfo>[];
    for (final item in (data as List? ?? const [])) {
      if (item is! Map) continue;
      final guid = (item['guid'] ?? '').toString();
      if (guid.isEmpty) continue;
      seasons.add(
        SeasonInfo(
          id: guid,
          name: (item['title'] ?? '').toString(),
          indexNumber: _asInt(item['season_number']),
        ),
      );
    }
    seasons.sort((a, b) => (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0));
    return seasons;
  }

  @override
  Future<List<EpisodeInfo>> getEpisodes(String itemId, MediaType type) {
    return _request('getEpisodes', '获取集数信息', () async {
      if (type == MediaType.movie) {
        final data = await _itemDetail(itemId);
        final title = (data['title'] ?? '').toString();
        return [
          EpisodeInfo(
            id: (data['guid'] ?? itemId).toString(),
            name: title,
            seriesName: title,
            runTimeTicks: _secondsToTicks(data['duration']),
            fileName: '',
            userData: _useRemoteHistory ? _userDataFrom(data) : null,
            imageUrl: _posterUrlOf(data),
          ),
        ];
      }
      if (type == MediaType.series) {
        final data = await _get(
          '/v/api/v1/episode/list/$itemId',
          action: '获取集数信息',
        );
        final raw = data is List ? data : (data is Map ? data['list'] : null);
        final episodes = <EpisodeInfo>[];
        for (final item in (raw as List? ?? const [])) {
          if (item is! Map) continue;
          final guid = (item['guid'] ?? '').toString();
          if (guid.isEmpty) continue;
          final title = (item['title'] ?? '').toString();
          episodes.add(
            EpisodeInfo(
              id: guid,
              name: title,
              indexNumber: _asInt(item['episode_number']),
              parentIndexNumber: _asInt(item['season_number']),
              seriesName: (item['tv_title'] ?? item['parent_title'] ?? '')
                  .toString(),
              runTimeTicks: _secondsToTicks(item['duration']),
              fileName: '',
              userData: _useRemoteHistory ? _userDataFrom(item) : null,
              imageUrl: _posterUrlOf(item),
            ),
          );
        }
        episodes.sort(
          (a, b) => (a.indexNumber ?? 0).compareTo(b.indexNumber ?? 0),
        );
        return episodes;
      }
      throw AppException('获取集数信息失败', '当前媒体不支持播放');
    });
  }

  @override
  Future<PlaybackTarget> getPlaybackTarget(String itemId) {
    return _request('getPlaybackTarget', '获取播放目标', () async {
      final data = await _itemDetail(itemId);
      final type = (data['type'] ?? '').toString();
      final guid = (data['guid'] ?? itemId).toString();
      switch (type) {
        case 'Movie':
          return (seasonId: guid, episodeId: guid, type: MediaType.movie);
        case 'Episode':
          final seasonGuid = (data['parent_guid'] ?? '').toString();
          if (seasonGuid.isEmpty) throw AppException('获取播放目标失败', '找不到季度信息');
          return (
            seasonId: seasonGuid,
            episodeId: guid,
            type: MediaType.series,
          );
        default:
          throw AppException('获取播放目标失败', '当前媒体不支持播放');
      }
    });
  }

  @override
  Future<List<ResumeItem>> getResumeItems({String? parentId, int limit = 12}) {
    return _request('getResumeItems', '获取继续观看', () async {
      final data = await _get('/v/api/v1/play/list', action: '获取继续观看');
      final raw = data is List ? data : (data is Map ? data['list'] : null);
      final records = <Map>[
        for (final item in (raw as List? ?? const []))
          if (item is Map && (item['guid'] ?? '').toString().isNotEmpty) item,
      ];
      final scopeId = parentId?.trim() ?? '';
      final seasonIds = scopeId.isEmpty
          ? const <String>{}
          : await _seasonIdsOf(scopeId);
      final items = <ResumeItem>[];
      for (final item in records) {
        final guid = (item['guid'] ?? '').toString();
        final parentGuid = (item['parent_guid'] ?? '').toString();
        if (scopeId.isNotEmpty &&
            guid != scopeId &&
            parentGuid != scopeId &&
            !seasonIds.contains(parentGuid)) {
          continue;
        }
        final seriesName = (item['tv_title'] ?? '').toString();
        items.add(
          ResumeItem(
            id: guid,
            name: (item['title'] ?? '').toString(),
            type: seriesName.isEmpty ? .movie : .series,
            seriesName: seriesName,
            parentIndexNumber: _asInt(item['season_number']),
            indexNumber: _asInt(item['episode_number']),
            playbackPositionTicks: _secondsToTicks(item['ts']) ?? 0,
            runTimeTicks: _secondsToTicks(item['duration']) ?? 0,
            seriesId: parentGuid.isNotEmpty ? parentGuid : guid,
            imageUrl: _posterUrlOf(item),
          ),
        );
        if (items.length >= limit) break;
      }
      return items;
    });
  }

  Future<Set<String>> _seasonIdsOf(String guid) async {
    try {
      return (await _getSeasons(guid)).map((season) => season.id).toSet();
    } catch (e) {
      _logger.warn('getResumeItems', '获取季度信息失败: $guid', error: e);
      return {};
    }
  }

  @override
  Future<void> setFavorite(String itemId, bool isFavorite) {
    final action = isFavorite ? '添加收藏' : '取消收藏';
    return _request('setFavorite', action, () async {
      const path = '/v/api/v1/item/favorite';
      final data = {'item_guid': itemId};
      final response = isFavorite
          ? await dio.put(path, data: data)
          : await dio.delete(path, data: data);
      _unwrap(response, action);
    });
  }

  @override
  Future<void> setPlayed(String itemId, bool isPlayed) {
    final action = isPlayed ? '标记为已观看' : '取消标记为已观看';
    return _request('setPlayed', action, () async {
      const path = '/v/api/v1/item/watched';
      final data = {'item_guid': itemId};
      final response = isPlayed
          ? await dio.post(path, data: data)
          : await dio.delete(path, data: data);
      _unwrap(response, action);
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
      final stream = await _fetchStream(await _fetchMediaGuid(itemId));
      final streamUrl = _directPlayUrl(stream);
      await dio.download(
        streamUrl,
        localPath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          headers: _playbackHeaders(streamUrl, stream.playHeaders),
        ),
      );
      _logger.info('downloadVideo', '下载完成: $itemId -> $localPath');
      return true;
    } catch (e, t) {
      if (e is DioException && e.type == .cancel) return false;
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
      await dio.download(
        subtitleUrl,
        localPath,
        cancelToken: cancelToken,
        options: Options(headers: headers),
      );
      _logger.info('downloadSubtitle', '字幕下载完成: $subtitleUrl');
      return true;
    } catch (e, t) {
      if (e is DioException && e.type == .cancel) return false;
      _logger.error('downloadSubtitle', '字幕下载失败', error: e, stackTrace: t);
      rethrow;
    }
  }

  Future<void> _recordPlayback(String itemId, int position) async {
    final mediaGuid = await _fetchMediaGuid(itemId);
    await _post('/v/api/v1/play/record', {
      'item_guid': itemId,
      'media_guid': mediaGuid,
      'ts': position ~/ 1000,
      'device_id': GetIt.I.get<GlobalService>().deviceId,
      'lan': 'zh-CN',
      'direct_link_audio_index': 0,
    }, action: '上报播放进度');
  }

  @override
  Future<void> reportPlaybackStart(
    String itemId,
    int position,
    String sessionId,
  ) {
    return _request('reportPlaybackStart', '上报播放开始', () async {
      await _recordPlayback(itemId, position);
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
      await _recordPlayback(itemId, position);
    });
  }

  @override
  Future<void> reportPlaybackStopped(
    String itemId,
    String sessionId,
    int position,
  ) {
    return _request('reportPlaybackStopped', '上报播放停止', () async {
      await _recordPlayback(itemId, position);
      _logger.info('reportPlaybackStopped', '上报播放停止: $itemId');
    });
  }

  @override
  void dispose() {}

  Future<Map<String, dynamic>> _itemDetail(String guid) async {
    final data = await _get('/v/api/v1/item/$guid', action: '获取媒体详情');
    if (data is! Map) throw AppException('获取媒体详情失败', '服务器未返回媒体信息');
    return Map<String, dynamic>.from(data);
  }

  Future<String> _fetchMediaGuid(String itemId) async {
    final cached = _mediaGuidCache[itemId];
    if (cached != null) return cached;
    final data = await _post('/v/api/v1/play/info', {
      'item_guid': itemId,
    }, action: '获取播放信息');
    if (data is! Map) throw AppException('获取播放信息失败', '服务器未返回播放信息');
    final mediaGuid = (data['media_guid'] ?? '').toString();
    if (mediaGuid.isEmpty) throw AppException('播放失败', '服务器未返回媒体源');
    _mediaGuidCache[itemId] = mediaGuid;
    return mediaGuid;
  }

  Future<_FnysStreamInfo> _fetchStream(String mediaGuid) async {
    final data = await _post('/v/api/v1/stream', {
      'media_guid': mediaGuid,
      'ip': md5.convert(utf8.encode(_token)).toString(),
      'header': {
        'User-Agent': [''],
      },
    }, action: '获取播放流');
    if (data is! Map) throw AppException('获取播放流失败', '服务器未返回流信息');
    return _FnysStreamInfo.fromJson(data, baseUrl: _baseUrl);
  }

  UserData _userDataFrom(Map item) {
    return UserData(
      played: _asInt(item['is_watched'] ?? item['watched'] ?? 0) == 1,
      playbackPositionTicks: _secondsToTicks(
        item['ts'] ?? item['watched_ts'] ?? 0,
      ),
    );
  }

  MediaType _mediaType(String? type) {
    return switch (type) {
      'Movie' => .movie,
      'TV' || 'Season' || 'Episode' => .series,
      _ => .none,
    };
  }

  String _sortColumn(String sortBy) {
    return switch (sortBy) {
      'SortName' => 'sort_title',
      'CommunityRating' => 'vote_average',
      'ProductionYear' => 'release_date',
      _ => 'create_time',
    };
  }

  bool _matchYears(Map item, String years) {
    final wanted = years
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .toSet();
    if (wanted.isEmpty) return true;
    final year = _yearOf(item['release_date']);
    return year != null && wanted.contains(year);
  }

  int? _yearOf(Object? releaseDate) {
    final value = releaseDate?.toString() ?? '';
    if (value.length < 4) return null;
    return int.tryParse(value.substring(0, 4));
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _secondsToTicks(Object value) => _asInt(value) * 10000000;

class _FnysStreamInfo {
  _FnysStreamInfo({
    required this.mediaGuid,
    required this.fileName,
    required this.audioStreams,
    required this.subtitleStreams,
    required this.directLinks,
    required this.playHeaders,
  });

  factory _FnysStreamInfo.fromJson(Map data, {required String baseUrl}) {
    final video = data['video_stream'] is Map
        ? data['video_stream'] as Map
        : const {};
    final file = data['file_stream'] is Map
        ? data['file_stream'] as Map
        : const {};
    final playHeaders = <String, String>{};
    final rawHeader = data['header'];
    if (rawHeader is Map) {
      rawHeader.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          playHeaders[key.toString()] = value.first.toString();
        } else if (value != null) {
          playHeaders[key.toString()] = value.toString();
        }
      });
    }
    final localAudio = data['audio_streams'] as List?;
    final rawAudio = localAudio != null && localAudio.isNotEmpty
        ? localAudio
        : (data['direct_link_audio_streams'] as List? ?? const []);
    final audioStreams = <MediaStreamInfo>[];
    for (final item in rawAudio) {
      if (item is! Map) continue;
      audioStreams.add(
        MediaStreamInfo(
          index: _asInt(item['index']),
          language: item['language']?.toString(),
          title: _streamTitle(item),
          isDefault: _asInt(item['is_default']) == 1,
        ),
      );
    }
    final subtitleStreams = <MediaStreamInfo>[];
    for (final item in (data['subtitle_streams'] as List? ?? const [])) {
      if (item is! Map) continue;
      final guid = (item['guid'] ?? '').toString();
      final isExternal = _asInt(item['is_external']) == 1;
      subtitleStreams.add(
        MediaStreamInfo(
          index: _asInt(item['index']),
          language: item['language']?.toString(),
          title: _streamTitle(item),
          isDefault: _asInt(item['is_default']) == 1,
          isExternal: isExternal,
          subtitleUrl: isExternal && guid.isNotEmpty
              ? '$baseUrl/v/api/v1/subtitle/dl/$guid'
              : null,
        ),
      );
    }
    final directLinks = <String>[];
    for (final item in (data['direct_link_qualities'] as List? ?? const [])) {
      if (item is! Map) continue;
      final link = (item['url'] ?? '').toString();
      if (link.isEmpty) continue;
      directLinks.add(link);
    }
    return _FnysStreamInfo(
      mediaGuid: (video['media_guid'] ?? '').toString(),
      fileName: (file['file_name'] ?? '').toString(),
      audioStreams: audioStreams,
      subtitleStreams: subtitleStreams,
      directLinks: directLinks,
      playHeaders: playHeaders,
    );
  }

  static String? _streamTitle(Map item) {
    final title = (item['title'] ?? '').toString();
    return title.isEmpty ? null : title;
  }

  final String mediaGuid;
  final String fileName;
  final List<MediaStreamInfo> audioStreams;
  final List<MediaStreamInfo> subtitleStreams;
  final List<String> directLinks;
  final Map<String, String> playHeaders;
}
