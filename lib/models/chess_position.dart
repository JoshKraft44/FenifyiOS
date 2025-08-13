import 'package:dartchess/dartchess.dart';
import '../services/dartchess_validation_service.dart';

/// ChessPosition model using DartChess ^0.9.0
class ChessPosition {
  final String id;
  final String name;
  final String fen;
  final DateTime date;
  final PositionAnalysis? analysis;

  ChessPosition({
    required this.id,
    required this.name,
    required this.fen,
    required this.date,
    this.analysis,
  });

  /// Create a ChessPosition 
  factory ChessPosition.fromFen({
    required String name,
    required String fen,
    String? id,
    DateTime? date,
  }) {
    try {
      // Validate the FEN using DartChess service
      final validationResult = DartChessValidationService.validateFen(fen);
      
      if (!validationResult.isValid) {
        throw Exception('Invalid FEN: ${validationResult.errorMessage}');
      }
      
      return ChessPosition(
        id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        fen: validationResult.cleanFen!,
        date: date ?? DateTime.now(),
        analysis: validationResult.analysis,
      );
    } catch (e) {
      throw Exception('Failed to create ChessPosition: $e');
    }
  }

  /// Create a ChessPosition with lenient validation (allows some invalid positions for editing)
  factory ChessPosition.fromFenLenient({
    required String name,
    required String fen,
    String? id,
    DateTime? date,
  }) {
    try {
      // Try validation, but allow creation even if validation fails
      final validationResult = DartChessValidationService.validateFen(fen);
      
      return ChessPosition(
        id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        fen: validationResult.isValid ? validationResult.cleanFen! : fen,
        date: date ?? DateTime.now(),
        analysis: validationResult.analysis,
      );
    } catch (e) {
      // If validation completely fails, create with original FEN
      return ChessPosition(
        id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        fen: fen,
        date: date ?? DateTime.now(),
        analysis: null,
      );
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fen': fen,
      'date': date.toIso8601String(),
      'analysis': analysis?.toJson(),
    };
  }

