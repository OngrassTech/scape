import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppAppearance {
  const AppAppearance({
    required this.theme,
    required this.isDark,
  });

  static const AppAppearance fallback = AppAppearance(
    theme: ThemeId.orange,
    isDark: true,
  );

  final ThemeId theme;
  final bool isDark;

  @override
  bool operator ==(Object other) {
    return other is AppAppearance &&
        other.theme == theme &&
        other.isDark == isDark;
  }

  @override
  int get hashCode => Object.hash(theme, isDark);
}

abstract class AppearancePreferences {
  Future<AppAppearance> loadAppearance();

  Future<void> saveAppearance(AppAppearance appearance);
}

class SharedPreferencesAppearancePreferences
    implements AppearancePreferences {
  const SharedPreferencesAppearancePreferences(this._preferences);

  static const String _themeKey = 'appearance.theme';
  static const String _isDarkKey = 'appearance.is_dark';

  final SharedPreferences _preferences;

  @override
  Future<AppAppearance> loadAppearance() async {
    final ThemeId? theme = _parseTheme(_preferences.getString(_themeKey));
    final bool? isDark = _preferences.getBool(_isDarkKey);

    return AppAppearance(
      theme: theme ?? AppAppearance.fallback.theme,
      isDark: isDark ?? AppAppearance.fallback.isDark,
    );
  }

  @override
  Future<void> saveAppearance(AppAppearance appearance) async {
    await _preferences.setString(_themeKey, appearance.theme.name);
    await _preferences.setBool(_isDarkKey, appearance.isDark);
  }

  ThemeId? _parseTheme(String? rawTheme) {
    if (rawTheme == null) {
      return null;
    }

    for (final ThemeId theme in ThemeId.values) {
      if (theme.name == rawTheme) {
        return theme;
      }
    }

    return null;
  }
}
