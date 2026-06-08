import 'dart:io';

import 'package:fldanplay/utils/log.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class SuperResolutionUtils {
  static const version = '1';
  static final Logger _logger = Logger('SuperResolutionUtils');

  // Anime4K: Mode A (HQ)
  static const List<String> modeAHQ = [
    'Anime4K_Clamp_Highlights.glsl',
    'Anime4K_Restore_CNN_VL.glsl',
    'Anime4K_Upscale_CNN_x2_VL.glsl',
    'Anime4K_AutoDownscalePre_x2.glsl',
    'Anime4K_AutoDownscalePre_x4.glsl',
    'Anime4K_Upscale_CNN_x2_M.glsl',
  ];

  // Anime4K: Mode A (Fast)
  static const List<String> modeAFast = [
    'Anime4K_Clamp_Highlights.glsl',
    'Anime4K_Restore_CNN_M.glsl',
    'Anime4K_Upscale_CNN_x2_M.glsl',
    'Anime4K_AutoDownscalePre_x2.glsl',
    'Anime4K_AutoDownscalePre_x4.glsl',
    'Anime4K_Upscale_CNN_x2_S.glsl',
  ];

  // Anime4K: Mode B (HQ)
  static const List<String> modeBHQ = [
    'Anime4K_Clamp_Highlights.glsl',
    'Anime4K_Restore_CNN_Soft_VL.glsl',
    'Anime4K_Upscale_CNN_x2_VL.glsl',
    'Anime4K_AutoDownscalePre_x2.glsl',
    'Anime4K_AutoDownscalePre_x4.glsl',
    'Anime4K_Upscale_CNN_x2_M.glsl',
  ];

  // Anime4K: Mode B (Fast)
  static const List<String> modeBFast = [
    'Anime4K_Clamp_Highlights.glsl',
    'Anime4K_Restore_CNN_Soft_M.glsl',
    'Anime4K_Upscale_CNN_x2_M.glsl',
    'Anime4K_AutoDownscalePre_x2.glsl',
    'Anime4K_AutoDownscalePre_x4.glsl',
    'Anime4K_Upscale_CNN_x2_S.glsl',
  ];

  static Future<void> initFile() async {
    final dir = '${(await getApplicationSupportDirectory()).path}/shaders';
    await Directory(dir).create(recursive: true);
    // 检查shader版本文件
    final file = File('$dir/version.txt');
    if (file.existsSync()) {
      final oldVersion = await file.readAsString();
      if (oldVersion == version) return;
      await Directory(dir).delete(recursive: true);
      await Directory(dir).create(recursive: true);
    }
    await file.writeAsString(version);
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = assetManifest.listAssets();
    final shaderFiles = assets.where(
      (String asset) =>
          asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'),
    );
    try {
      for (var filePath in shaderFiles) {
        final fileName = filePath.split('/').last;
        final targetFile = File(path.join(dir, fileName));
        if (await targetFile.exists()) continue;
        final data = await rootBundle.load(filePath);
        final List<int> bytes = data.buffer.asUint8List();
        await targetFile.writeAsBytes(bytes);
      }
    } catch (e, s) {
      _logger.error('initFile', '创建shader文件失败', error: e, stackTrace: s);
    }
  }

  static Future<String> buildPath(int type) async {
    final dir = '${(await getApplicationSupportDirectory()).path}/shaders';
    List<String> shaders;
    switch (type) {
      case 1:
        shaders = modeAHQ;
        break;
      case 2:
        shaders = modeAFast;
        break;
      case 3:
        shaders = modeBHQ;
        break;
      case 4:
        shaders = modeBFast;
        break;
      default:
        shaders = [];
    }
    final absolutePaths = shaders.map((shader) {
      return path.join(dir, shader);
    }).toList();
    if (Platform.isWindows) {
      return absolutePaths.join(';');
    }
    return absolutePaths.join(':');
  }
}
