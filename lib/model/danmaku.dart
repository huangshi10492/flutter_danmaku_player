import 'dart:convert';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:flutter/material.dart';

/// 弹幕数据模型
class Danmaku {
  /// 弹幕文本
  final String text;

  /// 出现时间
  final Duration time;

  /// 弹幕类型 弹幕模式：1-普通弹幕，4-底部弹幕，5-顶部弹幕
  final int type;

  /// 弹幕颜色 32位整数表示的颜色，算法为 Rx256x256+Gx256+B，R/G/B的范围应是0-255
  final Color color;

  final String source;

  final String userid;

  const Danmaku({
    required this.text,
    required this.time,
    required this.type,
    required this.color,
    required this.source,
    required this.userid,
  });

  // 格式: 出现时间,模式,颜色,[平台名]用户ID
  // 30.82,1,25,16777215,[5dm]379579
  // [平台名]可能为空
  factory Danmaku.fromJson(String p, String m) {
    final parts = p.split(',');
    final time = Duration(
      milliseconds: (double.parse(parts[0]) * 1000).round(),
    );
    final type = int.parse(parts[1]);
    final colorValue = int.parse(parts[2]);
    final color = Color.fromRGBO(
      colorValue ~/ 256 ~/ 256,
      colorValue ~/ 256 % 256,
      colorValue % 256,
      1.0,
    );
    // 解析用户ID和平台名
    String userPart = parts[3];
    String? source;
    String? userId;

    // 检查是否有平台名
    RegExp sourceRegex = RegExp(r"\[(.*?)\](.*)");
    Match? match = sourceRegex.firstMatch(userPart);

    if (match != null) {
      source = match.group(1);
      userId = match.group(2);
    } else {
      source = null;
      userId = userPart;
    }

    return Danmaku(
      text: m,
      time: time,
      type: type,
      color: color,
      source: source ?? 'DanDanPlay',
      userid: userId ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final colorValue =
        (color.r * 255 * 256 * 256).round() +
        (color.g * 255 * 256).round() +
        (color.b * 255).round();
    final p =
        "${time.inMilliseconds / 1000},$type,$colorValue,[$source]$userid";
    return {'p': p, 'm': text};
  }
}

class Anime {
  final String animeTitle;
  final int animeId;
  final List<Episode> episodes;

  const Anime({
    required this.animeTitle,
    required this.animeId,
    required this.episodes,
  });

  factory Anime.fromJson(Map<String, dynamic> json, String url) {
    return Anime(
      animeTitle: json['animeTitle'] as String,
      animeId: json['animeId'] as int,
      episodes: (json['episodes'] as List)
          .map(
            (e) => Episode.fromSearchJson(
              e as Map<String, dynamic>,
              json['animeTitle'] as String,
              json['animeId'] as int,
              url,
            ),
          )
          .toList(),
    );
  }
}

class Episode {
  final int episodeId;
  final String animeTitle;
  final String episodeTitle;
  final int animeId;
  final String url;

  const Episode({
    required this.episodeId,
    required this.animeId,
    required this.animeTitle,
    required this.episodeTitle,
    required this.url,
  });

  factory Episode.fromId(int episodeId, int animeId, String url) {
    return Episode(
      episodeId: episodeId,
      animeId: animeId,
      animeTitle: '',
      episodeTitle: '',
      url: url,
    );
  }

  bool exist() {
    return episodeId > 0 && animeId > 0;
  }

  factory Episode.fromJson(Map<String, dynamic> json, String url) {
    return Episode(
      episodeId: json['episodeId'] as int,
      animeTitle: json['animeTitle'] as String,
      episodeTitle: json['episodeTitle'] as String,
      animeId: json['animeId'] as int,
      url: url,
    );
  }

