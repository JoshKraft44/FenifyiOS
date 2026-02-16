import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart';
import '../../../providers/theme_provider.dart';
import '../../../constants/app_colors.dart';

/// A tree node representing a move in the variation tree
class MoveNode {
  final Move move;
  final Position position;
  final String san; // Standard Algebraic Notation
  final String fen;
  final List<MoveNode> variations;
  final MoveNode? parent;
  final int ply; // Half-move number (0-based)

  MoveNode({
    required this.move,
    required this.position,
    required this.san,
    required this.fen,
    required this.variations,
    this.parent,
    required this.ply,
  });

  /// Creates the root node from a FEN string
  static MoveNode fromFen(String fen) {
    final setup = Setup.parseFen(fen);
    final position = Position.setupPosition(Rule.chess, setup);

    // Create a dummy move for the root - this won't be used for anything
    const dummyMove = NormalMove(from: Square.a1, to: Square.a1);

    // Calculate initial ply from FEN - if it's White to move, we're at the start of a full move
    // If it's Black to move, we're halfway through a full move
    final fullMoveNumber = setup.fullmoves;
    final isWhiteToMove = setup.turn == Side.white;
    final initialPly = isWhiteToMove ? (fullMoveNumber - 1) * 2 : (fullMoveNumber - 1) * 2 + 1;

    return MoveNode(
      move: dummyMove, // Root has dummy move
      position: position,
      san: '',
      fen: fen,
      variations: [],
      parent: null,
      ply: initialPly,
    );
  }

  /// Add a new move as a variation from this node
  MoveNode addMove(Move move) {
    try {
      final newPosition = position.play(move);
      final san = position.makeSan(move).$2;
      final newFen = newPosition.fen;

      final newNode = MoveNode(
        move: move,
        position: newPosition,
        san: san,
        fen: newFen,
        variations: [],
        parent: this,
        ply: ply + 1,
      );

      // Check if this move already exists as a variation
      final existingIndex = variations.indexWhere((node) =>
        node.move.toString() == move.toString());

      if (existingIndex >= 0) {
        return variations[existingIndex];
      } else {
        variations.add(newNode);
        return newNode;
      }
    } catch (e) {
      throw Exception('Invalid move: $e');
    }
  }

  /// Find a node by FEN in the tree
  MoveNode? findByFen(String targetFen) {
    if (fen == targetFen) return this;

    for (final variation in variations) {
      final found = variation.findByFen(targetFen);
      if (found != null) return found;
    }

    return null;
  }

  /// Get the main line (first variation at each node)
  List<MoveNode> getMainLine() {
    final line = <MoveNode>[this];
    MoveNode current = this;

    while (current.variations.isNotEmpty) {
      current = current.variations.first;
      line.add(current);
    }

    return line;
  }

  /// Get path from root to this node
  List<MoveNode> getPathFromRoot() {
    final path = <MoveNode>[];
    MoveNode? current = this;

    while (current != null) {
      path.insert(0, current);
      current = current.parent;
    }

    return path;
  }
}

/// Widget that displays the variation tree in Chess.com style
class VariationTreeWidget extends StatefulWidget {
  final String initialFen;
  final MoveNode? rootNode;
  final MoveNode? currentNode;
  final Function(MoveNode) onMoveSelected;
  final Function(MoveNode, Move) onMoveAdded;

  const VariationTreeWidget({
    Key? key,
    required this.initialFen,
    this.rootNode,
    required this.currentNode,
    required this.onMoveSelected,
    required this.onMoveAdded,
  }) : super(key: key);

  @override
  State<VariationTreeWidget> createState() => _VariationTreeWidgetState();
}

