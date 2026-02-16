import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// State model for chess position analysis
/// Manages position data, engine state, analysis results, and UI state
class AnalysisState {
  // Position state
  final String currentFen;
  final String originalFen;
  final List<Map<String, dynamic>> gameHistory;
  final int currentMoveIndex;
  final bool isInvalidPosition;

  // Engine state
  final bool isInitializing;
  final bool isAnalyzing;
  final bool hasError;
  final bool engineReady;
  final String analysisText;
  final String? lastError;

  // Analysis data
  final double evaluationScore;
  final bool isMateScore;
  final int mateInMoves;
  final String bestMove;  // SAN format for display
  final String bestMoveUci;  // UCI format for highlighting
  final bool showBestMove;
  final int currentDepth;
  final List<String> principalVariation;
  final List<String> moveEvaluations;
  final List<List<String>> multiPV;

  // UI state
  final bool boardFlipped;
  final bool showArrows;
  final Set<Square> highlightedSquares;
  final ISet<Shape> boardShapes;
  final Square? lastMoveFrom;
  final Square? lastMoveTo;

  // Move state
  final bool awaitingPromotion;
  final Move? pendingPromotionMove;

  const AnalysisState({
    this.currentFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.originalFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.gameHistory = const [],
    this.currentMoveIndex = 0,
    this.isInvalidPosition = false,
    this.isInitializing = true,
    this.isAnalyzing = false,
    this.hasError = false,
    this.engineReady = false,
    this.analysisText = 'Initializing analysis engine...',
    this.lastError,
    this.evaluationScore = 0.0,
    this.isMateScore = false,
    this.mateInMoves = 0,
    this.bestMove = '',
    this.bestMoveUci = '',
    this.showBestMove = false,
    this.currentDepth = 0,
    this.principalVariation = const [],
    this.moveEvaluations = const [],
    this.multiPV = const [],
    this.boardFlipped = false,
    this.showArrows = true,
    this.highlightedSquares = const <Square>{},
    this.boardShapes = const ISetConst({}),
    this.lastMoveFrom,
    this.lastMoveTo,
    this.awaitingPromotion = false,
    this.pendingPromotionMove,
  });

  AnalysisState copyWith({
    String? currentFen,
    String? originalFen,
    List<Map<String, dynamic>>? gameHistory,
    int? currentMoveIndex,
    bool? isInvalidPosition,
    bool? isInitializing,
    bool? isAnalyzing,
    bool? hasError,
    bool? engineReady,
    String? analysisText,
    String? lastError,
    double? evaluationScore,
    bool? isMateScore,
    int? mateInMoves,
    String? bestMove,
    String? bestMoveUci,
    bool? showBestMove,
    int? currentDepth,
    List<String>? principalVariation,
    List<String>? moveEvaluations,
    List<List<String>>? multiPV,
    bool? boardFlipped,
    bool? showArrows,
    Set<Square>? highlightedSquares,
    ISet<Shape>? boardShapes,
    Square? lastMoveFrom,
    Square? lastMoveTo,
    bool? awaitingPromotion,
    Move? pendingPromotionMove,
  }) {
    return AnalysisState(
      currentFen: currentFen ?? this.currentFen,
      originalFen: originalFen ?? this.originalFen,
      gameHistory: gameHistory ?? this.gameHistory,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      isInvalidPosition: isInvalidPosition ?? this.isInvalidPosition,
      isInitializing: isInitializing ?? this.isInitializing,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      hasError: hasError ?? this.hasError,
      engineReady: engineReady ?? this.engineReady,
      analysisText: analysisText ?? this.analysisText,
      lastError: lastError ?? this.lastError,
      evaluationScore: evaluationScore ?? this.evaluationScore,
      isMateScore: isMateScore ?? this.isMateScore,
      mateInMoves: mateInMoves ?? this.mateInMoves,
      bestMove: bestMove ?? this.bestMove,
      bestMoveUci: bestMoveUci ?? this.bestMoveUci,
      showBestMove: showBestMove ?? this.showBestMove,
      currentDepth: currentDepth ?? this.currentDepth,
      principalVariation: principalVariation ?? this.principalVariation,
      moveEvaluations: moveEvaluations ?? this.moveEvaluations,
      multiPV: multiPV ?? this.multiPV,
      boardFlipped: boardFlipped ?? this.boardFlipped,
      showArrows: showArrows ?? this.showArrows,
      highlightedSquares: highlightedSquares ?? this.highlightedSquares,
      boardShapes: boardShapes ?? this.boardShapes,
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
      awaitingPromotion: awaitingPromotion ?? this.awaitingPromotion,
      pendingPromotionMove: pendingPromotionMove ?? this.pendingPromotionMove,
    );
  }

  /// Convenience getters for common state checks
  bool get hasValidPosition => !isInvalidPosition;
  bool get canAnalyze => hasValidPosition && engineReady && !hasError;
  bool get isReadyForMoves => hasValidPosition && !awaitingPromotion;
  
  String get evaluationText {
    if (isMateScore) {
      return 'Mate in ${mateInMoves.abs()} for ${mateInMoves > 0 ? "White" : "Black"}';
    } else {
      final sign = evaluationScore >= 0 ? '+' : '';
      return '$sign${evaluationScore.toStringAsFixed(2)}';
    }
  }
  
  String get statusText {
    if (hasError) return 'Error: ${lastError ?? "Unknown error"}';
    if (isInvalidPosition) return 'Invalid Position';
    if (isInitializing) return 'Initializing...';
    if (isAnalyzing) return 'Analyzing (Depth $currentDepth)';
    if (engineReady) return 'Ready';
    return 'Not Ready';
  }
  
  @override
  String toString() {
    return 'AnalysisState(fen: $currentFen, analyzing: $isAnalyzing, depth: $currentDepth, eval: $evaluationScore)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnalysisState &&
        other.currentFen == currentFen &&
        other.currentMoveIndex == currentMoveIndex &&
        other.isAnalyzing == isAnalyzing &&
        other.evaluationScore == evaluationScore;
  }
  
  @override
  int get hashCode {
    return Object.hash(currentFen, currentMoveIndex, isAnalyzing, evaluationScore);
  }
}