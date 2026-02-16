import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Small helper to save debug images, POST them to local HTTP server.
class DebugExporter {
  // Base URL / Ex.  http://192.168.1.65:8787
  static String? baseUrl;

  // Whether to save debug images to local storage (enable by default)
  static bool enableLocalSave = true;

  // Gets or creates the debug folder in app's document directory
  static Future<Directory?> _getDebugFolder() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final debugDir = Directory('${docDir.path}/opencv_debug');

      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
        if (kDebugMode) {
          debugPrint('DebugExporter: Created debug folder at ${debugDir.path}');
        }
      }

      return debugDir;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DebugExporter: Failed to create debug folder: $e');
      }
      return null;
    }
  }

  // Clears all files in the debug folder
  static Future<void> clearDebugFolder() async {
    if (!kDebugMode) return;

    try {
      final debugDir = await _getDebugFolder();
      if (debugDir == null) return;

      final files = debugDir.listSync();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }

      if (kDebugMode) {
        debugPrint('DebugExporter: Cleared ${files.length} debug files');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DebugExporter: Error clearing debug folder: $e');
      }
    }
  }

  // Gets the path to the debug folder (for showing to user)
  static Future<String?> getDebugFolderPath() async {
    final debugDir = await _getDebugFolder();
    return debugDir?.path;
  }

  // Saves bytes to local debug folder and uploads to HTTP server.
  static Future<void> exportBytes(Uint8List bytes,
      {required String name}) async {
    if (!kDebugMode) return;

    // Save to local debug folder
    if (enableLocalSave) {
      try {
        final debugDir = await _getDebugFolder();
        if (debugDir != null) {
          final file = File('${debugDir.path}/$name');
          await file.writeAsBytes(bytes);
          if (kDebugMode) {
            debugPrint(
                'DebugExporter: Saved $name (${bytes.length} bytes) to ${file.path}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('DebugExporter: Error saving to local folder: $e');
        }
      }
    }

    // Upload to HTTP server if configured
    final url = baseUrl;
    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url).replace(
      path: '/upload',
      queryParameters: {'name': name},
    );

    // Light retry to handle cases where server starts late
    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/octet-stream'},
          body: bytes,
        );
        if (resp.statusCode == 200) {
          if (kDebugMode) {
            debugPrint('DebugExporter: uploaded $name to ${uri.toString()}');
          }
          return;
        } else {
          if (kDebugMode) {
            debugPrint(
                'DebugExporter: upload failed ${resp.statusCode}: ${resp.body}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'DebugExporter: upload error (attempt $attempt/$maxAttempts): $e');
        }
      }
      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
  }
}
