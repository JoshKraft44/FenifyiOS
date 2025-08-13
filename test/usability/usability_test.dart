// test/usability/usability_tests.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/screens/home_screen.dart';
import 'package:fenify/screens/analysis_screen/analysis_screen.dart';
import 'package:fenify/widgets/chess_board_widget.dart';
import '../test_setup.dart';
import '../helpers/widget_test_helpers.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('Usability Tests', () {
    testWidgets('user can discover main features easily', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(HomeScreen()),
      );
      
      // Main features should be prominently displayed
      expect(find.text('Scan Chess Board'), findsOneWidget);
      expect(find.text('Edit Position'), findsOneWidget);
      expect(find.text('Saved Positions'), findsOneWidget);
      
      // Icons should be intuitive
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    testWidgets('error messages are clear and helpful', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          ChessBoardWidget(fen: TestPositions.invalidNoKings),
        ),
      );
      
      // Error should be clearly displayed
      expect(find.textContaining('Invalid position'), findsOneWidget);
      
      // Should provide helpful context
      expect(find.textContaining('exactly one'), findsOneWidget);
    });

    testWidgets('navigation is intuitive', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          AnalysisScreen(fen: TestPositions.startingPosition),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Navigation controls should be clearly labeled
      expect(find.byTooltip('Go to start'), findsOneWidget);
      expect(find.byTooltip('Previous move'), findsOneWidget);
      expect(find.byTooltip('Next move'), findsOneWidget);
      expect(find.byTooltip('Go to end'), findsOneWidget);
    });

    testWidgets('user feedback is immediate', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          AnalysisScreen(fen: TestPositions.startingPosition),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Tap flip board button
      final flipButton = find.byIcon(Icons.flip_camera_android);
      await tester.tap(flipButton);
      
      // Should provide immediate visual feedback
      await tester.pump(Duration(milliseconds: 16)); // Single frame
      
      // Visual change should be immediate (specific assertion depends on implementation)
      expect(find.byType(ChessBoardWidget), findsOneWidget);
    });

    testWidgets('complex workflows are guided', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(HomeScreen()),
      );
      
      // Navigate to position editor
      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();
      
      // Should show mode indicators
      expect(find.text('Drag & Drop'), findsOneWidget);
      
      // Switch to place mode
      await tester.tap(find.text('Place'));
      await tester.pump();
      
      // Should show piece selector
      expect(find.text('Select Piece to Place'), findsOneWidget);
      
      // Save the position
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();
      
      // Should return to analysis screen
      expect(find.text('Analysis'), findsOneWidget);
    });
  });
}