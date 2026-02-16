// test/screens/home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/screens/home_screen.dart';
import '../test_setup.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('HomeScreen Tests', () {
    testWidgets('renders home screen with main options', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(const HomeScreen()),
      );
      
      expect(find.text('fenify'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    testWidgets('navigates to camera analysis', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(const HomeScreen()),
      );
      
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();
      
      // Should navigate to camera screen (implementation dependent)
    });

    testWidgets('navigates to position editor', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(const HomeScreen()),
      );
      
      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();
      
      // Should navigate to position editor
    });

    testWidgets('navigates to saved positions', (WidgetTester tester) async {
      await tester.pumpWidget(
        WidgetTestHelpers.wrapInMaterialApp(const HomeScreen()),
      );
      
      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      await tester.pumpAndSettle();
      
      // Should navigate to saved positions screen
    });
  });
}