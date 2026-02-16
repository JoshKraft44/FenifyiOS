import 'package:flutter/foundation.dart';
import 'package:dartchess/dartchess.dart';
import '../services/dartchess_validation_service.dart';

/// Utility class for FEN manipulation, validation, chess position analysis
class FenUtils {
  // Standard initial position FEN
  static String getInitialPosition() {
    return 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  }

  /// FEN validation using DartChess
  static bool validateFen(String fen) {
    final result = DartChessValidationService.validateFen(fen);
    return result.isValid;
  }

  /// Get detailed validation result with error information
  static ValidationResult validateFenDetailed(String fen) {
    return DartChessValidationService.validateFen(fen);
  }

  /// Create a chess position from FEN string
  static Position? createPosition(String fen) {
    try {
      final setup = Setup.parseFen(fen);
      if (setup == null) return null;
      
      return Position.setupPosition(setup);
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating position from FEN: $e');
      return null;
    }
  }

  /// Get the setup object from FEN string
  static Setup? parseSetup(String fen) {
    try {
      return Setup.parseFen(fen);
    } catch (e) {
      if (kDebugMode) debugPrint('Error parsing FEN setup: $e');
      return null;
    }
  }

  /// Convert dartchess position to FEN string
  static String positionToFen(Position position) {
    return position.fen;
  }

  /// Create FEN with specific turn for DartChess ^0.9.0 API
  static String createFenWithTurn(String fen, Side turn) {
    try {
      // Modify the FEN string directly instead of using Setup constructor
      final parts = fen.split(' ');
      if (parts.length >= 2) {
        parts[1] = turn == Side.white ? 'w' : 'b';
        final newFen = parts.join(' ');
        
        // Validate the new FEN works
        final newPosition = createPosition(newFen);
        return newPosition?.fen ?? fen;
      }
      
      return fen;
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating FEN with turn: $e');
      return fen;
    }
  }

  /// Check if position is valid and playable
  static bool isValidPosition(String fen) {
    final result = DartChessValidationService.validateFen(fen);
    return result.isValid && result.position != null;
  }

  /// Get position analysis
  static PositionAnalysis? analyzePosition(String fen) {
    final result = DartChessValidationService.validateFen(fen);
    return result.analysis;
  }

  /// Check if position is in check
  static bool isInCheck(String fen) {
    final position = createPosition(fen);
    return position?.isCheck ?? false;
  }

  /// Check if position is checkmate
  static bool isCheckmate(String fen) {
    final position = createPosition(fen);
    return position?.isCheckmate ?? false;
  }

  /// Check if position is stalemate
  static bool isStalemate(String fen) {
    final position = createPosition(fen);
    return position?.isStalemate ?? false;
  }

  /// Get number of legal moves in position
  static int getLegalMovesCount(String fen) {
    final position = createPosition(fen);
    return position?.legalMoves.length ?? 0;
  }

  /// Check if game is over
  static bool isGameOver(String fen) {
    final position = createPosition(fen);
    return position?.isGameOver ?? false;
  }

  /// Get game outcome if game is over
  static Outcome? getOutcome(String fen) {
    final position = createPosition(fen);
    return position?.outcome;
  }

  /// Get material balance (positive = white advantage)
  static int getMaterialBalance(String fen) {
    final analysis = analyzePosition(fen);
    return analysis?.materialBalance ?? 0;
  }


  /// Clean FEN by removing any custom flags
  static String cleanFen(String fen) {
    return fen.replaceAll(RegExp(r' INVALID_\w+'), '').trim();
  }

  /// Extract board position from FEN (first part before space)
  static String extractBoardPosition(String fen) {
    return fen.split(' ')[0];
  }

  /// Extract active color from FEN
  static Side? extractActiveColor(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 2) return null;
    
