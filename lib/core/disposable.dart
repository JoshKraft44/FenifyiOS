/// Abstract interface for resources that require explicit cleanup.
/// Provides a contract for objects that hold resources like isolates, streams, or native resources.

/// Interface for resources that can be disposed
abstract class DisposableResource {
  /// Whether this resource has been disposed
  bool get isDisposed;
  
  /// Dispose of this resource and clean up any associated resources
  /// Should be idempotent - safe to call multiple times
  Future<void> dispose();
}

/// Mixin to provide common disposal functionality
mixin DisposableMixin implements DisposableResource {
  bool _isDisposed = false;
  
  @override
  bool get isDisposed => _isDisposed;
  
  /// Mark as disposed (call this in your dispose() implementation)
  void markDisposed() {
    _isDisposed = true;
  }
  
  /// Throws if already disposed
  void checkNotDisposed() {
    if (_isDisposed) {
      throw StateError('${runtimeType} has been disposed');
    }
  }
  
  @override
  Future<void> dispose() async {
    if (_isDisposed) return; // Already disposed
    
    await onDispose();
    markDisposed();
  }
  
  /// Override this method to implement disposal logic
  Future<void> onDispose();
}

/// Interface for resources that provide streams
abstract class StreamResource<T> extends DisposableResource {
  /// The main stream provided by this resource
  Stream<T> get stream;
  
  /// Close the stream and dispose resources
  Future<void> close();
}

/// Interface for isolate-based resources
abstract class IsolateResource extends DisposableResource {
  /// Whether the isolate is currently running
  bool get isRunning;
  
  /// Start the isolate
  Future<void> start();
  
  /// Stop the isolate and clean up
  Future<void> stop();
}

/// Interface for native platform resources
abstract class PlatformResource extends DisposableResource {
  /// Initialize the platform resource
  Future<void> initialize();
  
  /// Check if the resource is available on this platform
  bool get isAvailable;
}