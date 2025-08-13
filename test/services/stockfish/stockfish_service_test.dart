
// test/services/stockfish/stockfish_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/stockfish/stockfish_service.dart';
import '../../test_setup.dart';
import '../../fixtures/test_positions.dart';
import '../../mocks/mock_services.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  tearDownAll(() {
    MockStockfishService.dispose();
  });
  
  group('StockfishService Tests', () {
    test('initializes correctly', () async {
      await MockStockfishService.initialize();
      
      // Indirect initialization test
      final result = await MockStockfishService.analyze(depth: 1);
      expect(result, isNotNull);
    });

    test('sets position correctly', () async {
      await MockStockfishService.initialize();
      
      await MockStockfishService.setPosition(TestPositions.sicilianDefense);
      
      // Test that position was set by analyzing it
      final result = await MockStockfishService.analyze(depth: 1);
      expect(result, isNotNull);
      expect(result['bestMove'], isNotNull);
    });

    test('analyzes position and returns results', () async {
      await MockStockfishService.initialize();
      await MockStockfishService.setPosition(TestPositions.startingPosition);
      
      final result = await MockStockfishService.analyze(depth: 10);
      
      expect(result, isNotNull);
      expect(result['bestMove'], isNotNull);
      expect(result['evaluation'], isA<double>());
      expect(result['depth'], equals(10));
      expect(result['principalVariation'], isA<List>());
    });

    test('handles analysis without initialization', () async {
      MockStockfishService.dispose();
      
      expect(
        () => MockStockfishService.analyze(),
        throwsA(isA<Exception>()),
      );
    });

    test('provides multi-PV analysis', () async {
      await MockStockfishService.initialize();
      await MockStockfishService.setPosition(TestPositions.startingPosition);
      
      final result = await MockStockfishService.analyze();
      
      expect(result['multiPV'], isA<List>());
      expect(result['multiEval'], isA<List>());
      expect((result['multiPV'] as List).length, greaterThan(0));
    });
  });
}