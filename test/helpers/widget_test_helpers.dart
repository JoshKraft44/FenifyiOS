// test/helpers/widget_test_helpers.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WidgetTestHelpers {
  static Widget wrapInMaterialApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }
  
  static Widget wrapInProvider<T>(Widget child, T value) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }
  
  static Future<void> enterTextAndPump(WidgetTester tester, Finder finder, String text) async {
    await tester.enterText(finder, text);
    await tester.pump();
  }
  
  static Future<void> tapAndPump(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
  }
  
  static Finder findChessSquare(String square) {
    return find.byKey(Key('chess_square_$square'));
  }
  
  static Finder findChessPiece(String piece) {
    return find.byKey(Key('chess_piece_$piece'));
  }
}