import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../providers/theme_provider.dart';

/// Static helper methods for building consistent analysis UI components with unified styling
class AnalysisWidgets {

  static Widget buildInitializingWidget(String analysisText) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLarge),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                context.isDarkMode ? Colors.white.withOpacity(0.8) : AppColors.lightBlue,
              ), 
              strokeWidth: 3
            ),
            const SizedBox(height: 20),
            Text(
              analysisText, 
              style: TextStyle(
                color: context.secondaryTextColor, 
                fontSize: 14, 
                fontWeight: FontWeight.w500
              ), 
              textAlign: TextAlign.center
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildStatusIndicator({
    required Position position,
    required bool isAnalyzing,
    required bool engineReady,
    required int currentDepth,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLarge),
        border: Border.all(color: AppColors.lightBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 20, 
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: position.turn == Side.white ? AppColors.seasalt : AppColors.deepNavy,
              border: Border.all(color: AppColors.lightBlue, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${position.turn == Side.white ? "White" : "Black"} to move', 
            style: TextStyle(
              fontWeight: FontWeight.w600, 
              color: AppColors.deepNavy, 
              fontSize: 15
            )
          ),
          const Spacer(),
          if (isAnalyzing) ...[
            SizedBox(
              width: 16, 
              height: 16, 
              child: CircularProgressIndicator(
                strokeWidth: 2, 
                valueColor: AlwaysStoppedAnimation<ui.Color>(AppColors.lightBlue)
              )
            ),
            const SizedBox(width: 8),
            Text(
              'Depth $currentDepth', 
              style: TextStyle(
                color: AppColors.cadetGray, 
                fontSize: 12, 
                fontWeight: FontWeight.w500
              )
            ),
          ] else if (engineReady) ...[
            Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 18),
            const SizedBox(width: 6),
            Text(
              'Ready', 
              style: TextStyle(
                color: AppColors.successGreen, 
                fontSize: 12, 
                fontWeight: FontWeight.w600
              )
            ),
          ],
        ],
      ),
    );
  }

  static Widget buildAnalysisCard({
    required double evaluationScore,
    required bool isMateScore,
    required int mateInMoves,
    required List<List<String>> multiPV,
    required List<String> moveEvaluations,
    required String Function(String) formatMove,
  }) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(math.min(3, multiPV.length), (index) {
              if (index >= multiPV.length || multiPV[index].isEmpty) {
                return const SizedBox.shrink();
              }
              final eval = index < moveEvaluations.length ? moveEvaluations[index] : "0.00";
              final variation = multiPV[index].take(3).map(formatMove).join(' ');
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.isDarkMode
                    ? (index == 0
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05))
                    : (index == 0
                        ? AppColors.columbiaBlue.withOpacity(0.15)
                        : AppColors.seasalt),
                  border: Border(
                    top: index > 0
                      ? BorderSide(
                          color: context.isDarkMode
                            ? Colors.white.withOpacity(0.15)
                            : context.borderColor,
                          width: 0.5,
                        )
                      : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24, 
                      height: 24,
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                          ? (index == 0 
                              ? Colors.white.withOpacity(0.2) 
                              : Colors.white.withOpacity(0.1))
                          : (index == 0 
                              ? AppColors.columbiaBlue 
                              : AppColors.lightBlue.withOpacity(0.3)), 
                        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium)
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}', 
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.bold, 
                            color: context.isDarkMode ? Colors.white : AppColors.deepNavy
                          )
                        )
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        variation, 
                        style: TextStyle(
                          fontSize: 13, 
                          fontFamily: 'monospace', 
                          color: context.isDarkMode 
                            ? Colors.white.withOpacity(0.9) 
                            : AppColors.cadetGray, 
                          fontWeight: FontWeight.w500
                        ), 
                        overflow: TextOverflow.ellipsis
                      )
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.isDarkMode 
                          ? Colors.white.withOpacity(0.15) 
                          : AppColors.deepNavy.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Text(
                        eval, 
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.bold, 
                          color: context.isDarkMode ? Colors.white : AppColors.deepNavy
                        )
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  static Widget buildEvaluationBar({
    required double evaluationScore,
    required bool isMateScore,
    required int mateInMoves,
  }) {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(
            top: BorderSide(
              color: context.borderColor,
              width: 1.5,
            ),
            bottom: BorderSide(
              color: context.borderColor,
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Evaluation: ${isMateScore ? "Mate in ${mateInMoves.abs()} for ${mateInMoves > 0 ? 'White' : 'Black'}" : "${evaluationScore >= 0 ? '+' : ''}${evaluationScore.toStringAsFixed(2)}"}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: context.primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildErrorWidget({
    required String? lastError,
    required VoidCallback onRestart,
  }) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLarge),
          border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 48),
            const SizedBox(height: 16),
            Text(
              'Analysis Error', 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                color: context.primaryTextColor, 
                fontSize: 18
              )
            ),
            const SizedBox(height: 12),
            Text(
              lastError ?? 'Unknown error occurred', 
              textAlign: TextAlign.center, 
              style: TextStyle(color: context.secondaryTextColor, fontSize: 14)
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Restart Engine'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.columbiaBlue, 
                foregroundColor: context.isDarkMode ? Colors.black : AppColors.deepNavy
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildNavigationBar({
    required int currentMoveIndex,
    required int gameHistoryLength,
    required VoidCallback onStart,
    required VoidCallback onBack,
    required VoidCallback onForward,
    required VoidCallback onEnd,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepNavy.withOpacity(0.1), 
            blurRadius: 20, 
            offset: const Offset(0, -8)
          )
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                Icons.first_page_rounded, 
                'Start', 
                currentMoveIndex > 0, 
                onStart
              ),
              _buildNavButton(
                Icons.chevron_left_rounded, 
                'Back', 
                currentMoveIndex > 0, 
                onBack
              ),
              _buildNavButton(
                Icons.chevron_right_rounded, 
                'Forward', 
                currentMoveIndex < gameHistoryLength - 1, 
                onForward
              ),
              _buildNavButton(
                Icons.last_page_rounded, 
                'End', 
                currentMoveIndex < gameHistoryLength - 1, 
                onEnd
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildNavButton(
    IconData icon, 
    String label, 
    bool enabled, 
    VoidCallback onPressed
  ) {
    return Expanded(
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: enabled ? AppColors.columbiaBlue.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMedium),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                color: enabled ? AppColors.deepNavy : AppColors.cadetGray.withOpacity(0.5), 
                size: 24
              ),
              const SizedBox(height: 4),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w500, 
                  color: enabled ? AppColors.deepNavy : AppColors.cadetGray.withOpacity(0.5)
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}