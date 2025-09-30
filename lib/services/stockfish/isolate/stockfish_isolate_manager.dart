import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'stockfish_isolate_main.dart';

class StockfishIsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();

  bool get isRunning => _isolate != null && _sendPort != null;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> initialize() async {
    if (isRunning) {
      await cleanup();
    }

    if (kDebugMode) debugPrint('Creating Stockfish isolate...');

    _receivePort = ReceivePort();
    final isolateReadyCompleter = Completer<void>();
    late StreamSubscription subscription;

    try {
      if (kDebugMode) debugPrint('ISO: SPAWNING');
      _isolate = await Isolate.spawn(stockfishIsolateMain, _receivePort!.sendPort);
      if (kDebugMode) debugPrint('ISO: SPAWNED');
      if (kDebugMode) debugPrint('Isolate spawned successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('ISO: SPAWN_FAILED - $e');
      if (kDebugMode) debugPrint('Failed to spawn isolate: $e');
      _receivePort?.close();
      _receivePort = null;
      throw Exception('Failed to create Stockfish isolate: $e');
    }

    // Set up message handling
    subscription = _receivePort!.listen((message) {
      try {
        if (message is SendPort) {
          if (kDebugMode) debugPrint('Received SendPort from isolate');
          _sendPort = message;
          if (!isolateReadyCompleter.isCompleted) {
            isolateReadyCompleter.complete();
          }
        } else if (message is Map<String, dynamic>) {
          _messageController.add(message);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error handling isolate message: $e');
        if (!isolateReadyCompleter.isCompleted) {
          isolateReadyCompleter.completeError(e);
        }
      }
    }, onError: (error) {
      if (kDebugMode) debugPrint('Isolate receive port error: $error');
      if (!isolateReadyCompleter.isCompleted) {
        isolateReadyCompleter.completeError(error);
      }
    });

    // Wait for isolate to be ready with timeout
    try {
      await isolateReadyCompleter.future.timeout(Duration(seconds: 20));
      if (kDebugMode) debugPrint('Isolate communication established');
    } catch (e) {
      subscription.cancel();
      throw Exception('Isolate initialization timeout: $e');
    }

    // Initialize engine in isolate
    if (_sendPort != null) {
      if (kDebugMode) debugPrint('Sending init command to isolate');
      _sendPort!.send('init');
    } else {
      throw Exception('Failed to establish communication with isolate');
    }
  }

  void sendAnalysisCommand(String fen, int analysisId) {
    if (_sendPort != null) {
      _sendPort!.send({
        'type': 'analyze',
        'fen': fen,
        'id': analysisId,
      });
    }
  }

  void sendStopCommand() {
    if (_sendPort != null) {
      _sendPort!.send('stop');
    }
  }


  void sendValidationCommand(String fen, SendPort responsePort) {
    if (_sendPort != null) {
      _sendPort!.send({
        'type': 'validate_fen',
        'fen': fen,
        'responsePort': responsePort,
      });
    }
  }

  Future<void> cleanup() async {
    if (kDebugMode) debugPrint('Cleaning up isolate resources...');

    // First try to gracefully dispose
    if (_sendPort != null) {
      try {
        _sendPort!.send('dispose');
        // Give time for graceful shutdown
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        if (kDebugMode) debugPrint('Error sending dispose command: $e');
      }
      _sendPort = null;
    }

    // Force kill the isolate
    if (_isolate != null) {
      try {
        if (kDebugMode) debugPrint('ISO: KILLING');
        _isolate!.kill(priority: Isolate.immediate);
        if (kDebugMode) debugPrint('ISO: KILLED');

        // Wait for complete termination
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        if (kDebugMode) debugPrint('ISO: KILL_FAILED - $e');
        if (kDebugMode) debugPrint('Error killing isolate: $e');
      }
      _isolate = null;
    }

    if (_receivePort != null) {
      try {
        _receivePort!.close();
      } catch (e) {
        if (kDebugMode) debugPrint('Error closing receive port: $e');
      }
      _receivePort = null;
    }

    // Ensure all references are cleared
    _sendPort = null;
  }

  void dispose() {
    _messageController.close();
  }
}