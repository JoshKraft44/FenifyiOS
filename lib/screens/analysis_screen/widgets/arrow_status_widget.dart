import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

/// Widget displaying the best move arrow status and evaluation
class ArrowStatusWidget extends StatelessWidget {
  final String bestMove;
  final List<String> moveEvaluations;

  const ArrowStatusWidget({
    Key? key,
    required this.bestMove,
    required this.moveEvaluations,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.successGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Showing best move: ${_formatMove(bestMove)}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.deepNavy,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (moveEvaluations.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                moveEvaluations[0],
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
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