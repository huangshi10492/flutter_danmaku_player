/// 视频播放器工具类
class VideoPlayerUtils {
  /// 检查是否为支持的视频格式
  static bool isSupportedVideoFormat(String path) {
    final supportedExtensions = [
      '.mp4',
      '.avi',
      '.mkv',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
      '.3gp',
      '.ts',
      '.m3u8',
    ];
    final lowerPath = path.toLowerCase();
    return supportedExtensions.any((ext) => lowerPath.endsWith(ext));
  }

  static String? subtitleTitleTranslation(String id, String title) {
    switch (id) {
      case 'auto':
        return '自动选择';
      case 'no':
        return '禁用';
    }
    if (title.isNotEmpty) {
      switch (title) {
        case 'Simplified':
          return '中文(简体)';
        case 'Traditional':
          return '中文(繁体)';
        default:
          return title;
      }
    }
    return null;
  }

  static String subtitleLanguageTranslation(String language) {
    return switch (language) {
      'chi' => '中文',
      'eng' => '英文',
      'jpn' => '日文',
      'ara' => '阿拉伯语',
      'ger' => '德语',
      'spa' => '西班牙语',
      'fre' => '法语',
      'hin' => '印地语',
      'ind' => '印尼语',
      'ita' => '意大利语',
      'kor' => '韩语',
      'may' => '马来语',
      'dut' => '荷兰语',
      'pol' => '波兰语',
      _ => language,
    };
  }
}