class _VariationTreeWidgetState extends State<VariationTreeWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  MoveNode get _rootNode {
    return widget.rootNode ?? MoveNode.fromFen(widget.initialFen);
  }

  /// Add a move to the tree from the current position
  void addMove(Move move) {
    final currentNode = widget.currentNode ?? _rootNode;
    final newNode = currentNode.addMove(move);
    widget.onMoveAdded(currentNode, move);
    widget.onMoveSelected(newNode);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: _rootNode.variations.isEmpty
          ? _buildEmptyState(context)
          : _buildVariationTree(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_flat_rounded,
            size: 48,
            color: context.secondaryTextColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No moves played yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.secondaryTextColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make moves on the board to build\nyour variation tree',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryTextColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariationTree(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMainLine(context),
          ..._buildAlternativeLines(context),
          const SizedBox(height: 50), // Extra space at bottom for scrolling
        ],
      ),
    );
  }

  Widget _buildMainLine(BuildContext context) {
    if (_rootNode.variations.isEmpty) return const SizedBox.shrink();

    final mainLine = _rootNode.getMainLine().skip(1).toList(); // Skip root node
    return _buildHorizontalMoveSequence(context, mainLine, isMainLine: true);
  }

  List<Widget> _buildAlternativeLines(BuildContext context) {
    final alternatives = <Widget>[];

    // Build all variations except the main line (first variation at each node)
    void buildVariations(MoveNode node, List<MoveNode> pathFromRoot, int depth) {
      for (int i = 0; i < node.variations.length; i++) {
        final variation = node.variations[i];
        final newPath = [...pathFromRoot, variation];

        if (i == 0) {
          // Main line - continue recursively
          buildVariations(variation, newPath, depth);
        } else {
          // Alternative line - show the full line from this variation
          final divergencePoint = pathFromRoot.length > 1 ? pathFromRoot.length - 1 : 0;
          final moveNumber = divergencePoint > 0 ? ((pathFromRoot[divergencePoint].ply ~/ 2) + 1) : 1;

          alternatives.add(
            Padding(
              padding: EdgeInsets.only(left: depth * 12.0, top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$moveNumber.',
                    style: TextStyle(
                      color: context.secondaryTextColor.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildHorizontalMoveSequence(
                      context,
                      [variation, ...variation.getMainLine().skip(1)],
                      isMainLine: false
                    ),
                  ),
                ],
              ),
            ),
          );

          // Continue building from this alternative
          buildVariations(variation, newPath, depth + 1);
        }
      }
    }

    buildVariations(_rootNode, [_rootNode], 0);
    return alternatives;
  }

  Widget _buildHorizontalMoveSequence(BuildContext context, List<MoveNode> moveSequence, {required bool isMainLine}) {
    if (moveSequence.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];

    for (int i = 0; i < moveSequence.length; i++) {
      final move = moveSequence[i];
      final moveNumber = (move.ply ~/ 2) + 1;
      final isWhiteMove = move.ply % 2 == 0;
      final isCurrentMove = widget.currentNode?.fen == move.fen;

      // Add move number for white moves or start of variations
      if (isWhiteMove || (i == 0 && !isMainLine)) {
        spans.add(TextSpan(
          text: '$moveNumber${isWhiteMove ? '.' : '...'} ',
          style: TextStyle(
            fontSize: 14,
            color: context.secondaryTextColor.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ));
      }

      // Add the move
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => widget.onMoveSelected(move),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrentMove
                  ? (context.isDarkMode
                      ? AppColors.columbiaBlue.withOpacity(0.3)
                      : AppColors.columbiaBlue.withOpacity(0.2))
                  : null,
              borderRadius: BorderRadius.circular(4),
              border: isCurrentMove
                  ? Border.all(
                      color: context.isDarkMode
                          ? AppColors.columbiaBlue.withOpacity(0.5)
                          : AppColors.columbiaBlue,
                      width: 1,
                    )
                  : null,
            ),
            child: Text(
              move.san,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrentMove ? FontWeight.w600 : FontWeight.w500,
                color: isCurrentMove
                    ? (context.isDarkMode ? Colors.white : AppColors.deepNavy)
                    : context.primaryTextColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ));

      // Add space after move
      if (i < moveSequence.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(children: spans),
      ),
    );
  }

}