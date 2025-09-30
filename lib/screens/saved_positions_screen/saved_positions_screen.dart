import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartchess/dartchess.dart';
import '../../models/chess_position.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../services/storage_service.dart';
import '../../providers/theme_provider.dart';
import '../analysis_screen/analysis_screen.dart';
import 'controllers/saved_positions_controller.dart';
import 'widgets/position_card.dart';
import 'widgets/search_bar.dart';
import 'widgets/empty_state.dart';

class SavedPositionsScreen extends StatefulWidget {
  const SavedPositionsScreen({Key? key}) : super(key: key);

  @override
  _SavedPositionsScreenState createState() => _SavedPositionsScreenState();
}

class _SavedPositionsScreenState extends State<SavedPositionsScreen> 
    with TickerProviderStateMixin {
  
  late final SavedPositionsController _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;


  @override
  void initState() {
    super.initState();
    _controller = SavedPositionsController(
      onStateChanged: () => setState(() {}),
    );
    _setupAnimations();
    _controller.loadSavedPositions();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: context.iconColor,
      elevation: 0,
      systemOverlayStyle: context.isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      title: Text(
        'Saved Positions',
        style: TextStyle(
          color: context.primaryTextColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (_controller.savedPositions.isNotEmpty) ...[
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: context.iconColor),
            color: context.isDarkMode ? const Color(0xFF1a1a1a) : Colors.white,
            onSelected: _controller.changeSortOrder,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: context.primaryTextColor, size: 20),
                    const SizedBox(width: 8),
                    Text('Sort by Date', style: TextStyle(color: context.primaryTextColor)),
                    if (_controller.sortBy == 'date') ...[
                      const Spacer(),
                      Icon(_controller.sortAscending ? Icons.arrow_upward : Icons.arrow_downward, 
                           size: 16, color: context.secondaryTextColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.abc_rounded, color: context.primaryTextColor, size: 20),
                    const SizedBox(width: 8),
                    Text('Sort by Name', style: TextStyle(color: context.primaryTextColor)),
                    if (_controller.sortBy == 'name') ...[
                      const Spacer(),
                      Icon(_controller.sortAscending ? Icons.arrow_upward : Icons.arrow_downward, 
                           size: 16, color: context.secondaryTextColor),
                    ],
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.clear_all_rounded, color: context.iconColor),
            onPressed: () => _showClearAllDialog(),
            tooltip: 'Clear all positions',
          ),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                context.isDarkMode ? Colors.white.withOpacity(0.8) : AppColors.lightBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading saved positions...',
              style: TextStyle(color: context.secondaryTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Search bar
          if (_controller.savedPositions.isNotEmpty)
            SavedPositionsSearchBar(controller: _controller),
          
          // Results summary
          if (_controller.savedPositions.isNotEmpty)
            _buildResultsSummary(),
          
          const SizedBox(height: 16),
          
          // Positions list
          Expanded(
            child: _controller.filteredPositions.isEmpty
                ? SavedPositionsEmptyState(
                    hasPositions: _controller.savedPositions.isNotEmpty,
                    searchQuery: _controller.searchQuery,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _controller.filteredPositions.length,
                    itemBuilder: (context, index) => PositionCard(
                      position: _controller.filteredPositions[index],
                      onTap: () => _navigateToAnalysis(_controller.filteredPositions[index]),
                      onEdit: () => _controller.editPositionName(_controller.filteredPositions[index], context),
                      onDuplicate: () => _controller.duplicatePosition(_controller.filteredPositions[index]),
                      onShare: () => _controller.sharePosition(_controller.filteredPositions[index]),
                      onDelete: () => _confirmDelete(_controller.filteredPositions[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Showing ${_controller.filteredPositions.length} of ${_controller.savedPositions.length} positions',
            style: TextStyle(
              color: context.secondaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_controller.sortBy == 'date')
            Text(
              _controller.sortAscending ? 'Oldest first' : 'Newest first',
              style: TextStyle(
                color: context.accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              _controller.sortAscending ? 'A-Z' : 'Z-A',
              style: TextStyle(
                color: context.accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }


  void _showClearAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.isDarkMode ? const Color(0xFF1a1a1a) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.warningOrange, size: 24),
            const SizedBox(width: 8),
            Text('Clear All Positions', style: TextStyle(color: context.primaryTextColor, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text('Are you sure you want to delete all saved positions? This action cannot be undone.',
                     style: TextStyle(color: context.secondaryTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: context.secondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.clearAllPositions();
    }
  }

  void _confirmDelete(ChessPosition position) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.isDarkMode ? const Color(0xFF1a1a1a) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_rounded, color: AppColors.errorRed, size: 24),
            const SizedBox(width: 8),
            Text('Delete Position', style: TextStyle(color: context.primaryTextColor, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text('Are you sure you want to delete "${position.name}"?',
                     style: TextStyle(color: context.secondaryTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: context.secondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.deletePosition(position.id);
    }
  }

  void _navigateToAnalysis(ChessPosition position) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisScreen(fen: position.fen),
      ),
    );
  }
}