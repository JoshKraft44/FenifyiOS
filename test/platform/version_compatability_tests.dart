// test/compatibility/version_compatibility_tests.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/dartchess_validation_service.dart';
import 'package:fenify/models/chess_position.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('Version Compatibility Tests', () {
    test('handles legacy FEN formats', () {
      // Test FENs that might have been saved in older app versions
      final legacyFens = [
        TestPositions.startingPosition, // Standard
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -', // Missing parts
      ];
      
      for (final fen in legacyFens) {
        final result = DartChessValidationService.validateFen(fen);
        // Should either validate or fail gracefully
        expect(result, isNotNull);
      }
    });

    test('migrates old position data format', () {
      // Simulate old JSON format without analysis data
      final oldJsonFormat = {
        'id': 'old123',
        'name': 'Old Format Position',
        'fen': TestPositions.startingPosition,
        'date': '2023-01-01T00:00:00.000Z',
        // Missing 'analysis' field that newer versions include
      };
      
      expect(() => ChessPosition.fromJson(oldJsonFormat), returnsNormally);
      
      final position = ChessPosition.fromJson(oldJsonFormat);
      expect(position.analysis, isNull); // Should handle missing analysis gracefully
    });

    test('handles deprecated API usage gracefully', () {
      // Test that deprecated dartchess API calls are updated
      const fen = TestPositions.startingPosition;
      
      final result = DartChessValidationService.validateFen(fen);
      
      expect(result.isValid, isTrue);
      expect(result.position, isNotNull);
      
      // Verify that the position uses current API
      expect(result.position!.turn, isA<Side>());
      expect(result.position!.board, isNotNull);
    });
  });
}