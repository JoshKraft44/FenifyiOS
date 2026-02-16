import 'dart:io' as io;
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:dartchess/dartchess.dart';
import '../../constants/app_constants.dart';
import '../../services/dartchess_validation_service.dart';
import 'opencv_board_detector.dart';
import 'debug_exporter.dart';

/// Handles chess position recognition from images using TensorFlow Lite
/// Processes images through native Android/iOS implementations for optimal performance
class ImageProcessor {
  static const int BOARD_SIZE = AppConstants.boardSize;
  static const int SQUARE_SIZE = AppConstants.squareSize;
  static const int CHANNELS = 3;

  bool _isInitialized = false;
  bool _modelLoaded = false;
  static const MethodChannel _channel = MethodChannel('chess_ml_channel');

  // Debug export base URL for HTTP upload to a local server.
  // Local file saving always enabled via DebugExporter.enableLocalSave.
  // when set in debug mode, crops or inputs may be POSTed
  // to a local server for inspection / debug_crop_server.dart.
  static String? _debugExportBaseUrl;
  static set debugExportBaseUrl(String? url) {
    _debugExportBaseUrl = url;
    DebugExporter.baseUrl = url;
  }

  static String? get debugExportBaseUrl => _debugExportBaseUrl;

  /// Maps TensorFlow Lite model predictions to chess piece notation
  static const List<String> _pieceMapping = [
    'b',  // 0 = bB (black bishop)
    'k',  // 1 = bK (black king)
    'n',  // 2 = bN (black knight)
    'p',  // 3 = bP (black pawn)
    'q',  // 4 = bQ (black queen)
    'r',  // 5 = bR (black rook)
    '',   // 6 = empty square
    'B',  // 7 = wB (white bishop)
    'K',  // 8 = wK (white king)
    'N',  // 9 = wN (white knight)
    'P',  // 10 = wP (white pawn)
    'Q',  // 11 = wQ (white queen)
    'R',  // 12 = wR (white rook)
  ];

