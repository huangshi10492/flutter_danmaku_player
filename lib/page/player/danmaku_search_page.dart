import 'package:fldanplay/model/danmaku.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/global.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';

class DanmakuSearchPage extends StatefulWidget {
  final void Function(Episode episode) onEpisodeSelected;
  final Future<List<Anime>> Function(String name, String url) searchEpisodes;

  const DanmakuSearchPage({
    super.key,
    required this.onEpisodeSelected,
    required this.searchEpisodes,
  });

  @override
  State<DanmakuSearchPage> createState() => _DanmakuSearchPageState();
}

class _DanmakuSearchPageState extends State<DanmakuSearchPage> {
  final _searchController = TextEditingController();
  final _globalService = GetIt.I.get<GlobalService>();
  final _configureService = GetIt.I.get<ConfigureService>();
  bool _isLoading = false;
  String? _errorMessage;
  List<Anime>? _animes;
  String _selectedServer = '';

  @override
  void initState() {
    _searchController.text = _globalService.videoName;
    final serverList = _configureService.danmakuServerList.value;
    if (serverList.isNotEmpty) {
      _selectedServer = serverList.first;
    }
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _animes = null;
      _errorMessage = null;
    });

    try {
      final animes = await widget.searchEpisodes(keyword, _selectedServer);
      setState(() {
        _animes = animes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildServerSelector(),
          const SizedBox(height: 8),
          _buildSearchBar(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FAccordion(
              children: _buildBody(),
              style: (style) => style.copyWith(childPadding: EdgeInsets.zero),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerSelector() {
    final serverList = _configureService.danmakuServerList.value;
    if (serverList.isEmpty) return const SizedBox.shrink();
    return FSelect(
      control: .lifted(
        value: _selectedServer,
        onChange: (v) => setState(() {
          _selectedServer = v ?? '';
        }),
      ),
      items: {for (var e in serverList) e: e},
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: FTextField(
            control: .managed(controller: _searchController),
            hint: '输入动画或剧集名称',
            clearable: (value) => value.text.isNotEmpty,
            onTapOutside: (event) {
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        const SizedBox(width: 8),
        FButton.icon(
          onPress: _isLoading ? () {} : _search,
          child: _isLoading
              // 固定大小
              ? const SizedBox(
                  width: 25,
                  height: 25,
                  child: FCircularProgress(),
                )
              : Icon(
                  Icons.search,
                  size: 25,
                  color: context.theme.colors.primary,
                ),
        ),
      ],
    );
  }

  List<Widget> _buildBody() {
    if (_errorMessage != null) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('错误: $_errorMessage', textAlign: TextAlign.center),
          ),
        ),
      ];
    }
    if (_animes == null) return [];
    if (_animes!.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('无结果', textAlign: TextAlign.center),
          ),
        ),
      ];
    }
    return _animes!.map((anime) {
      return FAccordionItem(
        title: Text(anime.animeTitle),
        // 添加分割线
        child: ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: anime.episodes.length * 2 - 1,
          itemBuilder: (context, index) {
            if (index % 2 == 1) {
              return Divider(height: 1, color: context.theme.colors.border);
            }
            final episode = anime.episodes[(index / 2).round()];
            return FItem(
              style: (style) => style.copyWith(
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                contentStyle: (style) => style.copyWith(
                  padding: EdgeInsetsDirectional.symmetric(
                    vertical: 10,
                    horizontal: 6,
                  ),
                ),
              ),
              title: Text(
                episode.episodeTitle,
                style: context.theme.typography.base,
                maxLines: 2,
              ),
              onPress: () {
                widget.onEpisodeSelected(episode);
              },
            );
          },
        ),
      );
    }).toList();
  }
}
