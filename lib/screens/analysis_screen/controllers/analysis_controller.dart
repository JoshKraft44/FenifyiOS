import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../../../services/stockfish/stockfish_service.dart';
import '../../../models/chess_position.dart';
import '../../../services/storage_service.dart';
import '../../../services/chess_move_detector.dart';
import '../../../services/san_converter.dart';
import '../../../providers/theme_provider.dart';
import '../../saved_positions_screen/saved_positions_screen.dart';
import '../models/analysis_state.dart';
import '../widgets/variation_tree_widget.dart';
import 'dart:async';
import '../../../constants/app_colors.dart';
import 'dart:math' as math;
import '../../../utils/analysis_throttler.dart';

class AnalysisController {
  final String initialFen;
  final VoidCallback onStateChanged;
  
  // Services
  late final StockfishService _stockfishService;
  final StorageService _storageService = StorageService();
  late final ChessMoveDetector _moveDetector;
  final SanConverter _sanConverter = SanConverter();

  // State
  AnalysisState _state = AnalysisState();
  bool _disposed = false;
  StreamSubscription<Map<String, dynamic>>? _analysisSubscription;
  Timer? _retryTimer;
  Timer? _debounceTimer;
  int _currentAnalysisId = 0;
  DateTime? _lastAnalysisStart;
  String? _lastAnalyzedFen;

  // Power-saving components
  AnalysisThrottler? _throttler;
  FenDebouncer? _fenDebouncer;
  StateBatcher? _stateBatcher;
  bool _isAppInBackground = false;
  bool _isAnalysisViewVisible = true;
  int _multiPVLines = 1; // Default to 1 line for power saving
  bool _showAllVariations = false;

  Position? _position;
  chess_lib.Chess? _chess;

  // Variation tree state
  MoveNode? _variationTreeRoot;
  MoveNode? _currentVariationNode;


  AnalysisController({
    required this.initialFen,
    required this.onStateChanged,
  }) {
    _stockfishService = StockfishService();
    _moveDetector = ChessMoveDetector();

    // Initialize power-saving components
    _throttler = AnalysisThrottler(updatesPerSecond: 8);
    _fenDebouncer = FenDebouncer(delay: const Duration(milliseconds: 300));
    _stateBatcher = StateBatcher(
      onFlush: _notifyStateChanged,
      batchWindow: const Duration(milliseconds: 16),
    );
  }

  // Getters for state
  bool get isInitializing => _state.isInitializing;
  bool get isAnalyzing => _state.isAnalyzing;
  bool get hasError => _state.hasError;
  bool get engineReady => _state.engineReady;
  bool get isInvalidPosition => _state.isInvalidPosition;
  bool get boardFlipped => _state.boardFlipped;
  bool get showArrows => _state.showArrows;
  bool get awaitingPromotion => _state.awaitingPromotion;
  bool get showAllVariations => _showAllVariations;
  int get multiPVLines => _multiPVLines;

  String get currentFen => _state.currentFen;
  String get originalFen => _state.originalFen;
  String get analysisText => _state.analysisText;
  String? get lastError => _state.lastError;
  String get bestMove => _state.bestMove;
  
  int get currentMoveIndex => _state.currentMoveIndex;
  int get gameHistoryLength => _state.gameHistory.length;
  int get currentDepth => _state.currentDepth;
  int get mateInMoves => _state.mateInMoves;
  
  double get evaluationScore => _state.evaluationScore;
  bool get isMateScore => _state.isMateScore;
  
  List<String> get principalVariation => _state.principalVariation;
  List<String> get moveEvaluations => _state.moveEvaluations;
  List<List<String>> get multiPV => _state.multiPV;
  Set<Square> get highlightedSquares => _state.highlightedSquares;
  ISet<Shape> get boardShapes => _state.boardShapes;
  Move? get pendingPromotionMove => _state.pendingPromotionMove;
  Position? get position => _position;
  chess_lib.Chess? get chess => _chess;
  MoveNode? get currentVariationNode => _currentVariationNode;
  MoveNode? get variationTreeRoot => _variationTreeRoot;

  Future<void> initialize() async {
    if (_disposed) return;

    // Reset analysis state for new position
    _currentAnalysisId = 0;
    _lastAnalysisStart = null;
    _lastAnalyzedFen = null;
    
    // Cancel any existing timers and subscriptions
    _retryTimer?.cancel();
    _debounceTimer?.cancel();
    await _analysisSubscription?.cancel();
    _analysisSubscription = null;

    _state = _state.copyWith(
      originalFen: initialFen.isNotEmpty ? initialFen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      currentFen: initialFen.isNotEmpty ? initialFen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );
    
    if (kDebugMode) debugPrint('INIT: Fresh controller initialization - Analysis ID reset to 0');

    try {
      await _initializePositions();
      _initializeVariationTree();
      _notifyStateChanged();
      
      // Check state after initialization is complete (no timer race condition)
      if (!_disposed) {
        if (_state.isInvalidPosition) {
          _state = _state.copyWith(
            isInitializing: false,
            analysisText: "This position violates chess rules and cannot be analyzed.",
            isAnalyzing: false,
            hasError: false,
          );
          _notifyStateChanged();
        } else {
          // Small delay to allow UI to update, then start analysis
          await Future.delayed(const Duration(milliseconds: 100));
          if (!_disposed) {
            _initializeAndStartAnalysis();
          }
        }
      }
    } catch (e) {
      _setError('Failed to initialize position: $e');
    }
  }

