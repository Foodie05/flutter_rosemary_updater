class LatestStableAppRelease {
  LatestStableAppRelease({
    required this.found,
    required this.app,
    required this.release,
    required this.platforms,
    required this.changelog,
    this.reason = '',
  });

  final bool found;
  final String reason;
  final RosemaryAppInfo? app;
  final RosemaryReleaseInfo? release;
  final List<RosemaryPlatformPackage> platforms;
  final String changelog;

  factory LatestStableAppRelease.fromJson(Map<String, dynamic> json) {
    return LatestStableAppRelease(
      found: json['found'] == true,
      reason: json['reason'] as String? ?? '',
      app: _mapOrNull(json['app'], RosemaryAppInfo.fromJson),
      release: _mapOrNull(json['release'], RosemaryReleaseInfo.fromJson),
      platforms: _listOfMaps(
        json['platforms'],
        RosemaryPlatformPackage.fromJson,
      ),
      changelog: json['changelog'] as String? ?? '',
    );
  }
}

class LatestStableResourceRelease {
  LatestStableResourceRelease({
    required this.found,
    required this.app,
    required this.resource,
    required this.changelog,
    this.reason = '',
  });

  final bool found;
  final String reason;
  final RosemaryAppInfo? app;
  final RosemaryResourceInfo? resource;
  final String changelog;

  factory LatestStableResourceRelease.fromJson(Map<String, dynamic> json) {
    return LatestStableResourceRelease(
      found: json['found'] == true,
      reason: json['reason'] as String? ?? '',
      app: _mapOrNull(json['app'], RosemaryAppInfo.fromJson),
      resource: _mapOrNull(json['resource'], RosemaryResourceInfo.fromJson),
      changelog: json['changelog'] as String? ?? '',
    );
  }
}

class RosemaryAppInfo {
  RosemaryAppInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.lastUpdated,
    required this.minVersionCode,
    required this.eolVersionCode,
  });

  final String id;
  final String name;
  final String icon;
  final String description;
  final String lastUpdated;
  final int minVersionCode;
  final int eolVersionCode;

  factory RosemaryAppInfo.fromJson(Map<String, dynamic> json) {
    return RosemaryAppInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      description: json['description'] as String? ?? '',
      lastUpdated: json['lastUpdated'] as String? ?? '',
      minVersionCode: _intValue(json['minVersionCode']),
      eolVersionCode: _intValue(json['eolVersionCode']),
    );
  }
}

class RosemaryReleaseInfo {
  RosemaryReleaseInfo({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.category,
    required this.type,
    required this.publishDate,
    required this.downloadUrl,
    required this.changelog,
    required this.minSupportedVersionCode,
    this.codeName = '',
    this.patchUrl = '',
  });

  final String id;
  final String versionName;
  final int versionCode;
  final String codeName;
  final String category;
  final String type;
  final String publishDate;
  final String downloadUrl;
  final String patchUrl;
  final String changelog;
  final int minSupportedVersionCode;

  factory RosemaryReleaseInfo.fromJson(Map<String, dynamic> json) {
    return RosemaryReleaseInfo(
      id: json['id'] as String? ?? '',
      versionName: json['versionName'] as String? ?? '',
      versionCode: _intValue(json['versionCode']),
      codeName: json['codeName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      type: json['type'] as String? ?? '',
      publishDate: json['publishDate'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      patchUrl: json['patchUrl'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      minSupportedVersionCode: _intValue(json['minSupportedVersionCode']),
    );
  }
}

class RosemaryResourceInfo extends RosemaryReleaseInfo {
  RosemaryResourceInfo({
    required super.id,
    required super.versionName,
    required super.versionCode,
    required super.category,
    required super.type,
    required super.publishDate,
    required super.downloadUrl,
    required super.changelog,
    required super.minSupportedVersionCode,
    required this.url,
    required this.isPatch,
    super.codeName,
    super.patchUrl,
  });

  final String url;
  final bool isPatch;

  factory RosemaryResourceInfo.fromJson(Map<String, dynamic> json) {
    return RosemaryResourceInfo(
      id: json['id'] as String? ?? '',
      versionName: json['versionName'] as String? ?? '',
      versionCode: _intValue(json['versionCode']),
      codeName: json['codeName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      type: json['type'] as String? ?? '',
      publishDate: json['publishDate'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      patchUrl: json['patchUrl'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      minSupportedVersionCode: _intValue(json['minSupportedVersionCode']),
      url: json['url'] as String? ?? '',
      isPatch: json['isPatch'] == true,
    );
  }
}

class RosemaryPlatformPackage {
  RosemaryPlatformPackage({
    required this.platform,
    required this.url,
    required this.installKind,
    this.label = '',
    this.notes = '',
  });

  final String platform;
  final String url;
  final String installKind;
  final String label;
  final String notes;

  factory RosemaryPlatformPackage.fromJson(Map<String, dynamic> json) {
    return RosemaryPlatformPackage(
      platform: json['platform'] as String? ?? '',
      url: json['url'] as String? ?? '',
      installKind: json['installKind'] as String? ?? '',
      label: json['label'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

T? _mapOrNull<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is Map) {
    return fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

List<T> _listOfMaps<T>(
    Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
