import 'package:flutter_test/flutter_test.dart';
import 'package:mazegame/src/models.dart';
import 'package:mazegame/src/progress_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saves and restores player progress from shared preferences', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SharedPreferencesProgressPreferences store =
        SharedPreferencesProgressPreferences(preferences);

    await store.saveProgress(
      const PlayerProgress(
        points: 71,
        ownedThemes: <ThemeId>{ThemeId.orange, ThemeId.rose, ThemeId.emerald},
        equippedThemes: <ThemeId>{ThemeId.orange, ThemeId.rose},
        bestTimesByDifficulty: <Difficulty, int>{
          Difficulty.easy: 12,
          Difficulty.nightmare: 88,
        },
      ),
    );

    final PlayerProgress restored = await SharedPreferencesProgressPreferences(
      await SharedPreferences.getInstance(),
    ).loadProgress();

    expect(restored.points, 71);
    expect(restored.ownedThemes, <ThemeId>{
      ThemeId.orange,
      ThemeId.rose,
      ThemeId.emerald,
    });
    expect(restored.equippedThemes, <ThemeId>{ThemeId.orange, ThemeId.rose});
    expect(restored.bestTimeFor(Difficulty.easy), 12);
    expect(restored.bestTimeFor(Difficulty.nightmare), 88);
  });

  test(
    'falls back to orange-owned empty progress when nothing is saved',
    () async {
      final PlayerProgress restored =
          await SharedPreferencesProgressPreferences(
            await SharedPreferences.getInstance(),
          ).loadProgress();

      expect(restored, PlayerProgress.fallback);
    },
  );
}
