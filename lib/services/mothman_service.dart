import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/quest.dart';

/// ===============================
/// MOTHMAN SERVICE
/// Sensor-Logik für die Mottenmann Quest:
/// - Accelerometer: Bewegungserkennung mit 3s Toleranz
/// - Quest Fail bei zu viel Bewegung
/// ===============================
class MothmanService {
  StreamSubscription? _accelSub;
  DateTime? _movementStart;

  static const _moveTolerance = Duration(seconds: 3);
  static const _moveThreshold = 2.0;

  /// Startet den Accelerometer-Sensor für eine Mothman Quest
  void start({
    required Quest quest,
    required void Function(Quest q, String reason) onFail,
  }) {
    stop();

    _accelSub = accelerometerEventStream().listen((event) {
      if (quest.done) {
        stop();
        return;
      }

      // Gravitationskomponente (~9.8) herausrechnen
      final movement =
          (event.x.abs() + event.y.abs() + event.z.abs()) - 9.8;

      if (movement.abs() > _moveThreshold) {
        _movementStart ??= DateTime.now();
        final movingFor = DateTime.now().difference(_movementStart!);

        if (movingFor > _moveTolerance) {
          stop();
          onFail(quest, 'movement');
        }
      } else {
        // Keine Bewegung — Timer zurücksetzen
        _movementStart = null;
      }
    });
  }

  /// Stoppt alle Sensoren
  void stop() {
    _accelSub?.cancel();
    _accelSub = null;
    _movementStart = null;
  }

  /// Prüft ob eine Mothman Quest abgelaufen ist (Zeit um)
  static bool isExpired(Quest q) {
    if (q.type != QuestType.mothman) return false;
    if (q.done) return false;
    if (q.endAt == null) return false;
    return DateTime.now().isAfter(q.endAt!);
  }

  /// Prüft ob eine Mothman Quest noch nicht startbar ist (zu früh)
  static bool isTooEarly() {
    final hour = DateTime.now().hour;
    return hour >= 8 && hour < 20;
  }

  /// Gibt die aktive Mothman Quest zurück (falls vorhanden)
  static Quest? activeMothmanOrNull(List<Quest> pinned) {
    try {
      return pinned.firstWhere(
            (q) => q.type == QuestType.mothman && !q.done,
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    stop();
  }
}