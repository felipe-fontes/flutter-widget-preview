import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_binding/preview_binding.dart';
import 'package:preview_core/preview_core.dart';

void main() {
  PreviewTestBinding.ensureInitialized();

  testWidgets(
    'does not send duplicate frames for identical pumps',
    (tester) async {
      final binding = PreviewTestBinding.instance;
      final serverUri = await binding.startServer();

      final client = PreviewGrpcClient();
      final uri = Uri.parse(serverUri);
      await client.connect(uri.host, uri.port);

      final validFrames = <Frame>[];
      final firstValidFrame = Completer<void>();
      late final StreamSubscription<Frame> subscription;

      subscription = client.watchFrames().listen((frame) {
        if (frame.width <= 0 || frame.height <= 0 || frame.rgbaData.isEmpty) {
          return;
        }

        validFrames.add(frame);
        if (!firstValidFrame.isCompleted) {
          firstValidFrame.complete();
        }
      });

      try {
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

        await firstValidFrame.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final countAfterInitial = validFrames.length;
        expect(countAfterInitial, greaterThan(0));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(
          validFrames.length,
          equals(countAfterInitial),
          reason:
              'Identical frames from repeated pump() calls should be deduplicated',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Container(
              color: Colors.blue,
              width: 200,
              height: 200,
            ),
          ),
        );
        await tester.pump();

        await _waitUntil(
          () => validFrames.length > countAfterInitial,
          timeout: const Duration(seconds: 5),
        );

        expect(
          validFrames.length,
          greaterThan(countAfterInitial),
          reason: 'A visual change should still emit a new frame',
        );
      } finally {
        await subscription.cancel();
        await client.disconnect();
        await binding.stopServer();
      }
    },
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  required Duration timeout,
  Duration poll = const Duration(milliseconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(poll);
  }
}
