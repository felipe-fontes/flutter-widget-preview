import 'dart:async';

import 'package:preview_core/preview_core.dart';
import 'package:test/test.dart';

void main() {
  test('gRPC streaming works', () async {
    final server = PreviewGrpcServer();
    final port = await server.start(port: 0);
    print('Server started on port $port');

    final client = PreviewGrpcClient();
    await client.connect('localhost', port);
    print('Client connected');

    // Start watching frames
    final receivedFrames = <Frame>[];
    final completer = Completer<void>();

    final subscription = client.watchFrames().listen(
      (frame) {
        print('CLIENT RECEIVED: ${frame.width}x${frame.height}');
        receivedFrames.add(frame);
        if (receivedFrames.length >= 3) {
          completer.complete();
        }
      },
      onError: (e) {
        print('CLIENT ERROR: $e');
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        print('CLIENT DONE');
      },
    );
    print('Client listening');

    // Wait a bit for subscription to be established
    await Future.delayed(Duration(milliseconds: 100));

    // Push some frames
    for (var i = 0; i < 3; i++) {
      final frame = Frame()
        ..width = 100
        ..height = 100
        ..rgbaData = List.filled(100 * 100 * 4, 0)
        ..devicePixelRatio = 2.0
        ..testName = 'test';
      server.pushFrame(frame);
      print('Server pushed frame $i');
      await Future.delayed(Duration(milliseconds: 50));
    }

    // Wait for frames to be received
    try {
      await completer.future.timeout(Duration(seconds: 5));
      print('All frames received!');
    } catch (e) {
      print('Timeout or error: $e');
    }

    await subscription.cancel();
    await client.disconnect();
    await server.stop();

    print('Received ${receivedFrames.length} frames');
    expect(receivedFrames.length, 3);
  });
}
