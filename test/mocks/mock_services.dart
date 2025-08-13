// test/mocks/mock_services.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/dartchess_validation_service.dart';
import 'package:fenify/models/chess_position.dart';

class MockValidationService {
  static bool shouldFail = false;
  static String? forcedError;
  
  static ValidationResult validateFen(String fen) {
    if (shouldFail) {
      return ValidationResult.invalid(forcedError ?? 'Mock validation failure');
    }
    
    return ValidationResult.valid(
      cleanFen: fen,
      setup: null,
      position: null,
      analysis: null,
    );
  }
  
  static void reset() {
    shouldFail = false;
    forcedError = null;
  }
}

class MockImageProcessor {
  bool _shouldFail = false;
  String _mockFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  
  Future<void> init() async {
    if (_shouldFail) {
      throw Exception('Mock model loading failed');
    }
    await Future.delayed(Duration(milliseconds: 100));
  }
  
  Future<String> processImage(List<int> imageBytes) async {
    if (_shouldFail) {
      throw Exception('Mock image processing failed');
    }
    
    await Future.delayed(Duration(milliseconds: 500));
    return _mockFen;
  }
  
  void setShouldFail(bool shouldFail) {
    _shouldFail = shouldFail;
  }
  
  void setMockFen(String fen) {
    _mockFen = fen;
  }
}

class MockStockfishService {
  static bool _isInitialized = false;
  static String _currentFen = '';
  static double _mockEvaluation = 0.0;
  
  static Future<void> initialize() async {
    await Future.delayed(Duration(milliseconds: 200));
    _isInitialized = true;
  }
  
  static Future<void> setPosition(String fen) async {
    _currentFen = fen;
  }
  
  static Future<Map<String, dynamic>> analyze({int depth = 15}) async {
    if (!_isInitialized) {
      throw Exception('Stockfish not initialized');
    }
    
    await Future.delayed(Duration(milliseconds: 1000));
    
    return {
      'evaluation': _mockEvaluation,
      'isMate': false,
      'mateInMoves': 0,
      'bestMove': 'e2e4',
      'depth': depth,
      'principalVariation': ['e2e4', 'e7e5', 'g1f3'],
      'multiPV': [
        ['e2e4', 'e7e5'],
        ['d2d4', 'd7d5'],
      ],
      'multiEval': [0.2, 0.0],
    };
  }
  
  static void setMockEvaluation(double eval) {
    _mockEvaluation = eval;
  }
  
  static void dispose() {
    _isInitialized = false;
    _currentFen = '';
    _mockEvaluation = 0.0;
  }
}