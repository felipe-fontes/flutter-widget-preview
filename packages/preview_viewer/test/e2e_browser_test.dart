// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:preview_core/preview_core.dart';
import 'package:preview_viewer/preview_viewer.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// End-to-end test: gRPC server -> Viewer (with relay) -> WebSocket browser
void main() {
  test('Full viewer stack - browser receives frames', () async {
    // 1. Start gRPC server (simulates flutter test)
    final grpcServer = PreviewGrpcServer();
    final grpcPort = await grpcServer.start();
    print('GRPC_SERVER:$grpcPort');

    // 2. Start viewer (relay + web server)
    final relay = FrameRelay();
    final webServer = ViewerServer(relay);

    await relay.connectToTest('localhost', grpcPort);
    final webPort = await webServer.start(port: 0);
    print('WEB_SERVER:$webPort');

    // 3. Push some frames BEFORE browser connects
    for (var i = 0; i < 3; i++) {
      grpcServer.pushFrame(
        Frame()
          ..width = 100
          ..height = 100
          ..devicePixelRatio = 1.0
          ..testName = 'test'
          ..rgbaData = List.filled(100 * 100 * 4, i),
      );
      print('PUSHED_FRAME_${i + 1}');
    }

    // Give time for frames to flow through gRPC
    await Future.delayed(Duration(milliseconds: 500));

    // 4. Connect browser via WebSocket
    print('BROWSER_CONNECTING...');
    final wsChannel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:$webPort/ws'),
    );

    final messagesReceived = <dynamic>[];
    var framesReceived = 0;
    final gotFirstFrame = Completer<void>();

    wsChannel.stream.listen(
      (message) {
        print(
            'BROWSER_MESSAGE:${message.runtimeType} - ${message is String ? message.substring(0, 50.clamp(0, (message as String).length)) : "${(message as List).length} bytes"}');
        messagesReceived.add(message);

        // Every frame is 2 messages: JSON metadata + binary data
        if (message is List<int>) {
          framesReceived++;
          if (!gotFirstFrame.isCompleted) {
            gotFirstFrame.complete();
          }
        }
      },
      onError: (e) => print('BROWSER_ERROR:$e'),
      onDone: () => print('BROWSER_DISCONNECTED'),
    );

    // 5. Wait for buffered frames to arrive
    try {
      await gotFirstFrame.future.timeout(Duration(seconds: 5));
      print('GOT_FIRST_FRAME');
    } catch (e) {
      print('TIMEOUT_WAITING_FOR_FRAMES');
    }

    // Push more frames now that browser is connected
    for (var i = 3; i < 6; i++) {
      grpcServer.pushFrame(
        Frame()
          ..width = 100
          ..height = 100
          ..devicePixelRatio = 1.0
          ..testName = 'test'
          ..rgbaData = List.filled(100 * 100 * 4, i),
      );
      print('PUSHED_FRAME_${i + 1}');
    }

    // Wait for all frames
    await Future.delayed(Duration(milliseconds: 1000));

    await wsChannel.sink.close();
    await relay.disconnect();
    await webServer.stop();
    await grpcServer.stop();

    print('TOTAL_MESSAGES:${messagesReceived.length}');
    print('TOTAL_FRAMES:$framesReceived');

    // Should receive at least the buffered frames
    expect(framesReceived, greaterThanOrEqualTo(1),
        reason: 'Browser should receive at least 1 frame');
  });
}
