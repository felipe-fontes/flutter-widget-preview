import * as vscode from 'vscode';

export class PreviewPanel {
    public static currentPanel: PreviewPanel | undefined;
    public static readonly viewType = 'fontesWidgetViewer.preview';

    private readonly _panel: vscode.WebviewPanel;
    private _port: number;
    private _disposables: vscode.Disposable[] = [];

    private constructor(panel: vscode.WebviewPanel, extensionUri: vscode.Uri, port: number) {
        this._panel = panel;
        this._port = port;

        this._panel.webview.html = this._getHtmlForWebview(port);

        this._panel.onDidDispose(() => this.dispose(), null, this._disposables);
    }

    public static createOrShow(extensionUri: vscode.Uri, port: number): void {
        const column = vscode.ViewColumn.Beside;

        if (PreviewPanel.currentPanel) {
            PreviewPanel.currentPanel._panel.reveal(column);
            PreviewPanel.currentPanel.updatePort(port);
            return;
        }

        const panel = vscode.window.createWebviewPanel(
            PreviewPanel.viewType,
            'Widget Preview',
            column,
            {
                enableScripts: true,
                retainContextWhenHidden: true,
            }
        );

        PreviewPanel.currentPanel = new PreviewPanel(panel, extensionUri, port);
    }

    public updatePort(port: number): void {
        this._port = port;
        this._panel.webview.html = this._getHtmlForWebview(port);
    }

    public dispose(): void {
        PreviewPanel.currentPanel = undefined;

        this._panel.dispose();

        while (this._disposables.length) {
            const disposable = this._disposables.pop();
            if (disposable) {
                disposable.dispose();
            }
        }
    }

    private _getHtmlForWebview(port: number): string {
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src ws://localhost:${port} ws://127.0.0.1:${port};">
    <title>Widget Preview</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #1e1e1e;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 16px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            color: #ccc;
        }
        .header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 16px;
        }
        h1 {
            font-size: 14px;
            font-weight: 500;
            color: #888;
            text-transform: uppercase;
            letter-spacing: 2px;
        }
        #status {
            font-size: 11px;
            padding: 4px 10px;
            border-radius: 10px;
            background: rgba(74, 222, 128, 0.15);
            color: #4ade80;
        }
        #status.disconnected {
            background: rgba(248, 113, 113, 0.15);
            color: #f87171;
        }
        #status.connecting {
            background: rgba(250, 204, 21, 0.15);
            color: #facc15;
        }
        .canvas-container {
            background: #252526;
            border-radius: 8px;
            padding: 12px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            max-width: 100%;
            overflow: auto;
        }
        #preview {
            display: block;
            border-radius: 4px;
            background: #1a1a1a;
        }
        .info {
            margin-top: 12px;
            font-size: 11px;
            color: #666;
            display: flex;
            gap: 16px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Widget Preview</h1>
        <div id="status" class="connecting">Connecting...</div>
    </div>
    <div class="canvas-container">
        <canvas id="preview" width="400" height="800"></canvas>
    </div>
    <div class="info">
        <span id="dimensions">--</span>
        <span id="fps">-- fps</span>
    </div>

    <script>
        const canvas = document.getElementById('preview');
        const ctx = canvas.getContext('2d');
        const status = document.getElementById('status');
        const dimensions = document.getElementById('dimensions');
        const fpsDisplay = document.getElementById('fps');

        let frameCount = 0;
        let lastFpsUpdate = Date.now();
        let pendingMetadata = null;
        let reconnectTimeout = null;

        // Debug logging that shows in webview
        const log = (msg) => {
            console.log('[Preview]', msg);
            // Also show in dimensions for debugging
            // dimensions.textContent = msg;
        };

        function connect() {
            log('Connecting to ws://localhost:${port}/ws...');
            status.textContent = 'Connecting...';
            status.className = 'connecting';

            const ws = new WebSocket('ws://localhost:${port}/ws');
            ws.binaryType = 'arraybuffer';

            ws.onopen = () => {
                log('WebSocket connected!');
                status.textContent = 'Connected';
                status.className = '';
                if (reconnectTimeout) {
                    clearTimeout(reconnectTimeout);
                    reconnectTimeout = null;
                }
            };

            ws.onclose = (e) => {
                log('WebSocket closed: code=' + e.code + ' reason=' + e.reason);
                status.textContent = 'Disconnected';
                status.className = 'disconnected';
                reconnectTimeout = setTimeout(connect, 2000);
            };

            ws.onerror = (e) => {
                log('WebSocket error: ' + e.message);
            };

            ws.onmessage = (event) => {
                if (typeof event.data === 'string') {
                    pendingMetadata = JSON.parse(event.data);
                    log('Got metadata: ' + event.data.substring(0, 50));
                } else if (event.data instanceof ArrayBuffer && pendingMetadata) {
                    log('Got frame data: ' + event.data.byteLength + ' bytes');
                    renderFrame(pendingMetadata, new Uint8ClampedArray(event.data));
                    pendingMetadata = null;
                }
            };
        }

        function renderFrame(meta, rgbaData) {
            log('Rendering: ' + meta.width + 'x' + meta.height);
            const { width, height, devicePixelRatio } = meta;
            
            if (canvas.width !== width || canvas.height !== height) {
                canvas.width = width;
                canvas.height = height;
                const displayWidth = width / devicePixelRatio;
                const displayHeight = height / devicePixelRatio;
                canvas.style.width = displayWidth + 'px';
                canvas.style.height = displayHeight + 'px';
            }

            const imageData = new ImageData(rgbaData, width, height);
            ctx.putImageData(imageData, 0, 0);

            dimensions.textContent = Math.round(width/devicePixelRatio) + 'x' + Math.round(height/devicePixelRatio);
            
            frameCount++;
            const now = Date.now();
            if (now - lastFpsUpdate >= 1000) {
                fpsDisplay.textContent = frameCount + ' fps';
                frameCount = 0;
                lastFpsUpdate = now;
            }
        }

        connect();
    </script>
</body>
</html>`;
    }
}
