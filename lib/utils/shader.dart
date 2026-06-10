import 'dart:io';

import 'package:archive/archive_io.dart';
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
    final shaderDir =
        '${(await getApplicationSupportDirectory()).path}/shaders';
    final versionFile = File('$shaderDir/version.txt');
    try {
      if (await versionFile.exists()) {
        final oldVersion = await versionFile.readAsString();
        if (oldVersion == version) return;
      }
      final dir = Directory(shaderDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);
      final data = await rootBundle.load('assets/anime4k/anime4k.zip');
      final archive = ZipDecoder().decodeBytes(data.buffer.asUint8List());
      await extractArchiveToDisk(archive, shaderDir);
      await versionFile.writeAsString(version);
    } catch (e, s) {
      _logger.error('initFile', '解压shader失败', error: e, stackTrace: s);
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
