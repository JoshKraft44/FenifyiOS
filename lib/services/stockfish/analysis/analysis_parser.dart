import 'package:flutter/foundation.dart';

class AnalysisParser {
  /// Parse raw analysis data from Stockfish into a standardized format
  Map<String, dynamic> parseAnalysisData(Map<String, dynamic> data) {
    try {
      final fen = data['fen'] as String?;
      final analysisId = data['analysisId'];

      // Debug logging for turn tracking
      if (kDebugMode && fen != null) {
        final fenParts = fen.split(' ');
        final turn = fenParts.length > 1 ? fenParts[1] : 'unknown';
        debugPrint('DEBUG_PARSER: FEN=$fen, Turn=$turn, ID=$analysisId');
      }

      if (data.containsKey('invalid_position') && data['invalid_position'] == true) {
        final errorMessage = data['error'] as String? ?? 'Position is invalid';
        final result = {
          'evaluation': 0.0,
          'bestMove': '',
          'depth': 0,
          'nodes': 0,
          'pv': [],
          'multipv': [],
          'error': "ERROR: $errorMessage\n\nTo analyze this position:\n1. Tap \"Edit Position\" below\n2. Fix the position by adding/removing pieces\n3. Ensure both sides have exactly one king\n4. Return to analysis when position is valid",
          'invalid_position': true,
        };
        if (fen != null) result['fen'] = fen;
        if (analysisId != null) result['analysisId'] = analysisId;
        return result;
      }

      if (data.containsKey('error') && data['error'] == true) {
        throw Exception(data['message'] ?? 'Unknown analysis error');
      }

      final evaluationScore = (data['evaluation'] as num?)?.toDouble() ?? 0.0;
      final isMateScore = data['isMate'] as bool? ?? false;
      final mateInMoves = data['mateIn'] as int? ?? 0;
      final bestMove = data['bestMove'] as String? ?? '';
      final currentDepth = data['depth'] as int? ?? 0;

      final pvData = data['principalVariation'];
      final principalVariation = pvData is List ? pvData.cast<String>() : <String>[];

      final multiPVData = data['multiPV'];
      final multiEvalData = data['multiEval'];

      List<List<String>> multiPV = [];
      List<String> moveEvaluations = [];

      if (multiPVData is List && multiEvalData is List) {
        try {
          multiPV = multiPVData.map((pv) {
            if (pv is List) {
              return pv.cast<String>();
            }
            return <String>[];
          }).toList();

          moveEvaluations = multiEvalData.map((eval) {
            // Handle different types of evaluation data
            if (eval is num) {
              // Numeric evaluation (centipawns converted to pawns)
              final evalDouble = eval.toDouble();
              String sign = evalDouble >= 0 ? "+" : "";
              return "$sign${evalDouble.toStringAsFixed(2)}";
            } else if (eval is String) {
              // String evaluation (already formatted or mate notation)
              if (eval.startsWith('M')) {
                // Already formatted mate score (M1, M2, etc.)
                return eval;
              } else if (eval.contains('mate') || eval.contains('+') || eval.contains('-')) {
                // Already formatted evaluation 
                return eval;
              } else {
                // Try to parse as number
                final parsed = double.tryParse(eval);
                if (parsed != null) {
                  String sign = parsed >= 0 ? "+" : "";
                  return "$sign${parsed.toStringAsFixed(2)}";
                } else {
                  if (kDebugMode) debugPrint('Warning: Could not parse evaluation string: $eval');
                  return eval; // Return as-is if it can't be parsed
                }
              }
            } else {
              if (kDebugMode) debugPrint('Warning: Unexpected evaluation type: ${eval.runtimeType}, value: $eval');
              return "0.00";
            }
          }).toList();
        } catch (e) {
          if (kDebugMode) debugPrint('Error parsing multiPV data: $e');
          if (kDebugMode) debugPrint('multiPVData type: ${multiPVData.runtimeType}');
          if (kDebugMode) debugPrint('multiEvalData type: ${multiEvalData.runtimeType}');
          if (multiEvalData.isNotEmpty) {
            if (kDebugMode) debugPrint('First multiEval item: ${multiEvalData[0]} (type: ${multiEvalData[0].runtimeType})');
          }
          multiPV = [];
          moveEvaluations = [];
        }
      }

      final parsed = {
        'evaluation': evaluationScore,
        'isMate': isMateScore,
        'mateIn': mateInMoves,
        'bestMove': bestMove,
        'principalVariation': principalVariation,
        'multiPV': multiPV,
        'multiEval': moveEvaluations,
        'depth': currentDepth,
      };
      if (fen != null) parsed['fen'] = fen;
      if (analysisId != null) parsed['analysisId'] = analysisId;
      return parsed;
    } catch (e) {
      if (kDebugMode) debugPrint('Error in parseAnalysisData: $e');
      throw Exception('Failed to parse analysis data: $e');
    }
  }

  /// Format a move for display
  String formatMove(String move) {
    if (move.isEmpty || move.length < 4) return move;
    try {
      return "${move.substring(0, 2)}-${move.substring(2, 4)}${move.length > 4 ? move.substring(4) : ''}";
    } catch (e) {
      return move;
    }
  }

  /// Get evaluation text for display
  String getEvaluationText(double evaluation, bool isMate, int mateInMoves) {
    if (isMate) {
      return "Mate in ${mateInMoves.abs()} for ${mateInMoves > 0 ? 'White' : 'Black'}";
    } else {
      String scoreSign = evaluation >= 0 ? "+" : "";
      return "$scoreSign${evaluation.toStringAsFixed(2)}";
    }
  }
}