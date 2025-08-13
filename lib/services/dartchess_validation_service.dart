// lib/services/dartchess_validation_service.dart
import 'package:flutter/foundation.dart';
import 'package:dartchess/dartchess.dart';
import '../core/errors/error_handler.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/result.dart';
import 'castling_rights_detector.dart';

/// FEN validation service using the dartchess library
/// Provides chess position validation with automatic castling correction
class DartChessValidationService {
  static const String _TAG = 'DartChessValidationService';

  /// Main validation entry point - validates FEN and provides detailed analysis
  /// Automatically corrects castling rights based on piece positions
  static ValidationResult validateFen(String fen) {
    if (fen.trim().isEmpty) {
      return ValidationResult.invalid('FEN string cannot be empty');
    }

    try {
      if (kDebugMode) debugPrint('$_TAG: Validating FEN: $fen');
      
      // Remove any custom flags from image processing
      final cleanFen = _cleanFen(fen);
      if (kDebugMode) debugPrint('$_TAG: Cleaned FEN: $cleanFen');
      
      // Apply intelligent castling rights correction
      final correctedFen = CastlingRightsDetector.updateFenWithCastlingRights(cleanFen);
      if (kDebugMode) debugPrint('$_TAG: Corrected FEN: $correctedFen');
      
      // Parse using dartchess library
      final Setup? setup = Setup.parseFen(correctedFen);
      
      if (setup == null) {
        return ValidationResult.invalid('Invalid FEN format - failed to parse');
      }
      
      // Create position from setup using updated API
      final Position position = Position.setupPosition(Rule.chess, setup);
      
      // Perform additional chess rule validation
      final validationError = _performAdditionalValidation(setup, position);
      if (validationError != null) {
        return ValidationResult.invalid(validationError);
      }
      
      // Generate position analysis
      final analysis = _analyzePosition(position);
      
      if (kDebugMode) debugPrint('$_TAG: SUCCESS - FEN validation successful');
      return ValidationResult.valid(
        cleanFen: correctedFen, // Return corrected version
        setup: setup,
        position: position,
        analysis: analysis,
      );
      
    } catch (e) {
      if (kDebugMode) debugPrint('$_TAG: ERROR - FEN validation failed: $e');
      return ValidationResult.invalid('FEN validation error: ${e.toString()}');
    }
  }

