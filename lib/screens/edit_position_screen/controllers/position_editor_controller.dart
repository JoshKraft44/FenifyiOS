import 'package:flutter/foundation.dart';
import 'package:dartchess/dartchess.dart';
import '../../../services/castling_rights_detector.dart';

/// Manages interactive chess position editing with real-time visual feedback
/// Supports drag-and-drop, piece placement, and removal modes
class PositionEditorController {
  final String initialFen;
  final VoidCallback onStateChanged;

  // Core position state
  Position? _position;
  String _currentFen = '';
  
  // UI state
  bool _boardFlipped = false;
  
  // Edit mode state - only one can be active at a time
  bool _isDragMode = true;
  bool _isPlaceMode = false;
  bool _isRemoveMode = false;
  
  // Mode-specific state
  Square? _selectedSquare;  // For drag mode
  String? _selectedPiece;   // For place mode
  
  // Chess rule validation
  bool _whiteKingSide = true;
  bool _whiteQueenSide = true;
  bool _blackKingSide = true;
  bool _blackQueenSide = true;
  
  CastlingRightsResult? _possibleCastlingRights;

  /// Piece definitions with SVG asset paths for UI rendering
  final List<Map<String, String>> whitePieces = [
    {'symbol': 'P', 'asset': 'assets/pieces/wP.svg'},
    {'symbol': 'N', 'asset': 'assets/pieces/wN.svg'},
    {'symbol': 'B', 'asset': 'assets/pieces/wB.svg'},
    {'symbol': 'R', 'asset': 'assets/pieces/wR.svg'},
    {'symbol': 'Q', 'asset': 'assets/pieces/wQ.svg'},
    {'symbol': 'K', 'asset': 'assets/pieces/wK.svg'},
  ];
  
  final List<Map<String, String>> blackPieces = [
    {'symbol': 'p', 'asset': 'assets/pieces/bP.svg'},
    {'symbol': 'n', 'asset': 'assets/pieces/bN.svg'},
    {'symbol': 'b', 'asset': 'assets/pieces/bB.svg'},
    {'symbol': 'r', 'asset': 'assets/pieces/bR.svg'},
    {'symbol': 'q', 'asset': 'assets/pieces/bQ.svg'},
    {'symbol': 'k', 'asset': 'assets/pieces/bK.svg'},
  ];

  PositionEditorController({
    required this.initialFen,
    required this.onStateChanged,
  });

  // State getters
  Position? get position => _position;
  String get currentFen => _currentFen;
  bool get boardFlipped => _boardFlipped;
  bool get isDragMode => _isDragMode;
  bool get isPlaceMode => _isPlaceMode;
  bool get isRemoveMode => _isRemoveMode;
  Square? get selectedSquare => _selectedSquare;
  String? get selectedPiece => _selectedPiece;
  
  bool get whiteKingSide => _whiteKingSide;
  bool get whiteQueenSide => _whiteQueenSide;
  bool get blackKingSide => _blackKingSide;
  bool get blackQueenSide => _blackQueenSide;
  CastlingRightsResult? get possibleCastlingRights => _possibleCastlingRights;

  /// Initializes the editor with the provided FEN, handling invalid positions gracefully
  void initialize() {
    try {
      final cleanFen = initialFen.replaceAll(RegExp(r' INVALID_\w+'), '').trim();
      if (kDebugMode) debugPrint('EditPosition: Initializing with FEN: $cleanFen');
      
      final setup = Setup.parseFen(cleanFen);
      try {
        _position = Position.setupPosition(Rule.chess, setup);
        _currentFen = _position!.fen;
        if (kDebugMode) debugPrint('EditPosition: Successfully created position');
      } catch (e) {
        if (kDebugMode) debugPrint('EditPosition: Position invalid, but will allow editing: $e');
        // Create fallback position while preserving original FEN for editing
        final defaultSetup = Setup.parseFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
        _position = Position.setupPosition(Rule.chess, defaultSetup);
        _currentFen = cleanFen;
      }
          
      _initializeCastlingRights(_currentFen);
      onStateChanged();
      
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error in initialization: $e');
      // Emergency fallback to starting position
      final defaultSetup = Setup.parseFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      _position = Position.setupPosition(Rule.chess, defaultSetup);
      _currentFen = _position!.fen;
      _initializeCastlingRights(_currentFen);
      onStateChanged();
    }
  }

