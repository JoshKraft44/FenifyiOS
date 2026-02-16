// test/test_configuration.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fenify/constants/app_constants.dart';

/// Test configuration and setup utilities
class TestConfiguration {
  static const Duration defaultTimeout = AppConstants.defaultTestTimeout;
  static const Duration shortTimeout = Duration(seconds: 5);
  static const Duration longTimeout = AppConstants.longTestTimeout;
  
  static void setupTestEnvironment() {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Configure test timeouts
    TestWidgetsFlutterBinding.ensureInitialized().setTimeout(defaultTimeout);
    
    // Mock platform channels
    _setupPlatformChannelMocks();
    
    // Configure test rendering
    _setupTestRendering();
  }
  
  static void _setupPlatformChannelMocks() {
    // Mock image picker
    const MethodChannel('plugins.flutter.io/image_picker')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'pickImage':
          return {
            'path': '/mock/image/path.jpg',
            'width': 1024.0,
            'height': 1024.0,
          };
        default:
          return null;
      }
    });
    
    // Mock path provider
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getApplicationDocumentsDirectory':
          return '/mock/documents';
        case 'getTemporaryDirectory':
          return '/mock/temp';
        default:
          return '/mock';
      }
    });
    
    // Mock chess ML channel
    const MethodChannel('chess_ml_channel')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'loadModel':
          return true;
        case 'processChessboard':
          return 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        case 'extractFeatures':
          return {'confidence': 0.95, 'pieces': []};
        case 'validateModel':
          return {'isValid': true, 'version': '1.0.0'};
        default:
          return null;
      }
    });
    
    // Mock audio channels for move sounds
    const MethodChannel('plugins.flutter.io/audio')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return true;
    });
  }
  
  static void _setupTestRendering() {
    // Configure test rendering properties
    debugDefaultTargetPlatformOverride = null;
  }
}