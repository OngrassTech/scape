import 'dart:collection';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class PlayerProgress {
  const PlayerProgress({
    required this.points,
    required this.ownedThemes,
    this.equippedThemes = const <ThemeId>{ThemeId.orange},
    required this.bestTimesByDifficulty,
  });

  static const PlayerProgress fallback = PlayerProgress(
    points: 0,
    ownedThemes: <ThemeId>{ThemeId.orange},
    equippedThemes: <ThemeId>{ThemeId.orange},
    bestTimesByDifficulty: <Difficulty, int>{},
  );

  final int points;
  final Set<ThemeId> ownedThemes;
  final Set<ThemeId> equippedThemes;
  final Map<Difficulty, int> bestTimesByDifficulty;

  Set<ThemeId> get ownedThemesView => UnmodifiableSetView<ThemeId>(ownedThemes);
  Set<ThemeId> get equippedThemesView =>
      UnmodifiableSetView<ThemeId>(equippedThemes);

  Map<Difficulty, int> get bestTimesView =>
      UnmodifiableMapView<Difficulty, int>(bestTimesByDifficulty);

  int? bestTimeFor(Difficulty difficulty) => bestTimesByDifficulty[difficulty];

  PlayerProgress copyWith({
    int? points,
    Set<ThemeId>? ownedThemes,
    Set<ThemeId>? equippedThemes,
    Map<Difficulty, int>? bestTimesByDifficulty,
  }) {
    return PlayerProgress(
      points: points ?? this.points,
      ownedThemes: Set<ThemeId>.unmodifiable(ownedThemes ?? this.ownedThemes),
      equippedThemes: Set<ThemeId>.unmodifiable(
        equippedThemes ?? this.equippedThemes,
      ),
      bestTimesByDifficulty: Map<Difficulty, int>.unmodifiable(
        bestTimesByDifficulty ?? this.bestTimesByDifficulty,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! PlayerProgress || other.points != points) {
      return false;
    }

    if (other.ownedThemes.length != ownedThemes.length ||
        other.equippedThemes.length != equippedThemes.length ||
        other.bestTimesByDifficulty.length != bestTimesByDifficulty.length) {
      return false;
    }

    for (final ThemeId theme in ownedThemes) {
      if (!other.ownedThemes.contains(theme)) {
        return false;
      }
    }

    for (final ThemeId theme in equippedThemes) {
      if (!other.equippedThemes.contains(theme)) {
        return false;
      }
    }

    for (final MapEntry<Difficulty, int> entry
        in bestTimesByDifficulty.entries) {
      if (other.bestTimesByDifficulty[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      points,
      Object.hashAllUnordered(ownedThemes),
      Object.hashAllUnordered(equippedThemes),
      Object.hashAll(
        bestTimesByDifficulty.entries.map(
          (MapEntry<Difficulty, int> entry) =>
              Object.hash(entry.key, entry.value),
        ),
      ),
    );
  }
}

abstract class ProgressPreferences {
  Future<PlayerProgress> loadProgress();

  Future<void> saveProgress(PlayerProgress progress);
}

class SharedPreferencesProgressPreferences implements ProgressPreferences {
  const SharedPreferencesProgressPreferences(this._preferences);

  static const String _progressKey = 'progress.player';

  final SharedPreferences _preferences;

  @override
  Future<PlayerProgress> loadProgress() async {
    final String? rawProgress = _preferences.getString(_progressKey);
    if (rawProgress == null || rawProgress.isEmpty) {
      return PlayerProgress.fallback;
    }

    try {
      final Map<String, Object?>? data = _asMap(jsonDecode(rawProgress));
      if (data == null) {
        return PlayerProgress.fallback;
      }

      final int points = _asInt(data['points']) ?? 0;
      final Set<ThemeId> ownedThemes = _decodeOwnedThemes(data['ownedThemes']);
      final Set<ThemeId> equippedThemes = _decodeEquippedThemes(
        data['equippedThemes'],
        ownedThemes,
      );
      final Map<Difficulty, int> bestTimes = _decodeBestTimes(
        data['bestTimesByDifficulty'],
      );

      return PlayerProgress(
        points: points < 0 ? 0 : points,
        ownedThemes: Set<ThemeId>.unmodifiable(
          ownedThemes.isEmpty
              ? <ThemeId>{ThemeId.orange}
              : <ThemeId>{ThemeId.orange, ...ownedThemes},
        ),
        equippedThemes: Set<ThemeId>.unmodifiable(equippedThemes),
        bestTimesByDifficulty: Map<Difficulty, int>.unmodifiable(bestTimes),
      );
    } catch (_) {
      return PlayerProgress.fallback;
    }
  }

  @override
  Future<void> saveProgress(PlayerProgress progress) async {
    final Map<String, Object?> data = <String, Object?>{
      'points': progress.points,
      'ownedThemes': progress.ownedThemes
          .map((ThemeId theme) => theme.name)
          .toList(),
      'equippedThemes': progress.equippedThemes
          .map((ThemeId theme) => theme.name)
          .toList(),
      'bestTimesByDifficulty': <String, int>{
        for (final MapEntry<Difficulty, int> entry
            in progress.bestTimesByDifficulty.entries)
          entry.key.name: entry.value,
      },
    };

    await _preferences.setString(_progressKey, jsonEncode(data));
  }

  Set<ThemeId> _decodeOwnedThemes(Object? raw) {
    final List<Object?>? items = _asList(raw);
    if (items == null) {
      return <ThemeId>{ThemeId.orange};
    }

    final Set<ThemeId> themes = <ThemeId>{ThemeId.orange};
    for (final Object? item in items) {
      final ThemeId? theme = _parseTheme(item);
      if (theme != null) {
        themes.add(theme);
      }
    }
    return themes;
  }

  Set<ThemeId> _decodeEquippedThemes(Object? raw, Set<ThemeId> ownedThemes) {
    final List<Object?>? items = _asList(raw);

    if (items == null) {
      final Set<ThemeId> equippedThemes = <ThemeId>{ThemeId.orange};
      for (final ThemeId theme in shopThemeOrder) {
        if (equippedThemes.length >= maxEquippableThemes) {
          break;
        }
        if (theme != ThemeId.orange && ownedThemes.contains(theme)) {
          equippedThemes.add(theme);
        }
      }
      return equippedThemes;
    }

    final Set<ThemeId> equippedThemes = <ThemeId>{};
    for (final Object? item in items) {
      final ThemeId? theme = _parseTheme(item);
      if (theme == null || !ownedThemes.contains(theme)) {
        continue;
      }
      equippedThemes.add(theme);
      if (equippedThemes.length >= maxEquippableThemes) {
        break;
      }
    }

    return equippedThemes;
  }

  Map<Difficulty, int> _decodeBestTimes(Object? raw) {
    final Map<String, Object?>? data = _asMap(raw);
    if (data == null) {
      return <Difficulty, int>{};
    }

    final Map<Difficulty, int> bestTimes = <Difficulty, int>{};
    for (final MapEntry<String, Object?> entry in data.entries) {
      final Difficulty? difficulty = _parseDifficulty(entry.key);
      final int? seconds = _asInt(entry.value);
      if (difficulty != null && seconds != null && seconds >= 0) {
        bestTimes[difficulty] = seconds;
      }
    }
    return bestTimes;
  }

  ThemeId? _parseTheme(Object? rawTheme) {
    if (rawTheme is! String) {
      return null;
    }

    for (final ThemeId theme in ThemeId.values) {
      if (theme.name == rawTheme) {
        return theme;
      }
    }

    return null;
  }

  Difficulty? _parseDifficulty(Object? rawDifficulty) {
    if (rawDifficulty is! String) {
      return null;
    }

    for (final Difficulty difficulty in Difficulty.values) {
      if (difficulty.name == rawDifficulty) {
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
}
