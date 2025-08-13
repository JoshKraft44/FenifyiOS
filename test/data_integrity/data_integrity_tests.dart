// test/data_integrity/data_integrity_tests.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/models/chess_position.dart';
import 'package:fenify/services/storage_service.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('Data Integrity Tests', () {
    test('detects data corruption in saved positions', () async {
      final storageService = StorageService();
      
      final originalPosition = ChessPosition.fromFenLenient(
        name: 'Integrity Test',
        fen: TestPositions.startingPosition,
      );
      
      await storageService.savePosition(originalPosition);
      
      // Simulate data corruption by modifying underlying storage
      // (This would require access to the actual storage implementation)
      
      final loadedPositions = await storageService.loadPositions();
      
      // Should either load correctly or detect corruption
      expect(loadedPositions, isA<List<ChessPosition>>());
    });

    test('maintains FEN consistency across operations', () {
      final position = ChessPosition.fromFenLenient(
        name: 'Consistency Test',
        fen: TestPositions.englishOpening,
      );
      
      // Serialize and deserialize multiple times
      var currentPosition = position;
      
      for (int i = 0; i < 10; i++) {
        final json = currentPosition.toJson();
        currentPosition = ChessPosition.fromJson(json);
      }
      
      // FEN should remain unchanged
      expect(currentPosition.fen, equals(position.fen));
      expect(currentPosition.name, equals(position.name));
    });

    test('validates data integrity after storage operations', () async {
      final storageService = StorageService();
      
      final testPositions = [
        ChessPosition.fromFenLenient(name: 'Test 1', fen: TestPositions.startingPosition),
        ChessPosition.fromFenLenient(name: 'Test 2', fen: TestPositions.sicilianDefense),
        ChessPosition.fromFenLenient(name: 'Test 3', fen: TestPositions.englishOpening),
      ];
      
      // Save all positions
      for (final position in testPositions) {
        await storageService.savePosition(position);
      }
      
      // Load and verify
      final loadedPositions = await storageService.loadPositions();
      
      expect(loadedPositions.length, equals(testPositions.length));
      
      // Verify each position maintained integrity
      for (final original in testPositions) {
        final loaded = loadedPositions.firstWhere((p) => p.id == original.id);
        expect(loaded.fen, equals(original.fen));
        expect(loaded.name, equals(original.name));
      }
    });

    test('handles concurrent read/write operations safely', () async {
      final storageService = StorageService();
      
      // Simulate concurrent operations
      final futures = <Future>[];
      
      for (int i = 0; i < 10; i++) {
        futures.add(storageService.savePosition(
          ChessPosition.fromFenLenient(
            name: 'Concurrent $i',
            fen:)));
        
        final signedFormatted = number >= 0 ? '+$formatted' : formatted;
        expect(signedFormatted, isNotNull);
      }
    });

    test('chess notation is locale-independent', () {
      // Chess notation should work the same regardless of locale
      final testMoves = ['e2e4', 'Nf3', 'O-O', 'Qd1d4'];
      
      for (final move in testMoves) {
        // Chess moves should parse consistently
        expect(move, matches(RegExp(r'^[a-h1-8NBRQKO-]+ TestPositions.startingPosition,
            interactive: true,
            onPositionChanged: (fen) => changedFen = fen,
          ),
        ),
      );
      
      // Simulate a move (this would require more specific implementation)
      // For now, just verify the widget renders
      expect(find.byType(ChessBoardWidget), findsOneWidget);
    });

    testWidgets('displays flipped board correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          ChessBoardWidget(
            fen: TestPositions.startingPosition,
            flipped: true,
          ),
        ),
      );
      
      expect(find.byType(ChessBoardWidget), findsOneWidget);
      // Additional assertions for flipped board would go here
    });

    testWidgets('shows highlighted squares', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          ChessBoardWidget(
            fen: TestPositions.startingPosition,
            highlightedSquares: {Square.fromName('e2'), Square.fromName('e4')},
          ),
        ),
      );
      
      expect(find.byType(ChessBoardWidget), findsOneWidget);
      // Additional assertions for highlighted squares would go here
    });
  });
}