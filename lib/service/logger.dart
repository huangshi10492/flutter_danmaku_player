import 'dart:io';
import 'package:fldanplay/service/configure.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

class LoggerService {
  late Directory _logDirectory;
  late File _currentLogFile;
  late Logger logger;
  static const int maxFileCount = 5;

  Future<void> initialize(ConfigureService cs) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _logDirectory = Directory(path.join(appDir.path, 'logs'));

      if (!await _logDirectory.exists()) {
        await _logDirectory.create(recursive: true);
      }

      _cleanOldLogs();
      createNewLogFile();

      logger = Logger(
        filter: _LevelFilter(cs.logLevel.value),
        printer: HybridPrinter(
          SimplePrinter(colors: false),
          error: PrettyPrinter(
            colors: false,
            printEmojis: false,
            lineLength: 20,
          ),
        ),
        output: MultiOutput([
          ConsoleOutput(),
          FileOutput(file: _currentLogFile),
        ]),
      );
    } catch (e) {
      debugPrint('Logger initialization failed: $e');
    }
  }

  File createNewLogFile() {
    final timestamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = '$timestamp.log';
    _currentLogFile = File(path.join(_logDirectory.path, fileName));
    return _currentLogFile;
  }

  Future<void> _cleanOldLogs() async {
    try {
      if (!await _logDirectory.exists()) return;

      final files = await _logDirectory.list().toList();
      final logFiles = files
          .where((f) => f is File && f.path.endsWith('.log'))
          .cast<File>()
          .toList();

      if (logFiles.length > maxFileCount) {
        // 按修改时间排序，删除最旧的文件
        logFiles.sort(
          (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
        );

        for (int i = 0; i < logFiles.length - maxFileCount; i++) {
          await logFiles[i].delete();
        }
      }
    } catch (e) {
      debugPrint('Failed to clean old logs: $e');
    }
  }

  Future<List<File>> getLogFiles() async {
    try {
      if (!await _logDirectory.exists()) return [];

      final files = await _logDirectory.list().toList();
      return files
          .where((f) => f is File && f.path.endsWith('.log'))
          .cast<File>()
          .toList();
    } catch (e) {
      debugPrint('Failed to get log files: $e');
      return [];
    }
  }

  static Future<LoggerService> register(ConfigureService cs) async {
    final loggerCore = LoggerService();
    await loggerCore.initialize(cs);
    GetIt.I.registerSingleton<LoggerService>(loggerCore);
    return loggerCore;
  }

  void debug(dynamic message) {
    logger.d(message);
  }

  void info(dynamic message) {
    logger.i(message);
  }

  void warning(dynamic message, [Object? error, StackTrace? stackTrace]) {
    logger.w(message, error: error, stackTrace: stackTrace);
  }

  void error(dynamic message, [Object? error, StackTrace? stackTrace]) {
    logger.e(message, error: error, stackTrace: stackTrace);
  }
}

class _LevelFilter extends LogFilter {
  int minLevel = 0;
  _LevelFilter(String levelString) {
    switch (levelString) {
      case '0':
        minLevel = 2000;
        break;
      case '1':
        minLevel = 3000;
        break;
      case '2':
        minLevel = 4000;
        break;
      case '3':
        minLevel = 5000;
        break;
    }
  }
  @override
  bool shouldLog(LogEvent event) {
    return event.level.value >= minLevel;
  }
}
