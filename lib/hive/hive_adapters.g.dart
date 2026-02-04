// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class HistoryAdapter extends TypeAdapter<History> {
  @override
  final typeId = 1;

  @override
  History read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return History(
      uniqueKey: fields[1] as String,
      duration: (fields[2] as num).toInt(),
      position: (fields[3] as num).toInt(),
      url: fields[4] as String?,
      type: fields[6] as HistoriesType,
      storageKey: fields[10] as String?,
      updateTime: (fields[8] as num).toInt(),
      name: fields[11] as String,
      subtitle: fields[12] as String?,
      fileName: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, History obj) {
    writer
      ..writeByte(10)
      ..writeByte(1)
      ..write(obj.uniqueKey)
      ..writeByte(2)
      ..write(obj.duration)
      ..writeByte(3)
      ..write(obj.position)
      ..writeByte(4)
      ..write(obj.url)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(8)
      ..write(obj.updateTime)
      ..writeByte(10)
      ..write(obj.storageKey)
      ..writeByte(11)
      ..write(obj.name)
      ..writeByte(12)
      ..write(obj.subtitle)
      ..writeByte(13)
      ..write(obj.fileName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HistoriesTypeAdapter extends TypeAdapter<HistoriesType> {
  @override
  final typeId = 3;

  @override
  HistoriesType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 1:
        return HistoriesType.local;
      case 3:
        return HistoriesType.network;
      case 5:
        return HistoriesType.fileStorage;
      case 6:
        return HistoriesType.streamMediaStorage;
      default:
        return HistoriesType.local;
    }
  }

  @override
  void write(BinaryWriter writer, HistoriesType obj) {
    switch (obj) {
      case HistoriesType.local:
        writer.writeByte(1);
      case HistoriesType.network:
        writer.writeByte(3);
      case HistoriesType.fileStorage:
        writer.writeByte(5);
      case HistoriesType.streamMediaStorage:
        writer.writeByte(6);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoriesTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StorageAdapter extends TypeAdapter<Storage> {
  @override
  final typeId = 4;

  @override
  Storage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Storage(
      name: fields[0] as String,
      uniqueKey: fields[8] as String,
      url: fields[1] as String,
      port: (fields[2] as num?)?.toInt(),
      storageType: fields[4] as StorageType,
      account: fields[5] as String?,
      password: fields[6] as String?,
      isAnonymous: fields[7] as bool?,
      mediaLibraryId: fields[9] as String?,
      token: fields[10] as String?,
      userId: fields[11] as String?,
      useRemoteHistory: fields[12] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Storage obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.port)
      ..writeByte(4)
      ..write(obj.storageType)
      ..writeByte(5)
      ..write(obj.account)
      ..writeByte(6)
      ..write(obj.password)
      ..writeByte(7)
      ..write(obj.isAnonymous)
      ..writeByte(8)
      ..write(obj.uniqueKey)
      ..writeByte(9)
      ..write(obj.mediaLibraryId)
      ..writeByte(10)
      ..write(obj.token)
      ..writeByte(11)
      ..write(obj.userId)
      ..writeByte(12)
      ..write(obj.useRemoteHistory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StorageTypeAdapter extends TypeAdapter<StorageType> {
  @override
  final typeId = 5;

  @override
  StorageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StorageType.webdav;
      case 1:
        return StorageType.ftp;
      case 2:
        return StorageType.smb;
      case 3:
        return StorageType.local;
      case 4:
        return StorageType.jellyfin;
      case 5:
        return StorageType.emby;
      default:
        return StorageType.webdav;
    }
  }

  @override
  void write(BinaryWriter writer, StorageType obj) {
    switch (obj) {
      case StorageType.webdav:
        writer.writeByte(0);
      case StorageType.ftp:
        writer.writeByte(1);
      case StorageType.smb:
        writer.writeByte(2);
      case StorageType.local:
        writer.writeByte(3);
      case StorageType.jellyfin:
        writer.writeByte(4);
      case StorageType.emby:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineCacheAdapter extends TypeAdapter<OfflineCache> {
  @override
  final typeId = 6;

  @override
  OfflineCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineCache(
      uniqueKey: fields[0] as String,
      videoInfo: fields[1] as VideoInfo,
      content: fields[2] as String,
      cacheTime: (fields[4] as num).toInt(),
      fileSize: fields[3] == null ? 0 : (fields[3] as num).toInt(),
      status: fields[5] == null
          ? DownloadStatus.downloading
          : fields[5] as DownloadStatus,
      downloadedBytes: fields[6] == null ? 0 : (fields[6] as num).toInt(),
      totalBytes: fields[7] == null ? 0 : (fields[7] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineCache obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.uniqueKey)
      ..writeByte(1)
      ..write(obj.videoInfo)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.fileSize)
      ..writeByte(4)
      ..write(obj.cacheTime)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.downloadedBytes)
      ..writeByte(7)
      ..write(obj.totalBytes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VideoInfoAdapter extends TypeAdapter<VideoInfo> {
  @override
  final typeId = 7;

  @override
  VideoInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VideoInfo(
      currentVideoPath: fields[0] as String,
      virtualVideoPath: fields[1] as String,
      headers: fields[2] == null
          ? const {}
          : (fields[2] as Map).cast<String, String>(),
      historiesType: fields[3] as HistoriesType,
      storageKey: fields[4] as String?,
      videoName: fields[6] as String,
      name: fields[7] as String,
      subtitle: fields[8] as String?,
    )..uniqueKey = fields[5] as String;
  }

  @override
  void write(BinaryWriter writer, VideoInfo obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.currentVideoPath)
      ..writeByte(1)
      ..write(obj.virtualVideoPath)
      ..writeByte(2)
      ..write(obj.headers)
      ..writeByte(3)
      ..write(obj.historiesType)
      ..writeByte(4)
      ..write(obj.storageKey)
      ..writeByte(5)
      ..write(obj.uniqueKey)
      ..writeByte(6)
      ..write(obj.videoName)
      ..writeByte(7)
      ..write(obj.name)
      ..writeByte(8)
      ..write(obj.subtitle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadStatusAdapter extends TypeAdapter<DownloadStatus> {
  @override
  final typeId = 8;

  @override
  DownloadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DownloadStatus.finished;
      case 1:
        return DownloadStatus.downloading;
      case 2:
        return DownloadStatus.failed;
      default:
        return DownloadStatus.finished;
    }
  }

  @override
  void write(BinaryWriter writer, DownloadStatus obj) {
    switch (obj) {
      case DownloadStatus.finished:
        writer.writeByte(0);
      case DownloadStatus.downloading:
        writer.writeByte(1);
      case DownloadStatus.failed:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
