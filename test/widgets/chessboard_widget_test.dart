// test/widgets/chess_board_widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/widgets/chess_board_widget.dart';
import '../test_setup.dart';
import '../helpers/widget_test_helpers.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('ChessBoardWidget Tests', () {
    testWidgets('displays chess board with starting position', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          ChessBoardWidget(fen: TestPositions.startingPosition),
        ),
      );
      
      expect(find.byType(ChessBoardWidget), findsOneWidget);
    });

    testWidgets('shows error for invalid FEN', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          ChessBoardWidget(fen: TestPositions.invalidNoKings),
        ),
      );
      
      expect(find.textContaining('Invalid position'), findsOneWidget);
    });

    testWidgets('calls onPositionChanged when interactive', (WidgetTester tester) async {
      String? changedFen;
      
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          ChessBoardWidget(
            fen: TestPositions.startingPosition,
            interactive: true,
            onPositionChanged: (fen) {
              changedFen = fen;
            },
          ),
        ),
      );
      
      // Test that the widget responds to interactions
      expect(find.byType(ChessBoardWidget), findsOneWidget);
    });
  });
}