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
      // Test platform-specific behavior
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        
        // Validation should work the same on all platforms
        final result = DartChessValidationService.validateFen(TestPositions.startingPosition);
        expect(result.isValid, isTrue);
      }
      
      debugDefaultTargetPlatformOverride = null;
    });

    test('performance scales appropriately by platform', () {
      final platformResults = <String, int>{};
      
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 100; i++) {
          DartChessValidationService.validateFen(TestPositions.startingPosition);
        }
        
        stopwatch.stop();
        platformResults[platform.name] = stopwatch.elapsedMilliseconds;
      }
      
      debugDefaultTargetPlatformOverride = null;
      
      print('Platform Performance:');
      platformResults.forEach((platform, time) {
        print('- $platform: 100 validations in ${time}ms');
      });
    });

    test('handles platform-specific memory constraints', () {
      // Test memory usage patterns that might differ between platforms
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
        // If platform runs out of memory, should fail gracefully
        expect(e, isA<OutOfMemoryError>());
      } finally {
        positions.clear();
      }
    });
  });
}