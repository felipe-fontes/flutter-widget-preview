# Flutter Widget Preview 🎯

**Real-time widget testing for Flutter — see your UI as you build it.**

Flutter Widget Preview is a VS Code extension that lets you **see your widget tests render in real-time**. No more running tests blind — watch your widgets come to life frame by frame.

<p align="center">
  <img src="extension/media/icon.png" alt="Flutter Widget Preview" width="200">
</p>

<!-- ![Flutter Preview Demo](media/demo.gif) -->

## ✨ Features

### 🎬 Visual Widget Testing
Click **"▶ Preview"** above any `testWidgets()` to see your widget render live:

```dart
testWidgets('counter increments', (tester) async {
  await tester.pumpWidget(MyApp());
  expect(find.text('0'), findsOneWidget);
  
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();  // 📸 Frame captured!
  
  expect(find.text('1'), findsOneWidget);
});
```

Every `pump()` captures a frame — see exactly what Flutter renders at each step.

### 📱 Device Resolution Presets
Preview on real device sizes:
- **iOS**: iPhone 15 Pro, iPhone SE, iPad Pro 12.9", iPad Air
- **Android**: Pixel 8, Pixel 8 Pro, Galaxy S24, Galaxy Fold
- **Desktop**: 1080p, 1440p, 4K, Custom sizes

### 🤖 AI-Powered Widget Development (MCP)
Let your AI assistant **see** the widgets it creates. The extension includes an **MCP (Model Context Protocol) server** that enables AI coding assistants to preview Flutter widgets programmatically:

```
You: "Create a profile card with an avatar and name"
AI: [writes widget code]
AI: [calls preview_widget to see the result]
AI: "I've created the widget. The avatar is 80px and centered.
     Here's how it looks: [shows rendered preview]"
```

Works with **GitHub Copilot**, **Claude**, **Cursor**, and any MCP-compatible assistant.

---

## 🚀 Quick Start

### Installation

1. **Install the Extension**
   - Download from VS Code Marketplace, or
   - Install from VSIX: `code --install-extension flutter-preview-0.1.0.vsix`

2. **Open a Flutter Project** with widget tests

3. **Click "▶ Preview"** above any `testWidgets()`

That's it! The preview panel opens automatically.

---

## 📖 Usage Guide

### Basic Preview

1. Open any Dart file with `testWidgets()` calls
2. Click the **"▶ Preview"** CodeLens that appears above a test
3. Watch the preview panel as your test runs
4. Use the timeline to navigate between captured frames

### Select Device Resolution

1. Open Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`)
2. Run **"Flutter: Select Preview Resolution"**
3. Choose a device preset or enter custom dimensions

### Available Commands

| Command | Description |
|---------|-------------|
| `Flutter: Preview Widget Test` | Run preview on current test |
| `Flutter: Stop Widget Preview` | Stop the running preview |
| `Flutter: Select Preview Resolution` | Choose target device size |

---

## 🤖 MCP Integration for AI Assistants

Flutter Preview includes an **MCP (Model Context Protocol) server** that enables AI assistants to preview Flutter widgets programmatically. This creates a powerful feedback loop where AI can **see** what it builds.

### How It Works

```
┌─────────────────────┐     stdio      ┌─────────────────────┐   flutter test  ┌─────────────────────┐
│   AI Assistant      │ ◀──────────▶   │   MCP Server        │ ──────────────▶ │   Widget Test       │
│   (Copilot/Claude)  │    JSON-RPC    │   (mcp_preview)     │                 │   (captures PNG)    │
└─────────────────────┘                └─────────────────────┘                 └─────────────────────┘
```

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `preview_widget` | Preview arbitrary widget code — AI provides Dart code, gets rendered PNG back |
| `run_widget_test` | Run an existing test file and capture all frames |
| `list_frames` | List metadata for all captured frames (count, dimensions, timestamps) |
| `get_frame` | Get a specific frame as base64-encoded PNG image |
| `get_all_frames` | Get all frames at once (useful for animations/transitions) |

### Example: AI Widget Development Workflow

1. **User**: "Create a login form with email and password fields"

2. **AI** writes the widget code:
   ```dart
   Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
       TextField(decoration: InputDecoration(labelText: 'Email')),
       SizedBox(height: 16),
       TextField(
         decoration: InputDecoration(labelText: 'Password'),
         obscureText: true,
       ),
       SizedBox(height: 24),
       ElevatedButton(onPressed: () {}, child: Text('Login')),
     ],
   )
   ```

3. **AI** calls `preview_widget` with the code

4. **AI** receives the rendered PNG image and can verify:
   - Layout looks correct
   - Spacing is appropriate
   - No overflow errors

5. **AI** iterates if needed, or confirms completion with visual proof

### Register MCP Server

#### VS Code (with GitHub Copilot)
The extension automatically registers the MCP server. Enable it in:
- **Settings** → **GitHub Copilot** → **MCP Servers** → Enable "Flutter Preview"

#### Cursor
Use Command Palette → **"Flutter Preview: Register MCP for Cursor"**

Or use the deep link: `cursor://anysphere.cursor-deeplink/mcp/install?name=flutter-preview&config=...`

