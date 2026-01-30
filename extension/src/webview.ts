import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

export class PreviewPanel {
    public static currentPanel: PreviewPanel | undefined;
    public static readonly viewType = 'flutterPreview.preview';

    private readonly _panel: vscode.WebviewPanel;
    private readonly _extensionUri: vscode.Uri;
    private _port: number;
    private _disposables: vscode.Disposable[] = [];
    private _onDisposeCallback?: () => void;

    private constructor(panel: vscode.WebviewPanel, extensionUri: vscode.Uri, port: number, onDispose?: () => void) {
        this._panel = panel;
        this._extensionUri = extensionUri;
        this._port = port;
        this._onDisposeCallback = onDispose;

        this._panel.webview.html = this._getHtmlForWebview(port);

        this._panel.onDidDispose(() => this.dispose(), null, this._disposables);
    }

    public static createOrShow(extensionUri: vscode.Uri, port: number, onDispose?: () => void): void {
        const column = vscode.ViewColumn.Beside;

        if (PreviewPanel.currentPanel) {
            PreviewPanel.currentPanel._panel.reveal(column);
            PreviewPanel.currentPanel.updatePort(port);
            PreviewPanel.currentPanel._onDisposeCallback = onDispose;
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

        PreviewPanel.currentPanel = new PreviewPanel(panel, extensionUri, port, onDispose);
    }

    public updatePort(port: number): void {
        this._port = port;
        // Force refresh by setting empty HTML first, then the actual content
        this._panel.webview.html = '';
        this._panel.webview.html = this._getHtmlForWebview(port);
    }

    public dispose(): void {
        PreviewPanel.currentPanel = undefined;

        // Call the dispose callback to stop the preview runner
        if (this._onDisposeCallback) {
            this._onDisposeCallback();
        }

        this._panel.dispose();

        while (this._disposables.length) {
            const disposable = this._disposables.pop();
            if (disposable) {
                disposable.dispose();
            }
        }
    }

    private _getHtmlForWebview(port: number): string {
        // Read the shared HTML template
        const templatePath = path.join(this._extensionUri.fsPath, 'templates', 'viewer.html');
        let html = fs.readFileSync(templatePath, 'utf8');

        // Replace the port placeholder
        html = html.replace(/\{\{PORT\}\}/g, port.toString());

        // Add a timestamp comment to ensure content is unique (forces webview refresh)
        html = html.replace('</head>', `<!-- session: ${Date.now()} -->\n</head>`);

        return html;
    }
}
