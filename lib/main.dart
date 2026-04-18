import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'models/quest.dart';
import 'pages/shop_page.dart';
import 'models/app_lang.dart';
import 'pages/quest_history_page.dart';
import 'services/medusa_service.dart';
import 'services/pushup_counter_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SideQuestApp());
}

/* ========================= SPLASH ========================= */

class SplashVideoScreen extends StatefulWidget {
  const SplashVideoScreen({super.key});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  VideoPlayerController? _c;
  String? _error;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.asset('assets/splash/splash.mp4');

      await c.initialize().timeout(const Duration(seconds: 5));
      if (!mounted) return;

      c
        ..setLooping(false)
        ..play();

      setState(() => _c = c);

      c.addListener(() {
        final v = c.value;
        if (v.hasError && _error == null) {
          setState(() => _error = v.errorDescription ?? 'Unknown video error');
        }
        if (!_navigated &&
            v.isInitialized &&
            v.duration != Duration.zero &&
            v.position >= v.duration) {
          _goNext();
        }
      });

      // Safety-Fallback: nach 3s weiter
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_navigated) _goNext();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _goNext() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SideQuestHome()),
    );
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _goNext,
        child: Center(
          child: _error != null
              ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Splash Video Error:\n$_error',
              textAlign: TextAlign.center,
            ),
          )
              : (_c == null
              ? const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain, // ✅ kein Crop
              child: SizedBox(
                width: _c!.value.size.width,
                height: _c!.value.size.height,
                child: VideoPlayer(_c!),
              ),
            ),
          )),
        ),
      ),
    );
  }
}

/* ========================= THEME / APP ========================= */

class SideQuestApp extends StatelessWidget {
  const SideQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF9B5DE5);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
    );
    return MaterialApp(
      title: 'SideQuest',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.cinzelTextTheme(base.textTheme).copyWith(
          bodyMedium: GoogleFonts.crimsonPro(
              color: const Color(0xFFE8D9B8), fontSize: 15, fontWeight: FontWeight.w300),
          bodySmall: GoogleFonts.crimsonPro(
              color: const Color(0xFF8A7A5A), fontSize: 13, fontStyle: FontStyle.italic),
        ),
      ),
      home: const SplashVideoScreen(),
    );
  }
}

/* ========================= HOME ========================= */

class SideQuestHome extends StatefulWidget {
  const SideQuestHome({super.key});

  @override
  State<SideQuestHome> createState() => _SideQuestHomeState();
}

