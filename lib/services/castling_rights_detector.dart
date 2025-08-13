// lib/services/castling_rights_detector.dart
import 'package:flutter/foundation.dart';
import 'package:dartchess/dartchess.dart';

/// Intelligent castling rights detection and validation (Updated for dartchess ^0.9.0)
class CastlingRightsDetector {
  static const String _TAG = 'CastlingRightsDetector';

  /// Analyzes a chess position and determines valid castling rights
  static CastlingRightsResult analyzeCastlingRights(String fen) {
    try {
      if (kDebugMode) debugPrint('$_TAG: Analyzing castling rights for FEN: $fen');
      
      final setup = Setup.parseFen(fen);
      if (setup == null) {
        return CastlingRightsResult.invalid('Invalid FEN format');
      }
      
      final board = setup.board;
      final result = CastlingRightsResult.empty();
      
      // Check white castling rights
      result.whiteKingSide = _canCastleKingSide(board, Side.white);
      result.whiteQueenSide = _canCastleQueenSide(board, Side.white);
      
      // Check black castling rights
      result.blackKingSide = _canCastleKingSide(board, Side.black);
      result.blackQueenSide = _canCastleQueenSide(board, Side.black);
      
      // Generate castling string
      result.castlingString = _buildCastlingString(result);
      
      if (kDebugMode) debugPrint('$_TAG: Analysis complete - ${result.castlingString}');
      if (kDebugMode) debugPrint('$_TAG: White K-side: ${result.whiteKingSide}, Q-side: ${result.whiteQueenSide}');
      if (kDebugMode) debugPrint('$_TAG: Black K-side: ${result.blackKingSide}, Q-side: ${result.blackQueenSide}');
      
      return result;
      
    } catch (e) {
      if (kDebugMode) debugPrint('$_TAG: Error analyzing castling rights: $e');
      return CastlingRightsResult.invalid('Error analyzing position: $e');
    }
  }
  
  /// Checks if king-side castling is possible for the given side
  static bool _canCastleKingSide(Board board, Side side) {
    if (side == Side.white) {
      // White king-side: King on e1, Rook on h1
      final kingSquare = Square.fromName('e1');
      final rookSquare = Square.fromName('h1');
      
      final kingPiece = board.pieceAt(kingSquare);
      final rookPiece = board.pieceAt(rookSquare);
      
      final hasKing = kingPiece?.role == Role.king && kingPiece?.color == Side.white;
      final hasRook = rookPiece?.role == Role.rook && rookPiece?.color == Side.white;
      
      print('$_TAG: White K-side - King: $hasKing, Rook: $hasRook');
      return hasKing && hasRook;
      
    } else {
      // Black king-side: King on e8, Rook on h8
      final kingSquare = Square.fromName('e8');
      final rookSquare = Square.fromName('h8');
      
      final kingPiece = board.pieceAt(kingSquare);
      final rookPiece = board.pieceAt(rookSquare);
      
      final hasKing = kingPiece?.role == Role.king && kingPiece?.color == Side.black;
      final hasRook = rookPiece?.role == Role.rook && rookPiece?.color == Side.black;
      
      print('$_TAG: Black K-side - King: $hasKing, Rook: $hasRook');
      return hasKing && hasRook;
    }
  }
  
  /// Checks if queen-side castling is possible for the given side
  static bool _canCastleQueenSide(Board board, Side side) {
    if (side == Side.white) {
      // White queen-side: King on e1, Rook on a1
      final kingSquare = Square.fromName('e1');
      final rookSquare = Square.fromName('a1');
      
      final kingPiece = board.pieceAt(kingSquare);
      final rookPiece = board.pieceAt(rookSquare);
      
      final hasKing = kingPiece?.role == Role.king && kingPiece?.color == Side.white;
      final hasRook = rookPiece?.role == Role.rook && rookPiece?.color == Side.white;
    
      
      print('$_TAG: White Q-side - King: $hasKing, Rook: $hasRook');
      return hasKing && hasRook;
      
    } else {
      // Black queen-side: King on e8, Rook on a8
      final kingSquare = Square.fromName('e8');
      final rookSquare = Square.fromName('a8');
      
      final kingPiece = board.pieceAt(kingSquare);
      final rookPiece = board.pieceAt(rookSquare);
      
      final hasKing = kingPiece?.role == Role.king && kingPiece?.color == Side.black;
      final hasRook = rookPiece?.role == Role.rook && rookPiece?.color == Side.black;
      
      print('$_TAG: Black Q-side - King: $hasKing, Rook: $hasRook');
      return hasKing && hasRook;
    }
  }
  
