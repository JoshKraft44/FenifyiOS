import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as services;
import 'app_exceptions.dart';

/// Centralized error handler
/// Provides consistent logging, reporting, and user-friendly error messages.
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Handles and logs errors, converting them to appropriate AppExceptions
  AppException handleError(dynamic error, StackTrace? stackTrace, {String? context}) {
    // Log the error for debugging
    _logError(error, stackTrace, context);
    
    // Convert to appropriate AppException
    return _convertToAppException(error, stackTrace);
  }

  /// Handles platform channel errors specifically
  AppException handlePlatformError(services.PlatformException error, {String? context}) {
    final message = _getPlatformErrorMessage(error);
    _logError(error, null, context);
    
    return PlatformException(
      message, 
      originalError: error,
    );
  }

  /// Handles validation errors with context
  AppException handleValidationError(dynamic error, StackTrace? stackTrace, {String? context}) {
    final message = _getValidationErrorMessage(error);
    _logError(error, stackTrace, context);
    
    return ValidationException(
      message,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handles engine-related errors
  AppException handleEngineError(dynamic error, StackTrace? stackTrace, {String? context}) {
    final message = _getEngineErrorMessage(error);
    _logError(error, stackTrace, context);
    
    return EngineException(
      message,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handles storage-related errors
  AppException handleStorageError(dynamic error, StackTrace? stackTrace, {String? context}) {
    final message = _getStorageErrorMessage(error);
    _logError(error, stackTrace, context);
    
    return StorageException(
      message,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Handles image processing errors
  AppException handleImageProcessingError(dynamic error, StackTrace? stackTrace, {String? context}) {
    final message = _getImageProcessingErrorMessage(error);
    _logError(error, stackTrace, context);
    
    return ImageProcessingException(
      message,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Gets user-friendly error message for display
  String getUserFriendlyMessage(AppException exception) {
    switch (exception.code) {
      case 'VALIDATION_ERROR':
        return 'Invalid chess position. Please check the board setup.';
      case 'PLATFORM_ERROR':
        return 'Device operation failed. Please try again.';
      case 'ENGINE_ERROR':
        return 'Chess analysis unavailable. Please restart the engine.';
      case 'STORAGE_ERROR':
        return 'Unable to save or load data. Please check device storage.';
      case 'IMAGE_PROCESSING_ERROR':
        return 'Unable to process image. Please try a clearer photo.';
      case 'NETWORK_ERROR':
        return 'Network connection failed. Please check your internet.';
      case 'INITIALIZATION_ERROR':
        return 'App startup failed. Please restart the application.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Logs error with appropriate level based on error type
  void _logError(dynamic error, StackTrace? stackTrace, String? context) {
    if (!kDebugMode) return; // Only log in debug mode
    
    final contextStr = context != null ? '[$context] ' : '';
    final errorStr = '$contextStr$error';
    
    if (error is AppException) {
      debugPrint('AppException: $errorStr');
    } else if (error is PlatformException) {
      debugPrint('PlatformException: $errorStr');
    } else if (error is Exception) {
      debugPrint('Exception: $errorStr');
    } else {
      debugPrint('Error: $errorStr');
    }
    
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Converts various error types to AppException
  AppException _convertToAppException(dynamic error, StackTrace? stackTrace) {
    if (error is AppException) {
      return error;
    }
    
    if (error is services.PlatformException) {
      return PlatformException(
        _getPlatformErrorMessage(error),
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    
    if (error is FormatException || error is ArgumentError) {
      return ValidationException(
        _getValidationErrorMessage(error),
        originalError: error,
        stackTrace: stackTrace,
      );
    }
    
    // Default to generic AppException
    return AppException(
      error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Gets platform-specific error messages
  String _getPlatformErrorMessage(services.PlatformException error) {
    switch (error.code) {
      case 'unavailable':
        return 'Device feature not available';
      case 'permission_denied':
        return 'Permission denied. Please enable required permissions.';
      case 'not_found':
        return 'Requested resource not found';
      case 'timeout':
        return 'Operation timed out. Please try again.';
      default:
        return error.message ?? 'Platform operation failed';
    }
  }

  /// Gets validation-specific error messages
  String _getValidationErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('fen')) {
      return 'Invalid chess position format';
    }
    if (errorStr.contains('board')) {
      return 'Invalid board configuration';
    }
    if (errorStr.contains('king')) {
      return 'Invalid king placement';
    }
    if (errorStr.contains('castling')) {
      return 'Invalid castling rights';
    }
    if (errorStr.contains('turn')) {
      return 'Invalid turn indicator';
    }
    
    return 'Position validation failed';
  }

  /// Gets engine-specific error messages
  String _getEngineErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('timeout')) {
      return 'Chess engine response timeout';
    }
    if (errorStr.contains('initialization')) {
      return 'Chess engine failed to start';
    }
    if (errorStr.contains('isolate')) {
      return 'Chess engine communication error';
    }
    
    return 'Chess engine error occurred';
  }

  /// Gets storage-specific error messages
  String _getStorageErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('permission')) {
      return 'Storage permission denied';
    }
    if (errorStr.contains('space')) {
      return 'Insufficient storage space';
    }
    if (errorStr.contains('corrupt')) {
      return 'Storage data corrupted';
    }
    
    return 'Storage operation failed';
  }

  /// Gets image processing error messages
  String _getImageProcessingErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('format')) {
      return 'Unsupported image format';
    }
    if (errorStr.contains('size')) {
      return 'Image too large or too small';
    }
    if (errorStr.contains('model')) {
      return 'AI model not available';
    }
    if (errorStr.contains('detection')) {
      return 'Could not detect chess board';
    }
    
    return 'Image processing failed';
  }
}