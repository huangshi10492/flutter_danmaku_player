import 'package:fldanplay/model/video_info.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/theme/widget/adaptive_dialog.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/utils/icon.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/storage_sheet.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
                    (storage) => _ContextMenu(
                      edit: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          enableDrag: false,
                          builder: (context) {
                            return AnimatedPadding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(
                                  context,
                                ).viewInsets.bottom,
                              ),
                              duration: Duration.zero,
                              child: EditStorageSheet(
                                storageKey: storage.key,
                                storageType: storage.storageType,
                              ),
                            );
                          },
                        );
                      },
                      delete: () => showConfirmDialog(
                        context,
                        title: '删除媒体库',
                        content: '是否删除媒体库"${storage.name}"？',
                        onConfirm: () => storage.delete(),
                        confirmText: '删除',
                        destructive: true,
                      ),
                      childOnPress: () {
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
                      child: (onPress) => FItem(
                        prefix: _buildPrefix(storage.storageType),
                        title: Text(storage.name),
                        subtitle: Text(storage.url),
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

class _ContextMenu extends StatefulWidget with FItemMixin {
  final VoidCallback edit;
  final VoidCallback delete;
  final VoidCallback childOnPress;
  final FItem Function(VoidCallback onPress) child;
  const _ContextMenu({
    required this.edit,
    required this.delete,
    required this.childOnPress,
    required this.child,
  });
  @override
  _ContextMenuState createState() => _ContextMenuState();
}

class _ContextMenuState extends State<_ContextMenu>
    with TickerProviderStateMixin {
  late final FPopoverController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FPopoverController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _closeAndRun(VoidCallback action) async {
    await _controller.hide();
    if (mounted) action();
  }

  @override
  Widget build(BuildContext context) {
    final dpadEnabled = GetIt.I.get<ConfigureService>().dpadEnable.value;
    return FContextMenu.tiles(
      control: .managed(controller: _controller),
      menu: [
        .group(
          divider: .full,
          children: [
            if (dpadEnabled)
              .tile(
                prefix: const Icon(FLucideIcons.play),
                title: Text('打开'),
                autofocus: true,
                onPress: () => _closeAndRun(widget.childOnPress),
              ),
            .tile(
              prefix: const Icon(FLucideIcons.pencil),
              title: Text('编辑'),
              autofocus: !dpadEnabled,
              onPress: () => _closeAndRun(widget.edit),
            ),
            .tile(
              variant: .destructive,
              prefix: Icon(FLucideIcons.trash),
              title: Text('删除'),
              onPress: () => _closeAndRun(widget.delete),
            ),
          ],
        ),
      ],
      child: widget.child(
        dpadEnabled ? () => _controller.show() : widget.childOnPress,
      ),
    );
  }
}
