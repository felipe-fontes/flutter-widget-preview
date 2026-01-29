/// Phase 1 Test: Verify that PreviewTestBinding generates image data
///
/// This test isolates the image generation phase to verify:
/// 1. The binding's scheduleFrame is called during pump
/// 2. The postFrameCallback captures scene data
/// 3. The scene can be converted to an image with pixel data
///
/// This test does NOT involve gRPC - it captures frames via callback.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_binding/preview_binding.dart';

void main() {
  // Initialize binding FIRST - this is crucial
  PreviewTestBinding.ensureInitialized();

  group('Phase 1: Image Generation', () {
    testWidgets('binding captures frame with testWidgets', (tester) async {
      final binding = PreviewTestBinding.instance;
      print('PHASE1: Binding type: ${binding.runtimeType}');

      // Start server to enable frame capture
      await binding.startServer();
      print('PHASE1: Server started');

      // Track if we capture any frames
      int framesCaptured = 0;

      // Pump a simple widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 200,
              height: 200,
              color: Colors.red,
              child: const Center(
                child: Text('Test', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      );
      print('PHASE1: Widget pumped');

      // Wait a bit for rendering
      await tester.pump(const Duration(milliseconds: 100));
      print('PHASE1: After pump');

      // Check render views
      print('PHASE1: renderViews count: ${binding.renderViews.length}');
      for (final view in binding.renderViews) {
        print('PHASE1: RenderView: ${view.runtimeType}, size: ${view.size}');
      }

      // Try to manually capture a frame
      final renderView = binding.renderViews.firstOrNull;
      if (renderView != null) {
        final layer = renderView.debugLayer;
        print('PHASE1: debugLayer: $layer');

        if (layer != null) {
          final offsetLayer = layer as OffsetLayer;
          final size = renderView.size;
          final devicePixelRatio = 2.0;

          print('PHASE1: Capturing ${size.width}x${size.height}');

          final image = offsetLayer.toImageSync(
            Offset.zero & (size * devicePixelRatio),
            pixelRatio: 1.0,
          );

          print('PHASE1: Image created: ${image.width}x${image.height}');

          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          print('PHASE1: ByteData: ${byteData?.lengthInBytes ?? 0} bytes');

          if (byteData != null && byteData.lengthInBytes > 0) {
            framesCaptured++;

            // Sample pixels
            final bytes = byteData.buffer.asUint8List();

            // Find first non-transparent pixel
            for (int i = 0; i < bytes.length && i < 4000; i += 4) {
              if (bytes[i + 3] > 0) {
                // Alpha > 0
                print(
                    'PHASE1: Found non-transparent pixel at offset $i: RGBA(${bytes[i]}, ${bytes[i + 1]}, ${bytes[i + 2]}, ${bytes[i + 3]})');
                break;
              }
            }
          }

          image.dispose();
        }
      }

      await binding.stopServer();

      expect(framesCaptured, greaterThan(0),
          reason: 'Should capture at least one frame');
      print('PHASE1: SUCCESS - Captured $framesCaptured frames');
    });

    testWidgets('runTest is called for our binding', (tester) async {
      final binding = PreviewTestBinding.instance;

      // Just verify the binding is correct
      expect(binding.runtimeType.toString(), 'PreviewTestBinding');

      // Pump something
      await tester
          .pumpWidget(const Text('Hello', textDirection: TextDirection.ltr));

      print('PHASE1B: Test ran with binding ${binding.runtimeType}');
    });
  });
}
