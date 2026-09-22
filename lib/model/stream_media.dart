import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/utils/video_player_utils.dart';

enum MediaType {
  movie('Movie'),
  series('Series'),
  none('none');

  final String name;
  const MediaType(this.name);
}

class UserInfo {
  final String userId;
  final String token;
  UserInfo({required this.userId, required this.token});
  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(userId: json['User']['Id'], token: json['AccessToken']);
  }
}

class CollectionItem {
  final String name;
  final String id;
  CollectionItem({required this.name, required this.id});

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(name: json['Name'], id: json['Id']);
  }
}

class ResumeItem {
  final String id;
  final String name;
  final MediaType type;
  final String? seriesName;
  final int? parentIndexNumber;
  final int? indexNumber;
  final int playbackPositionTicks;
  final int? runTimeTicks;
  final DateTime? lastPlayedDate;
  final String? seriesId;
  final String? mainImage;
  final String? fallbackImage;

  const ResumeItem({
    required this.id,
    required this.name,
    required this.type,
    this.seriesName,
    this.parentIndexNumber,
    this.indexNumber,
    required this.playbackPositionTicks,
    this.runTimeTicks,
    this.lastPlayedDate,
    this.seriesId,
    this.mainImage,
    this.fallbackImage,
  });

  String get subtitle {
    if (seriesName != null && seriesName!.isNotEmpty) {
      final buffer = StringBuffer(seriesName!);
      if (parentIndexNumber != null) {
        buffer.write(' S$parentIndexNumber');
      }
      if (indexNumber != null) {
        buffer.write('E$indexNumber');
      }
      return buffer.toString();
    }
    return name;
  }
}

class MediaItem {
  final String name;
  final String id;
  final MediaType type;
  final UserData? userData;
  MediaItem({
    required this.name,
    required this.id,
    this.type = MediaType.none,
    this.userData,
  });

  factory MediaItem.fromJson(
    Map<String, dynamic> json, {
    bool includeUserData = false,
  }) {
    return MediaItem(
      name: json['Name'],
      id: json['Id'],
      type: MediaType.values.firstWhere(
        (e) => e.name == json['Type'],
        orElse: () => MediaType.none,
      ),
      userData: includeUserData && json['UserData'] != null
          ? UserData.fromJson(json['UserData'])
          : null,
    );
  }
}

class MediaDetail {
  final String id;
  final String name;
  final String? overview;
  final List<String> genres;
  final int? productionYear;
  final int? runTimeTicks;
  final MediaType type;
  final double rating;
  final bool isFavorite;
  final List<ExternalUrl> externalUrls;
  final List<String> tags;
  List<SeasonInfo> seasons = [];

  MediaDetail({
    required this.id,
    required this.name,
    this.overview,
    this.genres = const [],
    this.productionYear,
    this.runTimeTicks,
    this.type = MediaType.none,
    this.rating = 0,
    this.isFavorite = false,
    this.externalUrls = const [],
    this.tags = const [],
  });

  factory MediaDetail.fromJson(
    Map<String, dynamic> json, {
    bool includeUserData = false,
  }) {
    double priceAsDouble(dynamic value) {
      if (value is int) {
        return (value).toDouble();
      }
      return value as double;
    }

    return MediaDetail(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      overview: json['Overview'],
      genres: (json['Genres'] as List?)?.cast<String>() ?? [],
      productionYear: json['ProductionYear'],
      runTimeTicks: json['RunTimeTicks'],
      type: MediaType.values.firstWhere(
        (e) => e.name == json['Type'],
        orElse: () => MediaType.none,
      ),
      rating: priceAsDouble(json['CommunityRating'] ?? 0.0),
      isFavorite: includeUserData && json['UserData']?['IsFavorite'] == true,
      externalUrls: List<ExternalUrl>.from(
        json['ExternalUrls'].map((x) => ExternalUrl.fromJson(x)),
      ),
      tags: List<String>.from(json["Tags"]?.map((x) => x as String) ?? []),
    );
  }