  /// Initializes the TensorFlow Lite model and native processing pipeline
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) debugPrint("ImageProcessor: Initializing ML model...");
      try {
        if (kDebugMode) debugPrint("ImageProcessor: Calling loadModel method channel...");
        
        // Test method channel connectivity first
        try {
          final testResult = await _channel.invokeMethod('ping');
          if (kDebugMode) debugPrint("ImageProcessor: Method channel test - ping result: $testResult");
        } catch (testError) {
          if (kDebugMode) debugPrint("ImageProcessor: Method channel test failed: $testError");
        }
        
        final result = await _channel.invokeMethod('loadModel', {
          'modelPath': 'assets/piece_classifier.tflite',
          'labelPath': 'assets/piece_labels.txt',
        });

        if (kDebugMode) debugPrint("ImageProcessor: Method channel returned: $result (type: ${result.runtimeType})");
        if (result == true) {
          _modelLoaded = true;
          if (kDebugMode) debugPrint('Chess piece classifier model loaded successfully');
        } else {
          _modelLoaded = false;
          if (kDebugMode) debugPrint('Failed to load ML model - result was: $result');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ML model loading error: $e');
          debugPrint('ML model loading error type: ${e.runtimeType}');
          debugPrint('ML model loading error toString: ${e.toString()}');
        }
        _modelLoaded = false;
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('ML model not found: $e');
      _modelLoaded = false;
      _isInitialized = true;
    }
  }

  /// Main entry point for processing chess board images from file system
  /// Returns FEN notation with validation via DartChess
  Future<String> processImageFile(io.File imageFile) async {
    if (!_isInitialized) {
      await init();
    }

    if (_modelLoaded) {
      if (kDebugMode) debugPrint('Using model with DartChess validation');
      return await _processWithNativeKotlinPipeline(imageFile);
    } else {
      if (kDebugMode) debugPrint('TensorFlow Lite model not available - cannot process image');
      return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    }
  }

  /// Development utility to extract individual squares for ML model debugging
  Future<List<String>> extractSquaresForDebugging(io.File imageFile) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      if (kDebugMode) debugPrint('Extracting squares from image for debugging: ${imageFile.path}');
      
      final imageBytes = await imageFile.readAsBytes();
      final result = await _channel.invokeMethod('extractSquares', {
        'imageBytes': imageBytes,
      });
      
      if (result != null && result is Map && result['success'] == true) {
        final squaresPaths = List<String>.from(result['squaresPaths'] ?? []);
        if (kDebugMode) {
          debugPrint('Successfully extracted ${squaresPaths.length} squares');
          debugPrint('Squares saved to: ${squaresPaths.isNotEmpty ? squaresPaths.first.split('/').take(squaresPaths.first.split('/').length - 1).join('/') : 'unknown'}');
        }
        return squaresPaths;
      } else {
        if (kDebugMode) debugPrint('Failed to extract squares: ${result?['error'] ?? 'Unknown error'}');
        return [];
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error extracting squares: $e');
      return [];
    }
  }

  /// Processes image using optimized native Android/iOS pipeline with OpenCV enhancement
  /// Includes automatic board orientation detection and chess rule validation
  Future<String> _processWithNativeKotlinPipeline(io.File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      // Export original for debugging
      if (kDebugMode && DebugExporter.enableLocalSave) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        unawaited(DebugExporter.exportBytes(imageBytes, name: 'original_$ts.png'));
      }

      // OpenCV enhancement - always attempt robust board detection regardless of aspect ratio
      Uint8List finalImageBytes = imageBytes;
      bool opencvUsed = false;
      try {
        final enhancedImageBytes = await OpenCVBoardDetector.detectAndCropChessboard(imageBytes);
        if (enhancedImageBytes != null) {
          finalImageBytes = enhancedImageBytes;
          opencvUsed = true;
          if (kDebugMode && DebugExporter.enableLocalSave) {
            final ts = DateTime.now().millisecondsSinceEpoch;
            unawaited(DebugExporter.exportBytes(finalImageBytes,
                name: 'opencv_crop_$ts.png'));
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('OpenCV processing failed, using original: $e');
        }
      }

      if (kDebugMode) {
        print(
            'OpenCV enhancement attempt: ${opencvUsed ? "APPLIED" : "SKIPPED (fallback to original)"}');
        if (!opencvUsed && DebugExporter.enableLocalSave) {
          final ts = DateTime.now().millisecondsSinceEpoch;
          unawaited(DebugExporter.exportBytes(finalImageBytes,
              name: 'final_original_$ts.png'));
        }
      }

      // Delegate to native implementation for optimal performance
      final fen = await _channel.invokeMethod('processChessboard', {
        'imageBytes': finalImageBytes,
      });

      if (fen != null && fen is String && fen.isNotEmpty) {
        if (kDebugMode) debugPrint('Generated FEN: $fen');
        
        // Apply heuristic-based board orientation correction
        final orientedFen = _applyAutoOrientation(fen);
        if (kDebugMode) debugPrint('Auto-oriented FEN: $orientedFen');
        
        // Validate against chess rules using DartChess engine
        final validationResult = await _validateWithDartChess(orientedFen);
        if (kDebugMode) debugPrint('DartChess validation result: ${validationResult.isValid}');
        
        return validationResult.isValid 
            ? validationResult.cleanFen! 
            : '${orientedFen} INVALID_POSITION';
        
      }

      if (kDebugMode) debugPrint('Failed to generate position');
      return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    } catch (e) {
      if (kDebugMode) debugPrint('Error: $e');
      return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    }
  }

  /// Validates FEN using DartChess engine with positon analysis
  Future<ValidationResult> _validateWithDartChess(String fen) async {
    try {
      if (kDebugMode) debugPrint('FEN validation with DartChess: $fen');
      
      final result = DartChessValidationService.validateFen(fen);
      
      if (result.isValid) {
        if (kDebugMode) {
          debugPrint('SUCCESS: DartChess validation successful');
          debugPrint('   Position analysis: ${result.analysis?.statusDescription}');
          debugPrint('   Material balance: ${result.analysis?.materialDescription}');
          debugPrint('   Legal moves: ${result.analysis?.legalMovesCount}');
        }
        
        // Log important position characteristics for debugging
        if (result.analysis?.isCheck == true) {
          if (kDebugMode) debugPrint('   WARNING: Position has check');
        }
        if (result.analysis?.isGameOver == true) {
          if (kDebugMode) debugPrint('   GAME_OVER: ${result.analysis?.outcome}');
        }
        
        return result;
      } else {
        if (kDebugMode) {
          debugPrint('ERROR: DartChess validation failed: ${result.errorMessage}');
          debugPrint('   Returning FEN with invalid flag for user editing');
        }
        return result;
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('ERROR: Error during DartChess validation: $e');
      return ValidationResult.invalid('DartChess validation error: $e');
    }
  }

  /// Automatically detects and corrects board orientation using piece placement heuristics
  /// Common issue: cameras often capture boards from different angles
  String _applyAutoOrientation(String fen) {
    try {
      final parts = fen.split(' ');
      if (parts.isEmpty) return fen;
      
      final boardPosition = parts[0];
      
      // Convert to internal representation for analysis
      final predictions = _fenToPredictions(boardPosition);
      if (predictions.length != 64) {
        if (kDebugMode) debugPrint('Invalid predictions length: ${predictions.length}');
        return fen;
      }
      
      // Use chess logic to determine correct orientation
      final orientation = _determineCorrectOrientation(predictions);
      if (kDebugMode) debugPrint('Detected board orientation: $orientation');
      
      if (orientation == 'flipped') {
        // Flip board 180 degrees and reconstruct FEN
        final flippedPredictions = _flipPredictions(predictions);
        final flippedBoardPosition = _predictionsToBoardPosition(flippedPredictions);
        
        parts[0] = flippedBoardPosition;
        return parts.join(' ');
      }
      
      return fen;
    } catch (e) {
      if (kDebugMode) debugPrint('Error in auto-orientation: $e');
      return fen;
    }
  }

  List<int> _fenToPredictions(String boardPosition) {
    final predictions = List.filled(64, 6); // Default to empty (index 6)
    final ranks = boardPosition.split('/');
    
    if (ranks.length != 8) return predictions;
    
    int squareIndex = 0;
    
    for (final rank in ranks) {
      for (int i = 0; i < rank.length && squareIndex < 64; i++) {
        final char = rank[i];
        
        if ('12345678'.contains(char)) {
          // Handle empty squares notation
          final emptyCount = int.parse(char);
          for (int j = 0; j < emptyCount && squareIndex < 64; j++) {
            predictions[squareIndex] = 6; // empty
            squareIndex++;
          }
        } else {
          // Map piece character to prediction index
          final predictionIndex = _pieceCharToPredictionIndex(char);
          predictions[squareIndex] = predictionIndex;
          squareIndex++;
        }
      }
    }
    
    return predictions;
  }

  int _pieceCharToPredictionIndex(String piece) {
    for (int i = 0; i < _pieceMapping.length; i++) {
      if (_pieceMapping[i] == piece) {
        return i;
      }
    }
    return 6; // Default to empty if piece not recognized
  }

  String _predictionsToBoardPosition(List<int> predictions) {
    final ranks = <String>[];
    
    for (int rank = 0; rank < 8; rank++) {
      String rankStr = '';
      int emptyCount = 0;
      
      for (int file = 0; file < 8; file++) {
        final index = rank * 8 + file;
        if (index >= predictions.length) break;
        
        final prediction = predictions[index].clamp(0, _pieceMapping.length - 1);
        final piece = _pieceMapping[prediction];
        
        if (piece.isEmpty) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rankStr += emptyCount.toString();
            emptyCount = 0;
          }
          rankStr += piece;
        }
      }
      
      if (emptyCount > 0) {
        rankStr += emptyCount.toString();
      }
      
      ranks.add(rankStr);
    }
    
    return ranks.join('/');
  }

  /// Determine if board is upside down
  /// Analyzes typical piece placement patterns
  String _determineCorrectOrientation(List<int> predictions) {
    final board = List.generate(8, (_) => List.filled(8, 0));
    
    for (int i = 0; i < predictions.length && i < 64; i++) {
      final row = i ~/ 8;
      final col = i % 8;
      board[row][col] = predictions[i];
    }
    
    // Score both orientations using chess placement logic
    final orientationScores = <String, double>{
      'normal': _scoreOrientation(board, false),
      'flipped': _scoreOrientation(board, true),
    };
    
    if (kDebugMode) debugPrint('Orientation scores: $orientationScores');
    
    return orientationScores['normal']! >= orientationScores['flipped']! 
        ? 'normal' 
        : 'flipped';
  }

  /// Scores board orientation based on typical chess piece placement patterns
  double _scoreOrientation(List<List<int>> board, bool flipped) {
    double score = 0.0;
    
    final testBoard = flipped ? _flipBoard(board) : board;
    
    // Pawn placement analysis - strongest heuristic
    // White pawns should be closer to bottom, black pawns to top
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = testBoard[row][col];
        
        if (piece == 10) { // White pawn
          score += (7 - row) * 0.5; // Prefer bottom half
          if (row >= 4 && row <= 7) score += 2.0; // Reasonable pawn ranks
          if (row == 0) score -= 5.0; // Penalty for impossible placement
        }
        
        if (piece == 3) { // Black pawn
          score += row * 0.5; // Prefer top half
          if (row >= 0 && row <= 3) score += 2.0; // Reasonable pawn ranks
          if (row == 7) score -= 5.0; // Penalty for impossible placement
        }
      }
    }
    
    // Back rank piece analysis
    for (int col = 0; col < 8; col++) {
      final bottomPiece = testBoard[7][col];
      final topPiece = testBoard[0][col];
      
      // White major pieces prefer bottom rank
      if ([7, 8, 9, 11, 12].contains(bottomPiece)) {
        score += 3.0;
      }
      
      // Black major pieces prefer top rank
      if ([0, 1, 2, 4, 5].contains(topPiece)) {
        score += 3.0;
      }
      
      // Penalty for inverted arrangement
      if ([0, 1, 2, 4, 5].contains(bottomPiece)) {
        score -= 2.0;
      }
      if ([7, 8, 9, 11, 12].contains(topPiece)) {
        score -= 2.0;
      }
    }
    
    // King placement preferences
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = testBoard[row][col];
        
        if (piece == 8) { // White king
          score += (7 - row) * 0.3; // Prefer bottom half
          if (row >= 6) score += 1.5; // Back rank bonus
        }
        
        if (piece == 1) { // Black king
          score += row * 0.3; // Prefer top half
          if (row <= 1) score += 1.5; // Back rank bonus
        }
      }
    }
    
    return score;
  }

  List<List<int>> _flipBoard(List<List<int>> board) {
    final flipped = List.generate(8, (_) => List.filled(8, 0));
    
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        flipped[7 - row][7 - col] = board[row][col];
      }
    }
    
    return flipped;
  }

  List<int> _flipPredictions(List<int> predictions) {
    final flipped = List.filled(64, 0);
    
    for (int i = 0; i < 64; i++) {
      final row = i ~/ 8;
      final col = i % 8;
      final flippedIndex = (7 - row) * 8 + (7 - col);
      flipped[flippedIndex] = predictions[i];
    }
    
    return flipped;
  }

  /// Determines if an image likely needs cropping improvement
  /// Analyzes aspect ratio and content to decide if OpenCV should be applied
  Future<bool> _imageNeedsCropping(Uint8List imageBytes) async {
    try {
      // Decode image to check dimensions
      final image = img.decodeImage(imageBytes);
      if (image == null) return false;
      
      final width = image.width;
      final height = image.height;
      final aspectRatio = width / height;
      
      if (kDebugMode) {
        print('Image analysis: ${width}x$height, aspect ratio: ${aspectRatio.toStringAsFixed(2)}');
      }
      
      // If image is already roughly square (good for chess boards), likely doesn't need improvement
      if (aspectRatio > 0.8 && aspectRatio < 1.25) {
        if (kDebugMode) print('Image is already roughly square - skipping OpenCV');
        return false;
      }
      
      // If image is very wide or very tall, likely needs cropping
      if (aspectRatio < 0.5 || aspectRatio > 2.0) {
        if (kDebugMode) print('Image has extreme aspect ratio - applying OpenCV');
        return true;
      }
      
      // For vertical screenshots (common case), apply OpenCV if board might be small in frame
      if (aspectRatio < 0.8) {
        // Taller than wide (vertical screenshot)
        // Check if the image seems to have a lot of extra content
        // Simple heuristic: if height is much larger than width, likely has extra UI elements
        if (height > width * 1.5) {
          if (kDebugMode) print('Tall vertical image - likely needs cropping');
          return true;
        }
      }
      
      if (kDebugMode) print('Image seems adequately cropped - skipping OpenCV');
      return false;
      
    } catch (e) {
      if (kDebugMode) print('Error analyzing image for cropping needs: $e');
      return false; // If we can't analyze, don't risk breaking good images
    }
  }

  /// Processes raw image bytes - delegates to native implementation for performance
  Future<String> processImage(Uint8List imageBytes) async {
    if (!_isInitialized) {
      if (kDebugMode)
        debugPrint('ImageProcessor: Initializing before processing...');
      await init();
      if (kDebugMode)
        debugPrint(
            'ImageProcessor: Initialization completed, modelLoaded: $_modelLoaded');
    }

    try {
      if (kDebugMode) debugPrint('Converting bytes to file for processing...');
      
      // Create temporary file for native processing
      final tempDir = io.Directory.systemTemp;
      final tempFile = io.File(
          '${tempDir.path}/temp_chess_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);
      
      final result = await _processWithNativeKotlinPipeline(tempFile);
      
      // Clean up temporary file
      try {
        await tempFile.delete();
      } catch (e) {
        if (kDebugMode) debugPrint('Could not delete temp file: $e');
      }

      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('Error processing image: $e');
      return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    }
  }

  /// Processes Flutter UI Image objects
  Future<String> processUIImage(ui.Image uiImage) async {
    final bytes = await _uiImageToBytes(uiImage);
    return processImage(bytes);
  }

  Future<Uint8List> _uiImageToBytes(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Clean up TensorFlow Lite resources
  Future<void> dispose() async {
    if (_modelLoaded) {
      try {
        await _channel.invokeMethod('disposeModel');
        _modelLoaded = false;
      } catch (e) {
        if (kDebugMode) debugPrint('Error disposing ML model: $e');
      }
    }
  }
}
