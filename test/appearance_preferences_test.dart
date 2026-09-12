import 'package:flutter_test/flutter_test.dart';
import 'package:mazegame/src/appearance_preferences.dart';
import 'package:mazegame/src/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saves and restores appearance from shared preferences', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SharedPreferencesAppearancePreferences store =
        SharedPreferencesAppearancePreferences(preferences);

    await store.saveAppearance(
      const AppAppearance(theme: ThemeId.rose, isDark: false),
    );

    final AppAppearance restored = await SharedPreferencesAppearancePreferences(
      await SharedPreferences.getInstance(),
    ).loadAppearance();

    expect(
      restored,
      const AppAppearance(theme: ThemeId.rose, isDark: false),
    );
  });

  test('falls back to orange dark when no appearance is saved', () async {
    final AppAppearance restored = await SharedPreferencesAppearancePreferences(
      await SharedPreferences.getInstance(),
    ).loadAppearance();

    expect(restored, AppAppearance.fallback);
  });
}
