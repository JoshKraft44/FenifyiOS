// test/stress/stress_tests.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/dartchess_validation_service.dart';
import 'package:fenify/models/chess_position.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('Stress Tests', () {
    test('handles rapid position changes', () {
      final testFens = TestPositions.generateTestFens();
      
      for (int i = 0; i < 1000; i++) {
        final fen = testFens[i % testFens.length];
        final result = DartChessValidationService.validateFen(fen);
        expect(result, isNotNull);
      }
    });

    test('handles large number of saved positions', () {
      final positions = <ChessPosition>[];
      
      for (int i = 0; i < 10000; i++) {
        final position = ChessPosition.fromFenLenient(
          name: 'Stress Test Position $i',
          fen: TestPositions.startingPosition,
          id: 'stress_$i',
        );
        positions.add(position);
      }
      
      expect(positions.length, equals(10000));
      
      // Test serialization performance
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 100; i++) {
        final json = positions[i].toJson();
        final restored = ChessPosition.fromJson(json);
        expect(restored.id, equals(positions[i].id));
      }
      
      stopwatch.stop();
      
      print('Serialization Stress Test:');
      print('- 100 serialize/deserialize cycles in ${stopwatch.elapsedMilliseconds}ms');
      
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('handles malformed input gracefully', () {
      final malformedInputs = [
        null,
        '',
        '\x00\x01\x02\x03',
        'A' * 100000,
        '🐴♞🏇', // Unicode chess-related emojis
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' '\x00',
      ];
      
      for (final input in malformedInputs) {
        if (input != null) {
          final result = DartChessValidationService.validateFen(input);
          expect(result, isNotNull);
          expect(result.isValid, isFalse);
        }
      }
    });

    test('handles rapid fire API calls', () async {
      final futures = <Future>[];
      
      for (int i = 0; i < 100; i++) {
        futures.add(Future(() {
          return DartChessValidationService.validateFen(TestPositions.startingPosition);
        }));
      }
      
      final results = await Future.wait(futures);
      
      expect(results.length, equals(100));
      for (final result in results) {
        expect(result.isValid, isTrue);
      }
    });
  });
}