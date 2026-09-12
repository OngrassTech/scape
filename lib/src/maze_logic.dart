import 'dart:math';

import 'models.dart';

class MazeGenerator {
  const MazeGenerator();

  List<List<MazeCell>> generate(
    int width,
    int height, {
    Random? random,
  }) {
    final Random rng = random ?? Random();
    final List<List<MazeCell>> grid = List<List<MazeCell>>.generate(
      height,
      (int y) => List<MazeCell>.generate(
        width,
        (int x) => MazeCell(
          x: x,
          y: y,
          walls: WallSet(top: true, right: true, bottom: true, left: true),
        ),
      ),
    );

    final List<MazeCell> active = <MazeCell>[];
    final MazeCell start = grid[0][0];
    start.visited = true;
    active.add(start);

    while (active.isNotEmpty) {
      final bool useNewest = rng.nextDouble() < 0.7;
      final int index = useNewest ? active.length - 1 : rng.nextInt(active.length);
      final MazeCell current = active[index];
      final List<MazeCell> neighbors =
          _getUnvisitedNeighbors(current, grid, width, height);

      if (neighbors.isEmpty) {
        active.removeAt(index);
        continue;
      }

      final MazeCell next = neighbors[rng.nextInt(neighbors.length)];
      _removeWalls(current, next);
      next.visited = true;
      active.add(next);
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final MazeCell cell = grid[y][x];
        int wallCount = 0;
        if (cell.walls.top) wallCount++;
        if (cell.walls.right) wallCount++;
        if (cell.walls.bottom) wallCount++;
        if (cell.walls.left) wallCount++;

        if (wallCount == 3 && rng.nextDouble() < 0.15) {
          if ((x == 0 && y == 0) || (x == width - 1 && y == height - 1)) {
            continue;
          }

          final List<String> removable = <String>[];
          if (cell.walls.top && y > 0) removable.add('top');
          if (cell.walls.right && x < width - 1) removable.add('right');
          if (cell.walls.bottom && y < height - 1) removable.add('bottom');
          if (cell.walls.left && x > 0) removable.add('left');

          if (removable.isEmpty) {
            continue;
          }

          final String toRemove = removable[rng.nextInt(removable.length)];
          switch (toRemove) {
            case 'top':
              cell.walls.top = false;
              grid[y - 1][x].walls.bottom = false;
              break;
            case 'right':
              cell.walls.right = false;
              grid[y][x + 1].walls.left = false;
              break;
            case 'bottom':
              cell.walls.bottom = false;
              grid[y + 1][x].walls.top = false;
              break;
            case 'left':
              cell.walls.left = false;
              grid[y][x - 1].walls.right = false;
              break;
          }
        }
      }
    }

    return grid;
  }

  List<MazeCell> _getUnvisitedNeighbors(
    MazeCell cell,
    List<List<MazeCell>> grid,
    int width,
    int height,
  ) {
    final List<MazeCell> neighbors = <MazeCell>[];
    final int x = cell.x;
    final int y = cell.y;

    if (y > 0 && !grid[y - 1][x].visited) neighbors.add(grid[y - 1][x]);
    if (x < width - 1 && !grid[y][x + 1].visited) neighbors.add(grid[y][x + 1]);
    if (y < height - 1 && !grid[y + 1][x].visited) neighbors.add(grid[y + 1][x]);
    if (x > 0 && !grid[y][x - 1].visited) neighbors.add(grid[y][x - 1]);

    return neighbors;
  }

  void _removeWalls(MazeCell a, MazeCell b) {
    final int dx = a.x - b.x;
    if (dx == 1) {
      a.walls.left = false;
      b.walls.right = false;
    } else if (dx == -1) {
      a.walls.right = false;
      b.walls.left = false;
    }

    final int dy = a.y - b.y;
    if (dy == 1) {
      a.walls.top = false;
      b.walls.bottom = false;
    } else if (dy == -1) {
      a.walls.bottom = false;
      b.walls.top = false;
    }
  }
}

class MazeSolver {
  const MazeSolver();

  List<Position> solve(
    List<List<MazeCell>> maze,
    Position start,
    Position goal,
  ) {
    if (maze.isEmpty) {
      return const <Position>[];
    }

    final List<_QueueEntry> queue = <_QueueEntry>[
      _QueueEntry(x: start.x, y: start.y, path: const <Position>[]),
    ];
    final Set<String> visited = <String>{'${start.x},${start.y}'};

    while (queue.isNotEmpty) {
      final _QueueEntry current = queue.removeAt(0);
      if (current.x == goal.x && current.y == goal.y) {
        return current.path;
      }

      final MazeCell cell = maze[current.y][current.x];
      final List<({int x, int y, bool blocked})> neighbors =
          <({int x, int y, bool blocked})>[
        (x: current.x, y: current.y - 1, blocked: cell.walls.top),
        (x: current.x + 1, y: current.y, blocked: cell.walls.right),
        (x: current.x, y: current.y + 1, blocked: cell.walls.bottom),
        (x: current.x - 1, y: current.y, blocked: cell.walls.left),
      ];

      for (final ({int x, int y, bool blocked}) neighbor in neighbors) {
        if (neighbor.blocked) {
          continue;
        }
        if (neighbor.x < 0 ||
            neighbor.y < 0 ||
            neighbor.y >= maze.length ||
            neighbor.x >= maze[0].length) {
          continue;
        }

        final String key = '${neighbor.x},${neighbor.y}';
        if (!visited.add(key)) {
          continue;
        }

        queue.add(
          _QueueEntry(
            x: neighbor.x,
            y: neighbor.y,
            path: <Position>[
              ...current.path,
              Position(neighbor.x, neighbor.y),
            ],
          ),
        );
      }
    }

    return const <Position>[];
  }
}

class SlideEngine {
  const SlideEngine();

  SlideResult slide(
    List<List<MazeCell>> maze,
    Position playerPos,
    int dx,
    int dy,
    Position goalPos,
  ) {
    if (maze.isEmpty || (dx == 0 && dy == 0)) {
      return SlideResult(position: playerPos, path: const <Position>[]);
    }

    int currentX = playerPos.x;
    int currentY = playerPos.y;
    final List<Position> path = <Position>[];

    while (true) {
      final MazeCell currentCell = maze[currentY][currentX];
      if (dx == 1 && currentCell.walls.right) break;
      if (dx == -1 && currentCell.walls.left) break;
      if (dy == 1 && currentCell.walls.bottom) break;
      if (dy == -1 && currentCell.walls.top) break;

      currentX += dx;
      currentY += dy;
      path.add(Position(currentX, currentY));

      if (currentX == goalPos.x && currentY == goalPos.y) {
        break;
      }

      final MazeCell nextCell = maze[currentY][currentX];
      if (dx != 0) {
        if (!nextCell.walls.top || !nextCell.walls.bottom) {
          break;
        }
      } else {
        if (!nextCell.walls.left || !nextCell.walls.right) {
          break;
        }
      }
    }

    if (path.isEmpty) {
      return SlideResult(position: playerPos, path: const <Position>[]);
    }

    return SlideResult(position: path.last, path: path);
  }
}

class _QueueEntry {
  const _QueueEntry({
    required this.x,
    required this.y,
    required this.path,
  });

  final int x;
  final int y;
  final List<Position> path;
}
