import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:preview_core/preview_core.dart';

import 'image_converter.dart';
import 'test_runner.dart';

/// MCP Server for Flutter widget test preview
///
/// Implements the Model Context Protocol (JSON-RPC 2.0 over stdio)
/// to expose Flutter widget rendering capabilities to AI assistants.
///
/// Tools provided:
/// - `run_widget_test`: Run a widget test and capture frames
/// - `get_frame`: Get a specific frame as PNG image
/// - `list_frames`: List all captured frames with metadata
class McpServer {
  /// Cached frames from the last test run
  final List<Frame> _cachedFrames = [];
  String? _lastTestName;
  String? _lastTestFile;

  /// Path to fonts directory for consistent rendering
  final String? fontsPath;

  McpServer({this.fontsPath});

  /// Start the MCP server (reads from stdin, writes to stdout)
  Future<void> run() async {
    // Read JSON-RPC messages from stdin
    // The server waits for the client to send 'initialize' first
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      try {
        final message = jsonDecode(line) as Map<String, dynamic>;
        await _handleMessage(message);
      } catch (e) {
        _sendError(null, -32700, 'Parse error: $e');
      }
    }
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {
    final method = message['method'] as String?;
    final id = message['id'];
    final params = message['params'] as Map<String, dynamic>? ?? {};

    if (method == null) {
      _sendError(id, -32600, 'Invalid request: missing method');
      return;
    }

    switch (method) {
      case 'initialize':
        _handleInitialize(id, params);
        break;
      case 'tools/list':
        _handleToolsList(id);
        break;
      case 'tools/call':
        await _handleToolsCall(id, params);
        break;
      case 'notifications/initialized':
        // Client initialized, nothing to do
        break;
      default:
        _sendError(id, -32601, 'Method not found: $method');
    }
  }

  void _handleInitialize(dynamic id, Map<String, dynamic> params) {
    _sendResult(id, {
      'protocolVersion': '2024-11-05',
      'capabilities': {
        'tools': {},
      },
      'serverInfo': {
        'name': 'mcp_preview',
        'version': '0.1.0',
      },
    });
  }

