// A simple test script to validate the TestRunner directly
// Run with: dart run test/test_runner_test.dart

import 'dart:io';


import 'package:mcp_preview/src/test_runner.dart';
import 'package:mcp_preview/src/image_converter.dart';

void main() async {
  print('Testing TestRunner...\n');

  final testFile = '/Users/felipesantos/code/dartvm-preview/fontes_widget_viewer/examples/counter_app/test/widget_test.dart';
  final fontsPath = '/Users/felipesantos/code/dartvm-preview/fontes_widget_viewer/extension/fonts';

  print('Running widget test: $testFile');
  print('Test name: Counter increments smoke test');
  print('Fonts path: $fontsPath');
  print('Viewport: 400x600');
  print('Timeout: 40 seconds');
  print('');
  print('Starting test...\n');

  final result = await TestRunner.runTest(
    testFilePath: testFile,
    testName: 'Counter increments smoke test',
    fontsPath: fontsPath,
    width: 400,
    height: 600,
    devicePixelRatio: 1.0,
    timeout: const Duration(seconds: 40),
  );

  print('\n--- Results ---');
  print('Success: ${result.success}');
  print('Test name: ${result.testName}');
  print('Duration: ${result.duration.inMilliseconds}ms');
  print('Frames captured: ${result.frames.length}');
  
  if (result.error != null) {
    print('Error: ${result.error}');
  }

  if (result.frames.isNotEmpty) {
    print('\nFrame details:');
    for (var i = 0; i < result.frames.length; i++) {
      final frame = result.frames[i];
      print('  Frame $i: ${frame.width}x${frame.height} @ ${frame.devicePixelRatio}x');
    }

    // Save the last frame as a PNG file
    final lastFrame = result.frames.last;
    final pngBytes = ImageConverter.rgbaToPng(
      lastFrame.rgbaData,
      width: lastFrame.width,
      height: lastFrame.height,
    );

    final outputPath = '/tmp/mcp_preview_test_frame.png';
    File(outputPath).writeAsBytesSync(pngBytes);
    print('\nLast frame saved to: $outputPath');
    print('PNG size: ${pngBytes.length} bytes');
  }

  print('\n--- stdout ---');
  print(result.stdout);

  if (result.stderr.isNotEmpty) {
    print('\n--- stderr ---');
    print(result.stderr);
  }

  exit(result.success ? 0 : 1);
}
