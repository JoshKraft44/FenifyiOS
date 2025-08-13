// test/performance/performance_tests.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/dartchess_validation_service.dart';
import 'package:fenify/services/stockfish/analysis/analysis_parser.dart';
import 'package:fenify/models/chess_position.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('Performance Tests', () {
    test('FEN validation performance benchmark', () {
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 1000; i++) {
        DartChessValidationService.validateFen(TestPositions.startingPosition);
      }
      
      stopwatch.stop();
      
      print('FEN Validation Benchmark:');
      print('- 1000 validations in ${stopwatch.elapsedMilliseconds}ms');
      print('- Average: ${stopwatch.elapsedMicroseconds / 1000}μs per validation');
      
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Under 1 second
    });

    test('batch position validation performance', () {
      final testFens = TestPositions.generateTestFens();
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 100; i++) {
        for (final fen in testFens) {
          DartChessValidationService.validateFen(fen);
        }
      }
      
      stopwatch.stop();
      
      final totalValidations = 100 * testFens.length;
      print('Batch Validation Benchmark:');
      print('- $totalValidations validations in ${stopwatch.elapsedMilliseconds}ms');
      
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('analysis parsing benchmark', () {
      final parser = AnalysisParser();
      final testData = {
        'evaluation': 1.25,
        'isMate': false,
        'bestMove': 'e2e4',
        'depth': 20,
        'principalVariation': List.generate(15, (i) => 'move$i'),
        'multiPV': List.generate(3, (i) => List.generate(10, (j) => 'pv${i}_$j')),
        'multiEval': [1.25, 0.85, 0.45],
      };
      
      const iterations = 10000;
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < iterations; i++) {
        parser.parseAnalysisData(Map<String, dynamic>.from(testData));
      }
      
      stopwatch.stop();
      
      final avgTimePerParse = stopwatch.elapsedMicroseconds / iterations;
      
      print('Analysis Parsing Benchmark:');
      print('- Iterations: $iterations');
      print('- Total time: ${stopwatch.elapsedMilliseconds}ms');
      print('- Average time per parse: ${avgTimePerParse.toStringAsFixed(2)}μs');
      print('- Parses per second: ${(1000000 / avgTimePerParse).toStringAsFixed(0)}');
      
      expect(avgTimePerParse, lessThan(100.0)); // Under 100μs per parse
    });

    test('memory allocation benchmark', () {
      // Test memory efficiency during typical operations
      final positions = <ChessPosition>[];
      final startTime = DateTime.now();
      
      try {
        for (int i = 0; i < 1000; i++) {
          final position = ChessPosition.fromFenLenient(
            name: 'Benchmark Position $i',
            fen: TestPositions.startingPosition,
            id: 'bench_$i',
            date: DateTime.now(),
          );
          positions.add(position);
          
          // Validate each position
          DartChessValidationService.validateFen(position.fen);
        }
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        print('Memory Allocation Benchmark:');
        print('- Created 1000 positions in ${duration.inMilliseconds}ms');
        print('- Memory usage: ${positions.length * 1024} bytes estimated');
        
        expect(duration.inMilliseconds, lessThan(1000));
        expect(positions.length, equals(1000));
        
      } finally {
        positions.clear();
      }
    });

    test('concurrent validation stress test', () async {
      const testFen = TestPositions.startingPosition;
      
      // Simulate concurrent validation requests
      final futures = List.generate(50, (_) => 
        Future(() => DartChessValidationService.validateFen(testFen))
      );
      
      final stopwatch = Stopwatch()..start();
      final results = await Future.wait(futures);
      stopwatch.stop();
      
      print('Concurrent Validation Test:');
      print('- 50 concurrent validations in ${stopwatch.elapsedMilliseconds}ms');
      
      // All should succeed
      for (final result in results) {
        expect(result.isValid, isTrue);
      }
      
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}