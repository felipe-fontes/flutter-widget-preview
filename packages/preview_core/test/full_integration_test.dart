// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:preview_core/preview_core.dart';
import 'package:test/test.dart';

/// This test simulates the full integration flow:
/// 1. Start a gRPC server (like the flutter test does)
/// 2. Push frames in a delayed fashion (simulating widget pumping)
/// 3. Meanwhile, connect a client (like the viewer does)
/// 4. Verify frames are received
void main() {
  test('Full integration simulation - viewer connects while frames are pushed',
      () async {
    final server = PreviewGrpcServer();
    final port = await server.start();
    print('SERVER_STARTED:$port');

    // Start pushing frames in the background (simulates flutter test)
    final framePushComplete = Completer<void>();
    unawaited(() async {
      print('PUSHING_FRAMES_STARTING');
      for (var i = 0; i < 5; i++) {
        await Future.delayed(Duration(milliseconds: 100));
        server.pushFrame(
          Frame()
            ..width = 100
            ..height = 100
            ..devicePixelRatio = 1.0
            ..testName = 'test'
            ..rgbaData = List.filled(100 * 100 * 4, 0),
        );
        print('PUSHED_FRAME_${i + 1}');
      }
      framePushComplete.complete();
    }());

    // Connect the client with a small delay (simulates viewer starting up)
    await Future.delayed(Duration(milliseconds: 50));

    final client = PreviewGrpcClient();
    await client.connect('localhost', port);
    print('CLIENT_CONNECTED');

    final framesReceived = <Frame>[];
    final stream = client.watchFrames();
    print('CLIENT_GOT_STREAM');

    final subscription = stream.listen(
      (frame) {
        print('CLIENT_RECEIVED_FRAME:${framesReceived.length + 1}');
        framesReceived.add(frame);
      },
      onError: (e) => print('CLIENT_ERROR:$e'),
      onDone: () => print('CLIENT_STREAM_DONE'),
    );
    print('CLIENT_SUBSCRIPTION_CREATED');

    // Wait for frame pushing to complete
    await framePushComplete.future;
    print('ALL_FRAMES_PUSHED');

    // Give a bit more time for the last frames to be received
    await Future.delayed(Duration(milliseconds: 200));

    await subscription.cancel();
    await client.disconnect();
    await server.stop();

    print('TOTAL_FRAMES_RECEIVED:${framesReceived.length}');
    expect(framesReceived.length, greaterThanOrEqualTo(3),
        reason: 'Should receive at least 3 frames');
  });

  test('Viewer connects AFTER all frames pushed - tests buffering', () async {
    final server = PreviewGrpcServer();
    final port = await server.start();
    print('SERVER_STARTED:$port');

    // Push ALL frames first
    for (var i = 0; i < 5; i++) {
      server.pushFrame(
        Frame()
          ..width = 100
          ..height = 100
          ..devicePixelRatio = 1.0
          ..testName = 'test'
          ..rgbaData = List.filled(100 * 100 * 4, 0),
      );
      print('PUSHED_FRAME_${i + 1}');
    }
    print('ALL_FRAMES_PUSHED');

    // NOW connect the client (simulates late viewer connection)
    await Future.delayed(Duration(milliseconds: 100));

    final client = PreviewGrpcClient();
    await client.connect('localhost', port);
    print('CLIENT_CONNECTED');

    final framesReceived = <Frame>[];
    final stream = client.watchFrames();
    print('CLIENT_GOT_STREAM');

    final gotFirstFrame = Completer<void>();
    final subscription = stream.listen(
      (frame) {
        print('CLIENT_RECEIVED_FRAME:${framesReceived.length + 1}');
        framesReceived.add(frame);
        if (!gotFirstFrame.isCompleted) {
          gotFirstFrame.complete();
        }
      },
      onError: (e) => print('CLIENT_ERROR:$e'),
      onDone: () => print('CLIENT_STREAM_DONE'),
    );
    print('CLIENT_SUBSCRIPTION_CREATED');

    // Wait for buffered frames to arrive
    await gotFirstFrame.future.timeout(
      Duration(seconds: 2),
      onTimeout: () => throw StateError('No frames received'),
    );

    // Give time for all buffered frames
    await Future.delayed(Duration(milliseconds: 500));

    await subscription.cancel();
    await client.disconnect();
    await server.stop();

    print('TOTAL_FRAMES_RECEIVED:${framesReceived.length}');
    expect(framesReceived.length, greaterThanOrEqualTo(1),
        reason: 'Should receive at least 1 buffered frame');
  });
}
