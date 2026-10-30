library;

import 'package:fldanplay/model/storage2.dart';
import 'package:fldanplay/service/stream_media_explorer/emby.dart';
import 'package:fldanplay/service/stream_media_explorer/fnys.dart';
import 'package:fldanplay/service/stream_media_explorer/service.dart';

export 'stream_media_explorer/emby.dart';
export 'stream_media_explorer/fnys.dart';
export 'stream_media_explorer/service.dart';

Future<StreamMediaExplorerProvider?> createStreamMediaExplorerProvider(
  Storage2 storage, {
  bool validateCredentials = true,
}) async {
  final StreamMediaExplorerProvider? provider = switch (storage.storageType) {
    .emby => EmbyStreamMediaExplorerProvider(storage as EmbyMediaStorage),
    .jellyfin => JellyfinStreamMediaExplorerProvider(
      storage as JellyfinMediaStorage,
    ),
    .fnys => FnysStreamMediaExplorerProvider(storage as FnysMediaStorage),
    _ => null,
  };
  if (provider == null) return null;
  try {
    await provider.initialize(validateCredentials: validateCredentials);
    return provider;
  } catch (_) {
    provider.dispose();
    rethrow;
  }
}
