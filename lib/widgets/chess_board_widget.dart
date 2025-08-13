import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

/// Interactive chess board widget with optional FEN loading and position change callbacks
class ChessBoardWidget extends StatelessWidget {
  final String fen;
  final bool interactive;
  final Function(String)? onPositionChanged;
  
  const ChessBoardWidget({
    Key? key,
    required this.fen,
    this.interactive = false,
    this.onPositionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = ChessBoardController();
    
    // Load the FEN position
    try {
      controller.loadFen(fen);
    } catch (e) {
      return Center(
        child: Text('Invalid position: $e'),
      );
    }
    
    // Set up a listener if the board is interactive
    if (interactive && onPositionChanged != null) {
      controller.addListener(() {
        onPositionChanged!(controller.getFen());
      });
    }
    
    return ChessBoard(
      controller: controller,
      boardColor: BoardColor.orange,
      boardOrientation: PlayerColor.white,
      enableUserMoves: interactive,
      arrows: const [],
    );
  }
}
