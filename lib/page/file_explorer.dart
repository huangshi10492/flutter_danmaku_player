import 'dart:ui';

import 'package:fldanplay/model/file_item.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/file_explorer.dart';
import 'package:fldanplay/service/history.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/service/storage.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/utils/theme.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/error_refresh.dart';
import 'package:fldanplay/widget/icon_switch.dart';
import 'package:fldanplay/widget/sys_app_bar.dart';
import 'package:fldanplay/widget/video_item.dart';
import 'package:flutter/material.dart';
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
  String? _initError;
  final FileExplorerService _fileExplorerService = GetIt.I
      .get<FileExplorerService>();
  final OfflineCacheService _offlineCacheService = GetIt.I
      .get<OfflineCacheService>();
  final _historyService = GetIt.I.get<HistoryService>();
  final ScrollController _scrollController = ScrollController();
  final Map<String, int> _refreshMap = {};
  FocusNode? _focusNode;
  final List<String> _enteredStack = [];
  String? _pendingFocusKey;
  bool get _dpadEnabled => GetIt.I.get<ConfigureService>().dpadEnable.value;

  @override
  void initState() {
    init();
    GetIt.I.get<GlobalService>().updateListener = refreshItem;
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode?.dispose();
    GetIt.I.get<GlobalService>().updateListener = null;
    _fileExplorerService.provider.value?.dispose();
    super.dispose();
  }

  FocusNode? _getFocusNode(String key, int index) {
    if (!_dpadEnabled) return null;
    if (_pendingFocusKey != key) {
      if (_pendingFocusKey != null || index != 0) return null;
    }
    _focusNode?.dispose();
    _focusNode = FocusNode(debugLabel: 'file-explorer-$key-$index');
    return _focusNode;
  }

  void _requestFocus() {
    if (!_dpadEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusNode == null) return;
      _focusNode?.requestFocus();
      Scrollable.ensureVisible(
        _focusNode!.context!,
        duration: const Duration(milliseconds: 200),
        alignmentPolicy: .keepVisibleAtEnd,
      );
    });
  }

  void _openFolder(FileItem file) {
    _enteredStack.add(file.uniqueKey);
    _pendingFocusKey = null;
    _fileExplorerService.next(file.name);
    _scrollToRight();
  }

  void _navigateToDirectory(String path) {
    _enteredStack.clear();
    _pendingFocusKey = null;
    _fileExplorerService.cd(path);
  }

  void _navigateBack() {
    if (!_fileExplorerService.back()) {
      context.pop();
      return;
    }
    _pendingFocusKey = _enteredStack.isEmpty
        ? null
        : _enteredStack.removeLast();
  }

  void refreshItem(String uniqueKey) {
    setState(() {
      _refreshMap[uniqueKey] = (_refreshMap[uniqueKey] ?? 0) + 1;
    });
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
    try {
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
          return;
        case StorageType.smb:
          return;
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
        _initError = null;
      });
    } catch (e) {
      setState(() {
        _initError = e.toString();
      });
    }
  }

  void _playVideo(String path, int index) {
    final videoInfo = _fileExplorerService.getVideoInfo(index, path);
    if (GetIt.I.get<ConfigureService>().offlineCacheFirst.value) {
      videoInfo.cached = _offlineCacheService.isCached(videoInfo.uniqueKey);
    }
    _pendingFocusKey = videoInfo.uniqueKey;
    final location = Uri(path: videoPlayerPath);
    context.push(location.toString(), extra: videoInfo);
  }

  void _handleOfflineDownload(String path, int index) {
    final videoInfo = _fileExplorerService.getVideoInfo(index, path);
    _offlineCacheService.startDownload(videoInfo);
    showToast(title: '${videoInfo.name}已加入离线缓存');
  }

  Future<void> _retryInit() async {
    setState(() {
      _storage = null;
      _initError = null;
    });
    init();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _navigateBack();
      },
      child: Scaffold(
        appBar: SysAppBar(
          title: _storage?.name ?? '',
          actions: [
            SignalBuilder(
              builder: (context) {
                final isFiltered = _fileExplorerService.filter.value
                    .isFiltered();
                return FButton.icon(
                  variant: .ghost,
                  onPress: () => _openConfigSheet(),
                  child: Icon(
                    FLucideIcons.listFilter,
                    size: 24,
                    color: isFiltered ? context.theme.colors.primary : null,
                  ),
                );
              },
            ),
          ],
        ),
        body: _initError != null
            ? ErrorRefresh(error: _initError!, onRefresh: _retryInit)
            : _storage == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async =>
                    _fileExplorerService.getData(load: false),
                child: _buildBody(),
              ),
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
            child: SignalBuilder(
              builder: (context) {
                final path = _fileExplorerService.path;
                final parts = path
                    .split('/')
                    .where((p) => p.isNotEmpty)
                    .toList();
                final children = <Widget>[
                  FBreadcrumbItem(
                    onPress: () => _navigateToDirectory('/'),
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
                          : () => _navigateToDirectory(targetPath),
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
              },
            ),
          ),
        ),
        Expanded(
          child: SignalBuilder(
            builder: (context) => _fileExplorerService.files.value.map(
              data: (files) {
                if (files.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FLucideIcons.folder,
                          size: 48,
                          color: context.theme.colors.mutedForeground,
                        ),
                        Text(
                          '此文件夹为空',
                          style: context.theme.typography.display.xl,
                        ),
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
                          style: settingsItemGroupStyle,
                          children: _listBuilder(files),
                        ),
                      ),
                    ),
                  ],
                );
              },
              error: (error, stack) => ErrorRefresh(
                error: error.toString(),
                onRefresh: _fileExplorerService.getData,
              ),
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
      final focusNode = _getFocusNode(file.uniqueKey, i);
      if (file.isFolder) {
        widgetList.add(
          FItem(
            key: ValueKey(file.uniqueKey),
            focusNode: focusNode,
            prefix: const Icon(FLucideIcons.folder, size: 40),
            title: Text(file.name, maxLines: 2),
            subtitle: Text('目录'),
            onPress: () => _openFolder(file),
          ),
        );
        continue;
      }
      final refreshKey = _refreshMap[file.uniqueKey] ?? 0;
      final history = _historyService.getHistory(file.uniqueKey);
      final videoInfo = _fileExplorerService.getVideoInfo(i, file.path);
      widgetList.add(
        VideoItem(
          key: ValueKey(file.uniqueKey),
          refreshKey: refreshKey,
          history: history,
          uniqueKey: file.uniqueKey,
          name: file.name,
          focusNode: focusNode,
          danmakuMatchInfo: .fromVideoInfo(videoInfo),
          onPress: () => _playVideo(file.path, file.videoIndex),
          items: [
            .new(
              icon: FLucideIcons.download,
              title: '离线保存',
              onPress: () => _handleOfflineDownload(file.path, file.videoIndex),
            ),
            if (history != null)
              .new(
                icon: FLucideIcons.trash,
                variant: .destructive,
                title: '删除历史记录',
                onPress: () {
                  showConfirmDialog(
                    context,
                    title: '删除历史记录',
                    content: '是否删除观看历史？',
                    onConfirm: () async {
                      await _historyService.delete(history: history);
                      refreshItem(file.uniqueKey);
                    },
                    confirmText: '删除',
                    destructive: true,
                  );
                },
              ),
          ],
        ),
      );
    }
    _requestFocus();
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
              variant: .ghost,
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
        FSelectMenuTile<int>(
          menu: [
            for (final MapEntry(:key, :value) in displayModeOptions.entries)
              .tile(
                title: Text(key),
                value: value,
                autofocus: displayMode == value,
              ),
          ],
          selectControl: .lifted(
            value: {displayMode},
            onChange: (value) => setState(() {
              displayMode = value.last;
            }),
          ),
          title: Text('内容类型'),
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
                  icon: FLucideIcons.arrowDownAZ,
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
                  icon: FLucideIcons.arrowDownZA,
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
