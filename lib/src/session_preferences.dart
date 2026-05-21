import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class SavedGameSession {
  const SavedGameSession({
    required this.difficulty,
    required this.isTimeTrial,
    required this.time,
    required this.maze,
    required this.playerPos,
    required this.trail,
    required this.hintUsed,
  });

  final Difficulty difficulty;
  final bool isTimeTrial;
  final int time;
  final List<List<MazeCell>> maze;
  final Position playerPos;
  final List<Position> trail;
  final bool hintUsed;
}

abstract class SessionPreferences {
  Future<SavedGameSession?> loadSession();

  Future<void> saveSession(SavedGameSession session);

  Future<void> clearSession();
}

class SharedPreferencesSessionPreferences implements SessionPreferences {
  const SharedPreferencesSessionPreferences(this._preferences);

  static const String _sessionKey = 'session.current_game';

  final SharedPreferences _preferences;

  @override
  Future<SavedGameSession?> loadSession() async {
    final String? rawSession = _preferences.getString(_sessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    try {
      final Map<String, Object?>? data = _asMap(jsonDecode(rawSession));
      if (data == null) {
        return null;
      }

      final Difficulty? difficulty = _parseDifficulty(data['difficulty']);
      final bool? isTimeTrial = _asBool(data['isTimeTrial']);
      final int? time = _asInt(data['time']);
      final List<List<MazeCell>>? maze = _decodeMaze(data['maze']);
      final Position? playerPos = _decodePosition(data['playerPos']);
      final List<Position>? trail = _decodeTrail(data['trail']);
      final bool? hintUsed = _asBool(data['hintUsed']);
      if (difficulty == null ||
          isTimeTrial == null ||
          time == null ||
          maze == null ||
          maze.isEmpty ||
          playerPos == null ||
          trail == null ||
          hintUsed == null) {
        return null;
      }

      return SavedGameSession(
        difficulty: difficulty,
        isTimeTrial: isTimeTrial,
        time: time,
        maze: maze,
        playerPos: playerPos,
        trail: trail,
        hintUsed: hintUsed,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSession(SavedGameSession session) async {
    final Map<String, Object?> data = <String, Object?>{
      'difficulty': session.difficulty.name,
      'isTimeTrial': session.isTimeTrial,
      'time': session.time,
      'maze': _encodeMaze(session.maze),
      'playerPos': _encodePosition(session.playerPos),
      'trail': session.trail.map(_encodePosition).toList(growable: false),
      'hintUsed': session.hintUsed,
    };
    await _preferences.setString(_sessionKey, jsonEncode(data));
  }

  @override
  Future<void> clearSession() async {
    await _preferences.remove(_sessionKey);
  }

  Object _encodePosition(Position position) {
    return <String, int>{
      'x': position.x,
      'y': position.y,
    };
  }

  Object _encodeMaze(List<List<MazeCell>> maze) {
    return maze
        .map(
          (List<MazeCell> row) => row
              .map((MazeCell cell) => _encodeWalls(cell.walls))
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  int _encodeWalls(WallSet walls) {
    int mask = 0;
    if (walls.top) {
      mask |= 1;
    }
    if (walls.right) {
      mask |= 2;
    }
    if (walls.bottom) {
      mask |= 4;
    }
    if (walls.left) {
      mask |= 8;
    }
    return mask;
  }

  Position? _decodePosition(Object? raw) {
    final Map<String, Object?>? data = _asMap(raw);
    if (data == null) {
      return null;
    }

    final int? x = _asInt(data['x']);
    final int? y = _asInt(data['y']);
    if (x == null || y == null) {
      return null;
    }

    return Position(x, y);
  }

  List<Position>? _decodeTrail(Object? raw) {
    final List<Object?>? items = _asList(raw);
    if (items == null) {
      return null;
    }

    final List<Position> trail = <Position>[];
    for (final Object? item in items) {
      final Position? position = _decodePosition(item);
      if (position == null) {
        return null;
      }
      trail.add(position);
    }

    return List<Position>.unmodifiable(trail);
  }

  List<List<MazeCell>>? _decodeMaze(Object? raw) {
    final List<Object?>? rows = _asList(raw);
    if (rows == null || rows.isEmpty) {
      return null;
    }

    final List<List<MazeCell>> maze = <List<MazeCell>>[];
    int? width;
    for (int y = 0; y < rows.length; y++) {
      final List<Object?>? rowData = _asList(rows[y]);
      if (rowData == null || rowData.isEmpty) {
        return null;
      }
      width ??= rowData.length;
      if (rowData.length != width) {
        return null;
      }

      final List<MazeCell> row = <MazeCell>[];
      for (int x = 0; x < rowData.length; x++) {
        final int? mask = _asInt(rowData[x]);
        if (mask == null) {
          return null;
        }
        row.add(
          MazeCell(
            x: x,
            y: y,
            walls: _decodeWalls(mask),
          ),
        );
      }
      maze.add(List<MazeCell>.unmodifiable(row));
    }

    return List<List<MazeCell>>.unmodifiable(maze);
  }

  WallSet _decodeWalls(int mask) {
    return WallSet(
      top: (mask & 1) != 0,
      right: (mask & 2) != 0,
      bottom: (mask & 4) != 0,
      left: (mask & 8) != 0,
    );
  }

  Difficulty? _parseDifficulty(Object? raw) {
    if (raw is! String) {
      return null;
    }

    for (final Difficulty difficulty in Difficulty.values) {
      if (difficulty.name == raw) {
        return difficulty;
      }
    }

    return null;
  }

  Map<String, Object?>? _asMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    return value.map(
      (Object? key, Object? mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  List<Object?>? _asList(Object? value) {
    if (value is! List) {
      return null;
    }

    return List<Object?>.from(value);
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  bool? _asBool(Object? value) {
    return value is bool ? value : null;
  }
}
