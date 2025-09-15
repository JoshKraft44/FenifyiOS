import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';

class ImageProcessorPyTorch {
  static const MethodChannel _channel = MethodChannel('chess_ml_plugin');
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Loading PyTorch model...');
      
      final dynamic result = await _channel.invokeMethod('loadPyTorchModel');
      
      if (result == true) {
        _isInitialized = true;
        if (kDebugMode) debugPrint('ImageProcessorPyTorch: PyTorch model loaded successfully');
      } else {
        if (kDebugMode) debugPrint('ImageProcessorPyTorch: Model loading failed with result: $result');
        throw Exception('Failed to load PyTorch model: $result');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Failed to load PyTorch model: $e');
      rethrow;
    }
  }

  Future<String> processImageFile(File imageFile) async {
    if (!_isInitialized) {
      throw Exception('PyTorch processor not initialized. Call init() first.');
    }

    try {
      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Processing image file: ${imageFile.path}');

      // Read image file as bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Image size: ${imageBytes.length} bytes');

      // Process image using PyTorch model
      final String fen = await _channel.invokeMethod('processChessboardPyTorch', {
        'imageBytes': imageBytes,
      });

      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Generated FEN: $fen');
      
      return fen;
    } catch (e) {
      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Error processing image: $e');
      rethrow;
    }
  }

  Future<String> processImageBytes(Uint8List imageBytes) async {
    if (!_isInitialized) {
      throw Exception('PyTorch processor not initialized. Call init() first.');
    }

    try {
      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Processing image bytes, size: ${imageBytes.length}');

      // Process image using PyTorch model
      final String fen = await _channel.invokeMethod('processChessboardPyTorch', {
        'imageBytes': imageBytes,
      });

      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Generated FEN: $fen');
      
      return fen;
    } catch (e) {
      if (kDebugMode) debugPrint('ImageProcessorPyTorch: Error processing image bytes: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;

  Future<Map<String, dynamic>> testAvailability() async {
    try {
      final result = await _channel.invokeMethod('testPyTorchAvailability');
      if (kDebugMode) debugPrint('PyTorch availability test result: $result');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      if (kDebugMode) debugPrint('PyTorch availability test failed: $e');
      return {'error': e.toString()};
    }
  }
}