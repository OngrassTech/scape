import 'package:flutter/services.dart';

typedef UpdateReleaseLauncher = Future<bool> Function(String releaseUrl);

const MethodChannel _updateReleaseChannel = MethodChannel(
  'com.anoshione.scape/update_release',
);

Future<bool> openUpdateReleaseUrl(String releaseUrl) async {
  final String normalizedUrl = releaseUrl.trim();
  if (normalizedUrl.isEmpty) {
    return false;
  }

  try {
    final bool? didOpen = await _updateReleaseChannel.invokeMethod<bool>(
      'openReleaseUrl',
      <String, String>{'url': normalizedUrl},
    );
    return didOpen ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
