import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class CryptoUtils {
  static const int _dandanplayHashBytes = 16 * 1024 * 1024;

  static String generateVideoUniqueKey(String input) {
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  static Future<String?> generateHash(
    String fileUrl,
    Map<String, String>? headers,
  ) async {
    final localHash = await _generateFileHash(fileUrl);
    if (localHash != null) return localHash;
    return _generateRemoteHash(fileUrl, headers: headers);
  }

  static Future<String?> _generateRemoteHash(
    String url, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
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