#### Manual Configuration (Any MCP Client)

Add to your `mcp.json` or equivalent configuration:
```json
{
  "mcpServers": {
    "flutter-preview": {
      "command": "dart",
      "args": ["run", "mcp_preview", "--fonts-path", "/path/to/fonts"],
      "cwd": "/path/to/extension/packages/mcp_preview"
    }
  }
}
```

### MCP Tool Examples

**Preview a simple widget:**
```json
{
  "tool": "preview_widget",
  "arguments": {
    "widgetCode": "Container(color: Colors.blue, width: 200, height: 200, child: Center(child: Text('Hello!', style: TextStyle(color: Colors.white, fontSize: 24))))",
    "width": 400,
    "height": 300
  }
}
```

**Run an existing test:**
```json
{
  "tool": "run_widget_test",
  "arguments": {
    "testFile": "/path/to/my_widget_test.dart",
    "testName": "renders correctly"
  }
}
```

**Get the last rendered frame:**
```json
{
  "tool": "get_frame",
  "arguments": {
    "index": "last"
  }
}
```

---

## ⚙️ Configuration

### Extension Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `flutterPreview.webPort` | `9090` | Port for the preview web server |
| `flutterPreview.openInBrowser` | `false` | Open preview in external browser instead of VS Code webview |

### Environment Variables (dart-defines)

The extension automatically passes these to your tests:

| Define | Description |
|--------|-------------|
| `ENABLE_PREVIEW=true` | Activates preview mode |
| `PREVIEW_WIDTH=<n>` | Logical viewport width |
| `PREVIEW_HEIGHT=<n>` | Logical viewport height |
| `PREVIEW_DEVICE_PIXEL_RATIO=<n>` | Device pixel ratio (for high-DPI) |
| `PREVIEW_FONTS_PATH=<path>` | Path to fonts for consistent rendering |

---

## 🏗️ Architecture Overview

```
┌─────────────────────┐     gRPC      ┌─────────────────────┐   WebSocket   ┌─────────────────────┐
│   Flutter Test      │ ──────────▶   │   Viewer Server     │ ──────────▶   │   VS Code Webview   │
│   (preview_binding) │               │   (preview_viewer)  │               │                     │
└─────────────────────┘               └─────────────────────┘               └─────────────────────┘
         │                                     │                                      │
         │ Captures frames                     │ Caches ALL frames                    │ Displays
         │ on pump() calls                     │ for late connections                 │ frame timeline
```

**How it works:**

1. You click **"▶ Preview"** on a test
2. Extension injects a custom test binding that captures frames
3. Each `pump()` renders the widget and streams the frame via gRPC
4. A relay server converts gRPC to WebSocket for the browser
5. VS Code webview displays frames with a timeline scrubber

For the complete technical deep-dive, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 📦 Packages

| Package | Purpose |
|---------|---------|
| `preview_binding` | Custom Flutter test binding with frame capture |
| `preview_core` | gRPC protocol definitions and server/client |
| `preview_viewer` | HTTP/WebSocket relay server for browser viewing |
| `mcp_preview` | MCP server for AI assistant integration |

---

## 🧪 Development

### Build the Extension

```bash
cd extension
npm install
npm run package  # Creates flutter-preview-X.X.X.vsix
```

### Run Tests

```bash
# Test gRPC functionality
cd packages/preview_core && dart test

# Test binding frame capture
cd packages/preview_binding && flutter test

# Test viewer relay
cd packages/preview_viewer && dart test

# Test MCP server
cd packages/mcp_preview && dart test
```

### Regenerate Protocol Buffers

```bash
cd packages/preview_core
protoc --dart_out=grpc:lib/src/generated -I../../proto ../../proto/preview.proto
```

---

## 🔧 Troubleshooting

### Preview panel is empty
- Ensure your test has `pump()` calls — frames are only captured on pump
- Check the Output panel (View → Output → Flutter Preview) for errors

### MCP tools not showing in Copilot
- Go to Settings → GitHub Copilot → MCP Servers
- Ensure "Flutter Preview" is enabled
- Restart VS Code if needed

### Frame capture is slow
- Reduce viewport size in resolution settings
- Large frames (4K) require more memory and processing

---

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

<p align="center">
  <b>Built for Flutter developers who want to see what they're building.</b><br>
  <sub>Visual widget testing • AI-powered development • Real device previews</sub>
</p>
