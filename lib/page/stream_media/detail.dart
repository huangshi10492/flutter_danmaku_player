import 'dart:ui';

import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/page/stream_media/info_card.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/crypto_utils.dart';
import 'package:fldanplay/utils/dialog.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/error_refresh.dart';
import 'package:fldanplay/widget/network_image.dart';
import 'package:fldanplay/widget/video_item.dart';
import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class StreamMediaDetailPage extends StatefulWidget {
  final MediaItem mediaItem;
  const StreamMediaDetailPage({super.key, required this.mediaItem});

  @override
  State<StreamMediaDetailPage> createState() => _StreamMediaDetailPageState();
}

class _StreamMediaDetailPageState extends State<StreamMediaDetailPage>
    with TickerProviderStateMixin {
  final StreamMediaExplorerService _service = GetIt.I
      .get<StreamMediaExplorerService>();
  final OfflineCacheService _offlineCacheService = GetIt.I
      .get<OfflineCacheService>();

  late TabController _tabController;
  MediaDetail? _mediaDetail;
  ResumeItem? _continueItem;
  bool _isLoading = true;
  String? _error;
  final Map<String, int> _refreshMap = {};
  final FocusNode _continueFocusNode = FocusNode();
  final FocusNode _actionFocusNode = FocusNode();
  final Signal<bool> _isPlaying = signal(false);
  bool get _showContinueSection =>
      _service.storage?.useRemoteHistory == true && _continueItem != null;
  bool get _dpadEnabled => GetIt.I.get<ConfigureService>().dpadEnable.value;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _initialize();
    GetIt.I.get<GlobalService>().updateListener = refreshItem;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _continueFocusNode.dispose();
    _actionFocusNode.dispose();
    GetIt.I.get<GlobalService>().updateListener = null;
    super.dispose();
  }

  Future<void> _initialize() async {
    await Future.wait([_loadMediaDetail(), _loadContinueItem()]);
    if (!_dpadEnabled || !mounted) return;
    final node = _continueItem == null ? _actionFocusNode : _continueFocusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || node.context == null) return;
      node.requestFocus();
    });
  }

  void refreshItem(String uniqueKey) {
    _loadContinueItem();
    setState(() {
      _refreshMap[uniqueKey] = (_refreshMap[uniqueKey] ?? 0) + 1;
    });
  }

  Future<void> _loadMediaDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final detail = await _service.getMediaDetail(widget.mediaItem.id);
      if (!mounted) return;
      setState(() {
        _mediaDetail = detail;
        _isLoading = false;
        _tabController.dispose();
        _tabController = TabController(
          length: detail.seasons.length,
          vsync: this,
        );
      });
      _tabController.addListener(_handleTabChanged);
      if (detail.seasons.isNotEmpty) {
        await _loadEpisodes(detail.seasons.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging || _mediaDetail == null) return;
    final seasons = _mediaDetail!.seasons;
    if (_tabController.index < 0 || _tabController.index >= seasons.length) {
      return;
    }
    _loadEpisodes(seasons[_tabController.index]);
  }

  Future<void> _loadEpisodes(
    SeasonInfo season, {
    bool forceRefresh = false,
  }) async {
    await _service.getEpisodes(
      season.id,
      _mediaDetail?.type ?? .movie,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _loadContinueItem() async {
    if (_service.useRemoteHistory != true) return;
    try {
      final items = await _service.fetchResumeItems(
        parentId: widget.mediaItem.id,
      );
      if (!mounted) return;
      setState(() {
        _continueItem = items.isEmpty ? null : items.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (!_service.useRemoteHistory) return;
    final mediaDetail = _mediaDetail;
    if (mediaDetail == null) return;
    final nextValue = !mediaDetail.isFavorite;
    try {
      await _service.setFavorite(widget.mediaItem.id, nextValue);
      if (!mounted) return;
      setState(() {
        _mediaDetail = mediaDetail.copyWith(isFavorite: nextValue);
      });
    } catch (e) {
      showToast(
        level: 3,
        title: nextValue ? '收藏失败' : '取消收藏失败',
        description: e.toString(),
      );
    }
  }

  Future<void> _playContinueItem() async {
    final item = _continueItem;
    if (item == null || _isPlaying.value) return;
    _isPlaying.value = true;
    try {
      final videoInfo = await _service.item2VideoInfo(item.id);
      if (!mounted) return;
      final location = Uri(path: videoPlayerPath);
      await context.push(location.toString(), extra: videoInfo);
    } catch (e) {
      showToast(level: 3, title: '播放失败', description: e.toString());
    } finally {
      _isPlaying.value = false;
    }
  }

  Future<void> _onPlayEpisode(SeasonInfo season, int index) async {
    if (_isPlaying.value) return;
    _isPlaying.value = true;
    try {
      final videoInfo = await _service.season2VideoInfo(season.id, index);
      if (mounted) {
        final location = Uri(path: videoPlayerPath);
        context.push(location.toString(), extra: videoInfo);
      }
    } catch (e) {
      showToast(level: 3, title: '播放失败', description: e.toString());
    } finally {
      _isPlaying.value = false;
    }
  }

  void _onDownloadEpisode(SeasonInfo season, int index) {
    _service.selectPlaybackSeason(season.id);
    final videoInfo = _service.getVideoInfo(index);
    _offlineCacheService.startDownload(videoInfo);
    showToast(title: '${videoInfo.name}已加入离线缓存');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverAppBar.medium(
                    title: Text(
                      widget.mediaItem.name,
                      style: context.theme.typography.body.lg.copyWith(
                        height: 1.2,
                      ),
                    ),
                    scrolledUnderElevation: 0,
                    stretch: true,
                    centerTitle: false,
                    expandedHeight:
                        250 +
                        (_showContinueSection ? 96 : 0) +
                        kTextTabBarHeight +
                        kToolbarHeight,
                    toolbarHeight: kToolbarHeight,
                    collapsedHeight:
                        kTextTabBarHeight +
                        kToolbarHeight +
                        MediaQuery.paddingOf(context).top,
                    forceElevated: innerBoxIsScrolled,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Column(
                        children: [
                          Stack(
                            children: [
                              Positioned.fill(
                                bottom: 16,
                                child: _buildbackground(),
                              ),
                              SafeArea(
                                bottom: false,
                                child: StreamMediaInfoCard(
                                  title: widget.mediaItem.name,
                                  mediaId: widget.mediaItem.id,
                                  imageUrl: _service.getImageUrl(
                                    widget.mediaItem.id,
                                  ),
                                  headers: _service.headers,
                                  isLoading: _isLoading,
                                  showFavoriteAction: _service.useRemoteHistory,
                                  isFavorite: _mediaDetail?.isFavorite ?? false,
                                  mediaDetail: _mediaDetail,
                                  actionFocusNode: _actionFocusNode,
                                  onToggleFavorite: _toggleFavorite,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_showContinueSection) _buildContinueSection(),
                        ],
                      ),
                    ),
                    bottom: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerHeight: 0,
                      tabs: _mediaDetail == null
                          ? []
                          : _mediaDetail!.seasons
                                .map((season) => Tab(text: season.name))
                                .toList(),
                    ),
                  ),
                ),
              ];
            },
            body: SafeArea(top: false, child: _buildBody()),
          ),
          SignalBuilder(
            builder: (context) {
              if (!_isPlaying.value) {
                return const SizedBox.shrink();
              }
              return Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMediaDetail,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_mediaDetail == null || _mediaDetail!.seasons.isEmpty) {
      return const Center(child: Text('暂无季度信息'));
    }
    return TabBarView(
      controller: _tabController,
      children: _mediaDetail!.seasons.map(_buildSeasonTab).toList(),
    );
  }

  Widget _buildSeasonTab(SeasonInfo season) {
    return SignalBuilder(
      builder: (context) {
        final overlapHandle = NestedScrollView.sliverOverlapAbsorberHandleFor(
          context,
        );
        final state = _service.getEpisodeState(season.id);
        return RefreshIndicator(
          edgeOffset: overlapHandle.layoutExtent ?? 0,
          onRefresh: () => _loadEpisodes(season, forceRefresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
            slivers: <Widget>[
              SliverOverlapInjector(handle: overlapHandle),
              state.map<Widget>(
                data: (episodes) => episodes.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('暂无集数')),
                      )
                    : SliverList.builder(
                        itemCount: episodes.length,
                        itemBuilder: (context, index) =>
                            _buildSeasonViewBuilder(
                              index,
                              season,
                              episodes[index],
                            ),
                      ),
                error: (error) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorRefresh(
                    error: error,
                    onRefresh: () => _loadEpisodes(season, forceRefresh: true),
                  ),
                ),
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContinueSection() {
    if (_isLoading) return const SizedBox.shrink();
    final item = _continueItem;
    if (item == null) return const SizedBox.shrink();
    final uniqueKey = CryptoUtils.generateVideoUniqueKey(item.id);
    final positionMs = (item.playbackPositionTicks / 10000).round();
    final durationMs = ((item.runTimeTicks ?? 0) / 10000).round();
    _refreshMap[uniqueKey] ??= 0;
    final refreshKey = _refreshMap[uniqueKey]!;
    final history = History(
      uniqueKey: uniqueKey,
      duration: durationMs,
      position: positionMs,
      url: item.id,
      type: HistoriesType.streamMediaStorage,
      storageKey: _service.storage?.uniqueKey,
      updateTime: item.lastPlayedDate?.millisecondsSinceEpoch ?? 0,
      name: item.name,
      subtitle: item.subtitle,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: VideoItem(
        history: history,
        coutinue: true,
        uniqueKey: uniqueKey,
        name: item.name,
        focusNode: _dpadEnabled ? _continueFocusNode : null,
        onPress: _playContinueItem,
        refreshKey: refreshKey,
        imageUrl: item.mainImage == null
            ? null
            : _service.getImageUrl(item.mainImage!),
        headers: _service.headers,
        items: [
          playedItem(item.id, false, _loadContinueItem),
          historyItem(item.id),
        ],
      ),
    );
  }

  Widget _buildbackground() {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.4,
        child: LayoutBuilder(
          builder: (context, boxConstraints) {
            return ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.transparent],
                    stops: [0.7, 1],
                  ).createShader(bounds);
                },
                child: NetworkImageWidget(
                  url: _service.getImageUrl(widget.mediaItem.id),
                  headers: _service.headers,
                  maxWidth: boxConstraints.maxWidth,
                  maxHeight: boxConstraints.maxHeight,
                  radius: 0,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeasonViewBuilder(
    int index,
    SeasonInfo season,
    EpisodeInfo episode,
  ) {
    final uniqueKey = CryptoUtils.generateVideoUniqueKey(episode.id);
    _refreshMap[uniqueKey] ??= 0;
    final refreshKey = _refreshMap[uniqueKey]!;
    final history = _service.getHistory(episode);
    return VideoItem(
      key: ValueKey(uniqueKey),
      history: history,
      uniqueKey: uniqueKey,
      refreshKey: refreshKey,
      imageUrl: _service.getImageUrl(episode.id),
      headers: _service.headers,
      name: episode.name,
      danmakuMatchInfo: .new(
        fileName: episode.fileName,
        currentVideoPath: _service.getPlaybackUrl(episode.id),
        headers: _service.headers,
      ),
      subtitle: episode.subtitle,
      onPress: () => _onPlayEpisode(season, index),
      played: episode.userData?.played ?? false,
      items: [
        .new(
          icon: FLucideIcons.download,
          title: '离线保存',
          onPress: () => _onDownloadEpisode(season, index),
        ),
        if (episode.userData != null)
          playedItem(episode.id, episode.userData!.played, () {
            setState(() {
              episode.userData!.played = !episode.userData!.played;
            });
          }),
        if (history != null) historyItem(episode.id),
      ],
    );
  }

  ContextMenuItem playedItem(String itemId, bool played, Function() call) {
    return .new(
      icon: played ? FLucideIcons.circleX : FLucideIcons.circleCheck,
      title: played ? '未观看' : '已观看',
      onPress: () {
        _service.setPlayed(itemId, !played);
        call.call();
      },
    );
  }

  ContextMenuItem historyItem(String itemId) {
    return .new(
      icon: FLucideIcons.trash,
      variant: .destructive,
      title: '删除历史记录',
      onPress: () {
        showConfirmDialog(
          context,
          title: '删除历史记录',
          content: '是否删除观看历史？',
          onConfirm: () {
            _service.removeHistory(itemId);
          },
          confirmText: '删除',
          destructive: true,
        );
      },
    );
  }
}
