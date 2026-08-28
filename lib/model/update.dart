class UpdateResponse {
  final String latestVersion;
  final bool hasUpdate;
  final List<Release> releases;

  UpdateResponse({
    required this.latestVersion,
    required this.hasUpdate,
    required this.releases,
  });

  factory UpdateResponse.fromJson(Map<String, dynamic> json) {
    return UpdateResponse(
      latestVersion: json['latestVersion'] as String,
      hasUpdate: json['hasUpdate'] as bool,
      releases: (json['releases'] as List)
          .map((e) => Release.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Release {
  final String version;
  final String publishedAt;
  final String changelog;

  Release({
    required this.version,
    required this.publishedAt,
    required this.changelog,
  });

  factory Release.fromJson(Map<String, dynamic> json) {
    return Release(
      version: json['version'] as String,
      publishedAt: json['publishedAt'] as String,
      changelog: json['changelog'] as String,
    );
  }
}
