import 'dart:async';
import 'dart:io';

import 'package:canvas_danmaku/danmaku_controller.dart';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:fldanplay/model/danmaku.dart';
import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/utils/danmaku_api_utils.dart';
import 'package:fldanplay/utils/log.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

enum DanmakuStatus {
  none('无弹幕', 2),
  matching('匹配中', 1),
  downloading('下载中', 1),
  failed('加载失败', 2),
  fromCached('从缓存加载', 0),
  fromApi('从API加载', 0),
  fromLocal('从本地加载', 0);

  final String label;
  final int level; // 0: success, 1: loading, 2: error
  const DanmakuStatus(this.label, this.level);
}

class DanmakuService {
  late DanmakuController controller;
  final VideoInfo videoInfo;

  DanmakuService(this.videoInfo);

  ConfigureService configureService = GetIt.I.get<ConfigureService>();
  GlobalService globalService = GetIt.I.get<GlobalService>();
  final DanmakuGetter danmakuGetter = DanmakuGetter();

  final _log = Logger('DanmakuService');
  Map<int, List<Danmaku>> _bili = {};
  Map<int, List<Danmaku>> _gamer = {};
  Map<int, List<Danmaku>> _dandan = {};
  Map<int, List<Danmaku>> _other = {};
  final Signal<DanmakuSettings> danmakuSettings = Signal(DanmakuSettings());
  final Signal<bool> danmakuEnabled = Signal(true);
  final Signal<Episode> episode = Signal(Episode.fromId(0, 0, ''));
  final Signal<DanmakuStatus> status = Signal(.none);
  late History history;
  int lastTime = 0;
  String cacheDir = "";
  late bool danmakuServiceEnable = configureService.danmakuServiceEnable.value;

  Future<void> init() async {
    final documentsDir = await getApplicationSupportDirectory();
    cacheDir = Directory('${documentsDir.path}/danmaku').path;
    danmakuEnabled.value = configureService.defaultDanmakuEnable.value;
    final sittings = configureService.getDanmakuSettings();
    danmakuSettings.value = sittings;
    controller.updateOption(sittings.toDanmakuOption());
    globalService.videoName = videoInfo.videoName;
    loadDanmaku();
  }

  void syncWithVideo(bool isPlaying) {
    if (isPlaying) {
      controller.resume();
    } else {
      controller.pause();
    }
  }

  void _clear() {
    controller.clear();
    _bili = {};
    _gamer = {};
    _dandan = {};
    _other = {};
  }

  void resetDanmakuPosition() {
    controller.clear();
    lastTime = 0;
  }

  void updateSpeed() {
    if (danmakuSettings.value.speedSync) {
      controller.updateOption(
        danmakuSettings.value
            .copyWith(
              duration: danmakuSettings.value.duration / globalService.speed,
            )
            .toDanmakuOption(),
      );
    }
  }

  /// 根据当前播放位置更新弹幕显示
  void updatePlayPosition(Duration position, double speed) {
    if (!danmakuEnabled.value) return;
    final currentSecond = position.inSeconds;
    if (lastTime == currentSecond) return;
    lastTime = currentSecond;
    var delay = 0;
    if (danmakuSettings.value.bilibiliSource) {
      for (Danmaku danmaku
          in _bili[currentSecond + danmakuSettings.value.bilibiliDelay] ?? []) {
        delay = 0;
        if (danmaku.time > position) {
          delay =
              (danmaku.time.inMilliseconds -
                  danmakuSettings.value.bilibiliDelay * 1000 -
                  position.inMilliseconds) ~/
              speed;
        }
        Future.delayed(
          Duration(milliseconds: delay),
          () => _addDanmakuToController(danmaku),
        );
      }
    }
    if (danmakuSettings.value.gamerSource) {
      for (Danmaku danmaku
          in _gamer[currentSecond + danmakuSettings.value.gamerDelay] ?? []) {
        delay = 0;
        if (danmaku.time > position) {
          delay =
              (danmaku.time.inMilliseconds -
                  danmakuSettings.value.gamerDelay * 1000 -
                  position.inMilliseconds) ~/
              speed;
        }
        Future.delayed(
          Duration(milliseconds: delay),
          () => _addDanmakuToController(danmaku),
        );
      }
    }
    if (danmakuSettings.value.dandanSource) {
      for (Danmaku danmaku
          in _dandan[currentSecond + danmakuSettings.value.dandanDelay] ?? []) {
        delay = 0;
        if (danmaku.time > position) {
          delay =
              (danmaku.time.inMilliseconds -
                  danmakuSettings.value.dandanDelay * 1000 -
                  position.inMilliseconds) ~/
              speed;
        }
        Future.delayed(
          Duration(milliseconds: delay),
          () => _addDanmakuToController(danmaku),
        );
      }
    }
    if (danmakuSettings.value.otherSource) {
      for (Danmaku danmaku
          in _other[currentSecond + danmakuSettings.value.otherDelay] ?? []) {
        delay = 0;
        if (danmaku.time > position) {
          delay =
              (danmaku.time.inMilliseconds -
                  danmakuSettings.value.otherDelay * 1000 -
                  position.inMilliseconds) ~/
              speed;
        }
        Future.delayed(
          Duration(milliseconds: delay),
          () => _addDanmakuToController(danmaku),
        );
      }
    }
  }

