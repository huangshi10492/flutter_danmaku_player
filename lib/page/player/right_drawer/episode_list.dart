import 'package:fldanplay/model/file_item.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class EpisodeListPanel extends StatefulWidget {
  final VideoPlayerService playerService;
  final void Function(int index) onEpisodeSelected;
  final VideoInfo videoInfo;

  const EpisodeListPanel({
    super.key,
    required this.playerService,
    required this.onEpisodeSelected,
    required this.videoInfo,
  });

  @override
  State<EpisodeListPanel> createState() => _EpisodeListPanelState();
}

class _EpisodeListPanelState extends State<EpisodeListPanel> {
  final GlobalKey _targetEpisodeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_targetEpisodeKey.currentContext != null) {
        Scrollable.ensureVisible(
          _targetEpisodeKey.currentContext!,
          alignment: 0.8,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildEpisodePanel(context);
  }

  Widget _buildEpisodePanel(BuildContext context) {
    switch (widget.videoInfo.historiesType) {
      case HistoriesType.streamMediaStorage:
        final streamMediaExplorerService = GetIt.I
            .get<StreamMediaExplorerService>();
        final historyService = GetIt.I.get<HistoryService>();
        final episodeList = streamMediaExplorerService.episodeList;

        if (episodeList.isEmpty) {
          return _buildEmptyPlaylistPlaceholder(context);
        }
        return SingleChildScrollView(
          child: FItemGroup(
            children: episodeList.asMap().entries.map<FItem>((e) {
              final episode = e.value;
              final history = historyService.getHistoryByPath(episode.id);
              final titleText = episode.indexNumber != null
                  ? '${episode.indexNumber}. ${episode.name}'
                  : episode.name;
              return FItem(
                key: e.key == widget.videoInfo.videoIndex
                    ? _targetEpisodeKey
                    : null,
                selected: e.key == widget.videoInfo.videoIndex,
                title: Text(titleText),
                subtitle: _buildHistorySubtitle(history, e.key),
                onPress: () {
                  widget.onEpisodeSelected(e.key);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      case HistoriesType.fileStorage:
        final fileExplorerService = GetIt.I.get<FileExplorerService>();
        return SignalBuilder(
          builder: (context) => fileExplorerService.files.value.map(
            data: (files) {
              if (files.isEmpty) {
                return _buildEmptyPlaylistPlaceholder(context);
              }
              return SingleChildScrollView(
                child: FItemGroup(children: _buildItems(files, context)),
              );
            },
            error: (error, stack) => const Center(child: Text('加载失败')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        );
      default:
        return const Center(child: Text('不支持的媒体库类型'));
    }
  }

  List<FItemMixin> _buildItems(List<FileItem> files, BuildContext context) {
    final widgetList = <FItemMixin>[];
    for (var file in files) {
      if (!file.isVideo) continue;
      widgetList.add(
        FItem(
          key: file.videoIndex == widget.videoInfo.videoIndex
              ? _targetEpisodeKey
              : null,
          title: Text(file.name, maxLines: 2),
          subtitle: _buildHistorySubtitle(file.history, file.videoIndex),
          onPress: () {
            widget.onEpisodeSelected(file.videoIndex);
            Navigator.pop(context);
          },
        ),
      );
    }
    return widgetList;
  }

  Widget _buildEmptyPlaylistPlaceholder(BuildContext context) {
    return Center(child: Text('播放列表为空', style: context.theme.typography.lg));
  }

  Widget _buildHistorySubtitle(History? history, int index) {
    if (widget.videoInfo.videoIndex == index) return const Text('正在播放');
    if (history == null) return const Text('未观看');
    return Text(
      '观看进度: ${Utils.formatTime(history.position, history.duration)}',
    );
  }
}
