import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/player/danmaku.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/webdav_sync.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

class UpdateTimer {
  int _time = 1000;
  int _longTime = 10000;
  Function(Timer timer) updateFn;
  late Timer _timer;
  UpdateTimer(this.updateFn, {int time = 1000, int longTime = 10000}) {
    _time = time;
    _longTime = longTime;
  }
  void init() {
    _timer = Timer.periodic(Duration(milliseconds: _time), updateFn);
  }

  void changeTime({bool isLong = false}) {
    _timer.cancel();
    int time = isLong ? _longTime : _time;
    _timer = Timer.periodic(Duration(milliseconds: time), updateFn);
  }

  void dispose() {
    _timer.cancel();
  }
}

enum TimerType {
  // 历史记录
  history,
  // 弹幕状态更新
  danmaku,
}

/// 播放器状态
enum PlayerState {
  // 加载中
  loading,
  // 播放中
  playing,
  // 暂停
  paused,
  // 缓冲中
  buffering,
  // 错误状态
  error,
  // 已完成
  completed,
}

class VideoPlayerService {
  final VideoInfo videoInfo;

  final _historyService = GetIt.I<HistoryService>();
  final _globalService = GetIt.I<GlobalService>();
  final _configureService = GetIt.I<ConfigureService>();

  final _log = Logger('player');

  final Signal<PlayerState> playerState = Signal(PlayerState.loading);
  final Signal<Duration> position = Signal(Duration.zero);
  final Signal<Duration> bufferedPosition = Signal(Duration.zero);
  final Signal<double> playbackSpeed = Signal(1.0);
  final Signal<String?> errorMessage = Signal(null);
  final Signal<String> name = Signal('');
  final Signal<List<TrackInfo>> audioTracks = Signal([]);
  final Signal<List<TrackInfo>> subtitleTracks = Signal([]);
  final Signal<TrackInfo?> externalSubtitle = signal(null);
  final Signal<int> activeAudioTrack = Signal(0);
  final Signal<int> activeSubtitleTrack = Signal(0);
  final Signal<Map<int, String>> chapters = Signal({});

  late final Player _player;
  late final VideoController controller;
  late AudioSession _session;
  bool _playInterrupted = false;
  final _subscriptions = <StreamSubscription>[];
  Duration duration = Duration();
  late DanmakuService danmakuService;
  late History _history;
  StreamSubscription<PlayerLog>? playerLogSubscription;
  AudioParams? audioParams;
  VideoParams? videoParams;
  Media? media;
  String hwdec = '';

  // 定时器组
  late final Map<TimerType, UpdateTimer> _timerGroup = {
    TimerType.history: UpdateTimer((_) => updatePlaybackHistory(), time: 3000),
    TimerType.danmaku: UpdateTimer(
      (_) => danmakuService.updatePlayPosition(
        position.value,
        playbackSpeed.value,
      ),
      time: 100,
    ),
  };

