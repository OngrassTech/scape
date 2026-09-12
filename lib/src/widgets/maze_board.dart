import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../maze_theme.dart';
import '../models.dart';
import 'common.dart';

class BoardLayout {
  const BoardLayout({
    required this.cellSize,
    required this.boardWidth,
    required this.boardHeight,
  });

  final double cellSize;
  final double boardWidth;
  final double boardHeight;
}

BoardLayout calculateBoardLayout(Size viewport, DifficultyConfig config) {
  final double maxCellWidth = viewport.width / (config.width + 2);
  final double maxCellHeight = (viewport.height - 220) / (config.height + 2);
  final double cellSize = max(
    8,
    min(maxCellWidth, maxCellHeight).floorToDouble(),
  );

  return BoardLayout(
    cellSize: cellSize,
    boardWidth: config.width * cellSize,
    boardHeight: config.height * cellSize,
  );
}

class MazeBoard extends StatefulWidget {
  const MazeBoard({
    super.key,
    required this.maze,
    required this.playerPos,
    required this.goalPos,
    required this.trail,
    required this.hintPath,
    required this.isHintActive,
    required this.palette,
    required this.cellSize,
    required this.onMove,
    required this.enabled,
    required this.successCycle,
    required this.boardVersion,
    this.showOuterBorder = true,
  });

  final List<List<MazeCell>> maze;
  final Position playerPos;
  final Position goalPos;
  final List<Position> trail;
  final List<Position> hintPath;
  final bool isHintActive;
  final MazePalette palette;
  final double cellSize;
  final void Function(int dx, int dy) onMove;
  final bool enabled;
  final int successCycle;
  final int boardVersion;
  final bool showOuterBorder;

  @override
  State<MazeBoard> createState() => _MazeBoardState();
}

class _MazeBoardState extends State<MazeBoard> with TickerProviderStateMixin {
  late final AnimationController _successController;
  late final AnimationController _playerMoveController;
  late final AnimationController _trailOpacityController;
  late final AnimationController _hintOpacityController;

  late Offset _playerBegin;
  late Offset _playerEnd;
  int _lastSuccessCycle = 0;
  int _lastBoardVersion = 0;

  @override
  void initState() {
    super.initState();
    _lastSuccessCycle = widget.successCycle;
    _lastBoardVersion = widget.boardVersion;
    _playerBegin = _offsetFor(widget.playerPos);
    _playerEnd = _offsetFor(widget.playerPos);
    _successController = AnimationController(
      vsync: this,
      duration: MazeMotion.boardSuccess,
    );
    _playerMoveController = AnimationController(
      vsync: this,
      duration: MazeMotion.quick,
      value: 1,
    );
    _trailOpacityController = AnimationController(
      vsync: this,
      duration: MazeMotion.quick,
      value: widget.isHintActive ? 0 : 1,
    );
    _hintOpacityController = AnimationController(
      vsync: this,
      duration: MazeMotion.quick,
      value: widget.hintPath.isNotEmpty ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant MazeBoard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.boardVersion != _lastBoardVersion) {
      _lastBoardVersion = widget.boardVersion;
      _resetBoardAnimations();
    } else if (widget.playerPos != oldWidget.playerPos) {
      _animatePlayer(oldWidget.playerPos, widget.playerPos);
    }

    if (widget.successCycle != _lastSuccessCycle) {
      _lastSuccessCycle = widget.successCycle;
      _successController.forward(from: 0);
    }

    if (!oldWidget.isHintActive && widget.isHintActive) {
      _trailOpacityController.animateTo(
        0,
        duration: MazeMotion.quick,
        curve: MazeMotion.exitCurve,
      );
      if (widget.hintPath.isEmpty) {
        _hintOpacityController.value = 0;
      }
    }

    if (oldWidget.hintPath.isEmpty && widget.hintPath.isNotEmpty) {
      _hintOpacityController.forward(from: 0);
    }

    if (oldWidget.hintPath.isNotEmpty && widget.hintPath.isEmpty) {
      _hintOpacityController.reverse(from: _hintOpacityController.value);
    }

    if (oldWidget.isHintActive && !widget.isHintActive) {
      _trailOpacityController.forward(from: _trailOpacityController.value);
    }
  }

