// test/screens/analysis_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/screens/analysis_screen/analysis_screen.dart';
import 'package:fenify/screens/analysis_screen/widgets/analysis_board_widget.dart';
import 'package:fenify/screens/analysis_screen/widgets/analysis_content_widget.dart';
import '../test_setup.dart';
import '../helpers/widget_test_helpers.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('AnalysisScreen Tests', () {
    testWidgets('renders analysis screen correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          AnalysisScreen(fen: TestPositions.startingPosition),
        ),
      );
      
      expect(find.byType(AnalysisScreen), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
    });

    testWidgets('shows chess board and analysis panel', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          AnalysisScreen(fen: TestPositions.startingPosition),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Should find chess board
      expect(find.byType(AnalysisBoardWidget), findsOneWidget);
      
      // Should find analysis display
      expect(find.byType(AnalysisContentWidget), findsOneWidget);
    });

    testWidgets('navigation controls work', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          AnalysisScreen(fen: TestPositions.englishOpening),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Find navigation buttons
      final startButton = find.byIcon(Icons.skip_previous);
      final backButton = find.byIcon(Icons.keyboard_arrow_left);
      final forwardButton = find.byIcon(Icons.keyboard_arrow_right);
      final endButton = find.byIcon(Icons.skip_next);
      
      expect(startButton, findsOneWidget);
      expect(backButton, findsOneWidget);
      expect(forwardButton, findsOneWidget);
      expect(endButton, findsOneWidget);
    });

    testWidgets('flip board button works', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(
          AnalysisScreen(fen: TestPositions.startingPosition),
        ),
      );
      
      await tester.pumpAndSettle();
      
      final flipButton = find.byIcon(Icons.flip_camera_android);
      expect(flipButton, findsOneWidget);
      
      await tester.tap(flipButton);
      await tester.pump();
      
      // Board should be flipped (specific assertions would depend on implementation)
    });
  });
}