  /// Create from JSON
  factory ChessPosition.fromJson(Map<String, dynamic> json) {
    return ChessPosition(
      id: json['id'] as String,
      name: json['name'] as String,
      fen: json['fen'] as String,
      date: DateTime.parse(json['date'] as String),
      analysis: json['analysis'] != null 
          ? PositionAnalysisJson._fromJson(json['analysis'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Validate the current position
  bool get isValid {
    try {
      final result = DartChessValidationService.validateFen(fen);
      return result.isValid;
    } catch (e) {
      return false;
    }
  }

  /// Get validation errors if any
  String? get validationError {
    try {
      final result = DartChessValidationService.validateFen(fen);
      return result.isValid ? null : result.errorMessage;
    } catch (e) {
      return 'Validation error: $e';
    }
  }

  /// Get the dartchess Position object
  Position? get position {
    try {
      final setup = Setup.parseFen(fen);
      if (setup == null) return null;
      return Position.setupPosition(Rule.chess, setup);
    } catch (e) {
      return null;
    }
  }

  /// Get the dartchess Setup object
  Setup? get setup {
    try {
      return Setup.parseFen(fen);
    } catch (e) {
      return null;
    }
  }

  /// Get current analysis or generate new analysis
  PositionAnalysis? get currentAnalysis {
    if (analysis != null) return analysis;
    
    try {
      final result = DartChessValidationService.validateFen(fen);
      return result.analysis;
    } catch (e) {
      return null;
    }
  }

  /// Create a copy with modified properties
  ChessPosition copyWith({
    String? id,
    String? name,
    String? fen,
    DateTime? date,
    PositionAnalysis? analysis,
  }) {
    return ChessPosition(
      id: id ?? this.id,
      name: name ?? this.name,
      fen: fen ?? this.fen,
      date: date ?? this.date,
      analysis: analysis ?? this.analysis,
    );
  }


  /// Helper method to build castling rights string
  static String _buildCastlingString(Set<String> rights) {
    if (rights.isEmpty) return '-';
    
    final ordered = <String>[];
    if (rights.contains('K')) ordered.add('K');
    if (rights.contains('Q')) ordered.add('Q');
    if (rights.contains('k')) ordered.add('k');
    if (rights.contains('q')) ordered.add('q');
    
    return ordered.join();
  }

  /// Create a new position with modified turn
  ChessPosition withTurn(Side turn) {
    try {
      final parts = fen.split(' ');
      if (parts.length < 2) {
        throw Exception('Invalid FEN format');
      }
      
      parts[1] = turn == Side.white ? 'w' : 'b';
      final newFen = parts.join(' ');
      
      // Validate the new position
      final validationResult = DartChessValidationService.validateFen(newFen);
      if (!validationResult.isValid) {
        throw Exception('Invalid position after turn change: ${validationResult.errorMessage}');
      }
      
      return copyWith(
        fen: validationResult.cleanFen!,
        analysis: validationResult.analysis,
      );
    } catch (e) {
      throw Exception('Failed to change turn: $e');
    }
  }

  /// Create a new position with modified castling rights
  ChessPosition withCastlingRights({
    required bool whiteKingSide,
    required bool whiteQueenSide,
    required bool blackKingSide,
    required bool blackQueenSide,
  }) {
    try {
      final parts = fen.split(' ');
      if (parts.length < 3) {
        throw Exception('Invalid FEN format');
      }
      
      final rights = <String>{};
      if (whiteKingSide) rights.add('K');
      if (whiteQueenSide) rights.add('Q');
      if (blackKingSide) rights.add('k');
      if (blackQueenSide) rights.add('q');
      
      parts[2] = _buildCastlingString(rights);
      final newFen = parts.join(' ');
      
      // Validate the new position
      final validationResult = DartChessValidationService.validateFen(newFen);
      if (!validationResult.isValid) {
        throw Exception('Invalid position after castling change: ${validationResult.errorMessage}');
      }
      
      return copyWith(
        fen: validationResult.cleanFen!,
        analysis: validationResult.analysis,
      );
    } catch (e) {
      throw Exception('Failed to change castling rights: $e');
    }
  }

  /// Get formatted description of the position
  String get description {
    final pos = position;
    if (pos == null) return 'Invalid position';
    
    final turn = pos.turn == Side.white ? 'White' : 'Black';
    final moveNumber = _extractFullmoveNumber(fen);
    
    if (pos.isCheckmate) {
      return 'Checkmate - ${turn == 'White' ? 'Black' : 'White'} wins (Move $moveNumber)';
    } else if (pos.isStalemate) {
      return 'Stalemate (Move $moveNumber)';
    } else if (pos.isCheck) {
      return '$turn to move - In check (Move $moveNumber)';
    } else {
      return '$turn to move (Move $moveNumber)';
    }
  }

  /// Get castling rights as a formatted string
  String get castlingRightsDescription {
    final parts = fen.split(' ');
    if (parts.length < 3) return 'Unknown';
    
    final castlingStr = parts[2];
    if (castlingStr == '-') return 'No castling available';
    
    final rights = <String>[];
    if (castlingStr.contains('K')) rights.add('White king-side');
    if (castlingStr.contains('Q')) rights.add('White queen-side');
    if (castlingStr.contains('k')) rights.add('Black king-side');
    if (castlingStr.contains('q')) rights.add('Black queen-side');
    
    return rights.join(', ');
  }


  /// Get material balance description
  String get materialBalanceDescription {
    final analysis = currentAnalysis;
    if (analysis == null) return 'Unknown';
    
    return analysis.materialDescription;
  }

  /// Check if position has specific characteristics
  bool get isStartingPosition {
    return fen.startsWith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR');
  }


  bool get isKingAndPawnEndgame {
    final pos = position;
    if (pos == null) return false;
    
    int totalPieces = 0;
    int totalKings = 0;
    int totalPawns = 0;
    
    for (int file = 0; file < 8; file++) {
      for (int rank = 0; rank < 8; rank++) {
        final square = Square.fromCoords(File.values[file], Rank.values[rank]);
        final piece = pos.board.pieceAt(square);
        if (piece != null) {
          totalPieces++;
          if (piece.role == Role.king) totalKings++;
          if (piece.role == Role.pawn) totalPawns++;
        }
      }
    }
    
    return totalPieces == totalKings + totalPawns && totalKings == 2;
  }

  /// Helper method to extract fullmove number from FEN
  int _extractFullmoveNumber(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 6) return 1;
    return int.tryParse(parts[5]) ?? 1;
  }

  @override
  String toString() {
    return 'ChessPosition(id: $id, name: $name, fen: $fen, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChessPosition &&
        other.id == id &&
        other.name == name &&
        other.fen == fen &&
        other.date == date;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, fen, date);
  }
}

/// Extension for PositionAnalysis to add JSON serialization
extension PositionAnalysisJson on PositionAnalysis {
  Map<String, dynamic> toJson() {
    return {
      'isCheck': isCheck,
      'isCheckmate': isCheckmate,
      'isStalemate': isStalemate,
      'isInsufficientMaterial': isInsufficientMaterial,
      'isGameOver': isGameOver,
      'outcome': outcome?.toString(),
      'legalMovesCount': legalMovesCount,
      'materialBalance': materialBalance,
    };
  }

  static PositionAnalysis _fromJson(Map<String, dynamic> json) {
    return PositionAnalysis(
      isCheck: json['isCheck'] as bool,
      isCheckmate: json['isCheckmate'] as bool,
      isStalemate: json['isStalemate'] as bool,
      isInsufficientMaterial: json['isInsufficientMaterial'] as bool,
      isGameOver: json['isGameOver'] as bool,
      outcome: json['outcome'] != null ? _parseOutcome(json['outcome'] as String) : null,
      legalMovesCount: json['legalMovesCount'] as int,
      materialBalance: json['materialBalance'] as int,
    );
  }

  static Outcome? _parseOutcome(String outcomeStr) {
    switch (outcomeStr) {
      case 'Outcome.whiteWins': return Outcome.whiteWins;
      case 'Outcome.blackWins': return Outcome.blackWins;
      case 'Outcome.draw': return Outcome.draw;
      default: return null;
    }
  }

}