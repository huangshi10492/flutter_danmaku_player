import 'dart:ui';

import 'package:fldanplay/model/file_item.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/danmaku_match_dialog.dart';
import 'package:fldanplay/widget/error_refresh.dart';
import 'package:fldanplay/widget/icon_switch.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:fldanplay/widget/video_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class FileExplorerPage extends StatefulWidget {
  final String storageKey;
  const FileExplorerPage({super.key, required this.storageKey});

  @override
  State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  Storage? _storage;
  final FileExplorerService _fileExplorerService = GetIt.I
      .get<FileExplorerService>();
  final OfflineCacheService _offlineCacheService = GetIt.I
      .get<OfflineCacheService>();
  final ScrollController _scrollController = ScrollController();
  final Map<String, int> _refreshMap = {};
  bool isFABVisible = true;

  @override
  void initState() {
    init();
    GetIt.I.get<GlobalService>().updateListener = refreshItem;
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    GetIt.I.get<GlobalService>().updateListener = null;
    _fileExplorerService.provider.value?.dispose();
    super.dispose();
  }

  void refreshItem(String uniqueKey) {
    setState(() {
      _refreshMap[uniqueKey] = (_refreshMap[uniqueKey] ?? 0) + 1;
    });
    _refresh();
  }

  void _scrollToRight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void init() async {
    final storageService = GetIt.I.get<StorageService>();
    final storage = storageService.get(widget.storageKey);
    if (storage == null) {
      return;
    }
    late FileExplorerProvider provider;
    switch (storage.storageType) {
      case StorageType.webdav:
        provider = WebDAVFileExplorerProvider(storage);
        break;
      case StorageType.ftp:
        break;
      case StorageType.smb:
        break;
      case StorageType.local:
        provider = LocalFileExplorerProvider(storage.url);
        break;
      default:
        return;
    }
    await provider.init();
    _fileExplorerService.setProvider(provider, storage);
    setState(() {
      _storage = storage;
    });
  }

  void _playVideo(String path, int index) {
    final videoInfo = _fileExplorerService.getVideoInfo(index, path);
    if (GetIt.I.get<ConfigureService>().offlineCacheFirst.value) {
      videoInfo.cached = _offlineCacheService.isCached(videoInfo.uniqueKey);
    }
    if (mounted) {
      final location = Uri(path: videoPlayerPath);
      context.push(location.toString(), extra: videoInfo);
    }
  }

  void _handleOfflineDownload(String path, int index) {
    final videoInfo = _fileExplorerService.getVideoInfo(index, path);
    _offlineCacheService.startDownload(videoInfo);
    if (mounted) showToast(context, title: '${videoInfo.name}已加入离线缓存');
  }

  Future<void> _refresh() async {
    _fileExplorerService.getData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (!_fileExplorerService.back()) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: SysAppBar(title: _storage?.name ?? ''),
        body: _storage == null
            ? const Center(child: CircularProgressIndicator())
            : NotificationListener<UserScrollNotification>(
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
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildBody(),
                ),
              ),
        floatingActionButton: isFABVisible
            ? Watch((context) {
                bool isFiltered = _fileExplorerService.filter.value
                    .isFiltered();
                return FloatingActionButton(
                  onPressed: () => _openConfigSheet(),
                  shape: CircleBorder(),
                  child: isFiltered
                      ? const Icon(FIcons.listFilterPlus)
                      : const Icon(FIcons.listFilter),
                  // backgroundColor: ,
                );
              })
            : null,
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scrollController,
            child: Watch((context) {
              final path = _fileExplorerService.path.watch(context);
              final parts = path.split('/').where((p) => p.isNotEmpty).toList();
              final children = <Widget>[
                FBreadcrumbItem(
                  onPress: () => _fileExplorerService.cd('/'),
                  child: Text(
                    '根目录',
                    style: TextStyle(
                      color: parts.isEmpty
                          ? context.theme.colors.primary
                          : context.theme.colors.foreground,
                    ),
                  ),
                ),
              ];
              var currentPath = '';
              for (var i = 0; i < parts.length; i++) {
                final part = parts[i];
                currentPath += '$part/';
                final targetPath = currentPath;
                final isLast = i == parts.length - 1;
                children.add(
                  FBreadcrumbItem(
                    onPress: isLast
                        ? null
                        : () {
                            _fileExplorerService.cd(targetPath);
                            _scrollToRight();
                          },
                    child: Text(
                      part,
                      style: TextStyle(
                        color: isLast
                            ? context.theme.colors.primary
                            : context.theme.colors.foreground,
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: FBreadcrumb(children: children),
              );
            }),
          ),
        ),
        Expanded(
          child: Watch(
            (context) => _fileExplorerService.files.value.map(
              data: (files) {
                if (files.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FIcons.folder,
                          size: 48,
                          color: context.theme.colors.mutedForeground,
                        ),
                        const SizedBox(height: 16),
                        Text('此文件夹为空', style: context.theme.typography.xl),
                      ],
                    ),
                  );
                }
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: SafeArea(
                        child: FItemGroup(
                          divider: FItemDivider.indented,
                          children: _listBuilder(files),
                        ),
                      ),
                    ),
                  ],
                );
              },
              error: (error, stack) =>
                  ErrorRefresh(error: error.toString(), onRefresh: _refresh),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }

  void _openConfigSheet() {
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
                    child: FileExplorerFilterSheet(
                      service: _fileExplorerService,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<FItemMixin> _listBuilder(List<FileItem> files) {
    final widgetList = <FItemMixin>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      if (file.isFolder) {
        widgetList.add(
          FItem(
            prefix: const Icon(FIcons.folder, size: 40),
            title: Text(
              file.name,
              style: context.theme.typography.base,
              maxLines: 2,
            ),
            subtitle: Text('目录'),
            onPress: () {
              _fileExplorerService.next(file.name);
              _scrollToRight();
            },
          ),
        );
        continue;
      }
      final refreshKey = _refreshMap[file.uniqueKey] ?? 0;
      final videoInfo = _fileExplorerService.getVideoInfo(i, file.path);
      widgetList.add(
        VideoItem(
          key: ValueKey(file.uniqueKey),
          refreshKey: refreshKey,
          history: file.history,
          uniqueKey: file.uniqueKey!,
          name: file.name,
          onOfflineDownload: () =>
              _handleOfflineDownload(file.path, file.videoIndex),
          danmakuMatchDialog: DanmakuMatchDialog(
            uniqueKey: videoInfo.uniqueKey,
            fileName: videoInfo.videoName,
          ),
          onPress: () => _playVideo(file.path, file.videoIndex),
        ),
      );
    }
    return widgetList;
  }
}

