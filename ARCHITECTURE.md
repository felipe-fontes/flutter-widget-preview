# Fontes Widget Viewer - Architecture

A VS Code extension that provides real-time widget preview for Flutter tests.

## Overview

When you run a Flutter widget test with preview enabled, the extension:
1. Captures rendered frames during test execution
2. Streams frames via gRPC to a viewer server  
3. Relays frames to a WebSocket-connected browser in VS Code

```
┌─────────────────────┐     gRPC      ┌─────────────────────┐   WebSocket   ┌─────────────────────┐
│   Flutter Test      │ ──────────▶   │   Viewer Server     │ ──────────▶   │   VS Code Webview   │
│   (preview_binding) │               │   (preview_viewer)  │               │                     │
└─────────────────────┘               └─────────────────────┘               └─────────────────────┘
         │                                     │                                      │
         │ Renders frames                      │ Caches ALL frames                    │ Displays
         │ on pump() calls                     │ for late connections                 │ frame timeline
         │                                     │                                      │
```

## How It Works - Step by Step

### 1. User Clicks "▶ Preview"

When you open a Dart test file, the extension's `CodeLensProvider` scans for `testWidgets()` calls and adds "▶ Preview" buttons above each test.

```typescript
// codelens.ts - Matches testWidgets('test name', ...)
const testWidgetsPattern = /testWidgets\s*\(\s*['"]([^'"]+)['"]/g;
```

Clicking the button triggers the `fontesWidgetViewer.previewTest` command with the file path and test name.

### 2. Extension Injects Test Configuration

The extension's `PreviewRunner` does several things before running the test:

**a) Find Project Root**
```typescript
// Walk up from test file to find pubspec.yaml
findProjectRoot(testFile: string): string | undefined {
    let dir = path.dirname(testFile);
    while (dir !== root) {
        if (fs.existsSync(path.join(dir, 'pubspec.yaml'))) {
            return dir;
        }
        dir = path.dirname(dir);
    }
}
```

**b) Inject `flutter_test_config.dart`**

Flutter's test framework looks for a `flutter_test_config.dart` file in the test directory. If found, it calls `testExecutable()` before running tests. The extension copies its template into the test directory:

```dart
// flutter_test_config.dart (injected)
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const enablePreview = bool.fromEnvironment('ENABLE_PREVIEW');
  
  if (enablePreview) {
    // Replace Flutter's default test binding with our custom one
    _binding = PreviewTestBinding.ensureInitialized();
    
    // Start gRPC server for frame streaming
    await _binding!.startServer();
    
    // Wait for viewer to connect (blocks until connected)
    await _binding!.waitForViewerConnection();
    
    // Register cleanup that runs after all tests
    tearDownAll(() async {
      // 1-second drain ensures frames reach the browser
      await Future.delayed(Duration(seconds: 1));
      await _binding!.stopServer();
    });
    
    await testMain();  // Register tests (they run after this returns)
  }
}
```

**c) Add `preview_binding` Dependency**

The extension adds `preview_binding` as a path dependency to the project's `pubspec.yaml`:

```yaml
dev_dependencies:
  preview_binding:
    path: /path/to/extension/packages/preview_binding
```

Then runs `flutter pub get` to install it.

### 3. Extension Spawns Two Processes

**Process 1: Flutter Test (with dart-defines)**
```typescript
spawn('flutter', [
    'test',
    testFile,
    '--name', `"${testName}"`,
    '--dart-define=ENABLE_PREVIEW=true',           // Activates preview mode
    `--dart-define=PREVIEW_FONTS_PATH=${fontsPath}`, // For font loading
], { cwd: projectRoot });
```

The extension listens to stdout for `GRPC_SERVER_STARTED:<port>` to know when the test's gRPC server is ready.

**Process 2: Viewer Server (after gRPC port is known)**
```typescript
spawn('dart', [
    'run',
    'bin/preview_viewer.dart',
    '--grpc-port', grpcPort,  // Connect to test's gRPC
    '--web-port', webPort,     // Serve WebSocket to browser
], { cwd: viewerPackagePath });
```

### 4. The Binding Takes Over

When the test process starts with `ENABLE_PREVIEW=true`:

1. `flutter_test_config.dart` is executed
2. `PreviewTestBinding.ensureInitialized()` replaces Flutter's default binding
3. The binding starts a gRPC server on a dynamic port
4. The binding prints `GRPC_SERVER_STARTED:<port>` to stdout
5. The binding waits for a client to connect before running tests

```dart
class PreviewTestBinding extends TestWidgetsFlutterBinding {
  late final _grpcServer = PreviewGrpcServer();
  
  Future<String> startServer({int port = 0}) async {
    final serverPort = await _grpcServer.start(port: port);
    print('GRPC_SERVER_STARTED:$serverPort');  // Extension parses this!
    return 'grpc://localhost:$serverPort';
  }
  
  Future<void> waitForViewerConnection() async {
    print('PREVIEW_WAITING_FOR_VIEWER');
    await _grpcServer.waitForClientConnection(timeout: Duration(seconds: 30));
    print('PREVIEW_VIEWER_CONNECTED');
  }
}
```

