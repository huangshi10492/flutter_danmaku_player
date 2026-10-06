import 'package:fldanplay/model/history.dart';
import 'package:fldanplay/model/storage2.dart';
import 'package:fldanplay/model/storage.dart';
import 'package:fldanplay/model/offline_cache.dart';
import 'package:fldanplay/model/video_info.dart';
import 'package:hive_ce/hive.dart';
part 'hive_adapters.g.dart';

@GenerateAdapters([
  AdapterSpec<Storage>(),
  AdapterSpec<StorageRecord>(),
  AdapterSpec<History>(),
  AdapterSpec<StorageType>(),
  AdapterSpec<HistoriesType>(),
  AdapterSpec<OfflineCache>(),
  AdapterSpec<VideoInfo>(
    ignoredFields: {
      'videoIndex',
      'listLength',
      'canSwitch',
      'cached',
      'externalSubtitles',
      'chapters',
    },
  ),
  AdapterSpec<DownloadStatus>(),
])
class HiveAdapters {}
