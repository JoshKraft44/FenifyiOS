import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';
import 'dart:ui' as ui;
import '../../../providers/theme_provider.dart';

/// Status indicator widget showing whose turn it is and engine analysis state
class AnalysisStatusWidget extends StatelessWidget {
  final Position position;
  final bool isAnalyzing;
  final bool engineReady;
  final int currentDepth;

  const AnalysisStatusWidget({
    Key? key,
    required this.position,
    required this.isAnalyzing,
    required this.engineReady,
    required this.currentDepth,
  }) : super(key: key);

  // Color palette
  static const ui.Color deepNavy = ui.Color(0xFF1a1a2e);
  static const ui.Color cadetGray = ui.Color(0xFF4a5568);
  static const ui.Color lightBlue = ui.Color(0xFF94C5CC);
  static const ui.Color seasalt = ui.Color(0xFFF7FAFC);
  static const ui.Color successGreen = ui.Color(0xFF7FB069);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(
            color: context.borderColor,
            width: 1.5,
          ),
          bottom: BorderSide(
            color: context.borderColor,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Turn indicator circle
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: position.turn == Side.white
                  ? (context.isDarkMode ? Colors.white : seasalt)
                  : (context.isDarkMode ? Colors.black : deepNavy),
              border: Border.all(
                color: context.isDarkMode
                    ? Colors.white.withOpacity(0.3)
                    : lightBlue,
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Turn text
          Text(
            '${position.turn == Side.white ? "White" : "Black"} to move',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.primaryTextColor,
              fontSize: 15,
            ),
          ),

          const Spacer(),

          // Analysis status
          if (isAnalyzing) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : lightBlue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Depth $currentDepth',
              style: TextStyle(
                color: context.secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (engineReady) ...[
            const Icon(Icons.check_circle_rounded, color: successGreen, size: 18),
            const SizedBox(width: 6),
            const Text(
              'Ready',
              style: TextStyle(
                color: successGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
