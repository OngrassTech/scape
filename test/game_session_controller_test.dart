import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazegame/src/appearance_preferences.dart';
import 'package:mazegame/src/feedback.dart';
import 'package:mazegame/src/game_session_controller.dart';
import 'package:mazegame/src/app_update_models.dart';
import 'package:mazegame/src/models.dart';
import 'package:mazegame/src/progress_preferences.dart';
import 'package:mazegame/src/session_preferences.dart';

import 'test_helpers.dart';

void main() {
  group('GameSessionController', () {
    test(
      'medium difficulty now sits closer to hard than easy for board density',
      () {
        final DifficultyConfig easy = Difficulty.easy.config;
        final DifficultyConfig medium = Difficulty.medium.config;
        final DifficultyConfig hard = Difficulty.hard.config;

        expect(
          medium.width - easy.width,
          greaterThan(hard.width - medium.width),
        );
        expect(
          medium.height - easy.height,
          greaterThan(hard.height - medium.height),
        );
        expect(medium.timeLimitSeconds, greaterThan(easy.timeLimitSeconds));
        expect(medium.timeLimitSeconds, lessThan(hard.timeLimitSeconds));
      },
    );

    testWidgets(
      'nightmare time trial starts at one minute forty-five seconds',
      (WidgetTester tester) async {
        final GameSessionController controller = GameSessionController(
          feedbackController: NoopFeedbackController(),
        );
        try {
          controller.setDifficulty(Difficulty.nightmare);
          controller.toggleTimeTrial();
          controller.startNewGame();

          expect(Difficulty.nightmare.config.timeLimitSeconds, 105);
          expect(controller.time, 105);
          expect(controller.formatTime(controller.time), '01:45');
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets('difficulty changes clear a resumable game', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.startNewGame();
        controller.backToMenu(withFeedback: false, preserveResume: true);

        expect(controller.canResume, isTrue);

        controller.setDifficulty(Difficulty.medium);

        expect(controller.canResume, isFalse);
      } finally {
        controller.dispose();
      }
    });

    testWidgets(
      'checkForUpdates stores an available update for the settings UI',
      (WidgetTester tester) async {
        final GameSessionController controller = GameSessionController(
          feedbackController: NoopFeedbackController(),
          appUpdateLookup: (String currentVersion) async {
            return const AppUpdateResult.updateAvailable(
              latestVersion: '1.0.1',
              releaseUrl: 'https://github.com/OngrassTech/scape/releases',
              message: 'Update available: 1.0.1 on GitHub Releases.',
            );
          },
        );
        try {
          expect(controller.isCheckingForUpdates, isFalse);

          final Future<void> checkFuture = controller.checkForUpdates();
          expect(controller.isCheckingForUpdates, isTrue);

          await checkFuture;

          expect(controller.isCheckingForUpdates, isFalse);
          expect(controller.hasAvailableUpdate, isTrue);
          expect(
            controller.availableUpdateUrl,
            'https://github.com/OngrassTech/scape/releases',
          );
          expect(controller.transientToastMessage, isNull);
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'openAvailableUpdate forwards the release URL to the launcher',
      (WidgetTester tester) async {
        String? openedUrl;
        final GameSessionController controller = GameSessionController(
          feedbackController: NoopFeedbackController(),
          appUpdateLookup: (String currentVersion) async {
            return const AppUpdateResult.updateAvailable(
              latestVersion: '1.0.1',
              releaseUrl:
                  'https://github.com/OngrassTech/scape/releases/tag/v1.0.1',
              message: 'Update available: 1.0.1 on GitHub Releases.',
            );
          },
          updateReleaseLauncher: (String releaseUrl) async {
            openedUrl = releaseUrl;
            return true;
          },
        );
        try {
          await controller.checkForUpdates();
          await controller.openAvailableUpdate();

          expect(
            openedUrl,
            'https://github.com/OngrassTech/scape/releases/tag/v1.0.1',
          );
          expect(controller.transientToastMessage, isNull);
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets('collapses the trail when reversing over the same path', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.startNewGame();
        controller.move(1, 0);
        expect(controller.trail.length, greaterThan(1));

        controller.move(-1, 0);
        expect(controller.playerPos.x, 0);
        expect(controller.playerPos.y, 0);
        expect(controller.trail, <Position>[const Position(0, 0)]);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('counts upward in normal mode', (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.startNewGame();
        expect(controller.time, 0);

        await tester.pump(const Duration(seconds: 2));
        expect(controller.time, 2);
        expect(controller.isGameOver, isFalse);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('pauses elapsed time while settings are open', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.startNewGame();

        await tester.pump(const Duration(seconds: 2));
        expect(controller.time, 2);

        controller.openSettings();
        expect(controller.showSettings, isTrue);
        expect(controller.isPlaying, isTrue);

        await tester.pump(const Duration(seconds: 3));
        expect(controller.time, 2);

        controller.closeSettings();
        expect(controller.showSettings, isFalse);

        await tester.pump(const Duration(seconds: 2));
        expect(controller.time, 4);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('counts down in time trial and ends at zero', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.toggleTimeTrial();
        controller.startNewGame();

        expect(controller.time, 15);
        await tester.pump(const Duration(seconds: 14));
        expect(controller.time, 1);

        await tester.pump(const Duration(seconds: 1));
        expect(controller.time, 0);
        expect(controller.isGameOver, isTrue);
        expect(controller.isPlaying, isFalse);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('pauses time trial countdown while settings are open', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.toggleTimeTrial();
        controller.startNewGame();

        await tester.pump(const Duration(seconds: 2));
        expect(controller.time, 13);

        controller.openSettings();
        expect(controller.showSettings, isTrue);
        expect(controller.isPlaying, isTrue);

        await tester.pump(const Duration(seconds: 3));
        expect(controller.time, 13);

        controller.closeSettings();
        expect(controller.showSettings, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(controller.time, 12);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('settings dismissed via system back resumes timer', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.toggleTimeTrial();
        controller.startNewGame();

        await tester.pump(const Duration(seconds: 1));
        expect(controller.time, 14);

        controller.openSettings();
        await tester.pump(const Duration(seconds: 2));
        expect(controller.time, 14);

        controller.handleSystemBack();
        expect(controller.showSettings, isFalse);

        await tester.pump(const Duration(seconds: 1));
        expect(controller.time, 13);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('retry and new maze reset timer and transient flags', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.toggleTimeTrial();
        controller.startNewGame();
        await tester.pump(const Duration(seconds: 15));

        expect(controller.isGameOver, isTrue);

        controller.retryMaze();
        expect(controller.isGameOver, isFalse);
        expect(controller.time, 15);
        expect(controller.trail, <Position>[const Position(0, 0)]);

        controller.showHint();
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.hintPath, isNotEmpty);

        controller.nextMaze();
        expect(controller.hintPath, isEmpty);
        expect(controller.isHintActive, isFalse);
        expect(controller.time, 15);
        expect(controller.trail, <Position>[const Position(0, 0)]);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('shows only the first 15 hint steps and clears them later', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.startNewGame();
        controller.showHint();

        expect(controller.isHintActive, isTrue);
        expect(controller.hintPath, isEmpty);

        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.hintPath, hasLength(15));

        await tester.pump(const Duration(milliseconds: 2000));
        expect(controller.hintPath, isEmpty);

        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.isHintActive, isFalse);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('hint can only be used once per maze until the maze resets', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.startNewGame();
        expect(controller.canUseHint, isTrue);

        controller.showHint();
        expect(controller.canUseHint, isFalse);

        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.hintPath, isNotEmpty);

        await tester.pump(const Duration(milliseconds: 2300));
        expect(controller.isHintActive, isFalse);

        controller.showHint();
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.hintPath, isEmpty);

        controller.retryMaze();
        expect(controller.canUseHint, isTrue);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('plays a success cue when a maze is completed', (
      WidgetTester tester,
    ) async {
      final RecordingFeedbackController feedback =
          RecordingFeedbackController();
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easyLPathMaze()),
        feedbackController: feedback,
      );
      try {
        controller.startNewGame();
        feedback.sounds.clear();

        controller.move(1, 0);
        controller.move(0, 1);

        expect(
          feedback.sounds
              .where((SoundCue cue) => cue == SoundCue.success)
              .length,
          1,
        );
      } finally {
        controller.dispose();
      }
    });

    testWidgets('plays a failure cue when time trial expires', (
      WidgetTester tester,
    ) async {
      final RecordingFeedbackController feedback =
          RecordingFeedbackController();
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: feedback,
      );
      try {
        controller.toggleTimeTrial();
        controller.startNewGame();
        feedback.sounds.clear();

        await tester.pump(const Duration(seconds: 15));

        expect(
          feedback.sounds
              .where((SoundCue cue) => cue == SoundCue.failure)
              .length,
          1,
        );
      } finally {
        controller.dispose();
      }
    });

    testWidgets('plays one move cue per successful directional move only', (
      WidgetTester tester,
    ) async {
      final RecordingFeedbackController feedback =
          RecordingFeedbackController();
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easyLPathMaze()),
        feedbackController: feedback,
      );
      try {
        controller.startNewGame();

        feedback.sounds.clear();
        controller.move(1, 0);
        controller.move(1, 0);
        controller.move(0, 1);

        expect(
          feedback.sounds.where((SoundCue cue) => cue == SoundCue.move).length,
          2,
        );
      } finally {
        controller.dispose();
      }
    });

    testWidgets('restores a saved session as a resumable menu state', (
      WidgetTester tester,
    ) async {
      final MemorySessionPreferences sessionPreferences =
          MemorySessionPreferences();
      final GameSessionController originalController = GameSessionController(
        generator: FixedMazeGenerator(easyLPathMaze()),
        feedbackController: NoopFeedbackController(),
        sessionPreferences: sessionPreferences,
      );
      GameSessionController? restoredController;
      try {
        originalController.startNewGame();
        originalController.move(1, 0);
        await originalController.persistSession();

        final SavedGameSession? restoredSession = await sessionPreferences
            .loadSession();
        expect(restoredSession, isNotNull);

        restoredController = GameSessionController(
          generator: FixedMazeGenerator(easyLPathMaze()),
          feedbackController: NoopFeedbackController(),
          sessionPreferences: sessionPreferences,
          initialSession: restoredSession,
        );

        expect(restoredController.screen, AppScreen.menu);
        expect(restoredController.canResume, isTrue);
        expect(restoredController.hasMaze, isTrue);
        expect(restoredController.playerPos, const Position(9, 0));
        expect(restoredController.trail, <Position>[
          const Position(0, 0),
          for (int x = 1; x < 10; x++) Position(x, 0),
        ]);

        restoredController.resumeGame();
        expect(restoredController.screen, AppScreen.playing);
      } finally {
        originalController.dispose();
        restoredController?.dispose();
      }
    });

    testWidgets('plays a toggle cue when time trial is toggled', (
      WidgetTester tester,
    ) async {
      final RecordingFeedbackController feedback =
          RecordingFeedbackController();
      final GameSessionController controller = GameSessionController(
        feedbackController: feedback,
      );
      try {
        controller.toggleTimeTrial();

        expect(feedback.sounds, <SoundCue>[SoundCue.toggle]);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('plays a toggle cue when haptics are toggled', (
      WidgetTester tester,
    ) async {
      final RecordingFeedbackController feedback =
          RecordingFeedbackController();
      final GameSessionController controller = GameSessionController(
        feedbackController: feedback,
      );
      try {
        controller.toggleHaptics();

        expect(feedback.sounds, <SoundCue>[SoundCue.toggle]);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('first manual haptics re-enable shows the system toast once', (
      WidgetTester tester,
    ) async {
      final RecordingFeedbackController feedback =
          RecordingFeedbackController();
      final GameSessionController controller = GameSessionController(
        feedbackController: feedback,
      );
      try {
        controller.toggleHaptics();
        expect(controller.hapticsEnabled, isFalse);
        expect(controller.transientToastMessage, isNull);

        controller.toggleHaptics();
        expect(controller.hapticsEnabled, isTrue);
        expect(controller.transientToastMessage, 'Turn on all system haptics.');
        expect(feedback.haptics, <HapticCue>[HapticCue.medium]);

        await tester.pump(const Duration(seconds: 2));
        expect(controller.transientToastMessage, isNull);

        controller.toggleHaptics();
        controller.toggleHaptics();

        expect(controller.hapticsEnabled, isTrue);
        expect(controller.transientToastMessage, isNull);
        expect(feedback.haptics, <HapticCue>[
          HapticCue.medium,
          HapticCue.medium,
        ]);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('plays a toggle cue when sound is toggled off and on', (
      WidgetTester tester,
    ) async {
      final RecordingFeedbackController feedback =
          RecordingFeedbackController();
      final GameSessionController controller = GameSessionController(
        feedbackController: feedback,
      );
      try {
        controller.toggleSound();
        controller.toggleSound();

        expect(feedback.sounds, <SoundCue>[SoundCue.toggle, SoundCue.toggle]);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('ui sound audio context mixes with other audio on Android', (
      WidgetTester tester,
    ) async {
      final AudioContext context = buildUiSoundAudioContext();

      expect(context.android.audioFocus, AndroidAudioFocus.none);
      expect(context.android.usageType, AndroidUsageType.media);
    });

    testWidgets('persists appearance changes only', (
      WidgetTester tester,
    ) async {
      final MemoryAppearancePreferences appearancePreferences =
          MemoryAppearancePreferences();
      final GameSessionController controller = GameSessionController(
        appearancePreferences: appearancePreferences,
        feedbackController: NoopFeedbackController(),
        initialProgress: const PlayerProgress(
          points: 0,
          ownedThemes: <ThemeId>{ThemeId.orange, ThemeId.emerald},
          equippedThemes: <ThemeId>{ThemeId.orange, ThemeId.emerald},
          bestTimesByDifficulty: <Difficulty, int>{},
        ),
      );
      try {
        controller.setTheme(ThemeId.emerald);
        controller.toggleDarkMode();
        controller.toggleTimeTrial();

        expect(
          appearancePreferences.savedAppearances.last,
          const AppAppearance(theme: ThemeId.emerald, isDark: false),
        );
      } finally {
        controller.dispose();
      }
    });

    testWidgets('restores appearance without restoring time trial mode', (
      WidgetTester tester,
    ) async {
      final MemoryAppearancePreferences appearancePreferences =
          MemoryAppearancePreferences();
      final GameSessionController originalController = GameSessionController(
        appearancePreferences: appearancePreferences,
        feedbackController: NoopFeedbackController(),
        initialProgress: const PlayerProgress(
          points: 0,
          ownedThemes: <ThemeId>{ThemeId.orange, ThemeId.rose},
          equippedThemes: <ThemeId>{ThemeId.orange, ThemeId.rose},
          bestTimesByDifficulty: <Difficulty, int>{},
        ),
      );
      GameSessionController? restoredController;
      try {
        originalController.setTheme(ThemeId.rose);
        originalController.toggleDarkMode();
        originalController.toggleTimeTrial();

        final AppAppearance restoredAppearance = await appearancePreferences
            .loadAppearance();
        restoredController = GameSessionController(
          appearancePreferences: appearancePreferences,
          feedbackController: NoopFeedbackController(),
          initialAppearance: restoredAppearance,
          initialProgress: const PlayerProgress(
            points: 0,
            ownedThemes: <ThemeId>{ThemeId.orange, ThemeId.rose},
            equippedThemes: <ThemeId>{ThemeId.rose},
            bestTimesByDifficulty: <Difficulty, int>{},
          ),
        );

        expect(restoredController.theme, ThemeId.rose);
        expect(restoredController.isDark, isFalse);
        expect(restoredController.isTimeTrial, isFalse);
      } finally {
        originalController.dispose();
        restoredController?.dispose();
      }
    });

    testWidgets(
      'expert clears award repeatable points and store best seconds',
      (WidgetTester tester) async {
        final MemoryProgressPreferences progressPreferences =
            MemoryProgressPreferences();
        final GameSessionController controller = GameSessionController(
          generator: const OpenRouteMazeGenerator(),
          feedbackController: NoopFeedbackController(),
          progressPreferences: progressPreferences,
        );
        try {
          controller.setDifficulty(Difficulty.expert);
          controller.startNewGame();

          await tester.pump(const Duration(seconds: 5));
          controller.move(1, 0);
          controller.move(0, 1);

          expect(controller.lastClearElapsedSeconds, 5);
          expect(controller.lastPointsEarned, 1);
          expect(controller.lastClearWasNewBest, isTrue);
          expect(controller.points, 1);
          expect(controller.bestTimeForDifficulty(Difficulty.expert), 5);

          controller.nextMaze();
          await tester.pump(const Duration(seconds: 7));
          controller.move(1, 0);
          controller.move(0, 1);

          expect(controller.lastClearElapsedSeconds, 7);
          expect(controller.lastClearWasNewBest, isFalse);
          expect(controller.points, 2);
          expect(controller.bestTimeForDifficulty(Difficulty.expert), 5);

          await controller.persistProgress();
          expect(progressPreferences.storedProgress.points, 2);
          expect(
            progressPreferences.storedProgress.bestTimeFor(Difficulty.expert),
            5,
          );
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'time trial scoring uses elapsed seconds and grants two points on expert',
      (WidgetTester tester) async {
        final GameSessionController controller = GameSessionController(
          generator: const OpenRouteMazeGenerator(),
          feedbackController: NoopFeedbackController(),
        );
        try {
          controller.setDifficulty(Difficulty.expert);
          controller.toggleTimeTrial();
          controller.startNewGame();

          await tester.pump(const Duration(seconds: 10));
          controller.move(1, 0);
          controller.move(0, 1);

          expect(controller.lastClearElapsedSeconds, 10);
          expect(controller.lastPointsEarned, 2);
          expect(controller.lastClearWasNewBest, isTrue);
          expect(controller.points, 2);
          expect(controller.bestTimeForDifficulty(Difficulty.expert), 10);
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets('buyTheme deducts points and unlocks purchased themes', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        feedbackController: NoopFeedbackController(),
        initialProgress: const PlayerProgress(
          points: 70,
          ownedThemes: <ThemeId>{ThemeId.orange},
          equippedThemes: <ThemeId>{ThemeId.orange},
          bestTimesByDifficulty: <Difficulty, int>{},
        ),
      );
      try {
        expect(controller.buyTheme(ThemeId.rose), isTrue);
        expect(controller.points, 50);
        expect(controller.isThemeOwned(ThemeId.rose), isTrue);
        expect(controller.availableThemes, isNot(contains(ThemeId.rose)));
        expect(controller.equipTheme(ThemeId.rose), isTrue);
        expect(controller.availableThemes, contains(ThemeId.rose));
        controller.setTheme(ThemeId.rose);
        expect(controller.unequipTheme(ThemeId.orange), isTrue);
        expect(controller.availableThemes, isNot(contains(ThemeId.orange)));
        expect(controller.theme, ThemeId.rose);
        expect(controller.buyTheme(ThemeId.slate), isFalse);
        expect(controller.points, 50);
        expect(controller.transientToastMessage, 'Not enough points');

        await tester.pump(const Duration(seconds: 2));
        expect(controller.transientToastMessage, isNull);
      } finally {
        controller.dispose();
      }
    });

    testWidgets('equipTheme enforces a four-theme picker limit with a toast', (
      WidgetTester tester,
    ) async {
      final GameSessionController controller = GameSessionController(
        feedbackController: NoopFeedbackController(),
        initialProgress: const PlayerProgress(
          points: 500,
          ownedThemes: <ThemeId>{
            ThemeId.orange,
            ThemeId.rose,
            ThemeId.emerald,
            ThemeId.sapphire,
            ThemeId.violet,
          },
          equippedThemes: <ThemeId>{
            ThemeId.orange,
            ThemeId.rose,
            ThemeId.emerald,
            ThemeId.sapphire,
          },
          bestTimesByDifficulty: <Difficulty, int>{},
        ),
      );
      try {
        expect(controller.equipTheme(ThemeId.violet), isFalse);
        expect(
          controller.transientToastMessage,
          'Only 4 themes equipable at once.',
        );

        expect(controller.unequipTheme(ThemeId.rose), isTrue);
        expect(controller.equipTheme(ThemeId.violet), isTrue);
        expect(controller.isThemeEquipped(ThemeId.violet), isTrue);
        expect(controller.isThemeEquipped(ThemeId.rose), isFalse);
      } finally {
        controller.dispose();
      }
    });

    testWidgets(
      'unequipping the active theme falls back to the first equipped theme and never clears them all',
      (WidgetTester tester) async {
        final GameSessionController controller = GameSessionController(
          feedbackController: NoopFeedbackController(),
          initialAppearance: const AppAppearance(
            theme: ThemeId.rose,
            isDark: true,
          ),
          initialProgress: const PlayerProgress(
            points: 0,
            ownedThemes: <ThemeId>{ThemeId.orange, ThemeId.rose, ThemeId.aqua},
            equippedThemes: <ThemeId>{
              ThemeId.orange,
              ThemeId.rose,
              ThemeId.aqua,
            },
            bestTimesByDifficulty: <Difficulty, int>{},
          ),
        );
        try {
          expect(controller.theme, ThemeId.rose);

          expect(controller.unequipTheme(ThemeId.rose), isTrue);
          expect(controller.theme, ThemeId.orange);

          expect(controller.unequipTheme(ThemeId.aqua), isTrue);
          expect(controller.unequipTheme(ThemeId.orange), isFalse);
          expect(
            controller.transientToastMessage,
            "Can't unequipe everything!",
          );
        } finally {
          controller.dispose();
        }
      },
    );
  });
}