  factory Episode.fromSearchJson(
    Map<String, dynamic> episodeJson,
    String animeTitle,
    int animeId,
    String url,
  ) {
    return Episode(
      episodeId: episodeJson['episodeId'] as int,
      animeTitle: animeTitle,
      episodeTitle: episodeJson['episodeTitle'] as String,
      animeId: animeId,
      url: url,
    );
  }
}

class DanmakuComment {
  /// 弹幕ID
  final int cid;

  /// 弹幕参数
  final String p;

  /// 弹幕内容
  final String m;

  const DanmakuComment({required this.cid, required this.p, required this.m});

  /// 从JSON创建弹幕评论
  factory DanmakuComment.fromJson(Map<String, dynamic> json) {
    return DanmakuComment(
      cid: json['cid'] as int,
      p: json['p'] as String,
      m: json['m'] as String,
    );
  }

  /// 转换为Danmaku对象
  Danmaku toDanmaku() {
    return Danmaku.fromJson(p, m);
  }
}

// 弹幕设置
class DanmakuSettings {
  // 描边宽度
  double strokeWidth;

  // 透明度
  double opacity;

  // 显示时长
  double duration;

  // 与视频同步
  bool speedSync;

  // 字体大小
  double fontSize;

  // 字体粗细
  int fontWeight;

  // 弹幕区域
  double danmakuArea;

  // 隐藏顶部弹幕
  bool hideTop;

  // 隐藏底部弹幕
  bool hideBottom;

  // 隐藏滚动弹幕
  bool hideScroll;

  // 显示特殊弹幕
  bool hideSpecial;

  // 哔哩哔哩源
  bool bilibiliSource;

  // Gamer源
  bool gamerSource;

  // 弹弹play源
  bool dandanSource;

  // other源
  bool otherSource;

  // 哔哩哔哩源延迟
  int bilibiliDelay;

  // Gamer源延迟
  int gamerDelay;

  // 弹弹play源延迟
  int dandanDelay;

  // other源延迟
  int otherDelay;

  DanmakuSettings({
    this.strokeWidth = 1.5,
    this.opacity = 1.0,
    this.duration = 8,
    this.speedSync = true,
    this.fontSize = 16.0,
    this.fontWeight = 4,
    this.danmakuArea = 1.0,
    this.hideTop = false,
    this.hideBottom = true,
    this.hideScroll = false,
    this.hideSpecial = false,
    this.bilibiliSource = true,
    this.gamerSource = true,
    this.dandanSource = true,
    this.otherSource = true,
    this.bilibiliDelay = 0,
    this.gamerDelay = 0,
    this.dandanDelay = 0,
    this.otherDelay = 0,
  });

