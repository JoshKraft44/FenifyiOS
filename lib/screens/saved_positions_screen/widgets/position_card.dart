import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../../../models/chess_position.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../providers/theme_provider.dart';

class PositionCard extends StatelessWidget {
  final ChessPosition position;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const PositionCard({
    Key? key,
    required this.position,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onShare,
    required this.onDelete,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: context.isDarkMode ? null : [
          BoxShadow(
            color: context.primaryTextColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Position preview and info
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Mini chessboard preview
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Chessboard(
                        size: 80,
                        orientation: Side.white,
                        fen: position.fen,
                        settings: ChessboardSettings(
                          colorScheme: context.isDarkMode
                            ? ChessboardColorScheme(
                                lightSquare: const Color(0xFF5a5a5a), // Brighter medium gray
                                darkSquare: const Color(0xFF404040),   // Brighter darker gray
                                background: SolidColorChessboardBackground(
                                  lightSquare: const Color(0xFF5a5a5a),
                                  darkSquare: const Color(0xFF404040),
                                  coordinates: false,
                                ),
                                whiteCoordBackground: SolidColorChessboardBackground(
                                  lightSquare: const Color(0xFF5a5a5a),
                                  darkSquare: const Color(0xFF404040),
                                  coordinates: true,
                                ),
                                blackCoordBackground: SolidColorChessboardBackground(
                                  lightSquare: const Color(0xFF5a5a5a),
                                  darkSquare: const Color(0xFF404040),
                                  coordinates: true,
                                ),
                                lastMove: HighlightDetails(
                                  solidColor: const Color(0xFF656565),
                                ),
                                selected: HighlightDetails(
                                  solidColor: const Color(0xFF707070),
                                ),
                                validMoves: const Color(0xFF909090),
                                validPremoves: const Color(0xFF808080),
                              )
                            : ChessboardColorScheme.blue,
                        ),
                        game: GameData(
                          playerSide: PlayerSide.none,
                          sideToMove: _getSideToMove(position.fen),
                          validMoves: <Square, ISet<Square>>{}.lock,
                          promotionMove: null,
                          onMove: (move, {isDrop}) {},
                          onPromotionSelection: (role) {},
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Position info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          position.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.primaryTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 16, color: context.secondaryTextColor),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(position.date),
                              style: TextStyle(
                                fontSize: 14,
                                color: context.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getSideToMove(position.fen) == Side.white 
                                  ? (context.isDarkMode ? Colors.white : AppColors.seasalt)
                                  : (context.isDarkMode ? Colors.black : AppColors.deepNavy),
                                border: Border.all(
                                  color: context.isDarkMode ? Colors.white.withOpacity(0.3) : AppColors.lightBlue, 
                                  width: 1.5
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_getSideToMove(position.fen) == Side.white ? "White" : "Black"} to move',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.secondaryTextColor,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          // Action buttons
          Container(
            decoration: BoxDecoration(
              color: context.isDarkMode 
                ? Colors.white.withOpacity(0.02) 
                : AppColors.seasalt,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: context.borderColor)),
            ),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  onPressed: onEdit,
                  color: AppColors.lightBlue,
                ),
                _buildActionButton(
                  icon: Icons.content_copy_rounded,
                  label: 'Duplicate',
                  onPressed: onDuplicate,
                  color: AppColors.columbiaBlue,
                ),
                _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onPressed: onShare,
                  color: AppColors.successGreen,
                ),
                _buildActionButton(
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  onPressed: onDelete,
                  color: AppColors.errorRed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Side _getSideToMove(String fen) {
    final parts = fen.split(' ');
    if (parts.length >= 2) {
      return parts[1] == 'w' ? Side.white : Side.black;
    }
    return Side.white;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}