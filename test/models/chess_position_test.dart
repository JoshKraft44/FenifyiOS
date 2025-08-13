// test/models/chess_position_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/models/chess_position.dart';
import 'package:dartchess/dartchess.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('ChessPosition Tests', () {
    test('creates position from FEN', () {
      final position = ChessPosition.fromFenLenient(
        name: 'Test Position',
        fen: TestPositions.startingPosition,
      );
      
      expect(position.name, equals('Test Position'));
      expect(position.fen, equals(TestPositions.startingPosition));
      expect(position.id, isNotNull);
      expect(position.date, isNotNull);
    });
    
    test('validates position correctly', () {
      final validPosition = ChessPosition.fromFenLenient(
        name: 'Valid',
        fen: TestPositions.startingPosition,
      );
      
      final invalidPosition = ChessPosition.fromFenLenient(
        name: 'Invalid',
        fen: TestPositions.invalidNoKings,
      );
      
      expect(validPosition.isValid, isTrue);
      expect(invalidPosition.isValid, isFalse);
      expect(invalidPosition.validationError, isNotNull);
    });
    
    test('creates position with turn change', () {
      final position = ChessPosition.fromFenLenient(
        name: 'Test',
        fen: TestPositions.startingPosition,
      );
      
      final blackToMove = position.withTurn(Side.black);
      
      expect(blackToMove.fen, contains(' b '));
      expect(position.fen, contains(' w ')); // Original unchanged
    });
    
    test('serializes to and from JSON', () {
      final original = ChessPosition.fromFenLenient(
        name: 'JSON Test',
        fen: TestPositions.englishOpening,
      );
      
      final json = original.toJson();
      final restored = ChessPosition.fromJson(json);
      
      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.fen, equals(original.fen));
    });
    
    test('copies with modifications', () {
      final original = ChessPosition.fromFenLenient(
        name: 'Original',
        fen: TestPositions.startingPosition,
      );
      
      final modified = original.copyWith(
        name: 'Modified',
        fen: TestPositions.sicilianDefense,
      );
      
      expect(modified.name, equals('Modified'));
      expect(modified.fen, equals(TestPositions.sicilianDefense));
      expect(modified.id, equals(original.id)); // Should preserve ID
    });
  });
}