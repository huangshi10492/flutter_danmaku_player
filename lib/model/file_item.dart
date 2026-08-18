enum FileType { folder, video }

class FileItem {
  final String name;
  final String path;
  final FileType type;
  final String uniqueKey;
  final int? size;
  int videoIndex;

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