  /// Analyzes current position for valid castling rights based on piece placement
  void _initializeCastlingRights(String fen) {
    try {
      _parseCastlingRightsFromFen(fen);
      _possibleCastlingRights = CastlingRightsDetector.analyzeCastlingRights(fen);
      
      if (kDebugMode) debugPrint('EditPosition: Initialized castling rights from FEN');
      if (kDebugMode) debugPrint('  From FEN - K:$_whiteKingSide Q:$_whiteQueenSide k:$_blackKingSide q:$_blackQueenSide');
      if (_possibleCastlingRights?.isValid == true) {
        final possible = _possibleCastlingRights!;
        if (kDebugMode) debugPrint('  Possible - K:${possible.whiteKingSide} Q:${possible.whiteQueenSide} k:${possible.blackKingSide} q:${possible.blackQueenSide}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error initializing castling rights: $e');
      _parseCastlingRightsFromFen(fen);
    }
  }

  void _parseCastlingRightsFromFen(String fen) {
    final parts = fen.split(' ');
    if (parts.length >= 3) {
      final castling = parts[2];
      _whiteKingSide = castling.contains('K');
      _whiteQueenSide = castling.contains('Q');
      _blackKingSide = castling.contains('k');
      _blackQueenSide = castling.contains('q');
    }
  }

  void _updateCastlingAnalysis() {
    try {
      _possibleCastlingRights = CastlingRightsDetector.analyzeCastlingRights(_currentFen);
      
      // Auto-disable impossible castling rights
      if (_possibleCastlingRights?.isValid == true) {
        if (!_possibleCastlingRights!.whiteKingSide) _whiteKingSide = false;
        if (!_possibleCastlingRights!.whiteQueenSide) _whiteQueenSide = false;
        if (!_possibleCastlingRights!.blackKingSide) _blackKingSide = false;
        if (!_possibleCastlingRights!.blackQueenSide) _blackQueenSide = false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error updating castling analysis: $e');
    }
  }

  /// Updates position object from FEN for immediate visual feedback
  void _updatePositionFromFen() {
    try {
      final setup = Setup.parseFen(_currentFen);
      _position = Position.setupPosition(Rule.chess, setup);
        } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Could not update position from FEN: $e');
      // Keep existing position if update fails
    }
  }

  // Edit mode switching
  void setDragMode() {
    _isDragMode = true;
    _isPlaceMode = false;
    _isRemoveMode = false;
    _selectedPiece = null;
    _selectedSquare = null;
    onStateChanged();
  }

  void setPlaceMode() {
    _isDragMode = false;
    _isPlaceMode = true;
    _isRemoveMode = false;
    _selectedSquare = null;
    onStateChanged();
  }

  void setRemoveMode() {
    _isDragMode = false;
    _isPlaceMode = false;
    _isRemoveMode = true;
    _selectedPiece = null;
    _selectedSquare = null;
    onStateChanged();
  }

  void selectPiece(String piece) {
    _selectedPiece = piece;
    onStateChanged();
  }

  void toggleBoardFlip() {
    _boardFlipped = !_boardFlipped;
    onStateChanged();
  }

  /// Main square interaction handler - routes to appropriate mode handler
  void onSquareTap(Square square) {
    if (kDebugMode) debugPrint('EditPosition: Square tapped: ${square.name}, mode: ${_isDragMode ? "drag" : _isPlaceMode ? "place" : "remove"}');
    
    try {
      if (_isDragMode) {
        _handleDragModeClick(square);
      } else if (_isRemoveMode) {
        _removePieceFromFen(square);
      } else if (_isPlaceMode && _selectedPiece != null) {
        _placePieceInFen(square, _selectedPiece!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error handling square tap: $e');
    }
  }

  /// Handles two-click drag mode: first click selects, second click moves
  void _handleDragModeClick(Square square) {
    if (_selectedSquare == null) {
      // First click - select piece if present
      if (hasPieceAt(square)) {
        _selectedSquare = square;
        onStateChanged();
        if (kDebugMode) debugPrint('EditPosition: Selected square ${square.name} with piece ${getPieceAtSquare(square)}');
      } else {
        if (kDebugMode) debugPrint('EditPosition: No piece at ${square.name} to select');
      }
    } else {
      // Second click - move or deselect
      if (_selectedSquare == square) {
        _selectedSquare = null;
        onStateChanged();
        if (kDebugMode) debugPrint('EditPosition: Deselected square ${square.name}');
      } else {
        if (kDebugMode) debugPrint('EditPosition: Moving piece from ${_selectedSquare!.name} to ${square.name}');
        _movePieceInFen(_selectedSquare!, square);
        _selectedSquare = null;
        onStateChanged();
      }
    }
  }

  bool hasPieceAt(Square square) {
    final piece = getPieceAtSquare(square);
    return piece != null && piece.isNotEmpty;
  }

  /// Extracts piece at square from FEN string representation
  String? getPieceAtSquare(Square square) {
    try {
      final boardPart = _currentFen.split(' ')[0];
      final ranks = boardPart.split('/');
      
      final rankIndex = 7 - square.rank.value; // Convert to FEN rank indexing
      final fileIndex = square.file.value;
      
      if (rankIndex < 0 || rankIndex >= 8 || fileIndex < 0 || fileIndex >= 8) {
        return null;
      }
      
      final rank = ranks[rankIndex];
      int currentFile = 0;
      
      for (int i = 0; i < rank.length; i++) {
        final char = rank[i];
        
        if ('12345678'.contains(char)) {
          // Handle empty squares notation (1-8)
          final emptySquares = int.parse(char);
          if (currentFile <= fileIndex && fileIndex < currentFile + emptySquares) {
            return null; // Square is empty
          }
          currentFile += emptySquares;
        } else {
          // Found a piece
          if (currentFile == fileIndex) {
            return char;
          }
          currentFile++;
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error getting piece at ${square.name}: $e');
      return null;
    }
  }

  /// Moves piece from one square to another with immediate visual update
  void _movePieceInFen(Square fromSquare, Square toSquare) {
    try {
      final piece = getPieceAtSquare(fromSquare);
      if (piece == null || piece.isEmpty) {
        if (kDebugMode) debugPrint('EditPosition: No piece at source square ${fromSquare.name}');
        return;
      }
      
      // Two-step process: remove from source, add to destination
      String newFen = _removePieceFromFenString(fromSquare, _currentFen);
      newFen = _placePieceInFenString(toSquare, piece, newFen);
      
      _currentFen = newFen;
      _updateCastlingAnalysis();
      
      if (kDebugMode) debugPrint('EditPosition: Moved $piece from ${fromSquare.name} to ${toSquare.name}');
      
      _updatePositionFromFen();
      onStateChanged();
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error moving piece: $e');
    }
  }

  void _removePieceFromFen(Square square) {
    try {
      final newFen = _removePieceFromFenString(square, _currentFen);
      _currentFen = newFen;
      _updateCastlingAnalysis();
      if (kDebugMode) debugPrint('EditPosition: Removed piece from ${square.name}');
      
      _updatePositionFromFen();
      onStateChanged();
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error removing piece: $e');
    }
  }

  void _placePieceInFen(Square square, String piece) {
    try {
      final newFen = _placePieceInFenString(square, piece, _currentFen);
      _currentFen = newFen;
      _updateCastlingAnalysis();
      if (kDebugMode) debugPrint('EditPosition: Placed $piece at ${square.name}');
      
      _updatePositionFromFen();
      onStateChanged();
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error placing piece: $e');
    }
  }

  String _removePieceFromFenString(Square square, String fen) {
    return _modifyFenSquare(square, '', fen);
  }

  String _placePieceInFenString(Square square, String piece, String fen) {
    return _modifyFenSquare(square, piece, fen);
  }

  /// Core FEN manipulation - modifies a specific square in the FEN string
  String _modifyFenSquare(Square square, String newPiece, String fen) {
    try {
      final parts = fen.split(' ');
      final boardPart = parts[0];
      final ranks = boardPart.split('/');
      
      final rankIndex = 7 - square.rank.value; // Convert to FEN indexing
      final fileIndex = square.file.value;
      
      if (rankIndex < 0 || rankIndex >= 8 || fileIndex < 0 || fileIndex >= 8) {
        return fen; // Invalid square, return unchanged
      }
      
      final newRank = _modifyRankString(ranks[rankIndex], fileIndex, newPiece);
      ranks[rankIndex] = newRank;
      
      parts[0] = ranks.join('/');
      return parts.join(' ');
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error modifying FEN square: $e');
      return fen;
    }
  }

  /// Modifies a single rank string in FEN notation
  /// Handles conversion between piece notation and empty square counts
  String _modifyRankString(String rank, int fileIndex, String newPiece) {
    // Convert FEN rank notation to square array
    final squares = List.filled(8, '');
    int currentFile = 0;
    
    for (int i = 0; i < rank.length; i++) {
      final char = rank[i];
      
      if ('12345678'.contains(char)) {
        // Handle empty squares
        final emptySquares = int.parse(char);
        for (int j = 0; j < emptySquares && currentFile < 8; j++) {
          squares[currentFile] = '';
          currentFile++;
        }
      } else {
        // Handle piece placement
        if (currentFile < 8) {
          squares[currentFile] = char;
          currentFile++;
        }
      }
    }
    
    // Modify the target square
    if (fileIndex >= 0 && fileIndex < 8) {
      squares[fileIndex] = newPiece;
    }
    
    // Convert back to FEN rank notation
    String result = '';
    int emptyCount = 0;
    
    for (int i = 0; i < 8; i++) {
      if (squares[i].isEmpty) {
        emptyCount++;
      } else {
        if (emptyCount > 0) {
          result += emptyCount.toString();
          emptyCount = 0;
        }
        result += squares[i];
      }
    }
    
    if (emptyCount > 0) {
      result += emptyCount.toString();
    }
    
    return result.isEmpty ? '8' : result;
  }

  // Game state management
  void changeTurn(Side newTurn) {
    try {
      final parts = _currentFen.split(' ');
      parts[1] = newTurn == Side.white ? 'w' : 'b';
      
      _currentFen = parts.join(' ');
      _updatePositionFromFen();
      onStateChanged();
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error changing turn: $e');
    }
  }

  // Castling rights management
  String _buildCastlingString() {
    String castling = '';
    if (_whiteKingSide) castling += 'K';
    if (_whiteQueenSide) castling += 'Q';
    if (_blackKingSide) castling += 'k';
    if (_blackQueenSide) castling += 'q';
    return castling.isEmpty ? '-' : castling;
  }

  /// Updates castling rights with validation against current piece positions
  void setCastlingRight(String rightType, bool value) {
    if (value) {
      // Validate that the castling right is actually possible
      final validation = CastlingRightsDetector.validateCastlingChange(
        fen: _currentFen,
        whiteKingSide: rightType == 'whiteKingSide' ? true : _whiteKingSide,
        whiteQueenSide: rightType == 'whiteQueenSide' ? true : _whiteQueenSide,
        blackKingSide: rightType == 'blackKingSide' ? true : _blackKingSide,
        blackQueenSide: rightType == 'blackQueenSide' ? true : _blackQueenSide,
      );
      
      if (!validation.isValid) {
        // Let UI handle error display
        return;
      }
    }
    
    switch (rightType) {
      case 'whiteKingSide': _whiteKingSide = value; break;
      case 'whiteQueenSide': _whiteQueenSide = value; break;
      case 'blackKingSide': _blackKingSide = value; break;
      case 'blackQueenSide': _blackQueenSide = value; break;
    }
    onStateChanged();
  }

  /// Automatically detects and sets valid castling rights based on piece positions
  void autoDetectCastlingRights() {
    try {
      final analysis = CastlingRightsDetector.analyzeCastlingRights(_currentFen);
      
      if (analysis.isValid) {
        _whiteKingSide = analysis.whiteKingSide;
        _whiteQueenSide = analysis.whiteQueenSide;
        _blackKingSide = analysis.blackKingSide;
        _blackQueenSide = analysis.blackQueenSide;
        _possibleCastlingRights = analysis;
        onStateChanged();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error auto-detecting castling rights: $e');
    }
  }

  // Board manipulation utilities
  void resetToStartingPosition() {
    _currentFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    _initializeCastlingRights(_currentFen);
    _updatePositionFromFen();
    onStateChanged();
  }

  void clearBoard() {
    _currentFen = '8/8/8/8/8/8/8/8 w - - 0 1';
    _initializeCastlingRights(_currentFen);
    _updatePositionFromFen();
    onStateChanged();
  }

  /// Rotates the board 180 degrees - useful for correcting orientation
  void flipBoard180() {
    try {
      if (kDebugMode) debugPrint('EditPosition: Flipping board 180 degrees');
      
      final parts = _currentFen.split(' ');
      final boardPart = parts[0];
      final ranks = boardPart.split('/');
      
      // Process ranks in reverse order and reverse each rank
      final flippedRanks = <String>[];
      
      for (int i = ranks.length - 1; i >= 0; i--) {
        final rank = ranks[i];
        String flippedRank = '';
        
        // Convert rank to square array
        final squares = List.filled(8, '');
        int currentFile = 0;
        
        for (int j = 0; j < rank.length; j++) {
          final char = rank[j];
          
          if ('12345678'.contains(char)) {
            final emptySquares = int.parse(char);
            for (int k = 0; k < emptySquares && currentFile < 8; k++) {
              squares[currentFile] = '';
              currentFile++;
            }
          } else {
            if (currentFile < 8) {
              squares[currentFile] = char;
              currentFile++;
            }
          }
        }
        
        // Reverse the squares in this rank
        final reversedSquares = squares.reversed.toList();
        
        // Convert back to FEN notation
        int emptyCount = 0;
        for (int j = 0; j < 8; j++) {
          if (reversedSquares[j].isEmpty) {
            emptyCount++;
          } else {
            if (emptyCount > 0) {
              flippedRank += emptyCount.toString();
              emptyCount = 0;
            }
            flippedRank += reversedSquares[j];
          }
        }
        
        if (emptyCount > 0) {
          flippedRank += emptyCount.toString();
        }
        
        flippedRanks.add(flippedRank.isEmpty ? '8' : flippedRank);
      }
      
      // Update FEN with flipped board
      parts[0] = flippedRanks.join('/');
      final newFen = parts.join(' ');
      
      _currentFen = newFen;
      _selectedSquare = null; // Clear selection after flip
      _updateCastlingAnalysis();
      _updatePositionFromFen();
      onStateChanged();
      
      if (kDebugMode) debugPrint('EditPosition: Board flip completed');
    } catch (e) {
      if (kDebugMode) debugPrint('EditPosition: Error flipping board: $e');
    }
  }

  /// Builds final FEN with all components for analysis
  String buildFinalFen() {
    try {
      final parts = _currentFen.split(' ');
      
      // Ensure all FEN components are present
      while (parts.length < 6) {
        parts.add('');
      }
      
      // Update castling rights with current selection
      parts[2] = _buildCastlingString();
      
      // Set reasonable defaults for analysis
      if (parts[1].isEmpty) parts[1] = 'w'; // Default to white to move
      if (parts[3].isEmpty) parts[3] = '-';  // No en passant
      if (parts[4].isEmpty) parts[4] = '0';  // Halfmove clock
      if (parts[5].isEmpty) parts[5] = '1';  // Fullmove number
      
      return parts.join(' ');
    } catch (e) {
      if (kDebugMode) debugPrint('Error building final FEN: $e');
      return _currentFen;
    }
  }

  void dispose() {
    // Clean up any resources if needed
  }
}