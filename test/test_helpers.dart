import 'dart:math';

import 'package:mazegame/src/appearance_preferences.dart';
import 'package:mazegame/src/feedback.dart';
import 'package:mazegame/src/maze_logic.dart';
import 'package:mazegame/src/models.dart';
import 'package:mazegame/src/progress_preferences.dart';
import 'package:mazegame/src/session_preferences.dart';

class FixedMazeGenerator extends MazeGenerator {
  const FixedMazeGenerator(this.template);

  final List<List<MazeCell>> template;

  @override
  List<List<MazeCell>> generate(int width, int height, {Random? random}) {
    return cloneMaze(template);
  }
}

class OpenRouteMazeGenerator extends MazeGenerator {
  const OpenRouteMazeGenerator();

  @override
  List<List<MazeCell>> generate(int width, int height, {Random? random}) {
    final List<List<MazeCell>> maze = buildMazeGrid(width, height);
    for (int x = 0; x < width - 1; x++) {
      openRight(maze, x, 0);
    }
    for (int y = 0; y < height - 1; y++) {
      openBottom(maze, width - 1, y);
    }
    return maze;
  }
}

List<List<MazeCell>> cloneMaze(List<List<MazeCell>> maze) {
  return maze
      .map(
        (List<MazeCell> row) =>
            row.map((MazeCell cell) => cell.copy()).toList(),
      )
      .toList();
}

List<List<MazeCell>> buildMazeGrid(int width, int height) {
  return List<List<MazeCell>>.generate(
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
}

void openRight(List<List<MazeCell>> maze, int x, int y) {
  maze[y][x].walls.right = false;
  maze[y][x + 1].walls.left = false;
}

void openBottom(List<List<MazeCell>> maze, int x, int y) {
  maze[y][x].walls.bottom = false;
  maze[y + 1][x].walls.top = false;
}

List<List<MazeCell>> corridorMaze(int length) {
  final List<List<MazeCell>> maze = buildMazeGrid(length, 1);
  for (int x = 0; x < length - 1; x++) {
    openRight(maze, x, 0);
  }
  return maze;
}

List<List<MazeCell>> turnMaze() {
  final List<List<MazeCell>> maze = buildMazeGrid(3, 2);
  openRight(maze, 0, 0);
  openRight(maze, 1, 0);
  openBottom(maze, 1, 0);
  return maze;
}

List<List<MazeCell>> easySnakeMaze() {
  const int width = 10;
  const int height = 15;
  final List<List<MazeCell>> maze = buildMazeGrid(width, height);

  for (int y = 0; y < height; y++) {
    if (y.isEven) {
      for (int x = 0; x < width - 1; x++) {
        openRight(maze, x, y);
      }
    } else {
      for (int x = width - 1; x > 0; x--) {
        openRight(maze, x - 1, y);
      }
    }

    if (y < height - 1) {
      final int connectorX = y.isEven ? width - 1 : 0;
      openBottom(maze, connectorX, y);
    }
  }

  return maze;
}

List<List<MazeCell>> easyLPathMaze() {
  const int width = 10;
  const int height = 15;
  final List<List<MazeCell>> maze = buildMazeGrid(width, height);

  for (int x = 0; x < width - 1; x++) {
    openRight(maze, x, 0);
  }
  for (int y = 0; y < height - 1; y++) {
    openBottom(maze, width - 1, y);
  }

  return maze;
}

class RecordingFeedbackController extends NoopFeedbackController {
  final List<SoundCue> sounds = <SoundCue>[];
  final List<HapticCue> haptics = <HapticCue>[];

  @override
  Future<void> playHaptic(HapticCue cue) async {
    haptics.add(cue);
  }

  @override
  Future<void> playSound(SoundCue cue) async {
    sounds.add(cue);
  }
}

class MemoryAppearancePreferences implements AppearancePreferences {
  MemoryAppearancePreferences({this.storedAppearance = AppAppearance.fallback});

  AppAppearance storedAppearance;
  final List<AppAppearance> savedAppearances = <AppAppearance>[];

  @override
  Future<AppAppearance> loadAppearance() async {
    return storedAppearance;
  }

  @override
  Future<void> saveAppearance(AppAppearance appearance) async {
    storedAppearance = appearance;
    savedAppearances.add(appearance);
  }
}

class MemorySessionPreferences implements SessionPreferences {
  SavedGameSession? storedSession;
  final List<SavedGameSession> savedSessions = <SavedGameSession>[];
  int clearCount = 0;

  @override
  Future<void> clearSession() async {
    storedSession = null;
    clearCount++;
  }

  @override
  Future<SavedGameSession?> loadSession() async {
    return storedSession;
  }

  @override
  Future<void> saveSession(SavedGameSession session) async {
    storedSession = session;
    savedSessions.add(session);
  }
}

class MemoryProgressPreferences implements ProgressPreferences {
  MemoryProgressPreferences({this.storedProgress = PlayerProgress.fallback});

  PlayerProgress storedProgress;
  final List<PlayerProgress> savedProgress = <PlayerProgress>[];

  @override
  Future<PlayerProgress> loadProgress() async {
    return storedProgress;
  }

  @override
  Future<void> saveProgress(PlayerProgress progress) async {
    storedProgress = progress;
    savedProgress.add(progress);
  }
}