  /// 将弹幕添加到控制器中显示
  void _addDanmakuToController(Danmaku danmaku) {
    try {
      // 根据弹幕类型转换为canvas_danmaku的类型
      DanmakuItemType danmakuType;
      switch (danmaku.type) {
        case 4:
          danmakuType = DanmakuItemType.bottom; // 底部弹幕
          break;
        case 5:
          danmakuType = DanmakuItemType.top; // 顶部弹幕
          break;
        default:
          danmakuType = DanmakuItemType.scroll; // 默认滚动弹幕
      }

      // 调用controller的addDanmaku方法
      controller.addDanmaku(
        DanmakuContentItem(
          danmaku.text,
          type: danmakuType,
          color: danmaku.color,
        ),
      );
    } catch (e) {
      _log.error('_addDanmakuToController', '添加弹幕失败', error: e);
    }
  }

  void _danmaku2Map(List<Danmaku> danmakus) {
    _clear();
    var bili = 0;
    var gamer = 0;
    var dandan = 0;
    var other = 0;
    for (var danmaku in danmakus) {
      final key = danmaku.time.inSeconds;
      switch (danmaku.source) {
        case 'BiliBili':
        case 'bilibili':
        case 'bilibili1':
          bili++;
          if (!_bili.containsKey(key)) {
            _bili[key] = [];
          }
          _bili[key]!.add(danmaku);
          break;
        case 'Gamer':
        case 'bahumut':
          gamer++;
          if (!_gamer.containsKey(key)) {
            _gamer[key] = [];
          }
          _gamer[key]!.add(danmaku);
          break;
        case 'DanDanPlay':
        case 'dandan':
          dandan++;
          if (!_dandan.containsKey(key)) {
            _dandan[key] = [];
          }
          _dandan[key]!.add(danmaku);
          break;
        default:
          other++;
          if (!_other.containsKey(key)) {
            _other[key] = [];
          }
          _other[key]!.add(danmaku);
      }
    }
    globalService.danmakuCount.value = {
      'BiliBili': bili,
      'Gamer': gamer,
      'DanDanPlay': dandan,
      'Other': other,
    };
    globalService.showNotification('加载弹幕: ${danmakus.length}条');
  }

  /// 加载弹幕
  Future<void> loadDanmaku({bool force = false}) async {
    if (!danmakuServiceEnable) return;
    try {
      globalService.danmakuCount.value.clear();
      if (!force) {
        final exist = await _getCachedDanmakus(videoInfo.uniqueKey);
        if (exist) return;
      }
      status.value = .matching;
      Episode? result = await danmakuGetter.match(
        videoInfo.uniqueKey,
        videoInfo.videoName,
      );
      if (result == null) {
        globalService.showNotification('未匹配到弹幕');
        status.value = .none;
        return;
      }
      episode.value = result;
      status.value = .downloading;
      final danmakus = await danmakuGetter.save(videoInfo.uniqueKey, result);
      _danmaku2Map(danmakus);
      status.value = .fromApi;
    } catch (e, t) {
      status.value = .failed;
      _log.error('loadDanmaku', '加载弹幕失败', error: e, stackTrace: t);
      globalService.showNotification('加载弹幕失败');
    }
  }

  /// 从缓存获取弹幕数据
  Future<bool> _getCachedDanmakus(String uniqueKey) async {
    try {
      final danmakuFile = File('$cacheDir/$uniqueKey.json');
      if (!await danmakuFile.exists()) return false;
      final jsonString = await danmakuFile.readAsString();
      final danmakuData = DanmakuFile.fromJsonString(jsonString);
      final expireTime = danmakuData.expireTime.millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      episode.value = Episode(
        episodeId: danmakuData.episodeId,
        animeId: danmakuData.animeId,
        animeTitle: danmakuData.animeTitle ?? '',
        episodeTitle: danmakuData.episodeTitle ?? '',
        url: danmakuData.from ?? configureService.danmakuServerList.value.first,
      );
      if (now > expireTime) {
        _log.info('_getCachedDanmakus', '弹幕缓存已过期');
        status.value = .downloading;
        final result = await danmakuGetter.save(uniqueKey, episode.value);
        if (result.isNotEmpty) {
          status.value = .fromApi;
          _danmaku2Map(result);
          return true;
        }
      }
      status.value = .fromCached;
      _danmaku2Map(danmakuData.danmakus);
      return true;
    } catch (e, t) {
      status.value = .failed;
      _log.warn('_getCachedDanmakus', '读取缓存弹幕失败', error: e, stackTrace: t);
      return false;
    }
  }

