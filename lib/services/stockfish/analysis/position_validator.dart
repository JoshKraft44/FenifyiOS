import 'package:flutter/foundation.dart';
import '../../../services/dartchess_validation_service.dart';

class PositionValidator {
  /// FEN validation using DartChess
  Future<bool> validateFen(String fen) async {
    try {
      if (kDebugMode) debugPrint('Validating FEN with DartChess: $fen');
      
      final result = DartChessValidationService.validateFen(fen);
      
      if (result.isValid) {
        if (kDebugMode) debugPrint('FEN validated successfully by DartChess');
        if (result.analysis != null) {
          if (kDebugMode) debugPrint('   Analysis: ${result.analysis!.statusDescription}');
          if (kDebugMode) debugPrint('   Material: ${result.analysis!.materialDescription}');
          if (kDebugMode) debugPrint('   Legal moves: ${result.analysis!.legalMovesCount}');
        }
        return true;
      } else {
        if (kDebugMode) debugPrint('FEN rejected by DartChess: ${result.errorMessage}');
        return false;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('Error validating FEN with DartChess: $e');
      return false;
    }
  }

  /// Additional compatibility check for Stockfish-specific requirements
  String? checkStockfishCompatibility(String fen) {
    try {
      // Parse board position
      final parts = fen.split(' ');
      if (parts.isEmpty) return 'Invalid FEN format';
      
      final boardPosition = parts[0];
      final ranks = boardPosition.split('/');
      
      if (ranks.length != 8) return 'Board must have 8 ranks';
      
      int whiteKings = 0;
      int blackKings = 0;
      
      for (final rank in ranks) {
        for (int i = 0; i < rank.length; i++) {
          final char = rank[i];
          
          if (char == 'K') whiteKings++;
          if (char == 'k') blackKings++;
          
          // Check for invalid characters
          if (!'12345678KQRBNPkqrbnp'.contains(char)) {
            return 'Invalid piece character: $char';
          }
        }
      }

      if (whiteKings != 1) {
        return 'Must have exactly one white king (found $whiteKings)';
      }
      
      if (blackKings != 1) {
        return 'Must have exactly one black king (found $blackKings)';
      }
      
      // Additional checks for move format
      if (parts.length < 2) return 'Missing turn indicator';
      if (!'wb'.contains(parts[1])) return 'Invalid turn indicator: ${parts[1]}';
      
      return null; // All checks passed
      
    } catch (e) {
      return 'Error checking position compatibility: $e';
    }
  }

  /// Check if FEN contains invalid position flags
  bool hasInvalidFlags(String fen) {
    return fen.contains('INVALID_');
  }

  /// Clean FEN by removing validation flags
  String cleanFen(String fen) {
    return fen.replaceAll(RegExp(r' INVALID_\w+'), '').trim();
  }
}