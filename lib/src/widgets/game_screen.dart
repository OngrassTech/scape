import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_session_controller.dart';
import '../maze_theme.dart';
import '../models.dart';
import 'common.dart';
import 'maze_board.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({
    super.key,
    required this.controller,
    required this.palette,
    this.surfaceKey,
  });

  final GameSessionController controller;
  final MazePalette palette;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    if (!controller.hasMaze) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final BoardLayout layout = calculateBoardLayout(
          Size(constraints.maxWidth, constraints.maxHeight),
          controller.difficulty.config,
        );

        return Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 92, 16, 122),
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: SizedBox(
                    width: layout.boardWidth,
                    height: layout.boardHeight,
                    child: MazeSurfaceFrame(
                      key: surfaceKey,
                      palette: palette,
                      child: MazeBoard(
                        maze: controller.maze,
                        playerPos: controller.playerPos,
                        goalPos: controller.goalPos,
                        trail: controller.trail,
                        hintPath: controller.hintPath,
                        isHintActive: controller.isHintActive,
                        palette: palette,
                        cellSize: layout.cellSize,
                        onMove: controller.move,
                        enabled:
                            controller.isPlaying &&
                            !controller.showLevelComplete &&
                            !controller.isGameOver,
                        successCycle: controller.successCycle,
                        boardVersion: controller.boardVersion,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class GameplaySwipeLayer extends StatefulWidget {
  const GameplaySwipeLayer({
    super.key,
    required this.enabled,
    required this.onMove,
    required this.child,
  });

  final bool enabled;
  final void Function(int dx, int dy) onMove;
  final Widget child;

  @override
  State<GameplaySwipeLayer> createState() => _GameplaySwipeLayerState();
}

class _GameplaySwipeLayerState extends State<GameplaySwipeLayer> {
  Offset? _gestureStart;
  bool _didTriggerSwipe = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: widget.enabled ? _handlePanStart : null,
      onPanUpdate: widget.enabled ? _handlePanUpdate : null,
      onPanEnd: widget.enabled ? _handlePanEnd : null,
      onPanCancel: _resetGesture,
      child: widget.child,
    );
  }

  void _handlePanStart(DragStartDetails details) {
    _gestureStart = details.globalPosition;
    _didTriggerSwipe = false;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_didTriggerSwipe || _gestureStart == null) {
      return;
    }

    final Offset delta = details.globalPosition - _gestureStart!;
    if (delta.distance < 30) {
      return;
    }

    _didTriggerSwipe = true;
    if (delta.dx.abs() > delta.dy.abs()) {
      widget.onMove(delta.dx > 0 ? 1 : -1, 0);
    } else {
      widget.onMove(0, delta.dy > 0 ? 1 : -1);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _resetGesture();
  }

  void _resetGesture() {
    _gestureStart = null;
    _didTriggerSwipe = false;
  }
}

class GameResultOverlay extends StatelessWidget {
  const GameResultOverlay({
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
    if (controller.showLevelComplete) {
      final int? bestTime = controller.bestTimeForDifficulty(
        controller.difficulty,
      );
      final String bestLabelPrefix = controller.lastClearWasNewBest
          ? 'New Best'
          : 'Best';
      return _ResultDialog(
        palette: palette,
        heading: controller.formatTime(controller.lastClearElapsedSeconds),
        accentColor: palette.player,
        topAnimation: SuccessResultAnimation(palette: palette),
        details: controller.lastPointsEarned > 0
            ? <Widget>[
                Text(
                  '+${controller.lastPointsEarned} point${controller.lastPointsEarned == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: palette.player,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Total ${controller.points}',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
              ]
            : const <Widget>[],
        buttons: <Widget>[
          MazeActionButton(
            buttonKey: const Key('success-best-button'),
            label:
                '$bestLabelPrefix: ${bestTime == null ? '--' : '${bestTime}s'}',
            onPressed: controller.openScoreOverlay,
            palette: palette,
          ),
          const SizedBox(height: 14),
          MazeActionButton(
            label: 'Next Maze',
            onPressed: controller.nextMaze,
            palette: palette,
          ),
          const SizedBox(height: 14),
          MazeActionButton(
            label: 'Main Menu',
            onPressed: onMainMenu,
            palette: palette,
          ),
        ],
      );
    }

    if (controller.isGameOver) {
      return _ResultDialog(
        palette: palette,
        heading: "Time's Up!",
        accentColor: const Color(0xFFFF6B6B),
        subheading: '00:00',
        buttons: <Widget>[
          MazeActionButton(
            label: 'Retry',
            onPressed: controller.retryMaze,
            palette: palette,
          ),
          const SizedBox(height: 14),
          MazeActionButton(
            label: 'Next Maze',
            onPressed: controller.nextMaze,
            palette: palette,
          ),
          const SizedBox(height: 14),
          MazeActionButton(
            label: 'Main Menu',
            onPressed: onMainMenu,
            palette: palette,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.palette,
    required this.heading,
    required this.accentColor,
    required this.buttons,
    this.topAnimation,
    this.subheading,
    this.details = const <Widget>[],
  });

  final MazePalette palette;
  final String heading;
  final String? subheading;
  final Color accentColor;
  final List<Widget> buttons;
  final Widget? topAnimation;
  final List<Widget> details;

  @override
  Widget build(BuildContext context) {
    return MazeModal(
      palette: palette,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: FrostedPanel(
          palette: palette,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (topAnimation != null) ...<Widget>[
                topAnimation!,
                const SizedBox(height: 18),
              ],
              if (subheading == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Text(
                    heading,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 54,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                )
              else ...<Widget>[
                Text(
                  heading,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Text(
                    subheading!,
                    style: TextStyle(
                      color: palette.player,
                      fontSize: 54,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
              ...details,
              ...buttons,
            ],
          ),
        ),
      ),
    );
  }
}

class SuccessResultAnimation extends StatefulWidget {
  const SuccessResultAnimation({super.key, required this.palette});

  final MazePalette palette;

  @override
  State<SuccessResultAnimation> createState() => _SuccessResultAnimationState();
}

class _SuccessResultAnimationState extends State<SuccessResultAnimation>
    with SingleTickerProviderStateMixin {
  static const List<_ConfettiChipSpec> _chips = <_ConfettiChipSpec>[
    _ConfettiChipSpec(
      angle: -2.45,
      distance: 30,
      delay: 0.02,
      width: 8,
      height: 8,
    ),
    _ConfettiChipSpec(
      angle: -2.1,
      distance: 38,
      delay: 0.05,
      width: 7,
      height: 10,
    ),
    _ConfettiChipSpec(
      angle: -1.7,
      distance: 44,
      delay: 0.0,
      width: 10,
      height: 6,
    ),
    _ConfettiChipSpec(
      angle: -1.35,
      distance: 36,
      delay: 0.08,
      width: 8,
      height: 8,
    ),
    _ConfettiChipSpec(
      angle: -0.95,
      distance: 42,
      delay: 0.03,
      width: 9,
      height: 6,
    ),
    _ConfettiChipSpec(
      angle: -0.58,
      distance: 34,
      delay: 0.1,
      width: 7,
      height: 9,
    ),
    _ConfettiChipSpec(
      angle: -2.82,
      distance: 26,
      delay: 0.14,
      width: 6,
      height: 6,
    ),
    _ConfettiChipSpec(
      angle: -0.28,
      distance: 28,
      delay: 0.16,
      width: 6,
      height: 6,
    ),
    _ConfettiChipSpec(
      angle: -1.95,
      distance: 48,
      delay: 0.12,
      width: 10,
      height: 7,
    ),
    _ConfettiChipSpec(
      angle: -1.1,
      distance: 50,
      delay: 0.18,
      width: 8,
      height: 8,
    ),
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> chipColors = <Color>[
      widget.palette.player,
      widget.palette.goal,
      widget.palette.uiBorder.withValues(alpha: 0.82),
    ];

    return SizedBox(
      key: const Key('success-confetti-animation'),
      width: 140,
      height: 100,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double pulseProgress = (_controller.value / 0.26)
              .clamp(0.0, 1.0)
              .toDouble();
          final double pulse = Curves.easeOutCubic.transform(pulseProgress);
          final double coreFade =
              1 - Curves.easeIn.transform(_controller.value);

          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: Stack(
                  alignment: Alignment.center,
                  children: List<Widget>.generate(_chips.length, (int index) {
                    final _ConfettiChipSpec chip = _chips[index];
                    final double localProgress =
                        ((_controller.value - chip.delay) / 0.44)
                            .clamp(0.0, 1.0)
                            .toDouble();
                    if (localProgress <= 0) {
                      return const SizedBox.shrink();
                    }

                    final double travel = Curves.easeOutCubic.transform(
                      localProgress,
                    );
                    final double fade =
                        1 -
                        Curves.easeIn.transform(
                          ((localProgress - 0.18) / 0.82)
                              .clamp(0.0, 1.0)
                              .toDouble(),
                        );
                    final double dx =
                        math.cos(chip.angle) * chip.distance * travel;
                    final double dy =
                        math.sin(chip.angle) * chip.distance * travel -
                        (18 * travel);

                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: Opacity(
                        opacity: fade,
                        child: Transform.rotate(
                          angle: chip.angle * 0.35,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: chipColors[index % chipColors.length],
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: SizedBox(
                              width: chip.width,
                              height: chip.height,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Opacity(
                opacity: 0.52 * coreFade,
                child: Transform.scale(
                  scale: 0.86 + (pulse * 0.54),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.palette.player.withValues(alpha: 0.72),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: 0.34 * coreFade,
                child: Transform.scale(
                  scale: 1 + (pulse * 0.16),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.palette.goal.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: 0.96 - (_controller.value * 0.18),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: widget.palette.player,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: widget.palette.playerShadow,
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConfettiChipSpec {
  const _ConfettiChipSpec({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.width,
    required this.height,
  });

  final double angle;
  final double distance;
  final double delay;
  final double width;
  final double height;
}
