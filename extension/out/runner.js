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
exports.PreviewRunner = void 0;
const vscode = __importStar(require("vscode"));
const path = __importStar(require("path"));
const child_process_1 = require("child_process");
class PreviewRunner {
    constructor(extensionPath, outputChannel) {
        this.extensionPath = extensionPath;
        this.outputChannel = outputChannel;
    }
    async startTest(testFile, testName) {
        this.stop();
        const workspaceFolder = vscode.workspace.getWorkspaceFolder(vscode.Uri.file(testFile));
        if (!workspaceFolder) {
            throw new Error('No workspace folder found');
        }
        const cwd = workspaceFolder.uri.fsPath;
        this.outputChannel.appendLine(`Running test: ${testName}`);
        this.outputChannel.appendLine(`File: ${testFile}`);
        this.outputChannel.appendLine(`CWD: ${cwd}`);
        return new Promise((resolve, reject) => {
            const args = [
                'test',
                testFile,
                '--name', testName,
                '--dart-define=ENABLE_PREVIEW=true'
            ];
            this.outputChannel.appendLine(`Command: flutter ${args.join(' ')}`);
            this.testProcess = (0, child_process_1.spawn)('flutter', args, {
                cwd,
                shell: true,
                env: { ...process.env }
            });
            let grpcPort;
            let resolved = false;
            this.testProcess.stdout?.on('data', (data) => {
                const output = data.toString();
                this.outputChannel.append(output);
                const portMatch = output.match(/GRPC_SERVER_STARTED:(\d+)/);
                if (portMatch && !resolved) {
                    grpcPort = parseInt(portMatch[1], 10);
                    this.outputChannel.appendLine(`\ngRPC server started on port ${grpcPort}`);
                    resolved = true;
                    resolve(grpcPort);
                }
                const previewMatch = output.match(/PREVIEW_SERVER_STARTED:grpc:\/\/localhost:(\d+)/);
                if (previewMatch && !resolved) {
                    grpcPort = parseInt(previewMatch[1], 10);
                    this.outputChannel.appendLine(`\nPreview server started on port ${grpcPort}`);
                    resolved = true;
                    resolve(grpcPort);
                }
            });
            this.testProcess.stderr?.on('data', (data) => {
                this.outputChannel.append(data.toString());
            });
            this.testProcess.on('error', (error) => {
                this.outputChannel.appendLine(`Test process error: ${error.message}`);
                if (!resolved) {
                    resolved = true;
                    reject(error);
                }
            });
            this.testProcess.on('close', (code) => {
                this.outputChannel.appendLine(`Test process exited with code ${code}`);
                if (!resolved) {
                    resolved = true;
                    if (code === 0) {
                        resolve(undefined);
                    }
                    else {
                        reject(new Error(`Test process exited with code ${code}`));
                    }
                }
            });
            setTimeout(() => {
                if (!resolved) {
                    resolved = true;
                    reject(new Error('Timeout waiting for gRPC server to start (30s)'));
                }
            }, 30000);
        });
    }
    async startViewer(grpcPort, webPort) {
        if (this.viewerProcess) {
            this.viewerProcess.kill();
        }
        const viewerPackagePath = path.join(this.extensionPath, 'packages', 'preview_viewer');
        this.outputChannel.appendLine(`Starting viewer...`);
        this.outputChannel.appendLine(`  gRPC port: ${grpcPort}`);
        this.outputChannel.appendLine(`  Web port: ${webPort}`);
        this.viewerProcess = (0, child_process_1.spawn)('dart', [
            'run',
            'bin/preview_viewer.dart',
            '--grpc-port', grpcPort.toString(),
            '--web-port', webPort.toString()
        ], {
            cwd: viewerPackagePath,
            shell: true,
            env: { ...process.env }
        });
        this.viewerProcess.stdout?.on('data', (data) => {
            this.outputChannel.append(`[viewer] ${data.toString()}`);
        });
        this.viewerProcess.stderr?.on('data', (data) => {
            this.outputChannel.append(`[viewer] ${data.toString()}`);
        });
        this.viewerProcess.on('error', (error) => {
            this.outputChannel.appendLine(`Viewer error: ${error.message}`);
        });
        await new Promise((resolve) => setTimeout(resolve, 3000));
    }
    stop() {
        if (this.testProcess) {
            this.testProcess.kill();
            this.testProcess = undefined;
            this.outputChannel.appendLine('Test process stopped');
        }
        if (this.viewerProcess) {
            this.viewerProcess.kill();
            this.viewerProcess = undefined;
            this.outputChannel.appendLine('Viewer process stopped');
        }
    }
}
exports.PreviewRunner = PreviewRunner;
//# sourceMappingURL=runner.js.map