// test/services/dartchess_validation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/dartchess_validation_service.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  tearDownAll(() {
    TestSetup.tearDownAll();
  });
  
  group('DartChessValidationService Tests', () {
    test('validates correct starting position', () {
      final result = DartChessValidationService.validateFen(TestPositions.startingPosition);
      
      expect(result.isValid, isTrue);
      expect(result.cleanFen, equals(TestPositions.startingPosition));
      expect(result.setup, isNotNull);
      expect(result.position, isNotNull);
      expect(result.analysis, isNotNull);
    });
    
    test('rejects invalid FEN formats', () {
      final invalidFens = [
        '',
        'invalid',
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP', // Missing parts
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x KQkq - 0 1', // Invalid turn
      ];
      
      for (final fen in invalidFens) {
        final result = DartChessValidationService.validateFen(fen);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, isNotNull);
      }
    });
    
    test('validates all test positions', () {
      for (final fen in TestPositions.getValidPositions()) {
        final result = DartChessValidationService.validateFen(fen);
        expect(result.isValid, isTrue, reason: 'Failed to validate: $fen');
      }
    });
    
    test('rejects invalid positions', () {
      for (final fen in TestPositions.getInvalidPositions()) {
        final result = DartChessValidationService.validateFen(fen);
        expect(result.isValid, isFalse, reason: 'Should have rejected: $fen');
      }
    });
    
    test('cleans FEN with custom flags', () {
      const fenWithFlags = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1 INVALID_CASTLING';
      
      final result = DartChessValidationService.validateFen(fenWithFlags);
      
      expect(result.cleanFen, equals(TestPositions.startingPosition));
    });
    
    test('provides position analysis', () {
      final result = DartChessValidationService.validateFen(TestPositions.startingPosition);
      
      expect(result.analysis, isNotNull);
      expect(result.analysis!.isCheck, isFalse);
      expect(result.analysis!.isCheckmate, isFalse);
      expect(result.analysis!.isStalemate, isFalse);
      expect(result.analysis!.legalMovesCount, greaterThan(0));
    });
  });
}
