import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:fldanplay/model/danmaku.dart';
import 'package:fldanplay/utils/crypto_utils.dart';
import 'package:fldanplay/utils/log.dart';

const String dandanPlayServer = 'https://api.dandanplay.net';

// Provide these values with:
// --dart-define-from-file=dart_defines/dandanplay.json
const String dandanplayAppId = String.fromEnvironment('DANDANPLAY_APP_ID');
const String dandanplayAppSecret = String.fromEnvironment(
  'DANDANPLAY_APP_SECRET',
);

/// 弹弹play API工具类
class DanmakuApiUtils {
  final String baseUrl;
  DanmakuApiUtils(this.baseUrl);

  final Logger _logger = Logger('DanmakuApiUtils');

  Dio get _dio {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    if (baseUrl == dandanPlayServer) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (dandanplayAppId.isEmpty || dandanplayAppSecret.isEmpty) {
              throw AppException('弹弹play开放平台AppId或AppSecret未配置', null);
            }
            final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final path = Uri.parse(options.path).path;
            options.headers.addAll({
              'X-AppId': dandanplayAppId,
              'X-Timestamp': timestamp.toString(),
              'X-Signature': CryptoUtils.generateDandanplaySignature(
                appId: dandanplayAppId,
                appSecret: dandanplayAppSecret,
                path: path,
                timestamp: timestamp,
              ),
            });
            handler.next(options);
          },
        ),
      );
    }
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        logPrint: (message) => _logger.info('DioRetryInterceptor', message),
        retries: 3,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 3),
        ],
      ),
    );
    return dio;
  }

  /// 文件识别 - 根据文件信息匹配节目
  Future<List<Episode>> matchVideo({
    required String fileName,
    String? fileHash,
  }) async {
    const path = '/api/v2/match';
    try {
      final data = <String, String>{
        'fileName': fileName,
        'matchModel': fileHash == null ? 'fileNameOnly' : 'hashAndFileName',
      };
      if (fileHash != null) {
        data['fileHash'] = fileHash;
      }
      final response = await _dio.post(path, data: data);
      final matches = response.data['matches'] as List;
      final isMatched = response.data['isMatched'] as bool?;
      return matches
          .map((match) => Episode.fromJson(match, baseUrl, isMatched))
          .toList();
    } on DioException catch (e, t) {
      _logger.dio('matchVideo', e, t, action: '匹配节目');
    } catch (e, t) {
      _logger.error('matchVideo', '匹配节目失败', error: e, stackTrace: t);
      throw AppException('匹配节目失败', e);
    }
  }

  /// 搜索番剧集数
  Future<List<Anime>> searchEpisodes(String name) async {
    const path = '/api/v2/search/episodes';
    try {
      final queryParameters = <String, dynamic>{'anime': name};
      final response = await _dio.get(path, queryParameters: queryParameters);
      final animes = <Anime>[];
      // 遍历所有番剧，收集所有集数
      for (final anime in response.data['animes'] as List) {
        animes.add(Anime.fromJson(anime, baseUrl));
      }
      return animes;
    } on DioException catch (e, t) {
      _logger.dio('searchEpisodes', e, t, action: '搜索番剧');
    } catch (e, t) {
      _logger.error('searchEpisodes', '搜索番剧失败', error: e, stackTrace: t);
      throw AppException('搜索番剧失败', e);
    }
  }

  /// 获取弹幕
  Future<List<DanmakuComment>> getComments(
    int episodeId, {
    int sc = 1, // 中文简繁转换。0-不转换，1-转换为简体，2-转换为繁体。
  }) async {
    final path = '/api/v2/comment/$episodeId';
    try {
      final response = await _dio.get(
        path,
        queryParameters: {'withRelated': 'true', 'chConvert': sc},
      );
      final comments = response.data['comments'] as List;
      return comments
          .map((comment) => DanmakuComment.fromJson(comment))
          .toList();
    } on DioException catch (e, t) {
      _logger.dio('getComments', e, t, action: '获取弹幕');
    } catch (e, t) {
      _logger.error('getComments', '获取弹幕失败', error: e, stackTrace: t);
      throw AppException('获取弹幕失败', e);
    }
  }
}
