import 'package:fldanplay/service/player/danmaku.dart';
import 'package:fldanplay/widget/settings/settings_section.dart';
import 'package:fldanplay/widget/settings/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DanmakuSettingsPanel extends StatelessWidget {
  final DanmakuService danmakuService;

  const DanmakuSettingsPanel({super.key, required this.danmakuService});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final settings = danmakuService.danmakuSettings.value;
        return SingleChildScrollView(
          child: SettingsSection(
            title: '样式设置',
            children: [
              SettingsTile.sliderTile(
                title: '透明度',
                onSilderChange: (value) {
                  danmakuService.updateDanmakuSettings(
                    settings.copyWith(opacity: value),
                  );
                },
                details: settings.opacity.toStringAsFixed(1),
                silderValue: settings.opacity,
                silderDivisions: 10,
                silderMin: 0,
                silderMax: 1,
              ),
              SettingsTile.sliderTile(
                title: '字体大小',
                onSilderChange: (value) {
                  danmakuService.updateDanmakuSettings(
                    settings.copyWith(fontSize: value),
                  );
                },
                details: settings.fontSize.round().toString(),
                silderValue: settings.fontSize,
                silderDivisions: 22,
                silderMin: 10,
                silderMax: 32,
              ),
              SettingsTile.sliderTile(
                title: '字体粗细',
                onSilderChange: (value) {
                  danmakuService.updateDanmakuSettings(
                    settings.copyWith(fontWeight: value.round()),
                  );
                },
                details: settings.fontWeight.toString(),
                silderValue: settings.fontWeight.toDouble(),
                silderDivisions: 8,
                silderMin: 0,
                silderMax: 8,
              ),
              SettingsTile.sliderTile(
                title: '描边宽度',
                onSilderChange: (value) {
                  danmakuService.updateDanmakuSettings(
                    settings.copyWith(strokeWidth: value),
                  );
                },
                details: settings.strokeWidth.toString(),
                silderValue: settings.strokeWidth,
                silderDivisions: 16,
                silderMin: 0,
                silderMax: 4,
              ),
              SettingsTile.sliderTile(
                title: '显示时长',
                onSilderChange: (value) {
                  danmakuService.updateDanmakuSettings(
                    settings.copyWith(duration: value),
                  );
                },
                details: settings.duration.toString(),
                silderValue: settings.duration.toDouble(),
                silderDivisions: 16,
                silderMin: 1,
                silderMax: 17,
              ),
              SettingsTile.switchTile(
                title: '弹幕速度与视频同步',
                onBoolChange: (value) {
                  danmakuService.updateDanmakuSettings(
                    settings.copyWith(speedSync: value),
                  );
                  danmakuService.updateSpeed();
                },
                switchValue: settings.speedSync,
              ),
              SettingsTile.sliderTile(
                title: '弹幕区域',
                onSilderChange: (value) {
                  danmakuService.updateDanmakuSettings(
                    settings.copyWith(danmakuArea: value),
                  );
                },
                details: '${(settings.danmakuArea * 100).toStringAsFixed(1)}%',
                silderValue: settings.danmakuArea,
                silderDivisions: 8,
                silderMin: 0,
                silderMax: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