  @override
  void dispose() {
    _successController.dispose();
    _playerMoveController.dispose();
    _trailOpacityController.dispose();
    _hintOpacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.maze.isEmpty) {
      return const SizedBox.shrink();
    }

    final int width = widget.maze.first.length;
    final int height = widget.maze.length;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: SizedBox(
        width: width * widget.cellSize,
        height: height * widget.cellSize,
        child: AnimatedBuilder(
          animation: _successController,
          builder: (BuildContext context, _) {
            final double successScale =
                1 + (sin(_successController.value * pi) * 0.022);

            return Transform.scale(
              scale: successScale,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(
                    painter: _MazeBasePainter(
                      maze: widget.maze,
                      palette: widget.palette,
                      cellSize: widget.cellSize,
                      showOuterBorder: widget.showOuterBorder,
                    ),
                  ),
                  FadeTransition(
                    key: const Key('board-trail-fade'),
                    opacity: _trailOpacityController,
                    child: CustomPaint(
                      painter: _TrailPainter(
                        trail: widget.trail.toSet(),
                        palette: widget.palette,
                        cellSize: widget.cellSize,
                      ),
                    ),
                  ),
                  FadeTransition(
                    key: const Key('board-hint-fade'),
                    opacity: _hintOpacityController,
                    child: CustomPaint(
                      painter: _HintPainter(
                        hintPath: widget.hintPath.toSet(),
                        palette: widget.palette,
                        cellSize: widget.cellSize,
                      ),
                    ),
                  ),
                  FadeTransition(
                    key: const Key('board-goal-fade'),
                    opacity: ReverseAnimation(_successController),
                    child: CustomPaint(
                      painter: _GoalPainter(
                        goalPos: widget.goalPos,
                        palette: widget.palette,
                        cellSize: widget.cellSize,
                      ),
                    ),
                  ),
                  FadeTransition(
                    key: const Key('board-player-fade'),
                    opacity: ReverseAnimation(_successController),
                    child: AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[
                        _playerMoveController,
                        _successController,
                      ]),
                      builder: (BuildContext context, _) {
                        return CustomPaint(
                          painter: _PlayerPainter(
                            playerOffset: _currentPlayerOffset(),
                            palette: widget.palette,
                            cellSize: widget.cellSize,
                            successProgress: _successController.value,
                          ),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      key: const Key('board-success-burst'),
                      painter: _SuccessBurstPainter(
                        goalPos: widget.goalPos,
                        palette: widget.palette,
                        cellSize: widget.cellSize,
                        progress: _successController.value,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onMove(0, -1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onMove(0, 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onMove(-1, 0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onMove(1, 0);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Offset _offsetFor(Position position) {
    return Offset(position.x.toDouble(), position.y.toDouble());
  }

  Offset _currentPlayerOffset() {
    return Offset.lerp(
          _playerBegin,
          _playerEnd,
          MazeMotion.enterCurve.transform(_playerMoveController.value),
        ) ??
        _playerEnd;
  }

  void _animatePlayer(Position previous, Position next) {
    final Offset currentVisual = _currentPlayerOffset();
    final int distance = max(
      (next.x - previous.x).abs(),
      (next.y - previous.y).abs(),
    );
    final int durationMs = min(240, 140 + ((distance - 1).clamp(0, 4) * 24));

    _playerBegin = currentVisual;
    _playerEnd = _offsetFor(next);
    _playerMoveController.duration = Duration(milliseconds: durationMs);
    _playerMoveController.forward(from: 0);
  }

  void _resetBoardAnimations() {
    _successController.value = 0;
    _playerMoveController.value = 1;
    _playerBegin = _offsetFor(widget.playerPos);
    _playerEnd = _offsetFor(widget.playerPos);
    _trailOpacityController.value = widget.isHintActive ? 0 : 1;
    _hintOpacityController.value = widget.hintPath.isNotEmpty ? 1 : 0;
  }
}

class _MazeBasePainter extends CustomPainter {
  const _MazeBasePainter({
    required this.maze,
    required this.palette,
    required this.cellSize,
    required this.showOuterBorder,
  });

  final List<List<MazeCell>> maze;
  final MazePalette palette;
  final double cellSize;
  final bool showOuterBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()..color = palette.mazeBg;
    final Paint wallPaint = Paint()
      ..color = palette.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final int lastColumn = maze.isNotEmpty ? maze.first.length - 1 : -1;
    final int lastRow = maze.length - 1;

    canvas.drawRect(Offset.zero & size, backgroundPaint);

    for (int y = 0; y < maze.length; y++) {
      for (int x = 0; x < maze[y].length; x++) {
        final MazeCell cell = maze[y][x];
        final Rect cellRect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );

        if (cell.walls.right && (showOuterBorder || x != lastColumn)) {
          canvas.drawLine(cellRect.topRight, cellRect.bottomRight, wallPaint);
        }
        if (cell.walls.bottom && (showOuterBorder || y != lastRow)) {
          canvas.drawLine(cellRect.bottomLeft, cellRect.bottomRight, wallPaint);
        }
      }
    }

    if (showOuterBorder) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), wallPaint);
      canvas.drawLine(Offset.zero, Offset(0, size.height), wallPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MazeBasePainter oldDelegate) {
    return oldDelegate.maze != maze ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.showOuterBorder != showOuterBorder;
  }
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter({
    required this.trail,
    required this.palette,
    required this.cellSize,
  });

  final Set<Position> trail;
  final MazePalette palette;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint trailPaint = Paint()..color = palette.trail;

    for (final Position position in trail) {
      final Rect cellRect = Rect.fromLTWH(
        position.x * cellSize,
        position.y * cellSize,
        cellSize,
        cellSize,
      );
      final double inset = max(2, cellSize * 0.15);
      final Rect trailRect = cellRect.deflate(inset);
      canvas.drawRRect(
        RRect.fromRectAndRadius(trailRect, Radius.circular(cellSize * 0.1)),
        trailPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) {
    return oldDelegate.trail != trail ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize;
  }
}

class _HintPainter extends CustomPainter {
  const _HintPainter({
    required this.hintPath,
    required this.palette,
    required this.cellSize,
  });

  final Set<Position> hintPath;
  final MazePalette palette;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint hintPaint = Paint()
      ..color = palette.trail.withValues(alpha: 0.72);

    for (final Position position in hintPath) {
      final Rect cellRect = Rect.fromLTWH(
        position.x * cellSize,
        position.y * cellSize,
        cellSize,
        cellSize,
      );
      final Rect hintRect = Rect.fromLTWH(
        cellRect.left + cellSize * 0.25,
        cellRect.top + cellSize * 0.25,
        cellSize * 0.5,
        cellSize * 0.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(hintRect, Radius.circular(cellSize * 0.12)),
        hintPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HintPainter oldDelegate) {
    return oldDelegate.hintPath != hintPath ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize;
  }
}

class _GoalPainter extends CustomPainter {
  const _GoalPainter({
    required this.goalPos,
    required this.palette,
    required this.cellSize,
  });

  final Position goalPos;
  final MazePalette palette;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect cellRect = Rect.fromLTWH(
      goalPos.x * cellSize,
      goalPos.y * cellSize,
      cellSize,
      cellSize,
    );
    final Rect glowRect = cellRect.deflate(cellSize * 0.08);
    final Rect goalRect = cellRect.deflate(cellSize * 0.15);
    final Paint goalShadowPaint = Paint()..color = palette.goalShadow;
    final Paint goalPaint = Paint()..color = palette.goal;

    canvas.drawRRect(
      RRect.fromRectAndRadius(glowRect, Radius.circular(cellSize * 0.16)),
      goalShadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(goalRect, Radius.circular(cellSize * 0.14)),
      goalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoalPainter oldDelegate) {
    return oldDelegate.goalPos != goalPos ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize;
  }
}

class _PlayerPainter extends CustomPainter {
  const _PlayerPainter({
    required this.playerOffset,
    required this.palette,
    required this.cellSize,
    required this.successProgress,
  });

  final Offset playerOffset;
  final MazePalette palette;
  final double cellSize;
  final double successProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect cellRect = Rect.fromLTWH(
      playerOffset.dx * cellSize,
      playerOffset.dy * cellSize,
      cellSize,
      cellSize,
    );
    final double shadowScale = lerpDouble(1, 0, successProgress) ?? 1;
    final double playerScale = lerpDouble(1, 0, successProgress) ?? 1;
    final Paint playerShadowPaint = Paint()..color = palette.playerShadow;
    final Paint playerPaint = Paint()..color = palette.player;
    final Rect shadowRect = _scaledInsetRect(
      cellRect,
      0.12,
      shadowScale,
      cellSize,
    );
    final Rect playerRect = _scaledInsetRect(
      cellRect,
      0.15,
      playerScale,
      cellSize,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, Radius.circular(cellSize * 0.16)),
      playerShadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, Radius.circular(cellSize * 0.14)),
      playerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayerPainter oldDelegate) {
    return oldDelegate.playerOffset != playerOffset ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.successProgress != successProgress;
  }
}

class _SuccessBurstPainter extends CustomPainter {
  const _SuccessBurstPainter({
    required this.goalPos,
    required this.palette,
    required this.cellSize,
    required this.progress,
  });

  final Position goalPos;
  final MazePalette palette;
  final double cellSize;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final Rect cellRect = Rect.fromLTWH(
      goalPos.x * cellSize,
      goalPos.y * cellSize,
      cellSize,
      cellSize,
    );
    final Offset center = cellRect.center;
    final double glowProgress = Curves.easeOutCubic.transform(
      (progress / 0.6).clamp(0.0, 1.0),
    );
    final double fade = 1 - Curves.easeInCubic.transform(progress);

    final Paint glowPaint = Paint()
      ..color = palette.goal.withValues(alpha: 0.20 * fade)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellSize * 0.18);
    canvas.drawCircle(
      center,
      cellSize * (0.34 + (glowProgress * 0.92)),
      glowPaint,
    );

    for (final double delay in <double>[0, 0.12]) {
      final double ringProgress = ((progress - delay) / 0.52)
          .clamp(0.0, 1.0)
          .toDouble();
      if (ringProgress <= 0) {
        continue;
      }

      final double ringFade =
          1 - Curves.easeIn.transform(ringProgress.clamp(0.0, 1.0));
      final double ringScale = lerpDouble(0.7, 2.4, ringProgress) ?? 2.4;
      final Rect ringRect = Rect.fromCenter(
        center: center,
        width: cellSize * ringScale,
        height: cellSize * ringScale,
      );
      final Paint ringPaint = Paint()
        ..color = palette.player.withValues(alpha: 0.42 * ringFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(2.4, 1.2, ringProgress) ?? 1.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          ringRect,
          Radius.circular(cellSize * (0.16 + (ringProgress * 0.24))),
        ),
        ringPaint,
      );
    }

    final double sparkProgress = ((progress - 0.06) / 0.44)
        .clamp(0.0, 1.0)
        .toDouble();
    if (sparkProgress <= 0) {
      return;
    }

    final double travel = Curves.easeOutCubic.transform(sparkProgress);
    final double sparkFade = 1 - Curves.easeIn.transform(sparkProgress);
    final Paint sparkPaint = Paint()
      ..color = palette.player.withValues(alpha: 0.82 * sparkFade)
      ..strokeWidth = max(1.2, cellSize * 0.09)
      ..strokeCap = StrokeCap.round;
    final List<double> angles = <double>[-2.3, -1.6, -0.8, -0.1, 0.7, 1.5];
    for (final double angle in angles) {
      final Offset start = Offset(
        center.dx + (cos(angle) * cellSize * 0.28 * travel),
        center.dy + (sin(angle) * cellSize * 0.28 * travel),
      );
      final Offset end = Offset(
        center.dx + (cos(angle) * cellSize * (0.54 + (travel * 0.86))),
        center.dy + (sin(angle) * cellSize * (0.54 + (travel * 0.86))),
      );
      canvas.drawLine(start, end, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessBurstPainter oldDelegate) {
    return oldDelegate.goalPos != goalPos ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.progress != progress;
  }
}

Rect _scaledInsetRect(
  Rect cellRect,
  double insetFactor,
  double scale,
  double cellSize,
) {
  final Rect base = cellRect.deflate(cellSize * insetFactor);
  final Offset center = base.center;
  final double width = base.width * scale;
  final double height = base.height * scale;
  return Rect.fromCenter(center: center, width: width, height: height);
}
