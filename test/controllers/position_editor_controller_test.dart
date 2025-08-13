// test/controllers/position_editor_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fenify/screens/edit_position_screen/controllers/position_editor_controller.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('PositionEditorController Tests', () {
    late PositionEditorController controller;
    bool stateChanged = false;
    
    setUp(() {
      stateChanged = false;
      controller = PositionEditorController(
        initialFen: TestPositions.startingPosition,
        onStateChanged: () => stateChanged = true,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with starting position', () {
      controller.initialize();
      
      expect(controller.position, isNotNull);
      expect(controller.currentFen, contains('rnbqkbnr'));
      expect(stateChanged, isTrue);
    });

    test('switches between edit modes correctly', () {
      controller.initialize();
      
      // Test drag mode
      controller.setDragMode();
      expect(controller.isDragMode, isTrue);
      expect(controller.isPlaceMode, isFalse);
      expect(controller.isRemoveMode, isFalse);
      
      // Test place mode
      controller.setPlaceMode();
      expect(controller.isDragMode, isFalse);
      expect(controller.isPlaceMode, isTrue);
      expect(controller.isRemoveMode, isFalse);
      
      // Test remove mode
      controller.setRemoveMode();
      expect(controller.isDragMode, isFalse);
      expect(controller.isPlaceMode, isFalse);
      expect(controller.isRemoveMode, isTrue);
    });

    test('selects piece in place mode', () {
      controller.initialize();
      controller.setPlaceMode();
      
      controller.selectPiece('Q');
      
      expect(controller.selectedPiece, equals('Q'));
    });

    test('toggles board flip', () {
      controller.initialize();
      
      expect(controller.boardFlipped, isFalse);
      
      controller.toggleBoardFlip();
      
      expect(controller.boardFlipped, isTrue);
    });

    test('detects piece at square correctly', () {
      controller.initialize();
      
      final e1Square = Square.fromName('e1');
      final e4Square = Square.fromName('e4');
      
      expect(controller.hasPieceAt(e1Square), isTrue); // White king at e1
      expect(controller.getPieceAtSquare(e1Square), equals('K'));
      expect(controller.hasPieceAt(e4Square), isFalse); // Empty square
    });

    test('changes turn correctly', () {
      controller.initialize();
      
      expect(controller.position!.turn, equals(Side.white));
      
      controller.changeTurn(Side.black);
      
      expect(controller.position!.turn, equals(Side.black));
      expect(controller.currentFen, contains(' b '));
    });

    test('sets castling rights correctly', () {
      controller.initialize();
      
      controller.setCastlingRight('whiteKingSide', false);
      controller.setCastlingRight('whiteQueenSide', true);
      controller.setCastlingRight('blackKingSide', true);
      controller.setCastlingRight('blackQueenSide', false);
      
      expect(controller.currentFen, contains(' Qk '));
    });

    test('places piece on square', () {
      controller.initialize();
      controller.setPlaceMode();
      controller.selectPiece('Q');
      
      final e4Square = Square.fromName('e4');
      controller.onSquareTap(e4Square);
      
      expect(controller.hasPieceAt(e4Square), isTrue);
      expect(controller.getPieceAtSquare(e4Square), equals('Q'));
    });

    test('removes piece from square', () {
      controller.initialize();
      controller.setRemoveMode();
      
      final e1Square = Square.fromName('e1');
      expect(controller.hasPieceAt(e1Square), isTrue);
      
      controller.onSquareTap(e1Square);
      
      expect(controller.hasPieceAt(e1Square), isFalse);
    });

    test('clears board', () {
      controller.initialize();
      
      controller.clearBoard();
      
      // Should create empty board FEN
      expect(controller.currentFen, contains('8/8/8/8/8/8/8/8'));
      
      // Position object may not be valid for completely empty board
      // This is expected behavior for editing mode
    });

    test('resets to starting position', () {
      controller.initialize();
      
      // Modify position
      controller.clearBoard();
      expect(controller.currentFen, isNot(equals(TestPositions.startingPosition)));
      
      // Reset
      controller.resetToStartingPosition();
      expect(controller.currentFen, equals(TestPositions.startingPosition));
    });
  });
}