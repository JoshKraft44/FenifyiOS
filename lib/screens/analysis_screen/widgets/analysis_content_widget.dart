import 'package:flutter/material.dart';
import '../../../widgets/analysis_widgets.dart';
import '../controllers/analysis_controller.dart';
import 'promotion_widget.dart';
import 'arrow_status_widget.dart';
import 'dart:ui' as ui;

/// Main content area for analysis screen showing status, evaluation, and interactive elements
class AnalysisContentWidget extends StatelessWidget {
  final AnalysisController controller;

  const AnalysisContentWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  // Color palette
  static const ui.Color deepNavy = ui.Color(0xFF1a1a2e);
  static const ui.Color successGreen = ui.Color(0xFF7FB069);

  @override
  Widget build(BuildContext context) {
    if (controller.isInvalidPosition) {
      return const SizedBox.shrink(); // No content for invalid positions
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          // Analysis card
          if (controller.principalVariation.isNotEmpty)
            AnalysisWidgets.buildAnalysisCard(
              evaluationScore: controller.evaluationScore,
              isMateScore: controller.isMateScore,
              mateInMoves: controller.mateInMoves,
              multiPV: controller.multiPV,
              moveEvaluations: controller.moveEvaluations,
              formatMove: _formatMove,
            ),
          
          // Promotion status widget
          if (controller.awaitingPromotion)
            PromotionWidget(
              onPromotionSelection: controller.onPromotionSelection,
            ),
        ],
      ),
    );
  }

  String _formatMove(String move) {
    if (move.isEmpty || move.length < 4) return move;
    try {
      return "${move.substring(0, 2)}-${move.substring(2, 4)}${move.length > 4 ? move.substring(4) : ''}";
    } catch (e) {
      return move;
    }
  }
}