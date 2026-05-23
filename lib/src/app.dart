import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appearance_preferences.dart';
import 'game_session_controller.dart';
import 'maze_theme.dart';
import 'models.dart';
import 'progress_preferences.dart';
import 'session_preferences.dart';
import 'widgets/background_maze.dart';
import 'widgets/common.dart';
import 'widgets/game_screen.dart';
import 'widgets/help_dialog.dart';
import 'widgets/menu_screen.dart';
import 'widgets/settings_dialog.dart';

class MazeGameApp extends StatefulWidget {
  const MazeGameApp({
    super.key,
    this.controller,
    this.appearancePreferences,
    this.initialAppearance = AppAppearance.fallback,
    this.progressPreferences,
    this.initialProgress = PlayerProgress.fallback,
    this.sessionPreferences,
    this.initialSession,
  });

  final GameSessionController? controller;
  final AppearancePreferences? appearancePreferences;
  final AppAppearance initialAppearance;
  final ProgressPreferences? progressPreferences;
  final PlayerProgress initialProgress;
  final SessionPreferences? sessionPreferences;
  final SavedGameSession? initialSession;

  @override
  State<MazeGameApp> createState() => _MazeGameAppState();
}

class _MazeGameAppState extends State<MazeGameApp> {
  late final GameSessionController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        GameSessionController(
          appearancePreferences: widget.appearancePreferences,
          progressPreferences: widget.progressPreferences,
          sessionPreferences: widget.sessionPreferences,
          initialAppearance: widget.initialAppearance,
          initialProgress: widget.initialProgress,
          initialSession: widget.initialSession,
        );
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final MazePalette palette = MazeThemeRegistry.resolve(
          _controller.theme,
          _controller.isDark,
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: _controller.isDark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: palette.player,
              brightness: _controller.isDark
                  ? Brightness.dark
                  : Brightness.light,
            ),
            scaffoldBackgroundColor: palette.bg,
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(enableFeedback: false),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(enableFeedback: false),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(enableFeedback: false),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(enableFeedback: false),
            ),
            useMaterial3: true,
          ),
          home: _MazeGameHome(controller: _controller, palette: palette),
        );
      },
    );
  }
}

class _MazeGameHome extends StatefulWidget {
  const _MazeGameHome({required this.controller, required this.palette});

  final GameSessionController controller;
  final MazePalette palette;

  @override
  State<_MazeGameHome> createState() => _MazeGameHomeState();
}

class _MazeGameHomeState extends State<_MazeGameHome> {
  final GlobalKey _stackKey = GlobalKey(debugLabel: 'home-stack');
  final GlobalKey _menuSurfaceKey = GlobalKey(debugLabel: 'menu-surface');
  final GlobalKey _boardSurfaceKey = GlobalKey(debugLabel: 'board-surface');

  _SurfaceMorphSpec? _surfaceMorph;
  Timer? _exitToastTimer;
  Timer? _launchIntroTimer;
  bool _exitBackArmed = false;
  bool _showExitToast = false;
  bool _isOverlayMenuTransitionActive = false;
  bool _showLaunchIntro = true;

  GameSessionController get controller => widget.controller;
  MazePalette get palette => widget.palette;