  /// Modern Result-based validation method - doesn't throw exceptions.
  /// Use this for better error handling in UI code.
  static Result<ValidationResult, ValidationException> validateFenSafely(String fen) {
    try {
      final result = validateFen(fen);
      return Success(result);
    } catch (e, stackTrace) {
      final exception = ErrorHandler().handleValidationError(e, stackTrace, context: 'FEN validation');
      if (exception is ValidationException) {
        return Failure(exception);
      }
      // Convert other exceptions to ValidationException
      return Failure(ValidationException(
        exception.message,
        originalError: exception.originalError,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Removes custom flags added during image processing
  static String _cleanFen(String fen) {
    return fen.replaceAll(RegExp(r' INVALID_\w+'), '').trim();
  }

  /// Validates chess rules beyond basic FEN parsing
  /// Checks for exactly one king per side, valid pawn placement, etc.
  static String? _performAdditionalValidation(Setup setup, Position position) {
    try {
      final board = setup.board;
      int whiteKings = 0;
      int blackKings = 0;
      
      // Count kings and validate positions
      for (int file = 0; file < 8; file++) {
        for (int rank = 0; rank < 8; rank++) {
          final square = Square.fromCoords(File.values[file], Rank.values[rank]);
          final piece = board.pieceAt(square);
          if (piece != null) {
            if (piece.role == Role.king) {
              if (piece.color == Side.white) {
                whiteKings++;
              } else {
                blackKings++;
              }
            }
          }
        }
      }
      
      if (whiteKings != 1) {
        return 'Invalid position: must have exactly one white king (found $whiteKings)';
      }
      
      if (blackKings != 1) {
        return 'Invalid position: must have exactly one black king (found $blackKings)';
      }
      
      // Validate that kings are not adjacent (illegal position)
      final whiteKingSquare = _findKingSquare(board, Side.white);
      final blackKingSquare = _findKingSquare(board, Side.black);
      
      if (whiteKingSquare != null && blackKingSquare != null) {
        if (_areSquaresAdjacent(whiteKingSquare, blackKingSquare)) {
          return 'Invalid position: kings cannot be adjacent';
        }
      }
      
      // Validate pawn placement (no pawns on promotion ranks)
      for (int file = 0; file < 8; file++) {
        // Check 1st rank
        final piece1stRank = board.pieceAt(Square.fromCoords(File.values[file], Rank.first));
        if (piece1stRank?.role == Role.pawn) {
          return 'Invalid position: pawns cannot be on the 1st rank';
        }
        
        // Check 8th rank
        final piece8thRank = board.pieceAt(Square.fromCoords(File.values[file], Rank.eighth));
        if (piece8thRank?.role == Role.pawn) {
          return 'Invalid position: pawns cannot be on the 8th rank';
        }
      }
      
      return null; // All validations passed
      
    } catch (e) {
      return 'Validation error: ${e.toString()}';
    }
  }

  static Square? _findKingSquare(Board board, Side color) {
    for (int file = 0; file < 8; file++) {
      for (int rank = 0; rank < 8; rank++) {
        final square = Square.fromCoords(File.values[file], Rank.values[rank]);
        final piece = board.pieceAt(square);
        if (piece?.role == Role.king && piece?.color == color) {
          return square;
        }
      }
    }
    return null;
  }

  /// Checks if two squares are adjacent (including diagonally)
  static bool _areSquaresAdjacent(Square sq1, Square sq2) {
    final file1 = sq1.file.value;
    final rank1 = sq1.rank.value;
    final file2 = sq2.file.value;
    final rank2 = sq2.rank.value;
    
    final fileDiff = (file1 - file2).abs();
    final rankDiff = (rank1 - rank2).abs();
    
    return fileDiff <= 1 && rankDiff <= 1 && (fileDiff + rankDiff > 0);
  }

  /// Analyzes position to provide detailed information for UI display
  static PositionAnalysis _analyzePosition(Position position) {
    return PositionAnalysis(
      isCheck: position.isCheck,
      isCheckmate: position.isCheckmate,
      isStalemate: position.isStalemate,
      isInsufficientMaterial: position.isInsufficientMaterial,
      isGameOver: position.isGameOver,
      outcome: position.outcome,
      legalMovesCount: position.legalMoves.length,
      materialBalance: _calculateMaterialBalance(position),
    );
  }

  /// Calculates material advantage (positive = white advantage)
  static int _calculateMaterialBalance(Position position) {
    final board = position.board;
    final pieceValues = {
      Role.pawn: 1,
      Role.knight: 3,
      Role.bishop: 3,
      Role.rook: 5,
      Role.queen: 9,
      Role.king: 0,
    };
    
    int whiteTotal = 0;
    int blackTotal = 0;
    
    for (int file = 0; file < 8; file++) {
      for (int rank = 0; rank < 8; rank++) {
        final square = Square.fromCoords(File.values[file], Rank.values[rank]);
        final piece = board.pieceAt(square);
        if (piece != null) {
          final value = pieceValues[piece.role] ?? 0;
          if (piece.color == Side.white) {
            whiteTotal += value;
          } else {
            blackTotal += value;
          }
        }
      }
    }
    
    return whiteTotal - blackTotal;
  }


  /// Creates new position with modified turn
  static ValidationResult createPositionWithTurn(String fen, Side turn) {
    try {
      final parts = fen.split(' ');
      if (parts.length < 6) {
        return ValidationResult.invalid('Invalid FEN format');
      }
      
      parts[1] = turn == Side.white ? 'w' : 'b';
      final newFen = parts.join(' ');
      
      return validateFen(newFen);
      
    } catch (e) {
      return ValidationResult.invalid('Error creating position with new turn: $e');
    }
  }
}

/// Container for validation results with detailed analysis
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? cleanFen;
  final Setup? setup;
  final Position? position;
  final PositionAnalysis? analysis;

  ValidationResult.valid({
    required this.cleanFen,
    required this.setup,
    required this.position,
    required this.analysis,
  }) : isValid = true, errorMessage = null;

  ValidationResult.invalid(this.errorMessage)
      : isValid = false, cleanFen = null, setup = null, position = null, analysis = null;
}

/// Detailed analysis of a chess position
class PositionAnalysis {
  final bool isCheck;
  final bool isCheckmate;
  final bool isStalemate;
  final bool isInsufficientMaterial;
  final bool isGameOver;
  final Outcome? outcome;
  final int legalMovesCount;
  final int materialBalance;

  PositionAnalysis({
    required this.isCheck,
    required this.isCheckmate,
    required this.isStalemate,
    required this.isInsufficientMaterial,
    required this.isGameOver,
    required this.outcome,
    required this.legalMovesCount,
    required this.materialBalance,
  });

  String get statusDescription {
    if (isCheckmate) return 'Checkmate';
    if (isStalemate) return 'Stalemate';
    if (isInsufficientMaterial) return 'Insufficient Material';
    if (isCheck) return 'Check';
    return 'Normal';
  }

  String get materialDescription {
    if (materialBalance > 0) {
      return 'White +${materialBalance}';
    } else if (materialBalance < 0) {
      return 'Black +${materialBalance.abs()}';
    } else {
      return 'Equal material';
    }
  }
}

