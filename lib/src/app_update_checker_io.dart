import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_metadata.dart';
import 'app_update_models.dart';

const Duration _updateCheckTimeout = Duration(seconds: 10);
const String _updateCheckFailedMessage = 'Update check failed.';

Future<AppUpdateResult> fetchLatestGitHubRelease(String currentVersion) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = _updateCheckTimeout
    ..idleTimeout = _updateCheckTimeout;

  try {
    final AppUpdateResult? releasePageResult = await _tryFetchReleasePageLookup(
      client,
      currentVersion,
    );
    if (releasePageResult != null) {
      return releasePageResult;
    }

    return await _fetchLatestReleaseFromApi(client, currentVersion);
  } on TimeoutException {
    return const AppUpdateResult.unavailable(
      message: _updateCheckFailedMessage,
    );
  } on SocketException {
    return const AppUpdateResult.unavailable(
      message: _updateCheckFailedMessage,
    );
  } on HandshakeException {
    return const AppUpdateResult.unavailable(
      message: _updateCheckFailedMessage,
    );
  } on HttpException {
    return const AppUpdateResult.unavailable(
      message: _updateCheckFailedMessage,
    );
  } on FormatException {
    return const AppUpdateResult.unavailable(
      message: _updateCheckFailedMessage,
    );
  } finally {
    client.close(force: true);
  }
}

Future<AppUpdateResult?> _tryFetchReleasePageLookup(
  HttpClient client,
  String currentVersion,
) async {
  try {
    return await _fetchLatestReleaseFromReleasePage(client, currentVersion);
  } on TimeoutException {
    return null;
  } on SocketException {
    return null;
  } on HandshakeException {
    return null;
  } on HttpException {
    return null;
  } on FormatException {
    return null;
  }
}

Future<AppUpdateResult?> _fetchLatestReleaseFromReleasePage(
  HttpClient client,
  String currentVersion,
) async {
  final HttpClientRequest request = await client
      .headUrl(Uri.parse(appGithubLatestReleaseUrl))
      .timeout(_updateCheckTimeout);
  request.followRedirects = false;
  request.maxRedirects = 0;
  request.headers.set(
    HttpHeaders.userAgentHeader,
    '$appName/$appReleaseVersion',
  );

  final HttpClientResponse response = await request.close().timeout(
    _updateCheckTimeout,
  );
  if (response.statusCode == HttpStatus.notFound) {
    return const AppUpdateResult.unavailable(
      message: 'No GitHub release has been published yet.',
    );
  }
  if (!_isRedirectStatusCode(response.statusCode)) {
    return null;
  }

  final String? location = response.headers.value(HttpHeaders.locationHeader);
  if (location == null || location.trim().isEmpty) {
    return null;
  }

  final String releaseUrl = Uri.parse(
    appGithubLatestReleaseUrl,
  ).resolve(location).toString();
  final String latestVersion = extractReleaseVersionFromReleaseUrl(releaseUrl);
  if (latestVersion.isEmpty) {
    return null;
  }

  return _buildReleaseResult(
    currentVersion: currentVersion,
    latestVersion: latestVersion,
    releaseUrl: releaseUrl,
  );
}

Future<AppUpdateResult> _fetchLatestReleaseFromApi(
  HttpClient client,
  String currentVersion,
) async {
  final HttpClientRequest request = await client
      .getUrl(Uri.parse(appGithubLatestReleaseApiUrl))
      .timeout(_updateCheckTimeout);
  request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
  request.headers.set(
    HttpHeaders.userAgentHeader,
    '$appName/$appReleaseVersion',
  );

  final HttpClientResponse response = await request.close().timeout(
    _updateCheckTimeout,
  );
  if (response.statusCode == HttpStatus.notFound) {
    return const AppUpdateResult.unavailable(
      message: 'No GitHub release has been published yet.',
    );
  }
  if (response.statusCode != HttpStatus.ok) {
    return const AppUpdateResult.unavailable(
      message: _updateCheckFailedMessage,
    );
  }

  final String body = await utf8.decoder
      .bind(response)
      .join()
      .timeout(_updateCheckTimeout);
  final Map<String, dynamic> payload = jsonDecode(body) as Map<String, dynamic>;
  final String latestVersion = normalizeReleaseVersion(
    payload['tag_name'] as String? ?? '',
  );
  if (latestVersion.isEmpty) {
    return const AppUpdateResult.unavailable(
      message: _updateCheckFailedMessage,
    );
  }

  final String releaseUrl =
      (payload['html_url'] as String?)?.trim().isNotEmpty == true
      ? (payload['html_url'] as String).trim()
      : appGithubReleasesUrl;

  return _buildReleaseResult(
    currentVersion: currentVersion,
    latestVersion: latestVersion,
    releaseUrl: releaseUrl,
  );
}

AppUpdateResult _buildReleaseResult({
  required String currentVersion,
  required String latestVersion,
  required String releaseUrl,
}) {
  if (compareReleaseVersions(currentVersion, latestVersion) < 0) {
    return AppUpdateResult.updateAvailable(
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      message: 'Update available: $latestVersion on GitHub Releases.',
    );
  }

  return const AppUpdateResult.upToDate(
    message: '$appName $appDisplayVersion is up to date.',
  );
}

bool _isRedirectStatusCode(int statusCode) {
  return statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;
}
