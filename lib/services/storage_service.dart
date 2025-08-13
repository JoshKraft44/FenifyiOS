import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../core/errors/error_handler.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/result.dart';
import '../models/chess_position.dart';

/// Service for persisting chess positions using SharedPreferences
/// Handles save/load operations with error handling and validation
class StorageService {
  static const String _positionsKey = AppConstants.savedPositionsKey;
  static final ErrorHandler _errorHandler = ErrorHandler();

  /// Load all saved positions, sorted by date (newest first)
  Future<List<ChessPosition>> getSavedPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionsJson = prefs.getString(_positionsKey);
      
      if (positionsJson == null) {
        return [];
      }
      
      final positionsData = jsonDecode(positionsJson) as List;
      return positionsData
          .map((data) => ChessPosition.fromJson(data))
          .toList();
    } catch (e) {
      throw Exception('Failed to load saved positions: $e');
    }
  }

  /// Save or update a chess position (updates existing if same ID)
  Future<void> savePosition(ChessPosition position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positions = await getSavedPositions();
      
      // Check if position with same ID already exists
      final existingIndex = positions.indexWhere((p) => p.id == position.id);
      
      if (existingIndex >= 0) {
        // Replace existing position
        positions[existingIndex] = position;
      } else {
        // Add new position
        positions.add(position);
      }
      
      // Sort by date (newest first)
      positions.sort((a, b) => b.date.compareTo(a.date));
      
      // Save to SharedPreferences
      final positionsJson = jsonEncode(positions.map((p) => p.toJson()).toList());
      await prefs.setString(_positionsKey, positionsJson);
    } catch (e) {
      throw Exception('Failed to save position: $e');
    }
  }

  /// Delete a position by ID
  Future<void> deletePosition(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positions = await getSavedPositions();
      
      // Remove position with matching ID
      positions.removeWhere((position) => position.id == id);
      
      // Save updated list to SharedPreferences
      final positionsJson = jsonEncode(positions.map((p) => p.toJson()).toList());
      await prefs.setString(_positionsKey, positionsJson);
    } catch (e) {
      throw Exception('Failed to delete position: $e');
    }
  }

  /// Clear all saved positions (primarily for testing)
  Future<void> clearAllPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_positionsKey);
    } catch (e) {
      throw Exception('Failed to clear positions: $e');
    }
  }

  // Modern Result-based methods for better error handling

  /// Load all saved positions with Result-based error handling
  Future<Result<List<ChessPosition>, StorageException>> getSavedPositionsSafely() async {
    try {
      final positions = await getSavedPositions();
      return Success(positions);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleStorageError(e, stackTrace, context: 'Loading saved positions');
      return Failure(exception as StorageException);
    }
  }

  /// Save position with Result-based error handling
  Future<Result<void, StorageException>> savePositionSafely(ChessPosition position) async {
    try {
      // Check position limit
      final existingPositions = await getSavedPositions();
      if (existingPositions.length >= AppConstants.maxSavedPositions) {
        final existingIndex = existingPositions.indexWhere((p) => p.id == position.id);
        if (existingIndex == -1) {
          return Failure(StorageException('Maximum number of saved positions reached (${AppConstants.maxSavedPositions})'));
        }
      }
      
      await savePosition(position);
      return const Success(null);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleStorageError(e, stackTrace, context: 'Saving position');
      return Failure(exception as StorageException);
    }
  }

  /// Delete position with Result-based error handling
  Future<Result<bool, StorageException>> deletePositionSafely(String id) async {
    try {
      final positionsBefore = await getSavedPositions();
      await deletePosition(id);
      final positionsAfter = await getSavedPositions();
      
      // Return true if position was actually deleted
      final wasDeleted = positionsBefore.length > positionsAfter.length;
      return Success(wasDeleted);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleStorageError(e, stackTrace, context: 'Deleting position');
      return Failure(exception as StorageException);
    }
  }

  /// Clear all positions with Result-based error handling
  Future<Result<void, StorageException>> clearAllPositionsSafely() async {
    try {
      await clearAllPositions();
      return const Success(null);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleStorageError(e, stackTrace, context: 'Clearing all positions');
      return Failure(exception as StorageException);
    }
  }
}
