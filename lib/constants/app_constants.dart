/// Centralized application constants
/// Contains configuration values, timeouts, and other constant values.
class AppConstants {
  // Chess Board Configuration
  static const int boardSize = 8;
  static const int squareSize = 64;
  
  // Analysis Engine Configuration
  static const int maxInitRetries = 3;
  static const Duration initTimeout = Duration(seconds: 30);
  static const int defaultAnalysisDepth = 15;
  static const int maxAnalysisDepth = 22;
  
  // Testing Configuration
  static const Duration defaultTestTimeout = Duration(seconds: 30);
  static const Duration longTestTimeout = Duration(minutes: 2);
  
  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDelay = Duration(milliseconds: 500);
  
  // File and Storage
  static const String savedPositionsKey = 'saved_positions';
  static const int maxSavedPositions = 100;
  
  // Platform Channel Names
  static const String chessMLChannelName = 'com.joshuakraft.fenify/chess_ml';
  static const String imageProcessingChannelName = 'com.joshuakraft.fenify/image_processing';
  
  // Stockfish Configuration
  static const int stockfishHashSize = 128; // MB
  static const int stockfishThreads = 1;
  static const int multiPVLines = 3;
  
  // Prevent instantiation
  AppConstants._();
}