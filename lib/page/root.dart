import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/theme/widget/adaptive_dialog.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/utils/icon.dart';
import 'package:fldanplay/utils/theme.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/widget/context_menu.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../model/storage.dart';
import '../model/history.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => RootPageState();
}

class RootPageState extends State<RootPage> {
  final _storageService = GetIt.I.get<StorageService>();
  final _globalService = GetIt.I.get<GlobalService>();
  bool uping = false;

  @override
  void initState() {
    super.initState();
    upgrade();
  }

  Future<void> upgrade() async {
    int breakVersion = 2;
    final cs = GetIt.I.get<ConfigureService>();
    while (cs.breakVersion.value < breakVersion) {
      setState(() => uping = true);
      switch (cs.breakVersion.value) {
        case 0:
          await GetIt.I.get<StorageService>().migrateLibraries();
          cs.breakVersion.value = 1;
        case 1:
          await GetIt.I.get<HistoryService>().migrateUniqueKeys();
          await GetIt.I.get<OfflineCacheService>().migrateUniqueKeys();
          cs.breakVersion.value = 2;
      }
    }
    setState(() => uping = false);
  }

  void _showPlayVideoDialog() {
    showFDialog(
      context: context,
      builder: (context, style, animation) => AdaptiveDialog(
        style: style,
        animation: animation,
        title: const Text('选择视频来源'),
        body: const Text('网络视频只支持http(s)协议'),
        actions: [
          FButton(
            variant: .outline,
            onPress: () {
              Navigator.pop(context);
              _playLocalVideo();
            },
            child: const Text('本地'),
          ),
          FButton(
            variant: .outline,
            onPress: () {
              Navigator.pop(context);
              _playNetworkVideo();
            },
            child: const Text('网络'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefix(StorageType type) {
    switch (type) {
      case StorageType.webdav:
        return const Icon(FLucideIcons.server);
      case StorageType.ftp:
        return const Icon(MyIcon.ftp);
      case StorageType.smb:
        return const Icon(MyIcon.smb);
      case StorageType.local:
        return const Icon(FLucideIcons.folder);
      case StorageType.jellyfin:
        return const Icon(MyIcon.jellyfin);
      case StorageType.emby:
        return const Icon(MyIcon.emby);
    }
  }

  Future<void> _playLocalVideo() async {
    try {
      PlatformFile? result = await FilePicker.pickFile(type: FileType.video);
      if (result != null && result.path != null) {
        final filePath = result.path!;
        final videoInfo = VideoInfo.fromFile(
          currentVideoPath: filePath,
          virtualVideoPath: filePath,
          historiesType: HistoriesType.local,
        );
        if (mounted) {
          final location = Uri(path: videoPlayerPath);
          context.push(location.toString(), extra: videoInfo);
        }
      }
    } catch (e) {
      showToast(level: 3, title: '选择文件失败', description: e.toString());
    }
  }

  Future<void> _playNetworkVideo() async {
    try {
      showFDialog(
        context: context,
        builder: (context, style, animation) {
          final controller = TextEditingController();
          return AdaptiveDialog(
            style: style,
            animation: animation,
            title: Text('请输入视频URL'),
            body: FTextField(
              control: .managed(controller: controller),
              autofocus: true,
            ),
            actions: [
              FButton(
                onPress: () {
                  final input = controller.text.trim();
                  if (input.isEmpty) return;
                  final uri = Uri.tryParse(input);
                  if (uri == null ||
                      !uri.hasAbsolutePath ||
                      (uri.scheme != 'http' && uri.scheme != 'https') ||
                      uri.host.isEmpty) {
                    showToast(level: 2, title: '请输入有效的网络视频URL');
                    return;
                  }
                  final videoUrl = uri.toString();
                  final fileName = uri.pathSegments.isNotEmpty
                      ? uri.pathSegments.last
                      : videoUrl;
                  final videoInfo = VideoInfo(
                    currentVideoPath: videoUrl,
                    virtualVideoPath: videoUrl,
                    historiesType: HistoriesType.network,
                    videoName: Utils.removeExtension(fileName),
                    name: fileName,
                  );
                  final location = Uri(path: videoPlayerPath);
                  this.context.push(location.toString(), extra: videoInfo);
                  Navigator.pop(context);
                },
                child: const Text('确定'),
              ),
              FButton(
                variant: .outline,
                onPress: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      showToast(level: 3, title: '播放视频失败', description: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uping) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: .min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在迁移数据，请保持当前界面'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: SysAppBar(
        title: '主页',
        actions: [
          Stack(
            alignment: .topEnd,
            children: [
              FButton.icon(
                variant: .ghost,
                child: const Icon(FLucideIcons.settings, size: 24),
                onPress: () => context.push(settingsPath),
              ),
              SignalBuilder(
                builder: (context) {
                  if (_globalService.updateInfo.value != null &&
                      _globalService.updateInfo.value!.hasUpdate) {
                    return Padding(
                      padding: .all(6),
                      child: FBadge.raw(
                        builder: (context, style) =>
                            const SizedBox(width: 8, height: 8),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      ),
      body: SignalBuilder(
        builder: (_) {
          final storages = _storageService.storages.value;
          return SingleChildScrollView(
            child: SafeArea(
              child: FItemGroup(
                divider: FItemDivider.indented,
                style: .delta(
                  itemStyles: .delta([
                    .all(
                      .delta(
                        contentStyle: .delta(
                          titleTextStyle: .delta([
                            .base(.delta(fontSize: 18, height: 1.75)),
                          ]),
                          prefixIconStyle: .delta([.base(.delta(size: 32))]),
                          subtitleTextStyle: .delta([
                            .base(.delta(fontSize: 12, height: 1)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
                children: [
                  FItem(
                    prefix: const Icon(FLucideIcons.clock),
                    title: const Text('观看历史'),
                    subtitle: Text('查看观看历史'),
                    autofocus: true,
                    onPress: () => context.push(historyPath),
                  ),
                  FItem(
                    prefix: const Icon(FLucideIcons.download),
                    title: const Text('离线缓存'),
                    subtitle: Text('查看已缓存的视频'),
                    onPress: () => context.push(offlineCachePath),
                  ),
                  FItem(
                    prefix: const Icon(FLucideIcons.play),
                    title: const Text('选择视频播放'),
                    subtitle: Text('选择本地视频或网络视频'),
                    onPress: () => _showPlayVideoDialog(),
                  ),
                  ...storages.map(
                    (storage) => ContextMenu(
                      items: [
                        .new(
                          icon: FLucideIcons.pencil,
                          title: '编辑',
                          onPress: () => context.push(
                            '$storageEditPath?storage_key=${storage.key}&storage_type=${storage.storageType.name}',
                          ),
                        ),
                        .new(
                          icon: FLucideIcons.trash,
                          title: '删除',
                          variant: .destructive,
                          onPress: () => showConfirmDialog(
                            context,
                            title: '删除媒体库',
                            content: '是否删除媒体库"${storage.name}"？',
                            onConfirm: () =>
                                _storageService.delete(storage.key),
                            confirmText: '删除',
                            destructive: true,
                          ),
                        ),
                      ],
                      onOpen: () {
                        switch (storage.storageType) {
                          case StorageType.webdav:
                          case StorageType.ftp:
                          case StorageType.smb:
                          case StorageType.local:
                            context.push(
                              '$fileExplorerPath?key=${storage.key}',
                            );
                            break;
                          case StorageType.jellyfin:
                          case StorageType.emby:
                            context.push(
                              '$streamMediaExplorerPath?key=${storage.key}',
                            );
                            break;
                        }
                      },
                      child: (onPress, focusNode) => FItem(
                        prefix: _buildPrefix(storage.storageType),
                        title: Text(storage.name),
                        subtitle: Text(storage.subtitle),
                        focusNode: focusNode,
                        onPress: onPress,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加媒体库',
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (context) {
            return SelectStorageTypeSheet();
          },
        ),
        shape: CircleBorder(),
        child: const Icon(FLucideIcons.plus),
      ),
    );
  }
}

class SelectStorageTypeSheet extends StatelessWidget {
  const SelectStorageTypeSheet({super.key});

  void select(BuildContext context, StorageType storageType) {
    context.pop();
    context.push('$storageEditPath?storage_type=${storageType.name}');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SafeArea(
        minimum: const .all(8),
        child: Column(
          mainAxisSize: .min,
          children: [
            Text('选择媒体库类型', style: context.theme.typography.body.lg),
            const SizedBox(height: 8),
            FItemGroup(
              style: settingsItemGroupStyle,
              children: StorageType.values
                  .map(
                    (e) => FItem(
                      title: Text(e.label),
                      prefix: Icon(e.icon),
                      onPress: () => select(context, e),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
