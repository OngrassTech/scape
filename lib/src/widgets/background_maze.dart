import 'dart:math';

import 'package:flutter/material.dart';

import '../maze_logic.dart';
import '../maze_theme.dart';
import '../models.dart';
import 'maze_board.dart';

class BackgroundMaze extends StatelessWidget {
  const BackgroundMaze({
    super.key,
    required this.difficulty,
    required this.palette,
  });

  final Difficulty difficulty;
  final MazePalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isLightSurface = palette.bg.computeLuminance() > 0.5;
        final BoardLayout layout = calculateBoardLayout(
          Size(constraints.maxWidth, constraints.maxHeight),
          difficulty.config,
        );

        final double cellSize =
            layout.cellSize.clamp(10.0, 24.0).toDouble();
        final int columns = max(5, (constraints.maxWidth / cellSize).ceil() + 4);
        final int rows = max(5, (constraints.maxHeight / cellSize).ceil() + 4);
        final int seed = Object.hash(difficulty.index, columns, rows, 17);
        final List<List<MazeCell>> maze = const MazeGenerator().generate(
          columns,
          rows,
          random: Random(seed),
        );

        return IgnorePointer(
          child: CustomPaint(
            key: const Key('title-background-maze'),
            painter: _BackgroundMazePainter(
              maze: maze,
              cellSize: cellSize,
              gridColor: palette.grid.withValues(
                alpha: isLightSurface ? 0.47 : 0.36,
              ),
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _BackgroundMazePainter extends CustomPainter {
  const _BackgroundMazePainter({
    required this.maze,
    required this.cellSize,
    required this.gridColor,
  });

  final List<List<MazeCell>> maze;
  final double cellSize;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint wallPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final double startX = -cellSize * 2;
    final double startY = -cellSize * 2;
    final Path path = Path();

    for (int y = 0; y < maze.length; y++) {
      for (int x = 0; x < maze[y].length; x++) {
        final MazeCell cell = maze[y][x];
        final double left = startX + x * cellSize;
        final double top = startY + y * cellSize;

        if (cell.walls.right) {
          path.moveTo(left + cellSize, top);
          path.lineTo(left + cellSize, top + cellSize);
        }
        if (cell.walls.bottom) {
          path.moveTo(left, top + cellSize);
          path.lineTo(left + cellSize, top + cellSize);
        }
      }
    }

    canvas.drawPath(path, wallPaint);
  }

  @override
  bool shouldRepaint(covariant _BackgroundMazePainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.maze != maze;
  }
}
