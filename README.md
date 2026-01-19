# Fontes Widget Viewer

A CLI-first widget preview system that streams Flutter widget test frames via gRPC. View your widget tests in real-time in a browser.

## Architecture

```
┌─────────────────────────┐                    ┌─────────────────────────┐                    ┌─────────────────────────┐
│                         │    gRPC Stream     │                         │    WebSocket       │                         │
│   Flutter Widget Test   │ ─────────────────► │   preview_viewer CLI    │ ─────────────────► │      Browser            │
│   + PreviewTestBinding  │   Frame (RGBA)     │   (relay server)        │   Frame (RGBA)     │   (canvas renderer)     │
│                         │                    │                         │                    │                         │
└─────────────────────────┘                    └─────────────────────────┘                    └─────────────────────────┘
         ▲                                              ▲
         │                                              │
    Captures frames                              Relays frames to
    on each pump()                               connected browsers
```

## Packages

### preview_core

**Responsibility**: Core gRPC infrastructure for streaming frames.

| Component | Description |
|-----------|-------------|
| `preview.proto` | Protocol buffer definitions for Frame, Status, and PreviewService |
| `PreviewGrpcServer` | gRPC server that accepts client connections and broadcasts frames |
| `PreviewGrpcClient` | gRPC client that connects to server and receives frame stream |
| `Frame` | Protobuf message containing RGBA pixel data, dimensions, and metadata |

**Key Files**:
- `lib/src/grpc_server.dart` - Server implementation with `pushFrame()` and `watchFrames()` RPC
- `lib/src/grpc_client.dart` - Client implementation with `connect()` and `watchFrames()` stream
- `lib/src/generated/` - Auto-generated protobuf/gRPC code

### preview_binding

**Responsibility**: Custom Flutter test binding that captures rendered frames.

| Component | Description |
|-----------|-------------|
| `PreviewTestBinding` | Custom `TestWidgetsFlutterBinding` that intercepts rendering |
| `PreviewPlatformDispatcher` | Wraps platform dispatcher to capture scenes |
| `startServer()` / `stopServer()` | Controls the embedded gRPC server |

**How it works**:
1. Extends `TestWidgetsFlutterBinding` and implements `LiveTestWidgetsFlutterBinding`
2. On each `scheduleFrame()`, captures the rendered layer tree as an image
3. Converts the image to raw RGBA bytes
4. Pushes the frame to the gRPC server for connected viewers

**Key Files**:
- `lib/src/preview_test_binding.dart` - Main binding implementation
- `lib/src/preview_platform_dispatcher.dart` - Platform dispatcher wrapper

### preview_viewer

**Responsibility**: CLI tool that connects to a test and displays frames in a browser.

| Component | Description |
|-----------|-------------|
| `FrameRelay` | Connects to gRPC server and relays frames to browser WebSockets |
| `ViewerServer` | HTTP server that serves the viewer HTML and handles WebSocket connections |
| `viewer.html` | Canvas-based renderer that displays frames at ~10 FPS |

**Key Files**:
- `bin/preview_viewer.dart` - CLI entry point
- `lib/src/frame_relay.dart` - gRPC to WebSocket bridge
- `lib/src/viewer_server.dart` - HTTP/WebSocket server with embedded HTML

## Installation

```bash
cd fontes_widget_viewer

# Install preview_core dependencies
cd packages/preview_core
dart pub get

# Install preview_binding dependencies
cd ../preview_binding
flutter pub get

# Install preview_viewer dependencies
cd ../preview_viewer
dart pub get
```

## Usage

### Option 1: Demo Server (Test the Viewer)

Run a demo that generates animated frames without Flutter:

```bash
# Terminal 1: Start demo server
cd packages/preview_core
dart run bin/demo_server.dart

# Terminal 2: Start viewer
cd packages/preview_viewer
dart run bin/preview_viewer.dart --grpc-port 50055

# Open http://localhost:9090 in your browser
```

### Option 2: Flutter Widget Test

Use in your Flutter widget tests:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preview_binding/preview_binding.dart';

void main() {
  final binding = PreviewTestBinding.ensureInitialized();

  testWidgets('my widget preview', (tester) async {
    final serverUri = await binding.startServer(port: 0);
    print('Connect viewer to: $serverUri');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Hello Preview!')),
        ),
      ),
    );

    // Each pump() automatically captures and streams a frame
    await tester.pump();

    await binding.stopServer();
  });
}
```

Then connect the viewer:

```bash
cd packages/preview_viewer
dart run bin/preview_viewer.dart --grpc-port <PORT>
```

### CLI Options

```
preview_viewer [options]

Options:
  -h, --grpc-host    gRPC server host (default: localhost)
  -p, --grpc-port    gRPC server port (required)
  -w, --web-port     Web server port (default: 9090)
      --help         Show help
```

## Running Tests

### Unit Tests

```bash
# Test gRPC server functionality
cd packages/preview_core
dart test test/server_test.dart -r expanded

