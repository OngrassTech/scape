import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_metadata.dart';
import 'app_update_checker.dart';
import 'app_update_models.dart';
import 'appearance_preferences.dart';
import 'feedback.dart';
import 'maze_logic.dart';
import 'models.dart';
import 'progress_preferences.dart';
import 'session_preferences.dart';
import 'update_release_launcher.dart';

enum TransientToastAnchor { top, overlay }

class GameSessionController extends ChangeNotifier {
  GameSessionController({
    MazeGenerator? generator,
    MazeSolver? solver,
    SlideEngine? slideEngine,
    FeedbackController? feedbackController,
    AppUpdateLookup? appUpdateLookup,
    UpdateReleaseLauncher? updateReleaseLauncher,
    AppearancePreferences? appearancePreferences,
    ProgressPreferences? progressPreferences,
    SessionPreferences? sessionPreferences,
    AppAppearance initialAppearance = AppAppearance.fallback,
    PlayerProgress initialProgress = PlayerProgress.fallback,
    SavedGameSession? initialSession,
  }) : _generator = generator ?? const MazeGenerator(),
       _solver = solver ?? const MazeSolver(),
       _slideEngine = slideEngine ?? const SlideEngine(),
       _feedback = feedbackController ?? AudioFeedbackController(),
       _appUpdateLookup = appUpdateLookup,
       _updateReleaseLauncher = updateReleaseLauncher ?? openUpdateReleaseUrl,
       _appearancePreferences = appearancePreferences,
       _progressPreferences = progressPreferences,
       _sessionPreferences = sessionPreferences,
       _theme = initialAppearance.theme,
       _isDark = initialAppearance.isDark {
    _restoreProgress(initialProgress);
    if (!_equippedThemes.contains(_theme)) {
      _theme = _firstEquippedTheme() ?? ThemeId.orange;
      unawaited(_persistAppearance());
    }
    if (!_ownedThemes.contains(_theme)) {
      _ownedThemes = Set<ThemeId>.unmodifiable(<ThemeId>{
        ..._ownedThemes,
        _theme,
      });
      _scheduleProgressPersist();
    }
    if (initialSession != null) {
      _restoreSession(initialSession);
    }
  }

  static const Duration _successDialogDelay = Duration(milliseconds: 700);
  static const Duration _hintRevealDelay = Duration(milliseconds: 300);
  static const Duration _hintVisibleDuration = Duration(milliseconds: 2000);
  static const Duration _hintClearDelay = Duration(milliseconds: 300);
  static const Duration _transientToastDuration = Duration(seconds: 2);

  final MazeGenerator _generator;
  final MazeSolver _solver;
  final SlideEngine _slideEngine;
  final FeedbackController _feedback;
  final AppUpdateLookup? _appUpdateLookup;
  final UpdateReleaseLauncher _updateReleaseLauncher;
  final AppearancePreferences? _appearancePreferences;
  final ProgressPreferences? _progressPreferences;
  final SessionPreferences? _sessionPreferences;

  AppScreen _screen = AppScreen.menu;
  Difficulty _difficulty = Difficulty.easy;
  ThemeId _theme;
  bool _isDark;
  SettingsPanelPage _settingsPage = SettingsPanelPage.options;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _hasManuallyDisabledHaptics = false;
  bool _hasShownManualHapticsEnableToast = false;
  bool _showSettings = false;
  bool _showHelp = false;
  bool _hasSavedGame = false;
  bool _isTimeTrial = false;
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _showLevelComplete = false;
  bool _isSuccessAnimating = false;
  bool _isHintActive = false;
  bool _hasUsedHint = false;
  bool _isCheckingForUpdates = false;
  int _points = 0;
  int _time = 0;
  int _successCycle = 0;
  int _boardVersion = 0;
  int _lastPointsEarned = 0;
  int _lastClearElapsedSeconds = 0;
  bool _lastClearWasNewBest = false;
  AppUpdateResult? _availableAppUpdate;
  String? _transientToastMessage;
  TransientToastAnchor? _transientToastAnchor;
  List<List<MazeCell>> _maze = const <List<MazeCell>>[];
  Position _playerPos = const Position(0, 0);
  Position _goalPos = const Position(0, 0);
  List<Position> _trail = const <Position>[];
  List<Position> _hintPath = const <Position>[];
  Set<ThemeId> _ownedThemes = const <ThemeId>{ThemeId.orange};
  Set<ThemeId> _equippedThemes = const <ThemeId>{ThemeId.orange};
  Map<Difficulty, int> _bestTimesByDifficulty = const <Difficulty, int>{};

