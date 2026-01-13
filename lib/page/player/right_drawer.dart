import 'package:fldanplay/model/file_item.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/page/player/danmaku_info.dart';
import 'package:fldanplay/page/player/danmaku_filter.dart';
import 'package:fldanplay/page/player/track_page.dart';
import 'package:fldanplay/page/player/danmaku_search_page.dart';
import 'package:fldanplay/page/player/danmaku_settings.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/icon.dart';
import 'package:fldanplay/utils/utils.dart';
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
      width: 300,
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
        return DanmakuFilterPanel(danmakuService: playerService.danmakuService);
      case RightDrawerType.episode:
        return _buildEpisodePanel(context);
      case RightDrawerType.audioTrack:
        return TrackPage(playerService: playerService, isAudio: true);
      case RightDrawerType.subtitleTrack:
        return TrackPage(playerService: playerService, isAudio: false);
      case RightDrawerType.metadata:
        return _buildMetadataPanel(context);
    }
  }

  Widget _buildSpeedSettings(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          child: Watch((context) {
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
                    playerService.setPlaybackSpeed(Utils.sliderToSpeed(value));
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
          }),
        ),
      ),
    );
  }

  Widget _buildDanmakuActions(BuildContext context) {
    return Column(
      children: [
        Watch((context) {
          final configure = GetIt.I.get<ConfigureService>();
          return FItemGroup(
            children: [
              if (configure.danmakuServiceEnable.value) ...[
                FItem(
                  prefix: const Icon(MyIcon.danmaku, size: 20),
                  title: Text('弹幕信息', style: context.theme.typography.base),
                  onPress: () => onDrawerChanged(RightDrawerType.danmakuInfo),
                ),
                FItem(
                  prefix: const Icon(FIcons.palette, size: 20),
                  title: Text('弹幕外观', style: context.theme.typography.base),
                  onPress: () =>
                      onDrawerChanged(RightDrawerType.danmakuSettings),
                ),
                FItem(
                  prefix: const Icon(FIcons.funnel, size: 20),
                  title: Text('弹幕过滤与延迟', style: context.theme.typography.base),
                  onPress: () => onDrawerChanged(RightDrawerType.danmakuFilter),
                ),
              ],
              FItem(
                prefix: const Icon(Icons.audiotrack_outlined, size: 20),
                title: Text('音频选择', style: context.theme.typography.base),
                onPress: () => onDrawerChanged(RightDrawerType.audioTrack),
              ),
              FItem(
                prefix: const Icon(FIcons.closedCaption, size: 20),
                title: Text('字幕选择', style: context.theme.typography.base),
                onPress: () => onDrawerChanged(RightDrawerType.subtitleTrack),
              ),
              FItem(
                prefix: const Icon(FIcons.info, size: 20),
                title: Text('播放信息', style: context.theme.typography.base),
                onPress: () => onDrawerChanged(RightDrawerType.metadata),
              ),
            ],
          );
        }),
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

  Widget _buildHistorySubtitle(History? history, int index) {
    if (videoInfo.videoIndex == index) {
      return const Row(
        children: [Icon(Icons.play_arrow, size: 16), Text('正在播放')],
      );
    }
    if (history == null) return const Text('未观看');
    return Text(
      '观看进度: ${Utils.formatTime(history.position, history.duration)}',
    );
  }

  List<FItemMixin> _buildItems(List<FileItem> files, BuildContext context) {
    final widgetList = <FItemMixin>[];
    for (var file in files) {
      if (!file.isVideo) continue;
      widgetList.add(
        FItem(
          title: Text(file.name, maxLines: 2),
          subtitle: _buildHistorySubtitle(file.history, file.videoIndex),
          onPress: () => {
            onEpisodeSelected(file.videoIndex),
            Navigator.pop(context),
          },
        ),
      );
    }
    return widgetList;
  }

  Widget _buildEmptyPlaylistPlaceholder(BuildContext context) {
    return Center(child: Text('播放列表为空', style: context.theme.typography.lg));
  }

  Widget _buildEpisodePanel(BuildContext context) {
    switch (videoInfo.historiesType) {
      case HistoriesType.streamMediaStorage:
        final streamMediaExplorerService = GetIt.I
            .get<StreamMediaExplorerService>();
        final historyService = GetIt.I.get<HistoryService>();
        final episodeList = streamMediaExplorerService.episodeList;
        if (episodeList.isEmpty) {
          return _buildEmptyPlaylistPlaceholder(context);
        }
        return FItemGroup(
          children: episodeList.asMap().entries.map<FItem>((e) {
            final episode = e.value;
            final history = historyService.getHistoryByPath(episode.id);
            final titleText = episode.indexNumber != null
                ? '${episode.indexNumber}. ${episode.name}'
                : episode.name;
            return FItem(
              title: Text(titleText),
              subtitle: _buildHistorySubtitle(history, e.key),
              onPress: () => {onEpisodeSelected(e.key), Navigator.pop(context)},
            );
          }).toList(),
        );
      case HistoriesType.fileStorage:
        final fileExplorerService = GetIt.I.get<FileExplorerService>();
        return Watch(
          (context) => fileExplorerService.files.value.map(
            data: (files) {
              if (files.isEmpty) {
                return _buildEmptyPlaylistPlaceholder(context);
              }
              return FItemGroup(children: _buildItems(files, context));
            },
            error: (error, stack) => const Center(child: Text('加载失败')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        );
      default:
        return const Center(child: Text('不支持的媒体库类型'));
    }
  }

  Widget _buildMetadataPanel(BuildContext context) {
    return ListView(
      children: [
        Text('视频来源', style: context.theme.typography.xl),
        const SizedBox(height: 8),
        SelectableText(playerService.media.toString()),
        const SizedBox(height: 16),
        Text('硬件解码器', style: context.theme.typography.xl),
        const SizedBox(height: 8),
        SelectableText(playerService.hwdec),
        const SizedBox(height: 16),
        Text('视频信息', style: context.theme.typography.xl),
        const SizedBox(height: 8),
        SelectableText(playerService.videoParams.toString()),
        const SizedBox(height: 16),
        Text('音频信息', style: context.theme.typography.xl),
        const SizedBox(height: 8),
        SelectableText(playerService.audioParams.toString()),
      ],
    );
  }
}
