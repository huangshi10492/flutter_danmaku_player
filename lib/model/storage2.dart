import 'dart:convert';
import 'dart:io';

import 'package:fldanplay/model/storage.dart';
import 'package:hive_ce/hive.dart';

enum StorageFieldType { text, toggle, select }

class StorageEditField {
  final String key, label;
  final StorageFieldType type;
  final bool required, obscureText, number;
  final Map<String, String>? options;
  final Object? Function() read;
  final void Function(Object?) write;
  final String? Function(String?)? validator;

  const StorageEditField({
    required this.key,
    required this.label,
    required this.type,
    required this.read,
    required this.write,
    this.required = false,
    this.obscureText = false,
    this.number = false,
    this.options,
    this.validator,
  });
}

class StorageFieldConfig {
  final String key, label;
  final StorageFieldType type;
  final bool required, obscureText, number, editable;
  final Map<String, String>? options;
  final Object? Function() read;
  final void Function(Object?) write;
  final String? Function(String?)? validator;

  const StorageFieldConfig({
    required this.key,
    required this.label,
    required this.type,
    required this.read,
    required this.write,
    this.required = false,
    this.obscureText = false,
    this.number = false,
    this.editable = true,
    this.options,
    this.validator,
  });

  StorageEditField toEditField() => StorageEditField(
    key: key,
    label: label,
    type: type,
    required: required,
    obscureText: obscureText,
    number: number,
    options: options,
    validator: validator,
    read: read,
    write: write,
  );

  static StorageFieldConfig text(
    String key,
    String label, {
    required Object? Function() read,
    required void Function(String) write,
    bool required = false,
    bool obscureText = false,
    bool number = false,
    bool editable = true,
    String? Function(String?)? validator,
  }) => StorageFieldConfig(
    key: key,
    label: label,
    type: .text,
    required: required,
    obscureText: obscureText,
    number: number,
    editable: editable,
    validator: validator,
    read: read,
    write: (v) => write(v as String? ?? ''),
  );

  static StorageFieldConfig toggle(
    String key,
    String label, {
    required bool Function() read,
    required void Function(bool) write,
    bool editable = true,
  }) => StorageFieldConfig(
    key: key,
    label: label,
    type: .toggle,
    editable: editable,
    read: read,
    write: (v) => write(v as bool? ?? false),
  );

  static StorageFieldConfig select(
    String key,
    String label, {
    required String Function() read,
    required void Function(String) write,
    required Map<String, String> options,
    bool editable = true,
  }) => StorageFieldConfig(
    key: key,
    label: label,
    type: .select,
    options: options,
    editable: editable,
    read: read,
    write: (v) => write(v as String? ?? options.values.first),
  );
}

class StorageRecord extends HiveObject {
  @override
  String key;
  String type, name, data;
  int createdAt;

  StorageRecord({
    required this.type,
    required this.name,
    required this.key,
    required this.createdAt,
    required this.data,
  });
}

typedef Meta = ({String name, String key, DateTime createdAt});

sealed class Storage2 {
  String name, key;
  DateTime createdAt;