### 5. Frame Capture (On-Pump-Only)

The binding intercepts frame rendering but only captures when `pump()` is called:

```dart
// framePolicy = fadePointers means DON'T schedule continuous frames
@override
LiveTestWidgetsFlutterBindingFramePolicy get framePolicy =>
    LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;

bool _expectingFrame = false;

@override
void scheduleFrame() {
  // Don't call super.scheduleFrame() - we control when frames happen
  _expectingFrame = true;  // Flag that we want to capture next frame
  platformDispatcher.scheduleFrame();
}

@override
void handleDrawFrame() {
  super.handleDrawFrame();
  if (_expectingFrame) {
    _expectingFrame = false;
    _captureAndSendFrame();  // Capture only when pump() triggered this
  }
}
```

Frame capture converts the Flutter scene to PNG and sends via gRPC:

```dart
void _handleFrameCaptured(ui.Scene scene, ui.Size size, double dpr) async {
  final image = scene.toImageSync(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  
  final frame = Frame()
    ..width = width
    ..height = height
    ..rgbaData = byteData.buffer.asUint8List()
    ..testName = _currentTestName;
  
  _grpcServer.pushFrame(frame);
}
```

### 6. The Viewer Server (Daemon)

The viewer server (`preview_viewer`) acts as a bridge/daemon:

```dart
// bin/preview_viewer.dart
void main(List<String> args) async {
  final grpcPort = results['grpc-port'];
  final webPort = int.parse(results['web-port']);
  
  final relay = FrameRelay();       // Bridges gRPC ↔ WebSocket
  final server = ViewerServer(relay);  // HTTP + WebSocket server
  
  // Connect to the test's gRPC server
  await relay.connectToTest('localhost', int.parse(grpcPort));
  
  // Start WebSocket server for browsers
  await server.start(port: webPort);
  
  print('Open in browser: http://localhost:$webPort');
}
```

**FrameRelay - The Heart of the Daemon**

```dart
class FrameRelay {
  final PreviewGrpcClient _grpcClient = PreviewGrpcClient();
  final List<WebSocketChannel> _browserConnections = [];
  final List<Frame> _frameCache = [];  // ALL frames, no limit!
  bool _streamEnded = false;
  
  Future<void> connectToTest(String host, int port) async {
    await _grpcClient.connect(host, port);
    
    // Subscribe to frame stream from test
    _grpcClient.watchFrames().listen(
      (frame) {
        _frameCache.add(frame);  // Cache for late browsers
        _broadcastToBrowsers(frame);
      },
      onDone: () => _streamEnded = true,
    );
  }
  
  void addBrowserConnection(WebSocketChannel channel) {
    _browserConnections.add(channel);
    
    // REPLAY all cached frames to newly connected browser
    for (final frame in _frameCache) {
      _sendFrameToBrowser(channel, frame);
    }
  }
}
```

### 7. VS Code Webview Displays Frames

The extension opens a webview panel with an embedded WebSocket client:

```typescript
// webview.ts
const wsUrl = `ws://localhost:${port}/ws`;
const ws = new WebSocket(wsUrl);

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  if (data.type === 'frame') {
    displayFrame(data.image);  // base64-encoded PNG
  }
};
```

## Process Lifecycle

```
┌──────────────────────────────────────────────────────────────────────────┐
│ EXTENSION (TypeScript in VS Code)                                         │
├──────────────────────────────────────────────────────────────────────────┤
│ 1. User clicks "▶ Preview"                                                │
│ 2. Inject flutter_test_config.dart                                        │
│ 3. Spawn Process A: flutter test --dart-define=ENABLE_PREVIEW=true       │
│ 4. Parse stdout for "GRPC_SERVER_STARTED:<port>"                          │
│ 5. Spawn Process B: dart run preview_viewer --grpc-port <port>           │
│ 6. Open VS Code webview connected to viewer's WebSocket                   │
└──────────────────────────────────────────────────────────────────────────┘
        │                                    │
        ▼                                    ▼
┌───────────────────────────┐    ┌─────────────────────────────┐
│ PROCESS A: Flutter Test   │    │ PROCESS B: Viewer Server     │
├───────────────────────────┤    ├─────────────────────────────┤
│ - Loads flutter_test_     │    │ - Connects to test gRPC     │
│   config.dart             │    │ - Starts WebSocket server   │
│ - PreviewTestBinding      │    │ - Caches ALL frames         │
│   takes over              │    │ - Relays frames to browsers │
│ - Starts gRPC server      │    │                             │
│ - Waits for viewer        │    │                             │
│ - Runs test, captures     │    │                             │
│   frames on pump()        │    │                             │
│ - 1s drain after tests    │    │                             │
│ - Exits                   │    │ - Exits when test exits     │
└───────────────────────────┘    └─────────────────────────────┘
        │                                    │
        │         gRPC stream                │
        └────────────────────────────────────┘
                         │
                         │ WebSocket
                         ▼
              ┌─────────────────────┐
              │ VS Code Webview     │
              ├─────────────────────┤
              │ - Connects to       │
              │   ws://localhost    │
              │ - Receives frames   │
              │ - Displays timeline │
              └─────────────────────┘
