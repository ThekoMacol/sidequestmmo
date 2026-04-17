import '../models/quest.dart';
import '../models/app_lang.dart';

/// ===============================
/// MEDUSA SERVICE
/// Zentrale Logik für:
/// - Classic Medusa (4 Stunden Display aus)
/// - Medusa Hunt (gekoppelt an Adventure)
/// - Hardcore-Regel: Resume vor Ablauf => Hunt + Adventure FAIL
/// ===============================
class MedusaService {
  /* ---------- CLASSIC MEDUSA ---------- */

  /// Gibt die aktive Classic-Medusa zurück (falls vorhanden)
  static Quest? activeClassicMedusaOrNull(List<Quest> pinned) {
    try {
      return pinned.firstWhere(
            (q) => q.type == QuestType.medusa && q.linkedQuestId == null && !q.done,
      );
    } catch (_) {
      return null;
    }
  }

  /// Wird beim App-Resume aufgerufen, um zu prüfen:
  /// - Zu früh zurück? -> Fail
  /// - 4h vorbei? -> Success
  static String? evaluateClassicMedusaOnResume({
    required List<Quest> pinned,
    required List<Quest> completed,
    required Quest Function(Quest q) failQuest,
    required Quest Function(Quest q) finishQuest,
  }) {
    final now = DateTime.now();

    final medusa = activeClassicMedusaOrNull(pinned);
    if (medusa == null) return null;

    // Zu früh zurück?
    if (medusa.startAt != null &&
        now.isBefore(medusa.startAt!.add(const Duration(hours: 4)))) {
      failQuest(medusa);
      return "failed";
    }

    // Zeit abgelaufen -> Erfolg
    if (medusa.endAt != null && now.isAfter(medusa.endAt!)) {
      finishQuest(medusa);
      return "success";
    }

    return null;
  }

  /* ---------- MEDUSA HUNT (Adventure-Bonus) ---------- */

  /// Erstellt eine Hunt-Quest, die an ein Adventure gekoppelt ist
  static Quest createMedusaHunt({
    required AppLang lang,
    required String adventureId,
    required int bonus,
  }) {
    final now = DateTime.now();

    final q = Quest.medusa(
      name: lang == AppLang.de ? '🐍 Medusa Hunt' : '🐍 Medusa Hunt',
      start: now,
      end: now.add(const Duration(hours: 4)),
      medusaArmed: true,
    );

    // ✅ Danach Felder setzen (Constructor bleibt clean)
    q.linkedQuestId = adventureId;
    q.bonusGold = bonus;

    return q;
  }

  /// Findet die Hunt zu einem bestimmten Adventure
  static Quest? huntForAdventure(List<Quest> pinned, String adventureId) {
    try {
      return pinned.firstWhere(
            (q) =>
        q.type == QuestType.medusa &&
            q.linkedQuestId == adventureId &&
            !q.done,
      );
    } catch (_) {
      return null;
    }
  }

  /// Prüft jede Sekunde, ob Hunts abgelaufen sind → dann FAIL
  static int checkExpiredHunts({
    required List<Quest> pinned,
    required List<Quest> completed,
    required String reason,
  }) {
    final now = DateTime.now();
    int failedCount = 0;

    final expired = pinned.where(
          (q) =>
      q.type == QuestType.medusa &&
          q.linkedQuestId != null &&
          q.endAt != null &&
          now.isAfter(q.endAt!) &&
          !q.done,
    );

    for (final q in expired.toList()) {
      q.failed = true;
      q.failReason = reason;
      q.done = true;
      q.finishedAt = now;

      pinned.removeWhere((e) => e.id == q.id);
      completed.insert(0, q);
      failedCount++;
    }

    return failedCount;
  }

  /// Wird aufgerufen, wenn Adventure fertig ist.
  /// Vergibt Bonus NUR, wenn Hunt existiert und NICHT failed ist.
  static int tryAwardHuntForAdventure({
    required List<Quest> pinned,
    required List<Quest> completed,
    required Quest adventure,
  }) {
    final hunt = huntForAdventure(pinned, adventure.id);
    if (hunt == null) return 0;

    if (hunt.failed) return 0;

    hunt.done = true;
    hunt.finishedAt = DateTime.now();

    pinned.removeWhere((e) => e.id == hunt.id);
    completed.insert(0, hunt);

    return hunt.bonusGold ?? 0;
  }

  /* ---------- HARDCORE: Resume vor Ablauf => FAIL ---------- */

  /// Hardcore-Regel:
  /// Wenn eine Hunt aktiv ist (linkedQuestId != null) und die App resumed,
  /// bevor die 4h abgelaufen sind, dann:
  /// - Hunt FAIL
  /// - das verknüpfte Adventure FAIL
  ///
  /// Rückgabe: true wenn etwas gefailed ist.
  static bool failHardcoreHuntIfResumedTooEarly({
    required List<Quest> pinned,
    required List<Quest> completed,
    required Quest Function(Quest q, {String? reason}) failQuest,
    required Quest Function(Quest q, {String? reason}) failAdventure,
  }) {
    final now = DateTime.now();

    // aktive Hunts
    final hunts = pinned
        .where((q) =>
    q.type == QuestType.medusa &&
        q.linkedQuestId != null &&
        !q.done)
        .toList();

    bool anyFailed = false;

    for (final hunt in hunts) {
      final end = hunt.endAt;
      if (end == null) continue;

      // ✅ Wenn vor Ablauf resumed -> fail
      if (now.isBefore(end)) {
        anyFailed = true;

        // 1) Hunt fail
        failQuest(hunt, reason: 'returned_early');

        // 2) linked Adventure fail (falls vorhanden)
        final advId = hunt.linkedQuestId!;
        Quest? adv;
        try {
          adv = pinned.firstWhere(
                (x) => x.type == QuestType.adventure && x.id == advId && !x.done,
          );
        } catch (_) {
          adv = null;
        }

        if (adv != null) {
          failAdventure(adv, reason: 'medusa_returned_early');
        }
      }
    }

    return anyFailed;
  }
}
