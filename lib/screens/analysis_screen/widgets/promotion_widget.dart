import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';
import '../../../constants/app_colors.dart';

/// Widget for selecting promotion piece when a pawn reaches the end rank
class PromotionWidget extends StatelessWidget {
  final Function(Role?) onPromotionSelection;

  const PromotionWidget({
    Key? key,
    required this.onPromotionSelection,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.columbiaBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.columbiaBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.columbiaBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pawn promotion - select piece:',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.deepNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPromotionButton(Role.queen, 'Q', 'Queen'),
              _buildPromotionButton(Role.rook, 'R', 'Rook'),
              _buildPromotionButton(Role.bishop, 'B', 'Bishop'),
              _buildPromotionButton(Role.knight, 'N', 'Knight'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionButton(Role role, String symbol, String name) {
    return GestureDetector(
      onTap: () => onPromotionSelection(role),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.columbiaBlue, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.columbiaBlue.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.deepNavy,
              ),
            ),
            Text(
              name,
              style: TextStyle(
                fontSize: 8,
                color: AppColors.cadetGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}