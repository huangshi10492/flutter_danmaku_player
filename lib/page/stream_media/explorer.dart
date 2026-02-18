import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/page/stream_media/filter_sheet.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/widget/network_image.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

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
  late StreamMediaExplorerProvider provider;
  Storage? storage;
  bool isFABVisible = true;
  @override
  void initState() {
    storage = storageService.get(widget.storageKey);
    if (storage != null) {
      switch (storage!.storageType) {
        case StorageType.jellyfin:
          provider = JellyfinStreamMediaExplorerProvider(
            storage!.url,
            UserInfo(userId: storage!.userId!, token: storage!.token!),
          );
          break;
        case StorageType.emby:
          provider = EmbyStreamMediaExplorerProvider(
            storage!.url,
            UserInfo(userId: storage!.userId!, token: storage!.token!),
          );
          break;
        default:
          storage = null;
          return;
      }
      streamMediaExplorerService.setProvider(provider, storage!);
    }
    super.initState();
  }

  void _openConfigSheet(StreamMediaExplorerService service) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      context: context,
      builder: (context) {
        return AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          duration: Duration.zero,
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.colors.background,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
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
                    padding: const EdgeInsets.all(16),
                    child: StreamMediaFilterSheet(service: service),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
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
              Icons.folder_outlined,
              size: 70,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaCard(MediaItem mediaItem) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: Border.all(color: Colors.transparent),
      child: InkWell(
        onTap: () {
          context.push(streamMediaDetailPath, extra: mediaItem);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      url: provider.getImageUrl(mediaItem.id),
                      headers: provider.headers,
                      maxWidth: maxWidth,
                      maxHeight: maxHeight,
                      errorWidget: _buildEmtpyPrefix(),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const .symmetric(horizontal: 2, vertical: 2),
              child: Text(
                mediaItem.name,
                style: context.theme.typography.sm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (storage == null) {
      return Scaffold(
        appBar: SysAppBar(title: '媒体库'),
        body: const Center(child: Text('媒体库不存在')),
      );
    }
    return Scaffold(
      appBar: SysAppBar(title: storage!.name),
      body: Watch((context) {
        return streamMediaExplorerService.items.value.map(
          data: (items) {
            return SafeArea(
              minimum: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  const itemSpacing = 8.0;
                  final minItemWidth =
                      100.0 + (screenWidth - 300).clamp(0, 500) * 0.15;
                  final crossAxisCount =
                      (screenWidth / (minItemWidth + itemSpacing))
                          .floor()
                          .clamp(2, 100);
                  final itemWidth =
                      (screenWidth - itemSpacing * (crossAxisCount + 1)) /
                      crossAxisCount;
                  final imageHeight = itemWidth / 0.7;
                  final textHeight = 36;
                  final totalHeight = imageHeight + textHeight + 4.0;
                  return NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.direction == ScrollDirection.forward) {
                        setState(() {
                          isFABVisible = true;
                        });
                      }
                      if (notification.direction == ScrollDirection.reverse) {
                        setState(() {
                          isFABVisible = false;
                        });
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      slivers: [
                        SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: itemSpacing,
                                mainAxisSpacing: 4,
                                childAspectRatio: itemWidth / totalHeight,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            BuildContext context,
                            int index,
                          ) {
                            return _buildMediaCard(items[index]);
                          }, childCount: items.length),
                        ),
                        if (items.length == 300)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                '最多显示300个结果，更多结果请使用筛选',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
          error: (error, stack) =>
              Center(child: Text('加载失败\n${error.toString()}')),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
      }),
      floatingActionButton: isFABVisible
          ? Watch((context) {
              bool isFiltered = streamMediaExplorerService.filter.value
                  .isFiltered();
              return FloatingActionButton(
                onPressed: () => _openConfigSheet(streamMediaExplorerService),
                shape: CircleBorder(),
                child: isFiltered
                    ? const Icon(FIcons.listFilterPlus)
                    : const Icon(FIcons.listFilter),
                // backgroundColor: ,
              );
            })
          : null,
    );
  }
}