  Timer? _ticker;
  Timer? _levelCompleteTimer;
  Timer? _hintRevealTimer;
  Timer? _hintHideTimer;
  Timer? _hintDeactivateTimer;
  Timer? _transientToastTimer;
  bool _sessionPersistQueued = false;
  bool _sessionPersistInFlight = false;
  bool _progressPersistQueued = false;
  bool _progressPersistInFlight = false;

  AppScreen get screen => _screen;
  Difficulty get difficulty => _difficulty;
  ThemeId get theme => _theme;
  bool get isDark => _isDark;
  SettingsPanelPage get settingsPage => _settingsPage;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get showSettings => _showSettings;
  bool get showHelp => _showHelp;
  bool get hasSavedGame => _hasSavedGame;
  bool get isTimeTrial => _isTimeTrial;
  bool get isPlaying => _isPlaying;
  bool get isGameOver => _isGameOver;
  bool get showLevelComplete => _showLevelComplete;
  bool get isSuccessAnimating => _isSuccessAnimating;
  bool get isHintActive => _isHintActive;
  bool get hasUsedHint => _hasUsedHint;
  bool get isCheckingForUpdates => _isCheckingForUpdates;
  int get points => _points;
  int get time => _time;
  int get successCycle => _successCycle;
  int get boardVersion => _boardVersion;
  int get lastPointsEarned => _lastPointsEarned;
  int get lastClearElapsedSeconds => _lastClearElapsedSeconds;
  bool get lastClearWasNewBest => _lastClearWasNewBest;
  AppUpdateResult? get availableAppUpdate => _availableAppUpdate;
  bool get hasAvailableUpdate =>
      _availableAppUpdate?.status == AppUpdateStatus.updateAvailable;
  String? get availableUpdateUrl =>
      hasAvailableUpdate ? _availableAppUpdate?.releaseUrl : null;
  String? get transientToastMessage => _transientToastMessage;
  TransientToastAnchor? get transientToastAnchor => _transientToastAnchor;
  List<List<MazeCell>> get maze => _maze;
  Position get playerPos => _playerPos;
  Position get goalPos => _goalPos;
  List<Position> get trail => _trail;
  List<Position> get hintPath => _hintPath;
  Set<ThemeId> get ownedThemes => Set<ThemeId>.unmodifiable(_ownedThemes);
  Set<ThemeId> get equippedThemes => Set<ThemeId>.unmodifiable(_equippedThemes);
  List<ThemeId> get availableThemes {
    final List<ThemeId> themes = <ThemeId>[];
    for (final ThemeId theme in shopThemeOrder) {
      if ((_equippedThemes.contains(theme) || theme == _theme) &&
          !themes.contains(theme)) {
        themes.add(theme);
      }
    }
    return List<ThemeId>.unmodifiable(themes);
  }

  bool get hasMaze => _maze.isNotEmpty;
  bool get canResume => _hasSavedGame && hasMaze;
  bool get canUseHint => hasMaze && !_hasUsedHint;
  bool get hasBlockingOverlay =>
      _showSettings || _showHelp || _showLevelComplete || _isGameOver;
  bool get showAssistButton => true;
  bool get showOptionsButton => true;
  bool get utilityButtonsEnabled => !hasBlockingOverlay;

  int? bestTimeForDifficulty(Difficulty difficulty) {
    return _bestTimesByDifficulty[difficulty];
  }

  bool isThemeOwned(ThemeId theme) {
    return _ownedThemes.contains(theme);
  }

  bool isThemeEquipped(ThemeId theme) {
    return _equippedThemes.contains(theme);
  }

  bool canAffordTheme(ThemeId theme) {
    return _points >= theme.shopCost;
  }

