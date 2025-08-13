import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../controllers/analysis_controller.dart';
import '../../../providers/theme_provider.dart';
import 'dart:ui' as ui;

/// Chess board widget for analysis screen with support for invalid positions and interactive moves
class AnalysisBoardWidget extends StatelessWidget {
  final double boardSize;
  final AnalysisController controller;

  const AnalysisBoardWidget({
    Key? key,
    required this.boardSize,
    required this.controller,
  }) : super(key: key);

  // Color palette
  static const ui.Color cadetGray = ui.Color(0xFF4a5568);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: _buildChessBoard(context),
    );
  }

  Widget _buildChessBoard(BuildContext context) {
    // For invalid positions, try to display the invalid FEN on the board
    if (controller.isInvalidPosition) {
      return _buildInvalidPositionBoard(context);
    }

    final chess = controller.chess;
    
    if (chess == null) {
      return _buildInvalidPositionPlaceholder(context);
    }

    return Chessboard(
      size: boardSize,
      orientation: controller.boardFlipped ? Side.black : Side.white,
      fen: chess.fen,
      settings: ChessboardSettings(
        colorScheme: _getBoardColorScheme(context),
      ),
      game: GameData(
        playerSide: PlayerSide.both,
        sideToMove: controller.position?.turn ?? Side.white,
        validMoves: controller.buildValidMovesMap(),
        promotionMove: controller.awaitingPromotion && controller.pendingPromotionMove is NormalMove 
            ? controller.pendingPromotionMove as NormalMove 
            : null,
        onMove: controller.onMove,
        onPromotionSelection: controller.onPromotionSelection,
      ),
      shapes: controller.boardShapes.isNotEmpty ? controller.boardShapes : null,
    );
  }

  /// Returns theme-appropriate chess board color scheme
  ChessboardColorScheme _getBoardColorScheme(BuildContext context) {
    if (context.isDarkMode) {
      // Dark theme - brighter modern grays
      return ChessboardColorScheme(
        lightSquare: const Color(0xFF5a5a5a), // Brighter medium gray
        darkSquare: const Color(0xFF404040),   // Brighter darker gray
        background: SolidColorChessboardBackground(
          lightSquare: const Color(0xFF5a5a5a),
          darkSquare: const Color(0xFF404040),
          coordinates: false,
        ),
        whiteCoordBackground: SolidColorChessboardBackground(
          lightSquare: const Color(0xFF5a5a5a),
          darkSquare: const Color(0xFF404040),
          coordinates: true,
        ),
        blackCoordBackground: SolidColorChessboardBackground(
          lightSquare: const Color(0xFF5a5a5a),
          darkSquare: const Color(0xFF404040),
          coordinates: true,
        ),
        lastMove: HighlightDetails(
          solidColor: const Color(0xFF656565),
        ),
        selected: HighlightDetails(
          solidColor: const Color(0xFF707070),
        ),
        validMoves: const Color(0xFF909090),
        validPremoves: const Color(0xFF808080),
      );
    } else {
      // Light theme - keep existing blue scheme
      return ChessboardColorScheme.blue;
    }
  }

  /// Attempts to display invalid FEN by fixing game state part for visual representation
  Widget _buildInvalidPositionBoard(BuildContext context) {
    // Try to display the invalid FEN on the board
    try {
      final invalidFen = controller.currentFen;
      
      // Extract just the board part (before the first space)
      final boardPart = invalidFen.split(' ')[0];
      
      // Try to create a displayable FEN by fixing the game state part
      final displayFen = '$boardPart w KQkq - 0 1';
      
      return Chessboard(
        size: boardSize,
        orientation: controller.boardFlipped ? Side.black : Side.white,
        fen: displayFen,
        settings: ChessboardSettings(
          colorScheme: _getBoardColorScheme(context),
        ),
        game: GameData(
          playerSide: PlayerSide.none, // No moves allowed for invalid positions
          sideToMove: Side.white,
          validMoves: <Square, ISet<Square>>{}.lock,
          promotionMove: null,
          onMove: (move, {isDrop}) {}, // No-op
          onPromotionSelection: (role) {}, // No-op
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error displaying invalid position: $e');
      return _buildInvalidPositionPlaceholder(context);
    }
  }

  Widget _buildInvalidPositionPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          'Invalid Position\nUse Edit to Fix',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cadetGray,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}