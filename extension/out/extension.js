"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const codelens_1 = require("./codelens");
const runner_1 = require("./runner");
const webview_1 = require("./webview");
let previewRunner;
function activate(context) {
    console.log('Fontes Widget Viewer activating...');
    const outputChannel = vscode.window.createOutputChannel('Fontes Widget Viewer');
    context.subscriptions.push(outputChannel);
    previewRunner = new runner_1.PreviewRunner(context.extensionPath, outputChannel);
    context.subscriptions.push(vscode.languages.registerCodeLensProvider({ language: 'dart', scheme: 'file' }, new codelens_1.CodeLensProvider()));
    context.subscriptions.push(vscode.commands.registerCommand('fontesWidgetViewer.previewTest', async (args) => {
        outputChannel.show();
        outputChannel.appendLine(`Starting preview for: ${args.testName}`);
        try {
            const config = vscode.workspace.getConfiguration('fontesWidgetViewer');
            const webPort = config.get('webPort', 9090);
            const openInBrowser = config.get('openInBrowser', false);
            const grpcPort = await previewRunner.startTest(args.file, args.testName);
            if (grpcPort) {
                await previewRunner.startViewer(grpcPort, webPort);
                if (openInBrowser) {
                    vscode.env.openExternal(vscode.Uri.parse(`http://localhost:${webPort}`));
                }
                else {
                    webview_1.PreviewPanel.createOrShow(context.extensionUri, webPort);
                }
                outputChannel.appendLine(`Preview running at http://localhost:${webPort}`);
            }
        }
        catch (error) {
            outputChannel.appendLine(`Error: ${error}`);
            vscode.window.showErrorMessage(`Failed to start preview: ${error}`);
        }
    }));
    context.subscriptions.push(vscode.commands.registerCommand('fontesWidgetViewer.stopPreview', () => {
        previewRunner?.stop();
        webview_1.PreviewPanel.currentPanel?.dispose();
        outputChannel.appendLine('Preview stopped');
    }));
    console.log('Fontes Widget Viewer activated');
}
function deactivate() {
    previewRunner?.stop();
}
//# sourceMappingURL=extension.js.map