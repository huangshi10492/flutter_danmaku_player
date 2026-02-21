import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/utils/video_player_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class TrackPage extends StatelessWidget {
  final VideoPlayerService playerService;
  final bool isAudio;
  const TrackPage({
    super.key,
    required this.playerService,
    required this.isAudio,
  });

  Future<void> _pickExternalSubtitle(BuildContext context) async {
    final globalService = GetIt.I.get<GlobalService>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt', 'sub', 'idx'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        await playerService.loadExternalSubtitle(filePath);
        globalService.showNotification('外部字幕加载成功');
      }
    } catch (e) {
      globalService.showNotification('加载外部字幕失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Watch((context) {
            final tracks = isAudio
                ? playerService.audioTracks.value
                : playerService.subtitleTracks.value;
            final activeTrack = isAudio
                ? playerService.activeAudioTrack.value
                : playerService.activeSubtitleTrack.value;
            return FSelectTileGroup<int>(
              control: .lifted(
                value: {activeTrack},
                onChange: (value) {
                  if (isAudio) {
                    playerService.setActiveAudioTrack(value.first);
                  } else {
                    playerService.setActiveSubtitleTrack(value.first);
                  }
                  context.pop();
                },
              ),
              children: tracks.map((track) {
                final name = VideoPlayerUtils.trackNameTranslation(
                  track.id,
                  track.title,
                  track.language,
                );
                return FSelectTile(title: Text(name), value: track.index);
              }).toList(),
            );
          }),
          isAudio
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickExternalSubtitle(context),
                      icon: const Icon(Icons.file_upload),
                      label: const Text('导入外部字幕'),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
