# MCP Preview

A Model Context Protocol (MCP) server that enables AI assistants to run Flutter widget tests and see the rendered widget images.

## Overview

This MCP server provides tools for AI to:
- **Run widget tests** and capture rendered frames (one PNG per `pump()` call)
- **Query frame count** to know how many frames a test generated  
- **Retrieve specific frames** by index (e.g., "frame 4 of 10", "first", "last")
- **Get all frames** at once to see the complete test sequence

## Installation

### VS Code MCP Configuration

Add to your `.vscode/mcp.json`:

```json
{
  "servers": {
    "flutter-preview": {
      "type": "stdio",
      "command": "dart",
      "args": [
        "run",
        "--directory=/path/to/fontes_widget_viewer/packages/mcp_preview",
        "mcp_preview",
        "--fonts-path=/path/to/fonts"
      ]
    }
  }
}
```

### Options

- `--fonts-path`, `-f`: Path to fonts directory for consistent text rendering

## Tools

### `run_widget_test`

Run a Flutter widget test and capture rendered frames.

**Parameters:**
- `testFile` (required): Absolute path to the Flutter test file
- `testName` (optional): Specific test name to run (matches `testWidgets` name)
- `width` (optional): Logical viewport width (default: 800)
- `height` (optional): Logical viewport height (default: 600)  
- `devicePixelRatio` (optional): Device pixel ratio (default: 1.0)

**Returns:**
- Text summary with test result and frame count
- Image of the last captured frame (if any frames captured)

### `get_frame`

Get a specific frame from the last test run as a PNG image.

**Parameters:**
- `index`: Frame index selector:
  - JSON integer: 0-based (e.g. `0` is the first frame)
  - `"first"`/`"last"` (also accepts `-1` for last)
  - Numeric string: accepted for compatibility (e.g. `"1"`, `"10"`), treated as 1-based (`"1"` = first frame)

**Returns:**
- PNG image of the requested frame

### `list_frames`

List all captured frames from the last test run.

**Returns:**
- Text with frame count and metadata for each frame

### `get_all_frames`

Get all frames from the last test run as PNG images.

**Parameters:**
- `maxFrames` (optional): Maximum number of frames to return (default: all)

**Returns:**
- All captured frames as base64-encoded PNG images

## How It Works

1. The AI calls `run_widget_test` with a test file path
2. The server:
   - Injects `flutter_test_config.dart` if needed
   - Runs `flutter test` with preview dart-defines
   - Connects to the test's gRPC server to receive frames
   - Captures PNG for each `pump()` call
3. Returns frame count and last frame image
4. AI can request specific frames with `get_frame` or all frames with `get_all_frames`

## Requirements

- Flutter SDK installed and in PATH
- Test file must use `testWidgets()` with `pump()` calls
- Project must have `preview_binding` as a dependency

## Timeout

Tests have a default timeout of 40 seconds.
