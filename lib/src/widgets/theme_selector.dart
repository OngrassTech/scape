import 'package:flutter/material.dart';

import '../game_session_controller.dart';
import '../maze_theme.dart';
import '../models.dart';
import 'common.dart';

class ThemeSelector extends StatefulWidget {
  const ThemeSelector({
    super.key,
    required this.controller,
    required this.palette,
  });

  final GameSessionController controller;
  final MazePalette palette;

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<ThemeId, Color>> themes = widget
        .controller
        .availableThemes
        .map(
          (ThemeId theme) =>
              MapEntry<ThemeId, Color>(theme, _themeChipColor(theme)),
        )
        .toList(growable: false);

    return MazeTopPill(
      pillKey: const Key('theme-selector-pill'),
      palette: widget.palette,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MazeTopPillIconButton(
            buttonKey: const Key('theme-toggle-button'),
            onPressed: () {
              widget.controller.playUiFeedback(
                sound: SoundCue.swipe,
                haptic: HapticCue.heavy,
              );
              setState(() {
                _expanded = !_expanded;
              });
            },
            icon: Icons.palette_rounded,
            color: widget.palette.player,
          ),
          AnimatedSize(
            duration: MazeMotion.standard,
            curve: MazeMotion.enterCurve,
            child: _expanded
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ...themes.map((MapEntry<ThemeId, Color> theme) {
                        final bool selected =
                            widget.controller.theme == theme.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: GestureDetector(
                            key: Key('theme-option-${theme.key.name}'),
                            onTap: () => widget.controller.setTheme(theme.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: theme.value,
                                borderRadius: BorderRadius.circular(999),
                                border: selected
                                    ? Border.all(
                                        color: widget.palette.grid,
                                        width: 2,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.only(left: 1, right: 5),
                        child: MazeTopPillDivider(
                          color: widget.palette.player.withValues(alpha: 0.4),
                        ),
                      ),
                      MazeTopPillIconButton(
                        onPressed: widget.controller.toggleDarkMode,
                        icon: widget.controller.isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: widget.palette.player,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

Color _themeChipColor(ThemeId theme) {
  switch (theme) {
    case ThemeId.slate:
      return const Color(0xFF6B7280);
    case ThemeId.orange:
      return const Color(0xFFF97316);
    case ThemeId.gold:
      return const Color(0xFFE0A11A);
    case ThemeId.dandelion:
      return const Color(0xFFF2C94C);
    case ThemeId.rose:
      return const Color(0xFFF43F5E);
    case ThemeId.emerald:
      return const Color(0xFF10B981);
    case ThemeId.sapphire:
      return const Color(0xFF3B82F6);
    case ThemeId.violet:
      return const Color(0xFF8B5CF6);
    case ThemeId.coral:
      return const Color(0xFFFB7185);
    case ThemeId.aqua:
      return const Color(0xFF06B6D4);
    case ThemeId.cocoa:
      return const Color(0xFFB08968);
  }
}
