import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/appearance_preferences.dart';
import 'src/progress_preferences.dart';
import 'src/session_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences sharedPreferences =
      await SharedPreferences.getInstance();
  final SharedPreferencesAppearancePreferences appearancePreferences =
      SharedPreferencesAppearancePreferences(sharedPreferences);
  final SharedPreferencesProgressPreferences progressPreferences =
      SharedPreferencesProgressPreferences(sharedPreferences);
  final SharedPreferencesSessionPreferences sessionPreferences =
      SharedPreferencesSessionPreferences(sharedPreferences);
  final AppAppearance initialAppearance = await appearancePreferences
      .loadAppearance();
  final PlayerProgress initialProgress = await progressPreferences
      .loadProgress();
  final SavedGameSession? initialSession = await sessionPreferences
      .loadSession();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    MazeGameApp(
      appearancePreferences: appearancePreferences,
      initialAppearance: initialAppearance,
      progressPreferences: progressPreferences,
      initialProgress: initialProgress,
      sessionPreferences: sessionPreferences,
      initialSession: initialSession,
    ),
  );
}
