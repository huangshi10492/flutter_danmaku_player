import 'package:fldanplay/page/player/right_drawer.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/player/danmaku.dart';
import 'package:fldanplay/service/player/player.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

class DanmakuInfoPanel extends StatelessWidget {
  final DanmakuService danmakuService;
  final VideoPlayerService playerService;
  final void Function(RightDrawerType newType) onDrawerChanged;
  const DanmakuInfoPanel({
    super.key,
    required this.danmakuService,
    required this.playerService,
    required this.onDrawerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final globalService = GetIt.I.get<GlobalService>();
    return Scaffold(
      body: Watch((context) {
        return ListView(
          padding: EdgeInsets.all(4),
          children: [
            FCard(
              style: (style) => style.copyWith(
                contentStyle: (style) => style.copyWith(
                  subtitleTextStyle: style.subtitleTextStyle.copyWith(
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
              title: Text('弹幕信息', style: context.theme.typography.xl),
              subtitle: Watch((context) {
                return Column(
                  crossAxisAlignment: .start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('状态: ${danmakuService.status.value.label}'),
                        const SizedBox(width: 4),
                        if (danmakuService.status.value.level == 0)
                          const Icon(FIcons.check, color: Colors.green),
                        if (danmakuService.status.value.level == 1)
                          const FCircularProgress(),
                        if (danmakuService.status.value.level == 2)
                          const Icon(Icons.error, color: Colors.red),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('来源: ${danmakuService.episode.value.url}'),
                    const SizedBox(height: 8),
                    Text('剧名: ${danmakuService.episode.value.animeTitle}'),
                    const SizedBox(height: 8),
                    Text('集名: ${danmakuService.episode.value.episodeTitle}'),
                    const SizedBox(height: 8),
                    Text('数量: ${globalService.danmakuCountValue}'),
                  ],
                );
              }),
              mainAxisSize: MainAxisSize.min,
            ),
            const SizedBox(height: 8),
            FButton(
              style: FButtonStyle.secondary(),
              onPress: () => onDrawerChanged(RightDrawerType.danmakuSearch),
              child: const Text('手动搜索获取/更换弹幕'),
            ),
            const SizedBox(height: 8),
            FButton(
              style: FButtonStyle.secondary(),
              onPress: () {
                Navigator.pop(context);
                globalService.showNotification('正在匹配弹幕...');
                playerService.danmakuService.loadDanmaku(force: true);
              },
              child: const Text('重新匹配'),
            ),
            const SizedBox(height: 8),
            FButton(
              style: FButtonStyle.secondary(),
              onPress: () {
                Navigator.pop(context);
                globalService.showNotification('正在加载弹幕...');
                playerService.danmakuService.refreshDanmaku();
              },
              child: const Text('重新加载'),
            ),
          ],
        );
      }),
    );
  }
}
