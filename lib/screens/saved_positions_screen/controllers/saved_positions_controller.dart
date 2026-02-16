import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/chess_position.dart';
import '../../../services/storage_service.dart';
import '../../../constants/app_colors.dart';
import '../../../providers/theme_provider.dart';

class SavedPositionsController {
  final VoidCallback onStateChanged;
  final StorageService _storageService = StorageService();
  final TextEditingController searchController = TextEditingController();

  // State
  List<ChessPosition> _savedPositions = [];
  List<ChessPosition> _filteredPositions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'date'; // 'date', 'name', 'evaluation'
  bool _sortAscending = false;


  SavedPositionsController({required this.onStateChanged});

  // Getters
  List<ChessPosition> get savedPositions => _savedPositions;
  List<ChessPosition> get filteredPositions => _filteredPositions;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;

  Future<void> loadSavedPositions() async {
    _isLoading = true;
    onStateChanged();

    try {
      final positions = await _storageService.getSavedPositions();
      _savedPositions = positions;
      _applyFiltersAndSort();
      _isLoading = false;
      onStateChanged();
    } catch (e) {
      _isLoading = false;
      onStateChanged();
      _showErrorMessage('Error loading saved positions: ${e.toString()}');
    }
  }

  void _applyFiltersAndSort() {
    _filteredPositions = _savedPositions.where((position) {
      return position.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             position.fen.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    _filteredPositions.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'date':
          comparison = a.date.compareTo(b.date);
          break;
        case 'evaluation':
          // Sort by evaluation if available
          comparison = 0; // Implement if you store evaluation data
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void onSearchChanged(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    onStateChanged();
  }

  void clearSearch() {
    searchController.clear();
    onSearchChanged('');
  }

  void changeSortOrder(String sortBy) {
    if (_sortBy == sortBy) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = sortBy;
      _sortAscending = false;
    }
    _applyFiltersAndSort();
    onStateChanged();
  }

  Future<void> deletePosition(String id) async {
    try {
      await _storageService.deletePosition(id);
      await loadSavedPositions();
      _showSuccessMessage('Position deleted successfully');
    } catch (e) {
      _showErrorMessage('Error deleting position: ${e.toString()}');
    }
  }

  Future<void> duplicatePosition(ChessPosition position) async {
    try {
      final duplicatedPosition = ChessPosition(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${position.name} (Copy)',
        fen: position.fen,
        date: DateTime.now(),
      );
      
      await _storageService.savePosition(duplicatedPosition);
      await loadSavedPositions();
      _showSuccessMessage('Position duplicated successfully');
    } catch (e) {
      _showErrorMessage('Error duplicating position: ${e.toString()}');
    }
  }

  Future<void> editPositionName(ChessPosition position, BuildContext context) async {
    final controller = TextEditingController(text: position.name);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.isDarkMode ? const Color(0xFF1a1a1a) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: context.accentColor, size: 24),
            const SizedBox(width: 8),
            Text('Edit Name', style: TextStyle(color: context.primaryTextColor, fontWeight: FontWeight.w600)),
          ],
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.primaryTextColor),
          decoration: InputDecoration(
            labelText: 'Position Name',
            labelStyle: TextStyle(color: context.secondaryTextColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accentColor, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.secondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: context.isDarkMode ? Colors.black : AppColors.deepNavy,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != position.name) {
      try {
        final updatedPosition = ChessPosition(
          id: position.id,
          name: newName,
          fen: position.fen,
          date: position.date,
        );
        
        await _storageService.savePosition(updatedPosition);
        await loadSavedPositions();
        _showSuccessMessage('Position name updated');
      } catch (e) {
        _showErrorMessage('Error updating position name: ${e.toString()}');
      }
    }
  }

  Future<void> sharePosition(ChessPosition position) async {
    try {
      final textToShare = 'Chess Position: ${position.name}\nFEN: ${position.fen}';
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: textToShare));
      _showSuccessMessage('Position copied to clipboard');

      // Optionally, mplement sharing via other platforms here? 
    } catch (e) {
      _showErrorMessage('Error sharing position: ${e.toString()}');
    }
  }

  Future<void> clearAllPositions() async {
    try {
      await _storageService.clearAllPositions();
      await loadSavedPositions();
      _showSuccessMessage('All positions cleared');
    } catch (e) {
      _showErrorMessage('Error clearing positions: ${e.toString()}');
    }
  }

  void _showErrorMessage(String message) {

    if (kDebugMode) debugPrint('Error: $message');
  }

  void _showSuccessMessage(String message) {

    if (kDebugMode) debugPrint('Success: $message');
  }

  void dispose() {
    searchController.dispose();
  }
}