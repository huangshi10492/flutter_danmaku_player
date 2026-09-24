import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/utils/crypto_utils.dart';
import 'package:fldanplay/utils/utils.dart';

class VideoInfo {
  // 视频文件的真实地址
  String currentVideoPath;
  // 虚拟路径(1/video.mp4)
  String virtualVideoPath;
  Map<String, String> headers;
  HistoriesType historiesType;
  String? storageKey;
  int videoIndex;
  int listLength;
  bool canSwitch = false;
  late String uniqueKey;
  late String videoName; // 用于弹幕匹配
  late String name; // 显示在播放器顶部
  String? subtitle;
  bool cached = false;
  List<ExternalSubtitle> externalSubtitles = const [];
  Map<int, String> chapters = const {};

  VideoInfo.fromFile({
    required this.currentVideoPath,
    required this.virtualVideoPath,
    this.headers = const {},
    required this.historiesType,
    this.storageKey,
    this.videoIndex = 0,
    this.listLength = 0,
    this.canSwitch = false,
    this.subtitle,
    List<ExternalSubtitle>? externalSubtitles,
    Map<int, String>? chapters,
  }) {
    name = virtualVideoPath.split('/').last;
    videoName = Utils.removeExtension(name);
    uniqueKey = CryptoUtils.generateVideoUniqueKey(virtualVideoPath);
    this.externalSubtitles = externalSubtitles ?? const [];
    this.chapters = chapters ?? const {};
  }

  VideoInfo({
    required this.currentVideoPath,
    required this.virtualVideoPath,
    this.headers = const {},
    required this.historiesType,
    this.storageKey,
    this.videoIndex = 0,
    this.listLength = 0,
    this.canSwitch = false,
    required this.videoName,
    required this.name,
    this.subtitle,
    List<ExternalSubtitle>? externalSubtitles,
    Map<int, String>? chapters,
  }) {
    uniqueKey = CryptoUtils.generateVideoUniqueKey(virtualVideoPath);
    this.externalSubtitles = externalSubtitles ?? const [];
    this.chapters = chapters ?? const {};
  }

  bool get unsafeUrl {
    return currentVideoPath.startsWith('ftp') ||
        currentVideoPath.startsWith('smb2');
  }
}

class ExternalSubtitle(
  final String url,
  final String title,
  final String? language,
);

/// 轨道信息模型
class TrackInfo {
  final int index;
  final String id;
  final String language;
  final String title;

  const TrackInfo({
    required this.index,
    required this.id,
    required this.language,
    required this.title,
  });
}

class Metadata {
  final String media;
  final String hwdec;
  final String videoOutput;
  final String videoParams;
  final String audioParams;

  const Metadata({
    required this.media,
    required this.hwdec,
    required this.videoOutput,
    required this.videoParams,
    required this.audioParams,
  });
}

class DanmakuMatchInfo {
  final String fileName;
  String currentVideoPath;
  final Map<String, String> headers;

  DanmakuMatchInfo({
    required this.fileName,
    required this.currentVideoPath,
    this.headers = const {},
  });

  factory DanmakuMatchInfo.fromVideoInfo(VideoInfo videoInfo) {
    return DanmakuMatchInfo(
      fileName: videoInfo.videoName,
      currentVideoPath: videoInfo.currentVideoPath,
      headers: videoInfo.headers,
    );
  }
}
