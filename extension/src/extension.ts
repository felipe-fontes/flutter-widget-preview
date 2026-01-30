import * as vscode from 'vscode';
import { CodeLensProvider } from './codelens';
import { PreviewRunner } from './runner';
import { PreviewPanel } from './webview';
import { registerMcpServer } from './mcpProvider';
import {
    DEVICE_RESOLUTIONS,
    DeviceResolution,
    formatResolutionLabel,
    formatResolutionDetail,
    getDefaultResolution,
    getResolutionByName,
} from './resolutions';

let previewRunner: PreviewRunner | undefined;
let currentResolution: DeviceResolution = getDefaultResolution();

/** Key for storing resolution in workspace state */
const RESOLUTION_STATE_KEY = 'fontesWidgetViewer.selectedResolution';

export function activate(context: vscode.ExtensionContext): void {
    console.log('Fontes Widget Viewer activating...');

    const outputChannel = vscode.window.createOutputChannel('Fontes Widget Viewer');
    context.subscriptions.push(outputChannel);

    // Register MCP server provider for AI assistants
    registerMcpServer(context);

    // Restore saved resolution from workspace state
    const savedResolutionName = context.workspaceState.get<string>(RESOLUTION_STATE_KEY);
    if (savedResolutionName) {
        const saved = getResolutionByName(savedResolutionName);
        if (saved) {
            currentResolution = saved;
        }
    }

    previewRunner = new PreviewRunner(context.extensionPath, outputChannel);

    // Register CodeLens provider for Dart files
    context.subscriptions.push(
        vscode.languages.registerCodeLensProvider(
            { language: 'dart', scheme: 'file' },
            new CodeLensProvider()
        )
    );

    // Register preview command
    context.subscriptions.push(
        vscode.commands.registerCommand(
            'fontesWidgetViewer.previewTest',
            async (args: { file: string; testName: string; line: number }) => {
                outputChannel.show();
                outputChannel.appendLine(`Starting preview for: ${args.testName}`);
                outputChannel.appendLine(`Resolution: ${currentResolution.name} (${currentResolution.width}×${currentResolution.height} @${currentResolution.devicePixelRatio}x)`);

                try {
                    const config = vscode.workspace.getConfiguration('fontesWidgetViewer');
                    const webPort = config.get<number>('webPort', 9090);
                    const openInBrowser = config.get<boolean>('openInBrowser', false);

                    const grpcPort = await previewRunner!.startTest(
                        args.file,
                        args.testName,
                        currentResolution
                    );

                    if (grpcPort) {
                        await previewRunner!.startViewer(grpcPort, webPort);

                        if (openInBrowser) {
                            vscode.env.openExternal(vscode.Uri.parse(`http://localhost:${webPort}`));
                        } else {
                            PreviewPanel.createOrShow(context.extensionUri, webPort, () => {
                                // Stop the preview runner when the webview panel is closed
                                previewRunner?.stop();
                                outputChannel.appendLine('Preview panel closed, stopping preview');
                            });
                        }

                        outputChannel.appendLine(`Preview running at http://localhost:${webPort}`);
                    }
                } catch (error) {
                    outputChannel.appendLine(`Error: ${error}`);
                    vscode.window.showErrorMessage(`Failed to start preview: ${error}`);
                }
            }
        )
    );

    // Register stop command
    context.subscriptions.push(
        vscode.commands.registerCommand('fontesWidgetViewer.stopPreview', () => {
            previewRunner?.stop();
            PreviewPanel.currentPanel?.dispose();
            outputChannel.appendLine('Preview stopped');
        })
    );

    // Register resolution selection command
    context.subscriptions.push(
        vscode.commands.registerCommand('fontesWidgetViewer.selectResolution', async () => {
            // Build quick pick items grouped by category
            const categories = ['iOS', 'Android', 'Desktop'] as const;
            const items: (vscode.QuickPickItem & { resolution?: DeviceResolution })[] = [];

            for (const category of categories) {
                // Add separator
                items.push({
                    label: category,
                    kind: vscode.QuickPickItemKind.Separator,
                });

                // Add resolutions in this category
                const resolutions = DEVICE_RESOLUTIONS.filter(r => r.category === category);
                for (const res of resolutions) {
                    const isCurrent = res.name === currentResolution.name;
                    items.push({
                        label: `${isCurrent ? '$(check) ' : ''}${formatResolutionLabel(res)}`,
                        description: formatResolutionDetail(res),
                        resolution: res,
                    });
                }
            }

            const selected = await vscode.window.showQuickPick(items, {
                placeHolder: `Current: ${formatResolutionLabel(currentResolution)}`,
                title: 'Select Preview Resolution',
            });

            if (selected?.resolution) {
                currentResolution = selected.resolution;
                // Persist to workspace state
                await context.workspaceState.update(RESOLUTION_STATE_KEY, currentResolution.name);

                const physicalWidth = Math.round(currentResolution.width * currentResolution.devicePixelRatio);
                const physicalHeight = Math.round(currentResolution.height * currentResolution.devicePixelRatio);
                vscode.window.showInformationMessage(
                    `Preview resolution set to ${currentResolution.name} (${physicalWidth}×${physicalHeight})`
                );
                outputChannel.appendLine(`Resolution changed to: ${currentResolution.name}`);
            }
        })
    );

    console.log('Fontes Widget Viewer activated');
}

export function deactivate(): void {
    previewRunner?.stop();
}
