import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dartchess/dartchess.dart';
import '../../constants/app_constants.dart';
import '../../core/disposable.dart';
import '../../core/resource_manager.dart';
import '../dartchess_validation_service.dart';
import 'isolate/stockfish_isolate_manager.dart';
import 'analysis/analysis_parser.dart';
import 'analysis/position_validator.dart';

/// Manages Stockfish chess engine analysis using isolates for non-blocking performance
/// Integrates with DartChess for  position validation
class StockfishService with DisposableMixin {
  static final StockfishService _instance = StockfishService._internal();
  factory StockfishService() => _instance;
  StockfishService._internal() {
    // Register with global resource manager for automatic cleanup
    registerGlobally(name: 'stockfish_service');
  }

  StockfishIsolateManager? _isolateManager;
  AnalysisParser? _analysisParser;
  PositionValidator? _positionValidator;

  // Analysis state tracking
  bool _isAnalyzing = false;
  bool _engineInitialized = false;
  bool _initializationInProgress = false;
  StreamController<Map<String, dynamic>>? _analysisStreamController;
  int _analysisId = 0;

  int get currentAnalysisId => _analysisId;
  
  /// Force reset analysis ID for fresh sessions
  void resetAnalysisId() {
    _analysisId = 0;
    if (kDebugMode) debugPrint('Stockfish analysis ID force reset to 0');
  }

  // Reliability features
  int _initRetryCount = 0;
  static const int _maxInitRetries = AppConstants.maxInitRetries;
  static const Duration _initTimeout = AppConstants.initTimeout;

  bool get isAnalyzing => _isAnalyzing;
  bool get isEngineRunning => _isolateManager?.isRunning == true && _engineInitialized;
  bool get canInitialize => true;

