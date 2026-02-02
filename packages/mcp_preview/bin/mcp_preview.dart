import 'dart:io';

import 'package:args/args.dart';
import 'package:mcp_preview/mcp_preview.dart';

/// MCP Preview Server - Widget Test Preview for AI Assistants
///
/// This MCP server enables AI assistants to run Flutter widget tests
/// and see the rendered widget images. Perfect for visual debugging
/// and widget development with AI assistance.
///
/// Usage:
///   dart run mcp_preview [options]
///
/// Options:
///   --fonts-path         Path to fonts directory for consistent rendering
///   --flutter-sdk-path   Path to Flutter SDK root (for MaterialIcons font)
///   --help               Show this help message
void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'fonts-path',
      abbr: 'f',
      help: 'Path to fonts directory for consistent rendering',
    )
    ..addOption(
      'flutter-sdk-path',
      abbr: 's',
      help: 'Path to Flutter SDK root (for MaterialIcons font)',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    );

  try {
    final results = parser.parse(args);

    if (results['help'] as bool) {
      _printUsage(parser);
      exit(0);
    }

    final fontsPath = results['fonts-path'] as String?;
    final flutterSdkPath = results['flutter-sdk-path'] as String?;
    final server =
        McpServer(fontsPath: fontsPath, flutterSdkPath: flutterSdkPath);

    // Disable stdout buffering for real-time communication
    stdout.nonBlocking;

    await server.run();
  } catch (e) {
    stderr.writeln('Error: $e');
    _printUsage(parser);
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  stderr.writeln('''
MCP Preview Server - Widget Test Preview for AI Assistants

This MCP server enables AI assistants to run Flutter widget tests
and see the rendered widget images.

Tools provided:
  run_widget_test  - Run a Flutter widget test and capture frames
  get_frame        - Get a specific frame as PNG image
  list_frames      - List all captured frames with metadata

Options:
${parser.usage}

Example MCP configuration (mcp.json):
{
  "mcpServers": {
    "flutter-preview": {
      "command": "dart",
      "args": ["run", "mcp_preview", "--fonts-path", "/path/to/fonts"]
    }
  }
}
''');
}
