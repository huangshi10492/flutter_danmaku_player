import 'dart:io';

import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/danmaku_match_dialog.dart';
import 'package:fldanplay/widget/network_image.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:path_provider/path_provider.dart';
import '../model/history.dart';

class FileImageEx extends FileImage {
  late final int fileSize;
  FileImageEx(File file, {double scale = 1.0}) : super(file, scale: scale) {
    fileSize = file.lengthSync();
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is FileImageEx &&
        other.file.path == file.path &&
        other.scale == scale &&
        other.fileSize == fileSize;
  }

  @override
  int get hashCode => fileSize.hashCode;
}

class VideoItem extends StatefulWidget with FItemMixin {
  final History? history;
  final String uniqueKey;
  final String name;
  final void Function() onPress;
  final void Function()? onLongPress;
  final int refreshKey;
  final String? imageUrl;
  final Map<String, String>? headers;
  final Function()? onOfflineDownload;
  final DanmakuMatchDialog? danmakuMatchDialog;
  const VideoItem({
    super.key,
    required this.history,
    required this.uniqueKey,
    required this.name,
    required this.onPress,
    this.onLongPress,
    required this.refreshKey,
    this.imageUrl,
    this.headers,
    this.onOfflineDownload,
    this.danmakuMatchDialog,
  });
  @override
  State<VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> {
  late Future<Widget> _prefixFuture;
  bool _hasDanmaku = false;

  @override
  void initState() {
    super.initState();
    _prefixFuture = _buildPrefix(widget.history);
    init();
  }

  Future<void> init() async {
    final directory = await getApplicationSupportDirectory();
    final res = File('${directory.path}/danmaku/${widget.uniqueKey}.json');
    final hasDanmaku = await res.exists();
    setState(() {
      _hasDanmaku = hasDanmaku;
    });
  }

  @override
  void didUpdateWidget(VideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      setState(() {
        _prefixFuture = _buildPrefix(widget.history);
      });
    }
  }

  Widget _buildEmtpyPrefix() {
    return LayoutBuilder(
      builder: (context, boxConstraints) {
        final double maxWidth = boxConstraints.maxWidth;
        final double maxHeight = boxConstraints.maxHeight;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: const Color.fromARGB(255, 25, 25, 25),
          ),
          width: maxWidth,
          height: maxHeight,
          child: Center(
            child: const Icon(
              Icons.play_circle_outline,
              size: 30,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDanmakuIcon() {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colors.primary,
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      margin: EdgeInsets.only(top: 2, right: 2),
      child: Text(
        '弹',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: context.theme.colors.primaryForeground,
        ),
      ),
    );
  }

  Future<Widget> _buildPrefix(History? history) async {
    if (history != null) {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/screenshots/${history.uniqueKey}');
      bool hasLocalImage = false;
      if (await file.exists()) hasLocalImage = true;
      return LayoutBuilder(
        builder: (context, boxConstraints) {
          final double maxWidth = boxConstraints.maxWidth;
          final double maxHeight = boxConstraints.maxHeight;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Builder(
                  builder: (context) {
                    if (hasLocalImage) {
                      return Image(
                        image: FileImageEx(file),
                        fit: BoxFit.fitHeight,
                        width: maxWidth,
                        height: maxHeight,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildEmtpyPrefix();
                        },
                      );
                    }
                    if (widget.imageUrl != null) return _buildImage();
                    return _buildEmtpyPrefix();
                  },
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    Utils.formatTime(history.position, history.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
    if (widget.imageUrl != null) return _buildImage();
    return _buildEmtpyPrefix();
  }

  Widget _buildImage() {
    return LayoutBuilder(
      builder: (context, boxConstraints) {
        final double maxWidth = boxConstraints.maxWidth;
        final double maxHeight = boxConstraints.maxHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: NetworkImageWidget(
            url: widget.imageUrl!,
            headers: widget.headers,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            errorWidget: _buildEmtpyPrefix(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = 0;
    int progressPercent = 0;
    String lastWatchTime = '';
    if (widget.history != null) {
      progress = widget.history!.duration > 0
          ? (widget.history!.position / widget.history!.duration).clamp(
              0.0,
              1.0,
            )
          : 0.0;
      progressPercent = (progress * 100).round();
      lastWatchTime = Utils.formatLastWatchTime(widget.history!.updateTime);
    }
    final subtitleStyle =
        context.theme.itemStyles.base.contentStyle.subtitleTextStyle.base;
    return _PopoverMenu(
      download: widget.onOfflineDownload ?? () {},
      matchDanmaku: () async {
        if (widget.danmakuMatchDialog == null) return;
        await showFDialog(
          context: context,
          builder: (context, style, animation) => FDialog(
            style: style,
            animation: animation,
            actions: [],
            body: widget.danmakuMatchDialog!,
          ),
        );
        init();
      },
      child: (controller) => FItem(
        prefix: SizedBox(
          width: 95,
          height: 65,
          child: FutureBuilder(
            future: _prefixFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasData) {
                return snapshot.data!;
              }
              return _buildEmtpyPrefix();
            },
          ),
        ),
        title: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 65),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FTooltip(
                tipBuilder: (context, controller) => Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 50,
                  ),
                  child: Text(widget.name),
                ),
                child: Text(
                  widget.name,
                  style: context.theme.typography.base,
                  maxLines: 2,
                ),
              ),
              widget.history != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        widget.history!.subtitle == null
                            ? const SizedBox()
                            : Text(
                                widget.history!.subtitle!,
                                style: subtitleStyle,
                              ),
                        const SizedBox(height: 4),
                        FDeterminateProgress(
                          value: progress,
                          style: .delta(
                            motion: .delta(duration: Duration.zero),
                            constraints: .tightFor(height: 4),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                if (_hasDanmaku) _buildDanmakuIcon(),
                                Text(style: subtitleStyle, lastWatchTime),
                              ],
                            ),
                            Text(style: subtitleStyle, '$progressPercent%'),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        if (_hasDanmaku) _buildDanmakuIcon(),
                        Text(style: subtitleStyle, '未观看'),
                      ],
                    ),
            ],
          ),
        ),
        onPress: widget.onPress,
        onLongPress: widget.onLongPress ?? controller.toggle,
        onSecondaryPress: widget.onLongPress ?? controller.toggle,
      ),
    );
  }
}

class _PopoverMenu extends StatefulWidget with FItemMixin {
  final Function download;
  final Function matchDanmaku;
  final Widget Function(FPopoverController controller) child;
  const _PopoverMenu({
    required this.download,
    required this.matchDanmaku,
    required this.child,
  });
  @override
  _PopoverMenuState createState() => _PopoverMenuState();
}

class _PopoverMenuState extends State<_PopoverMenu>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final controller = FPopoverController(vsync: this);
    return FPopoverMenu.tiles(
      control: .managed(controller: controller),
      menu: [
        FTileGroup(
          children: [
            FTile(
              prefix: const Icon(FIcons.download),
              title: Text('离线保存'),
              onPress: () {
                controller.toggle();
                widget.download();
              },
            ),
            FTile(
              prefix: const Icon(FIcons.captions),
              title: Text('获取并保存弹幕'),
              onPress: () {
                controller.toggle();
                widget.matchDanmaku();
              },
            ),
          ],
        ),
      ],
      child: widget.child(controller),
    );
  }
}
