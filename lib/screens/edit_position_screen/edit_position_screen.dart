import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'dart:ui' as ui;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../../../services/dartchess_validation_service.dart';
import '../../constants/app_colors.dart';
import '../../providers/theme_provider.dart';
import 'controllers/position_editor_controller.dart';
import 'widgets/edit_mode_selector.dart';
import 'widgets/turn_indicator.dart';
import 'widgets/castling_controls.dart';
import 'widgets/tap_overlay.dart';

class EditPositionScreen extends StatefulWidget {
  final String fen;
  const EditPositionScreen({Key? key, required this.fen}) : super(key: key);

  @override
  State<EditPositionScreen> createState() => _EditPositionScreenState();
}

class _EditPositionScreenState extends State<EditPositionScreen> {
  late PositionEditorController _controller;


  @override
  void initState() {
    super.initState();
    _controller = PositionEditorController(
      initialFen: widget.fen,
      onStateChanged: () => setState(() {}),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveAndReturn() {
    try {
      final finalFen = _controller.buildFinalFen();
      if (kDebugMode) debugPrint('EditPosition: Saving FEN: $finalFen');
      
      // validation
      final validationResult = DartChessValidationService.validateFen(finalFen);
      if (!validationResult.isValid) {
        _showErrorDialog('Invalid Position', validationResult.errorMessage ?? 'Position is invalid');
        return;
      }
      
      if (!_hasExactlyOneKingPerSide(finalFen)) {
        _showErrorDialog('Invalid Position', 'Each side must have exactly one king');
        return;
      }
      
      Navigator.pop(context, finalFen);
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error saving: $e');
      _showErrorDialog('Error', 'Failed to save position: $e');
    }
  }

  bool _hasExactlyOneKingPerSide(String fen) {
    final boardPart = fen.split(' ')[0];
    int whiteKings = 0;
    int blackKings = 0;
    
    for (int i = 0; i < boardPart.length; i++) {
      if (boardPart[i] == 'K') whiteKings++;
      if (boardPart[i] == 'k') blackKings++;
    }
    
    return whiteKings == 1 && blackKings == 1;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.isDarkMode ? const Color(0xFF1a1a1a) : Colors.white,
        title: Text(title, style: TextStyle(color: context.primaryTextColor)),
        content: Text(message, style: TextStyle(color: context.secondaryTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: context.accentColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardSize = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: context.iconColor,
        elevation: 0,
        systemOverlayStyle: context.isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Text(
          'Edit Position',
          style: TextStyle(
            color: context.primaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(Icons.rotate_90_degrees_ccw_rounded, color: context.iconColor),
              onPressed: () {
                _controller.flipBoard180();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.rotate_90_degrees_ccw_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Board flipped 180°'),
                      ],
                    ),
                    backgroundColor: AppColors.warningOrange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Flip board (A1 ↔ H8)',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.warningOrange.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                _controller.boardFlipped ? Icons.flip_camera_ios_rounded : Icons.flip_camera_ios_outlined,
                color: context.iconColor,
              ),
              onPressed: _controller.toggleBoardFlip,
              tooltip: 'Flip view orientation',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.lightBlue.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(Icons.check_rounded, color: context.iconColor),
              onPressed: _saveAndReturn,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.successGreen.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Edit mode selector
              EditModeSelector(controller: _controller),

              const SizedBox(height: 16),
              
              // Status indicator
              _buildStatusIndicator(),

              const SizedBox(height: 20),

              // Chess board
              Center(
                child: SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: Stack(
                    children: [
                      Chessboard(
                        size: boardSize,
                        orientation: _controller.boardFlipped ? Side.black : Side.white,
                        fen: _controller.currentFen,
                        // Board Colors
                        settings: ChessboardSettings(
                          colorScheme: context.isDarkMode
                            ? const ChessboardColorScheme(
                                lightSquare: Color(0xFF5a5a5a), // Brighter medium gray
                                darkSquare: Color(0xFF404040),   // Brighter darker gray
                                background: SolidColorChessboardBackground(
                                  lightSquare: Color(0xFF5a5a5a),
                                  darkSquare: Color(0xFF404040),
                                  coordinates: false,
                                ),
                                whiteCoordBackground: SolidColorChessboardBackground(
                                  lightSquare: Color(0xFF5a5a5a),
                                  darkSquare: Color(0xFF404040),
                                  coordinates: true,
                                ),
                                blackCoordBackground: SolidColorChessboardBackground(
                                  lightSquare: Color(0xFF5a5a5a),
                                  darkSquare: Color(0xFF404040),
                                  coordinates: true,
                                ),
                                lastMove: HighlightDetails(
                                  solidColor: Color(0xFF656565),
                                ),
                                selected: HighlightDetails(
                                  solidColor: Color(0xFF707070),
                                ),
                                validMoves: Color(0xFF909090),
                                validPremoves: Color(0xFF808080),
                              )
                            : ChessboardColorScheme.blue,
                        ),
                        game: GameData(
                          playerSide: PlayerSide.none,
                          sideToMove: _controller.position?.turn ?? Side.white,
                          validMoves: <Square, ISet<Square>>{}.lock,
                          promotionMove: null,
                          onMove: (move, {isDrop}) {}, // No-op
                          onPromotionSelection: (role) {}, // No-op
                        ),
                      ),
                      TapOverlay(
                        boardSize: boardSize,
                        controller: _controller,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Turn indicator
              TurnIndicator(controller: _controller),

              const SizedBox(height: 20),

              // Castling controls
              CastlingControls(controller: _controller),

              const SizedBox(height: 20),

              // Action buttons
              _buildActionButtons(),

              const SizedBox(height: 20),

              // FEN display
              _buildFenDisplay(),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    String message;
    ui.Color color;
    IconData icon;
    
    if (_controller.isDragMode) {
      if (_controller.selectedSquare != null) {
        final piece = _controller.getPieceAtSquare(_controller.selectedSquare!);
        message = "Selected ${piece ?? 'piece'} - tap any square to move it there";
        color = AppColors.successGreen;
        icon = Icons.touch_app_rounded;
      } else {
        message = 'Tap any piece to select it, then tap where to move it';
        color = AppColors.lightBlue;
        icon = Icons.touch_app_rounded;
      }
    } else if (_controller.isPlaceMode) {
      if (_controller.selectedPiece != null) {
        message = 'Selected ${_controller.selectedPiece} - tap any square to place it';
        color = AppColors.successGreen;
        icon = Icons.add_circle_rounded;
      } else {
        message = 'Select a piece to place, then tap any square';
        color = AppColors.warningOrange;
        icon = Icons.add_circle_rounded;
      }
    } else if (_controller.isRemoveMode) {
      message = 'Tap any piece to remove it from the board';
      color = AppColors.errorRed;
      icon = Icons.delete_rounded;
    } else {
      message = 'Select an edit mode above';
      color = AppColors.cadetGray;
      icon = Icons.help_rounded;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _controller.resetToStartingPosition,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Reset to Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightBlue,
              foregroundColor: context.isDarkMode ? Colors.black : AppColors.deepNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _controller.clearBoard,
            icon: const Icon(Icons.clear_rounded),
            label: const Text('Clear Board'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFenDisplay() {
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
              Icon(Icons.code_rounded, color: context.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Current FEN:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.primaryTextColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.isDarkMode 
                ? Colors.white.withOpacity(0.05) 
                : AppColors.seasalt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.borderColor),
            ),
            child: SelectableText(
              _controller.buildFinalFen(),
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: context.secondaryTextColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}