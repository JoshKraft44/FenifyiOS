import 'package:flutter/foundation.dart';
import 'castling_rights_detector.dart';

// Service for auto-completing partial FEN strings with best guesses
// Handles FENs that are missing optional fields like castling rights, en passant, etc.

class FenCompletionService {
  // Accepts FENs in various formats,
  // Returns a complete FEN string with all 6 components
  static String completeFen(String partialFen) {
    try {
      // Trim whitespace
      final fen = partialFen.trim();

      // Split by spaces to get components
      final parts = fen.split(' ');

      // Ensure we have at least the board position
      if (parts.isEmpty || !parts[0].contains('/')) {
        if (kDebugMode) debugPrint('FenCompletion: Invalid board position');
        return partialFen; // Return as-is if invalid
      }

      // Build complete FEN with defaults
      final completeParts = List<String>.filled(6, '');

      // Component 0: Board position (required)
      completeParts[0] = parts[0];

      // Component 1: Side to move (default: white)
      if (parts.length > 1 && parts[1].isNotEmpty) {
        completeParts[1] = parts[1];
      } else {
        completeParts[1] = 'w';
        if (kDebugMode) {
          debugPrint('FenCompletion: Defaulting side to move to white');
        }
      }

      // Component 2: Castling rights (auto-detect,  default)
      if (parts.length > 2 && parts[2].isNotEmpty) {
        completeParts[2] = parts[2];
      } else {
        // Try to auto-detect castling rights based on piece positions
        final tempFen = '${completeParts[0]} ${completeParts[1]} - - 0 1';
        final castlingAnalysis =
            CastlingRightsDetector.analyzeCastlingRights(tempFen);

        if (castlingAnalysis.isValid) {
          String castlingRights = '';
          if (castlingAnalysis.whiteKingSide) castlingRights += 'K';
          if (castlingAnalysis.whiteQueenSide) castlingRights += 'Q';
          if (castlingAnalysis.blackKingSide) castlingRights += 'k';
          if (castlingAnalysis.blackQueenSide) castlingRights += 'q';

          completeParts[2] = castlingRights.isEmpty ? '-' : castlingRights;
          if (kDebugMode) {
            debugPrint(
                'FenCompletion: Auto-detected castling rights: ${completeParts[2]}');
          }
        } else {
          completeParts[2] = '-';
          if (kDebugMode) {
            debugPrint('FenCompletion: No castling rights available');
          }
        }
      }

      // Component 3: En passant target square (default: none)
      if (parts.length > 3 && parts[3].isNotEmpty) {
        completeParts[3] = parts[3];
      } else {
        completeParts[3] = '-';
      }

      // Component 4: Halfmove clock (default: 0)
      if (parts.length > 4 && parts[4].isNotEmpty) {
        completeParts[4] = parts[4];
      } else {
        completeParts[4] = '0';
      }

      // Component 5: Fullmove number (default: 1)
      if (parts.length > 5 && parts[5].isNotEmpty) {
        completeParts[5] = parts[5];
      } else {
        completeParts[5] = '1';
      }

      final completedFen = completeParts.join(' ');

      if (kDebugMode && partialFen != completedFen) {
        debugPrint('FenCompletion: Completed FEN');
        debugPrint('  Input:  $partialFen');
        debugPrint('  Output: $completedFen');
      }

      return completedFen;
    } catch (e) {
      if (kDebugMode) debugPrint('FenCompletion: Error completing FEN: $e');
      return partialFen; // Return original on error
    }
  }

  /// Validates that a FEN string has at least a valid board position
  /// More lenient than full FEN validation - only requires the board part
  static bool isValidPartialFen(String fen) {
    if (fen.isEmpty) return false;

    final parts = fen.trim().split(' ');
    if (parts.isEmpty) return false;

    final boardPart = parts[0];

    // Must contain rank separators
    if (!boardPart.contains('/')) return false;

    // Should have 8 ranks
    final ranks = boardPart.split('/');
    if (ranks.length != 8) return false;

    // Each rank should be valid FEN notation
    for (final rank in ranks) {
      if (rank.isEmpty) return false;

      // Count squares in rank
      int squareCount = 0;
      for (int i = 0; i < rank.length; i++) {
        final char = rank[i];
        if ('12345678'.contains(char)) {
          squareCount += int.parse(char);
        } else if ('pnbrqkPNBRQK'.contains(char)) {
          squareCount += 1;
        } else {
          return false; // Invalid character
        }
      }

      if (squareCount != 8) return false;
    }

    return true;
  }
}
