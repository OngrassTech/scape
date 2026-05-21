import 'app_update_models.dart';
import 'app_update_checker_stub.dart'
    if (dart.library.io) 'app_update_checker_io.dart'
    as platform;

typedef AppUpdateLookup =
    Future<AppUpdateResult> Function(String currentVersion);

Future<AppUpdateResult> fetchLatestGitHubRelease(String currentVersion) {
  return platform.fetchLatestGitHubRelease(currentVersion);
}
