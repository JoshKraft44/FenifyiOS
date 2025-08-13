// test/widgets/analysis_display_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/widgets/analysis_widgets.dart';
import '../test_setup.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('AnalysisWidgets Tests', () {
    testWidgets('shows initializing widget', (WidgetTester tester) async {
      final widget = AnalysisWidgets.buildInitializingWidget('Initializing analysis engine...');
      
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(widget),
      );
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Initializing analysis engine...'), findsOneWidget);
    });

    testWidgets('shows analysis card', (WidgetTester tester) async {
      final widget = AnalysisWidgets.buildAnalysisCard(
        evaluationScore: 0.25,
        isMateScore: false,
        mateInMoves: 0,
        multiPV: [['e2e4', 'e7e5', 'g1f3']],
        moveEvaluations: ['+0.25'],
        formatMove: (move) => move,
      );
      
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(widget),
      );
      
      expect(find.textContaining('Evaluation: +0.25'), findsOneWidget);
      expect(find.textContaining('e2e4'), findsOneWidget);
    });

    testWidgets('shows error widget', (WidgetTester tester) async {
      final widget = AnalysisWidgets.buildErrorWidget(
        lastError: 'Test error message',
        onRestart: () {},
      );
      
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(widget),
      );
      
      expect(find.text('Analysis Error'), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.text('Restart Engine'), findsOneWidget);
    });

    testWidgets('shows mate score correctly', (WidgetTester tester) async {
      final widget = AnalysisWidgets.buildAnalysisCard(
        evaluationScore: 999.0,
        isMateScore: true,
        mateInMoves: 3,
        multiPV: [['Qh5+']],
        moveEvaluations: ['M3'],
        formatMove: (move) => move,
      );
      
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(widget),
      );
      
      expect(find.textContaining('Mate in 3'), findsOneWidget);
    });
  });
}