  void _handleToolsList(dynamic id) {
    _sendResult(id, {
      'tools': [
        {
          'name': 'run_widget_test',
          'description':
              '''Run a Flutter widget test and capture rendered frames.
            
This tool executes a Flutter widget test with preview enabled, capturing a PNG image
for each pump() call. Returns the number of frames captured and the test result.

Use this to visually verify widget rendering during test execution.''',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'testFile': {
                'type': 'string',
                'description': 'Absolute path to the Flutter test file',
              },
              'testName': {
                'type': 'string',
                'description':
                    'Optional: specific test name to run (matches testWidgets name)',
              },
              'width': {
                'type': 'integer',
                'description':
                    'Optional: logical viewport width (default: 800)',
              },
              'height': {
                'type': 'integer',
                'description':
                    'Optional: logical viewport height (default: 600)',
              },
              'devicePixelRatio': {
                'type': 'number',
                'description': 'Optional: device pixel ratio (default: 1.0)',
              },
            },
            'required': ['testFile'],
          },
        },
        {
          'name': 'get_frame',
          'description':
              '''Get a specific frame from the last test run as a PNG image.

Use index to get a specific frame (0-based), or use special values:
- "last" or -1: Get the last frame
- "first" or 0: Get the first frame

The image is returned as base64-encoded PNG data.''',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'index': {
                'oneOf': [
                  {'type': 'integer'},
                  {
                    'type': 'string',
                    'enum': ['first', 'last']
                  },
                ],
                'description': 'Frame index (0-based), or "first"/"last"',
              },
            },
            'required': ['index'],
          },
        },
        {
          'name': 'list_frames',
          'description': '''List all captured frames from the last test run.

Returns metadata for each frame including index, dimensions, and timestamp.
Use this to see how many frames were captured before requesting specific frames.''',
          'inputSchema': {
            'type': 'object',
            'properties': {},
          },
        },
        {
          'name': 'get_all_frames',
          'description': '''Get all frames from the last test run as PNG images.

Returns all captured frames as base64-encoded PNG images.
Warning: This may return a large amount of data if many frames were captured.''',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'maxFrames': {
                'type': 'integer',
                'description':
                    'Optional: maximum number of frames to return (default: all)',
              },
            },
          },
        },
        {
          'name': 'preview_widget',
          'description':
              '''Preview arbitrary Flutter widget code without creating a test file.

This tool generates a temporary test, runs it to capture the widget rendering,
and returns the visual output. Perfect for AI-assisted UI development:

1. AI creates widget code based on user requirements or design mockups
2. AI calls preview_widget to see how it renders
3. AI can compare the result to design and iterate

The widget code should be a valid Dart expression that returns a Widget.
Examples:
- "Container(color: Colors.red, width: 100, height: 100)"
- "Text('Hello World', style: TextStyle(fontSize: 24))"
- "Column(children: [Icon(Icons.star), Text('Rating')])"''',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'widgetCode': {
                'type': 'string',
                'description':
                    'Dart code that evaluates to a Widget (e.g., "Container(color: Colors.red)")',
              },
              'imports': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'Optional: additional import statements needed (e.g., ["package:my_app/widgets.dart"])',
              },
              'projectPath': {
                'type': 'string',
                'description':
                    'Optional: path to Flutter project for running the test. If not provided, uses workspace default.',
              },
              'width': {
                'type': 'integer',
                'description':
                    'Optional: logical viewport width (default: 800)',
              },
              'height': {
                'type': 'integer',
                'description':
                    'Optional: logical viewport height (default: 600)',
              },
              'devicePixelRatio': {
                'type': 'number',
                'description': 'Optional: device pixel ratio (default: 1.0)',
              },
            },
            'required': ['widgetCode'],
          },
        },
      ],
    });
  }

  Future<void> _handleToolsCall(dynamic id, Map<String, dynamic> params) async {
    final toolName = params['name'] as String?;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

    if (toolName == null) {
      _sendError(id, -32602, 'Invalid params: missing tool name');
      return;
    }

    switch (toolName) {
      case 'run_widget_test':
        await _runWidgetTest(id, arguments);
        break;
      case 'get_frame':
        await _getFrame(id, arguments);
        break;
      case 'list_frames':
        _listFrames(id);
        break;
      case 'get_all_frames':
        _getAllFrames(id, arguments);
        break;
      case 'preview_widget':
        await _previewWidget(id, arguments);
        break;
      default:
        _sendError(id, -32602, 'Unknown tool: $toolName');
    }
  }

  Future<void> _runWidgetTest(dynamic id, Map<String, dynamic> args) async {
    final testFile = args['testFile'] as String?;
    if (testFile == null) {
      _sendError(id, -32602, 'Missing required parameter: testFile');
      return;
    }

    final testName = args['testName'] as String?;
    final width = args['width'] as int?;
    final height = args['height'] as int?;
    final devicePixelRatio = (args['devicePixelRatio'] as num?)?.toDouble();

    try {
      final result = await TestRunner.runTest(
        testFilePath: testFile,
        testName: testName,
        fontsPath: fontsPath,
        width: width ?? 800,
        height: height ?? 600,
        devicePixelRatio: devicePixelRatio ?? 1.0,
      );

      // Cache frames for subsequent get_frame calls
      _cachedFrames.clear();
      _cachedFrames.addAll(result.frames);
      _lastTestName = result.testName;
      _lastTestFile = testFile;

      // Build response content
      final content = <Map<String, dynamic>>[];

      // Add text summary
      content.add({
        'type': 'text',
        'text':
            '''Test ${result.success ? 'passed' : 'failed'}: ${result.testName}
Frames captured: ${result.frames.length}
Duration: ${result.duration.inMilliseconds}ms
${result.error != null ? 'Error: ${result.error}' : ''}

${result.frames.isEmpty ? 'No frames were captured. Make sure the test calls pump() and uses preview_binding.' : 'Use get_frame to retrieve specific frames, or list_frames to see all captured frames.'}''',
      });

      // If we have frames, include the last frame as an image
      if (result.frames.isNotEmpty) {
        final lastFrame = result.frames.last;
        final pngBytes = ImageConverter.rgbaToPng(
          lastFrame.rgbaData,
          width: lastFrame.width,
          height: lastFrame.height,
        );
        content.add({
          'type': 'image',
          'data': base64Encode(pngBytes),
          'mimeType': 'image/png',
        });
        content.add({
          'type': 'text',
          'text':
              '(Above: last frame - ${lastFrame.width}x${lastFrame.height}px)',
        });
      }

      _sendResult(id, {
        'content': content,
        'isError': !result.success,
      });
    } catch (e) {
      _sendError(id, -32603, 'Test execution failed: $e');
    }
  }

  Future<void> _getFrame(dynamic id, Map<String, dynamic> args) async {
    if (_cachedFrames.isEmpty) {
      _sendResult(id, {
        'content': [
          {
            'type': 'text',
            'text':
                'No frames available. Run a test first using run_widget_test.',
          }
        ],
      });
      return;
    }

    final indexArg = args['index'];
    int index;

    if (indexArg is String) {
      switch (indexArg) {
        case 'first':
          index = 0;
          break;
        case 'last':
          index = _cachedFrames.length - 1;
          break;
        default:
          _sendError(id, -32602,
              'Invalid index: $indexArg. Use integer, "first", or "last".');
          return;
      }
    } else if (indexArg is int) {
      if (indexArg == -1) {
        index = _cachedFrames.length - 1;
      } else {
        index = indexArg;
      }
    } else {
      _sendError(id, -32602, 'Invalid index type');
      return;
    }

    if (index < 0 || index >= _cachedFrames.length) {
      _sendResult(id, {
        'content': [
          {
            'type': 'text',
            'text':
                'Frame index out of range. Available frames: 0-${_cachedFrames.length - 1} (total: ${_cachedFrames.length})',
          }
        ],
      });
      return;
    }

    final frame = _cachedFrames[index];
    final pngBytes = ImageConverter.rgbaToPng(
      frame.rgbaData,
      width: frame.width,
      height: frame.height,
    );

    _sendResult(id, {
      'content': [
        {
          'type': 'text',
          'text':
              'Frame ${index + 1} of ${_cachedFrames.length} (${frame.width}x${frame.height}px)',
        },
        {
          'type': 'image',
          'data': base64Encode(pngBytes),
          'mimeType': 'image/png',
        },
      ],
    });
  }

  void _listFrames(dynamic id) {
    if (_cachedFrames.isEmpty) {
      _sendResult(id, {
        'content': [
          {
            'type': 'text',
            'text':
                'No frames available. Run a test first using run_widget_test.',
          }
        ],
      });
      return;
    }

    final frameList = _cachedFrames.asMap().entries.map((e) {
      final frame = e.value;
      return '  ${e.key}: ${frame.width}x${frame.height}px @ ${frame.devicePixelRatio}x (${frame.testName})';
    }).join('\n');

    _sendResult(id, {
      'content': [
        {
          'type': 'text',
          'text': '''Captured frames from: $_lastTestName
Test file: $_lastTestFile
Total frames: ${_cachedFrames.length}

Frames:
$frameList

Use get_frame with index 0-${_cachedFrames.length - 1}, or "first"/"last" to retrieve a specific frame.''',
        }
      ],
    });
  }

  void _getAllFrames(dynamic id, Map<String, dynamic> args) {
    if (_cachedFrames.isEmpty) {
      _sendResult(id, {
        'content': [
          {
            'type': 'text',
            'text':
                'No frames available. Run a test first using run_widget_test.',
          }
        ],
      });
      return;
    }

    final maxFrames = args['maxFrames'] as int?;
    final framesToReturn = maxFrames != null && maxFrames < _cachedFrames.length
        ? _cachedFrames.sublist(0, maxFrames)
        : _cachedFrames;

    final content = <Map<String, dynamic>>[
      {
        'type': 'text',
        'text':
            'Returning ${framesToReturn.length} of ${_cachedFrames.length} frames from: $_lastTestName',
      }
    ];

    for (var i = 0; i < framesToReturn.length; i++) {
      final frame = framesToReturn[i];
      final pngBytes = ImageConverter.rgbaToPng(
        frame.rgbaData,
        width: frame.width,
        height: frame.height,
      );
      content.add({
        'type': 'text',
        'text':
            'Frame ${i + 1}/${framesToReturn.length} (${frame.width}x${frame.height}px):',
      });
      content.add({
        'type': 'image',
        'data': base64Encode(pngBytes),
        'mimeType': 'image/png',
      });
    }

    _sendResult(id, {'content': content});
  }

  Future<void> _previewWidget(dynamic id, Map<String, dynamic> args) async {
    final widgetCode = args['widgetCode'] as String?;
    if (widgetCode == null || widgetCode.trim().isEmpty) {
      _sendError(id, -32602, 'Missing required parameter: widgetCode');
      return;
    }

    final imports = (args['imports'] as List<dynamic>?)?.cast<String>();
    final projectPath = args['projectPath'] as String?;
    final width = args['width'] as int?;
    final height = args['height'] as int?;
    final devicePixelRatio = (args['devicePixelRatio'] as num?)?.toDouble();

    try {
      final result = await TestRunner.previewWidget(
        widgetCode: widgetCode,
        imports: imports,
        projectPath: projectPath,
        fontsPath: fontsPath,
        width: width ?? 800,
        height: height ?? 600,
        devicePixelRatio: devicePixelRatio ?? 1.0,
      );

      // Cache frames for subsequent get_frame calls
      _cachedFrames.clear();
      _cachedFrames.addAll(result.frames);
      _lastTestName = 'preview_widget';
      _lastTestFile = 'inline widget code';

      // Build response content
      final content = <Map<String, dynamic>>[];

      // Add text summary
      content.add({
        'type': 'text',
        'text': '''Widget preview ${result.success ? 'completed' : 'failed'}
Frames captured: ${result.frames.length}
Duration: ${result.duration.inMilliseconds}ms
${result.error != null ? 'Error: ${result.error}' : ''}

Widget code:
```dart
$widgetCode
```''',
      });

      // If we have frames, include the last frame as an image
      if (result.frames.isNotEmpty) {
        final lastFrame = result.frames.last;
        final pngBytes = ImageConverter.rgbaToPng(
          lastFrame.rgbaData,
          width: lastFrame.width,
          height: lastFrame.height,
        );
        content.add({
          'type': 'image',
          'data': base64Encode(pngBytes),
          'mimeType': 'image/png',
        });
        content.add({
          'type': 'text',
          'text': '(Preview: ${lastFrame.width}x${lastFrame.height}px)',
        });
      } else {
        content.add({
          'type': 'text',
          'text':
              '\nNo frames captured. Check that the widget code is valid and compiles correctly.',
        });
        // Include stderr if available for debugging
        if (result.stderr.isNotEmpty) {
          content.add({
            'type': 'text',
            'text': '\nTest output:\n${result.stderr}',
          });
        }
      }

      _sendResult(id, {
        'content': content,
        'isError': !result.success,
      });
    } catch (e) {
      _sendError(id, -32603, 'Preview failed: $e');
    }
  }

  void _sendResult(dynamic id, Map<String, dynamic> result) {
    _sendResponse({
      'jsonrpc': '2.0',
      'result': result,
      'id': id,
    });
  }

  void _sendError(dynamic id, int code, String message) {
    _sendResponse({
      'jsonrpc': '2.0',
      'error': {
        'code': code,
        'message': message,
      },
      'id': id,
    });
  }

  void _sendResponse(Map<String, dynamic> response) {
    stdout.writeln(jsonEncode(response));
  }
}
