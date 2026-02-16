import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';

class SavedPositionsEmptyState extends StatelessWidget {
  final bool hasPositions;
  final String searchQuery;

  const SavedPositionsEmptyState({
    Key? key,
    required this.hasPositions,
    required this.searchQuery,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty) {
      return _buildNoSearchResults();
    } else if (!hasPositions) {
      return _buildNoPositions();
    } else {
      return _buildNoSearchResults();
    }
  }

  Widget _buildNoSearchResults() {
    return Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 70,
              color: context.secondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No positions found',
              style: TextStyle(
                fontSize: 18,
                color: context.primaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(
                color: context.secondaryTextColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPositions() {
    return Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 70,
              color: context.secondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No saved positions',
              style: TextStyle(
                fontSize: 18,
                color: context.primaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyze positions and save them for later',
              style: TextStyle(
                color: context.secondaryTextColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Analyze Position'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: context.isDarkMode ? Colors.black : AppColors.deepNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}