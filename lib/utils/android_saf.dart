import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

import 'log.dart';

class AndroidSaf {
  AndroidSaf._();

  static final SafUtil _saf = SafUtil();
  static final Logger _logger = Logger('AndroidSaf');

  static bool isTreeUri(String? uri) {
    return uri != null && uri.startsWith('content://');
  }

  static Future<String?> pickDirectory(String? initialUri) async {
    final dir = await _saf.pickDirectory(
      initialUri: initialUri,
      writePermission: false,
      persistablePermission: true,
    );
    if (dir == null) return null;
    return dir.uri;
  }

  static Future<bool> hasPermission(String uri) async {
    if (!isTreeUri(uri)) return false;
    try {
      return await _saf.hasPersistedPermission(uri);
    } catch (e, t) {
      _logger.error('hasPermission', '校验SAF授权失败', error: e, stackTrace: t);
      return false;
    }
  }

  static Future<SafDocumentFile> requireRoot(String uri) async {
    if (!isTreeUri(uri)) throw AppException('非SAF目录', null);
    if (!await hasPermission(uri)) {
      throw AppException('本地媒体库授权已失效，请重新选择文件夹', null);
    }
    final root = await _saf.stat(uri, true, throws: true);
    if (root == null) throw AppException('无法访问已授权的文件夹', null);
    return root;
  }

  static Future<SafDocumentFile> resolveDirectory(
    String rootUri,
    String relativePath,
  ) async {
    final root = await requireRoot(rootUri);
    final segments = relativePath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return root;
    final dir = await _saf.child(root.uri, segments);
    if (dir == null || !dir.isDir) throw AppException('目录不存在或无法访问', null);
    return dir;
  }

  static Future<List<SafDocumentFile>> listDirectory(
    String rootUri,
    String relativePath,
  ) async {
    final target = await resolveDirectory(rootUri, relativePath);
    return _saf.list(target.uri);
  }
}
