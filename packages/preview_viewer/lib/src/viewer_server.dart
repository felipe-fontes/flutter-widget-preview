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

  static const _viewerHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Flutter Widget Preview</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
    }
    body {
      background: #1a1a2e;
      display: flex;
      flex-direction: column;
      font-family: 'SF Mono', 'Fira Code', monospace;
      color: #eee;
    }
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 16px;
      background: rgba(0, 0, 0, 0.3);
      flex-shrink: 0;
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
      padding: 6px 12px;
      background: rgba(74, 222, 128, 0.1);
      border-radius: 4px;
    }
    #status.disconnected {
      color: #f87171;
      background: rgba(248, 113, 113, 0.1);
    }
    .canvas-wrapper {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 16px;
      min-height: 0;
      overflow: hidden;
    }
    .canvas-container {
      background: #16213e;
      border-radius: 12px;
      padding: 16px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
      max-width: 100%;
      max-height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    #preview {
      display: block;
      border-radius: 8px;
      background: #0f0f23;
      max-width: 100%;
      max-height: calc(100vh - 120px);
      object-fit: contain;
    }
    .footer {
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 8px 16px;
      background: rgba(0, 0, 0, 0.3);
      flex-shrink: 0;
    }
    .info {
      font-size: 11px;
      color: #666;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>Widget Preview</h1>
    <div id="status" class="disconnected">Connecting...</div>
  </div>
  <div class="canvas-wrapper">
    <div class="canvas-container">
      <canvas id="preview"></canvas>
    </div>
  </div>
  <div class="footer">
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
    const canvasWrapper = document.querySelector('.canvas-wrapper');

    let frameCount = 0;
    let lastFpsUpdate = Date.now();
    let pendingMetadata = null;
    let currentMeta = null;

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
      currentMeta = meta;
      
      // Set canvas internal dimensions to match the frame
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }

      // Calculate logical size
      const logicalWidth = width / devicePixelRatio;
      const logicalHeight = height / devicePixelRatio;
      
      // Get available space (accounting for padding)
      const availableWidth = canvasWrapper.clientWidth - 64;  // 16px padding on each side + 16px container padding
      const availableHeight = canvasWrapper.clientHeight - 64;
      
      // Calculate scale to fit while maintaining aspect ratio
      const scaleX = availableWidth / logicalWidth;
      const scaleY = availableHeight / logicalHeight;
      const scale = Math.min(scaleX, scaleY, 1);  // Don't upscale beyond 1:1
      
      // Apply scaled display size
      canvas.style.width = Math.round(logicalWidth * scale) + 'px';
      canvas.style.height = Math.round(logicalHeight * scale) + 'px';

      const imageData = new ImageData(rgbaData, width, height);
      ctx.putImageData(imageData, 0, 0);

      dimensions.textContent = Math.round(logicalWidth) + 'x' + Math.round(logicalHeight) + ' @' + devicePixelRatio + 'x';
      
      frameCount++;
      const now = Date.now();
      if (now - lastFpsUpdate >= 1000) {
        fpsDisplay.textContent = frameCount + ' fps';
        frameCount = 0;
        lastFpsUpdate = now;
      }
    }

    // Handle window resize
    window.addEventListener('resize', () => {
      if (currentMeta) {
        // Re-calculate display size on resize
        const { width, height, devicePixelRatio } = currentMeta;
        const logicalWidth = width / devicePixelRatio;
        const logicalHeight = height / devicePixelRatio;
        
        const availableWidth = canvasWrapper.clientWidth - 64;
        const availableHeight = canvasWrapper.clientHeight - 64;
        
        const scaleX = availableWidth / logicalWidth;
        const scaleY = availableHeight / logicalHeight;
        const scale = Math.min(scaleX, scaleY, 1);
        
        canvas.style.width = Math.round(logicalWidth * scale) + 'px';
        canvas.style.height = Math.round(logicalHeight * scale) + 'px';
      }
    });

    connect();
  </script>
</body>
</html>
''';
}