  VideoPlayerService(this.videoInfo) {
    danmakuService = DanmakuService(videoInfo);
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize:
            pow(2, _configureService.playerMemory.value).round() * 1024 * 1024,
        logLevel: _configureService.playerDebugMode.value
            ? MPVLogLevel.debug
            : MPVLogLevel.error,
        libass: true,
      ),
    );
    controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration:
            _configureService.hardwareDecoderEnable.value,
        hwdec: _configureService.hardwareDecoder.value,
      ),
    );
    name.value = videoInfo.name;
  }

  Future<void> initialize() async {
    try {
      _log.info('initialize', '开始初始化视频播放器');
      _subscriptions.add(
        _player.stream.error.listen((e) {
          final ctx = _globalService.playerContext;
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx)
              ..removeCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('播放器发生错误: $e'),
                  action: SnackBarAction(
                    label: 'Dismiss',
                    onPressed: () {
                      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                    },
                  ),
                ),
              );
          }
          _log.error('mpv', '播放器发生错误', error: e);
        }),
      );
      await _setProperty();
      playerState.value = PlayerState.loading;
      errorMessage.value = null;
      setPlaybackSpeed(_configureService.defaultPlaySpeed.value);
      _history = await _historyService.startHistory(
        url: videoInfo.virtualVideoPath,
        headers: jsonEncode(videoInfo.headers),
        type: videoInfo.historiesType,
        storageKey: videoInfo.storageKey,
        name: videoInfo.name,
        subtitle: videoInfo.subtitle,
        fileName: videoInfo.videoName,
      );
      late Duration historyPosition;
      if (_history.position > 0 &&
          _history.duration - _history.position > 1000) {
        historyPosition = Duration(milliseconds: _history.position);
        final positionText = Utils.formatDuration(historyPosition);
        _globalService.showNotification('恢复到 $positionText');
        _log.info('initialize', '恢复播放历史: $positionText');
      } else {
        historyPosition = Duration.zero;
      }
      if (videoInfo.cached) {
        final cachePath =
            '${(await getApplicationSupportDirectory()).path}/offline_cache';
        media = Media(
          '$cachePath/${videoInfo.uniqueKey}',
          start: historyPosition,
        );
        _log.info('initialize', '加载缓存视频: $cachePath/${videoInfo.uniqueKey}');
      } else {
        media = Media(
          videoInfo.currentVideoPath,
          httpHeaders: videoInfo.headers,
          start: historyPosition,
        );
        _log.info('initialize', '加载视频: ${videoInfo.currentVideoPath}');
      }
      danmakuService.history = _history;
      danmakuService.init();
      playerLogSubscription = _player.stream.log.listen((event) {
        switch (event.level) {
          case 'info':
            _log.info('mpv', '${event.prefix}:${event.text}');
          case 'error':
            _log.error('mpv', '${event.prefix}:${event.text}');
          case 'warning':
            _log.warn('mpv', '${event.prefix}:${event.text}');
          default:
            _log.debug('mpv', '${event.prefix}:${event.text}');
        }
      });
      await _initSession();
      await _player.open(media!, play: true);
      playerState.value = PlayerState.playing;
      duration = await _player.stream.duration.firstWhere(
        (d) => d != Duration.zero,
      );
      _getChapter();
      _timerGroup.forEach((_, value) => value.init());
      _subscriptions.addAll([
        _player.stream.playing.listen(_onPlayingStateChanged),
        _player.stream.completed.listen(_onCompleted),
        _player.stream.buffering.listen(_onBufferingStateChanged),
        _player.stream.position.listen((p) => position.value = p),
        _player.stream.buffer.listen((b) => bufferedPosition.value = b),
      ]);
      await _loadTracks();
      audioParams = _player.state.audioParams;
      videoParams = _player.state.videoParams;
      hwdec = await (_player.platform! as NativePlayer).getProperty(
        'hwdec-current',
      );
      _log.info('initialize', '视频播放器初始化完成');
    } catch (e, stackTrace) {
      playerState.value = PlayerState.error;
      errorMessage.value = e.toString();
      _log.error('initialize', '视频播放器初始化失败', error: e, stackTrace: stackTrace);
    }
  }

  Future _getChapter() async {
    var pp = _player.platform as NativePlayer;
    final chapters = <int, String>{};
    try {
      final chapterListStr = await pp.getProperty(
        "chapter-list",
        waitForInitialization: true,
      );
      if (chapterListStr.isNotEmpty) {
        final List res = jsonDecode(chapterListStr);
        for (var chapter in res) {
          chapters[chapter['time'].round()] = chapter['title'];
        }
        this.chapters.value = chapters;
      }
    } catch (e, t) {
      _log.error('loadChapters', '加载章节信息失败', error: e, stackTrace: t);
    }
  }

  Future<void> _setProperty() async {
    var pp = _player.platform as NativePlayer;
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      await pp.setProperty(
        "ao",
        _configureService.audioTrack.value
            ? "audiotrack,opensles"
            : "opensles,audiotrack",
      );
    }
    final fontsDir = await getApplicationSupportDirectory();
    await pp.setProperty("sub-fonts-dir", '${fontsDir.path}/fonts');
    await pp.setProperty("sub-font", _configureService.subtitleFontName.value);
    if (Utils.isDesktop()) {
      final volume = _configureService.desktopVolume.value;
      final mpvVolume = (volume * 100).toInt();
      await pp.setProperty("volume", mpvVolume.toString());
      _log.info('_setProperty', '设置桌面端音量: $mpvVolume');
    }
  }

  Future<void> _initSession() async {
    _session = await AudioSession.instance;
    _session.configure(const AudioSessionConfiguration.music());
    _session.interruptionEventStream.listen((event) {
      final state = playerState.value;
      if (event.begin) {
        if (state != PlayerState.playing && state != PlayerState.paused) return;
        switch (event.type) {
          case AudioInterruptionType.duck:
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            _playInterrupted = true;
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            break;
          case AudioInterruptionType.pause:
            if (_playInterrupted) play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
        _playInterrupted = false;
      }
    });
    _session.becomingNoisyEventStream.listen((_) {
      if (playerState.value == PlayerState.playing) {
        pause();
      }
    });
  }

  /// 播放视频
  Future<void> play() async {
    _log.debug('play', '开始播放视频');
    await _player.play();
    _session.setActive(true);
  }

  /// 暂停视频
  Future<void> pause() async {
    _log.debug('pause', '暂停视频');
    await _player.pause();
    if (!_playInterrupted) _session.setActive(false);
  }

  /// 跳转到指定位置
  Future<void> seekTo(Duration position) async {
    _log.debug('seekTo', '跳转到指定位置');
    this.position.value = position;
    danmakuService.resetDanmakuPosition();
    await _player.seek(position);
  }

  /// 相对跳转
  void seekRelative(Duration offset) {
    final currentPosition = position.value;
    final newPosition = currentPosition + offset;
    if (newPosition < Duration.zero) {
      seekTo(Duration.zero);
      return;
    }
    seekTo(newPosition);
  }

  /// 设置播放速度
  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setRate(speed);
    playbackSpeed.value = speed;
    _globalService.speed = speed;
    danmakuService.updateSpeed();
  }

  /// 长按加速播放
  Future<void> doubleSpeed(bool isDouble) async {
    final currentSpeed = playbackSpeed.value;
    final newSpeed = isDouble
        ? _configureService.doublePlaySpeed.value *
              (_configureService.doubleWithNowSpeed.value ? currentSpeed : 1)
        : currentSpeed;
    await _player.setRate(newSpeed);
    _globalService.speed = newSpeed;
    danmakuService.updateSpeed();
  }

  Future<void> setVolume(double volume) async {
    if (!Utils.isDesktop()) return;

    volume = volume.clamp(0.0, 1.0);
    final mpvVolume = (volume * 100).toInt();
    try {
      final pp = _player.platform as NativePlayer;
      await pp.setProperty("volume", mpvVolume.toString());
      _log.debug('setVolume', '设置桌面端音量: $mpvVolume');
    } catch (e, t) {
      _log.error('setVolume', '设置音量失败', error: e, stackTrace: t);
    }
  }

  /// 切换播放/暂停
  Future<void> togglePlayPause() async {
    if (playerState.value == PlayerState.playing) {
      await pause();
    } else if (playerState.value == PlayerState.paused) {
      await play();
      danmakuService.syncWithVideo(true);
    }
  }

  void _onPlayingStateChanged(bool isPlaying) {
    if (_player.state.buffering) return;
    if (isPlaying) {
      _log.debug('_onPlayingStateChanged', '视频开始播放');
      playerState.value = PlayerState.playing;
      danmakuService.syncWithVideo(true);
      _timerGroup.forEach((_, value) => value.changeTime());
    } else {
      _log.debug('_onPlayingStateChanged', '视频暂停播放');
      playerState.value = PlayerState.paused;
      danmakuService.syncWithVideo(false);
      _timerGroup.forEach((_, value) => value.changeTime(isLong: true));
    }
  }

  void _onCompleted(bool isCompleted) {
    if (isCompleted) {
      _log.debug('_onCompleted', '视频播放完成');
      playerState.value = PlayerState.completed;
      danmakuService.syncWithVideo(false);
      _timerGroup.forEach((_, value) => value.changeTime(isLong: true));
    }
  }

  void _onBufferingStateChanged(bool isBuffering) {
    if (isBuffering) {
      _log.debug('_onBufferingStateChanged', '视频缓冲中');
      playerState.value = PlayerState.buffering;
      danmakuService.syncWithVideo(false);
    } else {
      _log.debug('_onBufferingStateChanged', '视频缓冲完成');
      playerState.value = _player.state.playing
          ? PlayerState.playing
          : PlayerState.paused;
      danmakuService.syncWithVideo(_player.state.playing);
    }
  }

  Future<void> updatePlaybackHistory() async {
    _historyService.updateProgress(
      position: position.value,
      duration: duration,
      history: _history,
    );
  }

  Future<void> saveSnapshot() async {
    try {
      if (_history.uniqueKey.isEmpty) {
        _log.warn('saveSnapshot', 'Cannot get video unique key');
        return;
      }
      final rawSnapshot = await _player.screenshot(format: 'image/jpeg');
      if (rawSnapshot == null) {
        _log.warn('saveSnapshot', 'Failed to take snapshot');
        return;
      }
      final image = img.decodeJpg(rawSnapshot);
      if (image == null) {
        return;
      }
      final thumbnail = img.copyResize(image, width: 300);
      final documentsDir = await getApplicationSupportDirectory();
      final dir = Directory('${documentsDir.path}/screenshots');
      await dir.create(recursive: true);
      await img.encodeJpgFile('${dir.path}/${_history.uniqueKey}', thumbnail);
    } catch (e, t) {
      _log.error('saveSnapshot', '快照保存异常', error: e, stackTrace: t);
    }
  }

  /// 恢复播放进度
  Future<Duration> restoreProgress() async {
    if (_history.position > 0) {
      final position = Duration(milliseconds: _history.position);
      await seekTo(position);
      return position;
    }
    return Duration.zero;
  }

  Future<void> dispose() async {
    pause();
    try {
      await updatePlaybackHistory();
      if (_globalService.updateListener != null) {
        _globalService.updateListener!(_history.uniqueKey);
      }
      GetIt.I.get<WebDAVSyncService>().syncHistories();
      await saveSnapshot();
      if (_globalService.updateListener != null) {
        _globalService.updateListener!(_history.uniqueKey);
      }
      _timerGroup.forEach((_, value) => value.dispose());
      for (final s in _subscriptions) {
        s.cancel();
      }
      _subscriptions.clear();
      playerLogSubscription?.cancel();
      await _player.dispose();
    } catch (e, t) {
      _log.error('dispose', '释放播放器资源失败', error: e, stackTrace: t);
    }
  }

  /// 加载所有轨道信息
  Future<void> _loadTracks() async {
    try {
      await loadAudioTracks();
      await loadSubtitleTracks();
    } catch (e, t) {
      _log.error('_loadTracks', '加载轨道信息失败', error: e, stackTrace: t);
    }
  }

  /// 获取音频轨道信息
  Future<void> loadAudioTracks() async {
    try {
      final audios = _player.state.tracks.audio;
      final tracks = <TrackInfo>[];
      for (var i = 0; i < audios.length; i++) {
        final audio = audios[i];
        tracks.add(
          TrackInfo(
            index: i,
            id: audio.id,
            language: audio.language ?? audio.id,
            title: audio.title ?? '',
          ),
        );
      }
      audioTracks.value = tracks;
      _log.info('loadAudioTracks', '加载音频轨道完成');
      if (_configureService.autoAudioLanguage.value) {
        final jpnTrack = tracks.indexWhere((t) => t.language.contains('jpn'));
        if (jpnTrack != -1) {
          await setActiveAudioTrack(jpnTrack);
        }
      }
      final activeTrack = _player.state.track.audio;
      final activeIndex = audios.indexWhere((t) => t.id == activeTrack.id);
      activeAudioTrack.value = activeIndex;
    } catch (e, t) {
      _log.error('loadAudioTracks', '获取音频轨道信息失败', error: e, stackTrace: t);
      audioTracks.value = [];
    }
  }

  /// 设置活动音频轨道
  Future<void> setActiveAudioTrack(int trackIndex) async {
    final tracks = audioTracks.value;
    if (trackIndex < 0 || trackIndex >= tracks.length) {
      throw AppException('无效的音频轨道索引: $trackIndex', null);
    }
    try {
      await _player.setAudioTrack(_player.state.tracks.audio[trackIndex]);
      activeAudioTrack.value = trackIndex;
      final track = tracks[trackIndex];
      _log.info('setActiveAudioTrack', '切换音频轨道成功 - ${track.title}');
    } catch (e, t) {
      _log.error('setActiveAudioTrack', '切换音频轨道失败', error: e, stackTrace: t);
    }
  }

  /// 获取字幕轨道信息
  Future<void> loadSubtitleTracks() async {
    try {
      final subtitles = _player.state.tracks.subtitle;
      var tracks = <TrackInfo>[];
      for (var i = 0; i < subtitles.length; i++) {
        final sub = subtitles[i];
        tracks.add(
          TrackInfo(
            index: i,
            id: sub.id,
            language: sub.language ?? sub.id,
            title: sub.title ?? '',
          ),
        );
      }
      subtitleTracks.value = tracks;
      _log.info('loadSubtitleTracks', '加载了 ${tracks.length} 个字幕轨道');
      if (_configureService.autoLanguage.value != 0) {
        final lan = _configureService.autoLanguage.value == 1
            ? 'Simplified'
            : 'Traditional';
        final chiTrack = tracks.indexWhere((t) => t.title.contains(lan));
        if (chiTrack != -1) {
          await setActiveSubtitleTrack(chiTrack);
        }
      }
      final activeTrack = _player.state.track.subtitle;
      final activeIndex = subtitles.indexWhere((t) => t.id == activeTrack.id);
      activeSubtitleTrack.value = activeIndex;
    } catch (e, t) {
      _log.error('loadSubtitleTracks', '获取字幕轨道信息失败', error: e, stackTrace: t);
      subtitleTracks.value = [];
    }
  }

  /// 设置活动字幕轨道
  Future<void> setActiveSubtitleTrack(int trackIndex) async {
    try {
      final tracks = subtitleTracks.value;
      if (trackIndex < 0 || trackIndex >= tracks.length) {
        throw AppException('无效的字幕轨道索引: $trackIndex', null);
      }
      await _player.setSubtitleTrack(_player.state.tracks.subtitle[trackIndex]);
      activeSubtitleTrack.value = trackIndex;
      final track = tracks[trackIndex];
      _log.info('setActiveSubtitleTrack', '切换字幕轨道成功 - ${track.title}');
    } catch (e) {
      _log.error('setActiveSubtitleTrack', '切换字幕轨道失败', error: e);
    }
  }

  /// 加载外部字幕 TODO
  Future<void> loadExternalSubtitle(String filePath) async {
    try {
      await _player.setSubtitleTrack(SubtitleTrack.uri(filePath));
      final fileName = filePath.split('/').last;
      final externalTrack = TrackInfo(
        index: -1,
        id: 'external',
        language: '',
        title: fileName,
      );
      externalSubtitle.value = externalTrack;
      activeSubtitleTrack.value = subtitleTracks.value.length;
      subtitleTracks.value = [...subtitleTracks.value, externalTrack];
      _log.info('loadExternalSubtitle', '加载外部字幕成功 - $fileName');
    } catch (e, t) {
      _log.error('loadExternalSubtitle', '加载外部字幕失败', error: e, stackTrace: t);
    }
  }

  /// 移除外部字幕
  Future<void> removeExternalSubtitle() async {
    await setActiveSubtitleTrack(-1);
    externalSubtitle.value = null;
    subtitleTracks.value = subtitleTracks.value
        .where((t) => t.index != -1)
        .toList();
  }
}