class FileExplorerFilterSheet extends StatefulWidget {
  final FileExplorerService service;
  const FileExplorerFilterSheet({super.key, required this.service});
  @override
  State<FileExplorerFilterSheet> createState() =>
      _FileExplorerFilterSheetState();
}

class _FileExplorerFilterSheetState extends State<FileExplorerFilterSheet> {
  late Filter filter = widget.service.filter.value;
  late TextEditingController searchController;
  late int displayMode;
  late bool sortOrder;

  final displayModeOptions = {'全部': 0, '文件夹': 1, '视频': 2};

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() {
    setState(() {
      searchController = TextEditingController(text: filter.searchTerm);
      displayMode = filter.displayMode;
      sortOrder = filter.sortOrder;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    Filter filter = Filter()
      ..searchTerm = searchController.text
      ..displayMode = displayMode
      ..sortOrder = sortOrder;
    widget.service.filter.value = filter;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FButton(
              style: FButtonStyle.ghost(),
              onPress: () {
                filter = Filter();
                init();
              },
              child: const Text('重置'),
            ),
            FButton(onPress: () => _applyFilter(), child: const Text('确定')),
          ],
        ),
        const SizedBox(height: 12),
        FTextField(
          control: .managed(controller: searchController),
          label: Text('搜索'),
          hint: '输入关键词',
        ),
        const SizedBox(height: 12),
        FSelectMenuTile.fromMap(
          selectControl: .lifted(
            value: {displayMode},
            onChange: (value) => setState(() {
              displayMode = value.last;
            }),
          ),
          displayModeOptions,
          title: Text('连载状态'),
          details: Text(
            displayModeOptions.entries
                .firstWhere((e) => e.value == displayMode)
                .key,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: IconSwitch(
                  value: sortOrder,
                  onPress: () {
                    setState(() {
                      sortOrder = !sortOrder;
                    });
                  },
                  icon: FIcons.arrowDownAZ,
                  title: '升序',
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: IconSwitch(
                  value: !sortOrder,
                  onPress: () {
                    setState(() {
                      sortOrder = !sortOrder;
                    });
                  },
                  icon: FIcons.arrowDownZA,
                  title: '降序',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