  void playUiFeedback({SoundCue? sound, HapticCue? haptic}) {
    if (sound != null && _soundEnabled) {
      unawaited(_feedback.playSound(sound));
    }
    if (haptic != null && _hapticsEnabled) {
      unawaited(_feedback.playHaptic(haptic));
    }
  }

  void setDifficulty(Difficulty difficulty) {
    if (_difficulty == difficulty) {
      return;
    }
    _difficulty = difficulty;
    _hasSavedGame = false;
    _hasUsedHint = false;
    _lastClearWasNewBest = false;
    _scheduleSessionPersist();
    notifyListeners();
  }

  void setTheme(ThemeId theme) {
    if (_theme == theme || !_equippedThemes.contains(theme)) {
      return;
    }
    _theme = theme;
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    unawaited(_persistAppearance());
    notifyListeners();
  }

  bool useTheme(ThemeId theme) {
    if (!_equippedThemes.contains(theme)) {
      return false;
    }
    if (_theme == theme) {
      notifyListeners();
      return true;
    }
    _theme = theme;
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    unawaited(_persistAppearance());
    notifyListeners();
    return true;
  }

  bool equipTheme(
    ThemeId theme, {
    bool withFeedback = true,
    bool notify = true,
  }) {
    if (!_ownedThemes.contains(theme)) {
      return false;
    }
    if (_equippedThemes.contains(theme)) {
      return true;
    }
    if (_equippedThemes.length >= maxEquippableThemes) {
      _showTransientToast('Only 4 themes equipable at once.');
      if (withFeedback) {
        playUiFeedback(sound: SoundCue.failure, haptic: HapticCue.failure);
      }
      return false;
    }

    _equippedThemes = Set<ThemeId>.unmodifiable(<ThemeId>{
      ..._equippedThemes,
      theme,
    });
    _scheduleProgressPersist();
    if (withFeedback) {
      playUiFeedback(sound: SoundCue.toggle, haptic: HapticCue.medium);
    }
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  bool unequipTheme(ThemeId theme) {
    if (!_equippedThemes.contains(theme)) {
      return false;
    }
    if (_equippedThemes.length <= 1) {
      _showTransientToast("Can't unequipe everything!");
      playUiFeedback(sound: SoundCue.failure, haptic: HapticCue.failure);
      return false;
    }

    final Set<ThemeId> nextEquippedThemes = _equippedThemes
        .where((ThemeId item) => item != theme)
        .toSet();
    _equippedThemes = Set<ThemeId>.unmodifiable(nextEquippedThemes);
    if (_theme == theme) {
      _theme = _firstEquippedTheme(from: nextEquippedThemes) ?? ThemeId.orange;
      unawaited(_persistAppearance());
    }
    _scheduleProgressPersist();
    playUiFeedback(sound: SoundCue.toggle, haptic: HapticCue.medium);
    notifyListeners();
    return true;
  }

  ThemeId? _firstEquippedTheme({Set<ThemeId>? from}) {
    final Set<ThemeId> source = from ?? _equippedThemes;
    for (final ThemeId theme in shopThemeOrder) {
      if (source.contains(theme)) {
        return theme;
      }
    }
    return null;
  }

  void toggleDarkMode() {
    _isDark = !_isDark;
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    unawaited(_persistAppearance());
    notifyListeners();
  }

  void toggleSound() {
    if (_soundEnabled) {
      playUiFeedback(sound: SoundCue.toggle);
      _soundEnabled = false;
      notifyListeners();
      return;
    }

    _soundEnabled = true;
    notifyListeners();
    playUiFeedback(sound: SoundCue.toggle);
  }

  void toggleHaptics() {
    final bool next = !_hapticsEnabled;
    _hapticsEnabled = next;
    if (!next) {
      _hasManuallyDisabledHaptics = true;
      notifyListeners();
      playUiFeedback(sound: SoundCue.toggle);
      return;
    }

    final bool shouldShowEnableToast =
        _hasManuallyDisabledHaptics && !_hasShownManualHapticsEnableToast;
    if (shouldShowEnableToast) {
      _hasShownManualHapticsEnableToast = true;
      _showTransientToast('Turn on all system haptics.');
    } else {
      notifyListeners();
    }
    if (next) {
      playUiFeedback(haptic: HapticCue.medium);
    }
    playUiFeedback(sound: SoundCue.toggle);
  }

  void openSettings() {
    _showSettings = true;
    _settingsPage = SettingsPanelPage.options;
    _restartTicker();
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  void openShopOverlay() {
    _showSettings = true;
    _settingsPage = SettingsPanelPage.shop;
    _restartTicker();
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  void closeSettings() {
    if (!_showSettings) {
      return;
    }
    _clearOverlayTransientToast(notify: false);
    _showSettings = false;
    _settingsPage = SettingsPanelPage.options;
    _restartTicker();
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  void showShop() {
    _settingsPage = SettingsPanelPage.shop;
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  void showScore() {
    _settingsPage = SettingsPanelPage.score;
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  void openScoreOverlay() {
    _showLevelComplete = false;
    _isGameOver = false;
    _showSettings = true;
    _settingsPage = SettingsPanelPage.score;
    _restartTicker();
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  void showSettingsHome() {
    if (_settingsPage == SettingsPanelPage.options) {
      return;
    }
    _settingsPage = SettingsPanelPage.options;
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  void openHelp() {
    _showHelp = true;
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  Future<void> checkForUpdates() async {
    if (_isCheckingForUpdates) {
      return;
    }

    _isCheckingForUpdates = true;
    _availableAppUpdate = null;
    notifyListeners();

    try {
      // Resolve the network lookup only when the user explicitly requests it.
      final AppUpdateLookup appUpdateLookup =
          _appUpdateLookup ?? fetchLatestGitHubRelease;
      final AppUpdateResult result = await appUpdateLookup(appReleaseVersion);
      if (result.status == AppUpdateStatus.updateAvailable) {
        _availableAppUpdate = result;
        _clearTransientToast(notify: false);
      } else {
        _availableAppUpdate = null;
        _showTransientToast(result.message);
      }
    } catch (_) {
      _availableAppUpdate = null;
      _showTransientToast('Update check failed.');
    } finally {
      _isCheckingForUpdates = false;
      notifyListeners();
    }
  }

  Future<void> openAvailableUpdate() async {
    final String? releaseUrl = availableUpdateUrl;
    if (releaseUrl == null || releaseUrl.trim().isEmpty) {
      return;
    }

    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    final bool opened = await _updateReleaseLauncher(releaseUrl);
    if (!opened) {
      _showTransientToast('Unable to open update page.');
    }
  }

  void closeHelp() {
    if (!_showHelp) {
      return;
    }
    _clearOverlayTransientToast(notify: false);
    _showHelp = false;
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    notifyListeners();
  }

  void dismissGameplayOverlay() {
    final bool hadOverlay = _showSettings || _showLevelComplete || _isGameOver;
    if (!hadOverlay) {
      return;
    }

    _clearOverlayTransientToast(notify: false);
    _showSettings = false;
    _settingsPage = SettingsPanelPage.options;
    _showLevelComplete = false;
    _isGameOver = false;
    _restartTicker();
    notifyListeners();
  }

  void handleAssistAction() {
    if (_screen == AppScreen.menu) {
      openHelp();
      return;
    }
    showHint();
  }

  void startNewGame() {
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    _clearTransientToast(notify: false);
    _startFreshMaze();
  }

  void resumeGame() {
    if (!canResume) {
      return;
    }
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    _clearTransientToast(notify: false);
    _screen = AppScreen.playing;
    _isPlaying = true;
    _restartTicker();
    notifyListeners();
  }

  void retryMaze() {
    if (!hasMaze) {
      return;
    }
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    _resetCurrentMaze();
  }

  void nextMaze() {
    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    _startFreshMaze();
  }

  void backToMenu({bool withFeedback = true, bool preserveResume = false}) {
    if (withFeedback) {
      playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.heavy);
    }
    _clearOverlayTransientToast(notify: false);
    _levelCompleteTimer?.cancel();
    _levelCompleteTimer = null;
    _screen = AppScreen.menu;
    _isPlaying = false;
    _isGameOver = false;
    _showLevelComplete = false;
    _isSuccessAnimating = false;
    _showSettings = false;
    _settingsPage = SettingsPanelPage.options;
    _showHelp = false;
    _hasSavedGame = preserveResume && hasMaze;
    _lastPointsEarned = 0;
    _lastClearElapsedSeconds = 0;
    _lastClearWasNewBest = false;
    _scheduleSessionPersist();
    _restartTicker();
    notifyListeners();
  }

  void toggleTimeTrial() {
    _isTimeTrial = !_isTimeTrial;
    playUiFeedback(sound: SoundCue.toggle, haptic: HapticCue.medium);

    if (hasMaze) {
      _playerPos = const Position(0, 0);
      _trail = const <Position>[Position(0, 0)];
      _time = _isTimeTrial ? _difficulty.config.timeLimitSeconds : 0;
      _boardVersion++;
      _isGameOver = false;
      _showLevelComplete = false;
      _isSuccessAnimating = false;
      _hasUsedHint = false;
      if (_screen == AppScreen.playing) {
        _hasSavedGame = true;
      }
      _clearHintState();
    } else {
      _time = _isTimeTrial ? _difficulty.config.timeLimitSeconds : 0;
    }

    _scheduleSessionPersist();
    _restartTicker();
    notifyListeners();
  }

  void move(int dx, int dy) {
    if (!_isPlaying || !hasMaze || _showLevelComplete || _isGameOver) {
      return;
    }

    final SlideResult result = _slideEngine.slide(
      _maze,
      _playerPos,
      dx,
      dy,
      _goalPos,
    );
    if (!result.moved) {
      return;
    }

    playUiFeedback(sound: SoundCue.move, haptic: HapticCue.heavy);
    _playerPos = result.position;
    _clearHintState(notify: false);
    _trail = _applyTrail(_trail, result.path);

    if (_playerPos == _goalPos) {
      _finishLevel();
      return;
    }

    _scheduleSessionPersist();
    notifyListeners();
  }

  void showHint() {
    if (!hasMaze ||
        _showLevelComplete ||
        _isGameOver ||
        _isHintActive ||
        _hasUsedHint) {
      return;
    }

    playUiFeedback(sound: SoundCue.swipe, haptic: HapticCue.medium);
    _cancelHintTimers();
    _hasUsedHint = true;
    _isHintActive = true;
    _hintPath = const <Position>[];
    _scheduleSessionPersist();
    notifyListeners();

    _hintRevealTimer = Timer(_hintRevealDelay, () {
      final List<Position> path = _solver.solve(_maze, _playerPos, _goalPos);
      _hintPath = path.take(15).toList(growable: false);
      notifyListeners();
    });

    _hintHideTimer = Timer(_hintRevealDelay + _hintVisibleDuration, () {
      _hintPath = const <Position>[];
      notifyListeners();
    });

    _hintDeactivateTimer = Timer(
      _hintRevealDelay + _hintVisibleDuration + _hintClearDelay,
      () {
        _isHintActive = false;
        notifyListeners();
      },
    );
  }

  void handleSystemBack() {
    if (_showHelp) {
      _clearOverlayTransientToast(notify: false);
      _showHelp = false;
      notifyListeners();
      return;
    }
    if (_showSettings) {
      _clearOverlayTransientToast(notify: false);
      _showSettings = false;
      _settingsPage = SettingsPanelPage.options;
      _restartTicker();
      notifyListeners();
      return;
    }
    if (_screen == AppScreen.playing) {
      backToMenu(
        withFeedback: false,
        preserveResume: _isPlaying && !_showLevelComplete && !_isGameOver,
      );
      return;
    }
  }

  String formatTime(int seconds) {
    final String minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final String remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  bool buyTheme(ThemeId theme) {
    if (theme.isDefaultOwned || _ownedThemes.contains(theme)) {
      return false;
    }

    if (!canAffordTheme(theme)) {
      _showTransientToast('Not enough points');
      playUiFeedback(sound: SoundCue.failure, haptic: HapticCue.failure);
      return false;
    }

    _points -= theme.shopCost;
    _ownedThemes = Set<ThemeId>.unmodifiable(<ThemeId>{..._ownedThemes, theme});
    _scheduleProgressPersist();
    playUiFeedback(sound: SoundCue.success, haptic: HapticCue.success);
    notifyListeners();
    return true;
  }

  List<Position> _applyTrail(List<Position> currentTrail, List<Position> path) {
    final List<Position> nextTrail = List<Position>.from(currentTrail);
    for (final Position position in path) {
      if (nextTrail.length > 1 && nextTrail[nextTrail.length - 2] == position) {
        nextTrail.removeLast();
        continue;
      }
      nextTrail.add(position);
    }
    return List<Position>.unmodifiable(nextTrail);
  }

  void _startFreshMaze() {
    final DifficultyConfig config = _difficulty.config;
    _maze = _generator.generate(config.width, config.height);
    _playerPos = const Position(0, 0);
    _goalPos = Position(config.width - 1, config.height - 1);
    _trail = const <Position>[Position(0, 0)];
    _time = _isTimeTrial ? config.timeLimitSeconds : 0;
    _boardVersion++;
    _screen = AppScreen.playing;
    _isPlaying = true;
    _isGameOver = false;
    _showLevelComplete = false;
    _isSuccessAnimating = false;
    _hasUsedHint = false;
    _showSettings = false;
    _settingsPage = SettingsPanelPage.options;
    _showHelp = false;
    _hasSavedGame = true;
    _lastPointsEarned = 0;
    _lastClearElapsedSeconds = 0;
    _lastClearWasNewBest = false;
    _clearHintState(notify: false);
    _levelCompleteTimer?.cancel();
    _scheduleSessionPersist();
    _restartTicker();
    notifyListeners();
  }

  void _resetCurrentMaze() {
    _playerPos = const Position(0, 0);
    _trail = const <Position>[Position(0, 0)];
    _time = _isTimeTrial ? _difficulty.config.timeLimitSeconds : 0;
    _boardVersion++;
    _isGameOver = false;
    _showLevelComplete = false;
    _isSuccessAnimating = false;
    _hasUsedHint = false;
    _isPlaying = true;
    _showSettings = false;
    _settingsPage = SettingsPanelPage.options;
    _showHelp = false;
    _hasSavedGame = true;
    _lastPointsEarned = 0;
    _lastClearElapsedSeconds = 0;
    _lastClearWasNewBest = false;
    _clearHintState(notify: false);
    _levelCompleteTimer?.cancel();
    _scheduleSessionPersist();
    _restartTicker();
    notifyListeners();
  }

  void _finishLevel() {
    final int elapsedSeconds = _elapsedSecondsForCurrentRun();
    final int earnedPoints = _pointsEarnedForCurrentRun();
    _lastClearElapsedSeconds = elapsedSeconds;
    _lastPointsEarned = earnedPoints;
    _lastClearWasNewBest = _recordBestTime(elapsedSeconds);
    if (earnedPoints > 0) {
      _points += earnedPoints;
    }
    _isPlaying = false;
    _hasSavedGame = false;
    _isSuccessAnimating = true;
    _successCycle++;
    _scheduleProgressPersist();
    _scheduleSessionPersist();
    _restartTicker();
    playUiFeedback(sound: SoundCue.success, haptic: HapticCue.success);
    notifyListeners();

    _levelCompleteTimer?.cancel();
    _levelCompleteTimer = Timer(_successDialogDelay, () {
      _showLevelComplete = true;
      notifyListeners();
    });
  }

  void _handleGameOver() {
    _isPlaying = false;
    _isGameOver = true;
    _hasSavedGame = false;
    _lastPointsEarned = 0;
    _lastClearWasNewBest = false;
    _scheduleSessionPersist();
    _restartTicker();
    playUiFeedback(sound: SoundCue.failure, haptic: HapticCue.failure);
    notifyListeners();
  }

  void _restartTicker() {
    _ticker?.cancel();
    if (!_isPlaying || _screen != AppScreen.playing || _showSettings) {
      return;
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isTimeTrial) {
        if (_time <= 1) {
          _time = 0;
          _handleGameOver();
          return;
        }
        _time -= 1;
      } else {
        _time += 1;
      }
      _scheduleSessionPersist();
      notifyListeners();
    });
  }

  void _cancelHintTimers() {
    _hintRevealTimer?.cancel();
    _hintHideTimer?.cancel();
    _hintDeactivateTimer?.cancel();
  }

  void _clearHintState({bool notify = true}) {
    _cancelHintTimers();
    _hintPath = const <Position>[];
    _isHintActive = false;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _persistAppearance() async {
    final AppearancePreferences? appearancePreferences = _appearancePreferences;
    if (appearancePreferences == null) {
      return;
    }

    try {
      await appearancePreferences.saveAppearance(
        AppAppearance(theme: _theme, isDark: _isDark),
      );
    } catch (_) {}
  }

  Future<void> persistSession() async {
    if (_sessionPreferences == null) {
      return;
    }

    _sessionPersistQueued = true;
    if (_sessionPersistInFlight) {
      return;
    }

    _sessionPersistInFlight = true;
    try {
      while (_sessionPersistQueued) {
        _sessionPersistQueued = false;
        final SessionPreferences sessionPreferences = _sessionPreferences;

        final SavedGameSession? snapshot = _snapshotSession();
        if (snapshot == null) {
          await sessionPreferences.clearSession();
        } else {
          await sessionPreferences.saveSession(snapshot);
        }
      }
    } catch (_) {
    } finally {
      _sessionPersistInFlight = false;
    }
  }

  Future<void> persistProgress() async {
    if (_progressPreferences == null) {
      return;
    }

    _progressPersistQueued = true;
    if (_progressPersistInFlight) {
      return;
    }

    _progressPersistInFlight = true;
    try {
      while (_progressPersistQueued) {
        _progressPersistQueued = false;
        await _progressPreferences.saveProgress(_snapshotProgress());
      }
    } catch (_) {
    } finally {
      _progressPersistInFlight = false;
    }
  }

  void _scheduleSessionPersist() {
    if (_sessionPreferences == null) {
      return;
    }
    unawaited(persistSession());
  }

  void _scheduleProgressPersist() {
    if (_progressPreferences == null) {
      return;
    }
    unawaited(persistProgress());
  }

  SavedGameSession? _snapshotSession() {
    if (!hasMaze ||
        (!_hasSavedGame && !_isPlaying) ||
        _showLevelComplete ||
        _isGameOver) {
      return null;
    }

    return SavedGameSession(
      difficulty: _difficulty,
      isTimeTrial: _isTimeTrial,
      time: _time,
      maze: _cloneMaze(_maze),
      playerPos: _playerPos,
      trail: List<Position>.unmodifiable(_trail),
      hintUsed: _hasUsedHint,
    );
  }

  void _restoreSession(SavedGameSession session) {
    if (session.maze.isEmpty || session.maze.first.isEmpty) {
      return;
    }

    final List<List<MazeCell>> maze = _cloneMaze(session.maze);
    final Position safePlayerPos = _positionWithinMaze(maze, session.playerPos)
        ? session.playerPos
        : const Position(0, 0);
    final List<Position> safeTrail = session.trail.isEmpty
        ? const <Position>[Position(0, 0)]
        : session.trail
              .where((Position position) => _positionWithinMaze(maze, position))
              .toList(growable: false);

    _difficulty = session.difficulty;
    _maze = maze;
    _playerPos = safePlayerPos;
    _goalPos = Position(maze.first.length - 1, maze.length - 1);
    _trail = List<Position>.unmodifiable(
      safeTrail.isEmpty ? const <Position>[Position(0, 0)] : safeTrail,
    );
    _hintPath = const <Position>[];
    _isHintActive = false;
    _hasUsedHint = session.hintUsed;
    _isTimeTrial = session.isTimeTrial;
    _time = session.time < 0 ? 0 : session.time;
    _screen = AppScreen.menu;
    _isPlaying = false;
    _isGameOver = false;
    _showLevelComplete = false;
    _isSuccessAnimating = false;
    _showSettings = false;
    _settingsPage = SettingsPanelPage.options;
    _showHelp = false;
    _hasSavedGame = true;
    _boardVersion = 1;
  }

  PlayerProgress _snapshotProgress() {
    return PlayerProgress(
      points: _points,
      ownedThemes: Set<ThemeId>.unmodifiable(_ownedThemes),
      equippedThemes: Set<ThemeId>.unmodifiable(_equippedThemes),
      bestTimesByDifficulty: Map<Difficulty, int>.unmodifiable(
        _bestTimesByDifficulty,
      ),
    );
  }

  void _restoreProgress(PlayerProgress progress) {
    _points = progress.points < 0 ? 0 : progress.points;
    _ownedThemes = Set<ThemeId>.unmodifiable(
      progress.ownedThemes.isEmpty
          ? <ThemeId>{ThemeId.orange}
          : <ThemeId>{ThemeId.orange, ...progress.ownedThemes},
    );
    final Set<ThemeId> normalizedEquippedThemes = <ThemeId>{};
    for (final ThemeId theme in shopThemeOrder) {
      if (normalizedEquippedThemes.length >= maxEquippableThemes) {
        break;
      }
      if (progress.equippedThemes.contains(theme) &&
          _ownedThemes.contains(theme)) {
        normalizedEquippedThemes.add(theme);
      }
    }
    _equippedThemes = Set<ThemeId>.unmodifiable(normalizedEquippedThemes);
    _bestTimesByDifficulty = Map<Difficulty, int>.unmodifiable(
      progress.bestTimesByDifficulty,
    );
  }

  int _elapsedSecondsForCurrentRun() {
    if (!_isTimeTrial) {
      return _time;
    }

    final int elapsed = _difficulty.config.timeLimitSeconds - _time;
    return elapsed < 0 ? 0 : elapsed;
  }

  int _pointsEarnedForCurrentRun() {
    switch (_difficulty) {
      case Difficulty.expert:
      case Difficulty.nightmare:
        return _isTimeTrial ? 2 : 1;
      case Difficulty.easy:
      case Difficulty.medium:
      case Difficulty.hard:
        return 0;
    }
  }

  bool _recordBestTime(int elapsedSeconds) {
    final int? previousBest = _bestTimesByDifficulty[_difficulty];
    if (previousBest != null && previousBest <= elapsedSeconds) {
      return false;
    }

    _bestTimesByDifficulty = Map<Difficulty, int>.unmodifiable(
      <Difficulty, int>{..._bestTimesByDifficulty, _difficulty: elapsedSeconds},
    );
    return true;
  }

  bool _positionWithinMaze(List<List<MazeCell>> maze, Position position) {
    return position.y >= 0 &&
        position.y < maze.length &&
        position.x >= 0 &&
        position.x < maze[position.y].length;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _levelCompleteTimer?.cancel();
    _cancelHintTimers();
    _transientToastTimer?.cancel();
    _feedback.dispose();
    super.dispose();
  }

  void _showTransientToast(String message) {
    _transientToastTimer?.cancel();
    _transientToastMessage = message;
    _transientToastAnchor = hasBlockingOverlay
        ? TransientToastAnchor.overlay
        : TransientToastAnchor.top;
    notifyListeners();
    _transientToastTimer = Timer(_transientToastDuration, () {
      _clearTransientToast();
    });
  }

  void _clearTransientToast({bool notify = true}) {
    _transientToastTimer?.cancel();
    _transientToastTimer = null;
    if (_transientToastMessage == null) {
      return;
    }
    _transientToastMessage = null;
    _transientToastAnchor = null;
    if (notify) {
      notifyListeners();
    }
  }

  void _clearOverlayTransientToast({bool notify = true}) {
    if (_transientToastAnchor != TransientToastAnchor.overlay) {
      return;
    }
    _clearTransientToast(notify: notify);
  }
}

List<List<MazeCell>> _cloneMaze(List<List<MazeCell>> maze) {
  return maze
      .map(
        (List<MazeCell> row) =>
            row.map((MazeCell cell) => cell.copy()).toList(growable: false),
      )
      .toList(growable: false);
}
