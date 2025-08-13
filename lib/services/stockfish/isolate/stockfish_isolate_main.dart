// lib/services/stockfish/isolate/stockfish_isolate_main.dart
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';

/// Main function for the Stockfish isolate
void stockfishIsolateMain(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  Stockfish? engine;
  String currentFen = '';
  int currentAnalysisId = 0;
  bool engineReady = false;
  bool engineInitializing = false;

  // Analysis state
  double evaluation = 0.0;
  bool isMate = false;
  int mateIn = 0;
  String bestMove = '';
  List<String> principalVariation = [];
  List<List<String>> multiPV = [];
  List<dynamic> multiEval = [];
  int currentDepth = 0;

  Timer? engineTimeout;
  Timer? engineKeepAlive;
  
  // Add crash recovery state
  int crashCount = 0;
  const maxCrashes = 3;
  bool isRecovering = false;
  

  // Forward declarations
  late Future<void> Function() initializeEngine;
  late Future<void> Function() recoverFromCrash;
  

  void sendDebug(String message) {
    try {
      mainSendPort.send({'type': 'debug', 'message': message});
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending debug message: $e');
    }
  }

  void sendError(String error) {
    try {
      mainSendPort.send({'type': 'engine_error', 'error': error});
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending error message: $e');
    }
  }

  void sendInvalidPosition(String fen, String reason) {
    try {
      mainSendPort.send({
        'type': 'analysis',
        'data': {
          'fen': fen,
          'analysisId': currentAnalysisId,
          'invalid_position': true,
          'error': 'Invalid position detected: $reason\n\nFEN: $fen\n\nThis position cannot be analyzed because it violates chess rules or would crash the engine.',
          'evaluation': 0.0,
          'isMate': false,
          'mateIn': 0,
          'bestMove': '',
          'principalVariation': [],
          'multiPV': [],
          'multiEval': [],
          'depth': 0,
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending invalid position: $e');
    }
  }

  void sendAnalysis() {
    try {
      mainSendPort.send({
        'type': 'analysis',
        'data': {
          'fen': currentFen,
          'analysisId': currentAnalysisId,
          'evaluation': evaluation,
          'isMate': isMate,
          'mateIn': mateIn,
          'bestMove': bestMove,
          'principalVariation': principalVariation,
          'multiPV': multiPV,
          'multiEval': multiEval,
          'depth': currentDepth,
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending analysis: $e');
    }
  }

  /// FEN validation before sending to Stockfish
  bool validateFenForStockfish(String fen) {
    try {
      // Basic format check
      final parts = fen.split(' ');
      if (parts.length != 6) {
        sendInvalidPosition(fen, 'FEN must have exactly 6 parts');
        return false;
      }

      final boardPart = parts[0];
      final activeColor = parts[1];
      final castling = parts[2];
      final enPassant = parts[3];

      // Validate active color
      if (activeColor != 'w' && activeColor != 'b') {
        sendInvalidPosition(fen, 'Invalid active color: $activeColor');
        return false;
      }

      // Validate board structure
      final ranks = boardPart.split('/');
      if (ranks.length != 8) {
        sendInvalidPosition(fen, 'Board must have 8 ranks');
        return false;
      }

      // Count kings
      int whiteKings = 0;
      int blackKings = 0;
      
      for (final rank in ranks) {
        for (int i = 0; i < rank.length; i++) {
          final char = rank[i];
          if (char == 'K') whiteKings++;
          if (char == 'k') blackKings++;
          
          // Check for invalid characters
          if (!'12345678KQRBNPkqrbnp'.contains(char)) {
            sendInvalidPosition(fen, 'Invalid piece character: $char');
            return false;
          }
        }
      }
      
      if (whiteKings != 1) {
        sendInvalidPosition(fen, 'Must have exactly one white king (found $whiteKings)');
        return false;
      }
      
      if (blackKings != 1) {
        sendInvalidPosition(fen, 'Must have exactly one black king (found $blackKings)');
                return false;
      }
      
            // Additional safety checks
      if (castling != '-' && !RegExp(r'^[KQkq]*$').hasMatch(castling)) {
        sendInvalidPosition(fen, 'Invalid castling rights: $castling');
        return false;
      }

      if (enPassant != '-' && !RegExp(r'^[a-h][36]$').hasMatch(enPassant)) {
        sendInvalidPosition(fen, 'Invalid en passant square: $enPassant');
        return false;
      }

      return true;
    } catch (e) {
      sendInvalidPosition(fen, 'FEN validation error: $e');
      return false;
    }
  }

  void ensureMultiPVSize(int size) {
    while (multiPV.length < size) {
      multiPV.add([]);
      multiEval.add(0.0);
    }
  }

  void parseInfoLine(String line) {
    if (line.contains(' pv ')) {
      final depthMatch = RegExp(r'depth (\d+)').firstMatch(line);
      final multipvMatch = RegExp(r'multipv (\d+)').firstMatch(line);

      if (depthMatch != null) {
        final depth = int.parse(depthMatch.group(1)!);
        final multipv = multipvMatch != null ? int.parse(multipvMatch.group(1)!) : 1;

          currentDepth = depth;

        // Extract centipawn score or mate score
        double score = 0.0;
        bool isMateScore = false;
        int mateInValue = 0;

        if (line.contains('score cp ')) {
          final scoreMatch = RegExp(r'score cp (-?\d+)').firstMatch(line);
          if (scoreMatch != null) {
            final centipawns = int.parse(scoreMatch.group(1)!);
            score = centipawns / 100.0;
          }
        } else if (line.contains('score mate ')) {
          final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(line);
          if (mateMatch != null) {
            mateInValue = int.parse(mateMatch.group(1)!);
            isMateScore = true;
            score = mateInValue > 0 ? 999.0 : -999.0;
          }
        }
        
         // Convert evaluation from side-to-move perspective to White's perspective
        bool isWhiteTurn = currentFen.contains(' w ');
        if (!isWhiteTurn) {
          score = -score;
          if (isMateScore) {
            mateInValue = -mateInValue;
          }
        }

        // Extract the principal variation
        final pvMatch = RegExp(r' pv (.+)$').firstMatch(line);
        if (pvMatch != null) {
          final moves = pvMatch.group(1)!.split(' ');

          if (multipv == 1) {
            evaluation = score;
            isMate = isMateScore;
            mateIn = mateInValue;
            principalVariation = moves;
            bestMove = moves.isNotEmpty ? moves[0] : '';
            ensureMultiPVSize(3);
            multiPV[0] = moves;
            multiEval[0] = isMateScore ? "M${mateInValue.abs()}" : score;
          } else if (multipv <= 3) {
            ensureMultiPVSize(3);
            multiPV[multipv - 1] = moves;
            multiEval[multipv - 1] = isMateScore ? "M${mateInValue.abs()}" : score;
          }

          sendAnalysis();
        }
      }
    }
  }

  void processEngineLine(String line) {
    try {
      if (line.contains('info') && line.contains('depth')) {
        parseInfoLine(line);
      } else if (line.startsWith('bestmove')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            bestMove = parts[1];
            sendAnalysis();
        }
      } else if (line.trim() == 'readyok') {
        if (!engineReady) {
          engineReady = true;
          engineInitializing = false;
          engineTimeout?.cancel();
          sendDebug('SUCCESS: Engine is ready');
          mainSendPort.send({'type': 'engine_ready'});
          
          engineKeepAlive?.cancel();
          engineKeepAlive = Timer.periodic(Duration(seconds: 30), (timer) {
            if (engine != null && engineReady) {
              try {
                engine!.stdin = 'isready';
              } catch (e) {
                sendDebug('Keep-alive failed: $e');
                timer.cancel();
              }
            }
          });
        }
      } else if (line.contains('Stockfish') || line.contains('uciok')) {
        sendDebug('Engine response: $line');
      }
    } catch (e) {
      sendError('Error processing engine line: $e');
    }
  }

  // Define recoverFromCrash first
  recoverFromCrash = () async {
    if (isRecovering) return;
    
    isRecovering = true;
    crashCount++;
    
    sendDebug('Engine crashed (attempt $crashCount/$maxCrashes). Attempting recovery...');
    
    if (crashCount >= maxCrashes) {
      sendError('Engine has crashed $maxCrashes times. Cannot recover.');
      isRecovering = false;
      return;
    }

    // Clean up crashed engine
    try {
      engine?.dispose();
    } catch (e) {
      if (kDebugMode) debugPrint('Error disposing crashed engine: $e');
    }
    
    engine = null;
    engineReady = false;
    engineInitializing = false;
    
    // Wait before restart
    await Future.delayed(Duration(seconds: 2));
    
    // Restart engine
    try {
      await initializeEngine();
      sendDebug('SUCCESS: Engine recovered successfully');
      crashCount = 0; // Reset crash count on successful recovery
    } catch (e) {
      sendError('Failed to recover engine: $e');
    }
    
    isRecovering = false;
  };

  // Define initializeEngine second
  initializeEngine = () async {
    if (engine != null || engineInitializing) {
      sendDebug('Engine already exists or is initializing');
      return;
    }

    engineInitializing = true;
    sendDebug('Initializing engine in isolate');

    try {
      engine = Stockfish();

      engine!.stdout.listen((line) {
        processEngineLine(line);
      }, onError: (error) {
        sendError('Engine stdout error: $error');
        // Don't auto-recover on stdout errors, they might be temporary
      }, onDone: () {
        sendDebug('Engine stdout closed unexpectedly');
        if (!isRecovering) {
          recoverFromCrash();
        }
      });

      // Set timeout for engine initialization
      engineTimeout = Timer(Duration(seconds: 20), () {
        if (!engineReady) {
          sendError('Engine initialization timeout after 20 seconds');
        }
      });

      // Send UCI commands with proper sequencing and delays
      sendDebug('Sending UCI commands...');
      
      // Initial UCI command
      Future.delayed(Duration(milliseconds: 200), () {
        if (engine != null) {
          try {
            engine!.stdin = 'uci';
            sendDebug('Sent: uci');
          } catch (e) {
            sendError('Failed to send uci: $e');
            return;
          }

          // Wait for uciok, then send options
          Future.delayed(Duration(milliseconds: 500), () {
            if (engine != null) {
              try {
                engine!.stdin = 'setoption name Threads value 1';
                sendDebug('Sent: setoption name Threads value 1');
                
                engine!.stdin = 'setoption name Hash value 64';
                sendDebug('Sent: setoption name Hash value 64');
                
                engine!.stdin = 'setoption name MultiPV value 3';
                sendDebug('Sent: setoption name MultiPV value 3');
                
                // Final isready check
                Future.delayed(Duration(milliseconds: 200), () {
                  if (engine != null) {
                    try {
                      engine!.stdin = 'isready';
                      sendDebug('Sent: isready');
                    } catch (e) {
                      sendError('Failed to send isready: $e');
                    }
                  }
                });
              } catch (e) {
                sendError('Failed to send options: $e');
              }
            }
          });
        }
      });

    } catch (e) {
      engineInitializing = false;
      sendError('Failed to create engine: $e');
      if (!isRecovering) {
        recoverFromCrash();
      }
    }
  };

  receivePort.listen((message) {
    try {
      if (message is String) {
        if (message == 'init') {
          sendDebug('Received init command');
          initializeEngine();

        } else if (message == 'stop') {
          if (engine != null && engineReady) {
            try {
              sendDebug('STOP_RECEIVED: Stopping analysis');
              engine!.stdin = 'stop';
              sendDebug('Analysis stopped');
            } catch (e) {
              sendError('Failed to stop analysis: $e');
            }
          }

        } else if (message == 'dispose') {
          sendDebug('Disposing engine...');
          engineTimeout?.cancel();
          engineKeepAlive?.cancel();
          if (engine != null) {
            try {
              if (engineReady) {
                engine!.stdin = 'quit';
              }
              engine!.dispose();
            } catch (e) {
              sendDebug('Error disposing engine: $e');
            }
            engine = null;
            engineReady = false;
            engineInitializing = false;
          }
        }
      } else if (message is Map<String, dynamic>) {
        if (message['type'] == 'analyze') {
          currentFen = message['fen'] as String? ?? '';
          currentAnalysisId = message['id'] as int? ?? currentAnalysisId + 1;

          // Validate FEN before sending to Stockfish
          if (!validateFenForStockfish(currentFen)) {
            sendDebug('FEN validation failed, analysis skipped');
            return;
          }

          if (engine != null && engineReady) {
            sendDebug('GO_START: ' + currentFen);

            // Reset state
            evaluation = 0.0;
            isMate = false;
            mateIn = 0;
            bestMove = '';
            principalVariation = [];
            multiPV = [];
            multiEval = [];
            currentDepth = 0;

            // Start analysis
            try {
              sendDebug('GO_STOP: Sending stop command');
              engine!.stdin = 'stop';
              Future.delayed(Duration(milliseconds: 150), () {
                try {
                  if (engine != null && engineReady && !isRecovering) {
                    try {
                      sendDebug('GO_POSITION: Setting position');
                      engine!.stdin = 'position fen $currentFen';
                      sendDebug('GO_INFINITE: Starting infinite search');
                      engine!.stdin = 'go infinite';
                      sendDebug('Analysis started safely');
                    } catch (positionError) {
                              sendError('Position command failed: $positionError');
                      sendInvalidPosition(currentFen, 'Engine rejected position: $positionError');
                      if (!isRecovering) {
                        recoverFromCrash();
                      }
                    }
                  } else {
                        }
                } catch (e) {
                      sendError('Failed to set position: $e');
                  if (!isRecovering) {
                    recoverFromCrash();
                  }
                }
              });
            } catch (e) {
              sendError('Failed to start analysis: $e');
              if (!isRecovering) {
                recoverFromCrash();
              }
            }
          } else {
            sendError('Engine not ready for analysis (ready: $engineReady, engine: ${engine != null})');
          }
        } else if (message['type'] == 'validate_fen') {
          final fen = message['fen'] as String;
          final responsePort = message['responsePort'] as SendPort;

          final isValid = validateFenForStockfish(fen);
          responsePort.send({
            'type': 'validation_result',
            'isValid': isValid,
          });
        }
      }
    } catch (e) {
      sendError('Error handling message: $e');
      if (!isRecovering && e.toString().contains('crash')) {
        recoverFromCrash();
      }
    }
  }, onError: (error) {
    sendError('Receive port error: $error');
    if (!isRecovering) {
      recoverFromCrash();
    }
  });
}