  /// Initializes Stockfish engine in isolated thread with retry mechanism
  /// Ensures UI remains responsive during engine startup
  Future<void> initialize() async {
    // Allow reinitialization if needed for reliability
    if (_engineInitialized && _isolateManager?.isRunning == true) {
      if (kDebugMode) debugPrint('Stockfish already initialized and running');
      return;
    }
    
    if (_initializationInProgress) {
      if (kDebugMode) debugPrint('Initialization already in progress, waiting...');
      await _waitForEngineReady();
      return;
    }

    // Reset state for clean initialization
    _engineInitialized = false;
    _initializationInProgress = true;
    _initRetryCount = 0;
    
    _isolateManager = StockfishIsolateManager();
    _analysisParser = AnalysisParser();
    _positionValidator = PositionValidator();
    
    if (kDebugMode) debugPrint('Starting Stockfish initialization...');

    // Retry logic for reliability in different environments
    for (int attempt = 0; attempt < _maxInitRetries; attempt++) {
      try {
        if (kDebugMode) debugPrint('Initializing Stockfish (attempt ${attempt + 1}/$_maxInitRetries)...');
        
        await _isolateManager!.initialize();
        await _waitForEngineReady();

        if (_engineInitialized) {
          if (kDebugMode) debugPrint('Succes: Stockfish initialized successfully');
          _initializationInProgress = false;
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('ERROR: Initialization attempt ${attempt + 1} failed: $e');
        await _isolateManager!.cleanup();
        
        if (attempt == _maxInitRetries - 1) {
          _initializationInProgress = false;
          throw Exception('Failed to initialize Stockfish after $_maxInitRetries attempts: $e');
        }
        
        // Exponential backoff between retries
        await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
      }
    }

    _initializationInProgress = false;
    throw Exception('Failed to initialize Stockfish engine');
  }

  /// Validates FEN using DartChess instead of Stockfish to avoid crashes. Stockfish will crash on invalid positions.
  /// DartChess validation is better than engine queries
  Future<bool> validateFenWithDartChess(String fen) async {
    _positionValidator ??= PositionValidator();
    return await _positionValidator!.validateFen(fen);
  }

  /// Waits for engine initialization with timeout protection
  Future<void> _waitForEngineReady() async {
    if (_engineInitialized) {
      if (kDebugMode) debugPrint('Engine already ready');
      return;
    }

    if (kDebugMode) debugPrint('WAITING: Engine to be ready...');
    final completer = Completer<void>();
    Timer? timeoutTimer;

    // Prevent indefinite waiting
    timeoutTimer = Timer(_initTimeout, () {
      if (!completer.isCompleted) {
        if (kDebugMode) debugPrint('TIMEOUT: Engine initialization timeout');
        completer.completeError(TimeoutException('Engine initialization timeout'));
      }
    });

    // Listen for engine ready confirmation
    final subscription = _isolateManager!.messageStream.listen((message) {
      if (message['type'] == 'engine_ready') {
        if (kDebugMode) debugPrint('SUCCESS: Engine ready confirmed');
        _engineInitialized = true;
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (message['type'] == 'engine_error') {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(Exception(message['error']));
        }
      }
    });

    try {
      await completer.future;
      print('SUCCESS: Engine ready confirmed');
    } catch (e) {
      if (kDebugMode) debugPrint('ERROR: Engine initialization failed: $e');
      throw Exception('Engine failed to initialize: $e');
    } finally {
      timeoutTimer.cancel();
      subscription.cancel();
    }
  }

  /// Starts continuous position analysis with pre-validation
  /// Returns a stream of analysis updates for real-time UI updates
  Stream<Map<String, dynamic>> startContinuousAnalysis(String fen) async* {
    if (kDebugMode) debugPrint('Starting continuous analysis for FEN: $fen');

    // Handle positions marked as invalid from image processing
    if (fen.contains('INVALID_')) {
      yield* _handleInvalidPosition(fen);
      return;
    }

    try {
      final cleanFen = fen.replaceAll(RegExp(r' INVALID_\w+'), '');
      
      // Pre-validate with DartChess for immediate feedback
      if (kDebugMode) debugPrint('Pre-validating position with DartChess...');
      final validationResult = DartChessValidationService.validateFen(cleanFen);
      
      if (!validationResult.isValid) {
        if (kDebugMode) debugPrint('ERROR: DartChess pre-validation failed: ${validationResult.errorMessage}');
        yield {
          'evaluation': 0.0,
          'bestMove': '',
          'depth': 0,
          'nodes': 0,
          'pv': [],
          'multipv': [],
          'error': 'Invalid position: ${validationResult.errorMessage}\n\nTap "Edit Position" to fix the position.',
          'invalid_position': true,
        };
        return;
      }

      // Additional Stockfish compatibility check
      final compatibilityError = _positionValidator?.checkStockfishCompatibility(cleanFen);
      if (compatibilityError != null) {
        if (kDebugMode) debugPrint('ERROR: Stockfish compatibility check failed: $compatibilityError');
        yield {
          'evaluation': 0.0,
          'bestMove': '',
          'depth': 0,
          'nodes': 0,
          'pv': [],
          'multipv': [],
          'error': 'Position incompatible with Stockfish: $compatibilityError\n\nTap "Edit Position" to fix the position.',
          'invalid_position': true,
        };
        return;
      }
      
      if (kDebugMode) debugPrint('SUCCESS: DartChess pre-validation successful - starting Stockfish analysis');
      if (validationResult.analysis != null) {
        final analysis = validationResult.analysis!;
        if (kDebugMode) {
          debugPrint('   Position status: ${analysis.statusDescription}');
          debugPrint('   Material balance: ${analysis.materialDescription}');
          debugPrint('   Legal moves: ${analysis.legalMovesCount}');
        }
        
        // Handle game-over positions efficiently
        if (analysis.isGameOver) {
          if (kDebugMode) debugPrint('GAME_OVER: Position is game over: ${analysis.outcome}');
          yield {
            'evaluation': analysis.isCheckmate ? (analysis.outcome == Outcome.whiteWins ? 999.0 : -999.0) : 0.0,
            'isMate': analysis.isCheckmate,
            'mateIn': analysis.isCheckmate ? 0 : 0,
            'bestMove': '',
            'principalVariation': <String>[],
            'multiPV': <List<String>>[],
            'multiEval': <double>[],
            'depth': 0,
            'game_over': true,
            'outcome': analysis.statusDescription,
          };
          return;
        }
      }
      
      // Ensure engine is ready before analysis
      if (!_engineInitialized || _isolateManager?.isRunning != true) {
        if (kDebugMode) debugPrint('Engine not ready, initializing now...');
        await initialize();
      }

      // Start analysis with the validated FEN
      _analysisId++;
      yield* _performAnalysis(cleanFen, _analysisId);

    } catch (e) {
      if (kDebugMode) debugPrint('ERROR: Failed to start analysis: $e');
      yield* _createErrorStream('Failed to start analysis: $e');
    }
  }

  /// Handles positions marked as invalid during image processing
  Stream<Map<String, dynamic>> _handleInvalidPosition(String fen) async* {
    String errorMessage = 'Position is invalid and cannot be analyzed';
    if (fen.contains('INVALID_POSITION')) {
      errorMessage = 'Position contains invalid piece arrangements.\n\nTo analyze this position:\n1. Tap "Edit Position" below\n2. Fix the position by adding/removing pieces\n3. Ensure both sides have exactly one king\n4. Return to analysis when position is valid';
    } else if (fen.contains('INVALID_ERROR')) {
      errorMessage = 'Position validation encountered an error.\nPlease edit the position or capture a new image.';
    }
    
    // Return error analysis data but allow editing
    yield {
      'evaluation': 0.0,
      'bestMove': '',
      'depth': 0,
      'nodes': 0,
      'pv': [],
      'multipv': [],
      'error': errorMessage,
      'invalid_position': true,
    };
  }

  /// Manages the actual analysis process with proper cleanup and error handling
  Stream<Map<String, dynamic>> _performAnalysis(String cleanFen, int analysisId) async* {
    // Clean slate for new analysis
    await stopAnalysis();

    _isAnalyzing = true;
    _analysisStreamController = StreamController<Map<String, dynamic>>.broadcast();

    // Start analysis
    if (kDebugMode) debugPrint('Sending analysis command to isolate...');
    if (kDebugMode) debugPrint('DEBUG_ANALYSIS: FEN=$cleanFen, ID=$analysisId, Turn=${cleanFen.split(' ')[1]}');
    _isolateManager!.sendAnalysisCommand(cleanFen, analysisId);

    // Set up real-time analysis data processing
    final subscription = _isolateManager!.messageStream.listen(
      (message) {
        if (message['type'] == 'analysis') {
          try {
            final parsedData = _analysisParser!.parseAnalysisData(message['data']);
            if (_analysisStreamController != null && !_analysisStreamController!.isClosed) {
              _analysisStreamController!.add(parsedData);
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Error parsing analysis data: $e');
          }
        }
      },
      onError: (error) {
        if (kDebugMode) debugPrint('Analysis stream error: $error');
        if (_analysisStreamController != null && !_analysisStreamController!.isClosed) {
          _analysisStreamController!.addError(error);
        }
      },
    );

    try {
      yield* _analysisStreamController!.stream;
    } finally {
      subscription.cancel();
      _isAnalyzing = false;
      if (_analysisStreamController != null && !_analysisStreamController!.isClosed) {
        await _analysisStreamController!.close();
      }
      _analysisStreamController = null;
    }
  }

  /// Creates error stream for analysis failures
  Stream<Map<String, dynamic>> _createErrorStream(String error) async* {
    _isAnalyzing = false;
    final errorController = StreamController<Map<String, dynamic>>();
    errorController.add({
      'error': true,
      'message': error,
      'evaluation': 0.0,
      'isMate': false,
      'mateIn': 0,
      'bestMove': '',
      'principalVariation': <String>[],
      'multiPV': <List<String>>[],
      'multiEval': <double>[],
      'depth': 0,
    });
    errorController.close();
    yield* errorController.stream;
  }

  /// Stops any current analysis and cleans up resources
  Future<void> stopAnalysis() async {
    if (!_isAnalyzing) return;

    if (kDebugMode) debugPrint('STOPPING: Analysis');

    if (isEngineRunning) {
      try {
        _isolateManager!.sendStopCommand();
      } catch (e) {
        if (kDebugMode) debugPrint('Error sending stop command: $e');
      }
    }

    _isAnalyzing = false;

    if (_analysisStreamController != null && !_analysisStreamController!.isClosed) {
      try {
        await _analysisStreamController!.close();
      } catch (e) {
        if (kDebugMode) debugPrint('Error closing analysis stream: $e');
      }
      _analysisStreamController = null;
    }
  }

  // Gracefully shuts down the service while preserving singleton pattern
  // Implements DisposableMixin.onDispose for resource management
  // Completely Restart engine to avoid state corrpution

  Future<void> restartEngine() async {
    if (kDebugMode) debugPrint('Restarting Stockfish engine for clean state');

    // Stop and cleanup everything with proper delay
    await onDispose();

    // Add delay to ensure cleanup is complete
    await Future.delayed(const Duration(milliseconds: 1000));

    // Reset all state for fresh start
    _initRetryCount = 0;
    _analysisId = 0;
    _engineInitialized = false;
    _initializationInProgress = false;

    if (kDebugMode) debugPrint('Stockfish state reset complete, reinitializing...');

    // Reinitialize for fresh analysis
    await initialize();

    if (kDebugMode) debugPrint('Stockfish engine restart completed');
  }

  @override
  Future<void> onDispose() async {
    if (kDebugMode) debugPrint('Stopping Stockfish service');
    await stopAnalysis();

    if (_isolateManager != null) {
      await _isolateManager!.cleanup();
      _isolateManager = null;
    }

    _engineInitialized = false;
    _initializationInProgress = false;
    _analysisParser = null;
    _positionValidator = null;

    // Reset analysis ID for fresh sessions
    _analysisId = 0;
    if (kDebugMode) debugPrint('Stockfish Analysis ID reset to 0 for fresh session');

    if (kDebugMode) debugPrint('Success: Stockfish service stopped (can be restarted)');
  }
  
}