import * as vscode from 'vscode';
import { CodeLensProvider } from './codelens';
import { PreviewRunner } from './runner';
import { PreviewPanel } from './webview';

let previewRunner: PreviewRunner | undefined;

export function activate(context: vscode.ExtensionContext): void {
    console.log('Fontes Widget Viewer activating...');

    const outputChannel = vscode.window.createOutputChannel('Fontes Widget Viewer');
    context.subscriptions.push(outputChannel);

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

                try {
                    const config = vscode.workspace.getConfiguration('fontesWidgetViewer');
                    const webPort = config.get<number>('webPort', 9090);
                    const openInBrowser = config.get<boolean>('openInBrowser', false);

                    const grpcPort = await previewRunner!.startTest(args.file, args.testName);

                    if (grpcPort) {
                        await previewRunner!.startViewer(grpcPort, webPort);

                        if (openInBrowser) {
                            vscode.env.openExternal(vscode.Uri.parse(`http://localhost:${webPort}`));
                        } else {
                            PreviewPanel.createOrShow(context.extensionUri, webPort);
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

    console.log('Fontes Widget Viewer activated');
}

export function deactivate(): void {
    previewRunner?.stop();
}
