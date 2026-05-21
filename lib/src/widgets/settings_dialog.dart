import 'package:flutter/material.dart';

import '../app_metadata.dart';
import '../game_session_controller.dart';
import '../maze_theme.dart';
import '../models.dart';
import 'common.dart';
import 'mini_maze_scene.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({
    super.key,
    required this.controller,
    required this.palette,
    required this.onMainMenu,
  });

  final GameSessionController controller;
  final MazePalette palette;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return MazeModal(
      palette: palette,
      onDismiss: controller.closeSettings,
      barrierKey: const Key('settings-modal-barrier'),
      panelKey: const Key('settings-modal-panel'),
      child: AnimatedSize(
        key: const Key('settings-modal-morph'),
        duration: MazeMotion.surfaceMorph,
        curve: MazeMotion.enterCurve,
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 560),
          child: FrostedPanel(
            palette: palette,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: AnimatedSwitcher(
              duration: MazeMotion.standard,
              switchInCurve: MazeMotion.enterCurve,
              switchOutCurve: MazeMotion.exitCurve,
              layoutBuilder:
                  (Widget? currentChild, List<Widget> previousChildren) =>
                      currentChild ?? const SizedBox.shrink(),
              child: KeyedSubtree(
                key: ValueKey<SettingsPanelPage>(controller.settingsPage),
                child: switch (controller.settingsPage) {
                  SettingsPanelPage.options => _SettingsHomePage(
                    controller: controller,
                    palette: palette,
                    onMainMenu: onMainMenu,
                  ),
                  SettingsPanelPage.shop => _ShopPage(
                    controller: controller,
                    palette: palette,
                  ),
                  SettingsPanelPage.score => _ScorePage(
                    controller: controller,
                    palette: palette,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsHomePage extends StatelessWidget {
  const _SettingsHomePage({
    required this.controller,
    required this.palette,
    required this.onMainMenu,
  });

  final GameSessionController controller;
  final MazePalette palette;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    final bool isGameplay = controller.screen == AppScreen.playing;

    return SingleChildScrollView(
      key: const Key('settings-options-view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isGameplay) ...<Widget>[
            MazeActionButton(
              label: 'Retry',
              onPressed: controller.retryMaze,
              palette: palette,
            ),
            const SizedBox(height: 14),
            MazeActionButton(
              label: 'New Maze',
              onPressed: controller.nextMaze,
              palette: palette,
            ),
            const SizedBox(height: 14),
            MazeActionButton(
              label: 'Main Menu',
              onPressed: onMainMenu,
              palette: palette,
            ),
            const SizedBox(height: 24),
            Divider(color: palette.player.withValues(alpha: 0.18), height: 1),
          ],
          const SizedBox(height: 24),
          SettingToggleRow(
            label: 'Sound',
            value: controller.soundEnabled,
            onTap: controller.toggleSound,
            palette: palette,
            toggleKey: const Key('sound-toggle'),
          ),
          const SizedBox(height: 20),
          SettingToggleRow(
            label: 'Haptics',
            value: controller.hapticsEnabled,
            onTap: controller.toggleHaptics,
            palette: palette,
            toggleKey: const Key('haptics-toggle'),
          ),
          if (!isGameplay) ...<Widget>[
            const SizedBox(height: 24),
            Divider(
              key: const Key('settings-main-menu-footer-divider'),
              color: palette.player.withValues(alpha: 0.18),
              height: 1,
            ),
            const SizedBox(height: 24),
            Column(
              key: const Key('settings-main-menu-footer'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AnimatedSize(
                  duration: MazeMotion.surfaceMorph,
                  curve: MazeMotion.enterCurve,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      MazeActionButton(
                        buttonKey: const Key('check-updates-button'),
                        label: controller.isCheckingForUpdates
                            ? 'Checking...'
                            : 'Check for Updates',
                        onPressed: controller.isCheckingForUpdates
                            ? null
                            : controller.checkForUpdates,
                        palette: palette,
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      AnimatedSwitcher(
                        duration: MazeMotion.standard,
                        switchInCurve: MazeMotion.enterCurve,
                        switchOutCurve: MazeMotion.exitCurve,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  axisAlignment: -1,
                                  child: child,
                                ),
                              );
                            },
                        child: controller.hasAvailableUpdate
                            ? Padding(
                                key: const ValueKey<String>(
                                  'settings-update-button-visible',
                                ),
                                padding: const EdgeInsets.only(top: 14),
                                child: MazeActionButton(
                                  buttonKey: const Key('update-button'),
                                  label: 'Update',
                                  onPressed: () {
                                    controller.openAvailableUpdate();
                                  },
                                  palette: palette,
                                  backgroundColor: palette.player.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderColor: palette.player,
                                ),
                              )
                            : const SizedBox(
                                key: ValueKey<String>(
                                  'settings-update-button-hidden',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$appName $appDisplayVersion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.player,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appCopyrightLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.player.withValues(alpha: 0.84),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  appGithubRepoLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.player.withValues(alpha: 0.84),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Licensed under the MIT License',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.player.withValues(alpha: 0.84),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopPage extends StatelessWidget {
  const _ShopPage({required this.controller, required this.palette});

  final GameSessionController controller;
  final MazePalette palette;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('settings-shop-view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SubviewHeader(
            title: 'Shop',
            palette: palette,
            onBack: controller.showSettingsHome,
          ),
          const SizedBox(height: 18),
          Container(
            key: const Key('shop-points-balance'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: palette.uiBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.player, width: 2),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  'Points',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${controller.points}',
                  style: TextStyle(
                    color: palette.player,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...shopThemeOrder.expand((ThemeId theme) {
            return <Widget>[
              _ShopThemeCard(
                controller: controller,
                palette: palette,
                theme: theme,
              ),
              if (theme != shopThemeOrder.last) const SizedBox(height: 14),
            ];
          }),
        ],
      ),
    );
  }
}

class _ScorePage extends StatelessWidget {
  const _ScorePage({required this.controller, required this.palette});

  final GameSessionController controller;
  final MazePalette palette;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = Difficulty.values
        .map((Difficulty difficulty) {
          final int? bestTime = controller.bestTimeForDifficulty(difficulty);
          final bool isLast = difficulty == Difficulty.values.last;
          return Column(
            children: <Widget>[
              Row(
                key: Key('score-row-${difficulty.name}'),
                children: <Widget>[
                  Expanded(
                    child: Text(
                      difficulty.label,
                      style: TextStyle(
                        color: palette.player,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    bestTime == null ? '--' : '${bestTime}s',
                    key: Key('score-value-${difficulty.name}'),
                    style: TextStyle(
                      color: bestTime == null
                          ? palette.player.withValues(alpha: 0.58)
                          : palette.player,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (!isLast) ...<Widget>[
                const SizedBox(height: 12),
                Divider(
                  color: palette.player.withValues(alpha: 0.14),
                  height: 1,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        })
        .toList(growable: false);

    return SingleChildScrollView(
      key: const Key('settings-score-view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SubviewHeader(
            title: 'Score',
            palette: palette,
            onBack: controller.showSettingsHome,
          ),
          const SizedBox(height: 18),
          Text(
            'Lowest clear time for each difficulty.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.player.withValues(alpha: 0.84),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            key: const Key('score-minimal-list'),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _SubviewHeader extends StatelessWidget {
  const _SubviewHeader({
    required this.title,
    required this.palette,
    required this.onBack,
  });

  final String title;
  final MazePalette palette;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        MazePressEffect(
          child: IconButton(
            key: Key('${title.toLowerCase()}-back-button'),
            onPressed: onBack,
            enableFeedback: false,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: palette.player,
              size: 24,
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.player,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _ShopThemeCard extends StatelessWidget {
  const _ShopThemeCard({
    required this.controller,
    required this.palette,
    required this.theme,
  });

  final GameSessionController controller;
  final MazePalette palette;
  final ThemeId theme;

  @override
  Widget build(BuildContext context) {
    final MazePalette previewPalette = _previewPaletteForTheme(
      theme,
      isDark: controller.isDark,
    );
    final bool owned = controller.isThemeOwned(theme);
    final bool equipped = controller.isThemeEquipped(theme);
    final bool usingTheme = controller.theme == theme;
    final String statusLabel;
    final String primaryActionLabel;
    final VoidCallback? primaryAction;
    final Color actionBorderColor;

    if (!owned) {
      statusLabel = '${theme.shopCost} pts';
      primaryActionLabel = 'Buy';
      primaryAction = () => controller.buyTheme(theme);
      actionBorderColor = previewPalette.player;
    } else {
      statusLabel = usingTheme
          ? 'Active'
          : equipped
          ? 'Equipped'
          : 'Owned';
      primaryActionLabel = equipped ? 'Unequip' : 'Equip';
      primaryAction = equipped
          ? () => controller.unequipTheme(theme)
          : () => controller.equipTheme(theme);
      actionBorderColor = equipped ? palette.uiBorder : previewPalette.player;
    }

    return Container(
      key: Key('shop-card-${theme.name}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.uiBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.uiBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  theme.label,
                  style: TextStyle(
                    color: previewPalette.player,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: previewPalette.player.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  key: Key('shop-status-${theme.name}'),
                  style: TextStyle(
                    color: previewPalette.player,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MazeThemePreview(theme: theme, previewPalette: previewPalette),
          const SizedBox(height: 14),
          MazeActionButton(
            buttonKey: Key('shop-action-${theme.name}'),
            label: primaryActionLabel,
            onPressed: primaryAction,
            palette: palette,
            backgroundColor: previewPalette.uiBg,
            foregroundColor: previewPalette.player,
            disabledForegroundColor: previewPalette.textMuted,
            borderColor: actionBorderColor,
          ),
        ],
      ),
    );
  }
}

class _MazeThemePreview extends StatelessWidget {
  const _MazeThemePreview({required this.theme, required this.previewPalette});

  final ThemeId theme;
  final MazePalette previewPalette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('shop-preview-${theme.name}'),
      height: 108,
      child: MazeSurfaceFrame(
        palette: previewPalette,
        borderRadius: 26,
        borderColor: previewPalette.grid,
        backgroundColor: previewPalette.mazeBg,
        shadowAlpha: 0,
        child: MiniMazeScene(
          maze: _shopPreviewLayout.maze.maze,
          goalPos: _shopPreviewLayout.goal,
          playerOffset: Offset(
            _shopPreviewLayout.player.x.toDouble(),
            _shopPreviewLayout.player.y.toDouble(),
          ),
          palette: previewPalette,
          fit: MiniMazeSceneFit.cover,
          alignment: Alignment.center,
          showPerimeterWalls: false,
        ),
      ),
    );
  }
}

MazePalette _previewPaletteForTheme(ThemeId theme, {required bool isDark}) {
  return MazeThemeRegistry.resolve(theme, isDark);
}

class _ShopPreviewLayout {
  const _ShopPreviewLayout({
    required this.maze,
    required this.player,
    required this.goal,
  });

  final MiniMazePreviewData maze;
  final Position player;
  final Position goal;
}

final MiniMazePreviewData _shopPreviewMaze = buildGeneratedMiniMazeData(
  seed: 23,
  width: 11,
  height: 4,
  minRouteLength: 11,
);

final _ShopPreviewLayout _shopPreviewLayout = _buildShopPreviewLayout();

_ShopPreviewLayout _buildShopPreviewLayout() {
  final int width = _shopPreviewMaze.maze.first.length;
  final int height = _shopPreviewMaze.maze.length;

  return _ShopPreviewLayout(
    maze: _shopPreviewMaze,
    player: _pickShopPreviewPosition(
      width: width,
      height: height,
      preferTopLeft: true,
    ),
    goal: _pickShopPreviewPosition(
      width: width,
      height: height,
      preferTopLeft: false,
    ),
  );
}

Position _pickShopPreviewPosition({
  required int width,
  required int height,
  required bool preferTopLeft,
}) {
  final Iterable<Position> preferredRoute = preferTopLeft
      ? _shopPreviewMaze.route.take(
          (_shopPreviewMaze.route.length * 0.65).ceil(),
        )
      : _shopPreviewMaze.route.skip(
          (_shopPreviewMaze.route.length * 0.35).floor(),
        );

  final List<Position> interiorCandidates = preferredRoute
      .where(
        (Position position) =>
            position.x > 0 &&
            position.x < width - 1 &&
            position.y > 0 &&
            position.y < height - 1,
      )
      .toList(growable: false);
  final List<Position> edgeCandidates = preferredRoute
      .where(
        (Position position) =>
            position != _shopPreviewMaze.start &&
            position != _shopPreviewMaze.goal,
      )
      .toList(growable: false);
  final List<Position> candidates = interiorCandidates.isNotEmpty
      ? interiorCandidates
      : edgeCandidates.isNotEmpty
      ? edgeCandidates
      : _shopPreviewMaze.route;

  Position best = candidates.first;
  int bestScore = _previewCornerScore(
    best,
    width: width,
    height: height,
    preferTopLeft: preferTopLeft,
  );

  for (final Position candidate in candidates.skip(1)) {
    final int score = _previewCornerScore(
      candidate,
      width: width,
      height: height,
      preferTopLeft: preferTopLeft,
    );
    if (score < bestScore) {
      best = candidate;
      bestScore = score;
    }
  }

  return best;
}

int _previewCornerScore(
  Position position, {
  required int width,
  required int height,
  required bool preferTopLeft,
}) {
  if (preferTopLeft) {
    return (position.x * 2) + position.y;
  }
  return ((width - 1 - position.x) * 2) + (height - 1 - position.y);
}
