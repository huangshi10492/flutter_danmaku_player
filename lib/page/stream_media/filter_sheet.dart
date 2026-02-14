import 'package:fldanplay/service/stream_media_explorer.dart';
import 'package:fldanplay/widget/icon_switch.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class StreamMediaFilterSheet extends StatefulWidget {
  final StreamMediaExplorerService service;
  const StreamMediaFilterSheet({super.key, required this.service});
  @override
  State<StreamMediaFilterSheet> createState() => _StreamMediaFilterSheetState();
}

class _StreamMediaFilterSheetState extends State<StreamMediaFilterSheet> {
  late Filter filter = widget.service.filter.value;
  late TextEditingController searchController;
  late TextEditingController yearsController;
  late String status;
  late String sortBy;
  late bool sortOrder;

  final statusOptions = {'全部': '', '连载中': 'Continuing', '已完结': 'Ended'};

  final sortOptions = {
    '名称': 'SortName',
    '播放日期': 'DatePlayed',
    '社区评分': 'CommunityRating',
  };

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() {
    setState(() {
      searchController = TextEditingController(text: filter.searchTerm);
      yearsController = TextEditingController(text: filter.years);
      status = filter.seriesStatus;
      sortBy = filter.sortBy;
      sortOrder = filter.sortOrder;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    yearsController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    Filter filter = Filter()
      ..searchTerm = searchController.text
      ..years = yearsController.text
      ..seriesStatus = status
      ..sortBy = sortBy
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
        FTextField(
          control: .managed(controller: yearsController),
          label: Text('年份'),
          hint: '按,分隔年份，如2000,2001,2002',
        ),
        const SizedBox(height: 12),
        FSelectMenuTile.fromMap(
          selectControl: .lifted(
            value: {status},
            onChange: (value) => setState(() {
              status = value.last;
            }),
          ),
          statusOptions,
          title: Text('连载状态'),
          details: Text(
            statusOptions.entries.firstWhere((e) => e.value == status).key,
          ),
        ),
        const SizedBox(height: 12),
        FSelectMenuTile.fromMap(
          selectControl: .lifted(
            value: {sortBy},
            onChange: (value) => setState(() {
              sortBy = value.last;
            }),
          ),
          sortOptions,
          title: Text('排序类型'),
          details: Text(
            sortOptions.entries.firstWhere((e) => e.value == sortBy).key,
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
