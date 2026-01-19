import 'dart:async';
import 'dart:convert';

import 'package:preview_core/preview_core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FrameRelay {
  final PreviewGrpcClient _grpcClient = PreviewGrpcClient();
  final List<WebSocketChannel> _browserConnections = [];
  StreamSubscription<Frame>? _frameSubscription;

  Future<void> connectToTest(String host, int port) async {
    await _grpcClient.connect(host, port);
    print('RELAY_CONNECTED_TO_TEST:$host:$port');

    _frameSubscription = _grpcClient.watchFrames().listen(
      _handleFrame,
      onError: (error) {
        print('RELAY_ERROR:$error');
      },
      onDone: () {
        print('RELAY_STREAM_CLOSED');
      },
    );
  }

  void addBrowserConnection(WebSocketChannel channel) {
    _browserConnections.add(channel);
    print('BROWSER_CONNECTED:${_browserConnections.length} total');

    channel.stream.listen(
      (message) {},
      onDone: () {
        _browserConnections.remove(channel);
        print('BROWSER_DISCONNECTED:${_browserConnections.length} remaining');
      },
    );
  }

  void _handleFrame(Frame frame) {
    print('RELAY_FRAME:${frame.width}x${frame.height}');

    final metadata = jsonEncode({
      'type': 'frame',
      'width': frame.width,
      'height': frame.height,
      'devicePixelRatio': frame.devicePixelRatio,
      'testName': frame.testName,
    });

    for (final connection in _browserConnections) {
      try {
        connection.sink.add(metadata);
        connection.sink.add(frame.rgbaData);
      } catch (e) {
        print('RELAY_SEND_ERROR:$e');
      }
    }
  }

  Future<void> disconnect() async {
    await _frameSubscription?.cancel();
    await _grpcClient.disconnect();
    final connections = List.of(_browserConnections);
    _browserConnections.clear();
    for (final connection in connections) {
      await connection.sink.close();
    }
    print('RELAY_DISCONNECTED');
  }
}
