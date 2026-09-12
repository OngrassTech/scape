import 'app_update_models.dart';
import 'app_update_checker_stub.dart'
    if (dart.library.io) 'app_update_checker_io.dart'
    as platform;

typedef AppUpdateLookup =
    Future<AppUpdateResult> Function(String currentVersion);

Future<AppUpdateResult> fetchLatestGitHubRelease(String currentVersion) {
  if (const bool.fromEnvironment('FDROID')) {
    return Future.value(const AppUpdateResult.unavailable(
      message: 'Update checks are unavailable on this platform.',
    ));
  }
  return platform.fetchLatestGitHubRelease(currentVersion);
}
