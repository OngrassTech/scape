import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../maze_logic.dart';
import '../maze_theme.dart';
import '../models.dart';

class MiniMazePreviewData {
  const MiniMazePreviewData({
    required this.maze,
    required this.start,
    required this.goal,
    required this.route,
  });

  final List<List<MazeCell>> maze;
  final Position start;
  final Position goal;
  final List<Position> route;
}

enum MiniMazeSceneFit { contain, cover }

MiniMazePreviewData buildGeneratedMiniMazeData({
  required int seed,
  int width = 5,
  int height = 5,
  int minRouteLength = 8,
}) {
  final MazeGenerator generator = const MazeGenerator();
  final MazeSolver solver = const MazeSolver();
  MiniMazePreviewData? fallback;

  for (int attempt = 0; attempt < 6; attempt++) {
    final List<List<MazeCell>> maze = _cloneMiniMaze(
      generator.generate(width, height, random: Random(seed + (attempt * 19))),
    );
    const Position start = Position(0, 0);
    final Position goal = Position(width - 1, height - 1);
    final List<Position> route = <Position>[
      start,
      ...solver.solve(maze, start, goal),
    ];
    final MiniMazePreviewData preview = MiniMazePreviewData(
      maze: maze,
      start: start,
      goal: goal,
      route: List<Position>.unmodifiable(route),
    );
    fallback ??= preview;
    if (route.length >= minRouteLength) {
      return preview;
    }
  }

  return fallback!;
}

class MiniMazeScene extends StatelessWidget {
  const MiniMazeScene({
    super.key,
    required this.maze,
    required this.goalPos,
    required this.playerOffset,
    required this.palette,
    this.trail = const <Position>[],
    this.goalPulse = 0,
    this.fit = MiniMazeSceneFit.contain,
    this.alignment = Alignment.center,
    this.showPerimeterWalls = true,
    this.paintBackground = true,
  });

  final List<List<MazeCell>> maze;
  final Position goalPos;
  final Offset playerOffset;
  final MazePalette palette;
  final List<Position> trail;
  final double goalPulse;
  final MiniMazeSceneFit fit;
  final Alignment alignment;
  final bool showPerimeterWalls;
  final bool paintBackground;

