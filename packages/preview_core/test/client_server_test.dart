import 'dart:async';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:preview_core/preview_core.dart';
import 'package:test/test.dart';

void main() {
  test('client receives frames from server', () async {
    final server = PreviewGrpcServer();
    final port = await server.start(port: 0);
    print('SERVER_READY:$port');

    final client = PreviewGrpcClient();
    await client.connect('localhost', port);
    print('CLIENT_CONNECTED');

    final receivedFrames = <Frame>[];
    final subscription = client.watchFrames().listen((frame) {
      receivedFrames.add(frame);
      print('FRAME_RECEIVED:${frame.width}x${frame.height}');
    });

    await Future.delayed(const Duration(milliseconds: 100));

    for (var i = 0; i < 3; i++) {
      final frame = Frame()
        ..width = 200
        ..height = 150
        ..rgbaData = Uint8List(200 * 150 * 4)
        ..devicePixelRatio = 2.0
        ..timestampMs = Int64(DateTime.now().millisecondsSinceEpoch)
        ..testName = 'client_test';

      server.pushFrame(frame);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await Future.delayed(const Duration(milliseconds: 200));

    expect(receivedFrames.length, equals(3));
    expect(receivedFrames.first.width, equals(200));
    expect(receivedFrames.first.height, equals(150));
    print('FRAMES_TOTAL:${receivedFrames.length}');

    await subscription.cancel();
    await client.disconnect();
    await server.stop();
    print('CLIENT_SERVER_TEST_PASSED');
  });
}