  Future<void> _initializePositions() async {
    final startingFen = _state.currentFen;
    
    try {
      final cleanFen = startingFen.replaceAll(RegExp(r' INVALID_\w+'), '');
      
      // Initialize chess engines
      _chess = chess_lib.Chess.fromFEN(cleanFen);
      
      final setup = Setup.parseFen(cleanFen);
      if (setup == null) {
        throw Exception('Invalid FEN format');
      }
      
      _position = Position.setupPosition(Rule.chess, setup);
      
      final canonicalFen = _position!.fen;
      if (kDebugMode) debugPrint('INIT: Original FEN: $cleanFen');
      if (kDebugMode) debugPrint('INIT: Canonical FEN: $canonicalFen');
      
      // Clear all analysis state when initializing new position
      _state = _state.copyWith(
        currentFen: canonicalFen,  // Use canonical FEN
        gameHistory: [{'fen': canonicalFen}],  // Store canonical FEN
        currentMoveIndex: 0,
        isInvalidPosition: false,
        // Clear analysis state
        evaluationScore: 0.0,
        isMateScore: false,
        mateInMoves: 0,
        bestMove: '',
        bestMoveUci: '',
        showBestMove: false,
        currentDepth: 0,
        principalVariation: <String>[],
        moveEvaluations: <String>[],
        multiPV: <List<String>>[],
        highlightedSquares: <Square>{},
        boardShapes: <Shape>{}.lock,
        lastMoveFrom: null,
        lastMoveTo: null,
        isAnalyzing: false,
        hasError: false,
        analysisText: "Position loaded. Starting analysis...",
      );

      if (kDebugMode) debugPrint('Initialized with canonical FEN: $canonicalFen');
    } catch (e) {
      if (kDebugMode) debugPrint('Position is invalid but preserving for editing: $e');
      
      _state = _state.copyWith(
        isInvalidPosition: true,
        currentFen: startingFen,
        gameHistory: [{'fen': startingFen}],
        currentMoveIndex: 0,
        // Clear analysis state for invalid positions too
        evaluationScore: 0.0,
        isMateScore: false,
        mateInMoves: 0,
        bestMove: '',
        bestMoveUci: '',
        showBestMove: false,
        currentDepth: 0,
        principalVariation: <String>[],
        moveEvaluations: <String>[],
        multiPV: <List<String>>[],
        highlightedSquares: <Square>{},
        boardShapes: <Shape>{}.lock,
        lastMoveFrom: null,
        lastMoveTo: null,
        isAnalyzing: false,
        hasError: false,
      );
      
      // For invalid positions, try to create a chess_lib.Chess object that can display the FEN
      try {
        // Create a fallback chess object that shows the invalid position
        _chess = chess_lib.Chess.fromFEN('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
        // Then manually set the FEN to the invalid one for display purposes
        // This is a workaround to show the invalid position on the board
        final fallbackSetup = Setup.parseFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
        if (fallbackSetup != null) {
          _position = Position.setupPosition(Rule.chess, fallbackSetup);
        }
      } catch (fallbackError) {
        throw Exception('Critical error: Cannot create valid chess position');
      }
    }
  }

  void _initializeVariationTree() {
    try {
      final startingFen = _state.currentFen;
      _variationTreeRoot = MoveNode.fromFen(startingFen);
      _currentVariationNode = _variationTreeRoot;
      if (kDebugMode) debugPrint('VARIATION_TREE: Initialized with FEN: $startingFen');
    } catch (e) {
      if (kDebugMode) debugPrint('VARIATION_TREE: Failed to initialize: $e');
      _variationTreeRoot = null;
      _currentVariationNode = null;
    }
  }

  Future<void> _initializeAndStartAnalysis() async {
    if (_disposed || _state.isInvalidPosition) return;

    _state = _state.copyWith(
      isInitializing: true,
      hasError: false,
      analysisText: "Initializing Stockfish engine...",
    );
    _notifyStateChanged();

    try {
      if (kDebugMode) debugPrint('INIT: Starting fresh Stockfish initialization...');
      
      // Restart engine completely for clean state
      if (kDebugMode) debugPrint('INIT: Restarting Stockfish engine for clean state...');

      try {
        await _stockfishService.restartEngine();
        if (kDebugMode) debugPrint('INIT: Engine restart completed successfully');
      } catch (e) {
        if (kDebugMode) debugPrint('INIT: Error during engine restart (continuing): $e');
        // Fallback to just resetting analysis ID and reinitializing
        _stockfishService.resetAnalysisId();
        await _stockfishService.initialize();
      }

      if (_disposed) return;

      if (kDebugMode) debugPrint('SUCCESS: Stockfish initialization completed');
      _state = _state.copyWith(
        engineReady: true,
        isInitializing: false,
        analysisText: "Engine ready. Starting analysis...",
      );
      _notifyStateChanged();

      await Future.delayed(Duration(milliseconds: 1000));
      
      if (!_disposed && !_state.isInvalidPosition) {
        await _startAnalysis();
      }
    } catch (e) {
      if (!_disposed) {
        if (kDebugMode) debugPrint('ERROR: Failed to initialize chess engine: $e');
        _setError('Failed to initialize chess engine: $e');
      }
    }
  }

  Future<void> _startAnalysis() async {
    if (_disposed || !_state.engineReady || _state.isInvalidPosition) {
      return;
    }

    try {
      _state = _state.copyWith(
        isAnalyzing: true,
        analysisText: "Starting analysis...",
        hasError: false,
      );
      _notifyStateChanged();

      // Sync analysis ID with service (it will be incremented when stream starts)
      _currentAnalysisId = _stockfishService.currentAnalysisId + 1;
      if (kDebugMode) debugPrint('INITIAL: Starting initial analysis session ID: $_currentAnalysisId');
      
      // Get Fen
      final currentFen = _position?.fen ?? _state.currentFen;
      if (kDebugMode) debugPrint('INITIAL: Starting analysis for FEN: $currentFen (MultiPV: $_multiPVLines)');

      final analysisStream = _stockfishService.startContinuousAnalysis(
        currentFen,
        multiPVLines: _multiPVLines,
      );

      // Feed analysis stream to throttler and subscribe to throttled output
      final rawSubscription = analysisStream.listen((data) {
        if (_throttler != null && !_disposed) {
          _throttler!.add(data);
        }
      });

      _analysisSubscription = _throttler!.stream.listen(
        (analysisData) {
          if (_disposed) return;

          // Double-check analysis ID to prevent processing stale data
          final analysisId = analysisData['analysisId'];
          if (analysisId != null && analysisId != _currentAnalysisId) {
            if (kDebugMode) debugPrint('INITIAL: Dropping stale initial analysis data for ID: $analysisId (current: $_currentAnalysisId)');
            return;
          }

          try {
            _parseAnalysisData(analysisData);
            _state = _state.copyWith(
              analysisText: "Analysis running...",
              hasError: false,
            );
            _updateBestMoveHighlight();
            _updateBestMoveArrows();
            // Use state batcher to coalesce updates
            _stateBatcher?.markNeedsUpdate();
          } catch (e) {
            if (!_disposed) {
              _setError('Error processing analysis: $e');
            }
          }
        },
        onError: (error) {
          if (!_disposed) {
            if (kDebugMode) debugPrint('ERROR: Analysis stream error: $error');
            _setError('Analysis failed: $error');
          }
        },
        onDone: () {
          if (!_disposed) {
            if (kDebugMode) debugPrint('INITIAL: Initial analysis stream completed for ID: $_currentAnalysisId');
            _state = _state.copyWith(isAnalyzing: false);
            _notifyStateChanged();
          }
        },
      );
    } catch (e) {
      if (!_disposed) {
        if (kDebugMode) debugPrint('ERROR: Failed to start analysis: $e');
        _setError('Failed to start analysis: $e');
      }
    }
  }

  void _parseAnalysisData(Map<String, dynamic> data) {
    try {
      // Early exit if disposed
      if (_disposed) return;

      if (data['analysisId'] != null && data['analysisId'] != _currentAnalysisId) {
        if (kDebugMode) debugPrint('SYNC: Discarding analysis for stale id: ${data['analysisId']} (current: $_currentAnalysisId)');
        return;
      }

      // Check FEN using canonical dartchess comparison
      if (data['fen'] != null) {
        final incomingFen = data['fen'] as String;
        final currentCanonicalFen = _position?.fen ?? _state.currentFen;
        if (incomingFen != currentCanonicalFen) {
          if (kDebugMode) debugPrint('SYNC: Discarding analysis for stale FEN:');
          if (kDebugMode) debugPrint('  Incoming: $incomingFen');
          if (kDebugMode) debugPrint('  Current:  $currentCanonicalFen');
          if (kDebugMode) debugPrint('  Source: ${_position != null ? "dartchess" : "state"}');
          return;
        }
      }

      if (data.containsKey('invalid_position') && data['invalid_position'] == true) {
        final errorMessage = data['error'] as String? ?? 'Position is invalid';
        _state = _state.copyWith(
          analysisText: "This position violates chess rules and cannot be analyzed.",
          isAnalyzing: false,
          hasError: false,
        );
        return;
      }

      if (data.containsKey('error') && data['error'] == true) {
        throw Exception(data['message'] ?? 'Unknown analysis error');
      }

      final evaluationScore = (data['evaluation'] as num?)?.toDouble() ?? 0.0;
      final isMateScore = data['isMate'] as bool? ?? false;
      final mateInMoves = data['mateIn'] as int? ?? 0;
      final bestMoveUci = data['bestMove'] as String? ?? '';
      final currentDepth = data['depth'] as int? ?? 0;

      // Convert best move from UCI to SAN using dartchess FEN (source of truth)
      final currentFenForSan = _position?.fen ?? _state.currentFen;
      final bestMove = bestMoveUci.isNotEmpty 
          ? _sanConverter.formatBestMoveWithNumber(bestMoveUci, currentFenForSan)
          : '';

      final pvData = data['principalVariation'];
      final principalVariationUci = pvData is List ? pvData.cast<String>() : <String>[];
      
      // Convert principal variation to SAN using dartchess FEN (source of truth)
      final principalVariation = principalVariationUci.isNotEmpty
          ? [_sanConverter.formatPrincipalVariation(principalVariationUci, currentFenForSan)]
          : <String>[];

      final multiPVData = data['multiPV'];
      final multiEvalData = data['multiEval'];

      List<List<String>> multiPV = [];
      List<String> moveEvaluations = [];

      if (multiPVData is List && multiEvalData is List) {
        try {
          // Convert multiPV UCI moves to SAN notation
          multiPV = multiPVData.map((pv) {
            if (pv is List) {
              final uciMoves = pv.cast<String>();
              if (uciMoves.isNotEmpty) {
                // Convert to SAN and format as a single string using dartchess FEN
                final sanFormatted = _sanConverter.formatPrincipalVariation(uciMoves, currentFenForSan, maxMoves: 6);
                return sanFormatted.isNotEmpty ? [sanFormatted] : uciMoves;
              }
            }
            return <String>[];
          }).toList();

          // Evaluation parsing to handle both numbers and strings
          moveEvaluations = multiEvalData.map((eval) {
            try {
              if (eval == null) {
                return "0.00";
              } else if (eval is num) {
                // Numeric evaluation
                final evalDouble = eval.toDouble();
                if (evalDouble.abs() > 900) {
                  return "M${evalDouble > 0 ? '+' : '-'}";
                } else {
                  String sign = evalDouble >= 0 ? "+" : "";
                  return "$sign${evalDouble.toStringAsFixed(2)}";
                }
              } else if (eval is String) {
                // String evaluation 
                final trimmed = eval.trim();
                
                // Check if it's already a formatted mate score or evaluation
                if (trimmed.startsWith('M') || 
                    trimmed.contains('mate') || 
                    (trimmed.contains('+') || trimmed.contains('-')) && trimmed.length <= 6) {
                  return trimmed;
                }
                
                // Try to parse as a number
                final parsed = double.tryParse(trimmed);
                if (parsed != null) {
                  if (parsed.abs() > 900) {
                    return "M${parsed > 0 ? '+' : '-'}";
                  } else {
                    String sign = parsed >= 0 ? "+" : "";
                    return "$sign${parsed.toStringAsFixed(2)}";
                  }
                } else {
                  if (kDebugMode) debugPrint('Warning: Could not parse evaluation string: "$eval"');
                  return trimmed.isNotEmpty ? trimmed : "0.00";
                }
              } else {
                if (kDebugMode) debugPrint('Warning: Unexpected evaluation type: ${eval.runtimeType}, value: $eval');
                return "0.00";
              }
            } catch (e) {
              if (kDebugMode) debugPrint('Error parsing individual evaluation: $eval, error: $e');
              return "0.00";
            }
          }).toList();
          
          // print('Successfully parsed ${moveEvaluations.length} evaluations: $moveEvaluations');
        } catch (e) {
          if (kDebugMode) debugPrint('Error parsing multiPV data: $e');
          if (kDebugMode) debugPrint('multiPVData type: ${multiPVData.runtimeType}, length: ${multiPVData.length}');
          if (kDebugMode) debugPrint('multiEvalData type: ${multiEvalData.runtimeType}, length: ${multiEvalData.length}');
          if (multiEvalData.isNotEmpty) {
            if (kDebugMode) debugPrint('Sample multiEval items:');
            for (int i = 0; i < math.min(3, multiEvalData.length); i++) {
              if (kDebugMode) debugPrint('  [$i]: ${multiEvalData[i]} (type: ${multiEvalData[i].runtimeType})');
            }
          }
          multiPV = [];
          moveEvaluations = [];
        }
      }

      _state = _state.copyWith(
        evaluationScore: evaluationScore,
        isMateScore: isMateScore,
        mateInMoves: mateInMoves,
        bestMove: bestMove,
        bestMoveUci: bestMoveUci,
        showBestMove: bestMove.isNotEmpty,
        currentDepth: currentDepth,
        principalVariation: principalVariation,
        multiPV: multiPV,
        moveEvaluations: moveEvaluations,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _parseAnalysisData: $e');
      throw Exception('Failed to parse analysis data: $e');
    }
  }

  void _updateBestMoveHighlight() {
    final highlightedSquares = <Square>{};
    Square? lastMoveFrom;
    Square? lastMoveTo;
    
    if (_state.bestMoveUci.isNotEmpty && _state.bestMoveUci.length >= 4) {
      try {
        final fromSquare = Square.fromName(_state.bestMoveUci.substring(0, 2));
        final toSquare = Square.fromName(_state.bestMoveUci.substring(2, 4));

        highlightedSquares.add(fromSquare);
        highlightedSquares.add(toSquare);
        lastMoveFrom = fromSquare;
        lastMoveTo = toSquare;
      } catch (e) {
        if (kDebugMode) debugPrint('Error creating move highlight: $e');
      }
    }
    
    // Add check highlighting
    if (_position?.isCheck == true) {
      final kingSquare = _findKingSquare(_position!.turn);
      if (kingSquare != null) {
        highlightedSquares.add(kingSquare);
      }
    }

    _state = _state.copyWith(
      highlightedSquares: highlightedSquares,
      lastMoveFrom: lastMoveFrom,
      lastMoveTo: lastMoveTo,
    );
  }

  void _updateBestMoveArrows({Color? arrowColor}) {
    if (!_state.showArrows) {
      _state = _state.copyWith(boardShapes: <Shape>{}.lock);
      return;
    }

    final shapes = <Shape>[];
    
    // Add best move arrow
    if (_state.bestMoveUci.isNotEmpty && _state.bestMoveUci.length >= 4) {
      try {
        final fromSquare = Square.fromName(_state.bestMoveUci.substring(0, 2));
        final toSquare = Square.fromName(_state.bestMoveUci.substring(2, 4));
        
        final bestMoveArrow = Arrow(
          orig: fromSquare,
          dest: toSquare,
          color: arrowColor ?? AppColors.successGreen,
          scale: 1.0,
        );
        
        shapes.add(bestMoveArrow);
        // print('Added best move arrow: ${fromSquare.name} -> ${toSquare.name}');
      } catch (e) {
        if (kDebugMode) debugPrint('Error creating best move arrow: $e');
      }
    }
    
    _state = _state.copyWith(boardShapes: shapes.toISet());
  }

  Square? _findKingSquare(Side color) {
    if (_position == null) return null;
    
    for (int file = 0; file < 8; file++) {
      for (int rank = 0; rank < 8; rank++) {
        final square = Square.fromCoords(File.values[file], Rank.values[rank]);
        final piece = _position!.board.pieceAt(square);
        
        if (piece != null && 
            piece.role == Role.king && 
            piece.color == color) {
          return square;
        }
      }
    }
    return null;
  }

  void _setError(String error) {
    if (_disposed) return;
    _state = _state.copyWith(
      hasError: true,
      lastError: error,
      analysisText: error,
      isAnalyzing: false,
      isInitializing: false,
    );
    _notifyStateChanged();
  }

  void _notifyStateChanged() {
    if (!_disposed) {
      onStateChanged();
    }
  }

  // Public methods for UI interactions
  void toggleBoardFlip() {
    _state = _state.copyWith(boardFlipped: !_state.boardFlipped);
    _notifyStateChanged();
  }

  void toggleArrows() {
    _state = _state.copyWith(showArrows: !_state.showArrows);
    _updateBestMoveArrows();
    _notifyStateChanged();
  }

  /// Toggle showing all variations (1 line vs 3 lines)
  /// This is a major power-saving feature
  void toggleShowAllVariations() {
    _showAllVariations = !_showAllVariations;
    _multiPVLines = _showAllVariations ? 3 : 1;

    if (kDebugMode) {
      debugPrint('POWER_SAVE: MultiPV toggled to $_multiPVLines lines');
      debugPrint('POWER_SAVE: CPU load ${_showAllVariations ? "increased" : "reduced"} by ~66%');
    }

    // Restart analysis with new MultiPV setting
    if (_state.engineReady && !_state.isInvalidPosition) {
      _analyzePosition();
    }
    _notifyStateChanged();
  }

  /// Updates arrow colors based on current theme
  void updateArrowsForTheme(BuildContext context) {
    Color arrowColor;
    if (context.isDarkMode) {
      // More translucent muted dark blue for dark mode
      arrowColor = const Color(0xCC4A7C8A); // Semi-transparent muted dark blue
    } else {
      // Translucent charcoal for light mode  
      arrowColor = const Color(0x80404040); // Semi-transparent dark gray
    }
    
    _updateBestMoveArrows(arrowColor: arrowColor);
    _notifyStateChanged();
  }

  /// Pause analysis (called when app goes to background or view is hidden)
  Future<void> pauseAnalysis() async {
    try {
      if (kDebugMode) debugPrint('POWER_SAVE: Pausing analysis');
      await _analysisSubscription?.cancel();
      if (_stockfishService.isAnalyzing) {
        await _stockfishService.stopAnalysis();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error pausing analysis: $e');
    }
  }

  /// Resume analysis (called when app returns to foreground and view is visible)
  Future<void> resumeAnalysis() async {
    if (_state.engineReady && !_state.isAnalyzing && !_state.hasError && !_state.isInvalidPosition) {
      if (kDebugMode) debugPrint('POWER_SAVE: Resuming analysis');
      await _analyzePosition();
    }
  }

  /// Handle app lifecycle changes
  void onAppLifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is going to background - suspend all analysis
        _isAppInBackground = true;
        if (kDebugMode) debugPrint('POWER_SAVE: App going to background, killing analysis');
        pauseAnalysis();
        break;
      case AppLifecycleState.resumed:
        // App is returning to foreground
        _isAppInBackground = false;
        if (kDebugMode) debugPrint('POWER_SAVE: App resumed to foreground');
        if (_isAnalysisViewVisible) {
          resumeAnalysis();
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Set visibility of analysis view
  void setAnalysisViewVisible(bool visible) {
    _isAnalysisViewVisible = visible;
    if (kDebugMode) debugPrint('POWER_SAVE: Analysis view visibility: $visible');

    if (visible && !_isAppInBackground) {
      // View became visible and app is in foreground - resume analysis
      resumeAnalysis();
    } else if (!visible) {
      // View is no longer visible - suspend analysis
      pauseAnalysis();
    }
  }

  Future<void> restartAnalysis() async {
    await _initializeAndStartAnalysis();
  }

  Future<void> _analyzePosition() async {
    if (_disposed || !_state.engineReady || _state.isInvalidPosition) return;

    // Don't start analysis if app is in background or view is not visible
    if (_isAppInBackground || !_isAnalysisViewVisible) {
      if (kDebugMode) debugPrint('POWER_SAVE: Skipping analysis (background=$_isAppInBackground, visible=$_isAnalysisViewVisible)');
      return;
    }

    final currentFen = _position?.fen ?? _state.currentFen;

    // Use FenDebouncer for power-efficient debouncing (~300ms)
    _fenDebouncer?.debounce(() async {
      if (!_disposed && !_isAppInBackground && _isAnalysisViewVisible) {
        await _performAnalysisNow();
      }
    });
  }

  /// Safely analyze position after moves by ensuring previous analysis is fully stopped
  Future<void> _analyzePositionSafely() async {
    if (_disposed || !_state.engineReady || _state.isInvalidPosition) return;

    // Force stop any current analysis immediately
    if (_state.isAnalyzing) {
      try {
        await _analysisSubscription?.cancel();
        _analysisSubscription = null;
        
        if (_stockfishService.isAnalyzing) {
          await _stockfishService.stopAnalysis();
        }
        
        // Reset analysis state
        _lastAnalyzedFen = null;
        
        // Very short delay to let Stockfish process the stop command
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        if (kDebugMode) debugPrint('Error stopping analysis safely: $e');
      }
    }

    // Now start fresh analysis
    if (!_disposed) {
      await _performAnalysisNow();
    }
  }

  Future<void> _performAnalysisNow() async {
    if (_disposed || !_state.engineReady || _state.isInvalidPosition) return;

    // Get current FEN
    final currentFen = _position?.fen ?? _state.currentFen;
    final fenParts = currentFen.split(' ');
    final currentTurn = fenParts.length > 1 ? fenParts[1] : 'unknown';

    if (kDebugMode) debugPrint('CONTROLLER_ANALYSIS: Starting analysis for FEN=$currentFen, Turn=$currentTurn');
    
    // Simplified deduplication check
    if (_state.isAnalyzing && _lastAnalyzedFen == currentFen) {
      if (kDebugMode) debugPrint('ANALYSIS: Already analyzing FEN: $currentFen, skipping duplicate request');
      return;
    }


    // Get current analysis ID from service (incremented when stream starts)
    _currentAnalysisId = _stockfishService.currentAnalysisId + 1;
    if (kDebugMode) debugPrint('ANALYSIS: Starting new analysis session ID: $_currentAnalysisId');

    _retryTimer?.cancel();
    await _analysisSubscription?.cancel();
    _analysisSubscription = null;
    _lastAnalyzedFen = null; // Clear to prevent duplicate detection

    if (_stockfishService.isAnalyzing) {
      try {
        if (kDebugMode) debugPrint('ANALYSIS: Stopping previous analysis...');
        await _stockfishService.stopAnalysis();
        // Give Stockfish time to actually stop before starting new analysis
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        if (kDebugMode) debugPrint('ANALYSIS: Error stopping previous analysis: $e');
      }
    }

    if (_disposed) return;

    // Clear ALL analysis state when starting new analysis
    _state = _state.copyWith(
      isAnalyzing: true,
      analysisText: "Analyzing position...",
      showBestMove: false,
      highlightedSquares: <Square>{},
      boardShapes: <Shape>{}.lock,
      hasError: false,
      // Clear all analysis data
      evaluationScore: 0.0,
      isMateScore: false,
      mateInMoves: 0,
      bestMove: '',
      bestMoveUci: '',
      currentDepth: 0,
      principalVariation: <String>[],
      moveEvaluations: <String>[],
      multiPV: <List<String>>[],
      lastMoveFrom: null,
      lastMoveTo: null,
    );
    _notifyStateChanged();

    try {
      // Get FEN
      final currentFen = _position?.fen ?? _state.currentFen;
      if (kDebugMode) debugPrint('ANALYSIS: Starting analysis for canonical FEN: $currentFen (MultiPV: $_multiPVLines)');

      // Set the FEN being analyzed
      _lastAnalyzedFen = currentFen;

      final analysisStream = _stockfishService.startContinuousAnalysis(
        currentFen,
        multiPVLines: _multiPVLines,
      );
      // StockfishService increments its analysis ID when the returned stream is istened to
      final expectedStockfishId = _stockfishService.currentAnalysisId + 1;
      if (expectedStockfishId != _currentAnalysisId) {
        if (kDebugMode) debugPrint('ANALYSIS: ID mismatch - Controller: $_currentAnalysisId, Expected Stockfish: $expectedStockfishId');
      }


      // Feed analysis stream to throttler and subscribe to throttled output
      final rawSubscription2 = analysisStream.listen((data) {
        if (_throttler != null && !_disposed) {
          _throttler!.add(data);
        }
      });

      _analysisSubscription = _throttler!.stream.listen(
        (analysisData) {
          if (_disposed) return;

          // Double-check analysis ID to prevent processing stale data
          final analysisId = analysisData['analysisId'];
          if (analysisId != null && analysisId != _currentAnalysisId) {
            if (kDebugMode) debugPrint('ANALYSIS: Dropping stale analysis data for ID: $analysisId (current: $_currentAnalysisId)');
            return;
          }

          try {
            _parseAnalysisData(analysisData);
            _state = _state.copyWith(hasError: false);
            _updateBestMoveHighlight();
            _updateBestMoveArrows();
            // Use state batcher to coalesce updates
            _stateBatcher?.markNeedsUpdate();
          } catch (e) {
            if (!_disposed) {
              _setError('Error processing analysis: $e');
            }
          }
        },
        onError: (error) {
          if (!_disposed) {
            _setError('Analysis failed: $error');
          }
        },
        onDone: () {
          if (!_disposed) {
            if (kDebugMode) debugPrint('ANALYSIS: Stream completed for ID: $_currentAnalysisId');
            _state = _state.copyWith(isAnalyzing: false);
            _lastAnalyzedFen = null; // Clear to allow new analysis
            _notifyStateChanged();
          }
        },
      );
    } catch (e) {
      if (!_disposed) {
        _setError('Analysis error: $e');
      }
    }
  }

  // Navigation methods
  void goToStart() {
    if (_state.isInvalidPosition || _state.gameHistory.isEmpty) return;
    
    try {
      final historicalFen = _state.gameHistory.first['fen'] as String;
      if (kDebugMode) debugPrint('🏁 NAV: Going to start - Historical FEN: $historicalFen');
      
      // Parse with dartchess to get canonical FEN
      final setup = Setup.parseFen(historicalFen);
      if (setup == null) {
        if (kDebugMode) debugPrint('NAV: Invalid FEN in history: $historicalFen');
        return;
      }
      
      // Create canonical position and FEN
      _position = Position.setupPosition(Rule.chess, setup);
      final canonicalFen = _position!.fen;
      if (kDebugMode) debugPrint('NAV: Canonical FEN: $canonicalFen');
      if (kDebugMode) debugPrint('NAV: FEN normalization: ${historicalFen == canonicalFen ? "identical" : "normalized"}');
      
      // Sync chess_lib to canonical FEN
      try {
        _chess = chess_lib.Chess.fromFEN(canonicalFen);
      } catch (e) {
        if (kDebugMode) debugPrint('Warning: Could not sync chess_lib: $e');
      }
      
      // Update variation tree to root
      if (_variationTreeRoot != null) {
        _currentVariationNode = _variationTreeRoot;
      }

      // Update state with canonical FEN
      _state = _state.copyWith(
        currentMoveIndex: 0,
        currentFen: canonicalFen,  // Use canonical FEN, not historical
        showBestMove: false,
        highlightedSquares: <Square>{},
        boardShapes: <Shape>{}.lock,
        // Clear analysis data
        evaluationScore: 0.0,
        isMateScore: false,
        mateInMoves: 0,
        bestMove: '',
        bestMoveUci: '',
        currentDepth: 0,
        principalVariation: <String>[],
        moveEvaluations: <String>[],
        multiPV: <List<String>>[],
        lastMoveFrom: null,
        lastMoveTo: null,
      );
      
      // Update UI FIRST, then analyze
      _notifyStateChanged();
      
      // Wait a moment for UI to update, then start analysis
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!_disposed) {
          _analyzePosition();
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error going to start: $e');
    }
  }

  void goBackOneMove() {
    if (_state.currentMoveIndex > 0 && !_state.isInvalidPosition) {
      try {
        final newIndex = _state.currentMoveIndex - 1;
        final historicalFen = _state.gameHistory[newIndex]['fen'] as String;
        
        // Parse with dartchess to get canonical FEN
        final setup = Setup.parseFen(historicalFen);
        if (setup == null) {
          if (kDebugMode) debugPrint('Invalid FEN in history: $historicalFen');
          return;
        }
        
        // Create canonical position and FEN
        _position = Position.setupPosition(Rule.chess, setup);
        final canonicalFen = _position!.fen;
        
        // Sync chess_lib to canonical FEN
        try {
          _chess = chess_lib.Chess.fromFEN(canonicalFen);
        } catch (e) {
          if (kDebugMode) debugPrint('Warning: Could not sync chess_lib: $e');
        }

        // Sync variation tree
        _syncVariationTreeWithFen(canonicalFen);

        // Update state with canonical FEN
        _state = _state.copyWith(
          currentMoveIndex: newIndex,
          currentFen: canonicalFen,
          showBestMove: false,
          highlightedSquares: <Square>{},
          boardShapes: <Shape>{}.lock,
          // Clear analysis data
          evaluationScore: 0.0,
          isMateScore: false,
          mateInMoves: 0,
          bestMove: '',
          bestMoveUci: '',
          currentDepth: 0,
          principalVariation: <String>[],
          moveEvaluations: <String>[],
          multiPV: <List<String>>[],
          lastMoveFrom: null,
          lastMoveTo: null,
        );
        
        // Update UI first
        _notifyStateChanged();
        
        // Wait for UI update, then start analysis with proper cleanup
        Future.delayed(const Duration(milliseconds: 150), () async {
          if (!_disposed) {
            // Ensure any previous analysis is fully stopped before starting again
            await _analysisSubscription?.cancel();
            _analysisSubscription = null;
            
            // Reset any stale analysis state
            if (_stockfishService.isAnalyzing) {
              await _stockfishService.stopAnalysis();
            }
            
            _analyzePosition();
          }
        });
      } catch (e) {
        if (kDebugMode) debugPrint('Error going back one move: $e');
      }
    }
  }

  void goForwardOneMove() {
    if (_state.currentMoveIndex < _state.gameHistory.length - 1 && !_state.isInvalidPosition) {
      try {
        final newIndex = _state.currentMoveIndex + 1;
        final historicalFen = _state.gameHistory[newIndex]['fen'] as String;

        // Parse
        final setup = Setup.parseFen(historicalFen);
        if (setup == null) {
          if (kDebugMode) debugPrint('Invalid FEN in history: $historicalFen');
          return;
        }

        // Create canonical position and FEN
        _position = Position.setupPosition(Rule.chess, setup);
        final canonicalFen = _position!.fen;

        // Sync chess_lib to canonical FEN
        try {
          _chess = chess_lib.Chess.fromFEN(canonicalFen);
        } catch (e) {
          if (kDebugMode) debugPrint('Warning: Could not sync chess_lib: $e');
        }

        // Sync variation tree
        _syncVariationTreeWithFen(canonicalFen);

        // Update state with canonical FEN
        _state = _state.copyWith(
          currentMoveIndex: newIndex,
          currentFen: canonicalFen,  // Use canonical FEN
          showBestMove: false,
          highlightedSquares: <Square>{},
          boardShapes: <Shape>{}.lock,
          // Clear analysis data
          evaluationScore: 0.0,
          isMateScore: false,
          mateInMoves: 0,
          bestMove: '',
          bestMoveUci: '',
          currentDepth: 0,
          principalVariation: <String>[],
          moveEvaluations: <String>[],
          multiPV: <List<String>>[],
          lastMoveFrom: null,
          lastMoveTo: null,
        );
        
        // Update UI first
        _notifyStateChanged();
        
        // Wait for UI update, then start analysis with debouncing
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_disposed) {
            _analyzePosition();
          }
        });
      } catch (e) {
        if (kDebugMode) debugPrint('Error going forward one move: $e');
      }
    }
  }

  void goToEnd() {
    if (_state.gameHistory.isNotEmpty && !_state.isInvalidPosition) {
      try {
        final newIndex = _state.gameHistory.length - 1;
        final historicalFen = _state.gameHistory[newIndex]['fen'] as String;

        // Parse with dartchess to get canonical FEN
        final setup = Setup.parseFen(historicalFen);
        if (setup == null) {
          if (kDebugMode) debugPrint('Invalid FEN in history: $historicalFen');
          return;
        }

        // Create canonical position and FEN
        _position = Position.setupPosition(Rule.chess, setup);
        final canonicalFen = _position!.fen;

        // Sync chess_lib to canonical FEN
        try {
          _chess = chess_lib.Chess.fromFEN(canonicalFen);
        } catch (e) {
          if (kDebugMode) debugPrint('Warning: Could not sync chess_lib: $e');
        }

        // Sync variation tree
        _syncVariationTreeWithFen(canonicalFen);

        // Update state with canonical FEN
        _state = _state.copyWith(
          currentMoveIndex: newIndex,
          currentFen: canonicalFen,  // Use canonical FEN
          showBestMove: false,
          highlightedSquares: <Square>{},
          boardShapes: <Shape>{}.lock,
          // Clear analysis data
          evaluationScore: 0.0,
          isMateScore: false,
          mateInMoves: 0,
          bestMove: '',
          bestMoveUci: '',
          currentDepth: 0,
          principalVariation: <String>[],
          moveEvaluations: <String>[],
          multiPV: <List<String>>[],
          lastMoveFrom: null,
          lastMoveTo: null,
        );
        
        // Update UI first
        _notifyStateChanged();
        
        // Wait for UI update, then start analysis with debouncing
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_disposed) {
            _analyzePosition();
          }
        });
      } catch (e) {
        if (kDebugMode) debugPrint('Error going to end: $e');
      }
    }
  }

  // Variation tree methods
  void navigateToVariationNode(MoveNode node) {
    if (_disposed || _state.isInvalidPosition) return;

    try {
      if (kDebugMode) debugPrint('VARIATION_TREE: Navigating to node with FEN: ${node.fen}');

      // Update current variation node for UI synchronization
      _currentVariationNode = node;

      // Find the path from root to this node to build proper game history
      final pathFromRoot = node.getPathFromRoot();

      // Rebuild game history from the variation path
      final newGameHistory = <Map<String, dynamic>>[];
      for (int i = 0; i < pathFromRoot.length; i++) {
        final pathNode = pathFromRoot[i];
        newGameHistory.add({
          'fen': pathNode.fen,
          'move': pathNode.move.toString(),
          'fromSquare': '',
          'toSquare': '',
        });
      }

      // Parse the FEN to update position
      final setup = Setup.parseFen(node.fen);
      if (setup == null) {
        if (kDebugMode) debugPrint('VARIATION_TREE: Invalid FEN in node: ${node.fen}');
        return;
      }

      // Update the position
      _position = Position.setupPosition(Rule.chess, setup);
      final canonicalFen = _position!.fen;

      // Sync chess_lib
      try {
        _chess = chess_lib.Chess.fromFEN(canonicalFen);
      } catch (e) {
        if (kDebugMode) debugPrint('VARIATION_TREE: Could not sync chess_lib: $e');
      }

      // Update state with proper game history
      _state = _state.copyWith(
        currentFen: canonicalFen,
        gameHistory: newGameHistory,
        currentMoveIndex: newGameHistory.length - 1,
        showBestMove: false,
        highlightedSquares: <Square>{},
        boardShapes: <Shape>{}.lock,
        // Clear analysis data for clean restart
        evaluationScore: 0.0,
        isMateScore: false,
        mateInMoves: 0,
        bestMove: '',
        bestMoveUci: '',
        currentDepth: 0,
        principalVariation: <String>[],
        moveEvaluations: <String>[],
        multiPV: <List<String>>[],
        lastMoveFrom: null,
        lastMoveTo: null,
      );

      _notifyStateChanged();

      // Debug navigation state
      if (kDebugMode) {
        debugPrint('VARIATION_TREE: After navigation - currentMoveIndex: ${_state.currentMoveIndex}, gameHistoryLength: ${_state.gameHistory.length}');
        debugPrint('VARIATION_TREE: Can go back: ${_state.currentMoveIndex > 0}, Can go forward: ${_state.currentMoveIndex < _state.gameHistory.length - 1}');
      }

      // Start fresh analysis for the new position
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_disposed) {
          _analyzePositionSafely();
        }
      });

    } catch (e) {
      if (kDebugMode) debugPrint('VARIATION_TREE: Error navigating to node: $e');
    }
  }

  void addMoveToVariationTree(MoveNode parentNode, Move move) {
    if (_disposed || _state.isInvalidPosition || _variationTreeRoot == null) return;

    try {
      if (kDebugMode) debugPrint('VARIATION_TREE: Adding move ${move.toString()} to tree');

      final newNode = parentNode.addMove(move);
      _currentVariationNode = newNode;

      if (kDebugMode) debugPrint('VARIATION_TREE: Move added, new node FEN: ${newNode.fen}');

      _notifyStateChanged();
    } catch (e) {
      if (kDebugMode) debugPrint('VARIATION_TREE: Error adding move to tree: $e');
    }
  }

  void _syncVariationTreeWithFen(String fen) {
    if (_variationTreeRoot != null) {
      final node = _variationTreeRoot!.findByFen(fen);
      if (node != null) {
        _currentVariationNode = node;
        if (kDebugMode) debugPrint('VARIATION_TREE: Synced to node with FEN: $fen');
        if (kDebugMode) debugPrint('VARIATION_TREE: Current node has ${node.variations.length} variations');
      } else {
        if (kDebugMode) debugPrint('VARIATION_TREE: No node found for FEN: $fen');
        if (kDebugMode) debugPrint('VARIATION_TREE: Staying at current node');
      }
    }
  }

  // Move handling methods
  void onMove(NormalMove move, {bool? isDrop}) {
    if (_disposed || _state.isInvalidPosition || _position == null) return;

    try {
      if (kDebugMode && false) debugPrint('Chessground move: ${move.from.name} -> ${move.to.name}');
      
      final piece = _position!.board.pieceAt(move.from);
      if (kDebugMode && false) debugPrint('Piece being moved: ${piece?.role.name} (${piece?.color.name})');
      
      // Check for standard castling move
      final actualMove = _convertCastlingMove(move);
      
      // Check for pawn promotion using dartchess
      final isPromotion = piece != null && 
                         piece.role == Role.pawn && 
                         ((piece.color == Side.white && actualMove.to.rank == Rank.eighth) ||
                          (piece.color == Side.black && actualMove.to.rank == Rank.first));
      
      if (isPromotion) {
        if (kDebugMode && false) debugPrint('Pawn promotion detected');
        _state = _state.copyWith(
          pendingPromotionMove: actualMove,
          awaitingPromotion: true,
        );
        _notifyStateChanged();
        return;
      }
      
      // Validate move
      if (!_position!.isLegal(actualMove)) {
        if (kDebugMode && false) debugPrint('Invalid move attempted: ${actualMove.from.name} -> ${actualMove.to.name}');
        _notifyStateChanged();
        return;
      }
      
      if (kDebugMode && false) debugPrint('Move successful');
      _completeMoveAndAnalyze(actualMove);
      
    } catch (e) {
      if (kDebugMode) debugPrint('Error in onMove: $e');
      _notifyStateChanged();
    }
  }

  /// Convert standard castling destinations to actual castling moves
  /// (g1/c1/g8/c8 -> rook destinations that dartchess expects)
  NormalMove _convertCastlingMove(NormalMove move) {
    final piece = _position!.board.pieceAt(move.from);
    
    // Only convert for king moves
    if (piece?.role != Role.king) {
      return move;
    }
    
    try {
      // Check for standard castling destinations
      if (move.from == Square.e1) {
        // White king castling
        if (move.to == Square.g1) {
          // King-side castling: convert g1 to h1 (rook destination)
          if (kDebugMode) debugPrint('CASTLING: Converting white king-side castle g1 -> h1');
          return NormalMove(from: move.from, to: Square.h1);
        } else if (move.to == Square.c1) {
          // Queen-side castling: convert c1 to a1 (rook destination)
          if (kDebugMode) debugPrint('CASTLING: Converting white queen-side castle c1 -> a1');
          return NormalMove(from: move.from, to: Square.a1);
        }
      } else if (move.from == Square.e8) {
        // Black king castling
        if (move.to == Square.g8) {
          // King-side castling: convert g8 to h8 (rook destination)
          if (kDebugMode) debugPrint('CASTLING: Converting black king-side castle g8 -> h8');
          return NormalMove(from: move.from, to: Square.h8);
        } else if (move.to == Square.c8) {
          // Queen-side castling: convert c8 to a8 (rook destination)
          if (kDebugMode) debugPrint('CASTLING: Converting black queen-side castle c8 -> a8');
          return NormalMove(from: move.from, to: Square.a8);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error converting castling move: $e');
    }
    
    // Return original move if not a standard castling destination
    return move;
  }

  void onPromotionSelection(Role? role) {
    if (_disposed || !_state.awaitingPromotion || _state.pendingPromotionMove == null || role == null) return;

    try {
      if (kDebugMode && false) debugPrint('Promotion selected: ${role.name}');
      
      final move = _state.pendingPromotionMove;
      if (move is! NormalMove) {
        if (kDebugMode) debugPrint('Invalid promotion move type');
        _state = _state.copyWith(
          awaitingPromotion: false,
          pendingPromotionMove: null,
        );
        _notifyStateChanged();
        return;
      }
      
      // Create promotion move
      final promotionMove = NormalMove(
        from: move.from,
        to: move.to,
        promotion: role,
      );
      
      // Validate promotion move 
      if (!_position!.isLegal(promotionMove)) {
        if (kDebugMode) debugPrint('Invalid promotion move');
        _state = _state.copyWith(
          awaitingPromotion: false,
          pendingPromotionMove: null,
        );
        _notifyStateChanged();
        return;
      }
      
      _completeMoveAndAnalyze(promotionMove);
      
    } catch (e) {
      if (kDebugMode) debugPrint('Error in promotion: $e');
      _state = _state.copyWith(
        awaitingPromotion: false,
        pendingPromotionMove: null,
      );
      _notifyStateChanged();
    }
  }

  void _completeMoveAndAnalyze(Move move) {
    if (_position == null) return;
    
    try {
      _position = _position!.play(move);
      final canonicalFen = _position!.fen;
      if (kDebugMode) debugPrint('MOVE: Move made, new canonical FEN: $canonicalFen');
      
      // Sync chess_lib for UI display only
      if (_chess != null) {
        try {
          _chess = chess_lib.Chess.fromFEN(canonicalFen);
          if (kDebugMode) debugPrint('MOVE: chess_lib synced successfully');
        } catch (e) {
          if (kDebugMode) debugPrint('MOVE: Could not sync chess_lib for UI: $e');
          // Continue without chess_lib if sync fails
        }
      }
      
      // Add move to history
      final gameHistory = List<Map<String, dynamic>>.from(_state.gameHistory);
      if (_state.currentMoveIndex < gameHistory.length - 1) {
        gameHistory.removeRange(_state.currentMoveIndex + 1, gameHistory.length);
      }

      String fromSquare = '';
      String toSquare = '';
      String moveUci = '';
      
      if (move is NormalMove) {
        fromSquare = move.from.name;
        toSquare = move.to.name;
        moveUci = move.uci;
      }

      gameHistory.add({
        'fen': canonicalFen,  // Store FEN
        'move': moveUci,
        'fromSquare': fromSquare,
        'toSquare': toSquare,
      });

      _state = _state.copyWith(
        gameHistory: gameHistory,
        currentMoveIndex: gameHistory.length - 1,
        currentFen: canonicalFen,  // State FEN matches dartchess FEN exactly
        showBestMove: false,
        highlightedSquares: <Square>{},
        boardShapes: <Shape>{}.lock,
        hasError: false,
        awaitingPromotion: false,
        pendingPromotionMove: null,
        lastMoveFrom: move is NormalMove ? move.from : null,
        lastMoveTo: move is NormalMove ? move.to : null,
      );

      if (kDebugMode && false) debugPrint('Move made. History length: ${gameHistory.length}');
      if (kDebugMode && false) debugPrint('Current move index: ${_state.currentMoveIndex}');

      // Update variation tree
      if (_currentVariationNode != null && _variationTreeRoot != null) {
        try {
          final newVariationNode = _currentVariationNode!.addMove(move);
          _currentVariationNode = newVariationNode;
          if (kDebugMode) debugPrint('VARIATION_TREE: Move added to tree: ${move.toString()}');
          if (kDebugMode) debugPrint('VARIATION_TREE: Root now has ${_variationTreeRoot!.variations.length} variations');
        } catch (e) {
          if (kDebugMode) debugPrint('VARIATION_TREE: Error adding move to tree: $e');
        }
      } else {
        if (kDebugMode) debugPrint('VARIATION_TREE: Cannot add move - currentNode=${_currentVariationNode != null}, root=${_variationTreeRoot != null}');
      }

      _notifyStateChanged();

      // Properly stop previous analysis before starting new one
      _analyzePositionSafely();
    } catch (e) {
      if (kDebugMode) debugPrint('Error completing move: $e');
      _state = _state.copyWith(
        awaitingPromotion: false,
        pendingPromotionMove: null,
      );
      _notifyStateChanged();
    }
  }

  // Build valid moves map for chessground
  IMap<Square, ISet<Square>> buildValidMovesMap() {
    final validMovesMap = <Square, ISet<Square>>{};
    
    if (_position == null) return validMovesMap.lock;
    
    try {
      final legalMovesIMap = _position!.legalMoves;
      
      for (final entry in legalMovesIMap.entries) {
        final fromSquare = entry.key;
        final toSquares = entry.value;
        
        final toSquaresList = <Square>[];
        for (final square in toSquares.squares) {
          toSquaresList.add(square);
        }
        
        // Add standard castling destinations for kings
        final piece = _position!.board.pieceAt(fromSquare);
        if (piece?.role == Role.king) {
          final castlingSquares = _getStandardCastlingSquares(fromSquare, toSquaresList);
          toSquaresList.addAll(castlingSquares);
        }
        
        if (toSquaresList.isNotEmpty) {
          validMovesMap[fromSquare] = toSquaresList.toISet();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error building valid moves: $e');
    }
    
    return validMovesMap.lock;
  }

  /// Get standard castling destination squares (g1/c1 for white, g8/c8 for black)
  /// when castling to rook squares is legal
  List<Square> _getStandardCastlingSquares(Square kingSquare, List<Square> legalMoves) {
    final castlingSquares = <Square>[];
    
    try {
      // Check if king can castle by looking for rook destinations in legal moves
      if (kingSquare == Square.e1) {
        // White king on starting square
        if (legalMoves.contains(Square.h1)) {
          // King-side castling available - add g1 as destination
          castlingSquares.add(Square.g1);
        }
        if (legalMoves.contains(Square.a1)) {
          // Queen-side castling available - add c1 as destination
          castlingSquares.add(Square.c1);
        }
      } else if (kingSquare == Square.e8) {
        // Black king on starting square  
        if (legalMoves.contains(Square.h8)) {
          // King-side castling available - add g8 as destination
          castlingSquares.add(Square.g8);
        }
        if (legalMoves.contains(Square.a8)) {
          // Queen-side castling available - add c8 as destination
          castlingSquares.add(Square.c8);
        }
      }
      
      if (castlingSquares.isNotEmpty && kDebugMode) {
        debugPrint('CASTLING: Added standard destinations for ${kingSquare.name}: ${castlingSquares.map((s) => s.name).join(", ")}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error determining castling squares: $e');
    }
    
    return castlingSquares;
  }

  Future<void> savePosition(BuildContext context) async {
    if (_state.isInvalidPosition) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot save invalid positions. Please edit and fix the position first.'),
          backgroundColor: AppColors.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    
    final nameController = TextEditingController();
    String defaultName = _generatePositionName();
    nameController.text = defaultName;
    
    final positionName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.isDarkMode ? const Color(0xFF1a1a1a) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.bookmark_add_rounded, color: context.accentColor, size: 24),
            const SizedBox(width: 8),
            Text('Save Position', style: TextStyle(color: context.primaryTextColor, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Give this position a name:',
              style: TextStyle(color: context.secondaryTextColor, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: TextStyle(color: context.primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Position Name',
                labelStyle: TextStyle(color: context.secondaryTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.accentColor, width: 2),
                ),
                hintText: 'Enter a descriptive name...',
                hintStyle: TextStyle(color: context.secondaryTextColor.withOpacity(0.7)),
              ),
              autofocus: true,
              maxLength: 50,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.accentColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: context.accentColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current evaluation: ${_getEvaluationText()}',
                      style: TextStyle(
                        color: context.primaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.secondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: context.isDarkMode ? Colors.black : AppColors.deepNavy,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (positionName != null && positionName.isNotEmpty) {
      try {
        final position = ChessPosition(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: positionName,
          fen: _state.currentFen,
          date: DateTime.now(),
        );

        await _storageService.savePosition(position);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Position saved successfully!'),
                ],
              ),
              backgroundColor: AppColors.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              action: SnackBarAction(
                label: 'View All',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedPositionsScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving position: ${e.toString()}'),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  String _generatePositionName() {
    try {
      final moveNumber = _state.gameHistory.length;
      
      if (moveNumber <= 1) {
        return 'Starting Position';
      } else if (moveNumber <= 10) {
        return 'Opening Position (Move $moveNumber)';
      } else if (moveNumber <= 25) {
        return 'Middlegame Position (Move $moveNumber)';
      } else {
        return 'Endgame Position (Move $moveNumber)';
      }
    } catch (e) {
      return 'Chess Position ${DateTime.now().day}/${DateTime.now().month}';
    }
  }

  String _getEvaluationText() {
    if (_state.isMateScore) {
      return 'Mate in ${_state.mateInMoves.abs()} for ${_state.mateInMoves > 0 ? "White" : "Black"}';
    } else {
      final sign = _state.evaluationScore >= 0 ? '+' : '';
      return '${sign}${_state.evaluationScore.toStringAsFixed(2)}';
    }
  }

  void dispose() {
    if (kDebugMode) debugPrint('DISPOSING: AnalysisController disposing...');
    _disposed = true;

    // Cancel all timers
    _retryTimer?.cancel();
    _debounceTimer?.cancel();

    // Cancel analysis subscription
    _analysisSubscription?.cancel();
    _analysisSubscription = null;

    // Dispose power-saving components
    _throttler?.dispose();
    _fenDebouncer?.dispose();
    _stateBatcher?.dispose();

    // Thoroughly stop and reset Stockfish service
    _stopAndResetStockfish();

    if (kDebugMode) debugPrint('AnalysisController disposed');
  }
  
  void _stopAndResetStockfish() async {
    try {
      if (kDebugMode) debugPrint('CLEANUP: Stopping Stockfish service...');
      
      // Stop any running analysis
      if (_stockfishService.isAnalyzing) {
        await _stockfishService.stopAnalysis();
      }
      
      // Dispose the entire Stockfish service to reset its state
      await _stockfishService.dispose();
      
      if (kDebugMode) debugPrint('CLEANUP: Stockfish service reset complete');
    } catch (e) {
      if (kDebugMode) debugPrint('CLEANUP: Error during Stockfish cleanup: $e');
    }
  }
}