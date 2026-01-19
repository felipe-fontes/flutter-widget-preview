import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_binding/preview_binding.dart';
import 'package:preview_core/preview_core.dart';

void main() {
  PreviewTestBinding.ensureInitialized();

  testWidgets('captures frame from red container', (tester) async {
    final binding = PreviewTestBinding.instance;

    final serverUri = await binding.startServer();
    print('SERVER_URI:$serverUri');

    final client = PreviewGrpcClient();
    final uri = Uri.parse(serverUri);
    await client.connect(uri.host, uri.port);
    print('CLIENT_CONNECTED');

    final frames = <Frame>[];
    final completer = Completer<void>();

    final subscription = client.watchFrames().listen((frame) {
      frames.add(frame);
      print('FRAME_RECEIVED:${frame.width}x${frame.height}');
      if (frames.length >= 1 && !completer.isCompleted) {
        completer.complete();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Container(
          color: Colors.red,
          width: 200,
          height: 200,
        ),
      ),
    );
    await tester.pump();

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('TIMEOUT_WAITING_FOR_FRAMES');
      },
    );

    expect(frames.length, greaterThan(0), reason: 'Should have received at least one frame');
    print('FRAME_COUNT:${frames.length}');

    final frame = frames.first;
    expect(frame.rgbaData.length, greaterThan(0));
    print('PIXEL_DATA_SIZE:${frame.rgbaData.length}');

    await subscription.cancel();
    await client.disconnect();
    await binding.stopServer();
    print('BINDING_TEST_PASSED');
  });
}
