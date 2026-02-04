import 'package:hive_ce_flutter/hive_flutter.dart';

enum StorageType { webdav, ftp, smb, local, jellyfin, emby }

class Storage extends HiveObject {
  String name;
  String uniqueKey;
  String url;
  int? port;
  StorageType storageType;
  String? account;
  String? password;
  bool? isAnonymous;
  String? mediaLibraryId;
  String? token;
  String? userId;
  bool? useRemoteHistory;

  Storage({
    required this.name,
    required this.uniqueKey,
    required this.url,
    this.port,
    required this.storageType,
    this.account,
    this.password,
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
    int? port,
    StorageType? storageType,
    String? account,
    String? password,
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
      port: port ?? this.port,
      storageType: storageType ?? this.storageType,
      account: account ?? this.account,
      password: password ?? this.password,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      mediaLibraryId: mediaLibraryId ?? this.mediaLibraryId,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      useRemoteHistory: useRemoteHistory ?? this.useRemoteHistory,
    );
  }
}