  /// 搜索番剧集数
  Future<List<Anime>> searchEpisodes(String animeName, String url) async {
    return await danmakuGetter.search(animeName, url);
  }

  /// 选择episodeId并加载弹幕
  Future<void> selectEpisodeAndLoadDanmaku(
    String uniqueKey,
    Episode episode,
  ) async {
    try {
      this.episode.value = episode;
      status.value = .downloading;
      final danmakus = await danmakuGetter.save(uniqueKey, episode);
      status.value = .fromApi;
      _danmaku2Map(danmakus);
      _log.info('selectEpisodeAndLoadDanmaku', '搜索弹幕加载成功: ${danmakus.length}条');
    } catch (e, t) {
      status.value = .failed;
      _log.error(
        'selectEpisodeAndLoadDanmaku',
        '手动选择弹幕加载失败',
        error: e,
        stackTrace: t,
      );
      globalService.showNotification('手动选择弹幕加载失败');
    }
  }

  Future<void> refreshDanmaku() async {
    if (!episode.value.exist()) return;
    try {
      status.value = .downloading;
      final danmakus = await danmakuGetter.save(
        videoInfo.uniqueKey,
        episode.value,
      );
      status.value = .fromApi;
      _danmaku2Map(danmakus);
      _log.info('refreshDanmaku', '刷新弹幕成功: ${danmakus.length}条');
    } catch (e, t) {
      status.value = .failed;
      _log.error('refreshDanmaku', '刷新弹幕失败', error: e, stackTrace: t);
      globalService.showNotification('刷新弹幕失败');
    }
  }

  void updateDanmakuSettings(DanmakuSettings settings) {
    danmakuSettings.value = settings;
    configureService.setDanmakuSettings(settings);
    controller.updateOption(settings.toDanmakuOption());
    _log.debug('updateDanmakuSettings', '弹幕设置更新: $settings');
  }
}

class DanmakuGetter {
  final configureService = GetIt.I.get<ConfigureService>();
  final _log = Logger('DanmakuGetter');

  List<String> get serverList => configureService.danmakuServerList.value;

  DanmakuApiUtils _createApiUtils(String serverUrl) {
    return DanmakuApiUtils(serverUrl);
  }

  Future<List<Anime>> search(String name, String url) async {
    try {
      final apiUtils = _createApiUtils(url);
      return await apiUtils.searchEpisodes(name);
    } catch (e, t) {
      _log.error('search', '搜索番剧失败', error: e, stackTrace: t);
      throw AppException('搜索番剧失败', e);
    }
  }

  Future<Episode?> match(
    String uniqueKey,
    String fileName, {
    String? fileHash,
  }) async {
    for (final serverUrl in serverList) {
      try {
        _log.info('match', '尝试使用服务器: $serverUrl');
        final apiUtils = _createApiUtils(serverUrl);
        final episodes = await apiUtils.matchVideo(
          fileName: fileName,
          fileHash: fileHash,
        );
        if (episodes.isNotEmpty) {
          _log.info('match', '在服务器 $serverUrl 找到匹配结果');
          return episodes.first;
        }
        _log.info('match', '服务器 $serverUrl 未找到匹配结果，尝试下一个');
      } catch (e) {
        _log.warn('match', '服务器 $serverUrl 匹配失败: $e，尝试下一个');
        continue;
      }
    }
    _log.info('match', '所有服务器均未找到匹配结果');
    return null;
  }

  Future<List<Danmaku>> save(String uniqueKey, Episode episode) async {
    try {
      final apiUtils = _createApiUtils(episode.url);
      final comments = await apiUtils.getComments(
        episode.episodeId,
        sc: configureService.autoLanguage.value,
      );
      final danmakus = comments.map((comment) => comment.toDanmaku()).toList();
      final documentsDir = await getApplicationSupportDirectory();
      final cacheDir = Directory('${documentsDir.path}/danmaku');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final cacheFile = File('${cacheDir.path}/$uniqueKey.json');
      final cacheData = DanmakuFile(
        uniqueKey: uniqueKey,
        expireTime: DateTime.now().add(
          danmakus.length > 100
              ? const Duration(days: 3)
              : const Duration(days: 1),
        ),
        danmakus: danmakus,
        episodeId: episode.episodeId,
        animeId: episode.animeId,
        animeTitle: episode.animeTitle,
        episodeTitle: episode.episodeTitle,
        from: episode.url,
      );
      await cacheFile.writeAsString(cacheData.toJsonString());
      _log.info('save', '弹幕缓存保存成功， 弹幕数量: ${danmakus.length}');
      return danmakus;
    } catch (e, t) {
      _log.error('_save', '保存弹幕缓存失败', error: e, stackTrace: t);
      throw AppException('保存弹幕缓存失败', e);
    }
  }
}