    return parts[1] == 'w' ? Side.white : Side.black;
  }

  /// Extract castling rights from FEN - SIMPLIFIED VERSION
  static String extractCastlingRights(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 3) return '-';
    
    return parts[2];
  }

  /// Extract en passant square from FEN
  static Square? extractEnPassantSquare(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 4 || parts[3] == '-') return null;
    
    try {
      // Parse square name like "e3", "d6", etc.
      final squareName = parts[3];
      if (squareName.length != 2) return null;
      
      final fileIndex = squareName[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rankIndex = int.parse(squareName[1]) - 1;
      
      if (fileIndex >= 0 && fileIndex < 8 && rankIndex >= 0 && rankIndex < 8) {
        return Square.fromCoords(File.values[fileIndex], Rank.values[rankIndex]);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extract halfmove clock from FEN
  static int extractHalfmoveClock(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 5) return 0;
    
    return int.tryParse(parts[4]) ?? 0;
  }

  /// Extract fullmove number from FEN
  static int extractFullmoveNumber(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 6) return 1;
    
    return int.tryParse(parts[5]) ?? 1;
  }

  /// Create FEN from components - SIMPLIFIED VERSION
  static String createFen({
    required String boardPosition,
    required Side activeColor,
    String castlingRights = 'KQkq',
    Square? enPassantSquare,
    int halfmoveClock = 0,
    int fullmoveNumber = 1,
  }) {
    final parts = <String>[
      boardPosition,
      activeColor == Side.white ? 'w' : 'b',
      castlingRights.isEmpty ? '-' : castlingRights,
      enPassantSquare?.name ?? '-',
      halfmoveClock.toString(),
      fullmoveNumber.toString(),
    ];
    
    return parts.join(' ');
  }

  /// Convert 64-element piece matrix to FEN notation (used by ML image processing)
  static String positionToFenFromMatrix(List<String> pieceLabels) {
    if (pieceLabels.length != 64) {
      throw Exception('Position must have 64 squares');
    }

    final Map<String, String> pieceMap = {
      'white_pawn': 'P',
      'white_knight': 'N',
      'white_bishop': 'B',
      'white_rook': 'R',
      'white_queen': 'Q',
      'white_king': 'K',
      'black_pawn': 'p',
      'black_knight': 'n',
      'black_bishop': 'b',
      'black_rook': 'r',
      'black_queen': 'q',
      'black_king': 'k',
      'empty': '',
    };

    String fen = '';
    
    for (int row = 0; row < 8; row++) {
      int emptyCount = 0;
      
      for (int col = 0; col < 8; col++) {
        final index = row * 8 + col;
        final pieceLabel = pieceLabels[index];
        final pieceChar = pieceMap[pieceLabel] ?? '';
        
        if (pieceChar.isEmpty) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            fen += emptyCount.toString();
            emptyCount = 0;
          }
          fen += pieceChar;
        }
      }
      
      if (emptyCount > 0) {
        fen += emptyCount.toString();
      }
      
      if (row < 7) {
        fen += '/';
      }
    }
    
    // Add the remaining FEN components
    fen += ' w KQkq - 0 1';
    
    return fen;
  }


  /// Check if FEN represents starting position
  static bool isStartingPosition(String fen) {
    final cleanFen = cleanFen(fen);
    return cleanFen.startsWith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR');
  }

  /// Get common chess openings FENs
  static Map<String, String> getCommonOpenings() {
    return {
      'Starting Position':
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      'Sicilian Defense':
          'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
      'French Defense':
          'rnbqkbnr/pppp1ppp/4p3/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
      'Caro-Kann Defense':
          'rnbqkbnr/pp1ppppp/2p5/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
      'Queen\'s Gambit':
          'rnbqkbnr/ppp1pppp/8/3p4/2PP4/8/PP2PPPP/RNBQKBNR b KQkq c3 0 2',
      'King\'s Indian Defense':
          'rnbqkb1r/pppppp1p/5np1/8/2PP4/8/PP2PPPP/RNBQKBNR w KQkq - 0 3',
      'English Opening':
          'rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR b KQkq c3 0 1',
      'Ruy Lopez':
          'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
    };
  }

  /// Get endgame study positions
  static Map<String, String> getEndgamePositions() {
    return {
      'King and Queen vs King': '8/8/8/8/8/8/4K3/3QK3 w - - 0 1',
      'King and Rook vs King': '8/8/8/8/8/8/4K3/3RK3 w - - 0 1',
      'King and Pawn vs King': '8/8/8/8/8/8/3PK3/3K4 w - - 0 1',
      'Opposition': '8/8/8/3k4/8/3K4/8/8 w - - 0 1',
      'Lucena Position': '1K6/1P1k4/8/8/8/8/4r3/2R5 w - - 0 1',
      'Philidor Position': '2r5/8/8/8/8/3k4/R7/3K4 b - - 0 1',
    };
  }
}
