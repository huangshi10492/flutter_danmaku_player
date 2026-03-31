import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/page/stream_media/filter_sheet.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/utils/utils.dart';
import 'package:fldanplay/widget/network_image.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

class StreamMediaExplorerPage extends StatefulWidget {
  final String storageKey;
  const StreamMediaExplorerPage({super.key, required this.storageKey});

  @override
  State<StreamMediaExplorerPage> createState() =>
      _StreamMediaExplorerPageState();
}

class _StreamMediaExplorerPageState extends State<StreamMediaExplorerPage> {
  final storageService = GetIt.I.get<StorageService>();
  final streamMediaExplorerService = GetIt.I.get<StreamMediaExplorerService>();
  final Signal<bool> _librariesExpanded = signal(false);
  final ScrollController _resumeScrollController = ScrollController();
  Storage? storage;
  bool isFABVisible = true;
  String? _error;
  List<ResumeItem> _resumeItems = const [];
  TextStyle subtitleStyle(BuildContext context) =>
      context.theme.itemStyles.base.contentStyle.subtitleTextStyle.base;

  @override
  void initState() {
    _initializePage();
    super.initState();
  }

  Future<void> _initializePage() async {
    try {
      final currentStorage = storageService.get(widget.storageKey);
      if (currentStorage == null) {
        setState(() {
          _error = '媒体库不存在';
        });
        return;
      }
      if ((currentStorage.userId ?? '').isEmpty ||
          (currentStorage.token ?? '').isEmpty) {
        setState(() {
          _error = '请先编辑媒体库并登录';
        });
        return;
      }
      final provider = switch (currentStorage.storageType) {
        StorageType.jellyfin => JellyfinStreamMediaExplorerProvider(
          currentStorage.url,
          UserInfo(
            userId: currentStorage.userId!,
            token: currentStorage.token!,
          ),
        ),
        StorageType.emby => EmbyStreamMediaExplorerProvider(
          currentStorage.url,
          UserInfo(
            userId: currentStorage.userId!,
            token: currentStorage.token!,
          ),
        ),
        _ => null,
      };
      if (provider == null) {
        setState(() {
          storage = currentStorage;
          _error = '不支持的媒体库类型';
        });
        return;
      }
      streamMediaExplorerService.setProvider(provider, currentStorage);
      setState(() {
        storage = currentStorage;
        _error = null;
      });
      await streamMediaExplorerService.loadLibraries();
      await _loadResumeItems();
    } catch (e) {
      setState(() {
        _error = '初始化失败: $e';
      });
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      context: context,
      builder: (context) {
        return AnimatedPadding(
          padding: .only(bottom: MediaQuery.of(context).viewInsets.bottom),
          duration: Duration.zero,
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.colors.background,
              borderRadius: const .only(
                topLeft: .circular(8),
                topRight: .circular(8),
              ),
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              minChildSize: 0.4,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const .all(16),
                    child: StreamMediaFilterSheet(),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPrefix() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: .circular(4),
        color: const Color.fromARGB(255, 25, 25, 25),
      ),
      width: double.infinity,
      height: double.infinity,
      child: const Center(
        child: Icon(Icons.play_circle_outline, size: 50, color: Colors.grey),
      ),
    );
  }

  Widget _buildLibraryItem(CollectionItem library, bool selected) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      decoration: BoxDecoration(
        borderRadius: .circular(8),
        border: Border.all(
          color: selected
              ? context.theme.colors.primary
              : context.theme.colors.border,
        ),
      ),
      child: InkWell(
        borderRadius: .circular(8),
        onTap: () => streamMediaExplorerService.libraryId.value = library.id,
        child: Padding(
          padding: const .symmetric(horizontal: 16, vertical: 8),
          child: Text(
            library.name,
            maxLines: 1,
            textAlign: .center,
            overflow: .ellipsis,
            style: context.theme.typography.md.copyWith(
              color: selected ? context.theme.colors.primary : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryToggle() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: .circular(8),
        border: .all(color: context.theme.colors.border),
      ),
      child: InkWell(
        borderRadius: .circular(8),
        onTap: () => _librariesExpanded.value = !_librariesExpanded.value,
        child: Padding(
          padding: const .symmetric(horizontal: 8, vertical: 8),
          child: Watch(
            (context) => AnimatedRotation(
              turns: _librariesExpanded.value ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: const Icon(Icons.chevron_right, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLibraryItem({
    required Widget child,
    required bool visible,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) {
        return IgnorePointer(
          ignoring: value < 0.99,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              heightFactor: value,
              child: Opacity(
                opacity: value,
                child: Padding(padding: .all(4), child: child),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLibrarySection() {
    return Watch((context) {
      final librariesState = streamMediaExplorerService.libraries.value;
      final activeLibraryId = streamMediaExplorerService.libraryId.value;
      return librariesState.map(
        data: (libraries) {
          if (libraries.isEmpty) {
            return Padding(
              padding: const .symmetric(vertical: 8, horizontal: 4),
              child: Text('当前账号下没有可用媒体库', style: context.theme.typography.md),
            );
          }
          return Watch(
            (context) => Wrap(
              crossAxisAlignment: .center,
              children: [
                ...libraries.map((library) {
                  final selected = activeLibraryId == library.id;
                  return _buildAnimatedLibraryItem(
                    visible: selected || _librariesExpanded.value,
                    child: _buildLibraryItem(library, selected),
                  );
                }),
                if (libraries.length > 1)
                  Padding(padding: const .all(4), child: _buildLibraryToggle()),
              ],
            ),
          );
        },
        error: (error, stack) {
          return OutlinedButton(
            onPressed: streamMediaExplorerService.loadLibraries,
            child: const Text('重试'),
          );
        },
        loading: () {
          return Skeletonizer(
            enabled: true,
            child: Wrap(
              crossAxisAlignment: .center,
              children: [
                Padding(
                  padding: const .all(4),
                  child: Container(
                    constraints: BoxConstraints(minWidth: 100),
                    decoration: BoxDecoration(
                      borderRadius: .circular(8),
                      border: .all(color: context.theme.colors.border),
                    ),
                    child: Padding(
                      padding: const .symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        "加载中...",
                        textAlign: .center,
                        style: context.theme.typography.md,
                      ),
                    ),
                  ),
                ),
                Skeleton.shade(child: _buildLibraryToggle()),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildMediaCard(MediaItem mediaItem) {
    return InkWell(
      onTap: () {
        context.push(streamMediaDetailPath, extra: mediaItem);
      },
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          AspectRatio(
            aspectRatio: 0.7,
            child: LayoutBuilder(
              builder: (context, boxConstraints) {
                final double maxWidth = boxConstraints.maxWidth;
                final double maxHeight = boxConstraints.maxHeight;
                return Hero(
                  transitionOnUserGestures: true,
                  tag: mediaItem.id,
                  child: NetworkImageWidget(
                    url: streamMediaExplorerService.getImageUrl(mediaItem.id),
                    headers: streamMediaExplorerService.headers,
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                    radius: maxWidth / 25,
                    errorWidget: _buildEmptyPrefix(),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const .fromLTRB(2, 4, 2, 0),
            child: Text(
              mediaItem.name,
              style: context.theme.typography.sm,
              maxLines: 2,
              overflow: .ellipsis,
              textAlign: .center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadResumeItems() async {
    if (storage?.useRemoteHistory != true) return;
    try {
      final items = await streamMediaExplorerService.fetchResumeItems();
      if (!mounted) return;
      setState(() => _resumeItems = items);
    } catch (e) {
      showToast(level: 3, title: '加载继续观看失败', description: e.toString());
    }
  }

  void _openResumeDetail(ResumeItem item) {
    if (item.seriesId == null) return;
    final detailItem = MediaItem(
      id: item.seriesId!,
      name: item.seriesName ?? item.name,
      type: item.seriesName?.isNotEmpty == true ? MediaType.series : item.type,
    );
    context.push(streamMediaDetailPath, extra: detailItem).then((_) {
      streamMediaExplorerService.refresh();
      _loadResumeItems();
    });
  }

  Widget _buildContinuePlaybackCard(ResumeItem item, width) {
    final title = item.name;
    final subtitle = item.subtitle;
    final imageId = item.mainImage ?? item.fallbackImage;
    final imageUrl = imageId == null || imageId.isEmpty
        ? null
        : streamMediaExplorerService.getImageUrl(imageId);
    final positionMs = (item.playbackPositionTicks / 10000).round();
    final durationMs = ((item.runTimeTicks ?? 0) / 10000).round();
    final progressValue = durationMs <= 0
        ? null
        : (positionMs / durationMs).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => _openResumeDetail(item),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (imageUrl == null) {
                    return _buildEmptyPrefix();
                  }
                  return NetworkImageWidget(
                    url: imageUrl,
                    headers: streamMediaExplorerService.headers,
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                    fit: .contain,
                    errorWidget: _buildEmptyPrefix(),
                  );
                },
              ),
            ),
            Padding(
              padding: const .fromLTRB(2, 4, 2, 2),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: context.theme.typography.sm,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: subtitleStyle(context),
                  ),
                  const SizedBox(height: 4),
                  if (progressValue != null && positionMs > 0)
                    LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 4,
                      borderRadius: .circular(4),
                    ),
                  SizedBox(height: positionMs == 0 ? 8 : 4),
                  Text(
                    positionMs > 0
                        ? Utils.formatTime(positionMs, durationMs)
                        : '未观看',
                    style: subtitleStyle(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueWatchingSection() {
    if (_resumeItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .fromLTRB(4, 0, 0, 4),
          child: Text('继续观看', style: context.theme.typography.xl),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final itemWidth = 120.0 + (screenWidth - 300).clamp(0, 300) * 0.4;
            return SizedBox(
              height: itemWidth / 16 * 9 + 66,
              child: _HorizontalWheelScroll(
                controller: _resumeScrollController,
                child: ListView.separated(
                  controller: _resumeScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _resumeItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return _buildContinuePlaybackCard(
                      _resumeItems[index],
                      itemWidth,
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGridSection() {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.crossAxisExtent;
        const itemSpacing = 8.0;
        final minItemWidth = 100.0 + (screenWidth - 300).clamp(0, 500) * 0.15;
        final crossAxisCount = (screenWidth / (minItemWidth + itemSpacing))
            .floor()
            .clamp(2, 100);
        final itemWidth =
            (screenWidth - itemSpacing * (crossAxisCount + 1)) / crossAxisCount;
        final imageHeight = itemWidth / 0.7;
        const textHeight = 36;
        final totalHeight = imageHeight + textHeight + 6;
        return Watch((context) {
          return streamMediaExplorerService.items.value.map(
            data: (items) {
              return SliverMainAxisGroup(
                slivers: [
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: itemSpacing,
                      mainAxisSpacing: 4,
                      childAspectRatio: itemWidth / totalHeight,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return _buildMediaCard(items[index]);
                    }, childCount: items.length),
                  ),
                  if (items.length >= 300)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: .all(16),
                        child: Text(
                          '最多显示300个结果，更多结果请使用筛选',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              );
            },
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('加载失败\n${error.toString()}')),
            ),
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        });
      },
    );
  }

  Widget _buildBody() {
    if (storage == null) {
      return _error == null
          ? const SizedBox.shrink()
          : Center(child: Text(_error!));
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    return SafeArea(
      minimum: const .symmetric(horizontal: 8),
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == .forward) {
            setState(() => isFABVisible = true);
          }
          if (notification.direction == .reverse) {
            setState(() => isFABVisible = false);
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildLibrarySection()),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            SliverToBoxAdapter(child: _buildContinueWatchingSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            _buildGridSection(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(title: storage?.name ?? ''),
      body: _buildBody(),
      floatingActionButton: isFABVisible
          ? Watch((context) {
              final isFiltered = streamMediaExplorerService.filter.value
                  .isFiltered();
              return FloatingActionButton(
                onPressed: () => _openFilterSheet(),
                shape: const CircleBorder(),
                child: isFiltered
                    ? const Icon(FIcons.listFilterPlus)
                    : const Icon(FIcons.listFilter),
              );
            })
          : null,
    );
  }
}

class _HorizontalWheelScroll extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  const _HorizontalWheelScroll({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent || !controller.hasClients) return;
        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
          final delta = event.scrollDelta.dx == 0
              ? event.scrollDelta.dy
              : event.scrollDelta.dx;
          final nextOffset = (controller.offset + delta).clamp(
            controller.position.minScrollExtent,
            controller.position.maxScrollExtent,
          );
          if (nextOffset != controller.offset) {
            controller.jumpTo(nextOffset);
          }
        });
      },
      child: child,
    );
  }
}
