import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';

class PushupCounterService {
  final _repsCtrl = StreamController<int>.broadcast();
  Stream<int> get repsStream => _repsCtrl.stream;

  CameraController? _cam;
  bool _running = false;

  int _total = 0;
  bool _wasLow = false;

  int _startMs = 0;
  final int _warmupMs = 1200;

  int _lastCountMs = 0;
  final int _minIntervalMs = 900;

  // brightness tracking
  double _ema = 0.0;
  final double _alpha = 0.25;

  double _minB = 1e9;
  double _maxB = -1e9;

  final double _minSpan = 6.0; // require some contrast
  final double _kLow = 0.30;
  final double _kHigh = 0.70;

  bool _busy = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    _total = 0;
    _wasLow = false;

    _ema = 0.0;
    _minB = 1e9;
    _maxB = -1e9;

    final now = DateTime.now().millisecondsSinceEpoch;
    _startMs = now;
    _lastCountMs = 0;

    // pick front camera (best for "under chest")
    final cams = await availableCameras();
    final front = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );

    _cam = CameraController(
      front,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cam!.initialize();

    // stream frames
    await _cam!.startImageStream(_onFrame);
  }

  Future<void> stop() async {
    _running = false;

    final c = _cam;
    _cam = null;
    if (c == null) return;

    try {
      await c.stopImageStream();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _repsCtrl.close();
  }

  void _onFrame(CameraImage img) {
    if (!_running) return;
    if (_busy) return;
    _busy = true;

    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _startMs < _warmupMs) return;

      // Y plane = luma (brightness). We sample sparse pixels for speed.
      final y = img.planes[0].bytes;
      final w = img.width;
      final h = img.height;

      int sum = 0;
      int count = 0;

      // sample a grid (every ~20 px)
      final stepX = max(12, (w / 18).floor());
      final stepY = max(12, (h / 18).floor());

      for (int yy = 0; yy < h; yy += stepY) {
        final row = yy * w;
        for (int xx = 0; xx < w; xx += stepX) {
          sum += y[row + xx];
          count++;
        }
      }

      final b = count == 0 ? 0.0 : (sum / count).toDouble();

      // EMA smoothing
      if (_ema == 0.0) {
        _ema = b;
      } else {
        _ema = _ema + _alpha * (b - _ema);
      }

      // min/max tracking
      _minB = min(_minB, _ema);
      _maxB = max(_maxB, _ema);

      final span = (_maxB - _minB).abs();
      if (span < _minSpan) return;

      final lowTh = _minB + _kLow * span;
      final highTh = _minB + _kHigh * span;

      // Down (darker)
      if (!_wasLow && _ema <= lowTh) {
        _wasLow = true;
        return;
      }

      // Up (brighter) => count
      if (_wasLow && _ema >= highTh) {
        if (nowMs - _lastCountMs >= _minIntervalMs) {
          _lastCountMs = nowMs;
          _wasLow = false;
          _total += 1;
          if (!_repsCtrl.isClosed) _repsCtrl.add(_total);

          // relax window so it adapts
          final pad = max(8.0, span * 0.30);
          _minB = _ema - pad;
          _maxB = _ema + pad;
        }
      }
    } finally {
      _busy = false;
    }
  }
}
