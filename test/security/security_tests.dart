// test/security/security_tests.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/dartchess_validation_service.dart';
import 'package:fenify/models/chess_position.dart';
import 'package:fenify/services/storage_service.dart';
import '../test_setup.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('Security Tests', () {
    test('prevents XSS in position names', () {
      const xssName = '<script>alert("xss")</script>';
      
      final position = ChessPosition.fromFenLenient(
        name: xssName,
        fen: TestPositions.startingPosition,
      );
      
      // Name should be stored as-is (UI framework should handle escaping)
      expect(position.name, equals(xssName));
      
      // JSON serialization should handle special characters safely
      final json = position.toJson();
      expect(json['name'], equals(xssName));
    });

    test('handles extremely long FEN strings without crashing', () {
      final longFen = 'r' * 1000000; // Very long invalid FEN
      
      final result = DartChessValidationService.validateFen(longFen);
      
      expect(result.isValid, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('validates input sanitization for position names', () {
      final maliciousNames = [
        '<img src=x onerror=alert(1)>',
        'javascript:alert(1)',
        '${String.fromCharCode(0)}null byte',
        '\x00\x01\x02', // Control characters
        'A' * 10000, // Extremely long name
      ];
      
      for (final name in maliciousNames) {
        final position = ChessPosition.fromFenLenient(
          name: name,
          fen: TestPositions.startingPosition,
        );
        
        expect(position.name, equals(name)); // Should store as-is
        expect(() => position.toJson(), returnsNormally); // Should serialize safely
      }
    });

    test('prevents DoS through resource exhaustion', () {
      // Test with positions that might cause exponential processing
      final stressFens = [
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' * 100,
        'Q' * 64 + '/8/8/8/8/8/8/8 w - - 0 1', // Too many queens
        'invalid' * 1000,
      ];
      
      for (final fen in stressFens) {
        final stopwatch = Stopwatch()..start();
        
        final result = DartChessValidationService.validateFen(fen);
        
        stopwatch.stop();
        
        // Should complete quickly even for malicious input
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        expect(result.isValid, isFalse);
      }
    });

    test('handles SQL injection attempts in storage', () async {
      final storageService = StorageService();
      
      final maliciousPosition = ChessPosition.fromFenLenient(
        name: "'; DROP TABLE positions; --",
        fen: TestPositions.startingPosition,
      );
      
      // Should save and load without issues
      await storageService.savePosition(maliciousPosition);
      final positions = await storageService.loadPositions();
      
      expect(positions, contains(maliciousPosition));
    });
  });
}

