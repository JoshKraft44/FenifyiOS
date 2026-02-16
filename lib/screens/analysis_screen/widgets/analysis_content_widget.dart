import 'package:flutter/material.dart';
import '../../../widgets/analysis_widgets.dart';
import '../../../providers/theme_provider.dart';
import '../controllers/analysis_controller.dart';
import 'arrow_status_widget.dart';
import 'variation_tree_widget.dart';
import 'dart:ui' as ui;

/// Main content area for analysis screen showing status, evaluation, and interactive elements
class AnalysisContentWidget extends StatefulWidget {
  final AnalysisController controller;

  const AnalysisContentWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<AnalysisContentWidget> createState() => _AnalysisContentWidgetState();
}

class _AnalysisContentWidgetState extends State<AnalysisContentWidget> {
  late PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Color palette
  static const ui.Color deepNavy = ui.Color(0xFF1a1a2e);
  static const ui.Color successGreen = ui.Color(0xFF7FB069);

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isInvalidPosition) {
      return const SizedBox.shrink(); // No content for invalid positions
    }

    return Column(
      children: [
        // Page indicator
        if (widget.controller.principalVariation.isNotEmpty)
          _buildPageIndicator(context),

        // PageView with best moves and variation tree
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            children: [
              // Page 0: Best moves analysis
              _buildBestMovesPage(context),

              // Page 1: Variation tree
              _buildVariationTreePage(context),
            ],
          ),
        ),

      ],
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIndicatorDot(context, 0, 'Best Moves'),
          const SizedBox(width: 20),
          _buildIndicatorDot(context, 1, 'Variations'),
        ],
      ),
    );
  }

  Widget _buildIndicatorDot(BuildContext context, int index, String label) {
    final isActive = _currentPageIndex == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? context.primaryTextColor
                  : context.secondaryTextColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? context.primaryTextColor
                  : context.secondaryTextColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestMovesPage(BuildContext context) {
    // Show checkmate image when position is checkmate
    if (widget.controller.position?.isCheckmate == true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Image.asset(
            context.isDarkMode
                ? 'assets/images/Checkmate2.png'
                : 'assets/images/Checkmate1.png',
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      child: Column(
        children: [
          // Analysis card
          if (widget.controller.principalVariation.isNotEmpty)
            AnalysisWidgets.buildAnalysisCard(
              evaluationScore: widget.controller.evaluationScore,
              isMateScore: widget.controller.isMateScore,
              mateInMoves: widget.controller.mateInMoves,
              multiPV: widget.controller.multiPV,
              moveEvaluations: widget.controller.moveEvaluations,
              formatMove: _formatMove,
            ),
        ],
      ),
    );
  }

  Widget _buildVariationTreePage(BuildContext context) {
    return VariationTreeWidget(
      initialFen: widget.controller.originalFen,
      rootNode: widget.controller.variationTreeRoot,
      currentNode: widget.controller.currentVariationNode,
      onMoveSelected: (node) {
        widget.controller.navigateToVariationNode(node);
      },
      onMoveAdded: (parentNode, move) {
        widget.controller.addMoveToVariationTree(parentNode, move);
      },
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