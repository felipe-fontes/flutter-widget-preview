import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'frame_relay.dart';

class ViewerServer {
  final FrameRelay _relay;
  HttpServer? _server;

  ViewerServer(this._relay);

  Future<int> start({int port = 8080}) async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_createHandler());

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('VIEWER_SERVER_STARTED:http://localhost:${_server!.port}');
    return _server!.port;
  }

  Handler _createHandler() {
    return (Request request) {
      if (request.url.path == 'ws') {
        return _handleWebSocket(request);
      }

      if (request.url.path == '' || request.url.path == '/') {
        return Response.ok(_viewerHtml, headers: {
          'content-type': 'text/html',
        });
      }

      return Response.notFound('Not found');
    };
  }

  Future<Response> _handleWebSocket(Request request) async {
    final handler = webSocketHandler((WebSocketChannel channel, String? protocol) {
      _relay.addBrowserConnection(channel);
    });
    return await handler(request);
  }

  Future<void> stop() async {
    await _server?.close();
    print('VIEWER_SERVER_STOPPED');
  }

  static const _viewerHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flutter Widget Preview</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #1a1a2e;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      font-family: 'SF Mono', 'Fira Code', monospace;
      color: #eee;
    }
    .container {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 16px;
    }
    h1 {
      font-size: 14px;
      font-weight: 500;
      color: #888;
      text-transform: uppercase;
      letter-spacing: 2px;
    }
    #status {
      font-size: 12px;
      color: #4ade80;
      padding: 8px 16px;
      background: rgba(74, 222, 128, 0.1);
      border-radius: 4px;
    }
    #status.disconnected {
      color: #f87171;
      background: rgba(248, 113, 113, 0.1);
    }
    .canvas-container {
      background: #16213e;
      border-radius: 12px;
      padding: 16px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
    }
    #preview {
      display: block;
      border-radius: 8px;
      background: #0f0f23;
    }
    .info {
      font-size: 11px;
      color: #666;
      margin-top: 8px;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Widget Preview</h1>
    <div id="status" class="disconnected">Connecting...</div>
    <div class="canvas-container">
      <canvas id="preview" width="400" height="800"></canvas>
    </div>
    <div class="info">
      <span id="dimensions">--</span> |
      <span id="fps">-- fps</span>
    </div>
  </div>

  <script>
    const canvas = document.getElementById('preview');
    const ctx = canvas.getContext('2d');
    const status = document.getElementById('status');
    const dimensions = document.getElementById('dimensions');
    const fpsDisplay = document.getElementById('fps');

    let frameCount = 0;
    let lastFpsUpdate = Date.now();
    let pendingMetadata = null;

    function connect() {
      const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
      const ws = new WebSocket(protocol + '//' + location.host + '/ws');
      ws.binaryType = 'arraybuffer';

      ws.onopen = () => {
        status.textContent = 'Connected';
        status.classList.remove('disconnected');
      };

      ws.onclose = () => {
        status.textContent = 'Disconnected - Reconnecting...';
        status.classList.add('disconnected');
        setTimeout(connect, 1000);
      };

      ws.onerror = () => {
        ws.close();
      };

      ws.onmessage = (event) => {
        if (typeof event.data === 'string') {
          pendingMetadata = JSON.parse(event.data);
        } else if (event.data instanceof ArrayBuffer && pendingMetadata) {
          renderFrame(pendingMetadata, new Uint8ClampedArray(event.data));
          pendingMetadata = null;
        }
      };
    }

    function renderFrame(meta, rgbaData) {
      const { width, height, devicePixelRatio } = meta;
      
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
        const displayWidth = width / devicePixelRatio;
        const displayHeight = height / devicePixelRatio;
        canvas.style.width = displayWidth + 'px';
        canvas.style.height = displayHeight + 'px';
      }

      const imageData = new ImageData(rgbaData, width, height);
      ctx.putImageData(imageData, 0, 0);

      dimensions.textContent = Math.round(width/devicePixelRatio) + 'x' + Math.round(height/devicePixelRatio);
      
      frameCount++;
      const now = Date.now();
      if (now - lastFpsUpdate >= 1000) {
        fpsDisplay.textContent = frameCount + ' fps';
        frameCount = 0;
        lastFpsUpdate = now;
      }
    }

    connect();
  </script>
</body>
</html>
''';
}
