// test/services/storage_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/services/storage_service.dart';
import 'package:fenify/models/chess_position.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('StorageService Tests', () {
    late StorageService storageService;
    
    setUp(() async {
      storageService = StorageService();
      // Clear any existing data before each test
      await storageService.clearAllPositions();
    });

    test('saves and loads positions', () async {
      final position = ChessPosition.fromFenLenient(
        name: 'Test Save',
        fen: TestPositions.sicilianDefense,
      );
      
      await storageService.savePosition(position);
      
      final loadedPositions = await storageService.getSavedPositions();
      
      expect(loadedPositions, contains(position));
    });

    test('deletes positions correctly', () async {
      final position = ChessPosition.fromFenLenient(
        name: 'Test Delete',
        fen: TestPositions.englishOpening,
      );
      
      await storageService.savePosition(position);
      await storageService.deletePosition(position.id);
      
      final loadedPositions = await storageService.getSavedPositions();
      
      expect(loadedPositions, isNot(contains(position)));
    });

    test('updates existing positions', () async {
      final original = ChessPosition.fromFenLenient(
        name: 'Original Name',
        fen: TestPositions.startingPosition,
      );
      
      await storageService.savePosition(original);
      
      final updated = original.copyWith(name: 'Updated Name');
      await storageService.savePosition(updated);
      
      final loadedPositions = await storageService.getSavedPositions();
      final foundPosition = loadedPositions.firstWhere((p) => p.id == original.id);
      
      expect(foundPosition.name, equals('Updated Name'));
    });

    test('handles empty storage gracefully', () async {
      final positions = await storageService.getSavedPositions();
      
      expect(positions, isA<List<ChessPosition>>());
      expect(positions.isEmpty, isTrue);
    });

    test('saves multiple positions', () async {
      final positions = [
        ChessPosition.fromFenLenient(name: 'Pos 1', fen: TestPositions.startingPosition),
        ChessPosition.fromFenLenient(name: 'Pos 2', fen: TestPositions.sicilianDefense),
        ChessPosition.fromFenLenient(name: 'Pos 3', fen: TestPositions.englishOpening),
      ];
      
      for (final position in positions) {
        await storageService.savePosition(position);
      }
      
      final loadedPositions = await storageService.getSavedPositions();
      
      expect(loadedPositions.length, equals(3));
    });
  });
}