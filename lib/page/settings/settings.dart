import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/utils/icon.dart';
import 'package:fldanplay/utils/theme.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = GetIt.I<GlobalService>();
    return Scaffold(
      appBar: SysAppBar(title: '设置'),
      body: SingleChildScrollView(
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: FItemGroup(
            style: settingsItemGroupStyle,
            divider: FItemDivider.indented,
            children: [
              FItem(
                prefix: const Icon(FLucideIcons.settings),
                title: const Text('通用'),
                subtitle: const Text('界面、播放缓存优先度'),
                autofocus: true,
                onPress: () => context.push('/settings/general'),
              ),
              FItem(
                prefix: const Icon(FLucideIcons.video),
                title: const Text('播放器'),
                subtitle: const Text('播放速度、解码、字幕语言'),
                onPress: () => context.push('/settings/player'),
              ),
              FItem(
                prefix: const Icon(MyIcon.danmaku),
                title: const Text('弹幕'),
                subtitle: const Text('弹幕服务配置'),
                onPress: () => context.push('/settings/danmaku'),
              ),
              FItem(
                prefix: const Icon(FLucideIcons.type),
                title: const Text('字体'),
                subtitle: const Text('管理视频字幕字体'),
                onPress: () => context.push('/settings/font'),
              ),
              FItem(
                prefix: const Icon(FLucideIcons.cloud),
                title: const Text('同步'),
                subtitle: const Text('设置 WebDAV 同步参数'),
                onPress: () => context.push('/settings/webdav'),
              ),
              FItem(
                prefix: const Icon(FLucideIcons.wrench),
                title: const Text('维护'),
                subtitle: const Text('数据备份还原、清理'),
                onPress: () => context.push('/settings/maintenance'),
              ),
              FItem(
                prefix: const Icon(FLucideIcons.logs),
                title: const Text('日志'),
                subtitle: const Text('设置日志级别、导出日志'),
                onPress: () => context.push('/settings/log'),
              ),
              FItem(
                prefix: const Icon(FLucideIcons.info),
                title: Row(
                  children: [
                    const Text('关于'),
                    const SizedBox(width: 4),
                    SignalBuilder(
                      builder: (context) {
                        if (gs.updateInfo.value != null &&
                            gs.updateInfo.value!.hasUpdate) {
                          return FBadge.raw(
                            builder: (context, style) =>
                                const SizedBox(width: 8, height: 8),
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                subtitle: const Text('版本信息、项目主页、开源许可'),
                onPress: () => context.push('/settings/about'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
