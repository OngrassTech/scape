import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../game_session_controller.dart';
import '../maze_logic.dart';
import '../maze_theme.dart';
import '../models.dart';
import 'common.dart';
import 'maze_board.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({
    super.key,
    required this.controller,
    required this.palette,
    required this.onStartGame,
    this.showLaunchIntro = false,
    this.surfaceKey,
  });

  final GameSessionController controller;
  final MazePalette palette;
  final VoidCallback onStartGame;
  final bool showLaunchIntro;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    final List<Difficulty> difficulties = Difficulty.values;
    final int index = difficulties.indexOf(controller.difficulty);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentHeight = max(
          constraints.maxHeight,
          controller.canResume ? 560 : 512,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: contentHeight,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 34),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    'SCAPE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textMain,
                      fontSize: constraints.maxWidth < 360 ? 52 : 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 224,
                            height: 224,
                            child: GestureDetector(
                              key: const Key('menu-preview-card'),
                              behavior: HitTestBehavior.opaque,
                              onTap: onStartGame,
                              child: _MazePreviewCard(
                                surfaceKey: surfaceKey,
                                palette: palette,
                                showLaunchIntro: showLaunchIntro,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          IgnorePointer(
                            ignoring: showLaunchIntro,
                            child: AnimatedOpacity(
                              key: const Key('menu-controls-fade'),
                              duration: MazeMotion.standard,
                              curve: MazeMotion.enterCurve,
                              opacity: showLaunchIntro ? 0 : 1,
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: _DifficultySelector(
                                          controller: controller,
                                          palette: palette,
                                          difficulties: difficulties,
                                          index: index,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  AnimatedSize(
                                    duration: MazeMotion.standard,
                                    curve: MazeMotion.enterCurve,
                                    alignment: Alignment.topCenter,
                                    child: AnimatedSwitcher(
                                      duration: MazeMotion.standard,
                                      switchInCurve: MazeMotion.enterCurve,
                                      switchOutCurve: MazeMotion.exitCurve,
                                      transitionBuilder: _buildFadeTransition,
                                      child: controller.canResume
                                          ? Padding(
                                              key: const ValueKey<String>(
                                                'resume',
                                              ),
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: MazeActionButton(
                                                buttonKey: const Key(
                                                  'resume-button',
                                                ),
                                                label: 'Resume',
                                                onPressed:
                                                    controller.resumeGame,
                                                palette: palette,
                                                backgroundColor:
                                                    Colors.transparent,
                                              ),
                                            )
                                          : const SizedBox(
                                              key: ValueKey<String>(
                                                'resume-empty',
                                              ),
                                              height: 0,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _buildFadeTransition(Widget child, Animation<double> animation) {
  return FadeTransition(opacity: animation, child: child);
}

class _MazePreviewCard extends StatelessWidget {
  const _MazePreviewCard({
    this.surfaceKey,
    required this.palette,
    required this.showLaunchIntro,
  });

  final Key? surfaceKey;
  final MazePalette palette;
  final bool showLaunchIntro;

  @override
  Widget build(BuildContext context) {
    return MazeSurfaceFrame(
      key: surfaceKey,
      palette: palette,
      borderRadius: 28,
      borderColor: palette.uiBorder,
      backgroundColor: Colors.transparent,
      shadowAlpha: 0,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const SizedBox.expand(key: Key('menu-preview-outline')),
          AnimatedSwitcher(
            duration: MazeMotion.standard,
            switchInCurve: MazeMotion.enterCurve,
            switchOutCurve: MazeMotion.exitCurve,
            transitionBuilder: _buildFadeTransition,
            child: showLaunchIntro
                ? _LaunchPreviewAnimation(
                    key: const ValueKey<String>('launch-preview-active'),
                    palette: palette,
                  )
                : const SizedBox(key: ValueKey<String>('launch-preview-empty')),
          ),
        ],
      ),
    );
  }
}

class _DifficultySelector extends StatefulWidget {
  const _DifficultySelector({
    required this.controller,
    required this.palette,
    required this.difficulties,
    required this.index,
  });

  final GameSessionController controller;
  final MazePalette palette;
  final List<Difficulty> difficulties;
  final int index;

  @override
  State<_DifficultySelector> createState() => _DifficultySelectorState();
}

class _DifficultySelectorState extends State<_DifficultySelector>
    with SingleTickerProviderStateMixin {
  static const Duration _transitionDuration = Duration(milliseconds: 360);
  static const double _transitionSplit = 0.48;
  static const double _hiddenShift = 0.32;

  late final AnimationController _transitionController;
  late Difficulty _visibleDifficulty;
  Difficulty? _outgoingDifficulty;
  Difficulty? _incomingDifficulty;
  int _slideDirection = 1;

  @override
  void initState() {
    super.initState();
    _visibleDifficulty = widget.controller.difficulty;
    _transitionController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    )..addStatusListener(_handleTransitionStatus);
  }

  @override
  void dispose() {
    _transitionController
      ..removeStatusListener(_handleTransitionStatus)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DifficultySelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    final Difficulty nextDifficulty = widget.controller.difficulty;
    if (nextDifficulty == _settledDifficulty) {
      return;
    }

    if (_transitionController.isAnimating) {
      _finishTransition();
    }

    final int previousIndex = widget.difficulties.indexOf(_visibleDifficulty);
    final int nextIndex = widget.difficulties.indexOf(nextDifficulty);
    if (previousIndex != -1 && nextIndex != -1 && previousIndex != nextIndex) {
      _slideDirection = (nextIndex - previousIndex).sign;
    }

    setState(() {
      _outgoingDifficulty = _visibleDifficulty;
      _incomingDifficulty = nextDifficulty;
    });
    _transitionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          child: widget.index > 0
              ? MazePressEffect(
                  child: IconButton(
                    onPressed: () => _setDifficulty(widget.index - 1),
                    enableFeedback: false,
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: widget.palette.player,
                      size: 28,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: ClipRect(
            child: SizedBox(
              height: 32,
              child: AnimatedBuilder(
                animation: _transitionController,
                builder: (BuildContext context, Widget? child) {
                  if (_incomingDifficulty == null) {
                    return _buildDifficultyLabel(
                      _visibleDifficulty,
                      offsetDx: 0,
                      opacity: 1,
                      scale: 1,
                    );
                  }

                  final double progress = _transitionController.value;
                  final double outgoingPhase = Curves.easeInCubic.transform(
                    (progress / _transitionSplit).clamp(0.0, 1.0),
                  );
                  final double incomingPhase = Curves.easeOutCubic.transform(
                    ((progress - _transitionSplit) / (1 - _transitionSplit))
                        .clamp(0.0, 1.0),
                  );
                  final double incomingScalePhase = Curves.easeOutBack
                      .transform(
                        ((progress - _transitionSplit) / (1 - _transitionSplit))
                            .clamp(0.0, 1.0),
                      );

                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _buildDifficultyLabel(
                        _outgoingDifficulty!,
                        offsetDx:
                            _hiddenShift * _slideDirection * outgoingPhase,
                        opacity: 1 - outgoingPhase,
                        scale: 1 - (0.02 * outgoingPhase),
                      ),
                      _buildDifficultyLabel(
                        _incomingDifficulty!,
                        offsetDx:
                            -_hiddenShift *
                            _slideDirection *
                            (1 - incomingPhase),
                        opacity: incomingPhase,
                        scale: 0.94 + (0.06 * incomingScalePhase),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: widget.index < widget.difficulties.length - 1
              ? MazePressEffect(
                  child: IconButton(
                    onPressed: () => _setDifficulty(widget.index + 1),
                    enableFeedback: false,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: widget.palette.player,
                      size: 28,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDifficultyLabel(
    Difficulty difficulty, {
    required double offsetDx,
    required double opacity,
    required double scale,
  }) {
    return SlideTransition(
      key: ValueKey<String>('difficulty-slide-${difficulty.name}'),
      position: AlwaysStoppedAnimation<Offset>(Offset(offsetDx, 0)),
      child: FadeTransition(
        key: ValueKey<String>('difficulty-fade-${difficulty.name}'),
        opacity: AlwaysStoppedAnimation<double>(opacity),
        child: ScaleTransition(
          scale: AlwaysStoppedAnimation<double>(scale),
          child: SizedBox(
            key: ValueKey<Difficulty>(difficulty),
            width: double.infinity,
            child: Text(
              difficulty.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.palette.player,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setDifficulty(int nextIndex) {
    final Difficulty nextDifficulty = widget.difficulties[nextIndex];
    if (nextDifficulty == widget.controller.difficulty) {
      return;
    }

    _slideDirection = (nextIndex - widget.index).sign;
    widget.controller.playUiFeedback(
      sound: SoundCue.swipe,
      haptic: HapticCue.medium,
    );
    widget.controller.setDifficulty(nextDifficulty);
  }

  Difficulty get _settledDifficulty =>
      _incomingDifficulty ?? _visibleDifficulty;

  void _handleTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }

    setState(_finishTransition);
  }

  void _finishTransition() {
    if (_incomingDifficulty != null) {
      _visibleDifficulty = _incomingDifficulty!;
    }
    _outgoingDifficulty = null;
    _incomingDifficulty = null;
    _transitionController.value = 0;
  }
}

class _LaunchPreviewAnimation extends StatefulWidget {
  const _LaunchPreviewAnimation({super.key, required this.palette});

  final MazePalette palette;

  @override
  State<_LaunchPreviewAnimation> createState() =>
      _LaunchPreviewAnimationState();
}

class _LaunchPreviewAnimationState extends State<_LaunchPreviewAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MazeMotion.launchIntro,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = _launchIntroMaze.first.length;
          final int rows = _launchIntroMaze.length;
          final double cellSize = constraints.maxWidth / columns;

          return AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, _) {
              final double progress = _controller.value;
              final double boardScale =
                  lerpDouble(
                    1.14,
                    1.0,
                    Curves.easeInOutCubic.transform(progress),
                  ) ??
                  1.0;
              final double boardLift =
                  lerpDouble(8, 0, Curves.easeInOutCubic.transform(progress)) ??
                  0;
              final _LaunchIntroFrame frame = _launchIntroFrameFor(progress);

              return ColoredBox(
                color: widget.palette.mazeBg,
                child: Transform.translate(
                  offset: Offset(0, boardLift),
                  child: Transform.scale(
                    scale: boardScale,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: rows * cellSize,
                      child: MazeBoard(
                        key: const Key('launch-intro-board'),
                        maze: _launchIntroMaze,
                        playerPos: frame.playerPos,
                        goalPos: _launchIntroGoal,
                        trail: frame.trail,
                        hintPath: const <Position>[],
                        isHintActive: false,
                        palette: widget.palette,
                        cellSize: cellSize,
                        onMove: (int dx, int dy) {},
                        enabled: false,
                        successCycle: 0,
                        boardVersion: 0,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LaunchIntroFrame {
  const _LaunchIntroFrame({required this.playerPos, required this.trail});

  final Position playerPos;
  final List<Position> trail;
}

const Position _launchIntroGoal = Position(7, 7);

const List<_LaunchIntroFrame> _launchIntroFrames = <_LaunchIntroFrame>[
  _LaunchIntroFrame(
    playerPos: Position(0, 0),
    trail: <Position>[Position(0, 0)],
  ),
  _LaunchIntroFrame(
    playerPos: Position(7, 0),
    trail: <Position>[
      Position(0, 0),
      Position(1, 0),
      Position(2, 0),
      Position(3, 0),
      Position(4, 0),
      Position(5, 0),
      Position(6, 0),
      Position(7, 0),
    ],
  ),
  _LaunchIntroFrame(
    playerPos: Position(7, 3),
    trail: <Position>[
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
    ],
  ),
  _LaunchIntroFrame(
    playerPos: Position(2, 3),
    trail: <Position>[
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
    ],
  ),
  _LaunchIntroFrame(
    playerPos: Position(2, 7),
    trail: <Position>[
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
    ],
  ),
  _LaunchIntroFrame(
    playerPos: Position(7, 7),
    trail: <Position>[
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
    ],
  ),
];

const List<double> _launchIntroStops = <double>[
  0.0,
  0.18,
  0.36,
  0.56,
  0.78,
  0.92,
];

final List<List<MazeCell>> _launchIntroMaze = _buildLaunchIntroMaze();

_LaunchIntroFrame _launchIntroFrameFor(double progress) {
  for (int index = _launchIntroStops.length - 1; index >= 0; index--) {
    if (progress >= _launchIntroStops[index]) {
      return _launchIntroFrames[index];
    }
  }
  return _launchIntroFrames.first;
}

List<List<MazeCell>> _buildLaunchIntroMaze() {
  final List<List<MazeCell>> maze = const MazeGenerator()
      .generate(8, 8, random: Random(17))
      .map(
        (List<MazeCell> row) =>
            row.map((MazeCell cell) => cell.copy()).toList(growable: false),
      )
      .toList(growable: false);

  for (int x = 0; x < 7; x++) {
    _openLaunchIntroRight(maze, x, 0);
  }
  for (int y = 0; y < 3; y++) {
    _openLaunchIntroBottom(maze, 7, y);
  }
  for (int x = 2; x < 7; x++) {
    _openLaunchIntroRight(maze, x, 3);
  }
  for (int y = 3; y < 7; y++) {
    _openLaunchIntroBottom(maze, 2, y);
  }
  for (int x = 2; x < 7; x++) {
    _openLaunchIntroRight(maze, x, 7);
  }

  return maze;
}

void _openLaunchIntroRight(List<List<MazeCell>> maze, int x, int y) {
  maze[y][x].walls.right = false;
  maze[y][x + 1].walls.left = false;
}

void _openLaunchIntroBottom(List<List<MazeCell>> maze, int x, int y) {
  maze[y][x].walls.bottom = false;
  maze[y + 1][x].walls.top = false;
}