  /// Builds the castling rights string (e.g., "KQkq", "Kk", "-")
  static String _buildCastlingString(CastlingRightsResult result) {
    String castling = '';
    
    if (result.whiteKingSide) castling += 'K';
    if (result.whiteQueenSide) castling += 'Q';
    if (result.blackKingSide) castling += 'k';
    if (result.blackQueenSide) castling += 'q';
    
    return castling.isEmpty ? '-' : castling;
  }
  
  /// Updates FEN with corrected castling rights
  static String updateFenWithCastlingRights(String fen) {
    try {
      final analysis = analyzeCastlingRights(fen);
      if (!analysis.isValid) {
        print('$_TAG: Cannot analyze castling rights, keeping original FEN');
        return fen;
      }
      
      final parts = fen.split(' ');
      if (parts.length < 3) {
        print('$_TAG: Invalid FEN format, cannot update castling rights');
        return fen;
      }
      
      final oldCastling = parts[2];
      final newCastling = analysis.castlingString;
      
      if (oldCastling != newCastling) {
        print('$_TAG: Updating castling rights from "$oldCastling" to "$newCastling"');
        parts[2] = newCastling;
        return parts.join(' ');
      }
      
      return fen;
      
    } catch (e) {
      print('$_TAG: Error updating FEN with castling rights: $e');
      return fen;
    }
  }
  
  /// Validates if specific castling rights can be enabled
  static CastlingValidation validateCastlingChange({
    required String fen,
    required bool whiteKingSide,
    required bool whiteQueenSide,
    required bool blackKingSide,
    required bool blackQueenSide,
  }) {
    try {
      final analysis = analyzeCastlingRights(fen);
      if (!analysis.isValid) {
        return CastlingValidation.invalid('Cannot analyze position');
      }
      
      final errors = <String>[];
      
      // Check each requested right against what's actually possible
      if (whiteKingSide && !analysis.whiteKingSide) {
        errors.add('White king-side castling is not possible (King must be on e1, Rook on h1)');
      }
      
      if (whiteQueenSide && !analysis.whiteQueenSide) {
        errors.add('White queen-side castling is not possible (King must be on e1, Rook on a1)');
      }
      
      if (blackKingSide && !analysis.blackKingSide) {
        errors.add('Black king-side castling is not possible (King must be on e8, Rook on h8)');
      }
      
      if (blackQueenSide && !analysis.blackQueenSide) {
        errors.add('Black queen-side castling is not possible (King must be on e8, Rook on a8)');
      }
      
      if (errors.isNotEmpty) {
        return CastlingValidation.invalid(errors.join('\n\n'));
      }
      
      return CastlingValidation.valid();
      
    } catch (e) {
      return CastlingValidation.invalid('Error validating castling rights: $e');
    }
  }
}

/// Result of castling rights analysis
class CastlingRightsResult {
  bool whiteKingSide;
  bool whiteQueenSide;
  bool blackKingSide;
  bool blackQueenSide;
  String castlingString;
  bool isValid;
  String? errorMessage;
  
  CastlingRightsResult({
    this.whiteKingSide = false,
    this.whiteQueenSide = false,
    this.blackKingSide = false,
    this.blackQueenSide = false,
    this.castlingString = '-',
    this.isValid = true,
    this.errorMessage,
  });
  
  factory CastlingRightsResult.empty() {
    return CastlingRightsResult();
  }
  
  factory CastlingRightsResult.invalid(String error) {
    return CastlingRightsResult(
      isValid: false,
      errorMessage: error,
    );
  }
  
  /// Check if any castling is possible
  bool get hasAnyCastlingRights {
    return whiteKingSide || whiteQueenSide || blackKingSide || blackQueenSide;
  }
  
  /// Get a human-readable description
  String get description {
    if (!isValid) {
      return errorMessage ?? 'Invalid position';
    }
    
    if (!hasAnyCastlingRights) {
      return 'No castling rights available';
    }
    
    final rights = <String>[];
    if (whiteKingSide) rights.add('White king-side');
    if (whiteQueenSide) rights.add('White queen-side');
    if (blackKingSide) rights.add('Black king-side');
    if (blackQueenSide) rights.add('Black queen-side');
    
    return 'Available: ${rights.join(', ')}';
  }
}

/// Result of castling validation
class CastlingValidation {
  final bool isValid;
  final String? errorMessage;
  
  CastlingValidation.valid() : isValid = true, errorMessage = null;
  CastlingValidation.invalid(this.errorMessage) : isValid = false;
}