  @override
  Widget build(BuildContext context) {
    if (maze.isEmpty || maze.first.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = maze.first.length;
        final int rows = maze.length;
        final double cellSize = switch (fit) {
          MiniMazeSceneFit.contain => min(
            constraints.maxWidth / columns,
            constraints.maxHeight / rows,
          ),
          MiniMazeSceneFit.cover => max(
            constraints.maxWidth / columns,
            constraints.maxHeight / rows,
          ),
        };
        final double boardWidth = columns * cellSize;
        final double boardHeight = rows * cellSize;

        return SizedBox.expand(
          child: ClipRect(
            child: OverflowBox(
              alignment: alignment,
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: SizedBox(
                width: boardWidth,
                height: boardHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      painter: _MiniMazeBasePainter(
                        maze: maze,
                        palette: palette,
                        cellSize: cellSize,
                        showPerimeterWalls: showPerimeterWalls,
                        paintBackground: paintBackground,
                      ),
                    ),
                    if (trail.isNotEmpty)
                      CustomPaint(
                        painter: _MiniTrailPainter(
                          trail: trail.toSet(),
                          palette: palette,
                          cellSize: cellSize,
                        ),
                      ),
                    CustomPaint(
                      painter: _MiniGoalPainter(
                        goalPos: goalPos,
                        palette: palette,
                        cellSize: cellSize,
                        pulse: goalPulse,
                      ),
                    ),
                    CustomPaint(
                      painter: _MiniPlayerPainter(
                        playerOffset: playerOffset,
                        palette: palette,
                        cellSize: cellSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniMazeBasePainter extends CustomPainter {
  const _MiniMazeBasePainter({
    required this.maze,
    required this.palette,
    required this.cellSize,
    required this.showPerimeterWalls,
    required this.paintBackground,
  });

  final List<List<MazeCell>> maze;
  final MazePalette palette;
  final double cellSize;
  final bool showPerimeterWalls;
  final bool paintBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint wallPaint = Paint()
      ..color = palette.grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.6, cellSize * 0.08);

    if (paintBackground) {
      final Paint backgroundPaint = Paint()..color = palette.mazeBg;
      canvas.drawRect(Offset.zero & size, backgroundPaint);
    }

    for (int y = 0; y < maze.length; y++) {
      for (int x = 0; x < maze[y].length; x++) {
        final MazeCell cell = maze[y][x];
        final Rect cellRect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );

        if (cell.walls.right &&
            (showPerimeterWalls || x < maze[y].length - 1)) {
          canvas.drawLine(cellRect.topRight, cellRect.bottomRight, wallPaint);
        }
        if (cell.walls.bottom && (showPerimeterWalls || y < maze.length - 1)) {
          canvas.drawLine(cellRect.bottomLeft, cellRect.bottomRight, wallPaint);
        }
      }
    }

    if (showPerimeterWalls) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), wallPaint);
      canvas.drawLine(Offset.zero, Offset(0, size.height), wallPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMazeBasePainter oldDelegate) {
    return oldDelegate.maze != maze ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.showPerimeterWalls != showPerimeterWalls ||
        oldDelegate.paintBackground != paintBackground;
  }
}

class _MiniTrailPainter extends CustomPainter {
  const _MiniTrailPainter({
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
      final double inset = max(1.5, cellSize * 0.16);
      final Rect trailRect = cellRect.deflate(inset);
      canvas.drawRRect(
        RRect.fromRectAndRadius(trailRect, Radius.circular(cellSize * 0.14)),
        trailPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniTrailPainter oldDelegate) {
    return oldDelegate.trail != trail ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize;
  }
}

class _MiniGoalPainter extends CustomPainter {
  const _MiniGoalPainter({
    required this.goalPos,
    required this.palette,
    required this.cellSize,
    required this.pulse,
  });

  final Position goalPos;
  final MazePalette palette;
  final double cellSize;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect cellRect = Rect.fromLTWH(
      goalPos.x * cellSize,
      goalPos.y * cellSize,
      cellSize,
      cellSize,
    );
    final double scale = 1 + (0.16 * pulse);
    final Rect glowRect = _scaledInsetRect(cellRect, 0.08, scale, cellSize);
    final Rect goalRect = _scaledInsetRect(cellRect, 0.16, scale, cellSize);
    final Paint glowPaint = Paint()
      ..color = palette.goalShadow.withValues(alpha: 0.64 + (0.18 * pulse));
    final Paint goalPaint = Paint()..color = palette.goal;

    canvas.drawRRect(
      RRect.fromRectAndRadius(glowRect, Radius.circular(cellSize * 0.18)),
      glowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(goalRect, Radius.circular(cellSize * 0.14)),
      goalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniGoalPainter oldDelegate) {
    return oldDelegate.goalPos != goalPos ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.pulse != pulse;
  }
}

class _MiniPlayerPainter extends CustomPainter {
  const _MiniPlayerPainter({
    required this.playerOffset,
    required this.palette,
    required this.cellSize,
  });

  final Offset playerOffset;
  final MazePalette palette;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect cellRect = Rect.fromLTWH(
      playerOffset.dx * cellSize,
      playerOffset.dy * cellSize,
      cellSize,
      cellSize,
    );
    final Paint playerShadowPaint = Paint()..color = palette.playerShadow;
    final Paint playerPaint = Paint()..color = palette.player;
    final Rect shadowRect = cellRect.deflate(cellSize * 0.12);
    final Rect playerRect = cellRect.deflate(cellSize * 0.16);

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
  bool shouldRepaint(covariant _MiniPlayerPainter oldDelegate) {
    return oldDelegate.playerOffset != playerOffset ||
        oldDelegate.palette != palette ||
        oldDelegate.cellSize != cellSize;
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
  final double width =
      (lerpDouble(base.width, base.width * scale, 1) ?? base.width).clamp(
        0,
        double.infinity,
      );
  final double height =
      (lerpDouble(base.height, base.height * scale, 1) ?? base.height).clamp(
        0,
        double.infinity,
      );
  return Rect.fromCenter(center: center, width: width, height: height);
}

List<List<MazeCell>> _cloneMiniMaze(List<List<MazeCell>> maze) {
  return maze
      .map(
        (List<MazeCell> row) =>
            row.map((MazeCell cell) => cell.copy()).toList(growable: false),
      )
      .toList(growable: false);
}
