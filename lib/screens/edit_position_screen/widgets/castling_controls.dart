import 'package:flutter/material.dart';
import '../controllers/position_editor_controller.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';

class CastlingControls extends StatelessWidget {
  final PositionEditorController controller;

  const CastlingControls({
    Key? key,
    required this.controller,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.castle_rounded, color: context.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Castling Rights',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: context.primaryTextColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  controller.autoDetectCastlingRights();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Castling rights auto-detected'),
                      backgroundColor: AppColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.successGreen),
                label: const Text(
                  'Auto-detect',
                  style: TextStyle(color: AppColors.successGreen, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('White:', style: TextStyle(fontWeight: FontWeight.w600, color: context.primaryTextColor)),
                    const SizedBox(height: 8),
                    _buildCastlingCheckbox(
                      context,
                      'King-side (O-O)', 
                      controller.whiteKingSide, 
                      controller.possibleCastlingRights?.whiteKingSide ?? false,
                      (value) => _setCastlingRight(context, 'whiteKingSide', value ?? false),
                    ),
                    _buildCastlingCheckbox(
                      context,
                      'Queen-side (O-O-O)', 
                      controller.whiteQueenSide,
                      controller.possibleCastlingRights?.whiteQueenSide ?? false,
                      (value) => _setCastlingRight(context, 'whiteQueenSide', value ?? false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Black:', style: TextStyle(fontWeight: FontWeight.w600, color: context.primaryTextColor)),
                    const SizedBox(height: 8),
                    _buildCastlingCheckbox(
                      context,
                      'King-side (O-O)', 
                      controller.blackKingSide,
                      controller.possibleCastlingRights?.blackKingSide ?? false,
                      (value) => _setCastlingRight(context, 'blackKingSide', value ?? false),
                    ),
                    _buildCastlingCheckbox(
                      context,
                      'Queen-side (O-O-O)', 
                      controller.blackQueenSide,
                      controller.possibleCastlingRights?.blackQueenSide ?? false,
                      (value) => _setCastlingRight(context, 'blackQueenSide', value ?? false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCastlingCheckbox(
    BuildContext context,
    String title, 
    bool value, 
    bool isPossible, 
    ValueChanged<bool?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.successGreen,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isPossible 
                  ? context.secondaryTextColor 
                  : context.secondaryTextColor.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPossible ? AppColors.successGreen : AppColors.errorRed.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  void _setCastlingRight(BuildContext context, String rightType, bool value) {
    if (value) {
      // Check if this castling right is possible
      final possible = controller.possibleCastlingRights;
      bool isValid = false;
      
      switch (rightType) {
        case 'whiteKingSide':
          isValid = possible?.whiteKingSide ?? false;
          break;
        case 'whiteQueenSide':
          isValid = possible?.whiteQueenSide ?? false;
          break;
        case 'blackKingSide':
          isValid = possible?.blackKingSide ?? false;
          break;
        case 'blackQueenSide':
          isValid = possible?.blackQueenSide ?? false;
          break;
      }
      
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This castling right is not possible with the current piece positions'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    
    controller.setCastlingRight(rightType, value);
  }
}