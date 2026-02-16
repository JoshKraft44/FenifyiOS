import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../controllers/position_editor_controller.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';

class EditModeSelector extends StatelessWidget {
  final PositionEditorController controller;

  const EditModeSelector({
    Key? key,
    required this.controller,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildModeButton(
                'Drag & Drop', 
                Icons.open_with_rounded, 
                controller.isDragMode, 
                controller.setDragMode,
              ),
              _buildModeButton(
                'Place', 
                Icons.add_circle_rounded, 
                controller.isPlaceMode, 
                controller.setPlaceMode,
              ),
              _buildModeButton(
                'Remove', 
                Icons.delete_rounded, 
                controller.isRemoveMode, 
                controller.setRemoveMode,
              ),
            ],
          ),
          if (controller.isPlaceMode) ...[
            const SizedBox(height: 12),
            _buildPieceSelector(),
          ],
        ],
      ),
    );
  }

  Widget _buildModeButton(
    String label, 
    IconData icon, 
    bool isSelected, 
    VoidCallback onTap,
  ) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
              ? context.accentColor.withOpacity(0.2)
              : (context.isDarkMode 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.white),
            border: Border.all(
              color: isSelected 
                ? context.accentColor 
                : context.borderColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, 
                size: 24, 
                color: isSelected 
                  ? context.accentColor 
                  : context.secondaryTextColor,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected 
                    ? context.primaryTextColor 
                    : context.secondaryTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieceSelector() {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.isDarkMode 
            ? Colors.white.withOpacity(0.05) 
            : AppColors.seasalt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Text(
              'Select Piece to Place',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: controller.whitePieces.map((piece) => 
                _buildPieceButton(piece['symbol']!, piece['asset']!, true)
              ).toList(),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: context.borderColor),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: controller.blackPieces.map((piece) => 
                _buildPieceButton(piece['symbol']!, piece['asset']!, false)
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieceButton(String pieceSymbol, String assetPath, bool isWhite) {
    final isSelected = controller.selectedPiece == pieceSymbol;
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => controller.selectPiece(pieceSymbol),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected 
              ? context.accentColor.withOpacity(0.3) 
              : (context.isDarkMode 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.white),
            border: Border.all(
              color: isSelected 
                ? context.accentColor 
                : context.borderColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: SvgPicture.asset(
              assetPath,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}