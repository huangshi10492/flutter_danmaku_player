import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/page/player/right_drawer/danmaku_info.dart';
import 'package:fldanplay/page/player/right_drawer/danmaku_filter.dart';
import 'package:fldanplay/page/player/right_drawer/episode_list.dart';
import 'package:fldanplay/page/player/right_drawer/track_page.dart';
import 'package:fldanplay/page/player/right_drawer/danmaku_search_page.dart';
import 'package:fldanplay/page/player/right_drawer/danmaku_settings.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/utils/icon.dart';
import 'package:fldanplay/utils/theme.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/danmaku_keyword_filter.dart';
import 'package:fldanplay/widget/settings/radio_settings_section.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

enum RightDrawerType {
  danmakuActions,
  danmakuInfo,
  danmakuSearch,
  danmakuSettings,
  danmakuFilter,
  episode,
  speed,
  audioTrack,
  subtitleTrack,
  metadata,
  playerUI,
  danmakuKeywordFilter,
  superResolution,
}

class RightDrawerContent extends StatelessWidget {
  RightDrawerContent({
    super.key,
    required this.drawerType,
    required this.playerService,
    required this.onEpisodeSelected,
    required this.onDrawerChanged,
    required this.videoInfo,
  });

  final RightDrawerType drawerType;
  final VideoPlayerService playerService;
  final void Function(int index) onEpisodeSelected;
  final void Function(RightDrawerType newType) onDrawerChanged;
  final VideoInfo videoInfo;
  final _globalService = GetIt.I.get<GlobalService>();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: context.theme.colors.background),
      width: 320,
      height: MediaQuery.of(context).size.height,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (drawerType) {
      case RightDrawerType.speed:
        return _buildSpeedSettings(context);
      case RightDrawerType.danmakuActions:
        return _buildDanmakuActions(context);
      case RightDrawerType.danmakuInfo:
        return DanmakuInfoPanel(
          danmakuService: playerService.danmakuService,
          playerService: playerService,
          onDrawerChanged: onDrawerChanged,
        );
      case RightDrawerType.danmakuSearch:
        return _buildDanmakuSearch(context);
      case RightDrawerType.danmakuSettings:
        return DanmakuSettingsPanel(
          danmakuService: playerService.danmakuService,
        );
      case RightDrawerType.danmakuFilter:
        return DanmakuFilterPanel(
          danmakuService: playerService.danmakuService,
          onDrawerChanged: onDrawerChanged,
        );
      case RightDrawerType.episode:
        return EpisodeListPanel(
          playerService: playerService,
          onEpisodeSelected: onEpisodeSelected,
          videoInfo: videoInfo,
        );
      case RightDrawerType.audioTrack:
        return TrackPage(playerService: playerService, isAudio: true);
      case RightDrawerType.subtitleTrack:
        return TrackPage(playerService: playerService, isAudio: false);
      case RightDrawerType.metadata:
        return _buildMetadataPanel(context);
      case RightDrawerType.playerUI:
        return _buildPlayerUI(context);
      case .danmakuKeywordFilter:
        return Scaffold(
          body: Padding(
            padding: const .all(4),
            child: SingleChildScrollView(child: DanmakuKeywordFilter()),
          ),
        );
      case .superResolution:
        return _buildSuperResolution(context);
    }
  }

  Widget _buildSpeedSettings(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          child: SignalBuilder(
            builder: (context) {
              final speed = playerService.playbackSpeed.value;
              final configure = GetIt.I.get<ConfigureService>();
              final doubleSpeed = configure.doublePlaySpeed.value;
              return SettingsSection(
                children: [
                  SettingsTile.sliderTile(
                    title: '当前播放速度',
                    details: '${speed.toStringAsFixed(2)}X',
                    silderValue: Utils.speedToSlider(speed),
                    silderMin: 1,
                    silderMax: 28,
                    silderDivisions: 27,
                    onSilderChange: (value) {
                      playerService.setPlaybackSpeed(
                        Utils.sliderToSpeed(value),
                      );
                    },
                  ),
                  SettingsTile.sliderTile(
                    title: '长按加速播放速度',
                    details: '${doubleSpeed.toStringAsFixed(2)}X',
                    silderValue: doubleSpeed,
                    silderMin: 1,
                    silderMax: 8,
                    silderDivisions: 28,
                    onSilderChange: (value) {
                      configure.doublePlaySpeed.value = value;
                    },
                  ),
                  SettingsTile.switchTile(
                    title: '跟随当前速度加速',
                    onBoolChange: (value) {
                      configure.doubleWithNowSpeed.value = value;
                    },
                    switchValue: configure.doubleWithNowSpeed.value,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDanmakuActions(BuildContext context) {
    final configure = GetIt.I.get<ConfigureService>();
    return FItemGroup(
      style: settingsItemGroupStyle,
      children: [
        if (configure.danmakuServiceEnable.value) ...[
          FItem(
            prefix: const Icon(MyIcon.danmaku, size: 20),
            title: Text('弹幕信息'),
            onPress: () => onDrawerChanged(.danmakuInfo),
          ),
          FItem(
            prefix: const Icon(FLucideIcons.palette, size: 20),
            title: Text('弹幕外观'),
            onPress: () => onDrawerChanged(.danmakuSettings),
          ),
          FItem(
            prefix: const Icon(FLucideIcons.funnel, size: 20),
            title: Text('弹幕过滤与延迟'),
            onPress: () => onDrawerChanged(.danmakuFilter),
          ),
        ],
        FItem(
          prefix: const Icon(Icons.audiotrack_outlined, size: 20),
          title: Text('音频选择'),
          onPress: () => onDrawerChanged(.audioTrack),
        ),
        FItem(
          prefix: const Icon(FLucideIcons.closedCaption, size: 20),
          title: Text('字幕选择'),
          onPress: () => onDrawerChanged(.subtitleTrack),
        ),
        FItem(
          prefix: const Icon(FLucideIcons.wrench, size: 20),
          title: Text('播放器显示设置'),
          onPress: () => onDrawerChanged(.playerUI),
        ),
        FItem(
          prefix: const Icon(FLucideIcons.hd, size: 20),
          title: Text('超分辨率'),
          onPress: () => onDrawerChanged(.superResolution),
        ),
        FItem(
          prefix: const Icon(FLucideIcons.info, size: 20),
          title: Text('播放信息'),
          onPress: () => onDrawerChanged(.metadata),
        ),
      ],
    );
  }

  Widget _buildDanmakuSearch(BuildContext context) {
    return DanmakuSearchPage(
      searchEpisodes: (name, url) async {
        return playerService.danmakuService.searchEpisodes(name, url);
      },
      onEpisodeSelected: (episode) {
        Navigator.pop(context); // 关闭 sheet
        _globalService.showNotification('正在加载指定弹幕...');
        playerService.danmakuService.selectEpisodeAndLoadDanmaku(
          videoInfo.uniqueKey,
          episode,
        );
      },
    );
  }

  Widget _buildMetadataPanel(BuildContext context) {
    return FutureBuilder(
      future: playerService.getMetadata(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('加载失败'));
        }
        final data = snapshot.data!;
        final style = context.theme.typography.body.xl;
        return ListView(
          children: [
            Text('视频来源', style: style),
            const SizedBox(height: 8),
            SelectableText(data.media),
            const SizedBox(height: 16),
            Text('硬件解码器', style: style),
            const SizedBox(height: 8),
            SelectableText(data.hwdec),
            const SizedBox(height: 16),
            Text('视频输出', style: style),
            const SizedBox(height: 8),
            SelectableText(data.videoOutput),
            const SizedBox(height: 16),
            Text('视频信息', style: style),
            const SizedBox(height: 8),
            SelectableText(data.videoParams),
            const SizedBox(height: 16),
            Text('音频信息', style: style),
            const SizedBox(height: 8),
            SelectableText(data.audioParams),
          ],
        );
      },
    );
  }

  Widget _buildPlayerUI(BuildContext context) {
    return Scaffold(
      body: SignalBuilder(
        builder: (context) {
          final configure = GetIt.I.get<ConfigureService>();
          return ListView(
            padding: const EdgeInsets.all(4),
            children: [
              SettingsSection(
                title: '控制栏显示',
                children: [
                  SettingsTile.switchTile(
                    title: '显示章节',
                    switchValue: configure.showChapter.value,
                    onBoolChange: (value) {
                      configure.showChapter.value = value;
                    },
                  ),
                  SettingsTile.switchTile(
                    title: '显示弹幕趋势',
                    switchValue: configure.showDanmakuTrend.value,
                    onBoolChange: (value) {
                      configure.showDanmakuTrend.value = value;
                    },
                  ),
                  SettingsTile.switchTile(
                    title: '始终显示进度条',
                    switchValue: configure.alwaysShowProgressBar.value,
                    onBoolChange: (value) {
                      configure.alwaysShowProgressBar.value = value;
                    },
                  ),
                ],
              ),
              SettingsSectionTitle('下一章节按钮显示模式'),
              RadioSettingsSection(
                showOnlySubtitle: true,
                options: {'0': '优先显示章节跳转', '1': '只显示时间跳转', '2': '同时显示章节和时间跳转'},
                value: configure.jumpButtonMode.value.toString(),
                onChange: (value) {
                  configure.jumpButtonMode.value = int.parse(value);
                },
              ),
              StatefulBuilder(
                builder: (context, setState) {
                  final configure = GetIt.I.get<ConfigureService>();
                  final settings = configure.subtitleSettings.value;
                  return SettingsSection(
                    title: '字幕设置',
                    children: [
                      SettingsTile.sliderTile(
                        title: '字体大小',
                        onSilderChange: (value) {
                          setState(() => settings.fontSize = value.round());
                        },
                        onSilderEnd: (value) {
                          configure.subtitleSettings.value = configure
                              .subtitleSettings
                              .value
                              .copyWith(fontSize: value.round());
                        },
                        details: settings.fontSize.round().toString(),
                        silderValue: settings.fontSize.toDouble(),
                        silderDivisions: 20,
                        silderMin: 30,
                        silderMax: 70,
                      ),
                      SettingsTile.sliderTile(
                        title: '显示位置',
                        onSilderChange: (value) {
                          setState(() => settings.marginY = value.round());
                        },
                        onSilderEnd: (value) {
                          configure.subtitleSettings.value = configure
                              .subtitleSettings
                              .value
                              .copyWith(marginY: value.round());
                        },
                        details: settings.marginY.round().toString(),
                        silderValue: settings.marginY.toDouble(),
                        silderDivisions: 20,
                        silderMin: 10,
                        silderMax: 50,
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuperResolution(BuildContext context) {
    final configure = GetIt.I.get<ConfigureService>();
    final type = Signal(playerService.superResolutionType);
    return Scaffold(
      body: Padding(
        padding: const .all(4),
        child: ListView(
          children: [
            const SizedBox(height: 4),
            SignalBuilder(
              builder: (context) {
                return RadioSettingsSection(
                  showOnlySubtitle: true,
                  options: const {
                    '0': '关闭',
                    '1': 'Mode A (HQ)',
                    '2': 'Mode A (Fast)',
                    '3': 'Mode B (HQ)',
                    '4': 'Mode B (Fast)',
                  },
                  value: type.value.toString(),
                  onChange: (value) {
                    type.value = int.parse(value);
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            FButton(
              variant: .secondary,
              onPress: () {
                playerService.superResolutionType = type.value;
                playerService.setSuperResolution();
              },
              child: Text('仅本次有效'),
            ),
            const SizedBox(height: 8),
            FButton(
              variant: .secondary,
              onPress: () {
                playerService.superResolutionType = type.value;
                configure.superResolutionType.value = type.value;
                playerService.setSuperResolution();
              },
              child: Text('保存为默认设置'),
            ),
          ],
        ),
      ),
    );
  }
}
