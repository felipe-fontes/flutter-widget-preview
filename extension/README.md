# Flutter Widget Preview

**Real-time widget testing for Flutter — see your UI as you build it.**

Flutter Widget Preview lets you **see your widget tests render in real-time**. No more running tests blind — watch your widgets come to life frame by frame.

## Features

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

| iOS | Android | Desktop |
|-----|---------|---------|
| iPhone 15 Pro | Pixel 8 | 1080p |
| iPhone 15 Pro Max | Pixel 8 Pro | 1440p |
| iPhone SE | Galaxy S24 | 4K |
| iPad Pro 12.9" | Galaxy Fold | Custom |

### 🤖 AI-Powered Development (MCP)

Let your AI assistant **see** the widgets it creates:

```
You: "Create a profile card with avatar and name"

AI: [writes widget code]
AI: [calls preview_widget to see result]
AI: "Here's the profile card. The avatar is 80px, centered above the name."
```

Works with **GitHub Copilot**, **Claude**, **Cursor**, and any MCP-compatible assistant.

---

## Quick Start

1. **Open a Flutter project** with widget tests
2. **Click "▶ Preview"** above any `testWidgets()`
3. **Watch the preview panel** as your test runs

That's it!

---

## Commands

| Command | Description |
|---------|-------------|
| `Flutter Preview: Preview Widget Test` | Preview the widget test at cursor |
| `Flutter Preview: Stop Widget Preview` | Stop the running preview |
| `Flutter Preview: Select Preview Resolution` | Choose target device size |
| `Flutter Preview: Register MCP for Cursor` | Set up MCP in Cursor IDE |

---

## MCP Tools for AI Assistants

The extension includes an MCP server with these tools:

| Tool | Description |
|------|-------------|
| `preview_widget` | Preview widget code — provide Dart, get PNG back |
| `run_widget_test` | Run a test file and capture frames |
| `list_frames` | List captured frames with metadata |
| `get_frame` | Get a specific frame as PNG |
| `get_all_frames` | Get all frames (for animations) |

### Enable MCP in VS Code

1. **Settings** → **GitHub Copilot** → **MCP Servers**
2. Enable **"Flutter Preview"**

### Enable MCP in Cursor

Run command: **"Flutter Preview: Register MCP for Cursor"**

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `flutterPreview.webPort` | `9090` | Preview server port |
| `flutterPreview.openInBrowser` | `false` | Use external browser |
| `flutterPreview.defaultResolution` | `iPhone 15 Pro` | Default device |

---

## Requirements

- VS Code 1.74.0 or later
- Flutter SDK installed
- Dart extension for VS Code

---

## How It Works

1. You click **"▶ Preview"** on a test
2. Extension injects a custom test binding
3. Each `pump()` captures and streams the frame
4. VS Code webview displays frames with timeline

---

## Troubleshooting

**Preview panel is empty?**
- Ensure your test has `pump()` calls
- Check Output panel → "Flutter Preview" for errors

**MCP not working?**
- Settings → GitHub Copilot → MCP Servers → Enable Flutter Preview
- Restart VS Code

---

## License

MIT

---

<p align="center">
  <b>See what you're building.</b>
</p>