  Storage2({required this.name, required this.key, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  StorageType get storageType;
  String get subtitle;
  List<StorageFieldConfig> get fields;
  String get uniqueKey => key;
  List<StorageEditField> get editFields => [
    for (final f in fields)
      if (f.editable) f.toEditField(),
  ];

  Map<String, dynamic> toJson() => {for (final f in fields) f.key: f.read()};

  StorageRecord toRecord() => StorageRecord(
    type: storageType.name,
    name: name,
    key: key,
    createdAt: createdAt.millisecondsSinceEpoch,
    data: jsonEncode(toJson()),
  );

  static Storage2 create(StorageType type) => switch (type) {
    .webdav => WebDavStorage(name: '', key: '', url: ''),
    .ftp => FtpStorage(name: '', key: '', host: '', account: ''),
    .smb => SmbStorage(name: '', key: '', host: '', share: ''),
    .local => LocalStorage(name: '', key: '', url: ''),
    .jellyfin => JellyfinMediaStorage.empty(),
    .emby => EmbyMediaStorage.empty(),
  };

  static Storage2 fromRecord(StorageRecord record) {
    final json = jsonDecode(record.data);
    if (json is! Map) throw const FormatException('媒体库 data 不是 JSON 对象');
    final types = StorageType.values.where((e) => e.name == record.type);
    if (types.isEmpty) throw FormatException('未知媒体库类型: ${record.type}');
    final meta = (
      name: record.name,
      key: record.key,
      createdAt: DateTime.fromMillisecondsSinceEpoch(record.createdAt),
    );
    return switch (types.first) {
      .webdav => WebDavStorage.fromJson(json, meta),
      .ftp => FtpStorage.fromJson(json, meta),
      .smb => SmbStorage.fromJson(json, meta),
      .local => LocalStorage.fromJson(json, meta),
      .jellyfin => JellyfinMediaStorage.fromJson(json, meta),
      .emby => EmbyMediaStorage.fromJson(json, meta),
    };
  }

  static Storage2 fromLegacy(Storage s, {required DateTime createdAt}) =>
      switch (s.storageType) {
        .webdav => WebDavStorage(
          name: s.name,
          key: s.uniqueKey,
          createdAt: createdAt,
          url: s.url,
          account: s.account,
          password: s.password,
          isAnonymous: s.isAnonymous ?? false,
        ),
        .ftp => FtpStorage(
          name: s.name,
          key: s.uniqueKey,
          createdAt: createdAt,
          host: s.url,
          port: s.port ?? 21,
          account: s.account ?? '',
          password: s.password ?? '',
          ftpMode: s.ftpMode ?? 'passive',
        ),
        .smb => SmbStorage(
          name: s.name,
          key: s.uniqueKey,
          createdAt: createdAt,
          host: s.url,
          share: s.share ?? '',
          account: s.account,
          password: s.password,
        ),
        .local => LocalStorage(
          name: s.name,
          key: s.uniqueKey,
          createdAt: createdAt,
          url: s.url,
        ),
        .jellyfin => JellyfinMediaStorage(
          name: s.name,
          key: s.uniqueKey,
          createdAt: createdAt,
          url: s.url,
          account: s.account ?? '',
          password: s.password ?? '',
          mediaLibraryId: s.mediaLibraryId,
          token: s.token ?? '',
          userId: s.userId ?? '',
          useRemoteHistory: s.useRemoteHistory ?? false,
        ),
        .emby => EmbyMediaStorage(
          name: s.name,
          key: s.uniqueKey,
          createdAt: createdAt,
          url: s.url,
          account: s.account ?? '',
          password: s.password ?? '',
          mediaLibraryId: s.mediaLibraryId,
          token: s.token ?? '',
          userId: s.userId ?? '',
          useRemoteHistory: s.useRemoteHistory ?? false,
        ),
      };
}

String? _validateUrl(String? value) {
  if (value?.trim().isEmpty ?? true) return null;
  final uri = Uri.tryParse(value!.trim());
  return uri == null || !uri.hasScheme ? '请输入有效的URL' : null;
}

String? _validatePort(String? value) {
  if (value?.trim().isEmpty ?? true) return null;
  final port = int.tryParse(value!.trim());
  return port == null || port < 1 || port > 65535 ? '请输入有效的端口号(1-65535)' : null;
}

String? _validateHost(String? value, {required bool smb}) {
  if (value?.trim().isEmpty ?? true) return null;
  final host = value!.trim();
  final invalid = RegExp(smb ? r'[/\\@?#\s]' : r'[/@?#\s]');
  if (invalid.hasMatch(host)) return '请输入主机名或IP地址';
  if (host.contains(':') &&
      InternetAddress.tryParse(host)?.type != InternetAddressType.IPv6) {
    return smb ? 'SMB不支持自定义端口' : '端口请填写在端口字段中';
  }
  return null;
}

final class WebDavStorage extends Storage2 {
  String url;
  String? account, password;
  bool isAnonymous;

  WebDavStorage({
    required super.name,
    required super.key,
    super.createdAt,
    required this.url,
    this.account,
    this.password,
    this.isAnonymous = false,
  });

  WebDavStorage.fromJson(Map json, Meta meta)
    : this(
        name: meta.name,
        key: meta.key,
        createdAt: meta.createdAt,
        url: json['url'] as String? ?? '',
        account: json['account'] as String?,
        password: json['password'] as String?,
        isAnonymous: json['isAnonymous'] as bool? ?? false,
      );

  @override
  StorageType get storageType => .webdav;

  @override
  String get subtitle => url;

  @override
  List<StorageFieldConfig> get fields => [
    .text(
      'url',
      'WebDAV地址',
      required: true,
      validator: _validateUrl,
      read: () => url,
      write: (v) => url = v,
    ),
    .text('account', '用户名', read: () => account, write: (v) => account = v),
    .text(
      'password',
      '密码',
      obscureText: true,
      read: () => password,
      write: (v) => password = v,
    ),
    .toggle(
      'isAnonymous',
      '匿名访问',
      read: () => isAnonymous,
      write: (v) => isAnonymous = v,
    ),
  ];
}

final class FtpStorage extends Storage2 {
  String host, account, ftpMode;
  int port;
  String? password;

  FtpStorage({
    required super.name,
    required super.key,
    super.createdAt,
    required this.host,
    this.port = 21,
    required this.account,
    this.password,
    this.ftpMode = 'passive',
  });

  FtpStorage.fromJson(Map json, Meta meta)
    : this(
        name: meta.name,
        key: meta.key,
        createdAt: meta.createdAt,
        host: json['host'] as String? ?? '',
        port: (json['port'] as num?)?.toInt() ?? 21,
        account: json['account'] as String? ?? '',
        password: json['password'] as String?,
        ftpMode: json['ftpMode'] as String? ?? 'passive',
      );

  @override
  StorageType get storageType => .ftp;

  @override
  String get subtitle => 'ftp://$host:$port';

  @override
  List<StorageFieldConfig> get fields => [
    .text(
      'host',
      'FTP服务器',
      required: true,
      validator: (v) => _validateHost(v, smb: false),
      read: () => host,
      write: (v) => host = v,
    ),
    .text(
      'port',
      '端口',
      number: true,
      required: true,
      validator: _validatePort,
      read: () => port.toString(),
      write: (v) => port = int.tryParse(v.trim()) ?? 21,
    ),
    .text(
      'account',
      '用户名',
      required: true,
      read: () => account,
      write: (v) => account = v,
    ),
    .text(
      'password',
      '密码',
      obscureText: true,
      read: () => password,
      write: (v) => password = v,
    ),
    .select(
      'ftpMode',
      'FTP模式',
      options: const {'主动模式': 'active', '被动模式': 'passive'},
      read: () => ftpMode,
      write: (v) => ftpMode = v,
    ),
  ];
}

final class SmbStorage extends Storage2 {
  String host, share;
  String? account, password;

  SmbStorage({
    required super.name,
    required super.key,
    super.createdAt,
    required this.host,
    required this.share,
    this.account,
    this.password,
  });

  SmbStorage.fromJson(Map json, Meta meta)
    : this(
        name: meta.name,
        key: meta.key,
        createdAt: meta.createdAt,
        host: json['host'] as String? ?? '',
        share: json['share'] as String? ?? '',
        account: json['account'] as String?,
        password: json['password'] as String?,
      );

  @override
  StorageType get storageType => .smb;

  @override
  String get subtitle => 'smb://$host/$share';

  @override
  List<StorageFieldConfig> get fields => [
    .text(
      'host',
      'SMB主机',
      required: true,
      validator: (v) => _validateHost(v, smb: true),
      read: () => host,
      write: (v) => host = v,
    ),
    .text(
      'share',
      '共享名',
      required: true,
      validator: (v) {
        if (v?.trim().isEmpty ?? true) return null;
        return RegExp(r'[/\\]').hasMatch(v!) ? '共享名不能包含路径分隔符' : null;
      },
      read: () => share,
      write: (v) => share = v,
    ),
    .text('account', '用户名', read: () => account, write: (v) => account = v),
    .text(
      'password',
      '密码',
      obscureText: true,
      read: () => password,
      write: (v) => password = v,
    ),
  ];
}

final class LocalStorage extends Storage2 {
  String url;

  LocalStorage({
    required super.name,
    required super.key,
    super.createdAt,
    required this.url,
  });

  LocalStorage.fromJson(Map json, Meta meta)
    : this(
        name: meta.name,
        key: meta.key,
        createdAt: meta.createdAt,
        url: json['url'] as String? ?? '',
      );

  @override
  StorageType get storageType => .local;

  @override
  String get subtitle => url;

  @override
  List<StorageFieldConfig> get fields => [
    .text(
      'url',
      '本地路径',
      required: true,
      read: () => url,
      write: (v) => url = v,
    ),
  ];
}

abstract class StreamStorage extends Storage2 {
  String url, account, password, token, userId;
  String? mediaLibraryId;
  bool useRemoteHistory;

  StreamStorage({
    required super.name,
    required super.key,
    super.createdAt,
    required this.url,
    required this.account,
    required this.password,
    this.mediaLibraryId,
    required this.token,
    required this.userId,
    this.useRemoteHistory = false,
  });

  @override
  String get subtitle => url;

  @override
  List<StorageFieldConfig> get fields => [
    .text(
      'url',
      '服务器地址',
      required: true,
      validator: _validateUrl,
      read: () => url,
      write: (v) => url = v,
    ),
    .text('account', '用户名', read: () => account, write: (v) => account = v),
    .text(
      'password',
      '密码',
      required: true,
      obscureText: true,
      read: () => password,
      write: (v) => password = v,
    ),
    .text(
      'mediaLibraryId',
      '媒体库ID',
      editable: false,
      read: () => mediaLibraryId,
      write: (v) => mediaLibraryId = v,
    ),
    .text(
      'token',
      'Token',
      editable: false,
      read: () => token,
      write: (v) => token = v,
    ),
    .text(
      'userId',
      '用户ID',
      editable: false,
      read: () => userId,
      write: (v) => userId = v,
    ),
    .toggle(
      'useRemoteHistory',
      '使用远程历史',
      read: () => useRemoteHistory,
      write: (v) => useRemoteHistory = v,
    ),
  ];
}

class EmbyMediaStorage extends StreamStorage {
  EmbyMediaStorage({
    required super.name,
    required super.key,
    super.createdAt,
    required super.url,
    required super.account,
    required super.password,
    super.mediaLibraryId,
    required super.token,
    required super.userId,
    super.useRemoteHistory,
  });

  factory EmbyMediaStorage.empty() => EmbyMediaStorage(
    name: '',
    key: '',
    url: '',
    account: '',
    password: '',
    token: '',
    userId: '',
  );

  EmbyMediaStorage.fromJson(Map json, Meta meta)
    : this(
        name: meta.name,
        key: meta.key,
        createdAt: meta.createdAt,
        url: json['url'] as String? ?? '',
        account: json['account'] as String? ?? '',
        password: json['password'] as String? ?? '',
        mediaLibraryId: json['mediaLibraryId'] as String?,
        token: json['token'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        useRemoteHistory: json['useRemoteHistory'] as bool? ?? false,
      );

  @override
  StorageType get storageType => .emby;
}

final class JellyfinMediaStorage extends EmbyMediaStorage {
  JellyfinMediaStorage({
    required super.name,
    required super.key,
    super.createdAt,
    required super.url,
    required super.account,
    required super.password,
    super.mediaLibraryId,
    required super.token,
    required super.userId,
    super.useRemoteHistory,
  });

  factory JellyfinMediaStorage.empty() => JellyfinMediaStorage(
    name: '',
    key: '',
    url: '',
    account: '',
    password: '',
    token: '',
    userId: '',
  );

  JellyfinMediaStorage.fromJson(Map json, Meta meta)
    : this(
        name: meta.name,
        key: meta.key,
        createdAt: meta.createdAt,
        url: json['url'] as String? ?? '',
        account: json['account'] as String? ?? '',
        password: json['password'] as String? ?? '',
        mediaLibraryId: json['mediaLibraryId'] as String?,
        token: json['token'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        useRemoteHistory: json['useRemoteHistory'] as bool? ?? false,
      );

  @override
  StorageType get storageType => .jellyfin;
}
