import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

/**
 * Create the shell script that runs the MCP server
 */
function createMcpScript(extensionPath: string): string {
    const mcpPackagePath = path.join(extensionPath, 'packages', 'mcp_preview');
    const fontsPath = path.join(extensionPath, 'fonts');

    const scriptContent = `#!/bin/bash
cd "${mcpPackagePath}"
exec dart run bin/mcp_preview.dart --fonts-path="${fontsPath}" "$@"
`;

    const scriptDir = path.join(extensionPath, '.mcp-scripts');
    if (!fs.existsSync(scriptDir)) {
        fs.mkdirSync(scriptDir, { recursive: true });
    }

    const scriptPath = path.join(scriptDir, 'run-mcp-preview.sh');
    fs.writeFileSync(scriptPath, scriptContent, { mode: 0o755 });

    return scriptPath;
}

/**
 * Provides MCP server definition for the Flutter Preview MCP server.
 */
export class FlutterPreviewMcpProvider implements vscode.McpServerDefinitionProvider<vscode.McpStdioServerDefinition> {
    private readonly extensionPath: string;

    constructor(extensionPath: string) {
        this.extensionPath = extensionPath;
    }

    async provideMcpServerDefinitions(
        token: vscode.CancellationToken
    ): Promise<vscode.McpStdioServerDefinition[]> {
        const scriptPath = createMcpScript(this.extensionPath);

        const server = new vscode.McpStdioServerDefinition(
            'Flutter Preview',
            scriptPath,
            [],
            undefined,
            '0.1.0'
        );

        return [server];
    }

    async resolveMcpServerDefinition(
        server: vscode.McpStdioServerDefinition,
        token: vscode.CancellationToken
    ): Promise<vscode.McpStdioServerDefinition> {
        return server;
    }
}

/**
 * Prompt users to install the MCP server via deep link or manual config
 */
async function promptMcpInstall(context: vscode.ExtensionContext, appName: string): Promise<void> {
    const scriptPath = createMcpScript(context.extensionPath);
    const appNameLower = appName.toLowerCase();

    // Only Cursor supports the deep link installation
    if (appNameLower.includes('cursor')) {
        const mcpConfig = {
            type: "stdio",
            command: scriptPath
        };
        const configBase64 = Buffer.from(JSON.stringify(mcpConfig)).toString('base64');
        const mcpSetupUri = vscode.Uri.parse(
            `cursor://anysphere.cursor-deeplink/mcp/install?name=flutter-preview&config=${configBase64}`
        );

        const action = await vscode.window.showInformationMessage(
            `Would you like to install the Flutter Preview MCP server?`,
            'Yes', 'No'
        );

        if (action === 'Yes') {
            await vscode.commands.executeCommand('vscode.open', mcpSetupUri);
        }
    } else {
        // For other IDEs (Antigravity, etc.), show manual configuration
        const mcpJson = JSON.stringify({
            "flutter-preview": {
                "type": "stdio",
                "command": scriptPath
            }
        }, null, 2);

        const action = await vscode.window.showInformationMessage(
            `Add this to your MCP settings to enable Flutter Preview`,
            'Copy Config', 'Dismiss'
        );

        if (action === 'Copy Config') {
            await vscode.env.clipboard.writeText(mcpJson);
            vscode.window.showInformationMessage('MCP config copied to clipboard!');
        }
    }
}

/**
 * Generate MCP configuration JSON for manual setup
 */
function getMcpConfigJson(extensionPath: string): { scriptPath: string; config: object } {
    const scriptPath = createMcpScript(extensionPath);
    const config = {
        "flutter-preview": {
            "type": "stdio",
            "command": scriptPath
        }
    };
    return { scriptPath, config };
}

/**
 * Show MCP setup instructions to users
 */
async function showMcpSetupInstructions(context: vscode.ExtensionContext): Promise<void> {
    const { scriptPath, config } = getMcpConfigJson(context.extensionPath);

    const options = ['Copy MCP Config', 'Open MCP Settings', 'Learn More'];
    const selected = await vscode.window.showInformationMessage(
        'To use Flutter Preview with GitHub Copilot, you need to configure MCP.',
        ...options
    );

    if (selected === 'Copy MCP Config') {
        await vscode.env.clipboard.writeText(JSON.stringify(config, null, 2));
        vscode.window.showInformationMessage(
            'MCP config copied! Add it to your .vscode/mcp.json or VS Code MCP settings.'
        );
    } else if (selected === 'Open MCP Settings') {
        // Try to open the MCP settings file
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (workspaceFolder) {
            const mcpJsonPath = vscode.Uri.joinPath(workspaceFolder.uri, '.vscode', 'mcp.json');
            try {
                await vscode.workspace.fs.stat(mcpJsonPath);
                await vscode.window.showTextDocument(mcpJsonPath);
            } catch {
                // File doesn't exist, create it
                const initialConfig = {
                    servers: config
                };
                await vscode.workspace.fs.writeFile(
                    mcpJsonPath,
                    Buffer.from(JSON.stringify(initialConfig, null, 2))
                );
                await vscode.window.showTextDocument(mcpJsonPath);
            }
        }
    } else if (selected === 'Learn More') {
        vscode.env.openExternal(vscode.Uri.parse('https://code.visualstudio.com/docs/copilot/chat/mcp-servers'));
    }
}

/**
 * Register the MCP server provider with VS Code.
 */
export function registerMcpServer(context: vscode.ExtensionContext): void {
    const appName = vscode.env.appName || '';
    const appNameLower = appName.toLowerCase();

    const isVsCode = appNameLower.includes('visual studio code');

    console.log(`Flutter Preview MCP: Detected appName="${appName}", isVsCode=${isVsCode}`);

    // Register a command to help users set up MCP manually
    context.subscriptions.push(
        vscode.commands.registerCommand('flutterPreview.setupMcp', () => {
            showMcpSetupInstructions(context);
        })
    );

    // For VS Code: try to use the native API (only works in Insiders with proposed APIs)
    if (isVsCode) {
        const lmApi = (vscode as any).lm;
        if (lmApi && typeof lmApi.registerMcpServerDefinitionProvider === 'function') {
            try {
                const provider = new FlutterPreviewMcpProvider(context.extensionPath);
                context.subscriptions.push(
                    lmApi.registerMcpServerDefinitionProvider(
                        'flutter-preview.mcp-server',
                        provider
                    )
                );
                console.log('Flutter Preview MCP: Server provider registered with VS Code API');
                return;
            } catch (e) {
                console.warn('Flutter Preview MCP: Failed to register with VS Code API:', e);
            }
        } else {
            console.log('Flutter Preview MCP: VS Code MCP API not available (requires VS Code Insiders or newer version)');
        }
    }

    // For other IDEs (Cursor, Antigravity, etc.): prompt to install via deep link
    console.log('Flutter Preview MCP: Prompting for MCP install');
    promptMcpInstall(context, appName);
}
