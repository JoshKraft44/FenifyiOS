import 'package:flutter/foundation.dart';
import 'package:chess/chess.dart' as chess_lib;

// Detects move details from chess game state changes - for Move History + Highlighting
class ChessMoveDetector {
  
  Map<String, String>? detectMove({
    required dynamic lastMove,
    required String newFen,
    required List<Map<String, dynamic>> gameHistory,
    required int currentMoveIndex,
  }) {
    String? moveFromSquare;
    String? moveToSquare;
    
    try {
      if (kDebugMode) {
        debugPrint('Move object: $lastMove');
        debugPrint('Move object type: ${lastMove.runtimeType}');
      }
      
      // Method 1: Try to extract move details from move object string
      try {
        final moveData = lastMove.toString();
        if (kDebugMode) debugPrint('Move data string: $moveData');
        
        if (moveData.contains('from:') && moveData.contains('to:')) {
          final fromMatch = RegExp(r'from:\s*([a-h][1-8])').firstMatch(moveData);
          final toMatch = RegExp(r'to:\s*([a-h][1-8])').firstMatch(moveData);
          
          if (fromMatch != null && toMatch != null) {
            moveFromSquare = fromMatch.group(1);
            moveToSquare = toMatch.group(1);
            if (kDebugMode) debugPrint('Extracted from object string: $moveFromSquare -> $moveToSquare');
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to extract from move object string: $e');
      }
      
      // Method 2: Compare current board state with previous to detect changes
      if (moveFromSquare == null || moveToSquare == null) {
        if (kDebugMode) debugPrint('Attempting board diff analysis...');
        
        if (gameHistory.isNotEmpty && currentMoveIndex >= 0) {
          try {
            final previousFen = gameHistory[currentMoveIndex]['fen'] as String;
            final currentFen = newFen;
            
            if (kDebugMode) {
              debugPrint('Previous FEN: $previousFen');
              debugPrint('Current FEN: $currentFen');
            }
            
            final moveSquares = _detectMoveFromFenDiff(previousFen, currentFen);
            if (moveSquares != null) {
              moveFromSquare = moveSquares['from'];
              moveToSquare = moveSquares['to'];
              if (kDebugMode) debugPrint('Detected from FEN diff: $moveFromSquare -> $moveToSquare');
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Error in board diff analysis: $e');
          }
        }
      }
      
      // Method 3: Use move tracking approach
      if (moveFromSquare == null || moveToSquare == null) {
        if (kDebugMode) debugPrint('Attempting move detection...');
        
        try {
          if (gameHistory.isNotEmpty && currentMoveIndex >= 0) {
            final previousFen = gameHistory[currentMoveIndex]['fen'] as String;
            
            final tempChess = chess_lib.Chess.fromFEN(previousFen);
            final legalMoves = tempChess.moves({'verbose': true});
            
            // Find the move that transforms previous position to current position
            for (final move in legalMoves) {
              if (move != null && move is Map<String, dynamic>) {
                final tempChess2 = chess_lib.Chess.fromFEN(previousFen);
                
                try {
                  final moveResult = tempChess2.move({
                    'from': move['from'],
                    'to': move['to'],
                    'promotion': move['promotion'],
                  });
                  
                  if (moveResult != null && tempChess2.fen == newFen) {
                    moveFromSquare = move['from'] as String?;
                    moveToSquare = move['to'] as String?;
                    if (kDebugMode) debugPrint('Found matching move: $moveFromSquare -> $moveToSquare');
                    break;
                  }
                } catch (e) {
                  continue;
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error in move detection: $e');
        }
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('Error extracting move details: $e');
    }

    if (moveFromSquare != null && moveToSquare != null) {
      return {'from': moveFromSquare, 'to': moveToSquare};
    }
    
    return null;
  }

  // Helper method to detect move by comparing FEN positions
  Map<String, String>? _detectMoveFromFenDiff(String previousFen, String currentFen) {
    try {
      // Extract board parts (ignore game state)
      final prevBoard = previousFen.split(' ')[0];
      final currBoard = currentFen.split(' ')[0];
      
      if (prevBoard == currBoard) return null;
      
      // Convert FEN board to 8x8 arrays for comparison
      final prevSquares = _fenToSquareArray(prevBoard);
      final currSquares = _fenToSquareArray(currBoard);
      
      String? fromSquare;
      String? toSquare;
      
      // Find differences
      for (int rank = 0; rank < 8; rank++) {
        for (int file = 0; file < 8; file++) {
          final prevPiece = prevSquares[rank][file];
          final currPiece = currSquares[rank][file];
          
          if (prevPiece != currPiece) {
            final square = _indexToSquare(rank, file);
            
            if (prevPiece != ' ' && currPiece == ' ') {
              // Piece moved from this square
              fromSquare = square;
            } else if (prevPiece == ' ' && currPiece != ' ') {
              // Piece moved to this square
              toSquare = square;
            } else if (prevPiece != ' ' && currPiece != ' ' && prevPiece != currPiece) {
              // Capture: piece replaced another piece
              toSquare = square;
            }
          }
        }
      }
      
      // Special handling for castling
      if (fromSquare == null || toSquare == null) {
        final castlingMove = _detectCastling(prevBoard, currBoard);
        if (castlingMove != null) return castlingMove;
      }
      
      if (fromSquare != null && toSquare != null) {
        return {'from': fromSquare, 'to': toSquare};
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error in FEN diff detection: $e');
      return null;
    }
  }

  // Convert FEN board part to 8x8 character array
  List<List<String>> _fenToSquareArray(String boardFen) {
    final squares = List.generate(8, (_) => List.filled(8, ' '));
    final ranks = boardFen.split('/');
    
    for (int rank = 0; rank < 8; rank++) {
      int file = 0;
      for (int i = 0; i < ranks[rank].length; i++) {
        final char = ranks[rank][i];
        if ('12345678'.contains(char)) {
          // Empty squares
          file += int.parse(char);
        } else {
          // Piece
          squares[rank][file] = char;
          file++;
        }
      }
    }
    
    return squares;
  }

  // Convert rank/file indices to square notation
  String _indexToSquare(int rank, int file) {
    final fileChar = String.fromCharCode(97 + file); // a-h
    final rankChar = (8 - rank).toString(); // 8-1
    return '$fileChar$rankChar';
  }

  // Detect castling moves
  Map<String, String>? _detectCastling(String prevBoard, String currBoard) {
    try {
      final prevSquares = _fenToSquareArray(prevBoard);
      final currSquares = _fenToSquareArray(currBoard);
      
      // Check for white castling
      if (prevSquares[7][4] == 'K' && currSquares[7][4] == ' ') {
        // King moved from e1
        if (currSquares[7][6] == 'K' && prevSquares[7][7] == 'R' && currSquares[7][5] == 'R') {
          // Kingside castling
          return {'from': 'e1', 'to': 'g1'};
        } else if (currSquares[7][2] == 'K' && prevSquares[7][0] == 'R' && currSquares[7][3] == 'R') {
          // Queenside castling
          return {'from': 'e1', 'to': 'c1'};
        }
      }
      
      // Check for black castling
      if (prevSquares[0][4] == 'k' && currSquares[0][4] == ' ') {
        // King moved from e8
        if (currSquares[0][6] == 'k' && prevSquares[0][7] == 'r' && currSquares[0][5] == 'r') {
          // Kingside castling
          return {'from': 'e8', 'to': 'g8'};
        } else if (currSquares[0][2] == 'k' && prevSquares[0][0] == 'r' && currSquares[0][3] == 'r') {
          // Queenside castling
          return {'from': 'e8', 'to': 'c8'};
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Error detecting castling: $e');
      return null;
    }
  }
}