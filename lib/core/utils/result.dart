/// Result type for handling success and failure cases without exceptions.
/// Provides a functional approach to error handling with explicit success/failure states.

/// Base result type that can be either Success or Failure
abstract class Result<T, E> {
  const Result();
  
  /// Returns true if this is a Success result
  bool get isSuccess => this is Success<T, E>;
  
  /// Returns true if this is a Failure result
  bool get isFailure => this is Failure<T, E>;
  
  /// Gets the success value (throws if failure)
  T get value {
    if (this is Success<T, E>) {
      return (this as Success<T, E>).value;
    }
    throw StateError('Called value on Failure result');
  }
  
  /// Gets the error value (throws if success)
  E get error {
    if (this is Failure<T, E>) {
      return (this as Failure<T, E>).error;
    }
    throw StateError('Called error on Success result');
  }
  
  /// Gets the success value or null if failure
  T? get valueOrNull {
    if (this is Success<T, E>) {
      return (this as Success<T, E>).value;
    }
    return null;
  }
  
  /// Gets the error value or null if success
  E? get errorOrNull {
    if (this is Failure<T, E>) {
      return (this as Failure<T, E>).error;
    }
    return null;
  }
  
  /// Transforms the success value using the provided function
  Result<U, E> map<U>(U Function(T) transform) {
    if (this is Success<T, E>) {
      try {
        return Success(transform((this as Success<T, E>).value));
      } catch (e) {
        // If transform throws, rethrow - let caller handle conversion
        rethrow;
      }
    }
    return Failure((this as Failure<T, E>).error);
  }
  
  /// Transforms the error value using the provided function
  Result<T, U> mapError<U>(U Function(E) transform) {
    if (this is Failure<T, E>) {
      return Failure(transform((this as Failure<T, E>).error));
    }
    return Success((this as Success<T, E>).value);
  }
  
  /// Chains multiple Result operations together
  Result<U, E> flatMap<U>(Result<U, E> Function(T) transform) {
    if (this is Success<T, E>) {
      return transform((this as Success<T, E>).value);
    }
    return Failure((this as Failure<T, E>).error);
  }
  
  /// Executes one of two functions based on the result type
  U fold<U>(U Function(E error) onFailure, U Function(T value) onSuccess) {
    if (this is Success<T, E>) {
      return onSuccess((this as Success<T, E>).value);
    }
    return onFailure((this as Failure<T, E>).error);
  }
  
  /// Gets the success value or returns the provided default
  T getOrElse(T defaultValue) {
    if (this is Success<T, E>) {
      return (this as Success<T, E>).value;
    }
    return defaultValue;
  }
  
  /// Gets the success value or computes it using the provided function
  T getOrElseCompute(T Function(E error) compute) {
    if (this is Success<T, E>) {
      return (this as Success<T, E>).value;
    }
    return compute((this as Failure<T, E>).error);
  }
}

/// Represents a successful result containing a value
class Success<T, E> extends Result<T, E> {
  @override
  final T value;
  
  const Success(this.value);
  
  @override
  bool operator ==(Object other) {
    return other is Success<T, E> && other.value == value;
  }
  
  @override
  int get hashCode => value.hashCode;
  
  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result containing an error
class Failure<T, E> extends Result<T, E> {
  @override
  final E error;
  
  const Failure(this.error);
  
  @override
  bool operator ==(Object other) {
    return other is Failure<T, E> && other.error == error;
  }
  
  @override
  int get hashCode => error.hashCode;
  
  @override
  String toString() => 'Failure($error)';
}

/// Convenience methods for creating Result instances
extension ResultExtensions on Result {
  /// Creates a Success result
  static Result<T, E> success<T, E>(T value) => Success<T, E>(value);
  
  /// Creates a Failure result
  static Result<T, E> failure<T, E>(E error) => Failure<T, E>(error);
}

/// Extension methods for working with nullable values
extension NullableResultExtensions<T> on T? {
  /// Converts a nullable value to a Result
  Result<T, String> toResult([String? errorMessage]) {
    if (this != null) {
      return Success(this!);
    }
    return Failure(errorMessage ?? 'Value was null');
  }
}

/// Extension methods for working with Future<Result>
extension FutureResultExtensions<T, E> on Future<Result<T, E>> {
  /// Handles exceptions in async Result operations
  Future<Result<T, E>> catchError(E Function(Object error, StackTrace stackTrace) onError) {
    return then((result) => result).catchError((error, stackTrace) {
      return Failure<T, E>(onError(error, stackTrace));
    });
  }
}