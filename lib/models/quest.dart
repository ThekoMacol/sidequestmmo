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
  int level;
  int repsProgress;

  // Adventure/Medusa
  int stepsTarget;
  int stepsProgress;
  DateTime? startAt;
  DateTime? endAt;
  DateTime? dayKey;
  int? deviceBaseline;

  // Locks/State
  DateTime? unlockAt;
  bool done;

  DateTime? finishedAt;

  bool medusaArmed;

  bool failed;
  String? failReason;

  String? linkedQuestId;
  int bonusGold;
  bool bonusAwarded;

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

  // ── Private constructor for fromJson ──
  Quest._fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        type = QuestType.values[j['type'] as int],
        name = j['name'] as String,
        totalPages = j['totalPages'] as int?,
        readPages = j['readPages'] as int? ?? 0,
        readingUsesDefaultName = j['readingUsesDefaultName'] as bool? ?? false,
        level = j['level'] as int? ?? 0,
        repsProgress = j['repsProgress'] as int? ?? 0,
        stepsTarget = j['stepsTarget'] as int? ?? 0,
        stepsProgress = j['stepsProgress'] as int? ?? 0,
        startAt = j['startAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['startAt'] as int)
            : null,
        endAt = j['endAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['endAt'] as int)
            : null,
        dayKey = j['dayKey'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['dayKey'] as int)
            : null,
        deviceBaseline = j['deviceBaseline'] as int?,
        unlockAt = j['unlockAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['unlockAt'] as int)
            : null,
        done = j['done'] as bool? ?? false,
        finishedAt = j['finishedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['finishedAt'] as int)
            : null,
        medusaArmed = j['medusaArmed'] as bool? ?? false,
        failed = j['failed'] as bool? ?? false,
        failReason = j['failReason'] as String?,
        linkedQuestId = j['linkedQuestId'] as String?,
        bonusGold = j['bonusGold'] as int? ?? 0,
        bonusAwarded = j['bonusAwarded'] as bool? ?? false;

  // ── toJson ──
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'name': name,
    'totalPages': totalPages,
    'readPages': readPages,
    'readingUsesDefaultName': readingUsesDefaultName,
    'level': level,
    'repsProgress': repsProgress,
    'stepsTarget': stepsTarget,
    'stepsProgress': stepsProgress,
    'startAt': startAt?.millisecondsSinceEpoch,
    'endAt': endAt?.millisecondsSinceEpoch,
    'dayKey': dayKey?.millisecondsSinceEpoch,
    'deviceBaseline': deviceBaseline,
    'unlockAt': unlockAt?.millisecondsSinceEpoch,
    'done': done,
    'finishedAt': finishedAt?.millisecondsSinceEpoch,
    'medusaArmed': medusaArmed,
    'failed': failed,
    'failReason': failReason,
    'linkedQuestId': linkedQuestId,
    'bonusGold': bonusGold,
    'bonusAwarded': bonusAwarded,
  };

  // ── fromJson ──
  static Quest fromJson(Map<String, dynamic> j) => Quest._fromJson(j);

  static String _uid() => Random().nextInt(1 << 32).toRadixString(16);
}