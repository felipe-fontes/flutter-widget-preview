import 'dart:io';

import 'package:mcp_preview/src/test_runner.dart';
import 'package:test/test.dart';

void main() {
  group('TestRunner.previewWidget', () {
    test('can preview a simple Container widget', () async {
      // Use counter_app which is a proper Flutter project with preview_binding
      final result = await TestRunner.previewWidget(
        widgetCode: "Container(color: Colors.red, width: 100, height: 100)",
        projectPath:
            '/Users/felipesantos/code/dartvm-preview/fontes_widget_viewer/examples/counter_app',
        width: 400,
        height: 300,
      );

      print('Success: ${result.success}');
      print('Frames: ${result.frames.length}');
      print('Duration: ${result.duration}');
      print('Error: ${result.error}');
      print('stdout: ${result.stdout}');
      print('stderr: ${result.stderr}');

      // Verify the temp test file was cleaned up
      final testDir = Directory(
          '/Users/felipesantos/code/dartvm-preview/fontes_widget_viewer/examples/counter_app/test');
      final tempFiles =
          testDir.listSync().where((f) => f.path.contains('_mcp_preview_'));
      expect(tempFiles, isEmpty,
          reason: 'Temp test files should be cleaned up');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
