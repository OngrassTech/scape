enum AppScreen { menu, playing }

enum Difficulty { easy, medium, hard, expert, nightmare }

enum ThemeId {
  slate,
  orange,
  gold,
  dandelion,
  rose,
  emerald,
  sapphire,
  violet,
  coral,
  aqua,
  cocoa,
}

enum SettingsPanelPage { options, shop, score }

enum SoundCue { swipe, toggle, move, success, failure }

enum HapticCue { medium, heavy, success, failure }

const int maxEquippableThemes = 4;

const List<ThemeId> shopThemeOrder = <ThemeId>[
  ThemeId.orange,
  ThemeId.gold,
  ThemeId.dandelion,
  ThemeId.emerald,
  ThemeId.rose,
  ThemeId.sapphire,
  ThemeId.violet,
  ThemeId.cocoa,
  ThemeId.coral,
  ThemeId.aqua,
  ThemeId.slate,
];

class Position {
  const Position(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) {
    return other is Position && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

class WallSet {
  WallSet({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  bool top;
  bool right;
  bool bottom;
  bool left;

  WallSet copy() {
    return WallSet(top: top, right: right, bottom: bottom, left: left);
  }
}

class MazeCell {
  MazeCell({
    required this.x,
    required this.y,
    required this.walls,
    this.visited = false,
  });

  final int x;
  final int y;
  final WallSet walls;
  bool visited;

  MazeCell copy() {
    return MazeCell(x: x, y: y, walls: walls.copy(), visited: visited);
  }
}

class DifficultyConfig {
  const DifficultyConfig({
    required this.label,
    required this.width,
    required this.height,
    required this.timeLimitSeconds,
    required this.previewSize,
  });

  final String label;
  final int width;
  final int height;
  final int timeLimitSeconds;
  final int previewSize;
}

const Map<Difficulty, DifficultyConfig> difficultyConfigs =
    <Difficulty, DifficultyConfig>{
      Difficulty.easy: DifficultyConfig(
        label: 'Easy',
        width: 10,
        height: 15,
        timeLimitSeconds: 15,
        previewSize: 6,
      ),
      Difficulty.medium: DifficultyConfig(
        label: 'Medium',
        width: 16,
        height: 24,
        timeLimitSeconds: 30,
        previewSize: 16,
      ),
      Difficulty.hard: DifficultyConfig(
        label: 'Hard',
        width: 20,
        height: 30,
        timeLimitSeconds: 40,
        previewSize: 20,
      ),
      Difficulty.expert: DifficultyConfig(
        label: 'Expert',
        width: 25,
        height: 37,
        timeLimitSeconds: 80,
        previewSize: 30,
      ),
      Difficulty.nightmare: DifficultyConfig(
        label: 'Nightmare',
        width: 30,
        height: 45,
        timeLimitSeconds: 105,
        previewSize: 42,
      ),
    };

extension DifficultyX on Difficulty {
  DifficultyConfig get config => difficultyConfigs[this]!;

  String get label => config.label;
}

extension ThemeIdX on ThemeId {
  String get label {
    switch (this) {
      case ThemeId.slate:
        return 'Slate';
      case ThemeId.orange:
        return 'Amber';
      case ThemeId.gold:
        return 'Gold';
      case ThemeId.dandelion:
        return 'Dandelion';
      case ThemeId.rose:
        return 'Rose';
      case ThemeId.emerald:
        return 'Emerald';
      case ThemeId.sapphire:
        return 'Sapphire';
      case ThemeId.violet:
        return 'Violet';
      case ThemeId.coral:
        return 'Coral';
      case ThemeId.aqua:
        return 'Aqua';
      case ThemeId.cocoa:
        return 'Cocoa';
    }
  }

  int get shopCost {
    switch (this) {
      case ThemeId.orange:
      case ThemeId.gold:
      case ThemeId.dandelion:
      case ThemeId.rose:
      case ThemeId.emerald:
      case ThemeId.sapphire:
      case ThemeId.violet:
      case ThemeId.cocoa:
        return 20;
      case ThemeId.coral:
        return 67;
      case ThemeId.aqua:
        return 69;
      case ThemeId.slate:
        return 420;
    }
  }

  bool get isDefaultOwned => this == ThemeId.orange;
}

class SlideResult {
  const SlideResult({required this.position, required this.path});

  final Position position;
  final List<Position> path;

  bool get moved => path.isNotEmpty;
}
