import 'package:flutter/material.dart';
import '../controllers/saved_positions_controller.dart';
import '../../../providers/theme_provider.dart';

class SavedPositionsSearchBar extends StatelessWidget {
  final SavedPositionsController controller;

  const SavedPositionsSearchBar({
    Key? key,
    required this.controller,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: TextField(
        controller: controller.searchController,
        onChanged: controller.onSearchChanged,
        style: TextStyle(color: context.primaryTextColor),
        decoration: InputDecoration(
          hintText: 'Search positions...',
          hintStyle: TextStyle(color: context.secondaryTextColor.withOpacity(0.7)),
          prefixIcon: Icon(Icons.search_rounded, color: context.secondaryTextColor),
          suffixIcon: controller.searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: context.secondaryTextColor),
                  onPressed: controller.clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}