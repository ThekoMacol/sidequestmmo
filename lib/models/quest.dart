// lib/models/quest.dart
import 'dart:math';

enum QuestType { reading, pushups, adventure, medusa }

class Quest {
  final String id;
  final QuestType type;
  String name;

  // Reading
  final int? totalPages;
  int readPages;
  bool readingUsesDefaultName;

  // Pushups
  int level; // 0 => 10 reps … 99 => 1000 reps
  int repsProgress;

  // Adventure/Medusa
  int stepsTarget;
  int stepsProgress;
  DateTime? startAt;
  DateTime? endAt;
  DateTime? dayKey; // yyyy-mm-dd
  int? deviceBaseline;

  // Locks/State
  DateTime? unlockAt; // für Pushups
  bool done;

  // Abschluss-Zeitstempel (für „letzte 24h“)
  DateTime? finishedAt;

  // Medusa-Flag (für "Bildschirm aus"-Medusa)
  bool medusaArmed;

  // Ergebnis / Fail-Handling
  bool failed;
  String? failReason;

  // Medusa Hunt Link / Bonus
  String? linkedQuestId; // verbindet Hunt mit Adventure
  int bonusGold; // z.B. 25
  bool bonusAwarded; // Bonus nur 1x

  Quest.reading({
    required this.name,
    required this.totalPages,
    this.readingUsesDefaultName = false,
  })  : id = _uid(),
        type = QuestType.reading,
        readPages = 0,
        level = 0,
        repsProgress = 0,
        stepsTarget = 0,
        stepsProgress = 0,
        startAt = null,
        endAt = null,
        dayKey = null,
        deviceBaseline = null,
        unlockAt = null,
        done = false,
        finishedAt = null,
        medusaArmed = false,
        failed = false,
        failReason = null,
        linkedQuestId = null,
        bonusGold = 0,
        bonusAwarded = false;

  Quest.pushups({
    required this.name,
    int startLevel = 0,
    DateTime? unlockAt,
  })  : id = _uid(),
        type = QuestType.pushups,
        totalPages = null,
        readPages = 0,
        readingUsesDefaultName = false,
        level = startLevel,
        repsProgress = 0,
        stepsTarget = 0,
        stepsProgress = 0,
        startAt = null,
        endAt = null,
        dayKey = null,
        deviceBaseline = null,
        unlockAt = unlockAt,
        done = false,
        finishedAt = null,
        medusaArmed = false,
        failed = false,
        failReason = null,
        linkedQuestId = null,
        bonusGold = 0,
        bonusAwarded = false;

  Quest.adventure({
    required this.name,
    required int target,
    required DateTime start,
    required DateTime end,
    required DateTime dayOnly,
    int? baseline,
  })  : id = _uid(),
        type = QuestType.adventure,
        totalPages = null,
        readPages = 0,
        readingUsesDefaultName = false,
        level = 0,
        repsProgress = 0,
        stepsTarget = target,
        stepsProgress = 0,
        startAt = start,
        endAt = end,
        dayKey = DateTime(dayOnly.year, dayOnly.month, dayOnly.day),
        deviceBaseline = baseline,
        unlockAt = null,
        done = false,
        finishedAt = null,
        medusaArmed = false,
        failed = false,
        failReason = null,
        linkedQuestId = null,
        bonusGold = 0,
        bonusAwarded = false;

  /// Medusa:
  /// - classic (screen-off): linkedQuestId == null, medusaArmed true
  /// - hunt (bonus): linkedQuestId != null
  Quest.medusa({
    required this.name,
    required DateTime start,
    required DateTime end,
    this.medusaArmed = false,
  })  : id = _uid(),
        type = QuestType.medusa,
        totalPages = null,
        readPages = 0,
        readingUsesDefaultName = false,
        level = 0,
        repsProgress = 0,
        stepsTarget = 0,
        stepsProgress = 0,
        startAt = start,
        endAt = end,
        dayKey = DateTime(start.year, start.month, start.day),
        deviceBaseline = null,
        unlockAt = null,
        done = false,
        finishedAt = null,
        failed = false,
        failReason = null,
        linkedQuestId = null,
        bonusGold = 0,
        bonusAwarded = false;

  static String _uid() => Random().nextInt(1 << 32).toRadixString(16);
}
