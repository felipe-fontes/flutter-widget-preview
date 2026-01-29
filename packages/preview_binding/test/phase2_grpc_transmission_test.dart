/// Phase 2 Test: Verify that frames are transmitted via gRPC
///
/// This test verifies:
/// 1. gRPC server starts and accepts connections
/// 2. Client can connect and subscribe to frame stream
/// 3. Frames generated in Phase 1 are received by the client
/// 4. Frame data is valid (width, height, pixel data)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_binding/preview_binding.dart';
import 'package:preview_core/preview_core.dart';

void main() {
  // Initialize binding FIRST
  PreviewTestBinding.ensureInitialized();

  group('Phase 2: gRPC Frame Transmission', () {
    testWidgets('client receives frames via gRPC', (tester) async {
      final binding = PreviewTestBinding.instance;
      print('PHASE2: Binding type: ${binding.runtimeType}');

      // Start the gRPC server
      final serverUri = await binding.startServer();
      print('PHASE2: Server started at $serverUri');

      // Create a gRPC client
      final client = PreviewGrpcClient();
      final uri = Uri.parse(serverUri);
      await client.connect(uri.host, uri.port);
      print('PHASE2: Client connected');

      // Collect received frames
      final receivedFrames = <Frame>[];
      final completer = Completer<void>();

      final subscription = client.watchFrames().listen(
        (frame) {
          receivedFrames.add(frame);
          print(
              'PHASE2: Received frame ${receivedFrames.length}: ${frame.width}x${frame.height}, ${frame.rgbaData.length} bytes');
          if (receivedFrames.length >= 1 && !completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (e) {
          print('PHASE2: Stream error: $e');
        },
      );

      print('PHASE2: Watching frames...');

      // Pump a widget to generate frames
      await tester.pumpWidget(
        MaterialApp(
          home: Container(
            color: Colors.blue,
            child: const Center(
              child: Text(
                'Phase 2 Test',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
        ),
      );
      print('PHASE2: Widget pumped');

      await tester.pump();
      print('PHASE2: After pump');

      // Wait for at least one frame
      try {
        await completer.future.timeout(const Duration(seconds: 5));
        print('PHASE2: Received frames successfully');
      } catch (e) {
        print('PHASE2: Timeout waiting for frames');
      }

      // Cleanup
      await subscription.cancel();
      await client.disconnect();
      await binding.stopServer();

      // Assertions
      expect(receivedFrames, isNotEmpty,
          reason: 'Should receive at least one frame via gRPC');
      print('PHASE2: Total frames received: ${receivedFrames.length}');

      final frame = receivedFrames.first;
      expect(frame.width, greaterThan(0),
          reason: 'Frame width should be positive');
      expect(frame.height, greaterThan(0),
          reason: 'Frame height should be positive');
      expect(frame.rgbaData, isNotEmpty,
          reason: 'Frame should have pixel data');

      // Verify pixel data size matches dimensions
      final expectedBytes =
          frame.width * frame.height * 4; // RGBA = 4 bytes per pixel
      expect(frame.rgbaData.length, expectedBytes,
          reason: 'Pixel data size should match dimensions');

      // Verify it's not all zeros/transparent
      bool hasContent = false;
      for (int i = 3; i < frame.rgbaData.length && i < 10000; i += 4) {
        if (frame.rgbaData[i] > 0) {
          hasContent = true;
          break;
        }
      }
      expect(hasContent, isTrue, reason: 'Frame should have visible content');

      print(
          'PHASE2: SUCCESS - Frame validated: ${frame.width}x${frame.height}, ${frame.rgbaData.length} bytes');
    });

    test('gRPC server accepts multiple connections', () async {
      final binding = PreviewTestBinding.ensureInitialized();

      final serverUri = await binding.startServer();
      print('PHASE2B: Server at $serverUri');

      final uri = Uri.parse(serverUri);

      // Connect first client
      final client1 = PreviewGrpcClient();
      await client1.connect(uri.host, uri.port);
      print('PHASE2B: Client 1 connected');

      // Connect second client
      final client2 = PreviewGrpcClient();
      await client2.connect(uri.host, uri.port);
      print('PHASE2B: Client 2 connected');

      // Both should work
      expect(client1, isNotNull);
      expect(client2, isNotNull);

      await client1.disconnect();
      await client2.disconnect();
      await binding.stopServer();

      print('PHASE2B: SUCCESS - Multiple clients supported');
    });
  });
}
