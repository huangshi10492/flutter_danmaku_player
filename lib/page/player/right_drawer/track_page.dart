import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/video_player_utils.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class TrackPage extends StatelessWidget {
  final VideoPlayerService playerService;
  final bool isAudio;
  final void Function() onStreamReload;
  TrackPage({
    super.key,
    required this.playerService,
    required this.isAudio,
    required this.onStreamReload,
  });
  final _globalService = GetIt.I.get<GlobalService>();
  final _explorer = GetIt.I.get<StreamMediaExplorerService>();
  final _configure = GetIt.I.get<ConfigureService>();

  Future<void> _pickExternalSubtitle(BuildContext context) async {
    try {
      final result = await FilePicker.pickFile(
        type: .custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt', 'sub', 'idx'],
      );
      if (result != null && result.path != null) {
        final filePath = result.path!;
        await playerService.loadExternalSubtitle(filePath);
        _globalService.showNotification('外部字幕加载成功');
        if (context.mounted) context.pop();
      }
    } catch (e) {
      _globalService.showNotification('加载外部字幕失败');
    }
  }

  Widget _buildServerStreamSection(BuildContext context) {
    if (_explorer.tranOpt.isOriginal) return SizedBox.shrink();
    final streams = isAudio
        ? _explorer.audioStreams
        : _explorer.subtitleStreams;
    if (streams.isEmpty) return const SizedBox.shrink();
    final active =
        (isAudio
            ? _explorer.tranOpt.audioStreamIndex
            : _explorer.tranOpt.subtitleStreamIndex) ??
        -1;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingsSectionTitle('服务端流'),
        FSelectTileGroup<int>(
          control: .managedRadio(
            initial: active,
            onChange: (value) {
              if (isAudio) {
                _explorer.tranOpt.audioStreamIndex = value.first;
                if (context.mounted) context.pop();
                onStreamReload();
                return;
              }
              _explorer.tranOpt.subtitleStreamIndex = value.first;
              if (context.mounted) context.pop();
              if (_configure.transEmbedSub.value) {
                onStreamReload();
                return;
              }
              playerService.addServerSubtitle(
                .findByIndex(_explorer.subtitleStreams, value.first),
              );
            },
          ),
          children: [
            for (final stream in streams)
              FSelectTile(
                title: Text(stream.label),
                subtitle: Text(stream.language ?? ''),
                value: stream.index,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerTrackSection(BuildContext context) {
    final tracks = isAudio
        ? playerService.audioTracks
        : playerService.subtitleTracks;
    if (tracks.isEmpty) return const SizedBox.shrink();
    final active = isAudio
        ? playerService.activeAudioTrack
        : playerService.activeSubtitleTrack;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const SettingsSectionTitle('播放器轨道'),
        FSelectTileGroup<int>(
          control: .managedRadio(
            initial: active,
            onChange: (value) {
              if (isAudio) {
                playerService.setActiveAudioTrack(value.first);
              } else {
                playerService.setActiveSubtitleTrack(value.first);
              }
              context.pop();
            },
          ),
          children: [
            for (final track in tracks)
              FSelectTile(
                title: Text(
                  VideoPlayerUtils.subtitleTitleTranslation(
                        track.id,
                        track.title,
                      ) ??
                      VideoPlayerUtils.subtitleLanguageTranslation(
                        track.language,
                      ),
                ),
                subtitle: Text(
                  VideoPlayerUtils.subtitleLanguageTranslation(track.language),
                ),
                value: track.index,
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildServerStreamSection(context),
        _buildPlayerTrackSection(context),
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
    );
  }
}