  @override
  void initState() {
    super.initState();
    _launchIntroTimer = Timer(MazeMotion.launchIntro, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showLaunchIntro = false;
      });
    });
  }

  @override
  void dispose() {
    _exitToastTimer?.cancel();
    _launchIntroTimer?.cancel();
    super.dispose();
  }

  Rect? _localRectFor(GlobalKey key) {
    final BuildContext? context = key.currentContext;
    final BuildContext? stackContext = _stackKey.currentContext;
    if (context == null || stackContext == null) {
      return null;
    }

    final RenderObject? renderObject = context.findRenderObject();
    final RenderObject? stackRenderObject = stackContext.findRenderObject();
    if (renderObject is! RenderBox ||
        stackRenderObject is! RenderBox ||
        !renderObject.hasSize ||
        !stackRenderObject.hasSize) {
      return null;
    }

    final Offset offset = renderObject.localToGlobal(
      Offset.zero,
      ancestor: stackRenderObject,
    );
    return offset & renderObject.size;
  }

  void _handleStartGame() {
    _disarmExitToast();
    final Rect? fromRect = _localRectFor(_menuSurfaceKey);
    controller.startNewGame();

    if (fromRect == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final Rect? toRect = _localRectFor(_boardSurfaceKey);
      if (toRect == null) {
        return;
      }
      setState(() {
        _surfaceMorph = _SurfaceMorphSpec.menuToBoard(
          fromRect: fromRect,
          toRect: toRect,
        );
      });
    });
  }

  void _handleGameBackToMenu({required bool preserveResume, Rect? fromRect}) {
    _disarmExitToast();
    final Rect? originRect = fromRect ?? _localRectFor(_boardSurfaceKey);
    controller.backToMenu(withFeedback: false, preserveResume: preserveResume);

    if (originRect == null) {
      if (_isOverlayMenuTransitionActive && mounted) {
        setState(() {
          _isOverlayMenuTransitionActive = false;
        });
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final Rect? toRect = _localRectFor(_menuSurfaceKey);
      if (toRect == null) {
        if (_isOverlayMenuTransitionActive) {
          setState(() {
            _isOverlayMenuTransitionActive = false;
          });
        }
        return;
      }
      setState(() {
        _surfaceMorph = _SurfaceMorphSpec.boardToMenu(
          fromRect: originRect,
          toRect: toRect,
        );
      });
    });
  }

  Future<void> _handleOverlayMainMenu() async {
    if (_isOverlayMenuTransitionActive) {
      return;
    }

    _disarmExitToast();
    final Rect? fromRect = _localRectFor(_boardSurfaceKey);
    controller.playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    setState(() {
      _isOverlayMenuTransitionActive = true;
    });
    controller.dismissGameplayOverlay();

    await Future<void>.delayed(MazeMotion.modal);
    if (!mounted) {
      return;
    }

    _handleGameBackToMenu(preserveResume: false, fromRect: fromRect);
  }

  void _clearSurfaceMorph() {
    if (!mounted) {
      return;
    }
    setState(() {
      _surfaceMorph = null;
      _isOverlayMenuTransitionActive = false;
    });
  }

  void _handleSystemBack() {
    if (_isOverlayMenuTransitionActive) {
      return;
    }

    if (controller.showHelp || controller.showSettings) {
      _disarmExitToast();
      controller.handleSystemBack();
      return;
    }

    if (controller.screen == AppScreen.playing) {
      _handleGameBackToMenu(
        preserveResume:
            controller.isPlaying &&
            !controller.showLevelComplete &&
            !controller.isGameOver,
      );
      return;
    }

    _handleMenuBack();
  }

  void _handleMenuBack() {
    if (_exitBackArmed) {
      _exitToastTimer?.cancel();
      _exitBackArmed = false;
      _showExitToast = false;
      SystemNavigator.pop();
      return;
    }

    setState(() {
      _exitBackArmed = true;
      _showExitToast = true;
    });
    _exitToastTimer?.cancel();
    _exitToastTimer = Timer(const Duration(seconds: 2), _disarmExitToast);
  }

  void _disarmExitToast() {
    _exitToastTimer?.cancel();
    _exitBackArmed = false;
    if (!_showExitToast || !mounted) {
      return;
    }
    setState(() {
      _showExitToast = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void _) {
        if (didPop) {
          return;
        }
        _handleSystemBack();
      },
      child: Scaffold(
        body: AnimatedContainer(
          duration: MazeMotion.standard,
          color: palette.bg,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double topInset = MediaQuery.viewPaddingOf(context).top;
              final bool showBottomNav =
                  !_isOverlayMenuTransitionActive &&
                  !controller.hasBlockingOverlay &&
                  !(controller.screen == AppScreen.menu && _showLaunchIntro);
              final bool showGameplayTimer =
                  controller.screen == AppScreen.playing &&
                  !_isOverlayMenuTransitionActive &&
                  !controller.hasBlockingOverlay;
              final bool showOverlayToast =
                  controller.transientToastMessage != null &&
                  controller.transientToastAnchor ==
                      TransientToastAnchor.overlay;
              final bool showTopToast =
                  controller.transientToastMessage != null &&
                  controller.transientToastAnchor == TransientToastAnchor.top;
              final Widget content = Padding(
                padding: EdgeInsets.only(top: topInset),
                child: controller.screen == AppScreen.menu
                    ? MenuScreen(
                        controller: controller,
                        palette: palette,
                        onStartGame: _handleStartGame,
                        showLaunchIntro: _showLaunchIntro,
                        surfaceKey: _menuSurfaceKey,
                      )
                    : GameScreen(
                        controller: controller,
                        palette: palette,
                        surfaceKey: _boardSurfaceKey,
                      ),
              );

              final Widget stack = Stack(
                key: _stackKey,
                children: <Widget>[
                  Positioned.fill(
                    // BackgroundMaze now self-animates the wall-morph when
                    // difficulty changes — no AnimatedSwitcher needed here.
                    child: BackgroundMaze(
                      difficulty: controller.difficulty,
                      palette: palette,
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: MazeMotion.standard,
                      switchInCurve: MazeMotion.enterCurve,
                      switchOutCurve: MazeMotion.exitCurve,
                      child: KeyedSubtree(
                        key: ValueKey<AppScreen>(controller.screen),
                        child: content,
                      ),
                    ),
                  ),
                  if (_surfaceMorph case final _SurfaceMorphSpec surfaceMorph)
                    Positioned.fill(
                      child: _SurfaceMorph(
                        palette: palette,
                        spec: surfaceMorph,
                        onComplete: _clearSurfaceMorph,
                      ),
                    ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16 + topInset, 16, 16),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: AnimatedOpacity(
                          key: const Key('game-timer-fade'),
                          duration: MazeMotion.standard,
                          curve: MazeMotion.enterCurve,
                          opacity: showGameplayTimer ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !showGameplayTimer,
                            child: _GameplayTimerPill(
                              controller: controller,
                              palette: palette,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (controller.showHelp)
                    Positioned.fill(
                      child: HelpDialog(
                        controller: controller,
                        palette: palette,
                      ),
                    ),
                  if (controller.showSettings)
                    Positioned.fill(
                      child: SettingsDialog(
                        controller: controller,
                        palette: palette,
                        onMainMenu: _handleOverlayMainMenu,
                      ),
                    ),
                  if (controller.showLevelComplete || controller.isGameOver)
                    Positioned.fill(
                      child: GameResultOverlay(
                        controller: controller,
                        palette: palette,
                        onMainMenu: _handleOverlayMainMenu,
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      left: false,
                      right: false,
                      minimum: const EdgeInsets.only(bottom: 28),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedOpacity(
                          key: const Key('bottom-nav-fade'),
                          duration: MazeMotion.standard,
                          curve: MazeMotion.enterCurve,
                          opacity: showBottomNav ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !showBottomNav,
                            child: _BottomNavBar(
                              controller: controller,
                              palette: palette,
                              isVisible: showBottomNav,
                              embeddedMessage: _showExitToast
                                  ? 'Press back again to exit'
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 24,
                    right: 24,
                    child: SafeArea(
                      bottom: false,
                      left: false,
                      right: false,
                      minimum: EdgeInsets.only(
                        top: controller.screen == AppScreen.playing ? 72 : 24,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _TopToast(
                          palette: palette,
                          visible: showTopToast,
                          message: controller.transientToastMessage ?? '',
                          toastKey: const Key('purchase-toast'),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      left: false,
                      right: false,
                      minimum: const EdgeInsets.only(bottom: 24),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _BottomToast(
                          palette: palette,
                          visible: showOverlayToast,
                          message: controller.transientToastMessage ?? '',
                          toastKey: const Key('purchase-toast'),
                        ),
                      ),
                    ),
                  ),
                ],
              );

              if (controller.screen == AppScreen.playing) {
                return GameplaySwipeLayer(
                  enabled:
                      controller.isPlaying &&
                      !controller.hasBlockingOverlay &&
                      !_isOverlayMenuTransitionActive,
                  onMove: controller.move,
                  child: stack,
                );
              }

              return stack;
            },
          ),
        ),
      ),
    );
  }
}

class _GameplayTimerPill extends StatelessWidget {
  const _GameplayTimerPill({required this.controller, required this.palette});

  final GameSessionController controller;
  final MazePalette palette;

  @override
  Widget build(BuildContext context) {
    final bool isDanger = controller.isTimeTrial && controller.time <= 10;
    final String timeLabel = controller.formatTime(controller.time);
    final Color borderColor = isDanger
        ? const Color(0xFFFF6B6B)
        : palette.player;

    return AnimatedSize(
      duration: MazeMotion.standard,
      curve: MazeMotion.enterCurve,
      alignment: Alignment.centerRight,
      child: UnconstrainedBox(
        alignment: Alignment.centerRight,
        child: AnimatedContainer(
          key: const Key('game-timer-pill'),
          duration: MazeMotion.standard,
          curve: MazeMotion.enterCurve,
          constraints: const BoxConstraints(minHeight: MazeTopPill.height),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(MazeTopPill.radius),
          ),
          child: Text(
            timeLabel,
            style: TextStyle(
              color: borderColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatefulWidget {
  const _BottomNavBar({
    required this.controller,
    required this.palette,
    required this.isVisible,
    this.embeddedMessage,
  });

  final GameSessionController controller;
  final MazePalette palette;
  final bool isVisible;
  final String? embeddedMessage;

  @override
  State<_BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<_BottomNavBar>
    with TickerProviderStateMixin {
  static const Duration _themeSwapDuration = Duration(milliseconds: 320);
  static const Duration _timeTrialToastDuration = Duration(seconds: 1);
  static const double _navActionContentWidth =
      (MazeTopPill.buttonExtent * 6) + 5;

  late final AnimationController _themeSwapController;
  late final AnimationController _inlineMessageController;
  bool _showThemeOptions = false;
  Timer? _inlineMessageTimer;
  String? _inlineMessage;
  int _inlineMessageCycle = 0;
  Timer? _lockToastTimer;
  String? _lockToastMessage;

  GameSessionController get controller => widget.controller;
  MazePalette get palette => widget.palette;

  @override
  void initState() {
    super.initState();
    _themeSwapController = AnimationController(
      vsync: this,
      duration: _themeSwapDuration,
    );
    _inlineMessageController = AnimationController(
      vsync: this,
      duration: _themeSwapDuration,
    );
  }

  @override
  void dispose() {
    _lockToastTimer?.cancel();
    _inlineMessageTimer?.cancel();
    _inlineMessageController.dispose();
    _themeSwapController.dispose();
    super.dispose();
  }

  void _showLockToast() {
    controller.playUiFeedback(
      sound: SoundCue.failure,
      haptic: HapticCue.failure,
    );
    _lockToastTimer?.cancel();
    setState(() {
      _lockToastMessage = 'Buy themes from shop';
    });
    _lockToastTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _lockToastMessage = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? activeMessage = widget.embeddedMessage ?? _lockToastMessage;
    return MazeTopPill(
      pillKey: const Key('bottom-nav-pill'),
      palette: palette,
      backgroundColor: Colors.transparent,
      showShadow: false,
      child: AnimatedSize(
        duration: MazeMotion.standard,
        curve: MazeMotion.enterCurve,
        alignment: Alignment.bottomCenter,
        child: activeMessage != null
            ? AnimatedSwitcher(
                duration: MazeMotion.standard,
                switchInCurve: MazeMotion.enterCurve,
                switchOutCurve: MazeMotion.exitCurve,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.16),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildEmbeddedMessage(activeMessage),
              )
            : _buildNavActions(),
      ),
    );
  }

  Widget _buildEmbeddedMessage(String message) {
    return SizedBox(
      key: const ValueKey<String>('bottom-nav-message'),
      height: MazeTopPill.buttonExtent,
      child: Center(
        child: Text(
          message,
          key: const Key('exit-toast'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.player,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildNavActions() {
    final List<Widget> primarySlots = _buildPrimarySlots(
      enabled: !_showThemeOptions,
      shouldAnimateTimeTrial: widget.isVisible && !_showThemeOptions,
    );
    final List<Widget?> themeSlots = _buildThemeSlots(
      enabled: _showThemeOptions,
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _themeSwapController,
        _inlineMessageController,
      ]),
      builder: (BuildContext context, _) {
        final bool interactionLocked =
            _themeSwapController.isAnimating ||
            _inlineMessageController.isAnimating ||
            _inlineMessage != null;
        final double outgoingPhase = _navSwapOutgoingPhase(
          _inlineMessageController.value,
        );
        final double incomingPhase = _navSwapIncomingPhase(
          _inlineMessageController.value,
        );

        return SizedBox(
          width: _navActionContentWidth,
          height: MazeTopPill.buttonExtent,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Opacity(
                opacity: 1 - outgoingPhase,
                child: Transform.translate(
                  offset: Offset(0, 6 * outgoingPhase),
                  child: Row(
                    key: const ValueKey<String>('bottom-nav-actions'),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IgnorePointer(
                        ignoring: interactionLocked,
                        child: MazeTopPillIconButton(
                          buttonKey: const Key('theme-toggle-button'),
                          onPressed: _toggleThemeOptions,
                          icon: Icons.palette_rounded,
                          color: palette.player,
                        ),
                      ),
                      for (
                        int index = 0;
                        index < primarySlots.length;
                        index++
                      ) ...<Widget>[
                        _buildDivider(),
                        IgnorePointer(
                          ignoring: interactionLocked,
                          child: _BottomNavAnimatedSlot(
                            progress: _themeSwapController.value,
                            primaryChild: primarySlots[index],
                            alternateChild: themeSlots[index],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_inlineMessage != null)
                Opacity(
                  opacity: incomingPhase,
                  child: Transform.translate(
                    offset: Offset(0, 6 * (1 - incomingPhase)),
                    child: _buildInlineMessage(_inlineMessage!),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInlineMessage(String message) {
    return SizedBox(
      key: const ValueKey<String>('bottom-nav-inline-message'),
      width: _navActionContentWidth,
      height: MazeTopPill.buttonExtent,
      child: Center(
        child: Text(
          message,
          key: const Key('time-trial-toast'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.player,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPrimarySlots({
    required bool enabled,
    required bool shouldAnimateTimeTrial,
  }) {
    final bool assistEnabled =
        controller.screen == AppScreen.menu || controller.canUseHint;
    final bool canToggleTimeTrial = controller.screen == AppScreen.playing;

    return <Widget>[
      MazeTopPillIconButton(
        buttonKey: const Key('shop-button'),
        onPressed: enabled ? controller.openShopOverlay : null,
        icon: Icons.shopping_cart_rounded,
        color: palette.player,
      ),
      MazeTopPillIconButton(
        buttonKey: const Key('points-button'),
        onPressed: enabled ? controller.openScoreOverlay : null,
        icon: Icons.emoji_events_rounded,
        color: palette.player,
      ),
      MazeTopPillIconButton.custom(
        buttonKey: const Key('time-trial-button'),
        onPressed: enabled && canToggleTimeTrial
            ? _handleTimeTrialToggle
            : null,
        color: palette.player,
        child: _TimeTrialButtonIcon(
          color: palette.player,
          isOn: controller.isTimeTrial,
          isInteractive: canToggleTimeTrial,
          shouldAnimate: shouldAnimateTimeTrial,
        ),
      ),
      MazeTopPillIconButton(
        buttonKey: const Key('assist-button'),
        onPressed: enabled && assistEnabled
            ? controller.handleAssistAction
            : null,
        icon: assistEnabled
            ? Icons.lightbulb_rounded
            : Icons.lightbulb_outline_rounded,
        color: palette.player,
      ),
      MazeTopPillIconButton(
        buttonKey: const Key('settings-button'),
        onPressed: enabled ? controller.openSettings : null,
        icon: Icons.menu_rounded,
        color: palette.player,
      ),
    ];
  }

  List<Widget?> _buildThemeSlots({required bool enabled}) {
    final List<Widget?> slots = List<Widget?>.filled(5, null);
    final List<ThemeId> themes = controller.availableThemes;

    for (int index = 0; index < themes.length && index < 4; index++) {
      final ThemeId theme = themes[index];
      final bool selected = controller.theme == theme;
      slots[index] = _ThemeChipButton(
        buttonKey: Key('theme-option-${theme.name}'),
        color: _themeChipColor(theme),
        borderColor: selected ? palette.grid : null,
        onTap: enabled ? () => controller.setTheme(theme) : null,
      );
    }

    for (int index = themes.length; index < 4; index++) {
      slots[index] = MazeTopPillIconButton(
        buttonKey: Key('theme-lock-$index'),
        onPressed: enabled ? () => _showLockToast() : null,
        icon: Icons.lock_rounded,
        color: palette.player,
      );
    }

    slots[4] = MazeTopPillIconButton(
      buttonKey: const Key('theme-dark-mode-button'),
      onPressed: enabled ? controller.toggleDarkMode : null,
      icon: controller.isDark
          ? Icons.light_mode_rounded
          : Icons.dark_mode_rounded,
      color: palette.player,
    );

    return slots;
  }

  Widget _buildDivider() {
    return MazeTopPillDivider(color: palette.player.withValues(alpha: 0.3));
  }

  void _toggleThemeOptions() {
    controller.playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    setState(() {
      _showThemeOptions = !_showThemeOptions;
    });
    if (_showThemeOptions) {
      _themeSwapController.forward();
    } else {
      _themeSwapController.reverse();
    }
  }

  void _handleTimeTrialToggle() {
    controller.toggleTimeTrial();
    _showInlineMessage('Time trial: ${controller.isTimeTrial ? 'ON' : 'OFF'}');
  }

  void _showInlineMessage(String message) {
    _inlineMessageTimer?.cancel();
    _inlineMessageCycle++;
    final int cycle = _inlineMessageCycle;

    if (!mounted) {
      return;
    }

    setState(() {
      _inlineMessage = message;
    });

    _inlineMessageTimer = Timer(_timeTrialToastDuration, () {
      if (!mounted || cycle != _inlineMessageCycle) {
        return;
      }
      unawaited(_hideInlineMessage(cycle));
    });
    _inlineMessageController.forward(from: 0);
  }

  Future<void> _hideInlineMessage(int cycle) async {
    await _inlineMessageController.reverse();
    if (!mounted || cycle != _inlineMessageCycle) {
      return;
    }
    setState(() {
      _inlineMessage = null;
    });
  }
}

class _BottomNavAnimatedSlot extends StatelessWidget {
  const _BottomNavAnimatedSlot({
    required this.progress,
    required this.primaryChild,
    required this.alternateChild,
  });

  final double progress;
  final Widget? primaryChild;
  final Widget? alternateChild;

  @override
  Widget build(BuildContext context) {
    final double outgoingPhase = _navSwapOutgoingPhase(progress);
    final double incomingPhase = _navSwapIncomingPhase(progress);

    return SizedBox(
      width: MazeTopPill.buttonExtent,
      height: MazeTopPill.buttonExtent,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (primaryChild != null)
            IgnorePointer(
              ignoring: progress != 0,
              child: Opacity(
                opacity: 1 - outgoingPhase,
                child: Transform.translate(
                  offset: Offset(0, 6 * outgoingPhase),
                  child: primaryChild,
                ),
              ),
            ),
          if (alternateChild != null)
            IgnorePointer(
              ignoring: progress != 1,
              child: Opacity(
                opacity: incomingPhase,
                child: Transform.translate(
                  offset: Offset(0, 6 * (1 - incomingPhase)),
                  child: alternateChild,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

double _navSwapOutgoingPhase(double progress) {
  return Curves.easeInCubic.transform((progress / 0.42).clamp(0.0, 1.0));
}

double _navSwapIncomingPhase(double progress) {
  return Curves.easeOutCubic.transform(
    ((progress - 0.58) / 0.42).clamp(0.0, 1.0),
  );
}

class _ThemeChipButton extends StatelessWidget {
  const _ThemeChipButton({
    required this.color,
    required this.onTap,
    this.buttonKey,
    this.borderColor,
  });

  final Color color;
  final VoidCallback? onTap;
  final Key? buttonKey;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return MazeTapScale(
      key: buttonKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: MazeTopPill.buttonExtent,
        height: MazeTopPill.buttonExtent,
        child: Center(
          child: AnimatedContainer(
            duration: MazeMotion.standard,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color.withValues(alpha: onTap == null ? 0.42 : 1),
              borderRadius: BorderRadius.circular(999),
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor!, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeTrialButtonIcon extends StatefulWidget {
  const _TimeTrialButtonIcon({
    required this.color,
    required this.isOn,
    required this.isInteractive,
    required this.shouldAnimate,
  });

  final Color color;
  final bool isOn;
  final bool isInteractive;
  final bool shouldAnimate;

  @override
  State<_TimeTrialButtonIcon> createState() => _TimeTrialButtonIconState();
}

class _TimeTrialButtonIconState extends State<_TimeTrialButtonIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _TimeTrialButtonIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animate =
        widget.isOn && widget.isInteractive && widget.shouldAnimate;
    final double alpha = widget.isInteractive
        ? 1
        : widget.isOn
        ? 0.72
        : 0.42;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final double progress = animate ? _controller.value : 0;
        final double rotationTurns = _hourglassTurnsFor(progress);
        final IconData icon = progress < 0.5
            ? Icons.hourglass_bottom_rounded
            : Icons.hourglass_top_rounded;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationZ(rotationTurns * 6.283185307179586),
          child: Icon(
            icon,
            size: MazeTopPill.iconSize,
            color: widget.color.withValues(alpha: alpha),
          ),
        );
      },
    );
  }

  void _syncAnimation() {
    if (widget.isOn && widget.isInteractive && widget.shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    _controller
      ..stop()
      ..value = 0;
  }
}

double _hourglassTurnsFor(double progress) {
  if (progress < 0.2) {
    return 0;
  }
  if (progress < 0.5) {
    final double phase = Curves.easeInOutCubic.transform(
      ((progress - 0.2) / 0.3).clamp(0.0, 1.0),
    );
    return phase * 0.5;
  }
  if (progress < 0.7) {
    return 0.5;
  }
  final double phase = Curves.easeInOutCubic.transform(
    ((progress - 0.7) / 0.3).clamp(0.0, 1.0),
  );
  return 0.5 + (phase * 0.5);
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

class _SurfaceMorphSpec {
  const _SurfaceMorphSpec({
    required this.fromRect,
    required this.toRect,
    required this.fromRadius,
    required this.toRadius,
    required this.fromShadowAlpha,
    required this.toShadowAlpha,
    required this.fromBackgroundAlpha,
    required this.toBackgroundAlpha,
  });

  const _SurfaceMorphSpec.menuToBoard({
    required Rect fromRect,
    required Rect toRect,
  }) : this(
         fromRect: fromRect,
         toRect: toRect,
         fromRadius: 28,
         toRadius: 0,
         fromShadowAlpha: 0,
         toShadowAlpha: 0.08,
         fromBackgroundAlpha: 0,
         toBackgroundAlpha: 1,
       );

  const _SurfaceMorphSpec.boardToMenu({
    required Rect fromRect,
    required Rect toRect,
  }) : this(
         fromRect: fromRect,
         toRect: toRect,
         fromRadius: 0,
         toRadius: 28,
         fromShadowAlpha: 0.08,
         toShadowAlpha: 0,
         fromBackgroundAlpha: 1,
         toBackgroundAlpha: 0,
       );

  final Rect fromRect;
  final Rect toRect;
  final double fromRadius;
  final double toRadius;
  final double fromShadowAlpha;
  final double toShadowAlpha;
  final double fromBackgroundAlpha;
  final double toBackgroundAlpha;
}

class _SurfaceMorph extends StatefulWidget {
  const _SurfaceMorph({
    required this.palette,
    required this.spec,
    required this.onComplete,
  });

  final MazePalette palette;
  final _SurfaceMorphSpec spec;
  final VoidCallback onComplete;

  @override
  State<_SurfaceMorph> createState() => _SurfaceMorphState();
}

class _SurfaceMorphState extends State<_SurfaceMorph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MazeMotion.surfaceMorph,
    )..forward();
    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double progress = Curves.easeInOutCubic.transform(
            _controller.value,
          );
          final Rect rect = Rect.lerp(
            widget.spec.fromRect,
            widget.spec.toRect,
            progress,
          )!;
          final double radius =
              lerpDouble(
                widget.spec.fromRadius,
                widget.spec.toRadius,
                progress,
              ) ??
              widget.spec.toRadius;
          final double shadowAlpha =
              lerpDouble(
                widget.spec.fromShadowAlpha,
                widget.spec.toShadowAlpha,
                progress,
              ) ??
              widget.spec.toShadowAlpha;
          final double backgroundAlpha =
              lerpDouble(
                widget.spec.fromBackgroundAlpha,
                widget.spec.toBackgroundAlpha,
                progress,
              ) ??
              widget.spec.toBackgroundAlpha;
          final double fadeProgress = ((progress - 0.72) / 0.28)
              .clamp(0.0, 1.0)
              .toDouble();
          final double opacity = 1 - Curves.easeIn.transform(fadeProgress);

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fromRect(
                rect: rect,
                child: Opacity(
                  opacity: opacity,
                  child: MazeSurfaceFrame(
                    key: const Key('surface-morph-frame'),
                    palette: widget.palette,
                    borderRadius: radius,
                    borderColor: widget.palette.uiBorder,
                    backgroundColor: widget.palette.mazeBg.withValues(
                      alpha: backgroundAlpha,
                    ),
                    shadowAlpha: shadowAlpha,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}



class _TopToast extends StatelessWidget {
  const _TopToast({
    required this.palette,
    required this.visible,
    required this.message,
    required this.toastKey,
  });

  final MazePalette palette;
  final bool visible;
  final String message;
  final Key toastKey;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: MazeMotion.standard,
        switchInCurve: MazeMotion.enterCurve,
        switchOutCurve: MazeMotion.exitCurve,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.45),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: visible
            ? ConstrainedBox(
                key: ValueKey<String>('top-toast-visible-$message'),
                constraints: const BoxConstraints(maxWidth: 320),
                child: DecoratedBox(
                  key: toastKey,
                  decoration: BoxDecoration(
                    color: palette.uiBg,
                    border: Border.all(color: palette.player, width: 2),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.player,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(
                key: ValueKey<String>('top-toast-empty'),
                height: 0,
              ),
      ),
    );
  }
}

class _BottomToast extends StatelessWidget {
  const _BottomToast({
    required this.palette,
    required this.visible,
    required this.message,
    required this.toastKey,
  });

  final MazePalette palette;
  final bool visible;
  final String message;
  final Key toastKey;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: MazeMotion.standard,
        switchInCurve: MazeMotion.enterCurve,
        switchOutCurve: MazeMotion.exitCurve,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.45),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: visible
            ? ConstrainedBox(
                key: ValueKey<String>('toast-visible-$message'),
                constraints: const BoxConstraints(maxWidth: 360),
                child: DecoratedBox(
                  key: toastKey,
                  decoration: BoxDecoration(
                    color: palette.uiBg,
                    border: Border.all(color: palette.player, width: 2),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.player,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(key: ValueKey<String>('toast-empty'), height: 0),
      ),
    );
  }
}
