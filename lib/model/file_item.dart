enum FileType { folder, video, subtitle }

class FileItem {
  final String name;
  final String path;
  final FileType type;
  final String uniqueKey;
  final int? size;
  int videoIndex;
  List<String> subtitles = const [];

  FileItem({
    required this.name,
    required this.path,
    required this.type,
    required this.uniqueKey,
    this.size,
    this.videoIndex = 0,
  });

  FileItem copyWith({
    String? name,
    String? path,
    FileType? type,
    int? size,
    DateTime? modifiedTime,
    String? uniqueKey,
  }) {
    return FileItem(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      uniqueKey: uniqueKey ?? this.uniqueKey,
    );
  }

  bool get isVideo => type == FileType.video;
  bool get isFolder => type == FileType.folder;
  bool get isSubtitle => type == FileType.subtitle;

  static const subtitleExtensions = {'srt', 'ass', 'ssa', 'vtt', 'sub', 'sup'};

  static String _baseName(String name) {
    final i = name.lastIndexOf('.');
    return (i > 0 ? name.substring(0, i) : name).toLowerCase();
  }

  static bool isSubtitleFileName(String name) {
    final i = name.lastIndexOf('.');
    return i > 0 &&
        i < name.length - 1 &&
        subtitleExtensions.contains(name.substring(i + 1).toLowerCase());
  }

  static List<FileItem> resolveSubtitles(List<FileItem> files) {
    final subs = files.where((f) => f.isSubtitle).toList();
    if (subs.isEmpty) return files;
    return files.where((f) => !f.isSubtitle).map((f) {
      final base = _baseName(f.name);
      if (f.isVideo) {
        f.subtitles = subs
            .where((item) {
              final subBase = _baseName(item.name);
              return subBase == base || subBase.startsWith('$base.');
            })
            .map((e) => e.path)
            .toList();
      }
      return f;
    }).toList();
  }

  static (String, String)? _subtitleSuffix(
    String videoName,
    String subtitleName,
  ) {
    final vBase = _baseName(videoName);
    final sDot = subtitleName.lastIndexOf('.');
    if (sDot <= 0) return null;
    final sBase = subtitleName.substring(0, sDot).toLowerCase();
    if (sBase == vBase || !sBase.startsWith('$vBase.')) return null;
    var suffix = subtitleName.substring(vBase.length + 1, sDot);
    final lowerSuffix = suffix.toLowerCase();
    final vDot = videoName.lastIndexOf('.');
    if (vDot > 0) {
      final vExt = videoName.substring(vDot + 1).toLowerCase();
      if (lowerSuffix == vExt) return null;
      if (lowerSuffix.startsWith('$vExt.')) {
        suffix = suffix.substring(vExt.length + 1);
      }
    }
    return suffix.isEmpty ? null : (suffix, subtitleName.substring(sDot + 1));
  }

  static String subtitleTitle(String videoName, String subtitleName) {
    return switch (_subtitleSuffix(videoName, subtitleName)) {
      (final suffix, final ext) => '$suffix.$ext',
      null => subtitleName,
    };
  }

  // Check if file is a video based on extension
  static FileType getFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    const videoExtensions = {
      'mp4',
      'avi',
      'mkv',
      'mov',
      'wmv',
      'flv',
      'webm',
      'm4v',
      'mpg',
      'mpeg',
      '3gp',
      'ts',
      'rmvb',
      'rm',
      'asf',
    };

    if (videoExtensions.contains(extension)) {
      return FileType.video;
    }
    return FileType.folder;
  }
}
