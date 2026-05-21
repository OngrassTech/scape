import 'dart:ui';

import 'package:flutter/material.dart';

import '../maze_theme.dart';

class MazeMotion {
  const MazeMotion._();

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration background = Duration(milliseconds: 520);
  static const Duration modal = Duration(milliseconds: 240);
  static const Duration surfaceMorph = Duration(milliseconds: 280);
  static const Duration boardSuccess = Duration(milliseconds: 620);
  static const Duration launchIntro = Duration(milliseconds: 1450);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
}

class MazePressEffect extends StatefulWidget {
  const MazePressEffect({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<MazePressEffect> createState() => _MazePressEffectState();
}

class _MazePressEffectState extends State<MazePressEffect> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedSlide(
        duration: MazeMotion.quick,
        curve: MazeMotion.enterCurve,
        offset: _pressed ? const Offset(0, 0.03) : Offset.zero,
        child: AnimatedScale(
          duration: MazeMotion.quick,
          curve: MazeMotion.enterCurve,
          scale: _pressed ? 0.96 : 1,
          child: widget.child,
        ),
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }
}

class MazeTapScale extends StatefulWidget {
  const MazeTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.deferToChild,
  });

  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  @override
  State<MazeTapScale> createState() => _MazeTapScaleState();
}

class _MazeTapScaleState extends State<MazeTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;

    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: AnimatedSlide(
        duration: MazeMotion.quick,
        curve: MazeMotion.enterCurve,
        offset: _pressed ? const Offset(0, 0.03) : Offset.zero,
        child: AnimatedScale(
          duration: MazeMotion.quick,
          curve: MazeMotion.enterCurve,
          scale: _pressed ? 0.96 : 1,
          child: widget.child,
        ),
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = const BorderRadius.all(Radius.circular(32)),
  });

  final MazePalette palette;
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: palette.uiBorder, width: 2),
          borderRadius: borderRadius,
        ),
        child: child,
      ),
    );
  }
}

class MazeSurfaceFrame extends StatelessWidget {
  const MazeSurfaceFrame({
    super.key,
    required this.palette,
    required this.child,
    this.borderRadius = 0,
    this.borderColor,
    this.backgroundColor,
    this.shadowAlpha = 0.08,
  });

  final MazePalette palette;
  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final double shadowAlpha;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? palette.mazeBg,
          border: Border.all(color: borderColor ?? palette.uiBorder, width: 2),
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class MazeTopPill extends StatelessWidget {
  const MazeTopPill({
    super.key,
    required this.palette,
    required this.child,
    this.pillKey,
    this.backgroundColor,
    this.borderColor,
    this.showShadow = true,
  });

  static const double iconSize = 18;
  static const double buttonExtent = 40;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 3,
    vertical: 3,
  );
  static const double height = 46;
  static const double radius = 999;

  final MazePalette palette;
  final Widget child;
  final Key? pillKey;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: pillKey,
      decoration: BoxDecoration(
        color: backgroundColor ?? palette.uiBg,
        border: Border.all(color: borderColor ?? palette.player, width: 2),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: buttonExtent),
          child: child,
        ),
      ),
    );
  }
}

class MazeTopPillIconButton extends StatelessWidget {
  const MazeTopPillIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.buttonKey,
  }) : child = null;

  const MazeTopPillIconButton.custom({
    super.key,
    required this.child,
    required this.color,
    required this.onPressed,
    this.buttonKey,
  }) : icon = null;

  final IconData? icon;
  final Widget? child;
  final Color color;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return MazeTopPillButton(
      buttonKey: buttonKey,
      onPressed: onPressed,
      child:
          child ??
          Icon(
            icon,
            color: color.withValues(alpha: onPressed == null ? 0.42 : 1),
            size: MazeTopPill.iconSize,
          ),
    );
  }
}

class MazeTopPillButton extends StatelessWidget {
  const MazeTopPillButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.buttonKey,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return MazePressEffect(
      enabled: onPressed != null,
      child: SizedBox(
        key: buttonKey,
        width: MazeTopPill.buttonExtent,
        height: MazeTopPill.buttonExtent,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onPressed,
            containedInkWell: true,
            enableFeedback: false,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            radius: 20,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class MazeTopPillDivider extends StatelessWidget {
  const MazeTopPillDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 22, color: color);
  }
}

class MazeModal extends StatelessWidget {
  const MazeModal({
    super.key,
    required this.palette,
    required this.child,
    this.onDismiss,
    this.barrierKey,
    this.panelKey,
  });

  final MazePalette palette;
  final Widget child;
  final VoidCallback? onDismiss;
  final Key? barrierKey;
  final Key? panelKey;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: MazeMotion.modal,
      curve: MazeMotion.enterCurve,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (BuildContext context, double value, Widget? child) {
        final double panelOpacity = Curves.easeOut.transform(value);
        final double slideOffset = lerpDouble(18, 0, panelOpacity) ?? 0;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              key: barrierKey,
              onTap: onDismiss ?? () {},
              behavior: HitTestBehavior.opaque,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: lerpDouble(0, 7, panelOpacity) ?? 0,
                    sigmaY: lerpDouble(0, 7, panelOpacity) ?? 0,
                  ),
                  child: ColoredBox(
                    color: palette.bg.withValues(alpha: 0.72 * panelOpacity),
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Transform.translate(
                  offset: Offset(0, slideOffset),
                  child: Opacity(
                    opacity: panelOpacity,
                    child: GestureDetector(
                      key: panelKey,
                      onTap: () {},
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

class MazeActionButton extends StatelessWidget {
  const MazeActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.palette,
    this.buttonKey,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.foregroundColor,
    this.disabledForegroundColor,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final MazePalette palette;
  final Key? buttonKey;
  final Color? backgroundColor;
  final Color? disabledBackgroundColor;
  final Color? foregroundColor;
  final Color? disabledForegroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final Color resolvedBackgroundColor = backgroundColor ?? palette.uiBg;
    final Color resolvedDisabledBackgroundColor =
        disabledBackgroundColor ??
        (backgroundColor == null
            ? palette.uiBg.withValues(alpha: 0.7)
            : backgroundColor!);

    return SizedBox(
      width: double.infinity,
      child: MazePressEffect(
        enabled: onPressed != null,
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            enableFeedback: false,
            backgroundColor: resolvedBackgroundColor,
            foregroundColor: foregroundColor ?? palette.player,
            disabledBackgroundColor: resolvedDisabledBackgroundColor,
            disabledForegroundColor:
                disabledForegroundColor ?? palette.textMuted,
            shadowColor: Colors.transparent,
            side: BorderSide(color: borderColor ?? palette.player, width: 2),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class SettingToggleRow extends StatelessWidget {
  const SettingToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.palette,
    this.toggleKey,
  });

  final String label;
  final bool value;
  final VoidCallback onTap;
  final MazePalette palette;
  final Key? toggleKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.player,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          key: toggleKey,
          width: 56,
          height: 32,
          child: MazeTapScale(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: palette.uiBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.player, width: 2),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value ? palette.player : palette.textMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