# Test client-server round-trip
dart test test/client_server_test.dart -r expanded

# Test binding frame capture (Flutter)
cd packages/preview_binding
flutter test test/binding_capture_test.dart -r expanded

# Test viewer relay functionality
cd packages/preview_viewer
dart test test/viewer_test.dart -r expanded
```

### Expected Output Markers

Each component outputs verification markers:

| Marker | Source | Meaning |
|--------|--------|---------|
| `GRPC_SERVER_STARTED:<port>` | preview_core | gRPC server listening on port |
| `GRPC_CLIENT_CONNECTED:<host>:<port>` | preview_core | Client connected to server |
| `CLIENT_CONNECTED:watchFrames` | preview_core | Client subscribed to frame stream |
| `FRAME_PUSHED:<W>x<H>` | preview_core | Frame added to broadcast stream |
| `FRAME_CAPTURED:<W>x<H>` | preview_binding | Frame captured from render tree |
| `PREVIEW_SERVER_STARTED:<uri>` | preview_binding | Binding's gRPC server ready |
| `RELAY_CONNECTED_TO_TEST:<host>:<port>` | preview_viewer | Viewer connected to test |
| `RELAY_FRAME:<W>x<H>` | preview_viewer | Frame relayed to browser |
| `BROWSER_CONNECTED:<N> total` | preview_viewer | Browser WebSocket connected |
| `VIEWER_SERVER_STARTED:<url>` | preview_viewer | Web server ready |

## Protocol Buffer Schema

```protobuf
syntax = "proto3";
package fontes_widget_viewer;

service PreviewService {
  rpc WatchFrames(WatchRequest) returns (stream Frame);
  rpc GetStatus(Empty) returns (Status);
}

message Frame {
  bytes rgbaData = 1;        // Raw RGBA pixel data
  int32 width = 2;           // Frame width in pixels
  int32 height = 3;          // Frame height in pixels
  double devicePixelRatio = 4;
  int64 timestampMs = 5;
  string testName = 6;
}

message Status {
  bool isRunning = 1;
  string testName = 2;
  int32 frameCount = 3;
  string serverUri = 4;
}
```

## Data Flow

1. **Frame Capture** (preview_binding)
   - `PreviewTestBinding.scheduleFrame()` is called on each `pump()`
   - Captures `RenderView.debugLayer` as an image via `layer.toImage()`
   - Converts to raw RGBA bytes via `image.toByteData(format: rawRgba)`

2. **Frame Streaming** (preview_core)
   - `PreviewGrpcServer.pushFrame(frame)` adds frame to broadcast `StreamController`
   - Connected clients receive frames via `watchFrames()` gRPC stream

3. **Frame Relay** (preview_viewer)
   - `FrameRelay` subscribes to gRPC frame stream
   - For each frame, sends metadata JSON then raw bytes over WebSocket

4. **Frame Rendering** (Browser)
   - JavaScript receives metadata + RGBA bytes
   - Creates `ImageData` and renders to canvas via `putImageData()`

## Limitations

- **Flutter Test Timing**: Widget tests run with mocked async, which can interfere with gRPC real-time streaming. The demo server works reliably; widget test streaming may require running the gRPC server in a separate isolate.

- **One-Way Streaming**: Currently viewer only receives frames. No interaction events (tap, scroll) are sent back to the test.

- **Frame Size**: Large frames (e.g., 2400x1800 at 4 bytes/pixel = 17MB) can impact performance. Consider reducing test window size.

## Project Structure

```
fontes_widget_viewer/
├── proto/
│   └── preview.proto           # gRPC service definition
├── packages/
│   ├── preview_core/           # gRPC server/client
│   │   ├── bin/
│   │   │   └── demo_server.dart    # Demo frame generator
│   │   ├── lib/
│   │   │   └── src/
│   │   │       ├── grpc_server.dart
│   │   │       ├── grpc_client.dart
│   │   │       └── generated/      # protoc output
│   │   └── test/
│   │       ├── server_test.dart
│   │       └── client_server_test.dart
│   ├── preview_binding/        # Flutter test binding
│   │   ├── lib/
│   │   │   └── src/
│   │   │       ├── preview_test_binding.dart
│   │   │       └── preview_platform_dispatcher.dart
│   │   └── test/
│   │       └── binding_capture_test.dart
│   └── preview_viewer/         # CLI viewer tool
│       ├── bin/
│       │   └── preview_viewer.dart
│       ├── lib/
│       │   └── src/
│       │       ├── frame_relay.dart
│       │       └── viewer_server.dart
│       └── test/
│           └── viewer_test.dart
└── README.md
```

## Regenerating Protocol Buffers

If you modify `proto/preview.proto`:

```bash
cd packages/preview_core
protoc --dart_out=grpc:lib/src/generated -I../../proto ../../proto/preview.proto
```

Requires: `protoc` compiler and `protoc-gen-dart` plugin.

## License

MIT