```

## Stdout Protocol

The extension and test communicate via stdout messages:

| Message | Meaning |
|---------|---------|
| `GRPC_SERVER_STARTED:<port>` | Test's gRPC server is ready |
| `PREVIEW_WAITING_FOR_VIEWER` | Test is waiting for viewer to connect |
| `PREVIEW_VIEWER_CONNECTED` | Viewer connected, tests will start |
| `PREVIEW_TESTS_STARTING` | Tests are about to run |
| `PREVIEW_TESTS_COMPLETE:frames=N` | All tests done, N frames captured |
| `PREVIEW_DRAINING:Ns` | Waiting N seconds for frame delivery |
| `PREVIEW_DRAIN_COMPLETE` | Drain finished, shutting down |

## Directory Structure

```
fontes_widget_viewer/
├── extension/               # VS Code extension (TypeScript)
│   ├── src/
│   │   ├── extension.ts     # Extension entry point, registers commands
│   │   ├── codelens.ts      # "▶ Preview" CodeLens provider
│   │   ├── runner.ts        # Orchestrates test & viewer processes
│   │   └── webview.ts       # VS Code webview panel for preview
│   ├── templates/
│   │   └── flutter_test_config.dart  # Injected into test projects
│   ├── fonts/               # Roboto font for consistent rendering
│   └── packages/            # Auto-synced Dart packages (git-ignored)
│
├── packages/                # Main Dart packages (source of truth)
│   ├── preview_binding/     # Custom Flutter test binding
│   ├── preview_core/        # gRPC protocol & server/client
│   └── preview_viewer/      # HTTP/WebSocket relay server
│
└── examples/
    └── counter_app/         # Demo Flutter app with tests
```

## Key Files Reference

| File | Purpose |
|------|---------|
| [extension/src/extension.ts](extension/src/extension.ts) | Extension entry point, registers commands |
| [extension/src/codelens.ts](extension/src/codelens.ts) | "▶ Preview" button on tests |
| [extension/src/runner.ts](extension/src/runner.ts) | Orchestrates test execution & process spawning |
| [extension/src/webview.ts](extension/src/webview.ts) | VS Code preview panel with WebSocket client |
| [extension/templates/flutter_test_config.dart](extension/templates/flutter_test_config.dart) | Test config template (injected) |
| [packages/preview_binding/lib/src/preview_test_binding.dart](packages/preview_binding/lib/src/preview_test_binding.dart) | Custom test binding with frame capture |
| [packages/preview_core/lib/src/grpc_server.dart](packages/preview_core/lib/src/grpc_server.dart) | gRPC frame server |
| [packages/preview_core/lib/src/grpc_client.dart](packages/preview_core/lib/src/grpc_client.dart) | gRPC frame client |
| [packages/preview_viewer/lib/src/frame_relay.dart](packages/preview_viewer/lib/src/frame_relay.dart) | gRPC→WebSocket relay with caching |
| [packages/preview_viewer/bin/preview_viewer.dart](packages/preview_viewer/bin/preview_viewer.dart) | Viewer server entry point |

## Build & Package

### Build VSIX Extension

```bash
cd extension
npm install
npm run package  # Creates fontes-widget-viewer-0.0.1.vsix
```

The `package` script does:
1. `sync-packages` - Copies Dart packages into extension folder
2. `compile` - Compiles TypeScript to JavaScript
3. `vsce package` - Creates installable VSIX

### Install Extension

```bash
code --install-extension fontes-widget-viewer-0.0.1.vsix
```

## Design Decisions

### Why gRPC instead of direct IPC?
- gRPC provides typed, streaming protocol
- Works across process boundaries
- Auto-generated Dart code from protobuf

### Why separate viewer server (daemon)?
- Browser can't connect directly to gRPC (different protocol)
- WebSocket provides web-standard streaming
- Allows multiple browser connections
- Caches frames for late-connecting browsers

### Why cache ALL frames in the relay?
- VS Code webview loads AFTER test starts
- Test often completes before browser connects
- User expects to see complete test run
- Replay enables time-travel debugging

### Why on-pump-only capture?
- 60fps continuous capture creates too many frames (50+)
- Most frames are identical (nothing changed)
- 3-5 pump frames show meaningful state changes
- Much faster test execution

### Why 1-second drain?
- Ensures frames reach browser before server shutdown
- Previous 3-second drain was unnecessarily slow
- With few frames (on-pump-only), 1 second is sufficient

### Why inject flutter_test_config.dart?
- Flutter's test framework calls `testExecutable()` before tests
- Allows replacing the default test binding
- Works with any Flutter project without code changes
- Can be enabled/disabled via dart-define flag
