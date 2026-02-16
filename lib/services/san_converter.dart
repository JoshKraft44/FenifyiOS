import 'package:flutter/foundation.dart';
import 'package:dartchess/dartchess.dart';

/// Service for converting UCI moves to Standard Algebraic Notation (SAN)
/// Provides proper chess notation like "Nf3", "Bxd7+", "O-O", etc.
class SanConverter {
  static final SanConverter _instance = SanConverter._internal();
  factory SanConverter() => _instance;
  SanConverter._internal();

  /// Convert a UCI move to SAN notation
  /// UCI format: e2e4, g1f3, e1g1 (castling)
  /// SAN format: e4, Nf3, O-O
  String uciToSan(String uciMove, String currentFen) {
    try {
      if (uciMove.isEmpty || uciMove.length < 4) {
        return uciMove; // Return as-is if invalid
      }

      // Parse the current position
      final setup = Setup.parseFen(currentFen);

      final position = Position.setupPosition(Rule.chess, setup);

      // Parse the UCI move
      final fromSquare = Square.fromName(uciMove.substring(0, 2));
      final toSquare = Square.fromName(uciMove.substring(2, 4));
      final promotion =
          uciMove.length > 4 ? Role.fromChar(uciMove.substring(4, 5)) : null;

      // Create the move
      Move move;
      if (promotion != null) {
        move = NormalMove(from: fromSquare, to: toSquare, promotion: promotion);
      } else {
        move = NormalMove(from: fromSquare, to: toSquare);
      }

      // Check if it's a valid move in this position
      if (!position.isLegal(move)) {
        return uciMove;
      }

      // Convert to SAN using dartchess
      final sanResult = position.makeSan(move);
      return sanResult.$2;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error converting UCI to SAN: $uciMove, error: $e');
      }
      return uciMove; // Fallback to UCI notation
    }
  }

  /// Convert a list of UCI moves to SAN notation
  /// Used for principal variations and move sequences
  List<String> uciListToSan(List<String> uciMoves, String startingFen) {
    if (uciMoves.isEmpty) return [];

    try {
      final sanMoves = <String>[];
      String currentFen = startingFen;

      // Parse initial position
      var setup = Setup.parseFen(currentFen);

      var position = Position.setupPosition(Rule.chess, setup);

      for (final uciMove in uciMoves) {
        try {
          if (uciMove.isEmpty || uciMove.length < 4) {
            sanMoves.add(uciMove);
            continue;
          }

          // Parse the UCI move
          final fromSquare = Square.fromName(uciMove.substring(0, 2));
          final toSquare = Square.fromName(uciMove.substring(2, 4));
          final promotion = uciMove.length > 4
              ? Role.fromChar(uciMove.substring(4, 5))
              : null;

          // Create the move
          Move move;
          if (promotion != null) {
            move = NormalMove(
                from: fromSquare, to: toSquare, promotion: promotion);
          } else {
            move = NormalMove(from: fromSquare, to: toSquare);
          }

          // Check if it's a valid move
          if (!position.isLegal(move)) {
            debugPrint(
                'Move validation failed for: $uciMove (continuing with UCI)');
            sanMoves.add(uciMove); // Keep UCI if invalid
            break; // Stop processing on invalid moves
          }

          // Convert to SAN
          final sanResult = position.makeSan(move);
          sanMoves.add(sanResult.$2);

          // Make the move and update position for next iteration
          position = sanResult.$1;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error converting move $uciMove to SAN: $e');
          }
          sanMoves.add(uciMove); // Fallback to UCI
        }
      }

      return sanMoves;
    } catch (e) {
      if (kDebugMode) debugPrint('Error converting UCI list to SAN: $e');
      return uciMoves; // Fallback to UCI moves
    }
  }

  /// Convert a single best move to SAN with move number
  /// Format: "15. Nf3" or "15...Bxd7" depending on turn
  String formatBestMoveWithNumber(String uciMove, String currentFen) {
    try {
      if (uciMove.isEmpty) return '';

      final setup = Setup.parseFen(currentFen);

      final sanMove = uciToSan(uciMove, currentFen);
      final fullmoveNumber = setup.fullmoves;
      final isWhiteTurn = setup.turn == Side.white;

      if (isWhiteTurn) {
        return '$fullmoveNumber. $sanMove';
      } else {
        return '$fullmoveNumber...$sanMove';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error formatting best move with number: $e');
      return uciMove;
    }
  }

  /// Format a principal variation with proper move numbering
  /// Example: "1. e4 e5 2. Nf3 Nc6 3. Bb5"
  String formatPrincipalVariation(List<String> uciMoves, String startingFen,
      {int maxMoves = 10}) {
    if (uciMoves.isEmpty) return '';

    try {
      final setup = Setup.parseFen(startingFen);

      final sanMoves =
          uciListToSan(uciMoves.take(maxMoves).toList(), startingFen);
      if (sanMoves.isEmpty) return '';

      final formatted = <String>[];
      int fullmoveNumber = setup.fullmoves;
      bool isWhiteTurn = setup.turn == Side.white;

      for (int i = 0; i < sanMoves.length; i++) {
        final sanMove = sanMoves[i];

        if (isWhiteTurn) {
          // White's move
          formatted.add('$fullmoveNumber. $sanMove');
        } else {
          // Black's move
          if (i == 0) {
            // First move is black, need to show move number with dots
            formatted.add('$fullmoveNumber...$sanMove');
          } else {
            formatted.add(sanMove);
          }
          fullmoveNumber++; // Increment after black's move
        }

        isWhiteTurn = !isWhiteTurn;
      }

      return formatted.join(' ');
    } catch (e) {
      if (kDebugMode) debugPrint('Error formatting principal variation: $e');
      return uciMoves.take(maxMoves).join(' ');
    }
  }
}
