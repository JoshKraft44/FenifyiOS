import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';
import 'dart:ui' as ui;
import '../controllers/position_editor_controller.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';

/// A widget that displays the current turn (White or Black) in the position editor
class TurnIndicator extends StatelessWidget {
  /// The position editor controller that manages the chess position state
  final PositionEditorController controller;

  const TurnIndicator({
    Key? key,
    required this.controller,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    // Get the current turn from the position, defaulting to white if no position exists
    final currentTurn = controller.position?.turn ?? Side.white;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor, // Theme-aware surface color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor), // Theme-aware border
      ),
      child: Row(
        children: [
          // Visual indicator circle showing current turn color
          Container(
            width: 20, 
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // White circle for white turn, black for black turn
              // Colors adapt to theme for better contrast
              color: currentTurn == Side.white 
                ? (context.isDarkMode ? Colors.white : AppColors.seasalt)
                : (context.isDarkMode ? Colors.black : AppColors.deepNavy),
              border: Border.all(
                color: context.isDarkMode ? Colors.white.withOpacity(0.3) : AppColors.lightBlue, 
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Tappable text and icon to open turn selector dialog
          GestureDetector(
            onTap: () => _showTurnSelectorDialog(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currentTurn == Side.white ? "White" : "Black"} to move',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.primaryTextColor, // Theme-aware text color
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                // Swap icon indicating the field is interactive
                Icon(
                  Icons.swap_horiz_rounded,
                  color: context.accentColor, // Theme-aware accent color
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog allowing the user to select which side should move next
  void _showTurnSelectorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // Use opaque background that adapts to theme
          backgroundColor: context.isDarkMode ? const Color(0xFF1a1a1a) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, color: context.accentColor, size: 24),
              const SizedBox(width: 8),
              Text('Select Turn', style: TextStyle(color: context.primaryTextColor, fontWeight: FontWeight.w600)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Option for White to move
              _buildTurnOption(context, 'White to move', Colors.white, () => _changeTurn(context, Side.white)),
              const SizedBox(height: 8),
              // Option for Black to move
              _buildTurnOption(context, 'Black to move', AppColors.deepNavy, () => _changeTurn(context, Side.black)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: context.secondaryTextColor)),
            ),
          ],
        );
      },
    );
  }

  /// Builds a selectable option in the turn selector dialog
  /// 
  /// [context] - The build context for theme access
  /// [title] - The text to display (e.g., "White to move")
  /// [circleColor] - The color of the indicator circle (white or black)
  /// [onTap] - Callback function when the option is selected
  Widget _buildTurnOption(BuildContext context, String title, ui.Color circleColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDarkMode 
            ? Colors.white.withOpacity(0.05) 
            : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            // Color indicator circle showing the piece color
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleColor, // White or black circle
                border: Border.all(
                  // Border color adapts to theme for visibility
                  color: context.isDarkMode ? Colors.white.withOpacity(0.3) : AppColors.lightBlue, 
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Changes the current turn to the specified side and closes the dialog
  /// 
  /// [context] - The build context for navigation
  /// [newTurn] - The new side to move (Side.white or Side.black)
  void _changeTurn(BuildContext context, Side newTurn) {
    Navigator.of(context).pop(); // Close the dialog
    controller.changeTurn(newTurn); // Update the turn in the controller
  }
}