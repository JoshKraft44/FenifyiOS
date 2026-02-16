import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Performance monitoring utility for tracking CPU and energy usage
class PerformanceMonitor {
  static const _enabled = kDebugMode;

  /// Mark the start of a performance-critical section
  static void beginSignpost(String name) {
    if (!_enabled) return;
    developer.Timeline.startSync(name);
  }

  /// Mark the end of a performance-critical section
  static void endSignpost(String name) {
    if (!_enabled) return;
    developer.Timeline.finishSync();
  }

  /// Track a specific operation with automatic cleanup
  static Future<T> track<T>(String name, Future<T> Function() operation) async {
    if (!_enabled) return await operation();

    beginSignpost(name);
    try {
      return await operation();
    } finally {
      endSignpost(name);
    }
  }

  /// Track a synchronous operation
  static T trackSync<T>(String name, T Function() operation) {
    if (!_enabled) return operation();

    beginSignpost(name);
    try {
      return operation();
    } finally {
      endSignpost(name);
    }
  }

  /// Log current memory usage
  static void logMemory(String context) {
    if (!_enabled) return;
    // Memory tracking would require platform channels
    developer.log('Memory checkpoint: $context', name: 'PerformanceMonitor');
  }
}

/// Extension for easy performance tracking
extension PerformanceTrackingFuture<T> on Future<T> {
  Future<T> tracked(String name) => PerformanceMonitor.track(name, () => this);
}
