/// Centralized exception handling
/// Provides standardized error types and consistent error handling patterns.

/// Base exception class for all app-specific exceptions.
/// Provides structured error information with optional error codes and original error context.
class AppException implements Exception {
  /// Human-readable error message
  final String message;
  
  /// Optional error code for categorization
  final String? code;
  
  /// Original error that caused this exception (for debugging)
  final dynamic originalError;
  
  /// Stack trace from the original error (if available)
  final StackTrace? stackTrace;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AppException: $message');
    if (code != null) {
      buffer.write(' (Code: $code)');
    }
    if (originalError != null) {
      buffer.write(' | Original: $originalError');
    }
    return buffer.toString();
  }
}

/// Exception thrown when FEN validation fails
class ValidationException extends AppException {
  ValidationException(String message, {dynamic originalError, StackTrace? stackTrace})
      : super(
          message,
          code: 'VALIDATION_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when platform-specific operations fail
class PlatformException extends AppException {
  PlatformException(String message, {dynamic originalError, StackTrace? stackTrace})
      : super(
          message,
          code: 'PLATFORM_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when Stockfish engine operations fail
class EngineException extends AppException {
  EngineException(String message, {dynamic originalError, StackTrace? stackTrace})
      : super(
          message,
          code: 'ENGINE_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when storage operations fail
class StorageException extends AppException {
  StorageException(String message, {dynamic originalError, StackTrace? stackTrace})
      : super(
          message,
          code: 'STORAGE_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when image processing operations fail
class ImageProcessingException extends AppException {
  ImageProcessingException(String message, {dynamic originalError, StackTrace? stackTrace})
      : super(
          message,
          code: 'IMAGE_PROCESSING_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when network operations fail
class NetworkException extends AppException {
  NetworkException(String message, {dynamic originalError, StackTrace? stackTrace})
      : super(
          message,
          code: 'NETWORK_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exception thrown when initialization fails
class InitializationException extends AppException {
  InitializationException(String message, {dynamic originalError, StackTrace? stackTrace})
      : super(
          message,
          code: 'INITIALIZATION_ERROR',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}