import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';
import '../../../providers/theme_provider.dart';

/// Widget for selecting chess pieces during position editing
class PieceSelector extends StatelessWidget {
  final Function(String piece) onPieceSelected;
  final String? selectedPiece;

  const PieceSelector({
    Key? key,
    required this.onPieceSelected,
    this.selectedPiece,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const pieces = [
      'K', 'Q', 'R', 'B', 'N', 'P', // White pieces
      'k', 'q', 'r', 'b', 'n', 'p', // Black pieces
    ];
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: context.isDarkMode ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pieces.length + 1, // +1 for eraser
              itemBuilder: (context, index) {
                if (index == pieces.length) {
                  // Eraser tool
                  return _buildPieceButton(
                    context,
                    '🗑️',
                    '',
                    selectedPiece == '',
                  );
                }
                
                final piece = pieces[index];
                return _buildPieceButton(
                  context,
                  _getPieceUnicode(piece),
                  piece,
                  selectedPiece == piece,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieceButton(
    BuildContext context,
    String display,
    String piece,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => onPieceSelected(piece),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected 
            ? Colors.blue.withOpacity(0.3) 
            : (context.isDarkMode ? const Color(0xFFCCCCCC) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            display,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }

  String _getPieceUnicode(String piece) {
    const pieceUnicode = {
      'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
      'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
    };
    return pieceUnicode[piece] ?? piece;
  }
}