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
  group('TestRunner.previewWidget', () {
    test('can preview a simple Container widget', () async {
      if (!await _hasFlutter()) {
        return;
      }

      // Assumes this test runs with cwd = packages/mcp_preview
      final packageRoot = Directory.current.path;
      final counterAppRoot = p.normalize(
        p.join(packageRoot, '..', '..', 'examples', 'counter_app'),
      );

      final result = await TestRunner.previewWidget(
        widgetCode: "Container(color: Colors.red, width: 100, height: 100)",
        projectPath: counterAppRoot,
        width: 400,
        height: 300,
      );

      expect(
        result.success,
        isTrue,
        reason:
            'previewWidget failed. Error: ${result.error}\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}',
      );
      expect(result.frames.length, greaterThan(0));

      // Verify the temp test file was cleaned up
      final testDir = Directory(p.join(counterAppRoot, 'test'));
      final tempFiles =
          testDir.listSync().where((f) => f.path.contains('_mcp_preview_'));
      expect(tempFiles, isEmpty,
          reason: 'Temp test files should be cleaned up');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
