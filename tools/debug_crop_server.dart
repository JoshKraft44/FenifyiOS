// Minimal debug crop HTTP server with port fallback.

//   dart tools/debug_crop_server.dart --port 8787 --dir /path/to/save [--host 0.0.0.0]
//   dart tools/debug_crop_server.dart --port 0   (let OS choose a free port)

import 'dart:io';
import 'dart:async';

void main(List<String> args) async {
  int port = 8787;
  String dirPath = Directory.current.path;
  String host = InternetAddress.anyIPv4.address; // 0.0.0.0 by default
  int fallbackAttempts = 15; // try port+1 .. port+N if in use

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[i + 1]) ?? port;
      i++;
    } else if (args[i] == '--dir' && i + 1 < args.length) {
      dirPath = args[i + 1];
      i++;
    } else if (args[i] == '--host' && i + 1 < args.length) {
      host = args[i + 1];
      i++;
    } else if (args[i] == '--attempts' && i + 1 < args.length) {
      fallbackAttempts = int.tryParse(args[i + 1]) ?? fallbackAttempts;
      i++;
    }
  }

  final saveDir = Directory(dirPath);
  if (!await saveDir.exists()) {
    await saveDir.create(recursive: true);
  }

  final InternetAddress bindAddress = await _resolveHost(host);
  final server =
      await _bindWithFallback(bindAddress, port, attempts: fallbackAttempts);
  final boundHost = server.address.address == InternetAddress.anyIPv4.address
      ? 'localhost'
      : server.address.address;
  print('Debug crop server listening on http://$boundHost:${server.port}');
  print('Saving uploads to: ${saveDir.path}');
  print('Health:  GET  http://$boundHost:${server.port}/health');
  print(
      'Upload:  curl -X POST --data-binary @file.jpg "http://$boundHost:${server.port}/upload?name=file.jpg"');

  await for (HttpRequest req in server) {
    try {
      if (req.method == 'GET' && req.uri.path == '/health') {
        req.response.statusCode = 200;
        req.response.write('ok');
        await req.response.close();
        continue;
      }

      if (req.method == 'POST' && req.uri.path == '/upload') {
        final name = req.uri.queryParameters['name'] ??
            'upload-${DateTime.now().millisecondsSinceEpoch}.bin';
        final file = File('${saveDir.path}/$name');
        final sink = file.openWrite();
        await req.listen((data) => sink.add(data)).asFuture();
        await sink.close();
        req.response.statusCode = 200;
        req.response.write('saved ${file.path}');
        await req.response.close();
        print(
            'Saved ${file.path} from ${req.connectionInfo?.remoteAddress.address}');
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    } catch (e) {
      try {
        req.response.statusCode = 500;
        req.response.write('error: $e');
        await req.response.close();
      } catch (_) {}
      print('Error: $e');
    }
  }
}

Future<HttpServer> _bindWithFallback(InternetAddress address, int port,
    {int attempts = 10}) async {
  // If port == 0, OS will choose a free ephemeral port.
  if (port == 0) {
    return HttpServer.bind(address, 0);
  }

  SocketException? lastError;
  for (int i = 0; i <= attempts; i++) {
    final p = port + i;
    try {
      final server = await HttpServer.bind(address, p);
      if (i > 0) {
        stderr.writeln(
            'Note: requested port $port was busy; bound to $p instead.');
      }
      return server;
    } on SocketException catch (e) {
      lastError = e;
      final code = e.osError?.errorCode;
      // 48 = EADDRINUSE (macOS), 98 = EADDRINUSE (Linux)
      if (code == 48 || code == 98) {
        if (i < attempts) {
          continue; // try next port
        }
      }
      rethrow; // other errors or out of attempts
    }
  }
  // If we got here, all attempts failed with EADDRINUSE
  throw SocketException(
      'All attempted ports $port..${port + attempts} are in use',
      osError: lastError?.osError);
}

Future<InternetAddress> _resolveHost(String host) async {
  // Allow common host shorthands
  if (host == 'localhost') return InternetAddress.loopbackIPv4;
  if (host == '0.0.0.0') return InternetAddress.anyIPv4;
  try {
    final addrs = await InternetAddress.lookup(host);
    return addrs.first;
  } catch (_) {
    return InternetAddress.anyIPv4;
  }
}
