import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:preview_core/preview_core.dart';

/// Result of running a widget test with preview
class TestRunResult {
  final List<Frame> frames;
  final String testName;
  final bool success;
  final String? error;
  final Duration duration;
  final String stdout;
  final String stderr;

  TestRunResult({
    required this.frames,
    required this.testName,
    required this.success,
    this.error,
    required this.duration,
    this.stdout = '',
    this.stderr = '',
  });
}

/// Runs Flutter widget tests and captures frames via gRPC
class TestRunner {
  static const Duration defaultTimeout = Duration(seconds: 40);

  /// Find the project root (directory containing pubspec.yaml) from a test file
  static String? findProjectRoot(String testFilePath) {
    var dir = Directory(p.dirname(testFilePath));
    while (dir.path != dir.parent.path) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return null;
  }

  /// Find the package root (where mcp_preview is located) for accessing templates
  static String? findPackageRoot() {
    // This will be set during runtime based on where the package is installed
    // For development, we'll look relative to the script location
    final scriptUri = Platform.script;
    if (scriptUri.scheme == 'file') {
      var dir = Directory(p.dirname(scriptUri.toFilePath()));
      // Walk up to find the mcp_preview package root
      while (dir.path != dir.parent.path) {
        if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
          final pubspec =
              File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync();
          if (pubspec.contains('name: mcp_preview')) {
            return dir.path;
          }
        }
        dir = dir.parent;
      }
    }
    return null;
  }

  /// Run a widget test and capture frames
  ///
  /// [testFilePath] - Absolute path to the test file
  /// [testName] - Optional specific test name to run (uses --name flag)
  /// [timeout] - Maximum time to wait for test completion (default 40s)
  /// [fontsPath] - Optional path to fonts directory for consistent rendering
  /// [width] - Optional logical width for the test viewport
  /// [height] - Optional logical height for the test viewport
  /// [devicePixelRatio] - Optional device pixel ratio (default 1.0)
  static Future<TestRunResult> runTest({
    required String testFilePath,
    String? testName,
    Duration timeout = defaultTimeout,
    String? fontsPath,
    int? width,
    int? height,
    double? devicePixelRatio,
  }) async {
    final stopwatch = Stopwatch()..start();
    final frames = <Frame>[];

    // Find project root
    final projectRoot = findProjectRoot(testFilePath);
    if (projectRoot == null) {
      return TestRunResult(
        frames: [],
        testName: testName ?? p.basename(testFilePath),
        success: false,
        error: 'Could not find project root (pubspec.yaml) for: $testFilePath',
        duration: stopwatch.elapsed,
      );
    }

    // Ensure flutter_test_config.dart exists in the test directory
    final testDir = p.dirname(testFilePath);
    final configPath = p.join(testDir, 'flutter_test_config.dart');
    if (!File(configPath).existsSync()) {
      // Try to copy from template
      final templatePath = _findTemplateConfig();
      if (templatePath != null && File(templatePath).existsSync()) {
        File(templatePath).copySync(configPath);
      } else {
        return TestRunResult(
          frames: [],
          testName: testName ?? p.basename(testFilePath),
          success: false,
          error:
              'flutter_test_config.dart not found in test directory and no template available',
          duration: stopwatch.elapsed,
        );
      }
    }

    // Build dart-defines
    final dartDefines = <String>[
      '--dart-define=ENABLE_PREVIEW=true',
    ];

    if (fontsPath != null) {
      dartDefines.add('--dart-define=PREVIEW_FONTS_PATH=$fontsPath');
    }
    if (width != null) {
      dartDefines.add('--dart-define=PREVIEW_WIDTH=$width');
    }
    if (height != null) {
      dartDefines.add('--dart-define=PREVIEW_HEIGHT=$height');
    }
    if (devicePixelRatio != null) {
      dartDefines
          .add('--dart-define=PREVIEW_DEVICE_PIXEL_RATIO=$devicePixelRatio');
    }

    // Build flutter test command
    final args = [
      'test',
      testFilePath,
      ...dartDefines,
    ];

    if (testName != null) {
      args.addAll(['--name', testName]);
    }

    // Start flutter test process
    final process = await Process.start(
      'flutter',
      args,
      workingDirectory: projectRoot,
    );

    // Capture stdout/stderr for debugging
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    PreviewGrpcClient? grpcClient;
    StreamSubscription<Frame>? frameSubscription;

    // Completer to signal when gRPC connection is ready
    final grpcConnectedCompleter = Completer<void>();
    bool grpcConnected = false;

    // Completer to signal when drain is complete (test finished)
    final drainCompleteCompleter = Completer<void>();

    // Parse stdout for gRPC port and status messages
    process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdoutBuffer.writeln(line);

      // Look for GRPC_SERVER_STARTED:<port>
      final grpcMatch = RegExp(r'GRPC_SERVER_STARTED:(\d+)').firstMatch(line);
      if (grpcMatch != null && !grpcConnected) {
        grpcConnected = true;
        final port = int.parse(grpcMatch.group(1)!);

        // Connect to gRPC immediately and signal when done
        _connectToGrpc(port, frames).then((result) {
          grpcClient = result.$1;
          frameSubscription = result.$2;
          if (!grpcConnectedCompleter.isCompleted) {
            grpcConnectedCompleter.complete();
          }
        }).catchError((e) {
          if (!grpcConnectedCompleter.isCompleted) {
            grpcConnectedCompleter.completeError(e);
          }
        });
      }

      // Look for PREVIEW_DRAIN_COMPLETE - test is done
      if (line.contains('PREVIEW_DRAIN_COMPLETE') &&
          !drainCompleteCompleter.isCompleted) {
        drainCompleteCompleter.complete();
      }
    });

    process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrBuffer.writeln(line);
    });

    // Wait for drain complete or process exit or timeout
    try {
      // Race between: process exit, drain complete signal, or timeout
      final exitCodeFuture = process.exitCode;
      final drainFuture = drainCompleteCompleter.future;

      // Wait for either drain complete or process exit
      await Future.any([
        exitCodeFuture,
        drainFuture.then((_) async {
          // Give a moment for any remaining frames
          await Future.delayed(const Duration(milliseconds: 500));
        }),
      ]).timeout(timeout);

      // Wait for gRPC to be connected (should already be done)
      if (grpcConnected && !grpcConnectedCompleter.isCompleted) {
        await grpcConnectedCompleter.future.timeout(const Duration(seconds: 5));
      }

      // Give a moment for any remaining frames to arrive
      await Future.delayed(const Duration(milliseconds: 200));

      // Cleanup - disconnect gRPC first to allow test to exit
      await frameSubscription?.cancel();
      await grpcClient?.disconnect();

      // Kill the process if it's still running
      process.kill();

      stopwatch.stop();

      // Check if test passed (look for test success in output)
      final success = stdoutBuffer.toString().contains('+1:') ||
          stdoutBuffer.toString().contains('All tests passed');

      return TestRunResult(
        frames: frames,
        testName: testName ?? p.basename(testFilePath),
        success: success,
        duration: stopwatch.elapsed,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
      );
    } on TimeoutException {
      process.kill();
      await frameSubscription?.cancel();
      await grpcClient?.disconnect();
      stopwatch.stop();

      return TestRunResult(
        frames: frames,
        testName: testName ?? p.basename(testFilePath),
        success: false,
        error:
            'Test timed out after ${timeout.inSeconds} seconds\nstdout: ${stdoutBuffer.toString()}',
        duration: stopwatch.elapsed,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
      );
    }
  }

  /// Connect to the test's gRPC server and start collecting frames
  static Future<(PreviewGrpcClient, StreamSubscription<Frame>)> _connectToGrpc(
    int port,
    List<Frame> frames,
  ) async {
    final client = PreviewGrpcClient();
    await client.connect('localhost', port);

    final subscription = client.watchFrames().listen(
      (frame) {
        // Filter out empty/invalid frames
        if (frame.width > 0 && frame.height > 0 && frame.rgbaData.isNotEmpty) {
          frames.add(frame);
        }
      },
      onError: (e) {
        // Test may have ended, ignore errors
      },
    );

    return (client, subscription);
  }

  /// Find the flutter_test_config.dart template
  static String? _findTemplateConfig() {
    // Look for template in known locations relative to this package
    final possiblePaths = [
      // Development: relative to mcp_preview package
      p.join(findPackageRoot() ?? '', '..', '..', 'extension', 'templates',
          'flutter_test_config.dart'),
      // Installed: might be in a templates subdirectory
      p.join(findPackageRoot() ?? '', 'templates', 'flutter_test_config.dart'),
    ];

    for (final path in possiblePaths) {
      final normalized = p.normalize(path);
      if (File(normalized).existsSync()) {
        return normalized;
      }
    }
    return null;
  }

  /// Preview arbitrary widget code without a pre-existing test file.
  ///
  /// This generates a temporary test file with the widget code wrapped in
  /// a proper test structure, runs it, captures frames, and cleans up.
  ///
  /// [widgetCode] - Dart code that returns a Widget (e.g., "Container(color: Colors.red)")
  /// [imports] - Optional list of additional import statements (without 'import' keyword)
  /// [projectPath] - Path to a Flutter project to use for running the test
  static Future<TestRunResult> previewWidget({
    required String widgetCode,
    List<String>? imports,
    String? projectPath,
    Duration timeout = defaultTimeout,
    String? fontsPath,
    int? width,
    int? height,
    double? devicePixelRatio,
  }) async {
    // Find or create a project to run the test in
    final effectiveProjectPath = projectPath ?? _findPreviewProject();
    if (effectiveProjectPath == null) {
      return TestRunResult(
        frames: [],
        testName: 'preview_widget',
        success: false,
        error:
            'No Flutter project found. Provide a projectPath or run from within a Flutter project.',
        duration: Duration.zero,
      );
    }

    // Create a unique temporary test file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testDir = p.join(effectiveProjectPath, 'test');
    final tempTestFile = p.join(testDir, '_mcp_preview_$timestamp.dart');

    // Build imports section
    final importStatements = StringBuffer();
    importStatements.writeln("import 'package:flutter/material.dart';");
    importStatements
        .writeln("import 'package:flutter_test/flutter_test.dart';");
    if (imports != null) {
      for (final imp in imports) {
        if (imp.startsWith('import ')) {
          importStatements.writeln(imp);
        } else {
          importStatements.writeln("import '$imp';");
        }
      }
    }

    // Generate the test file content
    final testContent = '''
${importStatements.toString()}

void main() {
  testWidgets('MCP Preview Widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: $widgetCode,
          ),
        ),
      ),
    );
    await tester.pump();
  });
}
''';

    try {
      // Ensure test directory exists
      Directory(testDir).createSync(recursive: true);

      // Write the temporary test file
      File(tempTestFile).writeAsStringSync(testContent);

      // Run the test
      final result = await runTest(
        testFilePath: tempTestFile,
        testName: 'MCP Preview Widget',
        timeout: timeout,
        fontsPath: fontsPath,
        width: width,
        height: height,
        devicePixelRatio: devicePixelRatio,
      );

      return result;
    } finally {
      // Clean up the temporary test file
      try {
        final tempFile = File(tempTestFile);
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }

  /// Find a Flutter project for preview tests
  static String? _findPreviewProject() {
    // Look for a preview project in known locations
    final possiblePaths = [
      // Check current working directory
      Directory.current.path,
      // Check relative to mcp_preview package
      p.join(findPackageRoot() ?? '', '..', 'preview_core'),
    ];

    for (final path in possiblePaths) {
      final normalized = p.normalize(path);
      if (File(p.join(normalized, 'pubspec.yaml')).existsSync()) {
        return normalized;
      }
    }
    return null;
  }
}
