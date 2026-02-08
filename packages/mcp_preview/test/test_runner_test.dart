import 'dart:io';

import 'package:mcp_preview/src/test_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<bool> _hasFlutter() async {
  try {
    final result = await Process.run('flutter', ['--version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

void main() {
  group('TestRunner.runTest', () {
    test('runs counter_app widget_test and captures frames/logs', () async {
      if (!await _hasFlutter()) {
        return;
      }

      // Assumes this test runs with cwd = packages/mcp_preview
      final packageRoot = Directory.current.path;
      final counterAppRoot = p.normalize(
        p.join(packageRoot, '..', '..', 'examples', 'counter_app'),
      );
      final testFile = p.join(counterAppRoot, 'test', 'widget_test.dart');
      final fontsPath = p.normalize(
        p.join(packageRoot, '..', '..', 'extension', 'fonts'),
      );

      if (!File(testFile).existsSync()) {
        fail('Expected test file not found: $testFile');
      }

      final result = await TestRunner.runTest(
        testFilePath: testFile,
        testName: 'Counter increments smoke test',
        fontsPath: fontsPath,
        width: 400,
        height: 600,
        devicePixelRatio: 1.0,
        timeout: const Duration(seconds: 60),
      );

      // This is an integration-style test that depends on Flutter.
      // If it fails, include stderr/stdout for debugging.
      expect(
        result.success,
        isTrue,
        reason:
            'runTest failed. Error: ${result.error}\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}',
      );
      expect(result.frames.length, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 120)));
  });
}
