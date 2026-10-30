import 'package:fldanplay/utils/icon.dart';
import 'package:forui/forui.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';

enum StorageType {
  webdav('WebDAV', FLucideIcons.server),
  ftp('FTP', MyIcon.ftp),
  smb('SMB', MyIcon.smb),
  local('本地', FLucideIcons.folder),
  jellyfin('Jellyfin', MyIcon.jellyfin),
  emby('Emby', MyIcon.emby),
  fnys('飞牛影视', MyIcon.fnys);

  final String label;
  final IconData icon;
  const StorageType(this.label, this.icon);
}

class Storage extends HiveObject {
  String name;
  String uniqueKey;
  String url;
  String? share;
  int? port;
  StorageType storageType;
  String? account;
  String? password;
  String? ftpMode;
  bool? isAnonymous;
  String? mediaLibraryId;
  String? token;
  String? userId;
  bool? useRemoteHistory;

  Storage({
    required this.name,
    required this.uniqueKey,
    required this.url,
    this.share,
    this.port,
    required this.storageType,
    this.account,
    this.password,
    this.ftpMode,
    this.isAnonymous,
    this.mediaLibraryId,
    this.token,
    this.userId,
    this.useRemoteHistory,
  });

  static Storage create() {
    return Storage(
      name: '',
      uniqueKey: '',
      url: '',
      storageType: StorageType.webdav,
    );
  }

  Storage copyWith({
    String? name,
    String? uniqueKey,
    String? url,
    String? share,
    int? port,
    StorageType? storageType,
    String? account,
    String? password,
    String? ftpMode,
    bool? isAnonymous,
    String? mediaLibraryId,
    String? token,
    String? userId,
    bool? useRemoteHistory,
  }) {
    return Storage(
      name: name ?? this.name,
      uniqueKey: uniqueKey ?? this.uniqueKey,
      url: url ?? this.url,
      share: share ?? this.share,
      port: port ?? this.port,
      storageType: storageType ?? this.storageType,
      account: account ?? this.account,
      password: password ?? this.password,
      ftpMode: ftpMode ?? this.ftpMode,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      mediaLibraryId: mediaLibraryId ?? this.mediaLibraryId,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      useRemoteHistory: useRemoteHistory ?? this.useRemoteHistory,
    );
  }
}
