import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_smb2/dart_smb2.dart';
import 'package:dio/dio.dart';

typedef HashProgressCallback = void Function(int received, int total);

class CryptoUtils {
  static const int _dandanplayHashBytes = 16 * 1024 * 1024;

  static String generateVideoUniqueKey(String input) {
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  static Future<String?> generateHash(
    String fileUrl,
    Map<String, String>? headers, {
    HashProgressCallback? onProgress,
  }) async {
    final localHash = await _generateFileHash(fileUrl);
    if (localHash != null) return localHash;
    final uri = Uri.tryParse(fileUrl);
    switch (uri?.scheme.toLowerCase()) {
      case 'smb':
      case 'smb2':
        return _generateSmbHash(uri!, onProgress: onProgress);
      case 'http':
      case 'https':
        return _generateHttpHash(
          fileUrl,
          headers: headers,
          onProgress: onProgress,
        );
      default:
        return null;
    }
  }

  static Future<String?> _generateSmbHash(
    Uri uri, {
    HashProgressCallback? onProgress,
  }) async {
    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    if (uri.host.isEmpty || segments.length < 2) return null;
    final share = segments.first;
    final remotePath = segments.skip(1).join('/');
    final (user, password) = _splitUserInfo(uri.userInfo);
    final pool = await Smb2Pool.connect(
      host: uri.host,
      share: share,
      user: user,
      password: password,
      workers: 1,
      version: .any,
    );
    try {
      final bytes = BytesBuilder(copy: false);
      var window = _dandanplayHashBytes;
      await for (final chunk in pool.streamFile(
        remotePath,
        onProgress: (received, total) {
          window = total < _dandanplayHashBytes ? total : _dandanplayHashBytes;
          onProgress?.call(received > window ? window : received, window);
        },
      )) {
        final remaining = _dandanplayHashBytes - bytes.length;
        if (remaining <= 0) break;
        if (chunk.length >= remaining) {
          bytes.add(Uint8List.sublistView(chunk, 0, remaining));
          break;
        }
        bytes.add(chunk);
      }
      final data = bytes.takeBytes();
      if (data.isEmpty) return null;
      onProgress?.call(data.length, window);
      return md5.convert(data).toString();
    } finally {
      await pool.disconnect();
    }
  }

  static Future<String?> _generateHttpHash(
    String url, {
    Map<String, String>? headers,
    HashProgressCallback? onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final requestHeaders = <String, dynamic>{
      ...?headers,
      'Accept-Encoding': 'identity',
      'Range': 'bytes=0-${_dandanplayHashBytes - 1}',
    };
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        responseType: .stream,
        headers: requestHeaders,
      ),
    );
    final response = await dio.getUri<ResponseBody>(uri);
    final body = response.data;
    if (body == null) return null;
    final contentLength = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
    final total =
        contentLength == null ||
            contentLength <= 0 ||
            contentLength > _dandanplayHashBytes
        ? _dandanplayHashBytes
        : contentLength;
    onProgress?.call(0, total);
    final bytes = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in body.stream) {
      if (chunk.isEmpty) continue;
      final remaining = _dandanplayHashBytes - received;
      if (remaining <= 0) break;
      if (chunk.length > remaining) {
        bytes.add(chunk.sublist(0, remaining));
        received += remaining;
      } else {
        bytes.add(chunk);
        received += chunk.length;
      }
      onProgress?.call(received, total);
      if (received >= _dandanplayHashBytes) break;
    }
    if (received == 0) return null;
    return md5.convert(bytes.takeBytes()).toString();
  }

  static Future<String?> _generateFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final length = await file.length();
    if (length <= 0) return null;

    final end = length < _dandanplayHashBytes ? length : _dandanplayHashBytes;
    final digest = await md5.bind(file.openRead(0, end)).first;
    return digest.toString();
  }

  static (String?, String?) _splitUserInfo(String userInfo) {
    if (userInfo.isEmpty) return (null, null);
    final index = userInfo.indexOf(':');
    if (index < 0) return (_decodeUserInfo(userInfo), null);
    return (
      _decodeUserInfo(userInfo.substring(0, index)),
      _decodeUserInfo(userInfo.substring(index + 1)),
    );
  }

  static String? _decodeUserInfo(String value) {
    if (value.isEmpty) return null;
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  static String generateDandanplaySignature({
    required String appId,
    required String appSecret,
    required String path,
    required int timestamp,
  }) {
    final bytes = utf8.encode('$appId$timestamp$path$appSecret');
    final digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }
}
