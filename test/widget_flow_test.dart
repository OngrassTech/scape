import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazegame/src/app.dart';
import 'package:mazegame/src/app_update_models.dart';
import 'package:mazegame/src/feedback.dart';
import 'package:mazegame/src/game_session_controller.dart';
import 'package:mazegame/src/models.dart';
import 'package:mazegame/src/progress_preferences.dart';
import 'package:mazegame/src/widgets/common.dart';
import 'package:mazegame/src/widgets/maze_board.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('menu flow starts a game and exposes resume after system back', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('menu-flow-app'),
          controller: controller,
        ),
      );

      expect(find.text('SCAPE'), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();

      expect(controller.screen, AppScreen.playing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-button')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('resume-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resume-button')));
      await tester.pumpAndSettle();
      expect(controller.screen, AppScreen.playing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('launch intro animation fades away shortly after startup', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('launch-intro-app'),
          controller: controller,
        ),
      );

      expect(find.text('SCAPE'), findsOneWidget);
      expect(find.byKey(const Key('launch-intro-board')), findsOneWidget);
      expect(
        _animatedOpacityValue(tester, const Key('menu-controls-fade')),
        closeTo(0, 0.001),
      );
      expect(
        _animatedOpacityValue(tester, const Key('bottom-nav-fade')),
        closeTo(0, 0.001),
      );

      await _settlePastLaunchIntro(tester);

      expect(find.byKey(const Key('launch-intro-board')), findsNothing);
      expect(
        _animatedOpacityValue(tester, const Key('menu-controls-fade')),
        closeTo(1, 0.001),
      );
      expect(
        _animatedOpacityValue(tester, const Key('bottom-nav-fade')),
        closeTo(1, 0.001),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('launch intro maze has surrounding passages beyond the route', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('launch-intro-maze-app'),
          controller: controller,
        ),
      );

      final MazeBoard board = tester.widget<MazeBoard>(
        find.byKey(const Key('launch-intro-board')),
      );
      int offRouteOpenCells = 0;

      for (final List<MazeCell> row in board.maze) {
        for (final MazeCell cell in row) {
          final Position position = Position(cell.x, cell.y);
          if (_launchIntroRoute.contains(position)) {
            continue;
          }

          final bool hasOpening =
              !cell.walls.top ||
              !cell.walls.right ||
              !cell.walls.bottom ||
              !cell.walls.left;
          if (hasOpening) {
            offRouteOpenCells++;
          }
        }
      }

      expect(offRouteOpenCells, greaterThanOrEqualTo(24));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'difficulty label exits before the next label enters from the opposite side',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('difficulty-slide-app'),
            controller: controller,
          ),
        );
        await _settlePastLaunchIntro(tester);

        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));

        expect(find.text('Easy'), findsOneWidget);
        expect(find.text('Medium'), findsOneWidget);
        expect(
          _difficultyLabelOffset(tester, Difficulty.easy),
          greaterThan(0.12),
        );
        expect(
          _difficultyLabelOffset(tester, Difficulty.medium),
          lessThan(-0.3),
        );
        expect(
          _difficultyLabelOpacity(tester, Difficulty.medium),
          closeTo(0, 0.001),
        );

        await tester.pump(const Duration(milliseconds: 80));

        expect(
          _difficultyLabelOpacity(tester, Difficulty.medium),
          greaterThan(0.2),
        );

        await tester.pumpAndSettle();
        expect(find.text('Medium'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));

        expect(find.text('Medium'), findsOneWidget);
        expect(find.text('Easy'), findsOneWidget);
        expect(
          _difficultyLabelOffset(tester, Difficulty.medium),
          lessThan(-0.12),
        );
        expect(
          _difficultyLabelOffset(tester, Difficulty.easy),
          greaterThan(0.3),
        );
        expect(
          _difficultyLabelOpacity(tester, Difficulty.easy),
          closeTo(0, 0.001),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('main menu back requires a second press to exit', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('double-back-app'),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      platformCalls.clear();

      expect(find.byKey(const Key('exit-toast')), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byKey(const Key('exit-toast')), findsOneWidget);
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(platformCalls, isEmpty);
      expect(find.byKey(const Key('bottom-nav-pill')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(
        platformCalls.where(
          (MethodCall call) => call.method == 'SystemNavigator.pop',
        ),
        hasLength(1),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('exit toast stays anchored to the bottom with padding', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = const FakeViewPadding(bottom: 10);
    tester.view.padding = const FakeViewPadding(bottom: 10);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);

    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('bottom-toast-app'),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(MazeMotion.standard);

      final Rect navRect = tester.getRect(
        find.byKey(const Key('bottom-nav-pill')),
      );
      expect(navRect.bottom, 816);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('settings toggles update controller state', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('settings-flow-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      await tester.tap(
        find.byKey(const Key('settings-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sound-toggle')));
      await tester.pumpAndSettle();
      expect(controller.soundEnabled, isFalse);

      await tester.tap(find.byKey(const Key('haptics-toggle')));
      await tester.pumpAndSettle();
      expect(controller.hapticsEnabled, isFalse);

      await tester.tapAt(
        tester.getTopLeft(find.byType(MazeModal)) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('time-trial-button')));
      await tester.pump();
      expect(controller.isTimeTrial, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('menu settings keep only options toggles and footer content', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('menu-settings-order-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      await tester.tap(find.byKey(const Key('settings-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sound-toggle')), findsOneWidget);
      expect(find.byKey(const Key('haptics-toggle')), findsOneWidget);
      expect(find.byKey(const Key('open-shop-button')), findsNothing);
      expect(find.byKey(const Key('open-score-button')), findsNothing);
      expect(find.byKey(const Key('time-trial-toggle')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('settings-main-menu-footer')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-main-menu-footer-divider')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('check-updates-button')), findsOneWidget);
      expect(find.text('Scape v1.0.1'), findsOneWidget);
      expect(find.text('© 2026 OngrassTech'), findsOneWidget);
      expect(find.text('github.com/OngrassTech/scape'), findsOneWidget);
      expect(find.text('Licensed under GPLv3'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('first manual haptics re-enable shows the system toast', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('haptics-toast-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      await tester.tap(find.byKey(const Key('settings-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('haptics-toggle')));
      await tester.pumpAndSettle();
      expect(controller.hapticsEnabled, isFalse);
      expect(find.text('Turn on all system haptics.'), findsNothing);

      await tester.tap(find.byKey(const Key('haptics-toggle')));
      await tester.pump();

      expect(controller.hapticsEnabled, isTrue);
      expect(find.text('Turn on all system haptics.'), findsOneWidget);
      expect(find.byKey(const Key('purchase-toast')), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('update checks stay idle until the settings button is tapped', (
    WidgetTester tester,
  ) async {
    int lookupCalls = 0;
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
      appUpdateLookup: (String currentVersion) async {
        lookupCalls++;
        return const AppUpdateResult.upToDate(
          message: 'Scape v1.0.1 is up to date.',
        );
      },
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('check-updates-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);
      expect(lookupCalls, 0);

      await tester.tap(find.byKey(const Key('settings-button')));
      await tester.pumpAndSettle();
      expect(lookupCalls, 0);

      await tester.tap(find.byKey(const Key('check-updates-button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(lookupCalls, 1);
      expect(find.text('Scape v1.0.1 is up to date.'), findsOneWidget);
      expect(find.byKey(const Key('purchase-toast')), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'update checks reveal an Update button and stretch the settings panel',
    (WidgetTester tester) async {
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
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('available-update-app'),
            controller: controller,
          ),
        );
        await _settlePastLaunchIntro(tester);

        await tester.tap(find.byKey(const Key('settings-button')));
        await tester.pumpAndSettle();

        final Rect panelBefore = tester.getRect(
          find.byKey(const Key('settings-modal-panel')),
        );
        expect(find.byKey(const Key('update-button')), findsNothing);

        await tester.tap(find.byKey(const Key('check-updates-button')));
        await tester.pump();
        await tester.pumpAndSettle();

        final Rect panelAfter = tester.getRect(
          find.byKey(const Key('settings-modal-panel')),
        );
        final Rect checkButtonAfterRect = tester.getRect(
          find.byKey(const Key('check-updates-button')),
        );
        final Rect updateButtonRect = tester.getRect(
          find.byKey(const Key('update-button')),
        );

        expect(controller.hasAvailableUpdate, isTrue);
        expect(find.byKey(const Key('purchase-toast')), findsNothing);
        expect(updateButtonRect.top, greaterThan(checkButtonAfterRect.bottom));
        expect(panelAfter.height, greaterThan(panelBefore.height));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'closing settings dismisses an overlay toast without moving it to the top',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GameSessionController controller = GameSessionController(
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('overlay-toast-close-app'),
            controller: controller,
          ),
        );
        await _settlePastLaunchIntro(tester);

        await tester.tap(find.byKey(const Key('settings-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('haptics-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('haptics-toggle')));
        await tester.pump();

        expect(find.text('Turn on all system haptics.'), findsOneWidget);
        expect(find.byKey(const Key('purchase-toast')), findsOneWidget);

        await tester.tapAt(
          tester.getTopLeft(find.byType(MazeModal)) + const Offset(8, 8),
        );
        await tester.pump();

        expect(find.byKey(const Key('settings-modal-panel')), findsNothing);
        expect(find.byKey(const Key('purchase-toast')), findsNothing);
        expect(find.text('Turn on all system haptics.'), findsNothing);

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('purchase-toast')), findsNothing);
        expect(find.text('Turn on all system haptics.'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('shop includes gold and dandelion themes', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('yellow-theme-shop-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      await tester.tap(find.byKey(const Key('shop-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shop-card-gold')), findsOneWidget);
      expect(find.byKey(const Key('shop-card-dandelion')), findsOneWidget);
      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Dandelion'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'gameplay settings keep actions above toggles and hide the footer',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: const OpenRouteMazeGenerator(),
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('game-settings-order-app'),
            controller: controller,
          ),
        );

        await tester.tap(find.byKey(const Key('menu-preview-card')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('settings-button')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('open-shop-button')), findsNothing);
        expect(
          tester.getTopLeft(find.text('Main Menu')).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('sound-toggle'))).dy),
        );
        expect(
          find.byKey(const Key('settings-main-menu-footer-divider')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('settings-main-menu-footer')),
          findsNothing,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('theme selector starts with amber only and adds purchases', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
      initialProgress: const PlayerProgress(
        points: 69,
        ownedThemes: <ThemeId>{ThemeId.orange},
        bestTimesByDifficulty: <Difficulty, int>{},
      ),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('theme-unlock-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      await tester.tap(find.byKey(const Key('theme-toggle-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theme-option-orange')), findsOneWidget);
      expect(find.byKey(const Key('theme-option-rose')), findsNothing);
      expect(find.byKey(const Key('theme-option-emerald')), findsNothing);

      await tester.tap(find.byKey(const Key('theme-toggle-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('shop-button')));
      await tester.pumpAndSettle();
      expect(find.text('Amber'), findsOneWidget);
      expect(find.text('Orange'), findsNothing);
      expect(find.byKey(const Key('shop-preview-orange')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('shop-action-rose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shop-action-rose')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shop-action-rose')));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getTopLeft(find.byType(MazeModal)) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('theme-toggle-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('theme-option-rose')), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('locked theme purchase shows not enough points toast', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
      initialProgress: const PlayerProgress(
        points: 0,
        ownedThemes: <ThemeId>{ThemeId.orange},
        bestTimesByDifficulty: <Difficulty, int>{},
      ),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('purchase-toast-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      await tester.tap(find.byKey(const Key('shop-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('shop-action-slate')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shop-action-slate')));
      await tester.pump();

      expect(find.byKey(const Key('purchase-toast')), findsOneWidget);
      expect(find.text('Not enough points'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('shop shows an equip limit toast when a fifth theme is added', (
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
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('equip-limit-toast-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      await tester.tap(find.byKey(const Key('shop-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('shop-action-violet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shop-action-violet')));
      await tester.pump();

      expect(find.byKey(const Key('purchase-toast')), findsOneWidget);
      expect(find.text('Only 4 themes equipable at once.'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('score popup shows one seconds value per difficulty', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
      initialProgress: const PlayerProgress(
        points: 0,
        ownedThemes: <ThemeId>{ThemeId.orange},
        bestTimesByDifficulty: <Difficulty, int>{
          Difficulty.easy: 12,
          Difficulty.nightmare: 88,
        },
      ),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('score-popup-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      await tester.tap(find.byKey(const Key('points-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-score-view')), findsOneWidget);
      expect(find.byKey(const Key('score-minimal-list')), findsOneWidget);
      expect(find.byKey(const Key('score-card')), findsNothing);
      expect(find.text('12s'), findsOneWidget);
      expect(find.text('88s'), findsOneWidget);
      expect(find.byKey(const Key('score-value-medium')), findsOneWidget);
      expect(find.text('--'), findsWidgets);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('settings main menu does not expose resume', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('settings-main-menu-app'),
          controller: controller,
        ),
      );

      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();
      expect(controller.screen, AppScreen.playing);

      await tester.tap(
        find.byKey(const Key('settings-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main Menu'));
      await tester.pump();
      await tester.pump(MazeMotion.modal);
      await tester.pumpAndSettle();

      expect(controller.screen, AppScreen.menu);
      expect(controller.canResume, isFalse);
      expect(find.byKey(const Key('resume-button')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'settings main menu dismisses the popup before the board morphs home',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easyLPathMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('settings-main-menu-morph-app'),
            controller: controller,
          ),
        );

        await tester.tap(find.byKey(const Key('menu-preview-card')));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('settings-button')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('settings-modal-panel')), findsOneWidget);

        await tester.tap(find.text('Main Menu'));
        await tester.pump();

        expect(find.byKey(const Key('settings-modal-panel')), findsNothing);
        expect(controller.screen, AppScreen.playing);
        expect(find.byKey(const Key('surface-morph-frame')), findsNothing);

        await tester.pump(MazeMotion.modal);
        expect(controller.screen, AppScreen.menu);
        await tester.pump();
        expect(find.byKey(const Key('surface-morph-frame')), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byKey(const Key('resume-button')), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('drag from outside the board still moves during gameplay', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('global-swipe-app'),
          controller: controller,
        ),
      );

      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();

      expect(controller.playerPos, const Position(0, 0));

      final Offset swipeStart = tester.getCenter(
        find.byKey(const Key('settings-button')),
      );
      await tester.dragFrom(swipeStart, const Offset(90, 0));
      await tester.pumpAndSettle();

      expect(controller.playerPos, const Position(9, 0));
      expect(find.byKey(const Key('settings-modal-panel')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('tap on a top control still works during gameplay', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('gameplay-settings-tap-app'),
          controller: controller,
        ),
      );

      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();

      expect(controller.playerPos, const Position(0, 0));

      await tester.tap(
        find.byKey(const Key('settings-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-modal-panel')), findsOneWidget);
      expect(controller.playerPos, const Position(0, 0));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'gameplay time trial button resets the maze state and timer immediately',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easyLPathMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('gameplay-time-trial-delay-app'),
            controller: controller,
          ),
        );

        await tester.tap(find.byKey(const Key('menu-preview-card')));
        await tester.pumpAndSettle();
        controller.move(1, 0);
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        expect(controller.playerPos, isNot(const Position(0, 0)));
        expect(controller.time, 3);

        await tester.tap(find.byKey(const Key('time-trial-button')));
        await tester.pump();

        expect(controller.isTimeTrial, isTrue);
        expect(controller.time, 15);
        expect(controller.playerPos, const Position(0, 0));
        expect(controller.trail, <Position>[const Position(0, 0)]);
        expect(find.text('00:15'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));

        expect(controller.time, 14);
        expect(find.text('00:14'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'time trial toggle shows a short inline nav toast without resizing the nav',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easyLPathMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('time-trial-inline-toast-app'),
            controller: controller,
          ),
        );
        await _settlePastLaunchIntro(tester);
        await tester.tap(find.byKey(const Key('menu-preview-card')));
        await tester.pumpAndSettle();

        final Rect navRectBefore = tester.getRect(
          find.byKey(const Key('bottom-nav-pill')),
        );

        await tester.tap(find.byKey(const Key('time-trial-button')));
        await tester.pump(const Duration(milliseconds: 320));

        final Rect navRectDuring = tester.getRect(
          find.byKey(const Key('bottom-nav-pill')),
        );

        expect(controller.isTimeTrial, isTrue);
        expect(find.text('Time trial: ON'), findsOneWidget);
        expect(find.byKey(const Key('time-trial-toast')), findsOneWidget);
        expect(
          (navRectBefore.width - navRectDuring.width).abs(),
          lessThanOrEqualTo(1),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(find.byKey(const Key('time-trial-toast')), findsNothing);
        expect(find.byKey(const Key('time-trial-button')), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('menu time trial toggle does not create resume', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      controller.startNewGame();
      controller.backToMenu(withFeedback: false);

      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('menu-time-trial-resume-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      expect(controller.hasMaze, isTrue);
      expect(controller.canResume, isFalse);

      await tester.tap(find.byKey(const Key('time-trial-button')));
      await tester.pump();

      expect(controller.isTimeTrial, isFalse);
      expect(controller.canResume, isFalse);
      expect(find.byKey(const Key('resume-button')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('saved session restores a resume button on relaunch', (
    WidgetTester tester,
  ) async {
    final MemorySessionPreferences sessionPreferences =
        MemorySessionPreferences();
    final GameSessionController originalController = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
      sessionPreferences: sessionPreferences,
    );
    try {
      originalController.startNewGame();
      originalController.move(1, 0);
      await originalController.persistSession();

      final savedSession = await sessionPreferences.loadSession();
      expect(savedSession, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      originalController.dispose();

      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('relaunch-resume-app'),
          sessionPreferences: sessionPreferences,
          initialSession: savedSession,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('resume-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resume-button')), findsNothing);
      expect(find.byKey(const Key('menu-preview-card')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('level complete and failure dialogs expose their actions', (
    WidgetTester tester,
  ) async {
    final GameSessionController winController = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    final GameSessionController loseController = GameSessionController(
      generator: FixedMazeGenerator(easySnakeMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('win-flow-app'),
          controller: winController,
        ),
      );
      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();

      winController.move(1, 0);
      winController.move(0, 1);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('success-confetti-animation')),
        findsOneWidget,
      );
      expect(find.text('Next Maze'), findsOneWidget);
      expect(find.text('Main Menu'), findsOneWidget);

      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('lose-flow-app'),
          controller: loseController,
        ),
      );
      loseController.toggleTimeTrial();
      loseController.startNewGame();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();

      expect(find.text("Time's Up!"), findsOneWidget);
      expect(find.byKey(const Key('success-confetti-animation')), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Next Maze'), findsOneWidget);
      expect(find.text('Main Menu'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      winController.dispose();
      loseController.dispose();
    }
  });

  testWidgets(
    'success main menu dismisses the result before the board morphs home',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easyLPathMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('success-main-menu-morph-app'),
            controller: controller,
          ),
        );
        await tester.tap(find.byKey(const Key('menu-preview-card')));
        await tester.pumpAndSettle();

        controller.move(1, 0);
        controller.move(0, 1);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        expect(find.byType(MazeModal), findsOneWidget);

        await tester.tap(find.text('Main Menu'));
        await tester.pump();

        expect(find.byType(MazeModal), findsNothing);
        expect(controller.screen, AppScreen.playing);
        expect(find.byKey(const Key('surface-morph-frame')), findsNothing);

        await tester.pump(MazeMotion.modal);
        expect(controller.screen, AppScreen.menu);
        await tester.pump();
        expect(find.byKey(const Key('surface-morph-frame')), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byKey(const Key('resume-button')), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'failure main menu dismisses the result before the board morphs home',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('failure-main-menu-morph-app'),
            controller: controller,
          ),
        );
        controller.toggleTimeTrial();
        controller.startNewGame();
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();

        expect(find.byType(MazeModal), findsOneWidget);

        await tester.tap(find.text('Main Menu'));
        await tester.pump();

        expect(find.byType(MazeModal), findsNothing);
        expect(controller.screen, AppScreen.playing);
        expect(find.byKey(const Key('surface-morph-frame')), findsNothing);

        await tester.pump(MazeMotion.modal);
        expect(controller.screen, AppScreen.menu);
        await tester.pump();
        expect(find.byKey(const Key('surface-morph-frame')), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byKey(const Key('resume-button')), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('difficulty boards fit a small phone viewport without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('responsive-app'),
          controller: controller,
        ),
      );

      for (final Difficulty difficulty in Difficulty.values) {
        controller.setDifficulty(difficulty);
        controller.startNewGame();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        controller.backToMenu(withFeedback: false);
        await tester.pumpAndSettle();
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('next maze resets the board fade and trail to the start cell', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('next-maze-reset-app'),
          controller: controller,
        ),
      );

      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();

      controller.move(1, 0);
      controller.move(0, 1);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next Maze'));
      await tester.pumpAndSettle();

      expect(controller.playerPos, const Position(0, 0));
      expect(controller.trail, <Position>[const Position(0, 0)]);
      expect(
        _fadeValue(tester, const Key('board-player-fade')),
        closeTo(1, 0.001),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'hint animation fades trail out, reveals hint, then restores trail',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easySnakeMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        controller.startNewGame();
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('hint-sequence-app'),
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          _fadeValue(tester, const Key('board-trail-fade')),
          closeTo(1, 0.001),
        );
        expect(
          _fadeValue(tester, const Key('board-hint-fade')),
          closeTo(0, 0.001),
        );

        controller.showHint();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));

        expect(controller.hintPath, isEmpty);
        expect(
          _fadeValue(tester, const Key('board-trail-fade')),
          lessThan(0.05),
        );
        expect(
          _fadeValue(tester, const Key('board-hint-fade')),
          closeTo(0, 0.001),
        );

        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 90));

        expect(controller.hintPath, isNotEmpty);
        expect(
          _fadeValue(tester, const Key('board-hint-fade')),
          greaterThan(0.2),
        );

        await tester.pump(const Duration(milliseconds: 1910));
        await tester.pump(const Duration(milliseconds: 90));

        expect(controller.hintPath, isEmpty);
        expect(_fadeValue(tester, const Key('board-hint-fade')), lessThan(0.8));

        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 180));

        expect(controller.isHintActive, isFalse);
        expect(
          _fadeValue(tester, const Key('board-hint-fade')),
          lessThan(0.05),
        );
        expect(
          _fadeValue(tester, const Key('board-trail-fade')),
          greaterThan(0.95),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('bottom nav hides while help and settings overlays are visible', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('utility-overlay-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      expect(find.byKey(const Key('menu-preview-outline')), findsOneWidget);
      expect(
        _animatedOpacityValue(tester, const Key('bottom-nav-fade')),
        closeTo(1, 0.001),
      );
      expect(find.byKey(const Key('settings-button')), findsOneWidget);
      expect(find.byKey(const Key('assist-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('assist-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('help-modal-panel')), findsOneWidget);
      expect(find.byKey(const Key('help-start-thumbnail')), findsOneWidget);
      expect(find.byKey(const Key('help-start-pulse')), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-220, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('help-swipe-demo')), findsOneWidget);
      expect(find.byKey(const Key('help-swipe-block')), findsOneWidget);
      expect(
        find.text(
          'Swipe anywhere in any direction to slide the block until it can turn or hits a wall.',
        ),
        findsOneWidget,
      );
      await tester.drag(find.byType(PageView), const Offset(-220, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('help-scoring-demo')), findsOneWidget);
      expect(find.byKey(const Key('help-scoring-points-chip')), findsOneWidget);
      expect(
        find.text(
          'Expert and Nightmare give you 1 point.\nIn time trial they give 2 points.',
        ),
        findsOneWidget,
      );
      expect(
        _animatedOpacityValue(tester, const Key('bottom-nav-fade')),
        closeTo(0, 0.001),
      );

      await tester.tapAt(
        tester.getTopLeft(find.byType(MazeModal)) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('settings-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-modal-panel')), findsOneWidget);
      expect(
        _animatedOpacityValue(tester, const Key('bottom-nav-fade')),
        closeTo(0, 0.001),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('bottom nav hides during win and loss overlays', (
    WidgetTester tester,
  ) async {
    final GameSessionController winController = GameSessionController(
      generator: FixedMazeGenerator(easyLPathMaze()),
      feedbackController: NoopFeedbackController(),
    );
    final GameSessionController loseController = GameSessionController(
      generator: FixedMazeGenerator(easySnakeMaze()),
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('utility-win-app'),
          controller: winController,
        ),
      );

      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();

      winController.move(1, 0);
      winController.move(0, 1);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        _animatedOpacityValue(tester, const Key('bottom-nav-fade')),
        closeTo(0, 0.001),
      );

      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('utility-loss-app'),
          controller: loseController,
        ),
      );
      loseController.toggleTimeTrial();
      loseController.startNewGame();
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();

      expect(
        _animatedOpacityValue(tester, const Key('bottom-nav-fade')),
        closeTo(0, 0.001),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      winController.dispose();
      loseController.dispose();
    }
  });

  testWidgets('bottom nav and gameplay timer reuse the same pill height', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      feedbackController: NoopFeedbackController(),
    );
    try {
      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('top-pill-app'),
          controller: controller,
        ),
      );
      await _settlePastLaunchIntro(tester);

      final Rect navRect = tester.getRect(
        find.byKey(const Key('bottom-nav-pill')),
      );
      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();
      final Rect timerRect = tester.getRect(
        find.byKey(const Key('game-timer-pill')),
      );

      expect((navRect.height - timerRect.height).abs(), lessThanOrEqualTo(4));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets(
    'bottom nav, gameplay timer, and resume button keep transparent fills',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('transparent-controls-app'),
            controller: controller,
          ),
        );
        await _settlePastLaunchIntro(tester);

        final BoxDecoration navDecoration =
            tester
                    .widget<DecoratedBox>(
                      find.byKey(const Key('bottom-nav-pill')),
                    )
                    .decoration
                as BoxDecoration;
        expect(navDecoration.color, Colors.transparent);
        expect(navDecoration.boxShadow, isNull);

        await tester.tap(find.byKey(const Key('menu-preview-card')));
        await tester.pumpAndSettle();

        final AnimatedContainer timerContainer = tester
            .widget<AnimatedContainer>(
              find.byKey(const Key('game-timer-pill')),
            );
        final BoxDecoration timerDecoration =
            timerContainer.decoration! as BoxDecoration;
        final Rect timerRect = tester.getRect(
          find.byKey(const Key('game-timer-pill')),
        );

        expect(timerDecoration.color, Colors.transparent);
        expect(timerDecoration.boxShadow, isNull);
        expect(timerRect.width, lessThanOrEqualTo(110));

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        final FilledButton resumeButton = tester.widget<FilledButton>(
          find.byKey(const Key('resume-button')),
        );
        expect(
          resumeButton.style?.backgroundColor?.resolve(<WidgetState>{}),
          Colors.transparent,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'help, settings, and result overlays use the shared modal wrapper',
    (WidgetTester tester) async {
      final GameSessionController controller = GameSessionController(
        generator: FixedMazeGenerator(easyLPathMaze()),
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('modal-wrapper-app'),
            controller: controller,
          ),
        );
        await _settlePastLaunchIntro(tester);

        await tester.tap(find.byKey(const Key('assist-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(MazeModal), findsOneWidget);
        expect(find.byKey(const Key('help-modal-panel')), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
        await tester.tapAt(
          tester.getTopLeft(find.byType(MazeModal)) + const Offset(8, 8),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MazeModal), findsNothing);

        await tester.tap(find.byKey(const Key('settings-button')));
        await tester.pumpAndSettle();
        expect(find.byType(MazeModal), findsOneWidget);
        expect(find.byKey(const Key('settings-modal-panel')), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
        await tester.tapAt(
          tester.getTopLeft(find.byType(MazeModal)) + const Offset(8, 8),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MazeModal), findsNothing);

        await tester.tap(find.byKey(const Key('menu-preview-card')));
        await tester.pumpAndSettle();

        controller.move(1, 0);
        controller.move(0, 1);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        expect(find.byType(MazeModal), findsOneWidget);
        expect(find.text('Next Maze'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets(
    'background maze reaches the top while controls stay inside safe areas',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);

      final GameSessionController controller = GameSessionController(
        feedbackController: NoopFeedbackController(),
      );
      try {
        await tester.pumpWidget(
          MazeGameApp(
            key: const ValueKey<String>('background-safe-area-app'),
            controller: controller,
          ),
        );
        await _settlePastLaunchIntro(tester);

        final Rect backgroundRect = tester.getRect(
          find.byKey(const Key('title-background-maze')),
        );
        final Rect navRect = tester.getRect(
          find.byKey(const Key('bottom-nav-pill')),
        );

        await tester.tap(find.byKey(const Key('menu-preview-card')));
        await tester.pumpAndSettle();
        final Rect timerRect = tester.getRect(
          find.byKey(const Key('game-timer-pill')),
        );

        expect(backgroundRect.top, 0);
        expect(backgroundRect.bottom, 844);
        expect(timerRect.top, 60);
        expect(navRect.bottom, 810);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    },
  );

  testWidgets('expert win popup shows earned points and total balance', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: const OpenRouteMazeGenerator(),
      feedbackController: NoopFeedbackController(),
    );
    try {
      controller.setDifficulty(Difficulty.expert);

      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('win-points-app'),
          controller: controller,
        ),
      );

      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      controller.move(1, 0);
      controller.move(0, 1);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('+1 point'), findsOneWidget);
      expect(find.text('Total 1'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('success best button opens the score screen', (
    WidgetTester tester,
  ) async {
    final GameSessionController controller = GameSessionController(
      generator: const OpenRouteMazeGenerator(),
      feedbackController: NoopFeedbackController(),
    );
    try {
      controller.setDifficulty(Difficulty.expert);

      await tester.pumpWidget(
        MazeGameApp(
          key: const ValueKey<String>('success-best-score-app'),
          controller: controller,
        ),
      );

      await tester.tap(find.byKey(const Key('menu-preview-card')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      controller.move(1, 0);
      controller.move(0, 1);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final int? bestTime = controller.bestTimeForDifficulty(Difficulty.expert);
      expect(bestTime, isNotNull);
      expect(find.byKey(const Key('success-best-button')), findsOneWidget);
      expect(find.text('New Best: ${bestTime}s'), findsOneWidget);

      await tester.tap(find.byKey(const Key('success-best-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-score-view')), findsOneWidget);
      expect(find.byKey(const Key('success-best-button')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });
}

double _fadeValue(WidgetTester tester, Key key) {
  return tester.widget<FadeTransition>(find.byKey(key)).opacity.value;
}

double _animatedOpacityValue(WidgetTester tester, Key key) {
  return tester.widget<AnimatedOpacity>(find.byKey(key)).opacity;
}

double _difficultyLabelOffset(WidgetTester tester, Difficulty difficulty) {
  return tester
      .widget<SlideTransition>(
        find.byKey(ValueKey<String>('difficulty-slide-${difficulty.name}')),
      )
      .position
      .value
      .dx;
}

double _difficultyLabelOpacity(WidgetTester tester, Difficulty difficulty) {
  return tester
      .widget<FadeTransition>(
        find.byKey(ValueKey<String>('difficulty-fade-${difficulty.name}')),
      )
      .opacity
      .value;
}

Future<void> _settlePastLaunchIntro(WidgetTester tester) async {
  await tester.pump(MazeMotion.launchIntro);
  await tester.pumpAndSettle();
}

final Set<Position> _launchIntroRoute = <Position>{
  Position(0, 0),
  Position(1, 0),
  Position(2, 0),
  Position(3, 0),
  Position(4, 0),
  Position(5, 0),
  Position(6, 0),
  Position(7, 0),
  Position(7, 1),
  Position(7, 2),
  Position(7, 3),
  Position(6, 3),
  Position(5, 3),
  Position(4, 3),
  Position(3, 3),
  Position(2, 3),
  Position(2, 4),
  Position(2, 5),
  Position(2, 6),
  Position(2, 7),
  Position(3, 7),
  Position(4, 7),
  Position(5, 7),
  Position(6, 7),
  Position(7, 7),
};
