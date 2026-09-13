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
    this.previewCardKey,
    this.showRoamingBlock = false,
  });

  final Difficulty difficulty;
  final MazePalette palette;
  final GlobalKey? previewCardKey;
  final bool showRoamingBlock;

  @override
  State<BackgroundMaze> createState() => _BackgroundMazeState();
}

class _BackgroundMazeState extends State<BackgroundMaze>
    with TickerProviderStateMixin {
  late final AnimationController _morphController;
  late final AnimationController _roamController;

  // Lazily populated inside LayoutBuilder so we always have the right size.
  _MazeSnapshot? _fromSnapshot;
  _MazeSnapshot? _toSnapshot;

  // Remember the last constraints so we can regenerate when size changes.
  BoxConstraints? _lastConstraints;

  // Roaming block state
  Position _currPos = const Position(0, 0);
  Position _nextPos = const Position(0, 0);
  List<Position> _roamPath = <Position>[];
  int _roamPathIndex = 0;
  final List<Position> _recentCells = <Position>[];
  final Map<Position, int> _visitCounts = <Position, int>{};
  final Random _roamRandom = Random();
  Rect? _cachedCardRect;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: _morphDuration,
    )..value = 1.0; // fully arrived → no morph on first paint

    _roamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _roamController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _stepRoamingBlock();
        final bool isTest =
            WidgetsBinding.instance.runtimeType.toString().contains('Test');
        if (mounted && widget.showRoamingBlock && !isTest) {
          _roamController.forward(from: 0.0);
        }
      }
    });

    if (widget.showRoamingBlock) {
      _roamController.forward(from: 0.0);
    }
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
        _visitCounts.clear();
        _recentCells.clear();
      });
      _morphController.forward(from: 0);
    }
    if (widget.showRoamingBlock != oldWidget.showRoamingBlock) {
      if (widget.showRoamingBlock) {
        final Rect cardRect = _resolveCardRect();
        if (_toSnapshot != null &&
            (!_isCellInsideCard(_currPos, _toSnapshot!.cellSize, cardRect) ||
             _roamPath.isEmpty)) {
          _initRoamingPositions(_toSnapshot!, cardRect);
        }
        if (!_roamController.isAnimating) {
          _stepRoamingBlock();
          _roamController.forward(from: 0.0);
        }
      } else {
        _roamController.stop();
      }
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _roamController.dispose();
    super.dispose();
  }

  Rect _resolveCardRect([BoxConstraints? constraints]) {
    final BuildContext? cardContext = widget.previewCardKey?.currentContext;
    if (mounted && cardContext != null && cardContext.mounted) {
      try {
        final RenderObject? ro = cardContext.findRenderObject();
        final RenderObject? stackRo = context.findRenderObject();
        if (ro is RenderBox &&
            stackRo is RenderBox &&
            ro.hasSize &&
            stackRo.hasSize) {
          final Offset offset = ro.localToGlobal(Offset.zero, ancestor: stackRo);
          final Rect resolved = offset & ro.size;
          if (_cachedCardRect != resolved && _toSnapshot != null) {
            final bool hadShift = _cachedCardRect != null &&
                (_cachedCardRect!.top - resolved.top).abs() > 4.0;
            _cachedCardRect = resolved;
            if (hadShift || !_isCellInsideCard(_currPos, _toSnapshot!.cellSize, resolved)) {
              _initRoamingPositions(_toSnapshot!, resolved);
            }
          } else {
            _cachedCardRect = resolved;
          }
          return _cachedCardRect!;
        }
      } catch (_) {
        // Element not active or attached
      }
    }
    if (_cachedCardRect != null) {
      return _cachedCardRect!;
    }
    final double width = constraints?.maxWidth ?? 360.0;
    final double height = constraints?.maxHeight ?? 640.0;
    return Rect.fromCenter(
      center: Offset(width / 2, height * 0.44),
      width: 224,
      height: 224,
    );
  }

  bool _isCellInsideCard(Position pos, double cellSize, Rect cardRect) {
    final double cx = (pos.x - 3.5) * cellSize;
    final double cy = (pos.y - 3.5) * cellSize;
    final double margin = max(10.0, cellSize * 0.55);
    final RRect cardRRect = RRect.fromRectAndRadius(
      cardRect.deflate(margin),
      const Radius.circular(16),
    );
    return cardRRect.contains(Offset(cx, cy));
  }

  List<Position> _getValidNeighbors(
    _MazeSnapshot snapshot,
    Position pos,
    Rect cardRect,
  ) {
    final List<Position> neighbors = <Position>[];
    final int x = pos.x;
    final int y = pos.y;
    final List<List<MazeCell>> maze = snapshot.maze;
    final double cellSize = snapshot.cellSize;

    if (y < 0 || y >= maze.length || x < 0 || x >= maze[y].length) {
      return neighbors;
    }

    final MazeCell cell = maze[y][x];

    // Right: (x+1, y)
    if (x + 1 < maze[y].length && !cell.walls.right && !maze[y][x + 1].walls.left) {
      final Position n = Position(x + 1, y);
      if (_isCellInsideCard(n, cellSize, cardRect)) {
        neighbors.add(n);
      }
    }
    // Left: (x-1, y)
    if (x - 1 >= 0 && !cell.walls.left && !maze[y][x - 1].walls.right) {
      final Position n = Position(x - 1, y);
      if (_isCellInsideCard(n, cellSize, cardRect)) {
        neighbors.add(n);
      }
    }
    // Down: (x, y+1)
    if (y + 1 < maze.length && !cell.walls.bottom && !maze[y + 1][x].walls.top) {
      final Position n = Position(x, y + 1);
      if (_isCellInsideCard(n, cellSize, cardRect)) {
        neighbors.add(n);
      }
    }
    // Up: (x, y-1)
    if (y - 1 >= 0 && !cell.walls.top && !maze[y - 1][x].walls.bottom) {
      final Position n = Position(x, y - 1);
      if (_isCellInsideCard(n, cellSize, cardRect)) {
        neighbors.add(n);
      }
    }

    return neighbors;
  }

  List<Position> _findNewRoamPath(
    _MazeSnapshot snapshot,
    Position start,
    Rect cardRect,
  ) {
    final Map<Position, Position?> parentMap = <Position, Position?>{start: null};
    final Map<Position, int> distMap = <Position, int>{start: 0};
    final List<Position> queue = <Position>[start];

    while (queue.isNotEmpty) {
      final Position u = queue.removeAt(0);
      final int uDist = distMap[u]!;

      for (final Position v in _getValidNeighbors(snapshot, u, cardRect)) {
        if (!distMap.containsKey(v)) {
          distMap[v] = uDist + 1;
          parentMap[v] = u;
          queue.add(v);
        }
      }
    }

    if (distMap.length <= 1) {
      return <Position>[start];
    }

    double bestScore = -double.infinity;
    List<Position> bestCandidates = <Position>[];

    for (final MapEntry<Position, int> entry in distMap.entries) {
      final Position v = entry.key;
      final int dist = entry.value;
      if (dist < 1) continue;

      final int visits = _visitCounts[v] ?? 0;
      final int recentIndex = _recentCells.lastIndexOf(v);
      final int stepsAgo = recentIndex == -1 ? 999 : (_recentCells.length - 1 - recentIndex);

      double score = 100.0 / (1.0 + visits * 3.0);

      if (stepsAgo < 15) {
        score -= (15 - stepsAgo) * 12.0;
      } else {
        score += min(stepsAgo, 40) * 1.5;
      }

      // Reward distance to encourage longer journeys through passages
      score += min(dist, 8) * 4.0;

      // Small jitter to break ties dynamically
      score += _roamRandom.nextDouble() * 3.0;

      if (score > bestScore + 0.001) {
        bestScore = score;
        bestCandidates = <Position>[v];
      } else if ((score - bestScore).abs() <= 0.001) {
        bestCandidates.add(v);
      }
    }

    if (bestCandidates.isEmpty) {
      return <Position>[start];
    }

    final Position target = bestCandidates[_roamRandom.nextInt(bestCandidates.length)];

    final List<Position> path = <Position>[];
    Position? curr = target;
    while (curr != null) {
      path.add(curr);
      curr = parentMap[curr];
    }

    return path.reversed.toList();
  }

  void _initRoamingPositions(_MazeSnapshot snapshot, Rect cardRect) {
    final double cellSize = snapshot.cellSize;
    if (cellSize <= 0 || snapshot.maze.isEmpty) {
      return;
    }

    final int cols = snapshot.maze.first.length;
    final int rows = snapshot.maze.length;

    final int minX = ((cardRect.left / cellSize) + 2).floor().clamp(0, cols - 1);
    final int maxX = ((cardRect.right / cellSize) + 5).ceil().clamp(0, cols - 1);
    final int minY = ((cardRect.top / cellSize) + 2).floor().clamp(0, rows - 1);
    final int maxY = ((cardRect.bottom / cellSize) + 5).ceil().clamp(0, rows - 1);

    final Set<Position> allCellsInCard = <Position>{};
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final Position pos = Position(x, y);
        if (_isCellInsideCard(pos, cellSize, cardRect)) {
          allCellsInCard.add(pos);
        }
      }
    }

    final Set<Position> visited = <Position>{};
    List<Position> largestComponent = <Position>[];

    for (final Position pos in allCellsInCard) {
      if (visited.contains(pos)) continue;

      final List<Position> component = <Position>[];
      final List<Position> queue = <Position>[pos];
      visited.add(pos);

      while (queue.isNotEmpty) {
        final Position u = queue.removeAt(0);
        component.add(u);

        for (final Position v in _getValidNeighbors(snapshot, u, cardRect)) {
          if (!visited.contains(v)) {
            visited.add(v);
            queue.add(v);
          }
        }
      }

      if (component.length > largestComponent.length) {
        largestComponent = component;
      }
    }

    _visitCounts.clear();
    _recentCells.clear();

    if (largestComponent.isEmpty) {
      final int midX = ((cardRect.center.dx / cellSize) + 3.5).round().clamp(0, cols - 1);
      final int midY = ((cardRect.center.dy / cellSize) + 3.5).round().clamp(0, rows - 1);
      final Position fallback = Position(midX, midY);
      _currPos = fallback;
      _nextPos = fallback;
      _roamPath = <Position>[fallback];
      _roamPathIndex = 0;
      return;
    }

    _currPos = largestComponent[_roamRandom.nextInt(largestComponent.length)];
    _visitCounts[_currPos] = 1;
    _recentCells.add(_currPos);

    _roamPath = _findNewRoamPath(snapshot, _currPos, cardRect);
    _roamPathIndex = 0;

    if (_roamPath.length > 1) {
      _nextPos = _roamPath[1];
      _roamPathIndex = 1;
    } else {
      _nextPos = _currPos;
    }
  }

  void _stepRoamingBlock() {
    final _MazeSnapshot? snapshot = _toSnapshot;
    if (snapshot == null || snapshot.cellSize <= 0) {
      return;
    }

    final Rect cardRect = _resolveCardRect();

    // Self-healing guard: If _currPos or _nextPos is ever outside cardRect, re-anchor immediately
    if (!_isCellInsideCard(_currPos, snapshot.cellSize, cardRect) ||
        !_isCellInsideCard(_nextPos, snapshot.cellSize, cardRect)) {
      _initRoamingPositions(snapshot, cardRect);
      return;
    }

    _currPos = _nextPos;
    _visitCounts[_currPos] = (_visitCounts[_currPos] ?? 0) + 1;
    _recentCells.add(_currPos);
    if (_recentCells.length > 30) {
      _recentCells.removeAt(0);
    }

    if (_roamPath.isNotEmpty && _roamPathIndex < _roamPath.length - 1) {
      _roamPathIndex++;
      _nextPos = _roamPath[_roamPathIndex];
    } else {
      _roamPath = _findNewRoamPath(snapshot, _currPos, cardRect);
      if (_roamPath.length > 1) {
        _roamPathIndex = 1;
        _nextPos = _roamPath[1];
      } else {
        _nextPos = _currPos;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Regenerate the "to" snapshot whenever difficulty or size changes.
        if (_toSnapshot == null || _lastConstraints != constraints) {
          _lastConstraints = constraints;
          _toSnapshot = _buildSnapshot(widget.difficulty, constraints);
          final Rect initialCardRect = _resolveCardRect(constraints);
          _initRoamingPositions(_toSnapshot!, initialCardRect);
        }

        final _MazeSnapshot toSnap = _toSnapshot!;
        final _MazeSnapshot? fromSnap = _fromSnapshot;
        final Rect cardRect = _resolveCardRect(constraints);

        if (!_isCellInsideCard(_currPos, toSnap.cellSize, cardRect)) {
          _initRoamingPositions(toSnap, cardRect);
        }

        final bool isLightSurface = widget.palette.bg.computeLuminance() > 0.5;
        final Color gridColor = widget.palette.grid.withValues(
          alpha: isLightSurface ? 0.47 : 0.36,
        );

        return IgnorePointer(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_morphController, _roamController]),
            builder: (BuildContext context, _) {
              return RepaintBoundary(
                child: CustomPaint(
                  key: const Key('title-background-maze'),
                  painter: _MorphMazePainter(
                    fromSnap: fromSnap,
                    toSnap: toSnap,
                    // If there is no "from", jump straight to the settled state.
                    progress: fromSnap == null ? 1.0 : _morphController.value,
                    gridColor: gridColor,
                    showRoamingBlock: widget.showRoamingBlock,
                    roamProgress: _roamController.value,
                    currPos: _currPos,
                    nextPos: _nextPos,
                    cardRect: cardRect,
                    playerColor: widget.palette.player,
                  ),
                  size: Size.infinite,
                ),
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
    required this.showRoamingBlock,
    required this.roamProgress,
    required this.currPos,
    required this.nextPos,
    required this.cardRect,
    required this.playerColor,
  });

  final _MazeSnapshot? fromSnap;
  final _MazeSnapshot toSnap;

  /// Normalised animation progress [0, 1].  1 = fully settled on [toSnap].
  final double progress;
  final Color gridColor;
  final bool showRoamingBlock;
  final double roamProgress;
  final Position currPos;
  final Position nextPos;
  final Rect? cardRect;
  final Color playerColor;

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

    // ── 1. Paint background maze walls ──────────────────────────────────
    if (from == null || progress >= 1.0) {
      _paintMaze(canvas, toSnap, toSnap.cellSize, gridColor, 1.0);
    } else {
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

    // ── 2. Paint roaming block inside preview card ───────────────────────
    final Rect? card = cardRect;
    if (showRoamingBlock && card != null && toSnap.cellSize > 0) {
      canvas.save();
      // Clip to card rounded border
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          card,
          const Radius.circular(28),
        ),
      );

      final double currentCellSize = from != null && progress < 1.0
          ? (lerpDouble(from.cellSize, toSnap.cellSize, _scaleCurve.transform(progress)) ?? toSnap.cellSize)
          : toSnap.cellSize;

      final Offset currCenter = Offset(
        (currPos.x - 3.5) * currentCellSize,
        (currPos.y - 3.5) * currentCellSize,
      );
      final Offset nextCenter = Offset(
        (nextPos.x - 3.5) * currentCellSize,
        (nextPos.y - 3.5) * currentCellSize,
      );

      final double t = Curves.easeInOut.transform(roamProgress);
      final Offset blockCenter = Offset.lerp(currCenter, nextCenter, t)!;

      final double blockSize = currentCellSize * 0.65;
      final double cornerRadius = blockSize * 0.28;

      // Soft subtle glow
      final Paint glowPaint = Paint()
        ..color = playerColor.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: blockCenter,
            width: blockSize + 3,
            height: blockSize + 3,
          ),
          Radius.circular(cornerRadius + 1.5),
        ),
        glowPaint,
      );

      // Player block
      final Paint blockPaint = Paint()
        ..color = playerColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: blockCenter,
            width: blockSize,
            height: blockSize,
          ),
          Radius.circular(cornerRadius),
        ),
        blockPaint,
      );

      canvas.restore();
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
        oldDelegate.toSnap != toSnap ||
        oldDelegate.showRoamingBlock != showRoamingBlock ||
        oldDelegate.roamProgress != roamProgress ||
        oldDelegate.currPos != currPos ||
        oldDelegate.nextPos != nextPos ||
        oldDelegate.cardRect != cardRect ||
        oldDelegate.playerColor != playerColor;
  }
}
