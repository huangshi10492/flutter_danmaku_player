import 'dart:io';
import 'package:fldanplay/widget/settings/settings_scaffold.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:fldanplay/service/logger.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  late LoggerService _loggerService;
  late ConfigureService _configureService;

  @override
  void initState() {
    super.initState();
    _loggerService = GetIt.I.get<LoggerService>();
    _configureService = GetIt.I.get<ConfigureService>();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '日志设置',
      child: Column(
        children: [
          SettingsSection(
            children: [
              Watch((context) {
                return SettingsTile.radioTile(
                  title: '日志级别',
                  radioValue: _configureService.logLevel.value,
                  onRadioChange: (value) {
                    _configureService.logLevel.value = value;
                  },
                  radioOptions: {
                    'DEBUG': '0',
                    'INFO': '1',
                    'WARNING': '2',
                    'ERROR': '3',
                  },
                );
              }),
            ],
          ),
          FutureBuilder<List<File>>(
            future: _loggerService.getLogFiles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox();
              }
              if (snapshot.hasError) {
                return const SizedBox();
              }
              final logFiles = snapshot.data ?? [];
              if (logFiles.isEmpty) {
                return SettingsSection(
                  title: '日志文件',
                  children: [SettingsTile.simpleTile(title: '暂无日志文件')],
                );
              }
              logFiles.sort(
                (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
              );
              return SettingsSection(
                title: '日志文件',
                children: logFiles.map((file) {
                  final fileName = file.uri.pathSegments.last;
                  return SettingsTile.navigationTile(
                    title: fileName,
                    onPress: () =>
                        context.push('/settings/log/view?file=${file.path}'),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