class _SideQuestHomeState extends State<SideQuestHome>
    with WidgetsBindingObserver {
  final List<Quest> pinned = [];
  final List<Quest> completed = [];

  // HUD
  int gold = 0;

  // Skills
  int scholarPoints = 0;
  int athletePoints = 0;
  int adventurerPoints = 0;

  // App XP
  int appLevel = 1;
  double appXp = 0;
  double appXpNeeded = 60;

  bool _showCreator = false;

  // Cooldowns
  DateTime? _lastPushupAcceptAt;
  DateTime? _lastDailyClaimAt;

  // Daily
  static const int _dailyRewardGold = 5;
  static const Duration _dailyCooldown = Duration(hours: 24);

  // Shop flags
  bool _xpBarGreen = false;
  bool _destinyStyle = false;
  bool _destinyPurchased = false;

  // Sprache
  AppLang _lang = AppLang.de;

  // Pedometer
  StreamSubscription<StepCount>? _stepSub;
  int? _lastDeviceStep;

  // Timer
  Timer? _tickTimer;
  Timer? _midnightTimer;

  //Pushup Sensor Counter
  PushupCounterService? _pushupCounter;
  StreamSubscription<int>? _pushupSub;
  bool _pushupCounting = false;
  String? _pushupQuestIdRunning; // ✅ welche Pushup-Quest zählt gerade?

  //Save and Load
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('gold', gold);
    prefs.setInt('appLevel', appLevel);
    prefs.setDouble('appXp', appXp);
    prefs.setDouble('appXpNeeded', appXpNeeded);
    prefs.setInt('scholarPoints', scholarPoints);
    prefs.setInt('athletePoints', athletePoints);
    prefs.setInt('adventurerPoints', adventurerPoints);
    prefs.setBool('xpBarGreen', _xpBarGreen);
    prefs.setBool('destinyStyle', _destinyStyle);
    prefs.setBool('destinyPurchased', _destinyPurchased);
    prefs.setInt('lang', _lang.index);
    if (_lastPushupAcceptAt != null) {
      prefs.setInt('lastPushupAcceptAt', _lastPushupAcceptAt!.millisecondsSinceEpoch);
    }
    if (_lastDailyClaimAt != null) {
      prefs.setInt('lastDailyClaimAt', _lastDailyClaimAt!.millisecondsSinceEpoch);
    }
    // Quests speichern
    final pinnedJson = pinned.map((q) => jsonEncode(q.toJson())).toList();
    final completedJson = completed.map((q) => jsonEncode(q.toJson())).toList();
    prefs.setStringList('pinned', pinnedJson);
    prefs.setStringList('completed', completedJson);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      gold = prefs.getInt('gold') ?? 0;
      appLevel = prefs.getInt('appLevel') ?? 1;
      appXp = prefs.getDouble('appXp') ?? 0.0;
      appXpNeeded = prefs.getDouble('appXpNeeded') ?? 60.0;
      scholarPoints = prefs.getInt('scholarPoints') ?? 0;
      athletePoints = prefs.getInt('athletePoints') ?? 0;
      adventurerPoints = prefs.getInt('adventurerPoints') ?? 0;
      _xpBarGreen = prefs.getBool('xpBarGreen') ?? false;
      _destinyStyle = prefs.getBool('destinyStyle') ?? false;
      _destinyPurchased = prefs.getBool('destinyPurchased') ?? false;
      final langIndex = prefs.getInt('lang') ?? 0;
      _lang = AppLang.values[langIndex];
      final pushupMs = prefs.getInt('lastPushupAcceptAt');
      if (pushupMs != null) {
        _lastPushupAcceptAt = DateTime.fromMillisecondsSinceEpoch(pushupMs);
      }
      final dailyMs = prefs.getInt('lastDailyClaimAt');
      if (dailyMs != null) {
        _lastDailyClaimAt = DateTime.fromMillisecondsSinceEpoch(dailyMs);
      }
      // Quests laden
      final pinnedRaw = prefs.getStringList('pinned') ?? [];
      final completedRaw = prefs.getStringList('completed') ?? [];
      pinned.clear();
      completed.clear();
      pinned.addAll(pinnedRaw.map((s) => Quest.fromJson(jsonDecode(s))));
      completed.addAll(completedRaw.map((s) => Quest.fromJson(jsonDecode(s))));
      // Nach den pinned/completed addAll Zeilen:
      print('Loaded pinned: ${pinned.length} quests');
      print('Loaded completed: ${completed.length} quests');
    });
  }

  //Push up Sensor
  Future<void> _startPushupSensorForQuest(Quest q) async {
    final now = DateTime.now();

    // Guards
    if (q.type != QuestType.pushups) return;
    if (q.unlockAt != null && now.isBefore(q.unlockAt!)) return;
    if (q.done) return;

    // ✅ Wenn schon ein anderer Pushup läuft -> erst den stoppen
    if (_pushupCounting && _pushupQuestIdRunning != q.id) {
      _stopPushupSensor();
    }
    if (_pushupCounting && _pushupQuestIdRunning == q.id) return;

    _pushupCounter ??= PushupCounterService();
    _pushupSub?.cancel();

    await _pushupCounter!.start();
    await WakelockPlus.enable();


    setState(() {
      _pushupCounting = true;
      _pushupQuestIdRunning = q.id; // ✅ bind to this quest
    });

    int lastTotal = 0;

    _pushupSub = _pushupCounter!.repsStream.listen((total) {
      if (!mounted) return;

      // ✅ Falls Quest gewechselt/gestoppt: ignorieren
      if (!_pushupCounting || _pushupQuestIdRunning != q.id) return;

      final delta = total - lastTotal;
      if (delta <= 0) return;
      lastTotal = total;

      _addReps(q, delta);
    });

    _toast(_lang == AppLang.de
        ? '📳 Push-up Sensor gestartet'
        : '📳 Push-up sensor started');
  }

  void _stopPushupSensor({bool silent = false}) {
    WakelockPlus.disable();
    final wasRunning = _pushupCounting;

    _pushupSub?.cancel();
    _pushupSub = null;
    _pushupCounter?.stop();

    if (mounted) {
      setState(() {
        _pushupCounting = false;
        _pushupQuestIdRunning = null;
      });
    } else {
      _pushupCounting = false;
      _pushupQuestIdRunning = null;
    }

    // ✅ nur toasten, wenn er wirklich lief UND nicht silent
    if (!silent && wasRunning) {
      _toast(_lang == AppLang.de
          ? '🛑 Push-up Sensor gestoppt'
          : '🛑 Push-up sensor stopped');
    }
  }

  // Medusa-Startsteuerung (Dialog wartet auf Display-Off)
  bool _awaitingMedusaArm = false;
  bool _medusaDialogOpen = false;
  bool _popMedusaDialogOnResume = false;

  // ✅ Adventure-Startsteuerung (nur für Adventure + Hunt!)
  bool _awaitingAdventureArm = false;
  bool _adventureArmDialogOpen = false;
  bool _popAdventureDialogOnResume = false;

  bool _pendingAdventureHunt = false;
  DateTime? _pendingAdventureDayKey;

  bool _lastArmedAdventureHadHunt = false;

  // 🔥 GLOBAL SWIPE DETECTOR (läuft “über” der ListView, ohne Scroll zu killen)
  double? _swipeDownY;
  int? _swipeDownMs;
  bool _historyOpenLock = false;

  void _openHistory() {
    if (_historyOpenLock) return;
    _historyOpenLock = true;

    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => QuestHistoryPage(
        completedQuests: completed,
        lang: _lang,
      ),
    ))
        .then((_) {
      // minimaler Lock, damit es nicht 2x öffnet
      Future.delayed(const Duration(milliseconds: 150), () {
        _historyOpenLock = false;
      });
    });
  }

  void _handleGlobalSwipe(PointerDownEvent e) {
    _swipeDownY = e.position.dy;
    _swipeDownMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _handleGlobalSwipeEnd(PointerUpEvent e) {
    if (_swipeDownY == null || _swipeDownMs == null) return;

    final dy = e.position.dy - _swipeDownY!;
    final dtMs = max(1, DateTime.now().millisecondsSinceEpoch - _swipeDownMs!);
    final vy = (dy / dtMs) * 1000.0; // px/s

    // Swipe UP: dy negativ
    final isSwipeUp = dy < -120 && vy < -800;
    if (isSwipeUp) _openHistory();

    _swipeDownY = null;
    _swipeDownMs = null;
  }

  /* ---------- Übersetzungen ---------- */

  String tr(String key) {
    final m = <String, Map<AppLang, String>>{
      'sidequest': {AppLang.de: '📜 SideQuest', AppLang.en: '📜 SideQuest'},
      'newQuest': {AppLang.de: 'Neue Quest', AppLang.en: 'New Quest'},
      'skills': {AppLang.de: 'Fähigkeiten', AppLang.en: 'Skills'},
      'dailyQuest': {AppLang.de: 'Daily Quest', AppLang.en: 'Daily Quest'},
      'dailyIn': {AppLang.de: 'in', AppLang.en: 'in'},
      'selectQuest': {
        AppLang.de: 'Quest auswählen',
        AppLang.en: 'Choose a quest'
      },
      'bookReading': {
        AppLang.de: '📘 Buch lesen',
        AppLang.en: '📘 Read a Book'
      },
      'pushups': {AppLang.de: '💪 Liegestütze', AppLang.en: '💪 Push-ups'},
      'adventure': {AppLang.de: '⛰️ Abenteuer', AppLang.en: '⛰️ Adventure'},
      'medusa': {AppLang.de: '👁️ Medusa', AppLang.en: '👁️ Medusa'},
      'adventureDesc': {
        AppLang.de: 'Gehe 10.000 Schritte in 12 Stunden (Reset um 00:00).',
        AppLang.en: 'Walk 10,000 steps in 12 hours (resets at midnight).'
      },
      'startAdventure': {
        AppLang.de: 'Abenteuer starten',
        AppLang.en: 'Start adventure'
      },
      'alreadyStartedToday': {
        AppLang.de: 'Heute bereits ein Abenteuer gestartet.',
        AppLang.en: 'You already started an adventure today.'
      },
      'alreadyDone': {
        AppLang.de: 'Schon erledigt für heute.',
        AppLang.en: 'Already claimed for today.'
      },
      'remaining': {AppLang.de: 'Noch', AppLang.en: 'Remaining'},
      'pinned': {AppLang.de: 'Angepinnt', AppLang.en: 'Pinned'},
      'nonePinned': {
        AppLang.de: 'Noch keine Quests.',
        AppLang.en: 'No quests yet.'
      },
      'completed': {AppLang.de: 'Abgeschlossen', AppLang.en: 'Completed'},
      'noneCompleted': {
        AppLang.de: 'Noch nichts abgeschlossen',
        AppLang.en: 'Nothing completed yet'
      },
      'shop': {AppLang.de: 'Shop', AppLang.en: 'Shop'},
      'yourLevel': {AppLang.de: 'Erfahrungspunkte', AppLang.en: 'Experience'},
      'aboutLine': {
        AppLang.de: '2025 by Kornelius E. Thelen',
        AppLang.en: '2025 by Kornelius E. Thelen'
      },
      'watchVideo': {
        AppLang.de:
        'Schau das 30-Sekunden-Video bis zum Ende, um Gold zu erhalten.',
        AppLang.en: 'Watch the 30-second video to the end to earn gold.'
      },
      'start': {AppLang.de: 'Start', AppLang.en: 'Start'},
      'bookTitleOptional': {
        AppLang.de: 'Buchtitel (optional)',
        AppLang.en: 'Book title (optional)'
      },
      'pagesCount': {AppLang.de: 'Anzahl Seiten', AppLang.en: 'Total pages'},
      'acceptQuest': {
        AppLang.de: 'Quest annehmen',
        AppLang.en: 'Accept quest'
      },
      'cancel': {AppLang.de: 'Abbrechen', AppLang.en: 'Cancel'},
      'pushupIntro': {
        AppLang.de:
        'Du startest mit 10 Wiederholungen (Level 1).\nJedes abgeschlossene Level zählt als eigene Quest und schaltet automatisch das nächste Level frei (20, 30, …, 1000).\n\nHinweis: Nur 1× alle 24 Stunden annehmbar.',
        AppLang.en:
        'You start with 10 reps (Level 1).\nEach completed level counts as its own quest and unlocks the next (20, 30, …, 1000).\n\nNote: Only once every 24 hours.'
      },
      'startQuest': {AppLang.de: 'Quest starten', AppLang.en: 'Start quest'},
      'phewRest': {
        AppLang.de: 'Puh, auch Helden brauchen Erholung',
        AppLang.en: 'Phew, even heroes need rest'
      },
      'lockedIn': {AppLang.de: '🔒 in', AppLang.en: '🔒 in'},
      'pages': {AppLang.de: 'Seiten', AppLang.en: 'pages'},
      'reps': {AppLang.de: 'Reps', AppLang.en: 'reps'},
      'plus10pages': {AppLang.de: '+10 Seiten', AppLang.en: '+10 pages'},
      'plus5reps': {AppLang.de: '+5 Reps', AppLang.en: '+5 reps'},
      'dailyRewardToast': {
        AppLang.de: 'Daily-Belohnung: +',
        AppLang.en: 'Daily reward: +'
      },
      'gold': {AppLang.de: ' Gold', AppLang.en: ' gold'},
      'greenXpTitle': {AppLang.de: 'Green XP Bar', AppLang.en: 'Green XP Bar'},
      'destinyTitle': {AppLang.de: 'Destiny Style', AppLang.en: 'Destiny Style'},
      'buy': {AppLang.de: 'Kaufen', AppLang.en: 'Buy'},
      'on': {AppLang.de: 'An', AppLang.en: 'On'},
      'off': {AppLang.de: 'Aus', AppLang.en: 'Off'},
      'boughtXpToast': {
        AppLang.de: 'Gekauft! XP-Balken ist jetzt grün (−10 Gold)',
        AppLang.en: 'Purchased! XP bar is now green (−10 gold)'
      },
      'activatedToast': {
        AppLang.de: 'Destiny Style aktiviert!',
        AppLang.en: 'Destiny style activated!'
      },
      'deactivatedToast': {
        AppLang.de: 'Destiny Style deaktiviert.',
        AppLang.en: 'Destiny style deactivated.'
      },
      'support': {AppLang.de: 'Support', AppLang.en: 'Support'},
      'subject': {AppLang.de: 'Betreff', AppLang.en: 'Subject'},
      'message': {AppLang.de: 'Nachricht', AppLang.en: 'Message'},
      'send': {AppLang.de: 'Absenden', AppLang.en: 'Send'},
      'emailError': {
        AppLang.de: 'Konnte Mail-App nicht öffnen.',
        AppLang.en: 'Could not open mail app.'
      },
      'thanks': {
        AppLang.de: 'Danke! Entwurf in deiner Mail-App geöffnet.',
        AppLang.en: 'Thanks! Draft opened in your mail app.'
      },
      'medusaInfoTitle': {AppLang.de: '👁️ Medusa', AppLang.en: '👁️ Medusa'},
      'medusaInfoBody': {
        AppLang.de:
        'Die Quest startet, sobald du jetzt den Bildschirm ausschaltest (Power-Taste). Kehre nicht vor Ablauf von 4 Stunden zurück – sonst scheiterst du.',
        AppLang.en:
        'The quest starts as soon as you now turn the screen off (power button). Do not return before 4 hours pass—or you fail.'
      },
      'medusaWaiting': {
        AppLang.de: 'Warte auf Bildschirm AUS…',
        AppLang.en: 'Waiting for screen OFF…'
      },
      'medusaArmedToast': {
        AppLang.de: '✅ Medusa gestartet. 4 Std. fernbleiben.',
        AppLang.en: '✅ Medusa started. Stay away for 4 hours.'
      },
      'medusaFailed': {
        AppLang.de: '❌ Medusa fehlgeschlagen (zu früh zurück).',
        AppLang.en: '❌ Medusa failed (returned too early).'
      },
      'medusaSuccess': {
        AppLang.de: '✅ Medusa bestanden! (+1 Gold)',
        AppLang.en: '✅ Medusa completed! (+1 gold)'
      },
      'timeLeft': {AppLang.de: 'Verbleibend', AppLang.en: 'Remaining'},
      'devCheat': {AppLang.de: 'DEV: +100 Gold', AppLang.en: 'DEV: +100 gold'},

      // ✅ New
      'huntLine': {
        AppLang.de:
        'Jage auf diesem Abenteuer nach der Medusa und erhalte eine besondere Belohnung (+25 Gold).',
        AppLang.en:
        'Hunt the Medusa during this adventure and earn a special reward (+25 gold).'
      },
      'huntBadge': {AppLang.de: '🐍 Medusa Hunt', AppLang.en: '🐍 Medusa Hunt'},
      'failedLabel': {AppLang.de: 'Fehlgeschlagen', AppLang.en: 'Failed'},
      'completedLabel': {AppLang.de: 'Abgeschlossen', AppLang.en: 'Completed'},
      'bonusEarned': {AppLang.de: 'Bonus verdient', AppLang.en: 'Bonus earned'},
    };
    return m[key]?[_lang] ?? key;
  }

  /* ---------- Theme helpers ---------- */

  Color get _bgColor =>
      _destinyStyle ? const Color(0xFF0B1021) : const Color(0xFF0A0805);
  Color get _surfaceColor =>
      _destinyStyle ? const Color(0xFF151B37) : const Color(0xFF0A0805);
  Color get _paperColor =>
      _destinyStyle ? const Color(0xFF1C2447) : const Color(0xFF1C1610);
  Color get _paperBorder =>
      _destinyStyle ? const Color(0xFF2B3A73) : const Color(0xFF2A1E0E);
  Color get _outlineTopBar =>
      _destinyStyle ? const Color(0xFF2B3A73) : const Color(0xFF1A1208);

  Color get _xpBarColor => _xpBarGreen
      ? Colors.green
      : (_destinyStyle ? const Color(0xFF00D1FF) : const Color(0xFFFFD86B));

  /* ---------- Lifecycle ---------- */

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _ensureActivityPermission().then((_) {
      _subscribePedometer();
    });
    _startTick();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepSub?.cancel();
    _tickTimer?.cancel();
    _midnightTimer?.cancel();

    _stopPushupSensor(silent: true);
    _pushupCounter?.dispose(); // stream controller schließen
    _pushupCounter = null;
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ FIRST: handle background/screen-off transitions
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopPushupSensor(silent: true); // ✅ kein Spam beim Screen-off / background
      _onScreenOffWhileMaybeArmingMedusa(); // arm Medusa / Adventure(+Hunt)
      return;
    }

    // ✅ THEN: handle resume
    if (state == AppLifecycleState.resumed) {
      // Pop Medusa dialog if needed
      if (_popMedusaDialogOnResume && _medusaDialogOpen && mounted) {
        _popMedusaDialogOnResume = false;
        _medusaDialogOpen = false;
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }

      // Pop Adventure dialog if needed
      if (_popAdventureDialogOnResume && _adventureArmDialogOpen && mounted) {
        _popAdventureDialogOnResume = false;
        _adventureArmDialogOpen = false;
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();

        _toast(_lang == AppLang.de
            ? '✅ Abenteuer gestartet${_lastArmedAdventureHadHunt ? ' + 🐍 Medusa Hunt' : ''}.'
            : '✅ Adventure started${_lastArmedAdventureHadHunt ? ' + 🐍 Medusa Hunt' : ''}.');
      }

      // ✅ Hardcore: Hunt early return => fail
      final failedHardcore = MedusaService.failHardcoreHuntIfResumedTooEarly(
        pinned: pinned,
        completed: completed,
        failQuest: (Quest q, {String? reason}) {
          setState(() {
            q.failed = true;
            q.failReason = reason;
            q.done = true;
            q.finishedAt = DateTime.now();
            pinned.removeWhere((e) => e.id == q.id);
            completed.insert(0, q);
          });
          return q;
        },
        failAdventure: (Quest q, {String? reason}) {
          setState(() {
            q.failed = true;
            q.failReason = reason;
            q.done = true;
            q.finishedAt = DateTime.now();
            pinned.removeWhere((e) => e.id == q.id);
            completed.insert(0, q);
          });
          return q;
        },
      );

      if (failedHardcore) {
        _toast(_lang == AppLang.de
            ? '❌ Medusa Hunt fehlgeschlagen (zu früh zurück).'
            : '❌ Medusa Hunt failed (returned too early).');
        return;
      }

      // ✅ Classic Medusa check
      _evaluateMedusaOnResumeNEW();
    }
  }

  void _evaluateMedusaOnResumeNEW() {
    final result = MedusaService.evaluateClassicMedusaOnResume(
      pinned: pinned,
      completed: completed,
      failQuest: (Quest q) {
        setState(() {
          q.failed = true;
          q.failReason = 'returned_early';
          q.done = true;
          q.finishedAt = DateTime.now();
          pinned.removeWhere((e) => e.id == q.id);
          completed.insert(0, q);
        });
        return q;
      },
      finishQuest: (Quest q) {
        setState(() {
          _gainAppXp(15);
          q.done = true;
          q.finishedAt = DateTime.now();
          pinned.removeWhere((e) => e.id == q.id);
          completed.insert(0, q);
          gold += 1;
        });
        return q;
      },
    );

    if (result == "failed") _toast(tr('medusaFailed'));
    if (result == "success") _toast(tr('medusaSuccess'));
  }

  void _onScreenOffWhileMaybeArmingMedusa() {
    final now = DateTime.now();

    // 1) Classic Medusa arm
    if (_awaitingMedusaArm) {
      final end = now.add(const Duration(hours: 4));
      setState(() {
        pinned.add(Quest.medusa(
          name: _lang == AppLang.de ? 'Medusa' : 'Medusa',
          start: now,
          end: end,
          medusaArmed: true,
        ));
        _awaitingMedusaArm = false;
        _popMedusaDialogOnResume = true;
      });
      _saveData(); // NEU
      return;
    }

    // 2) Adventure (+ optional Hunt) arm
    if (_awaitingAdventureArm) {
      final endAdventure = now.add(_pendingAdventureHunt
          ? const Duration(hours: 4)   // ✅ Hardcore
          : const Duration(hours: 12));

      final key = _pendingAdventureDayKey ?? _todayKey();

      setState(() {
        _lastArmedAdventureHadHunt = _pendingAdventureHunt;

        final adventure = Quest.adventure(
          name: _lang == AppLang.de ? 'Abenteuer' : 'Adventure',
          target: 10000,
          start: now,
          end: endAdventure,
          dayOnly: key,
          baseline: _lastDeviceStep,
        );

        pinned.add(adventure);

        if (_pendingAdventureHunt) {
          pinned.add(MedusaService.createMedusaHunt(
            lang: _lang,
            adventureId: adventure.id,
            bonus: 25,
            // optional: durationHours: 4 (falls du das im Service anbietest)
          ));
        }

        _awaitingAdventureArm = false;
        _pendingAdventureHunt = false;
        _pendingAdventureDayKey = null;

        _popAdventureDialogOnResume = true;
      });

      return;
    }
  }

  Future<void> _ensureActivityPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        status = await Permission.activityRecognition.request();
      }
      if (!status.isGranted && mounted) {
        _toast('Bitte Bewegungsdaten erlauben, um Schritte zu zählen.');
      }
    }
  }

  void _subscribePedometer() {
    try {
      _stepSub = Pedometer.stepCountStream.listen((StepCount e) {
        _lastDeviceStep = e.steps;

        // ✅ Adventure Fortschritt (baseline-safe)
        for (final q in pinned.where((qq) => qq.type == QuestType.adventure && !qq.done)) {
          // baseline erst setzen, wenn wir wirklich Steps bekommen
          q.deviceBaseline ??= _lastDeviceStep;

          if (q.deviceBaseline != null) {
            final delta = max(0, (_lastDeviceStep ?? 0) - q.deviceBaseline!);
            if (q.stepsProgress != delta) {
              setState(() => q.stepsProgress = delta);
              _checkAdventureCompletion(q);
            }
          }
        }
      });
    } catch (_) {
      /* ignore */
    }
  }

  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      // ✅ Hunts prüfen (Fail bei Ablauf)
      final failed = MedusaService.checkExpiredHunts(
        pinned: pinned,
        completed: completed,
        reason: 'timeout',
      );

      if (failed > 0) {
        _toast(_lang == AppLang.de
            ? '❌ Medusa Hunt fehlgeschlagen.'
            : '❌ Medusa Hunt failed.');
      }

      // ✅ Adventure Timeout -> fail
      final now = DateTime.now();
      final expiredAdventures = pinned
          .where((q) =>
      q.type == QuestType.adventure &&
          !q.done &&
          q.endAt != null &&
          now.isAfter(q.endAt!))
          .toList();

      for (final adv in expiredAdventures) {
        _failQuest(adv, reason: 'timeout');
        _toast(_lang == AppLang.de
            ? '❌ Abenteuer fehlgeschlagen (Zeit abgelaufen).'
            : '❌ Adventure failed (time expired).');
      }

      final hasActiveTimers =
      pinned.any((q) => (q.type == QuestType.adventure || q.type == QuestType.medusa) && !q.done);
      if (hasActiveTimers) setState(() {});
    });
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight =
    DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final dur = nextMidnight.difference(now);
    _midnightTimer = Timer(dur, () {
      setState(() {
        pinned.removeWhere((q) => q.type == QuestType.adventure && !q.done);
      });
      _scheduleMidnightReset();
    });
  }

  /* ---------- XP ---------- */

  void _gainAppXp(double amount) {
    setState(() {
      appXp += amount;
      while (appXp >= appXpNeeded && appLevel < 100) {
        appXp -= appXpNeeded;
        appLevel++;
        appXpNeeded = 60 + (appLevel - 1) * ((6000 - 60) / 99);
        _toast(_lang == AppLang.de
            ? 'Level Up! Dein Level: $appLevel'
            : 'Level up! Your level: $appLevel');
      }
      if (appLevel >= 100) {
        appLevel = 100;
        appXp = min(appXp, appXpNeeded);
      }
    });
    _saveData();
  }

  void _toast(String msg) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg, overflow: TextOverflow.ellipsis, maxLines: 2),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1400),
    ));
  }

  /* ---------- Helpers ---------- */

  int _repsNeededForLevel(int level) => min(1000, (level + 1) * 10);
  int _repsNeededForQuest(Quest q) => _repsNeededForLevel(q.level);

  String _pushupTitleForLevel(int level) => _lang == AppLang.de
      ? 'Liegestütze – ${_repsNeededForLevel(level)} Wiederholungen'
      : 'Push-ups – ${_repsNeededForLevel(level)} reps';

  String _fmtDurationClock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  DateTime _todayKey() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _hasAdventureToday() {
    final key = _todayKey();

    // ✅ wenn Adventure gerade "armed" wird -> zählt als "heute schon gestartet"
    if (_awaitingAdventureArm && _pendingAdventureDayKey == key) return true;

    return pinned.any((q) => q.type == QuestType.adventure && q.dayKey == key && !q.done) ||
        completed.any((q) => q.type == QuestType.adventure && q.dayKey == key);
  }

  Duration _remainingFrom(DateTime? last, Duration cool) {
    if (last == null) return Duration.zero;
    final next = last.add(cool);
    final now = DateTime.now();
    return now.isBefore(next) ? next.difference(now) : Duration.zero;
  }

  /* ---------- Quest logic ---------- */

  Future<void> _addReadingQuest(BuildContext ctx) async {
    final ctrlName = TextEditingController(text: '');
    final ctrlPages = TextEditingController(text: '800');

    final accepted = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(tr('bookReading'), softWrap: false),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                decoration: InputDecoration(labelText: tr('bookTitleOptional')),
                controller: ctrlName),
            TextField(
              decoration: InputDecoration(labelText: tr('pagesCount')),
              controller: ctrlPages,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('cancel'), softWrap: false)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('acceptQuest'), softWrap: false)),
        ],
      ),
    );

    if (accepted != true) return;
    final pages = max(1, min(100000, int.tryParse(ctrlPages.text.trim()) ?? 1));
    final entered = ctrlName.text.trim();

    if (!mounted) return;
    setState(() {
      pinned.add(Quest.reading(
        name: entered.isEmpty
            ? (_lang == AppLang.de ? 'Buch lesen' : 'Read a Book')
            : entered,
        totalPages: pages,
        readingUsesDefaultName: entered.isEmpty,
      ));
      _showCreator = false;
    });
    _saveData(); // NEU
  }

  Future<void> _addPushupQuest(BuildContext ctx) async {
    final now = DateTime.now();
    final remaining = _remainingFrom(_lastPushupAcceptAt, const Duration(hours: 24));
    if (remaining > Duration.zero) {
      _toast(tr('phewRest'));
      return;
    }

    final accepted = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(tr('pushups'), softWrap: false),
        content: Text(tr('pushupIntro')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr('cancel'), softWrap: false)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('startQuest'), softWrap: false)),
        ],
      ),
    );

    if (accepted != true) return;

    if (!mounted) return;
    setState(() {
      pinned.add(Quest.pushups(name: _pushupTitleForLevel(0), startLevel: 0, unlockAt: now));
      _lastPushupAcceptAt = now;
      _showCreator = false;
    });
    _saveData(); // NEU
  }

  // ✅ FIXED: Adventure ohne Hunt startet normal, nur Hunt verlangt Screen-Off
  Future<void> _addAdventureQuest(BuildContext ctx) async {
    if (_hasAdventureToday()) {
      _toast(tr('alreadyStartedToday'));
      return;
    }

    if (Platform.isAndroid) {
      final granted = await Permission.activityRecognition.isGranted ||
          (await Permission.activityRecognition.request()).isGranted;
      if (!granted) {
        _toast('Bitte Bewegungsdaten erlauben, um Schritte zu zählen.');
        return;
      }
    }

    bool huntMedusa = true;

    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: ctx,
      builder: (c) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('adventure'), softWrap: false),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('adventureDesc')),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(tr('huntLine'))),
                    const SizedBox(width: 8),
                    Switch(
                      value: huntMedusa,
                      onChanged: (v) => setLocal(() => huntMedusa = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr('cancel'), softWrap: false)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(tr('startAdventure'), softWrap: false)),
          ],
        ),
      ),
    );

    if (accepted != true) return;

    // ✅ Hunt: erst Screen-Off, dann Adventure+Hunt starten
    if (huntMedusa) {
      if (!mounted) return;
      setState(() => _showCreator = false);
      _openAdventureArmDialog(hunt: true);
      return;
    }

    // ✅ Ohne Hunt: normal sofort starten
    final now = DateTime.now();
    final end = now.add(const Duration(hours: 12));
    final key = _todayKey();

    if (!mounted) return;
    setState(() {
      final adventure = Quest.adventure(
        name: _lang == AppLang.de ? 'Abenteuer' : 'Adventure',
        target: 10000,
        start: now,
        end: end,
        dayOnly: key,
        baseline: _lastDeviceStep,
      );
      pinned.add(adventure);
      _showCreator = false;
    });_saveData(); // NEU

  }

  void _openMedusaInfoDialog() {
    if (MedusaService.activeClassicMedusaOrNull(pinned) != null) return;

    _awaitingMedusaArm = true;
    _medusaDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (c) => WillPopScope(
        onWillPop: () async {
          _awaitingMedusaArm = false;
          _medusaDialogOpen = false;
          return true;
        },
        child: AlertDialog(
          title: Text(tr('medusaInfoTitle'), softWrap: false),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('medusaInfoBody')),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(tr('medusaWaiting')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _awaitingMedusaArm = false;
                _medusaDialogOpen = false;
                Navigator.pop(c);
              },
              child: Text(tr('cancel'), softWrap: false),
            ),
          ],
        ),
      ),
    );
  }


  void _openAdventureArmDialog({required bool hunt}) {
    if (_awaitingAdventureArm) return;

    _awaitingAdventureArm = true;
    _adventureArmDialogOpen = true;
    _pendingAdventureHunt = hunt;
    _pendingAdventureDayKey = _todayKey();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (c) => WillPopScope(
        onWillPop: () async {
          _awaitingAdventureArm = false;
          _adventureArmDialogOpen = false;
          _pendingAdventureHunt = false;
          _pendingAdventureDayKey = null;
          return true;
        },
        child: AlertDialog(
          title: Text(
            hunt
                ? (_lang == AppLang.de
                ? '⛰️ Abenteuer + 🐍 Medusa Hunt'
                : '⛰️ Adventure + 🐍 Medusa Hunt')
                : (_lang == AppLang.de ? '⛰️ Abenteuer starten' : '⛰️ Start adventure'),
            softWrap: false,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hunt
                    ? (_lang == AppLang.de
                    ? 'Schalte jetzt den Bildschirm AUS (Power-Taste). Erst dann starten die Timer.\n\nMedusa Hunt: Lass das Display 4 Stunden aus.'
                    : 'Turn the screen OFF now (power button). Only then the timers start.\n\nMedusa Hunt: Keep the display off for 4 hours.')
                    : (_lang == AppLang.de
                    ? 'Schalte jetzt den Bildschirm AUS (Power-Taste).'
                    : 'Turn the screen OFF now (power button).'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(_lang == AppLang.de
                      ? 'Warte auf Bildschirm AUS…'
                      : 'Waiting for screen OFF…'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _awaitingAdventureArm = false;
                _adventureArmDialogOpen = false;
                _pendingAdventureHunt = false;
                _pendingAdventureDayKey = null;
                Navigator.pop(c);
              },
              child: Text(tr('cancel'), softWrap: false),
            ),
          ],
        ),
      ),
    );
  }

  void _finishQuest(Quest q, {bool giveGold = true}) {
    if (q.done) return;
    setState(() {
      q.done = true;
      q.finishedAt = DateTime.now();
      pinned.removeWhere((e) => e.id == q.id);
      completed.insert(0, q);
      if (giveGold) gold += 1;


    });
    if (giveGold) {
      _toast(_lang == AppLang.de
          ? '🎉 Quest erledigt: ${q.name} (+1${tr('gold')})'
          : '🎉 Quest completed: ${q.name} (+1${tr('gold')})');
    }
    _saveData(); // NEU
  }

  void _failQuest(Quest q, {String? reason}) {
    if (q.done) return;
    setState(() {
      q.failed = true;
      q.failReason = reason;
      q.done = true;
      q.finishedAt = DateTime.now();
      pinned.removeWhere((e) => e.id == q.id);
      completed.insert(0, q);
    });
  }

  void _addPages(Quest q, int add) {
    if (q.type != QuestType.reading || q.done) return;
    final total = q.totalPages!;
    setState(() => q.readPages = min(total, q.readPages + add));
    if (q.readPages >= total) {
      scholarPoints = min(100, scholarPoints + 1);
      _gainAppXp(15);
      _finishQuest(q);
      _saveData(); // explizit nochmal aufrufen
    }
  }

  void _addReps(Quest q, int reps) {
    if (q.type != QuestType.pushups || q.done) return;

    final now = DateTime.now();
    if (q.unlockAt != null && now.isBefore(q.unlockAt!)) {
      final remaining = q.unlockAt!.difference(now);
      _toast(_lang == AppLang.de
          ? 'Noch gesperrt: ${_fmtShort(remaining)}'
          : 'Locked: ${_fmtShort(remaining)}');
      return;
    }

    final needed = _repsNeededForQuest(q);
    setState(() => q.repsProgress = min(needed, q.repsProgress + reps));

    if (q.repsProgress >= needed) {
      _stopPushupSensor(); // ✅ stop immediately on completion

      athletePoints = min(100, athletePoints + 1);
      _gainAppXp(15);
      _toast(_lang == AppLang.de
          ? '💪 Level geschafft!'
          : '💪 Level cleared!');

      _finishQuest(q);
      _saveData();

      final nextLevel = q.level + 1;
      if (nextLevel < 100) {
        final nextUnlock = (_lastPushupAcceptAt ?? now).add(const Duration(hours: 24));
        setState(() {
          pinned.add(Quest.pushups(
            name: _pushupTitleForLevel(nextLevel),
            startLevel: nextLevel,
            unlockAt: nextUnlock,
          ));
        });
      } else {
        _toast(_lang == AppLang.de
            ? '💪 Maximales Liegestütze-Level erreicht!'
            : '💪 Max push-ups level reached!');
      }
    }
  }

  void _checkAdventureCompletion(Quest q) {
    if (q.type != QuestType.adventure || q.done) return;

    // baseline muss existieren
    if (q.deviceBaseline == null) return;

    final now = DateTime.now();
    if (q.endAt != null && now.isAfter(q.endAt!)) return;

    if (q.stepsProgress < q.stepsTarget) return;

    // ✅ AB HIER: completed
    adventurerPoints = min(100, adventurerPoints + 1);
    _gainAppXp(15);

    // Bonus nur wenn Adventure completed
    final int bonus = MedusaService.tryAwardHuntForAdventure(
      pinned: pinned,
      completed: completed,
      adventure: q,
    );
    if (bonus > 0) {
      setState(() => gold += bonus);
      _toast(_lang == AppLang.de
          ? '🐍 Medusa Hunt geschafft! +$bonus Gold'
          : '🐍 Medusa Hunt completed! +$bonus gold');
    }

    _finishQuest(q, giveGold: true);
    _saveData();
  }


  void _applyLocalizationToQuests() {
    String localizedBook() => _lang == AppLang.de ? 'Buch lesen' : 'Read a Book';
    String localizedAdventure() => _lang == AppLang.de ? 'Abenteuer' : 'Adventure';
    String localizedMedusa() => _lang == AppLang.de ? 'Medusa' : 'Medusa';

    void updateList(List<Quest> list) {
      for (final q in list) {
        switch (q.type) {
          case QuestType.reading:
            if (q.readingUsesDefaultName) q.name = localizedBook();
            break;
          case QuestType.pushups:
            q.name = _pushupTitleForLevel(q.level);
            break;
          case QuestType.adventure:
            q.name = localizedAdventure();
            break;
          case QuestType.medusa:
          // classic
            if (q.linkedQuestId == null && q.name.contains('Medusa')) {
              q.name = localizedMedusa();
            }
            // hunt stays "🐍 Medusa Hunt"
            break;
        }
      }
    }

    setState(() {
      updateList(pinned);
      updateList(completed);
    });
  }

  void _openDailyQuest() {
    final remaining = _remainingFrom(_lastDailyClaimAt, _dailyCooldown);
    if (remaining > Duration.zero) {
      _toast('${tr('alreadyDone')} ⏳ ${tr('remaining')} ${_fmtShort(remaining)}');
      return;
    }

    Timer? t;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (c) {
        int secondsLeft = 30;
        void start(StateSetter setLocal) {
          t?.cancel();
          t = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            setLocal(() => secondsLeft--);
            if (secondsLeft <= 0) {
              timer.cancel();
              setState(() {
                gold += _dailyRewardGold;
                _lastDailyClaimAt = DateTime.now();
              });
              _saveData(); // NEU
              Navigator.pop(c);
              _toast('${tr('dailyRewardToast')}${_dailyRewardGold}${tr('gold')}');
            }
          });
        }
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(tr('dailyQuest'), softWrap: false),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('watchVideo')),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: (30 - secondsLeft) / 30, minHeight: 10),
                  const SizedBox(height: 8),
                  Text('${secondsLeft}s'),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: t == null ? () => start(setLocal) : null,
                    child: Text(tr('start'), softWrap: false))
              ],
            );
          },
        );
      },
    ).then((_) => t?.cancel());
  }

  Future<void> _sendSupportEmail({required String subject, required String message}) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(message);
    final uri = Uri.parse('mailto:kornelius.thelen@gmail.com?subject=$encodedSubject&body=$encodedBody');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _toast(tr('emailError'));
    } else {
      _toast(tr('thanks'));
    }
  }

  void _openSupportForm() {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (c) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 460),
        title: Text(tr('support'), softWrap: false),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: subjectCtrl,
                decoration: InputDecoration(labelText: tr('subject')),
                textInputAction: TextInputAction.next),
            const SizedBox(height: 8),
            TextField(
                controller: messageCtrl,
                decoration: InputDecoration(labelText: tr('message')),
                maxLines: 6),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('cancel'), softWrap: false)),
          FilledButton(
            onPressed: () {
              final subj = subjectCtrl.text.trim();
              final body = messageCtrl.text.trim();
              Navigator.pop(c);
              _sendSupportEmail(subject: subj.isEmpty ? 'SideQuest Support' : subj, message: body);
            },
            child: Text(tr('send'), softWrap: false),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (c) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 520),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('aboutLine')),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    minimumSize: const Size(36, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() => _lang = AppLang.de);
                    Navigator.pop(c);
                    _applyLocalizationToQuests();
                  },
                  child: const Text('🇩🇪'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    minimumSize: const Size(36, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() => _lang = AppLang.en);
                    Navigator.pop(c);
                    _applyLocalizationToQuests();
                  },
                  child: const Text('🇬🇧'),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(c);
                    setState(() => gold += 100);
                    _toast(tr('devCheat'));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.developer_mode, size: 16),
                        SizedBox(width: 6),
                        Text('DEV', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(c);
                _openSupportForm();
              },
              icon: const Icon(Icons.support_agent_rounded),
              label: Text(tr('support'), softWrap: false),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _stdBtn() => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(42),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    alignment: Alignment.center,
    backgroundColor: const Color(0xFF1C1610),
    foregroundColor: const Color(0xFFC9A84C),
    side: const BorderSide(color: Color(0xFFC9A84C), width: 1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w600,
        letterSpacing: 0.3, height: 1.3),
  );

  ButtonStyle _dailyButtonStyle({required bool disabled}) => _stdBtn().copyWith(
    foregroundColor: WidgetStateProperty.all(
      disabled ? const Color(0xFF5A5040) : const Color(0xFFC9A84C),
    ),
    backgroundColor: WidgetStateProperty.all(const Color(0xFF1C1610)),
    side: WidgetStateProperty.all(BorderSide(
      color: disabled
          ? const Color(0xFF3A3020).withOpacity(0.5)
          : const Color(0xFFC9A84C),
    )),
  );

  Widget _btnText(String s) => Text(
    s,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
  );

  void _openShopPage() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ShopPage(
        lang: _lang,
        gold: gold,
        xpBarGreen: _xpBarGreen,
        destinyPurchased: _destinyPurchased,
        destinyStyle: _destinyStyle,
        paperColor: _paperColor,
        paperBorder: _paperBorder,
        onBuyGreenXp: () {
          if (!_xpBarGreen && gold >= 10) {
            setState(() {
              gold -= 10;
              _xpBarGreen = true;
            });
            _toast(tr('boughtXpToast'));
          }
        },
        onToggleDestiny: () {
          setState(() {
            if (!_destinyPurchased) {
              if (gold >= 20) {
                gold -= 20;
                _destinyPurchased = true;
                _destinyStyle = true;
                _toast(tr('activatedToast'));
              }
            } else {
              _destinyStyle = !_destinyStyle;
              _toast(_destinyStyle ? tr('activatedToast') : tr('deactivatedToast'));
            }
          });
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final dailyRemaining = _remainingFrom(_lastDailyClaimAt, _dailyCooldown);
    final dailyDisabled = dailyRemaining > Duration.zero;
    String dailyLabel;
    if (dailyDisabled) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day + 1);
      final untilMidnight = midnight.difference(now);
      dailyLabel = _fmtDurationClock(untilMidnight);
    } else {
      dailyLabel = tr('dailyQuest');
    }