  DanmakuOption toDanmakuOption() {
    return DanmakuOption(
      fontSize: fontSize,
      fontWeight: fontWeight,
      area: danmakuArea,
      duration: duration,
      staticDuration: duration,
      hideBottom: hideBottom,
      hideScroll: hideScroll,
      hideTop: hideTop,
      hideSpecial: hideSpecial,
      strokeWidth: strokeWidth,
      massiveMode: false,
      safeArea: true,
      fontFamily: Utils.font(null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strokeWidth': strokeWidth,
      'opacity': opacity,
      'duration': duration,
      'speedSync': speedSync,
      'fontSize': fontSize,
      'danmakuArea': danmakuArea,
      'hideTop': hideTop,
      'hideBottom': hideBottom,
      'hideScroll': hideScroll,
      'hideSpecial': hideSpecial,
      'fontWeight': fontWeight,
    };
  }

  factory DanmakuSettings.fromJson(Map<String, dynamic> json) {
    return DanmakuSettings(
      strokeWidth: (json['strokeWidth'] as double?) ?? 1.5,
      opacity: (json['opacity'] as double?) ?? 1.0,
      duration: (json['duration'] as double?) ?? 8,
      speedSync: (json['speedSync'] as bool?) ?? true,
      fontSize: (json['fontSize'] as double?) ?? 16.0,
      fontWeight: (json['fontWeight'] as int?) ?? 4,
      danmakuArea: (json['danmakuArea'] as double?) ?? 1.0,
      hideTop: (json['hideTop'] as bool?) ?? false,
      hideBottom: (json['hideBottom'] as bool?) ?? true,
      hideScroll: (json['hideScroll'] as bool?) ?? false,
      hideSpecial: (json['hideSpecial'] as bool?) ?? false,
    );
  }

  DanmakuSettings copyWith({
    double? strokeWidth,
    double? opacity,
    double? duration,
    bool? speedSync,
    double? fontSize,
    double? danmakuArea,
    bool? hideTop,
    bool? hideBottom,
    bool? hideScroll,
    bool? massiveMode,
    bool? hideSpecial,
    int? fontWeight,
    bool? bilibiliSource,
    bool? gamerSource,
    bool? dandanSource,
    bool? otherSource,
    int? bilibiliDelay,
    int? gamerDelay,
    int? dandanDelay,
    int? otherDelay,
  }) {
    return DanmakuSettings(
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      duration: duration ?? this.duration,
      speedSync: speedSync ?? this.speedSync,
      fontSize: fontSize ?? this.fontSize,
      danmakuArea: danmakuArea ?? this.danmakuArea,
      hideTop: hideTop ?? this.hideTop,
      hideBottom: hideBottom ?? this.hideBottom,
      hideScroll: hideScroll ?? this.hideScroll,
      hideSpecial: hideSpecial ?? this.hideSpecial,
      fontWeight: fontWeight ?? this.fontWeight,
      bilibiliSource: bilibiliSource ?? this.bilibiliSource,
      gamerSource: gamerSource ?? this.gamerSource,
      dandanSource: dandanSource ?? this.dandanSource,
      otherSource: otherSource ?? this.otherSource,
      bilibiliDelay: bilibiliDelay ?? this.bilibiliDelay,
      gamerDelay: gamerDelay ?? this.gamerDelay,
      dandanDelay: dandanDelay ?? this.dandanDelay,
      otherDelay: otherDelay ?? this.otherDelay,
    );
  }
}

class DanmakuFile {
  String uniqueKey;
  DateTime expireTime;
  List<Danmaku> danmakus;
  int episodeId;
  int animeId;
  String? animeTitle;
  String? episodeTitle;
  String? from;

  DanmakuFile({
    required this.uniqueKey,
    required this.expireTime,
    required this.danmakus,
    required this.episodeId,
    required this.animeId,
    this.animeTitle,
    this.episodeTitle,
    this.from,
  });

  // 将对象转换为Map，用于JSON序列化
  Map<String, dynamic> toJson() {
    return {
      'uniqueKey': uniqueKey,
      'expireTime': expireTime.millisecondsSinceEpoch,
      'danmakus': danmakus.map((d) => d.toJson()).toList(),
      'episodeId': episodeId,
      'animeId': animeId,
      'episodeTitle': episodeTitle,
      'animeTitle': animeTitle,
      'from': from,
    };
  }

  // 从Map创建对象，用于JSON反序列化
  factory DanmakuFile.fromJson(Map<String, dynamic> json) {
    return DanmakuFile(
      uniqueKey: json['uniqueKey'],
      expireTime: DateTime.fromMillisecondsSinceEpoch(json['expireTime']),
      danmakus: (json['danmakus'] as List)
          .map(
            (item) =>
                Danmaku.fromJson(item['p'] as String, item['m'] as String),
          )
          .toList(),
      episodeId: json['episodeId'] as int,
      animeId: json['animeId'] as int,
      animeTitle: json['animeTitle'] as String?,
      episodeTitle: json['episodeTitle'] as String?,
      from: json['from'] as String?,
    );
  }

  // 将对象转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // 从JSON字符串创建对象
  factory DanmakuFile.fromJsonString(String jsonString) {
    return DanmakuFile.fromJson(jsonDecode(jsonString));
  }
}
