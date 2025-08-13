import 'package:flutter/foundation.dart';
import 'disposable.dart';

/// Centralized resource manager
/// Handles automatic cleanup of resources and prevents memory leaks.
class ResourceManager with DisposableMixin {
  static final ResourceManager _instance = ResourceManager._internal();
  factory ResourceManager() => _instance;
  ResourceManager._internal();

  final List<DisposableResource> _resources = [];
  final Map<String, DisposableResource> _namedResources = {};
  
  /// Register a resource for automatic cleanup
  T register<T extends DisposableResource>(T resource, {String? name}) {
    checkNotDisposed();
    
    _resources.add(resource);
    
    if (name != null) {
      _namedResources[name] = resource;
    }
    
    if (kDebugMode) {
      debugPrint('ResourceManager: Registered ${resource.runtimeType}${name != null ? ' ($name)' : ''}');
    }
    
    return resource;
  }
  
  /// Register a resource with automatic type-based naming
  T registerTyped<T extends DisposableResource>(T resource) {
    return register(resource, name: T.toString());
  }
  
  /// Get a named resource
  T? get<T extends DisposableResource>(String name) {
    final resource = _namedResources[name];
    return resource is T ? resource : null;
  }
  
  /// Get a resource by type (first matching resource)
  T? getByType<T extends DisposableResource>() {
    for (final resource in _resources) {
      if (resource is T) return resource;
    }
    return null;
  }
  
  /// Get all resources of a specific type
  List<T> getAllByType<T extends DisposableResource>() {
    return _resources.whereType<T>().toList();
  }
  
  /// Unregister a resource (caller becomes responsible for disposal)
  bool unregister(DisposableResource resource) {
    checkNotDisposed();
    
    final removed = _resources.remove(resource);
    _namedResources.removeWhere((key, value) => value == resource);
    
    if (removed && kDebugMode) {
      debugPrint('ResourceManager: Unregistered ${resource.runtimeType}');
    }
    
    return removed;
  }
  
  /// Unregister a named resource
  T? unregisterNamed<T extends DisposableResource>(String name) {
    checkNotDisposed();
    
    final resource = _namedResources.remove(name);
    if (resource != null) {
      _resources.remove(resource);
      if (kDebugMode) {
        debugPrint('ResourceManager: Unregistered $name (${resource.runtimeType})');
      }
    }
    
    return resource is T ? resource : null;
  }
  
  /// Dispose a specific resource and unregister it
  Future<void> disposeResource(DisposableResource resource) async {
    if (unregister(resource)) {
      await resource.dispose();
    }
  }
  
  /// Dispose a named resource
  Future<void> disposeNamed(String name) async {
    final resource = unregisterNamed(name);
    if (resource != null) {
      await resource.dispose();
    }
  }
  
  /// Get count of registered resources
  int get resourceCount => _resources.length;
  
  /// Get count of named resources
  int get namedResourceCount => _namedResources.length;
  
  /// Get information about registered resources (for debugging)
  Map<String, dynamic> getResourceInfo() {
    final typeCount = <String, int>{};
    for (final resource in _resources) {
      final typeName = resource.runtimeType.toString();
      typeCount[typeName] = (typeCount[typeName] ?? 0) + 1;
    }
    
    return {
      'totalResources': _resources.length,
      'namedResources': _namedResources.length,
      'typeBreakdown': typeCount,
      'namedResourceKeys': _namedResources.keys.toList(),
    };
  }
  
  /// Dispose all resources in reverse order (LIFO)
  @override
  Future<void> onDispose() async {
    if (kDebugMode) {
      debugPrint('ResourceManager: Disposing ${_resources.length} resources');
    }
    
    final errors = <Exception>[];
    
    // Dispose in reverse order (last registered, first disposed)
    for (final resource in _resources.reversed) {
      try {
        if (!resource.isDisposed) {
          await resource.dispose();
        }
      } catch (e) {
        errors.add(Exception('Failed to dispose ${resource.runtimeType}: $e'));
        if (kDebugMode) {
          debugPrint('ResourceManager: Error disposing ${resource.runtimeType}: $e');
        }
      }
    }
    
    _resources.clear();
    _namedResources.clear();
    
    if (errors.isNotEmpty) {
      throw AggregateException('Multiple disposal errors occurred', errors);
    }
    
    if (kDebugMode) {
      debugPrint('ResourceManager: All resources disposed');
    }
  }
}

/// Exception that aggregates multiple exceptions
class AggregateException implements Exception {
  final String message;
  final List<Exception> innerExceptions;
  
  AggregateException(this.message, this.innerExceptions);
  
  @override
  String toString() {
    final buffer = StringBuffer(message);
    buffer.writeln();
    for (int i = 0; i < innerExceptions.length; i++) {
      buffer.writeln('  ${i + 1}. ${innerExceptions[i]}');
    }
    return buffer.toString();
  }
}

/// Scoped resource manager for temporary resource groups
class ScopedResourceManager with DisposableMixin {
  final List<DisposableResource> _scopedResources = [];
  
  /// Register a resource in this scope
  T register<T extends DisposableResource>(T resource) {
    checkNotDisposed();
    _scopedResources.add(resource);
    return resource;
  }
  
  /// Dispose all resources in this scope
  @override
  Future<void> onDispose() async {
    for (final resource in _scopedResources.reversed) {
      if (!resource.isDisposed) {
        await resource.dispose();
      }
    }
    _scopedResources.clear();
  }
}

/// Extension methods for convenient resource management
extension ResourceManagerExtensions on DisposableResource {
  /// Register this resource with the global ResourceManager
  T registerGlobally<T extends DisposableResource>({String? name}) {
    return ResourceManager().register(this as T, name: name);
  }
  
  /// Register this resource in a scoped manager
  T registerScoped<T extends DisposableResource>(ScopedResourceManager scope) {
    return scope.register(this as T);
  }
}