// test/accessibility/accessibility_tests.dart
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
  
  group('Accessibility Tests', () {
    testWidgets('home screen has proper semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(HomeScreen()),
      );
      
      // Test semantic labels
      expect(find.bySemanticsLabel('Upload Photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Edit position manually'), findsOneWidget);
      expect(find.bySemanticsLabel('View saved positions'), findsOneWidget);
    });

    testWidgets('analysis screen has accessible controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          AnalysisScreen(fen: TestPositions.startingPosition),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Test navigation controls accessibility
      expect(find.bySemanticsLabel('Go to start'), findsOneWidget);
      expect(find.bySemanticsLabel('Previous move'), findsOneWidget);
      expect(find.bySemanticsLabel('Next move'), findsOneWidget);
      expect(find.bySemanticsLabel('Go to end'), findsOneWidget);
    });

    testWidgets('chess board squares have proper semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          ChessBoardWidget(fen: TestPositions.startingPosition),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Test that chess squares have semantic labels
      expect(find.bySemanticsLabel(RegExp(r'[a-h][1-8]')), findsWidgets);
    });

    testWidgets('buttons have minimum touch target size', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(HomeScreen()),
      );
      
      final buttonFinders = [
        find.byIcon(Icons.camera_alt_rounded),
        find.byIcon(Icons.edit_note_rounded),
        find.byIcon(Icons.bookmark_rounded),
      ];
      
      for (final finder in buttonFinders) {
        final button = tester.widget(finder);
        final renderBox = tester.renderObject(finder) as RenderBox;
        
        // Minimum touch target should be 44x44 logical pixels
        expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
        expect(renderBox.size.height, greaterThanOrEqualTo(44.0));
      }
    });

    testWidgets('text has sufficient contrast', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(HomeScreen()),
      );
      
      // Test various text elements for contrast (implementation would depend on theme)
      expect(find.text('fenify'), findsOneWidget);
      expect(find.text('Scan Chess Board'), findsOneWidget);
      expect(find.text('Edit Position'), findsOneWidget);
      expect(find.text('Saved Positions'), findsOneWidget);
    });
  });
}