  MediaDetail copyWith({
    String? id,
    String? name,
    String? overview,
    List<String>? genres,
    int? productionYear,
    int? runTimeTicks,
    MediaType? type,
    double? rating,
    bool? isFavorite,
    List<ExternalUrl>? externalUrls,
    List<String>? tags,
    List<SeasonInfo>? seasons,
  }) {
    final detail = MediaDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      overview: overview ?? this.overview,
      genres: genres ?? this.genres,
      productionYear: productionYear ?? this.productionYear,
      runTimeTicks: runTimeTicks ?? this.runTimeTicks,
      type: type ?? this.type,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      externalUrls: externalUrls ?? this.externalUrls,
      tags: tags ?? this.tags,
    );
    detail.seasons = seasons ?? this.seasons;
    return detail;
  }

  String? get formattedRuntime {
    if (runTimeTicks == null) return null;
    final minutes = (runTimeTicks! / 10000000 / 60).round();
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '$hours小时$remainingMinutes分钟';
    }
    return '$remainingMinutes分钟';
  }
}

class ExternalUrl {
  String name;
  String url;

  ExternalUrl({required this.name, required this.url});

  factory ExternalUrl.fromJson(Map<String, dynamic> json) =>
      ExternalUrl(name: json["Name"], url: json["Url"]);
}

class SeasonInfo {
  final String id;
  final String name;
  final int? indexNumber;

  SeasonInfo({required this.id, required this.name, this.indexNumber});

  factory SeasonInfo.fromJson(Map<String, dynamic> json) {
    return SeasonInfo(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      indexNumber: json['IndexNumber'],
    );
  }
}

class PlaybackTarget {
  final String seasonId;
  final String episodeId;
  final MediaType type;

  const PlaybackTarget({
    required this.seasonId,
    required this.episodeId,
    required this.type,
  });
}

class PlayBackInfo(
  final String mediaSourceId,
  final String playSessionId,
  final bool supportsTranscoding,
  final int bitrate,
  final List<MediaStreamInfo> audioStreams,
  final List<MediaStreamInfo> subtitleStreams,
  final int? defaultAudio,
  final int? defaultSubtitle,
);

class MediaStreamInfo {
  final int index;
  final String? language;
  final String? title;
  final bool isDefault;
  final String? subtitleUrl;

  const MediaStreamInfo({
    required this.index,
    this.language,
    this.title,
    this.isDefault = false,
    this.subtitleUrl,
  });

  factory MediaStreamInfo.fromJson(
    Map<dynamic, dynamic> json, {
    String? subtitleUrl,
  }) {
    final map = Map<String, dynamic>.from(json);
    final rawIndex = map['Index'];
    return MediaStreamInfo(
      index: rawIndex is int
          ? rawIndex
          : int.tryParse(rawIndex?.toString() ?? '') ?? -1,
      language: map['Language']?.toString(),
      title: (map['DisplayTitle'] ?? map['Title'])?.toString(),
      isDefault: map['IsDefault'] == true,
      subtitleUrl: subtitleUrl,
    );
  }

  String get label {
    if (title != null && title!.isNotEmpty) return title!;
    return VideoPlayerUtils.subtitleLanguageTranslation(language ?? '');
  }

  static MediaStreamInfo? findByIndex(
    List<MediaStreamInfo> streams,
    int? index,
  ) {
    if (index == null) return null;
    for (final stream in streams) {
      if (stream.index == index) return stream;
    }
    return null;
  }
}

class TranscodeOptions {
  TranscodeOptions(this.itemId);
  String itemId;
  int bitrate = 0;
  int? audioStreamIndex;
  int? subtitleStreamIndex;
  int maxBitrate = 0;

  bool get isOriginal => bitrate == 0;

  factory fromPlayBackInfo(String itemId, PlayBackInfo info) =>
      TranscodeOptions(itemId)
        ..audioStreamIndex = info.defaultAudio
        ..subtitleStreamIndex = info.defaultSubtitle
        ..maxBitrate = info.bitrate;

