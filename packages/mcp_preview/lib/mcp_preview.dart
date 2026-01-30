/// MCP Preview - Model Context Protocol server for Flutter widget test preview
///
/// This package provides an MCP server that enables AI assistants to:
/// - Run Flutter widget tests and capture rendered frames
/// - Query frame count from a test
/// - Retrieve specific frames by index (e.g., "frame 4 of 10" or "last")
/// - Get frames as base64-encoded PNG images
library;

export 'src/mcp_server.dart';
export 'src/test_runner.dart';
export 'src/image_converter.dart';
