// test/integration/app_integration_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/main.dart' as app;
import 'package:fenify/screens/analysis_screen/widgets/analysis_board_widget.dart';
import '../test_setup.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('App Integration Tests', () {
    testWidgets('full app workflow - edit position and analyze', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // Should start on home screen
      expect(find.text('fenify'), findsOneWidget);
      
      // Go to position editor
      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();
      
      // Should be on position editor
      expect(find.text('Edit Position'), findsOneWidget);
      
      // Enter custom FEN
      const customFen = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';
      await tester.enterText(find.byType(TextFormField), customFen);
      
      // Navigate to analysis
      await tester.tap(find.text('Analyze Position'));
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Should be on analysis screen
      expect(find.text('Analysis'), findsOneWidget);
      expect(find.byType(AnalysisBoardWidget), findsOneWidget);
    });

    testWidgets('save and load position workflow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // Navigate to position editor
      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();
      
      // Create and analyze position
      const testFen = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';
      await tester.enterText(find.byType(TextFormField), testFen);
      await tester.tap(find.text('Analyze Position'));
      await tester.pumpAndSettle();
      
      // Save position
      await tester.tap(find.byIcon(Icons.bookmark_add_rounded));
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byType(TextField).last, 'Integration Test Position');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      
      // Navigate to saved positions
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      await tester.pumpAndSettle();
      
      // Should find saved position
      expect(find.text('Integration Test Position'), findsOneWidget);
      
      // Load the position
      await tester.tap(find.text('Integration Test Position'));
      await tester.pumpAndSettle();
      
      // Should be back on analysis screen with loaded position
      expect(find.text('Analysis'), findsOneWidget);
    });

    testWidgets('app handles rapid navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // Rapidly navigate between screens
      for (int i = 0; i < 5; i++) {
        // Go to position editor
        await tester.tap(find.byIcon(Icons.edit_note_rounded));
        await tester.pump(Duration(milliseconds: 100));
        
        // Go back
        await tester.pageBack();
        await tester.pump(Duration(milliseconds: 100));
        
        // Go to saved positions
        await tester.tap(find.byIcon(Icons.bookmark_rounded));
        await tester.pump(Duration(milliseconds: 100));
        
        // Go back
        await tester.pageBack();
        await tester.pump(Duration(milliseconds: 100));
      }
      
      await tester.pumpAndSettle();
      
      // Should still be functional
      expect(find.text('fenify'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('app persists state correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // Make some changes that should persist
      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();
      
      // Enter custom FEN
      const customFen = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';
      await tester.enterText(find.byType(TextFormField), customFen);
      
      // Navigate to analysis
      await tester.tap(find.text('Analyze Position'));
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Save position
      await tester.tap(find.byIcon(Icons.bookmark_add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Persistence Test');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      
      // Simulate app restart by navigating away and back
      await tester.pageBack();
      await tester.pumpAndSettle();
      
      // Check saved positions
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      await tester.pumpAndSettle();
      
      // Position should still be there
      expect(find.text('Persistence Test'), findsOneWidget);
    });
  });
}
