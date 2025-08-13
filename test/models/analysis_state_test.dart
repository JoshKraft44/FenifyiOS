// test/models/analysis_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/screens/analysis_screen/models/analysis_state.dart';
import 'package:dartchess/dartchess.dart';
import '../test_setup.dart';
import '../fixtures/test_positions.dart';

void main() {
  setUpAll(() {
    TestSetup.setupAll();
  });
  
  group('AnalysisState Tests', () {
    test('creates default state correctly', () {
      const state = AnalysisState();
      
      expect(state.currentFen, equals(TestPositions.startingPosition));
      expect(state.isInitializing, isTrue);
      expect(state.isAnalyzing, isFalse);
      expect(state.hasError, isFalse);
      expect(state.engineReady, isFalse);
      expect(state.boardFlipped, isFalse);
      expect(state.showArrows, isTrue);
      expect(state.currentMoveIndex, equals(0));
    });

    test('copyWith creates modified state correctly', () {
      const originalState = AnalysisState();
      
      final newState = originalState.copyWith(
        isAnalyzing: true,
        evaluationScore: 1.5,
        bestMove: 'e2e4',
        currentDepth: 10,
      );
      
      expect(newState.isAnalyzing, isTrue);
      expect(newState.evaluationScore, equals(1.5));
      expect(newState.bestMove, equals('e2e4'));
      expect(newState.currentDepth, equals(10));
      // Unchanged properties should remain the same
      expect(newState.currentFen, equals(originalState.currentFen));
      expect(newState.boardFlipped, equals(originalState.boardFlipped));
    });

    test('helper methods work correctly', () {
      const state = AnalysisState(
        isInvalidPosition: false,
        engineReady: true,
        hasError: false,
        awaitingPromotion: false,
      );
      
      expect(state.hasValidPosition, isTrue);
      expect(state.canAnalyze, isTrue);
      expect(state.isReadyForMoves, isTrue);
    });

    test('evaluation text formats correctly', () {
      const positiveEvalState = AnalysisState(evaluationScore: 1.25, isMateScore: false);
      const negativeEvalState = AnalysisState(evaluationScore: -0.75, isMateScore: false);
      const mateState = AnalysisState(isMateScore: true, mateInMoves: 3);
      
      expect(positiveEvalState.evaluationText, equals('+1.25'));
      expect(negativeEvalState.evaluationText, equals('-0.75'));
      expect(mateState.evaluationText, equals('Mate in 3 for White'));
    });

    test('status text reflects current state', () {
      const initializingState = AnalysisState(isInitializing: true);
      const analyzingState = AnalysisState(isInitializing: false, isAnalyzing: true, currentDepth: 8);
      const errorState = AnalysisState(hasError: true, lastError: 'Test error');
      const readyState = AnalysisState(isInitializing: false, engineReady: true);
      
      expect(initializingState.statusText, equals('Initializing...'));
      expect(analyzingState.statusText, equals('Analyzing (Depth 8)'));
      expect(errorState.statusText, equals('Error: Test error'));
      expect(readyState.statusText, equals('Ready'));
    });

    test('equality and hashCode work correctly', () {
      const state1 = AnalysisState(evaluationScore: 1.5, currentDepth: 10);
      const state2 = AnalysisState(evaluationScore: 1.5, currentDepth: 10);
      const state3 = AnalysisState(evaluationScore: 2.0, currentDepth: 10);
      
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
      expect(state1.hashCode, equals(state2.hashCode));
      expect(state1.hashCode, isNot(equals(state3.hashCode)));
    });
  });
}