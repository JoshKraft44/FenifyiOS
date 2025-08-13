import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';
import '../controllers/position_editor_controller.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';

class TapOverlay extends StatelessWidget {
  final double boardSize;
  final PositionEditorController controller;

  const TapOverlay({
    Key? key,
    required this.boardSize,
    required this.controller,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          late final int file;
          late final int rank;
          
          if (controller.boardFlipped) {
            file = 7 - (index % 8);
            rank = index ~/ 8;
          } else {
            file = index % 8;
            rank = 7 - (index ~/ 8);
          }
          
          final square = Square.fromCoords(File.values[file], Rank.values[rank]);
          final hasPiece = controller.hasPieceAt(square);
          final isSelected = controller.selectedSquare == square;
          
          return GestureDetector(
            onTap: () => controller.onSquareTap(square),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected 
                  ? context.accentColor.withOpacity(0.6)
                  : Colors.transparent,
                border: isSelected 
                  ? Border.all(color: context.accentColor, width: 3)
                  : null,
              ),
              child: controller.isDragMode && hasPiece && !isSelected
                ? Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: context.isDarkMode 
                          ? Colors.white.withOpacity(0.3) 
                          : AppColors.lightBlue.withOpacity(0.5), 
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : null,
            ),
          );
        },
      ),
    );
  }
}