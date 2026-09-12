import 'app_update_models.dart';

Future<AppUpdateResult> fetchLatestGitHubRelease(String currentVersion) async {
  return const AppUpdateResult.unavailable(
    message: 'Update checks are unavailable on this platform.',
  );
}
