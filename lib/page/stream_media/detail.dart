import 'dart:ui';

import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/stream_media.dart';
import 'package:fldanplay/page/stream_media/info_card.dart';
import 'package:fldanplay/router.dart';
import 'package:fldanplay/service/global.dart';
import 'package:fldanplay/service/offline_cache.dart';
import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/utils/crypto_utils.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:fldanplay/widget/danmaku_match_dialog.dart';
import 'package:fldanplay/widget/network_image.dart';
import 'package:fldanplay/widget/video_item.dart';
import 'package:flutter/material.dart';
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
  final Signal<bool> _isPlaying = signal(false);
  bool get _showContinueSection =>
      _service.storage?.useRemoteHistory == true && _continueItem != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadMediaDetail();
    _loadContinueItem();
    GetIt.I.get<GlobalService>().updateListener = refreshItem;
  }

  @override
  void dispose() {
    _tabController.dispose();
    GetIt.I.get<GlobalService>().updateListener = null;
    super.dispose();
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
      setState(() {
        _mediaDetail = detail;
        _isLoading = false;
        _tabController.dispose();
        _tabController = TabController(
          length: detail.seasons.length,
          vsync: this,
        );
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadContinueItem() async {
    if (_service.storage?.useRemoteHistory != true) return;
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

  Future<void> _playContinueItem() async {
    final item = _continueItem;
    if (item == null || _isPlaying.value) return;
    _isPlaying.value = true;
    try {
      final videoInfo = await _service.prepareVideoInfoByItemId(item.id);
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
      final videoInfo = await _service.prepareVideoInfoForSeason(season, index);
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
    _service.setVideoList(season);
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
                      style: context.theme.typography.lg.copyWith(height: 1.2),
                    ),
                    scrolledUnderElevation: 0,
                    stretch: true,
                    centerTitle: false,
                    expandedHeight:
                        304 +
                        (_showContinueSection ? 144 : 0) +
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
                                  mediaDetail: _mediaDetail,
                                ),
                              ),
                            ],
                          ),
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
          Watch((context) {
            if (!_isPlaying.value) {
              return const SizedBox.shrink();
            }
            return Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            );
          }),
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
      children: _mediaDetail!.seasons.map((season) {
        if (season.episodes.isEmpty) {
          return const Center(child: Text('暂无集数'));
        }
        return Builder(
          builder: (BuildContext context) {
            return CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                ),
                SliverList.builder(
                  itemCount: season.episodes.length,
                  itemBuilder: (context, index) {
                    return _buildSeasonViewBuilder(context, index, season);
                  },
                ),
              ],
            );
          },
        );
      }).toList(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const .only(left: 16, top: 8),
            child: Text('继续观看', style: context.theme.typography.xl),
          ),
          VideoItem(
            history: history,
            uniqueKey: uniqueKey,
            name: item.name,
            onPress: _playContinueItem,
            refreshKey: refreshKey,
            imageUrl: item.mainImage == null
                ? null
                : _service.getImageUrl(item.mainImage!),
            headers: _service.headers,
            previewWidth: 160,
            previewHeight: 90,
            onLongPress: () {},
          ),
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
    BuildContext context,
    int index,
    SeasonInfo season,
  ) {
    final episode = season.episodes[index];
    final uniqueKey = CryptoUtils.generateVideoUniqueKey(episode.id);
    _refreshMap[uniqueKey] ??= 0;
    final refreshKey = _refreshMap[uniqueKey]!;
    return VideoItem(
      key: ValueKey(uniqueKey),
      history: _service.getHistory(episode),
      uniqueKey: uniqueKey,
      refreshKey: refreshKey,
      imageUrl: _service.getImageUrl(episode.id),
      headers: _service.headers,
      name: episode.name,
      subtitle: episode.subtitle,
      onOfflineDownload: () => _onDownloadEpisode(season, index),
      danmakuMatchDialog: DanmakuMatchDialog(
        uniqueKey: uniqueKey,
        fileName: episode.fileName,
      ),
      onPress: () => _onPlayEpisode(season, index),
    );
  }
}
