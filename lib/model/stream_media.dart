import 'package:fldanplay/utils/video_player_utils.dart';

enum MediaType {
  movie('Movie'),
  series('Series'),
  none('none');

  final String name;
  const MediaType(this.name);
}

typedef UserInfo = ({String userId, String token});
typedef CollectionItem = ({String id, String name});
typedef ExternalUrl = ({String name, String url});
typedef PlaybackTarget = ({String seasonId, String episodeId, MediaType type});

class MediaItem({
  required final String name,
  required final String id,
  final MediaType type = MediaType.none,
  final UserData? userData,
  final String? imageUrl,
});

class SeasonInfo({
  required final String id,
  required final String name,
  final int? indexNumber,
});

class UserData({
  final int? unplayedItemCount,
  final int? playbackPositionTicks,
  final DateTime? lastPlayedDate,
  var bool played = false,
});

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
  final String? imageUrl;
  final String? fallbackImageUrl;

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
    this.imageUrl,
    this.fallbackImageUrl,
  });

  String get subtitle => (seriesName == null || seriesName!.isEmpty)
      ? name
      : formatSeriesSubtitle(
          seriesName: seriesName,
          seasonNumber: parentIndexNumber,
          episodeNumber: indexNumber,
          fallback: name,
        );
}

String formatSeriesSubtitle({
  String? seriesName,
  int? seasonNumber,
  int? episodeNumber,
  String? fallback,
}) {
  final buffer = StringBuffer();
  final hasSeries = seriesName != null && seriesName.isNotEmpty;
  if (hasSeries) buffer.write(seriesName);
  if (seasonNumber != null) {
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write('S$seasonNumber');
  }
  if (episodeNumber != null) {
    if (seasonNumber == null && buffer.isNotEmpty) buffer.write(' ');
    buffer.write('E$episodeNumber');
  }
  if (buffer.isEmpty) return fallback ?? '';
  return buffer.toString();
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
  final String? imageUrl;
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
    this.imageUrl,
  });

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
    String? imageUrl,
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
      imageUrl: imageUrl ?? this.imageUrl,
    );
    detail.seasons = seasons ?? this.seasons;
    return detail;
  }
}

class EpisodeInfo {
  final String id;
  final String name;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String? seriesName;
  final int? runTimeTicks;
  UserData? userData;
  String fileName;
  Map<int, String> chapters;
  String? imageUrl;

  EpisodeInfo({
    required this.id,
    required this.name,
    this.indexNumber,
    this.parentIndexNumber,
    this.seriesName,
    this.runTimeTicks,
    this.userData,
    required this.fileName,
    this.chapters = const {},
    this.imageUrl,
  });

  String get subtitle => formatSeriesSubtitle(
    seriesName: seriesName,
    seasonNumber: parentIndexNumber,
    episodeNumber: indexNumber,
  );
}

class PlaybackInfo {
  final String itemId;
  final String mediaSourceId;
  final String playSessionId;
  final bool supportsTranscoding;
  final int bitrate;
  final List<MediaStreamInfo> audioStreams;
  final List<MediaStreamInfo> subtitleStreams;
  final int? defaultAudio;
  final int? defaultSubtitle;
  final String fileName;
  final Map<int, String> chapters;
  final String? videoUrl;
  final Map<String, String> headers;

  const PlaybackInfo({
    required this.itemId,
    required this.mediaSourceId,
    required this.playSessionId,
    required this.supportsTranscoding,
    required this.bitrate,
    this.audioStreams = const [],
    this.subtitleStreams = const [],
    this.defaultAudio,
    this.defaultSubtitle,
    this.fileName = '',
    this.chapters = const {},
    this.videoUrl,
    this.headers = const {},
  });
}

class MediaStreamInfo {
  final int index;
  final String? language;
  final String? title;
  final bool isDefault;
  final bool isExternal;
  final String? subtitleUrl;

  const MediaStreamInfo({
    required this.index,
    this.language,
    this.title,
    this.isDefault = false,
    this.isExternal = false,
    this.subtitleUrl,
  });

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

  factory fromMediaPlaybackInfo(PlaybackInfo info) =>
      TranscodeOptions(info.itemId)
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