  Map<String, String> generateBitrateMap() {
    const Map<int, String> presetLadder = {
      0: '原画',
      800000: '800 Kbps',
      1000000: '1 Mbps',
      2000000: '2 Mbps',
      4000000: '4 Mbps',
      8000000: '8 Mbps',
      16000000: '16 Mbps',
    };
    final Map<String, String> resultMap = {};
    presetLadder.forEach((bitrate, displayName) {
      if (bitrate <= maxBitrate) {
        resultMap[bitrate.toString()] = displayName;
      }
    });
    return resultMap;
  }
}

class EpisodeInfo {
  final String id;
  final String name;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String? seriesName;
  final String? overview;
  final int? runTimeTicks;
  UserData? userData;
  String fileName;
  Map<int, String> chapters;

  EpisodeInfo({
    required this.id,
    required this.name,
    this.indexNumber,
    this.parentIndexNumber,
    this.seriesName,
    this.overview,
    this.runTimeTicks,
    this.userData,
    required this.fileName,
    this.chapters = const {},
  });

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    return EpisodeInfo(
      id: json['Id'] ?? '',
      name: json['Name'] ?? '',
      indexNumber: json['IndexNumber'],
      parentIndexNumber: json['ParentIndexNumber'],
      seriesName: json['SeriesName'],
      overview: json['Overview'],
      runTimeTicks: json['RunTimeTicks'],
      fileName: '',
    );
  }

  String? get formattedRuntime {
    if (runTimeTicks == null) return null;
    final minutes = (runTimeTicks! / 10000000 / 60).round();
    return '$minutes分钟';
  }

  String get subtitle {
    String buffer = seriesName ?? '';
    if (parentIndexNumber != null && indexNumber != null) {
      buffer += ' S${parentIndexNumber}E$indexNumber';
    }
    return buffer;
  }
}

class ItemInfo {
  final String fileName;
  final UserData? userData;
  final Map<int, String> chapters;

  ItemInfo({
    required this.fileName,
    required this.userData,
    this.chapters = const {},
  });

  factory ItemInfo.fromJson(
    Map<String, dynamic> json, {
    bool includeUserData = false,
  }) {
    final List<dynamic>? mediaSources = json['MediaSources'];
    if (mediaSources == null || mediaSources.isEmpty) {
      throw Exception('MediaSources is null');
    }
    return ItemInfo(
      fileName: mediaSources.first['Name'] ?? '',
      userData: includeUserData && json['UserData'] != null
          ? UserData.fromJson(json['UserData'])
          : null,
      chapters: parseChapters(json['Chapters']),
    );
  }

  static Map<int, String> parseChapters(dynamic json) {
    if (json is! List) return const {};
    final entries = <(int, String)>[];
    for (final item in json) {
      if (item is! Map) continue;
      final rawTicks = item['StartPositionTicks'];
      final ticks = rawTicks is num
          ? rawTicks.toInt()
          : int.tryParse(rawTicks?.toString() ?? '');
      if (ticks == null) continue;
      final seconds = ticks ~/ 10000000;
      final name = item['Name']?.toString() ?? '';
      entries.add((
        seconds,
        name.isNotEmpty
            ? name
            : Utils.formatDuration(Duration(seconds: seconds)),
      ));
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    return {for (final entry in entries) entry.$1: entry.$2};
  }
}

class UserData {
  final int? unplayedItemCount;
  final int? playbackPositionTicks;
  final DateTime? lastPlayedDate;
  final bool isFavorite;
  bool played;

  UserData({
    this.unplayedItemCount,
    this.playbackPositionTicks,
    this.lastPlayedDate,
    this.isFavorite = false,
    this.played = false,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      unplayedItemCount: json['UnplayedItemCount'],
      playbackPositionTicks: json['PlaybackPositionTicks'],
      lastPlayedDate: json['LastPlayedDate'] != null
          ? DateTime.parse(json['LastPlayedDate']).toUtc()
          : null,
      isFavorite: json['IsFavorite'] == true,
      played: json['Played'] == true,
    );
  }
}
