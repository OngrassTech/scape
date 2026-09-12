import 'package:flutter_test/flutter_test.dart';
import 'package:mazegame/src/models.dart';
import 'package:mazegame/src/session_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saves and restores a resumable session from shared preferences', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final SharedPreferencesSessionPreferences store =
        SharedPreferencesSessionPreferences(preferences);

    final List<List<MazeCell>> maze = <List<MazeCell>>[
      <MazeCell>[
        MazeCell(
          x: 0,
          y: 0,
          walls: WallSet(top: true, right: false, bottom: true, left: true),
        ),
        MazeCell(
          x: 1,
          y: 0,
          walls: WallSet(top: true, right: true, bottom: false, left: false),
        ),
      ],
      <MazeCell>[
        MazeCell(
          x: 0,
          y: 1,
          walls: WallSet(top: true, right: false, bottom: true, left: true),
        ),
        MazeCell(
          x: 1,
          y: 1,
          walls: WallSet(top: false, right: true, bottom: true, left: false),
        ),
      ],
    ];

    await store.saveSession(
      SavedGameSession(
        difficulty: Difficulty.easy,
        isTimeTrial: true,
        time: 11,
        maze: maze,
        playerPos: const Position(1, 1),
        trail: const <Position>[
          Position(0, 0),
          Position(1, 0),
          Position(1, 1),
        ],
        hintUsed: true,
      ),
    );

    final SavedGameSession? restored = await store.loadSession();

    expect(restored, isNotNull);
    expect(restored!.difficulty, Difficulty.easy);
    expect(restored.isTimeTrial, isTrue);
    expect(restored.time, 11);
    expect(restored.playerPos, const Position(1, 1));
    expect(
      restored.trail,
      const <Position>[Position(0, 0), Position(1, 0), Position(1, 1)],
    );
    expect(restored.hintUsed, isTrue);
    expect(restored.maze.length, 2);
    expect(restored.maze.first.length, 2);
    expect(restored.maze[0][0].walls.right, isFalse);
    expect(restored.maze[0][1].walls.bottom, isFalse);
    expect(restored.maze[1][1].walls.top, isFalse);
  });

  test('returns null when no saved session exists', () async {
    final SavedGameSession? restored = await SharedPreferencesSessionPreferences(
      await SharedPreferences.getInstance(),
    ).loadSession();

    expect(restored, isNull);
  });
}
