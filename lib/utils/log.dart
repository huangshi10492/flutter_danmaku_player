import 'package:dio/dio.dart';
import 'package:fldanplay/service/logger.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

class AppException implements Exception {
  String message;

  AppException(this.message, Object? e) {
    if (e is AppException) {
      message = e.message;
    }
  }
  @override
  String toString() {
    return message;
  }
}

class Logger {
  final String module;
  late LoggerService _loggerService;

  Logger(this.module) {
    _loggerService = GetIt.I<LoggerService>();
  }

  void debug(String function, String message) {
    final time = DateFormat('HH:mm:ss').format(DateTime.now());
    final formattedMessage = '$time [$module.$function] $message';
    _loggerService.debug(formattedMessage);
  }

  void info(String function, String message) {
    final time = DateFormat('HH:mm:ss').format(DateTime.now());
    final formattedMessage = '$time [$module.$function] $message';
    _loggerService.info(formattedMessage);
  }

  void warn(
    String function,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final time = DateFormat('HH:mm:ss').format(DateTime.now());
    final formattedMessage = '$time [$module.$function] $message';
    _loggerService.warning(formattedMessage, error, stackTrace);
  }

  void error(
    String function,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (error is AppException) {
      return;
    }
    final time = DateFormat('HH:mm:ss').format(DateTime.now());
    final formattedMessage = '$time [$module.$function] $message';
    _loggerService.error(formattedMessage, error, stackTrace);
  }

  static String buildMessage(DioException error, {String? action}) {
    final base = _baseMessage(error);
    if (action == null || action.isEmpty) {
      return base;
    }
    if (base.isEmpty) {
      return '$action失败';
    }
    return '$action失败：$base';
  }

  static String _baseMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case .transformTimeout:
        return '网络连接超时，请检查网络';
      case DioExceptionType.badCertificate:
        return '证书错误，无法建立安全连接';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == null) {
          return '服务器返回错误响应';
        }
        if (statusCode >= 500) {
          return '服务器内部错误';
        }
        if (statusCode == 401) {
          return '登录凭证无效';
        }
        return '服务器返回错误 (HTTP $statusCode)';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请检查网络';
      case DioExceptionType.unknown:
        final msg = error.message;
        if (msg != null && msg.isNotEmpty) {
          return msg;
        }
        return '发生未知网络错误';
    }
  }

  Never dio(
    String function,
    DioException error,
    StackTrace stackTrace, {
    String? action,
  }) {
    final message = buildMessage(error, action: action);
    this.error(function, message, error: error, stackTrace: stackTrace);
    throw AppException(message, error);
  }

  Never webdav(
    String function,
    WebdavException error,
    StackTrace stackTrace, {
    String? action,
  }) {
    final message = 'WebDAV错误(${error.statusCode}): ${error.message}';
    this.error(function, message, error: error, stackTrace: stackTrace);
    throw AppException(message, error);
  }
}
