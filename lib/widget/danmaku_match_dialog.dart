import 'package:fldanplay/model/danmaku.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:fldanplay/service/player/danmaku.dart';
import 'package:fldanplay/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

enum _DanmakuSearchState {
  matching('正在匹配弹幕...'),
  downloading('正在下载弹幕...'),
  success(''),
  search(''),
  searching(''),
  saving('正在保存弹幕...');

  final String message;

  const _DanmakuSearchState(this.message);
}

class DanmakuMatchDialog extends StatefulWidget {
  final String uniqueKey;
  final String videoName;
  final FDialogStyle style;
  final Animation<double> animation;
  const DanmakuMatchDialog({
    super.key,
    required this.style,
    required this.animation,
    required this.uniqueKey,
    required this.videoName,
  });

  @override
  State<DanmakuMatchDialog> createState() => _DanmakuMatchDialogState();
}

class _DanmakuMatchDialogState extends State<DanmakuMatchDialog> {
  final _searchController = TextEditingController();
  final danmakuGetter = DanmakuGetter();
  final configure = GetIt.I<ConfigureService>();
  _DanmakuSearchState _state = _DanmakuSearchState.matching;
  String _message = '';
  String? _errorMessage;
  List<Anime>? _animes;
  String _selectedServer = '';

  @override
  void initState() {
    super.initState();
    _match();
    _searchController.text = widget.videoName;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _match() async {
    var result = await danmakuGetter.match(widget.uniqueKey, widget.videoName);
    if (result == null) {
      setState(() {
        _state = _DanmakuSearchState.search;
      });
      showToast(title: '未找到弹幕');
      return;
    }
    setState(() {
      _state = _DanmakuSearchState.saving;
    });
    await danmakuGetter.save(widget.uniqueKey, result);
    setState(() {
      _state = _DanmakuSearchState.success;
      _message = '${result.animeTitle}\n${result.episodeTitle}';
    });
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      return;
    }
    if (_selectedServer.isEmpty) {
      showToast(title: '请选择服务器');
      return;
    }
    setState(() {
      _state = _DanmakuSearchState.searching;
      _animes = null;
      _errorMessage = null;
    });
    try {
      final animes = await danmakuGetter.search(keyword, _selectedServer);
      setState(() {
        _animes = animes;
        _state = _DanmakuSearchState.search;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = _DanmakuSearchState.search;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FDialog(
      style: widget.style,
      animation: widget.animation,
      direction: .vertical,
      constraints: BoxConstraints(minWidth: 10, maxWidth: 560),
      title: _buildTitle(),
      body: _buildBody(),
      actions: _buildAction(),
    );
  }

  Widget? _buildTitle() {
    switch (_state) {
      case .success:
        return Text('自动匹配成功');
      case .search:
      case .searching:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('搜索弹幕', style: context.theme.typography.lg),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close),
            ),
          ],
        );
      default:
        return null;
    }
  }

  List<Widget> _buildAction() {
    switch (_state) {
      case .success:
        return [
          FButton(
            variant: .outline,
            onPress: () => setState(() {
              _state = _DanmakuSearchState.search;
            }),
            child: const Text('手动搜索覆盖'),
          ),
          FButton(
            onPress: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildBody() {
    switch (_state) {
      case .matching:
      case .downloading:
      case .saving:
        return Column(
          mainAxisSize: .min,
          children: [
            SizedBox(height: 8),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(_state.message, style: context.theme.typography.md),
          ],
        );
      case .success:
        return Text(_message);
      case .search:
      case .searching:
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            minHeight: 200,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildServerSelector(),
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FAccordion(
                    style: .delta(childPadding: .value(.zero)),
                    children: _buildListBody(),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildServerSelector() {
    return Watch((context) {
      final serverList = configure.danmakuServerList.value;
      if (serverList.isEmpty) return const SizedBox.shrink();
      if (_selectedServer.isEmpty && serverList.isNotEmpty) {
        _selectedServer = serverList.first;
      }
      return FSelect<String>(
        control: .lifted(
          value: _selectedServer,
          onChange: (v) {
            setState(() {
              _selectedServer = v ?? '';
            });
          },
        ),
        items: {for (var server in serverList) server: server},
      );
    });
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: FTextField(
            control: .managed(controller: _searchController),
            hint: '输入动画或剧集名称',
            clearable: (value) => value.text.isNotEmpty,
          ),
        ),
        const SizedBox(width: 8),
        FButton.icon(
          style: .delta(iconContentStyle: .delta(padding: .value(.all(8)))),
          onPress: _state == _DanmakuSearchState.searching ? () {} : _search,
          child: _state == _DanmakuSearchState.searching
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: FCircularProgress(),
                )
              : Icon(
                  Icons.search,
                  size: 22,
                  color: context.theme.colors.primary,
                ),
        ),
      ],
    );
  }

  List<Widget> _buildListBody() {
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
        title: Text(anime.animeTitle, textAlign: TextAlign.start),
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
              style: .delta(
                margin: .value(.symmetric(vertical: 2, horizontal: 0)),
                contentStyle: .delta(
                  // padding: .value(.symmetric(vertical: 10, horizontal: 6)),
                ),
              ),
              title: Text(
                episode.episodeTitle,
                style: context.theme.typography.md,
                maxLines: 2,
              ),
              onPress: () async {
                setState(() {
                  _state = _DanmakuSearchState.saving;
                });
                final result = await danmakuGetter.save(
                  widget.uniqueKey,
                  episode,
                );
                if (result.isNotEmpty) {
                  showToast(title: '弹幕保存成功');
                  if (mounted) {
                    Navigator.pop(this.context, result);
                  }
                } else {
                  showToast(title: '弹幕保存失败');
                  setState(() {
                    _state = _DanmakuSearchState.search;
                  });
                }
              },
            );
          },
        ),
      );
    }).toList();
  }
}