final hasActiveMedusa = MedusaService.activeClassicMedusaOrNull(pinned) != null;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Hintergrundbild
          Positioned.fill(
            child: Image.asset(
              DateTime.now().hour >= 21 || DateTime.now().hour < 6
                  ? 'assets/images/bg_main_night.png'
                  : 'assets/images/bg_main_day.png',
              fit: BoxFit.cover,
            ),
          ),
          // Haupt UI
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 72),
                        children: [
                          _header(cs),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => setState(() => _showCreator = !_showCreator),
                                  style: _stdBtn(),
                                  child: Text(
                                    _showCreator ? '${tr('newQuest')} ▾' : '${tr('newQuest')} ▸',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _openSkills,
                                  style: _stdBtn(),
                                  child: Text(
                                    tr('skills'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: FilledButton(
                                  onPressed: dailyDisabled ? null : _openDailyQuest,
                                  style: _dailyButtonStyle(disabled: dailyDisabled),
                                  child: Text(
                                    dailyLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.cinzel(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 2),
                              child: Container(
                                decoration: _paper(),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(tr('selectQuest'),
                                        style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 10),
                                    FilledButton(
                                      onPressed: () => _addReadingQuest(context),
                                      style: _stdBtn(),
                                      child: _btnText(tr('bookReading')),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton(
                                      onPressed: () => _addPushupQuest(context),
                                      style: _stdBtn(),
                                      child: _btnText(tr('pushups')),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton(
                                      onPressed: () => _addAdventureQuest(context),
                                      style: _stdBtn(),
                                      child: _btnText(tr('adventure')),
                                    ),
                                    const SizedBox(height: 8),
                                    if (!hasActiveMedusa)
                                      FilledButton(
                                        onPressed: _openMedusaInfoDialog,
                                        style: _stdBtn(),
                                        child: _btnText(tr('medusa')),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            crossFadeState: _showCreator
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 180),
                          ),
                          const SizedBox(height: 8),
                          Text(tr('pinned'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          if (pinned.isEmpty) _emptyCard(tr('nonePinned')),
                          ...pinned.map(_questCard),
                          const SizedBox(height: 12),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    Positioned(left: 0, right: 0, bottom: 0, child: _appXpBar(cs)),
                  ],
                ),
              ),
            ),
          ),

          // 🔥 Overlay Listener: Swipe UP funktioniert auch während du scrollst
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _handleGlobalSwipe,
              onPointerUp: _handleGlobalSwipeEnd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: _showAbout,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC9A84C).withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/sidequest_alpha.png',
                height: 46,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1610),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/icons/gold_coin.svg', width: 18, height: 18),
                  const SizedBox(width: 6),
                  Text('$gold', style: GoogleFonts.cinzel(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFFC9A84C),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // SHOP
            GestureDetector(
              onTap: _openShopPage,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1610),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.3)),
                ),
                child: Center(
                  child: SvgPicture.asset('assets/icons/shop.svg', width: 20, height: 20),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // HISTORY
            GestureDetector(
              onTap: _openHistory,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1610),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.3)),
                ),
                child: Center(
                  child: SvgPicture.asset('assets/icons/history.svg', width: 20, height: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _paper(),
    child: Text(text, textAlign: TextAlign.center),
  );

  BoxDecoration _paper() => BoxDecoration(
    color: _paperColor.withOpacity(0.75),
    border: Border.all(
      color: _destinyStyle
          ? const Color(0xFF2B3A73)
          : const Color(0xFFC9A84C).withOpacity(0.25),
      width: 1,
    ),
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: _destinyStyle
            ? const Color(0xFF00D1FF).withOpacity(0.05)
            : const Color(0xFFC9A84C).withOpacity(0.08),
        blurRadius: 12,
      ),
    ],
  );

  Widget _animatedStepsLine({required int steps, required int target, required String timeLeft}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: Text('⛰️ $steps/$target • $timeLeft', key: ValueKey(steps)),
    );
  }

  Widget _progressBar(double pct) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: pct.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 14,
          backgroundColor: const Color(0xFF000000).withValues(alpha: 0.25),
          valueColor: AlwaysStoppedAnimation<Color>(
            _xpBarGreen
                ? Colors.green
                : (_destinyStyle
                ? const Color(0xFF00D1FF)
                : const Color(0xFFF0C060)),
          ),
        );
      },
    ),
  );

  Widget _huntBadgeForAdventure(Quest adventure) {
final hunt = MedusaService.huntForAdventure(pinned, adventure.id);

// Badge nur solange Hunt pinned ist
    if (hunt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final remain = hunt.endAt != null && now.isBefore(hunt.endAt!)
        ? hunt.endAt!.difference(now)
        : Duration.zero;

    final text = hunt.failed
        ? '${tr('huntBadge')} • ${tr('failedLabel')}'
        : '${tr('huntBadge')} • ${_fmtDurationClock(remain)} • +${hunt.bonusGold}';

    final color = hunt.failed ? Colors.redAccent : Colors.greenAccent;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.8)),
          color: color.withValues(alpha: 0.10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _questCard(Quest q, {bool locked = false}) {
    final now = DateTime.now();

    Widget subtitle;
    double pct;

    if (q.type == QuestType.reading) {
      final total = (q.totalPages ?? 1);
      pct = total <= 0 ? 0.0 : q.readPages / total;
      subtitle = Text('📘 ${q.readPages}/${q.totalPages} ${tr('pages')}');
    } else if (q.type == QuestType.pushups) {
      final isCooldownLocked = (!locked) && q.unlockAt != null && now.isBefore(q.unlockAt!);
      if (isCooldownLocked) {
        final remaining = q.unlockAt!.difference(now);
        subtitle = Text('💪 Level ${q.level + 1} – ${tr('lockedIn')} ${_fmtShort(remaining)}');
        final total = const Duration(hours: 24).inSeconds.toDouble();
        final elapsed = (total - remaining.inSeconds).toDouble().clamp(0, total);
        pct = (elapsed / total).clamp(0.0, 1.0);
      } else {
        final need = _repsNeededForQuest(q);
        pct = need <= 0 ? 0.0 : q.repsProgress / need;
        subtitle = Text(
            '💪 Level ${q.level + 1} – ${q.repsProgress}/${_repsNeededForQuest(q)} ${tr('reps')}');
      }
    } else if (q.type == QuestType.adventure) {
      final ended = (q.endAt != null && now.isAfter(q.endAt!));
      final remain = ended ? Duration.zero : q.endAt!.difference(now);
      pct = q.stepsTarget <= 0 ? 0.0 : q.stepsProgress / q.stepsTarget;
      pct = pct.clamp(0.0, 1.0);
      subtitle = _animatedStepsLine(
        steps: q.stepsProgress,
        target: q.stepsTarget,
        timeLeft: _fmtDurationClock(remain),
      );
    } else {
      // Medusa (classic or hunt)
      final remain = q.endAt != null && now.isBefore(q.endAt!) ? q.endAt!.difference(now) : Duration.zero;
      final total = q.endAt != null && q.startAt != null
          ? q.endAt!.difference(q.startAt!)
          : const Duration(hours: 4);
      final elapsed = (total - remain).inSeconds.toDouble().clamp(0, total.inSeconds.toDouble());
      pct = (elapsed / total.inSeconds.toDouble()).clamp(0.0, 1.0);

      final label = q.failed ? '❌ ${tr('failedLabel')}' : '👁️ ${tr('timeLeft')}: ${_fmtDurationClock(remain)}';

      if (q.linkedQuestId != null && !q.failed) {
        subtitle = Text('$label • +${q.bonusGold}');
      } else {
        subtitle = Text(label);
      }
    }

    final isFailed = q.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _paper(),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isFailed ? Colors.redAccent : null,
                              ),
                            ),
                          ),
                          if (isFailed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.8)),
                              ),
                              child: Text(
                                tr('failedLabel'),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      ensureSpace(),
                      Opacity(opacity: 0.85, child: subtitle),

                      // ✅ Badge direkt auf Adventure-Karte
                      if (q.type == QuestType.adventure) _huntBadgeForAdventure(q),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _progressBar(pct),
            const SizedBox(height: 6),
            if (q.type == QuestType.reading && !locked)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _addPages(q, 10),
                      style: _stdBtn(),
                      child: _btnText(tr('plus10pages')),
                    ),
                  ),
                ],
              ),
            if (q.type == QuestType.pushups &&
                !locked &&
                (q.unlockAt == null || now.isAfter(q.unlockAt!)))
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: (_pushupCounting && _pushupQuestIdRunning == q.id)
                          ? _stopPushupSensor
                          : () => _startPushupSensorForQuest(q),
                      style: _stdBtn(),
                      child: _btnText(
                        (_pushupCounting && _pushupQuestIdRunning == q.id)
                            ? (_lang == AppLang.de ? '🛑 Sensor Stop' : '🛑 Stop sensor')
                            : (_lang == AppLang.de ? '📳 Sensor Start' : '📳 Start sensor'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _addReps(q, 5),
                      style: _stdBtn(),
                      child: _btnText(tr('plus5reps')),
                    ),
                  ),
                ],
              ),

          ],
        ),
      ),
    );
  }

  // kleine Hilfe, damit der Analyzer nicht meckert (Spacing)
  Widget ensureSpace() => const SizedBox(height: 2);

  Widget _appXpBar(ColorScheme cs) {
    final pct = appXpNeeded <= 0 ? 0.0 : (appXp / appXpNeeded).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _destinyStyle ? const Color(0xFF151B37).withOpacity(0.85) : const Color(0xFF120E08).withOpacity(0.85),
        border: Border(top: BorderSide(
          color: _destinyStyle
              ? const Color(0xFF151B37).withOpacity(0.85)
              : Colors.black.withOpacity(0.6),
        )),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('yourLevel'), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'Level $appLevel',
                style: GoogleFonts.cinzel(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFC9A84C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _progressBar(pct),
        ],
      ),
    );
  }

  void _openSkills() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 420),
        title: Text('⚔️ ${tr('skills')}', softWrap: false),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📘 ${_lang == AppLang.de ? 'Gelehrter' : 'Scholar'}: $scholarPoints/100'),
            Text('💪 ${_lang == AppLang.de ? 'Athlet' : 'Athlete'}: $athletePoints/100'),
            Text('🏔️ ${_lang == AppLang.de ? 'Abenteurer' : 'Adventurer'}: $adventurerPoints/100'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }
}
