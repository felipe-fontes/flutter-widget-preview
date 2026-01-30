import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'frame_relay.dart';

class ViewerServer {
  final FrameRelay _relay;
  final String _templatePath;
  HttpServer? _server;
  String? _cachedHtml;
  int? _cachedPort;

  ViewerServer(this._relay, {required String templatePath})
      : _templatePath = templatePath;

  Future<int> start({int port = 8080}) async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_createHandler(port));

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('VIEWER_SERVER_STARTED:http://localhost:${_server!.port}');
    return _server!.port;
  }

  String _getViewerHtml(int port) {
    // Use cached HTML if port matches
    if (_cachedHtml != null && _cachedPort == port) {
      return _cachedHtml!;
    }

    final file = File(_templatePath);
    if (!file.existsSync()) {
      throw StateError('Template file not found: $_templatePath');
    }

    var html = file.readAsStringSync();
    html = html.replaceAll('{{PORT}}', port.toString());

    // Cache the result
    _cachedHtml = html;
    _cachedPort = port;

    return html;
  }

  Handler _createHandler(int port) {
    return (Request request) {
      if (request.url.path == 'ws') {
        return _handleWebSocket(request);
      }

      if (request.url.path == '' || request.url.path == '/') {
        return Response.ok(_getViewerHtml(port), headers: {
          'content-type': 'text/html',
        });
      }

      return Response.notFound('Not found');
    };
  }

  Future<Response> _handleWebSocket(Request request) async {
    final handler =
        webSocketHandler((WebSocketChannel channel, String? protocol) {
      _relay.addBrowserConnection(channel);
    });
    return await handler(request);
  }

  Future<void> stop() async {
    await _server?.close();
    print('VIEWER_SERVER_STOPPED');
  }
}
