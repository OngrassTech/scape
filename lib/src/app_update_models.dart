enum AppUpdateStatus { upToDate, updateAvailable, unavailable }

class AppUpdateResult {
  const AppUpdateResult._({
    required this.status,
    required this.message,
    this.latestVersion,
    this.releaseUrl,
  });

  const AppUpdateResult.upToDate({required String message})
    : this._(status: AppUpdateStatus.upToDate, message: message);

  const AppUpdateResult.updateAvailable({
    required String latestVersion,
    required String releaseUrl,
    required String message,
  }) : this._(
         status: AppUpdateStatus.updateAvailable,
         message: message,
         latestVersion: latestVersion,
         releaseUrl: releaseUrl,
       );

  const AppUpdateResult.unavailable({required String message})
    : this._(status: AppUpdateStatus.unavailable, message: message);

  final AppUpdateStatus status;
  final String message;
  final String? latestVersion;
  final String? releaseUrl;
}

String normalizeReleaseVersion(String rawVersion) {
  final String trimmed = rawVersion.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final String withoutPrefix = trimmed.replaceFirst(RegExp(r'^[vV]'), '');
  final Match? versionMatch = RegExp(
    r'\d+(?:\.\d+){0,2}',
  ).firstMatch(withoutPrefix);
  return versionMatch?.group(0) ?? withoutPrefix;
}

int compareReleaseVersions(String currentVersion, String latestVersion) {
  final List<int> currentParts = _parseVersionParts(currentVersion);
  final List<int> latestParts = _parseVersionParts(latestVersion);
  final int maxLength = currentParts.length > latestParts.length
      ? currentParts.length
      : latestParts.length;

  for (int index = 0; index < maxLength; index++) {
    final int currentPart = index < currentParts.length
        ? currentParts[index]
        : 0;
    final int latestPart = index < latestParts.length ? latestParts[index] : 0;
    if (currentPart != latestPart) {
      return currentPart.compareTo(latestPart);
    }
  }

  return 0;
}

String extractReleaseVersionFromReleaseUrl(String releaseUrl) {
  final String trimmed = releaseUrl.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return _extractNormalizedReleaseVersion(trimmed);
  }

  final List<String> segments = uri.pathSegments
      .where((String segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) {
    return '';
  }

  final int tagIndex = segments.lastIndexOf('tag');
  if (tagIndex >= 0 && tagIndex + 1 < segments.length) {
    return _extractNormalizedReleaseVersion(
      Uri.decodeComponent(segments[tagIndex + 1]),
    );
  }

  return _extractNormalizedReleaseVersion(Uri.decodeComponent(segments.last));
}

List<int> _parseVersionParts(String rawVersion) {
  final String normalized = normalizeReleaseVersion(rawVersion);
  if (normalized.isEmpty) {
    return const <int>[0];
  }

  return normalized
      .split('.')
      .map((String part) => int.tryParse(part) ?? 0)
      .toList(growable: false);
}

String _extractNormalizedReleaseVersion(String rawVersion) {
  final String normalized = normalizeReleaseVersion(rawVersion);
  return RegExp(r'\d').hasMatch(normalized) ? normalized : '';
}
