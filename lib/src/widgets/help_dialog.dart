import 'dart:ui';

import 'package:flutter/material.dart';

import '../game_session_controller.dart';
import '../maze_theme.dart';
import '../models.dart';
import 'common.dart';
import 'mini_maze_scene.dart';

class HelpDialog extends StatefulWidget {
  const HelpDialog({
    super.key,
    required this.controller,
    required this.palette,
  });

  final GameSessionController controller;
  final MazePalette palette;

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  static const int _pageCount = 3;

  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MazeModal(
      palette: widget.palette,
      onDismiss: widget.controller.closeHelp,
      barrierKey: const Key('help-modal-barrier'),
      panelKey: const Key('help-modal-panel'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: FrostedPanel(
          palette: widget.palette,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 312,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (int value) {
                    setState(() {
                      _page = value;
                    });
                  },
                  children: <Widget>[
                    _HelpPage(
                      palette: widget.palette,
                      title: 'Start Game',
                      body:
                          'Choose the difficulty, then tap the maze to start.',
                      demo: _TapStartDemo(palette: widget.palette),
                    ),
                    _HelpPage(
                      palette: widget.palette,
                      title: 'Swipe to Control',
                      body:
                          'Swipe anywhere in any direction to slide the block until it can turn or hits a wall.',
                      demo: _SwipeDemo(palette: widget.palette),
                    ),
                    _HelpPage(
                      palette: widget.palette,
                      title: 'Scoring',
                      body:
                          'Expert and Nightmare give you 1 point.\n'
                          'In time trial they give 2 points.',
                      demo: _ScoringDemo(palette: widget.palette),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(_pageCount, (int index) {
                  final bool selected = _page == index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: MazeTapScale(
                      onTap: () {
                        widget.controller.playUiFeedback(
                          sound: SoundCue.swipe,
                          haptic: HapticCue.medium,
                        );
                        _pageController.animateToPage(
                          index,
                          duration: MazeMotion.modal,
                          curve: MazeMotion.enterCurve,
                        );
                      },
                      child: AnimatedContainer(
                        duration: MazeMotion.standard,
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: selected
                              ? widget.palette.player
                              : widget.palette.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoringDemo extends StatefulWidget {
  const _ScoringDemo({required this.palette});

  final MazePalette palette;

  @override
  State<_ScoringDemo> createState() => _ScoringDemoState();
}

class _ScoringDemoState extends State<_ScoringDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Position> route = _scoringDemoMaze.route;

    return SizedBox(
      key: const Key('help-scoring-demo'),
      width: 112,
      height: 112,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double moveProgress = Curves.easeInOutCubic.transform(
            (_controller.value / 0.62).clamp(0.0, 1.0),
          );
          final double goalPulse = ((_controller.value - 0.54) / 0.18)
              .clamp(0.0, 1.0)
              .toDouble();
          final double chipProgress = ((_controller.value - 0.66) / 0.18)
              .clamp(0.0, 1.0)
              .toDouble();
          final double chipFade = ((_controller.value - 0.86) / 0.14)
              .clamp(0.0, 1.0)
              .toDouble();
          final Offset playerPosition = _positionAlongRoute(
            route,
            moveProgress,
          );
          final List<Position> visibleTrail = _visibleRouteTrail(
            route,
            moveProgress,
          );

          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              MiniMazeScene(
                maze: _scoringDemoMaze.maze,
                goalPos: _scoringDemoMaze.goal,
                playerOffset: playerPosition,
                palette: widget.palette,
                trail: visibleTrail,
                goalPulse: goalPulse,
                fit: MiniMazeSceneFit.cover,
                showPerimeterWalls: false,
                paintBackground: false,
              ),
              Positioned(
                top: 10,
                right: 4,
                child: Opacity(
                  opacity: chipProgress * (1 - chipFade),
                  child: Transform.translate(
                    offset: Offset(0, lerpDouble(6, -2, chipProgress) ?? 0),
                    child: Container(
                      key: const Key('help-scoring-points-chip'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: widget.palette.player,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: widget.palette.playerShadow,
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Text(
                        '+1',
                        style: TextStyle(
                          color: widget.palette.mazeBg,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
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

class _HelpPage extends StatelessWidget {
  const _HelpPage({
    required this.palette,
    required this.title,
    required this.body,
    required this.demo,
  });

  final MazePalette palette;
  final String title;
  final String body;
  final Widget demo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        demo,
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            color: palette.player,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.player.withValues(alpha: 0.84),
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _TapStartDemo extends StatefulWidget {
  const _TapStartDemo({required this.palette});

  final MazePalette palette;

  @override
  State<_TapStartDemo> createState() => _TapStartDemoState();
}

class _TapStartDemoState extends State<_TapStartDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('help-start-demo'),
      width: 112,
      height: 112,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double phase = (_controller.value * 2) % 1;
          final double pulse = Curves.easeOut.transform(phase);
          const double baseSize = 70;

          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                key: const Key('help-start-thumbnail'),
                width: baseSize,
                height: baseSize,
                child: MazeSurfaceFrame(
                  palette: widget.palette,
                  borderRadius: 24,
                  borderColor: widget.palette.uiBorder,
                  backgroundColor: Colors.transparent,
                  shadowAlpha: 0,
                  child: const SizedBox.expand(),
                ),
              ),
              Opacity(
                opacity: (1 - pulse) * 0.7,
                child: Transform.scale(
                  scale: lerpDouble(1, 1.28, pulse) ?? 1,
                  child: Container(
                    key: const Key('help-start-pulse'),
                    width: baseSize,
                    height: baseSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.palette.player.withValues(alpha: 0.8),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.palette.player,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: widget.palette.playerShadow,
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwipeDemo extends StatefulWidget {
  const _SwipeDemo({required this.palette});

  final MazePalette palette;

  @override
  State<_SwipeDemo> createState() => _SwipeDemoState();
}

class _SwipeDemoState extends State<_SwipeDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('help-swipe-demo'),
      width: 112,
      height: 112,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double raw = _controller.value * 4;
          final int segmentIndex = raw.floor().clamp(0, 3);
          final double segmentProgress = Curves.easeInOut.transform(
            raw - segmentIndex,
          );
          final List<Offset> path = <Offset>[
            const Offset(18, 18),
            const Offset(70, 18),
            const Offset(70, 70),
            const Offset(18, 70),
            const Offset(18, 18),
          ];
          final Offset position = Offset.lerp(
            path[segmentIndex],
            path[segmentIndex + 1],
            segmentProgress,
          )!;

          return Stack(
            children: <Widget>[
              MazeSurfaceFrame(
                palette: widget.palette,
                borderRadius: 28,
                borderColor: widget.palette.player.withValues(alpha: 0.42),
                backgroundColor: Colors.transparent,
                shadowAlpha: 0,
                child: CustomPaint(
                  painter: _SquarePathPainter(
                    color: widget.palette.player.withValues(alpha: 0.2),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 46,
                child: _DemoArrow(
                  icon: Icons.arrow_upward_rounded,
                  color: widget.palette.player,
                  active: segmentIndex == 3,
                ),
              ),
              Positioned(
                top: 46,
                right: 6,
                child: _DemoArrow(
                  icon: Icons.arrow_forward_rounded,
                  color: widget.palette.player,
                  active: segmentIndex == 0,
                ),
              ),
              Positioned(
                bottom: 6,
                left: 46,
                child: _DemoArrow(
                  icon: Icons.arrow_downward_rounded,
                  color: widget.palette.player,
                  active: segmentIndex == 1,
                ),
              ),
              Positioned(
                top: 46,
                left: 6,
                child: _DemoArrow(
                  icon: Icons.arrow_back_rounded,
                  color: widget.palette.player,
                  active: segmentIndex == 2,
                ),
              ),
              Positioned(
                left: position.dx,
                top: position.dy,
                child: Container(
                  key: const Key('help-swipe-block'),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.palette.player,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: widget.palette.playerShadow,
                        blurRadius: 12,
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

class _DemoArrow extends StatelessWidget {
  const _DemoArrow({
    required this.icon,
    required this.color,
    required this.active,
  });

  final IconData icon;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: MazeMotion.quick,
      opacity: active ? 0.92 : 0.24,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SquarePathPainter extends CustomPainter {
  const _SquarePathPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Rect pathRect = Rect.fromLTWH(
      size.width * 0.2,
      size.height * 0.2,
      size.width * 0.6,
      size.height * 0.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pathRect, const Radius.circular(14)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SquarePathPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

final MiniMazePreviewData _scoringDemoMaze = buildGeneratedMiniMazeData(
  seed: 37,
  width: 8,
  height: 8,
  minRouteLength: 12,
);

Offset _positionAlongRoute(List<Position> route, double progress) {
  if (route.length <= 1) {
    return const Offset(0, 0);
  }

  final double clampedProgress = progress.clamp(0.0, 1.0);
  final double scaledProgress = clampedProgress * (route.length - 1);
  final int index = scaledProgress.floor().clamp(0, route.length - 2);
  final double segmentProgress = Curves.easeInOutCubic.transform(
    scaledProgress - index,
  );
  final Position from = route[index];
  final Position to = route[index + 1];

  return Offset.lerp(
        Offset(from.x.toDouble(), from.y.toDouble()),
        Offset(to.x.toDouble(), to.y.toDouble()),
        segmentProgress,
      ) ??
      Offset(to.x.toDouble(), to.y.toDouble());
}

List<Position> _visibleRouteTrail(List<Position> route, double progress) {
  if (route.isEmpty) {
    return const <Position>[];
  }

  final int visibleCount =
      ((route.length - 1) * progress).floor().clamp(0, route.length - 1) + 1;
  return route.take(visibleCount).toList(growable: false);
}
