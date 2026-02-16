import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Throttles analysis updates to reduce UI rebuilds and save power
/// Emits updates at most 5-10 times per second
class AnalysisThrottler {
  final int updatesPerSecond;
  final Duration throttleDuration;

  Map<String, dynamic>? _latestData;
  Timer? _throttleTimer;
  bool _hasScheduledUpdate = false;

  final StreamController<Map<String, dynamic>> _controller;

  AnalysisThrottler({this.updatesPerSecond = 8})
      : throttleDuration = Duration(milliseconds: 1000 ~/ updatesPerSecond),
        _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  /// Add data to throttle - only the latest data is kept and emitted
  void add(Map<String, dynamic> data) {
    if (_controller.isClosed) return;

    // Always keep the latest data
    _latestData = data;

    // If we haven't scheduled an update, schedule one
    if (!_hasScheduledUpdate) {
      _scheduleUpdate();
    }
  }

  void _scheduleUpdate() {
    _hasScheduledUpdate = true;

    // Use frame scheduling to coalesce updates with the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for the throttle duration
      _throttleTimer?.cancel();
      _throttleTimer = Timer(throttleDuration, () {
        if (_latestData != null && !_controller.isClosed) {
          _controller.add(_latestData!);
        }
        _hasScheduledUpdate = false;
        _latestData = null;
      });
    });
  }

  void dispose() {
    _throttleTimer?.cancel();
    _controller.close();
  }
}

/// Debouncer for FEN changes to avoid redundant analysis requests
class FenDebouncer {
  final Duration delay;
  Timer? _timer;

  FenDebouncer({this.delay = const Duration(milliseconds: 300)});

  /// Debounce a function call - only executes after delay of inactivity
  void debounce(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Batches state updates to minimize rebuilds
class StateBatcher {
  final VoidCallback onFlush;
  final Duration batchWindow;

  Timer? _batchTimer;
  bool _hasPendingUpdate = false;

  StateBatcher({
    required this.onFlush,
    this.batchWindow = const Duration(milliseconds: 16), // ~60fps
  });

  /// Mark that an update is needed - will be flushed after batch window
  void markNeedsUpdate() {
    if (_hasPendingUpdate) return;

    _hasPendingUpdate = true;

    // Schedule flush on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _batchTimer?.cancel();
      _batchTimer = Timer(batchWindow, _flush);
    });
  }

  void _flush() {
    if (_hasPendingUpdate) {
      _hasPendingUpdate = false;
      onFlush();
    }
  }

  /// Force immediate flush
  void flushNow() {
    _batchTimer?.cancel();
    _flush();
  }

  void dispose() {
    _batchTimer?.cancel();
  }
}
