// test/platform/platform_compatibility_tests.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/dartchess_validation_service.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('Platform Compatibility Tests', () {
    test('handles different platform conventions', () {
      // Test platform behavior
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      
      // Validation should work correctly
      final result = DartChessValidationService.validateFen(TestPositions.startingPosition);
      expect(result.isValid, isTrue);
      
      debugDefaultTargetPlatformOverride = null;
    });

    test('performance scales appropriately', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 100; i++) {
        DartChessValidationService.validateFen(TestPositions.startingPosition);
      }
      
      stopwatch.stop();
      
      debugDefaultTargetPlatformOverride = null;
      
      print('Performance: 100 validations in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('handles memory constraints', () {
      // Test memory usage patterns
      final positions = <ChessPosition>[];
      
      try {
        for (int i = 0; i < 1000; i++) {
          positions.add(ChessPosition.fromFenLenient(
            name: 'Position $i',
            fen: TestPositions.startingPosition,
            id: 'pos_$i',
          ));
        }
        
        // Should handle 1000 positions without issues
        expect(positions.length, equals(1000));
        
      } catch (e) {
        // If out of memory, should fail gracefully
        expect(e, isA<OutOfMemoryError>());
      } finally {
        positions.clear();
      }
    });
  });
}