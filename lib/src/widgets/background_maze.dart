import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../maze_logic.dart';
import '../maze_theme.dart';
import '../models.dart';
import 'maze_board.dart'; // for calculateBoardLayout

// Duration of the wall-morph animation when difficulty changes.
const Duration _morphDuration = Duration(milliseconds: 540);

/// Decorative background maze that morphs its walls when the difficulty changes.
///
/// Instead of a cross-fade, every wall segment animates individually:
/// departing walls shrink toward their midpoints while arriving walls grow
/// outward from their midpoints.  The grid cell size is also lerped so the
/// overall scale transition feels seamless.
class BackgroundMaze extends StatefulWidget {
  const BackgroundMaze({
    super.key,
    required this.difficulty,
    required this.palette,
  });

  final Difficulty difficulty;
  final MazePalette palette;

  @override
  State<BackgroundMaze> createState() => _BackgroundMazeState();
}

class _BackgroundMazeState extends State<BackgroundMaze>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Lazily populated inside LayoutBuilder so we always have the right size.
  _MazeSnapshot? _fromSnapshot;
  _MazeSnapshot? _toSnapshot;

  // Remember the last constraints so we can regenerate when size changes.
  BoxConstraints? _lastConstraints;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _morphDuration)
      ..value = 1.0; // fully arrived → no morph on first paint
  }

  @override
  void didUpdateWidget(covariant BackgroundMaze oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.difficulty != widget.difficulty) {
      setState(() {
        // The current "to" snapshot becomes the new "from" snapshot.
        _fromSnapshot = _toSnapshot;
        // Force regeneration of the "to" snapshot on the next LayoutBuilder pass.
        _toSnapshot = null;
      });
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Regenerate the "to" snapshot whenever difficulty or size changes.
        if (_toSnapshot == null || _lastConstraints != constraints) {
          _lastConstraints = constraints;
          _toSnapshot = _buildSnapshot(widget.difficulty, constraints);
        }

        final _MazeSnapshot toSnap = _toSnapshot!;
        final _MazeSnapshot? fromSnap = _fromSnapshot;

        final bool isLightSurface = widget.palette.bg.computeLuminance() > 0.5;
        final Color gridColor = widget.palette.grid.withValues(
          alpha: isLightSurface ? 0.47 : 0.36,
        );

        return IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, _) {
              return CustomPaint(
                key: const Key('title-background-maze'),
                painter: _MorphMazePainter(
                  fromSnap: fromSnap,
                  toSnap: toSnap,
                  // If there is no "from", jump straight to the settled state.
                  progress: fromSnap == null ? 1.0 : _controller.value,
                  gridColor: gridColor,
                ),
                size: Size.infinite,
              );
            },
          ),
        );
      },
    );
  }

  static _MazeSnapshot _buildSnapshot(
    Difficulty d,
    BoxConstraints constraints,
  ) {
    final BoardLayout layout = calculateBoardLayout(
      Size(constraints.maxWidth, constraints.maxHeight),
      d.config,
    );
    final double cellSize = layout.cellSize.clamp(10.0, 24.0).toDouble();
    final int columns = max(5, (constraints.maxWidth / cellSize).ceil() + 4);
    final int rows = max(5, (constraints.maxHeight / cellSize).ceil() + 4);
    final int seed = Object.hash(d.index, columns, rows, 17);
    final List<List<MazeCell>> maze = const MazeGenerator().generate(
      columns,
      rows,
      random: Random(seed),
    );
    return _MazeSnapshot(maze: maze, cellSize: cellSize);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data container
// ─────────────────────────────────────────────────────────────────────────────

class _MazeSnapshot {
  _MazeSnapshot({required this.maze, required this.cellSize})
    : unitPath = _buildUnitPath(maze),
      segments = _buildSegments(maze);

  final List<List<MazeCell>> maze;
  final double cellSize;
  final Path unitPath;
  final List<_WallSegment> segments;

  static Path _buildUnitPath(List<List<MazeCell>> maze) {
    final Path path = Path();

    for (int y = 0; y < maze.length; y++) {
      for (int x = 0; x < maze[y].length; x++) {
        final MazeCell cell = maze[y][x];
        final double left = x - 2;
        final double top = y - 2;

        if (cell.walls.right) {
          path.moveTo(left + 1, top);
          path.lineTo(left + 1, top + 1);
        }
        if (cell.walls.bottom) {
          path.moveTo(left, top + 1);
          path.lineTo(left + 1, top + 1);
        }
      }
    }

    return path;
  }

  static List<_WallSegment> _buildSegments(List<List<MazeCell>> maze) {
    final List<_WallSegment> segments = <_WallSegment>[];

    for (int y = 0; y < maze.length; y++) {
      for (int x = 0; x < maze[y].length; x++) {
        final MazeCell cell = maze[y][x];
        final double left = x - 2;
        final double top = y - 2;

        if (cell.walls.right) {
          segments.add(
            _WallSegment(center: Offset(left + 1, top + 0.5), isVertical: true),
          );
        }
        if (cell.walls.bottom) {
          segments.add(
            _WallSegment(
              center: Offset(left + 0.5, top + 1),
              isVertical: false,
            ),
          );
        }
      }
    }

    return segments;
  }
}

class _WallSegment {
  const _WallSegment({required this.center, required this.isVertical});

  final Offset center;
  final bool isVertical;
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _MorphMazePainter extends CustomPainter {
  const _MorphMazePainter({
    required this.fromSnap,
    required this.toSnap,
    required this.progress,
    required this.gridColor,
  });

  final _MazeSnapshot? fromSnap;
  final _MazeSnapshot toSnap;

  /// Normalised animation progress [0, 1].  1 = fully settled on [toSnap].
  final double progress;
  final Color gridColor;

  // Keep the morph readable, but ease it a little more gently so it settles
  // without feeling sticky on either end.
  static const Curve _growCurve = Curves.easeOutCubic;
  static const Curve _shrinkCurve = Curves.easeInCubic;
  static const Curve _scaleCurve = Interval(
    0,
    0.86,
    curve: Curves.easeInOutCubic,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final _MazeSnapshot? from = fromSnap;

    // ── Fast path: already settled or no prior maze ──────────────────────
    if (from == null || progress >= 1.0) {
      _paintMaze(canvas, toSnap, toSnap.cellSize, gridColor, 1.0);
      return;
    }

    // ── Lerp the cell size on its own curve ───────────────────────────────
    final double scaleT = _scaleCurve.transform(progress);
    final double cellSize = lerpDouble(from.cellSize, toSnap.cellSize, scaleT)!;

    final double growT = _growCurve.transform(progress);
    final double shrinkT = _shrinkCurve.transform(progress);

    // Outgoing walls: full opacity → transparent, full length → 0.
    final double fromAlpha = gridColor.a * (1.0 - shrinkT);
    if (fromAlpha > 0.004) {
      _paintMaze(
        canvas,
        from,
        cellSize,
        gridColor.withValues(alpha: fromAlpha),
        1.0 - shrinkT, // wallFraction: 1 → 0
      );
    }

    // Incoming walls: transparent → full opacity, 0 → full length.
    final double toAlpha = gridColor.a * growT;
    if (toAlpha > 0.004) {
      _paintMaze(
        canvas,
        toSnap,
        cellSize,
        gridColor.withValues(alpha: toAlpha),
        growT, // wallFraction: 0 → 1
      );
    }
  }

  /// Draws [maze] at [cellSize] with each wall segment drawn at [wallFraction]
  /// of its full length (growing/shrinking from its midpoint outward).
  void _paintMaze(
    Canvas canvas,
    _MazeSnapshot snapshot,
    double cellSize,
    Color color,
    double wallFraction,
  ) {
    if (wallFraction <= 0 || cellSize <= 0) {
      return;
    }

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 / cellSize
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(-cellSize * 2, -cellSize * 2);
    canvas.scale(cellSize);

    // ── Full-length fast path ────────────────────────────────────────────
    if (wallFraction >= 1.0) {
      canvas.drawPath(snapshot.unitPath, paint);
      canvas.restore();
      return;
    }

    // ── Partial-length path: each wall shrinks toward / grows from midpoint ─
    // Batch all segments into one Path to avoid per-segment draw-call overhead.
    final double halfLen = wallFraction / 2.0;
    final Path path = Path();

    for (final _WallSegment segment in snapshot.segments) {
      if (segment.isVertical) {
        path.moveTo(segment.center.dx, segment.center.dy - halfLen);
        path.lineTo(segment.center.dx, segment.center.dy + halfLen);
      } else {
        path.moveTo(segment.center.dx - halfLen, segment.center.dy);
        path.lineTo(segment.center.dx + halfLen, segment.center.dy);
      }
    }

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MorphMazePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.fromSnap != fromSnap ||
        oldDelegate.toSnap != toSnap;
  }
}
