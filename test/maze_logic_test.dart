import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mazegame/src/maze_logic.dart';
import 'package:mazegame/src/models.dart';

import 'test_helpers.dart';

void main() {
  group('MazeGenerator', () {
    test('creates the requested dimensions', () {
      final List<List<MazeCell>> maze = const MazeGenerator().generate(
        10,
        15,
        random: Random(1),
      );

      expect(maze, hasLength(15));
      expect(maze.first, hasLength(10));
    });

    test('always creates a solvable maze', () {
      final List<List<MazeCell>> maze = const MazeGenerator().generate(
        10,
        15,
        random: Random(2),
      );

      final List<Position> path = const MazeSolver().solve(
        maze,
        const Position(0, 0),
        const Position(9, 14),
      );

      expect(path, isNotEmpty);
      expect(path.last, const Position(9, 14));
    });

    test('never opens walls outside the maze bounds', () {
      final List<List<MazeCell>> maze = const MazeGenerator().generate(
        12,
        8,
        random: Random(3),
      );

      for (int y = 0; y < maze.length; y++) {
        for (int x = 0; x < maze[y].length; x++) {
          final MazeCell cell = maze[y][x];
          if (y == 0) expect(cell.walls.top, isTrue);
          if (x == 0) expect(cell.walls.left, isTrue);
          if (y == maze.length - 1) expect(cell.walls.bottom, isTrue);
          if (x == maze[y].length - 1) expect(cell.walls.right, isTrue);
        }
      }
    });
  });

  group('SlideEngine', () {
    test('stops at the next wall when no turn is available', () {
      final SlideResult result = const SlideEngine().slide(
        corridorMaze(3),
        const Position(0, 0),
        1,
        0,
        const Position(2, 0),
      );

      expect(result.position, const Position(2, 0));
      expect(result.path, <Position>[
        const Position(1, 0),
        const Position(2, 0),
      ]);
    });

    test('stops when a perpendicular turn becomes available', () {
      final SlideResult result = const SlideEngine().slide(
        turnMaze(),
        const Position(0, 0),
        1,
        0,
        const Position(2, 1),
      );

      expect(result.position, const Position(1, 0));
      expect(result.path, <Position>[const Position(1, 0)]);
    });

    test('stops immediately when it reaches the goal', () {
      final SlideResult result = const SlideEngine().slide(
        corridorMaze(3),
        const Position(0, 0),
        1,
        0,
        const Position(1, 0),
      );

      expect(result.position, const Position(1, 0));
      expect(result.path, <Position>[const Position(1, 0)]);
    });

    test('returns no movement when blocked', () {
      final SlideResult result = const SlideEngine().slide(
        buildMazeGrid(1, 1),
        const Position(0, 0),
        1,
        0,
        const Position(0, 0),
      );

      expect(result.moved, isFalse);
      expect(result.position, const Position(0, 0));
      expect(result.path, isEmpty);
    });
  });
}
