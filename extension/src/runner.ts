import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { spawn, ChildProcess, execSync } from 'child_process';
import { DeviceResolution } from './resolutions';
import { detectFlutterSdkPath } from './flutter';

export class PreviewRunner {
    private testProcess: ChildProcess | undefined;
    private viewerProcess: ChildProcess | undefined;
    private readonly fontsPath: string;
    private readonly templatesPath: string;
    private flutterSdkPath: string | undefined;
    private injectedConfigPath: string | undefined;
    private originalPubspecContent: string | undefined;
    private modifiedPubspecPath: string | undefined;
    private originalPubspecLockContent: string | undefined;

    constructor(
        private readonly extensionPath: string,
        private readonly outputChannel: vscode.OutputChannel
    ) {
        this.fontsPath = path.join(extensionPath, 'fonts');
        this.templatesPath = path.join(extensionPath, 'templates');
        this.flutterSdkPath = detectFlutterSdkPath();
        if (this.flutterSdkPath) {
            this.outputChannel.appendLine(`Flutter SDK: ${this.flutterSdkPath}`);
        } else {
            this.outputChannel.appendLine('Could not detect Flutter SDK path - MaterialIcons may not render');
        }
    }

    private async injectTestConfig(testDir: string, projectRoot: string): Promise<void> {
        const configPath = path.join(testDir, 'flutter_test_config.dart');

        // Check if config already exists
        if (fs.existsSync(configPath)) {
            const content = fs.readFileSync(configPath, 'utf-8');
            if (!content.includes('Fontes Widget Viewer')) {
                // User has their own config - we can't inject
                this.outputChannel.appendLine('Warning: flutter_test_config.dart already exists. Preview may not work.');
                return;
            }
        }

        // Copy our template
        const templatePath = path.join(this.templatesPath, 'flutter_test_config.dart');
        if (fs.existsSync(templatePath)) {
            fs.copyFileSync(templatePath, configPath);
            this.injectedConfigPath = configPath;
            this.outputChannel.appendLine(`Injected flutter_test_config.dart into ${testDir}`);
        }

        // Ensure preview_binding is available - add as path dependency
        await this.ensurePreviewBindingDependency(projectRoot);
    }

    private async ensurePreviewBindingDependency(projectRoot: string): Promise<void> {
        const pubspecPath = path.join(projectRoot, 'pubspec.yaml');
        const pubspecLockPath = path.join(projectRoot, 'pubspec.lock');
        if (!fs.existsSync(pubspecPath)) return;

        const content = fs.readFileSync(pubspecPath, 'utf-8');

        // Backup original pubspec.yaml content for restoration
        this.originalPubspecContent = content;
        this.modifiedPubspecPath = pubspecPath;

        // Also backup pubspec.lock if it exists
        if (fs.existsSync(pubspecLockPath)) {
            this.originalPubspecLockContent = fs.readFileSync(pubspecLockPath, 'utf-8');
        }

        if (content.includes('preview_binding:')) {
            this.outputChannel.appendLine('preview_binding already in pubspec.yaml');
            // Don't restore if it was already there
            this.originalPubspecContent = undefined;
            this.modifiedPubspecPath = undefined;
            this.originalPubspecLockContent = undefined;
            return;
        }

        // Find the preview_binding package path (inside the extension folder)
        const previewBindingPath = path.join(this.extensionPath, 'packages', 'preview_binding');
        const absolutePath = path.resolve(previewBindingPath);

        if (!fs.existsSync(absolutePath)) {
            this.outputChannel.appendLine(`Warning: preview_binding not found at ${absolutePath}`);
            return;
        }

        // Add preview_binding as a dev dependency
        const devDepsMatch = content.match(/dev_dependencies:\s*\n/);
        if (devDepsMatch) {
            const insertPos = devDepsMatch.index! + devDepsMatch[0].length;
            const newContent = content.slice(0, insertPos) +
                `  preview_binding:\n    path: ${absolutePath}\n` +
                content.slice(insertPos);
            fs.writeFileSync(pubspecPath, newContent);
            this.outputChannel.appendLine(`Added preview_binding to dev_dependencies`);
        } else {
            // No dev_dependencies section - add it
            const newContent = content + `\ndev_dependencies:\n  preview_binding:\n    path: ${absolutePath}\n`;
            fs.writeFileSync(pubspecPath, newContent);
            this.outputChannel.appendLine(`Added dev_dependencies with preview_binding`);
        }

        // Run flutter pub get
        this.outputChannel.appendLine('Running flutter pub get...');
        try {
            execSync('flutter pub get', { cwd: projectRoot, stdio: 'pipe' });
            this.outputChannel.appendLine('flutter pub get completed');
        } catch (e) {
            this.outputChannel.appendLine(`flutter pub get failed: ${e}`);
        }
    }

    private cleanupInjectedConfig(): void {
        this.outputChannel.appendLine('Cleaning up injected files...');

        // Remove injected flutter_test_config.dart
        if (this.injectedConfigPath && fs.existsSync(this.injectedConfigPath)) {
            try {
                fs.unlinkSync(this.injectedConfigPath);
                this.outputChannel.appendLine(`Removed flutter_test_config.dart`);
            } catch (e) {
                this.outputChannel.appendLine(`Failed to remove flutter_test_config.dart: ${e}`);
            }
        }
        this.injectedConfigPath = undefined;

        // Restore original pubspec.yaml
        if (this.modifiedPubspecPath && this.originalPubspecContent) {
            try {
                fs.writeFileSync(this.modifiedPubspecPath, this.originalPubspecContent);
                this.outputChannel.appendLine(`Restored original pubspec.yaml`);
            } catch (e) {
                this.outputChannel.appendLine(`Failed to restore pubspec.yaml: ${e}`);
            }

            // Restore original pubspec.lock (must do before clearing modifiedPubspecPath)
            if (this.originalPubspecLockContent) {
                const lockPath = this.modifiedPubspecPath.replace('pubspec.yaml', 'pubspec.lock');
                try {
                    fs.writeFileSync(lockPath, this.originalPubspecLockContent);
                    this.outputChannel.appendLine(`Restored original pubspec.lock`);
                } catch (e) {
                    this.outputChannel.appendLine(`Failed to restore pubspec.lock: ${e}`);
                }
            }
        }

        // Clear all state
        this.originalPubspecContent = undefined;
        this.modifiedPubspecPath = undefined;
        this.originalPubspecLockContent = undefined;
    }

    /**
     * Find the Flutter project root by looking for pubspec.yaml
     * starting from the test file and walking up the directory tree.
     */
    private findProjectRoot(testFile: string): string | undefined {
        let dir = path.dirname(testFile);
        const root = path.parse(dir).root;

        while (dir !== root) {
            const pubspecPath = path.join(dir, 'pubspec.yaml');
            if (fs.existsSync(pubspecPath)) {
                return dir;
            }
            dir = path.dirname(dir);
        }
        return undefined;
    }

    async startTest(testFile: string, testName: string, resolution: DeviceResolution): Promise<number | undefined> {
        await this.stop();

        // Find the Flutter project root (where pubspec.yaml is)
        const projectRoot = this.findProjectRoot(testFile);
        if (!projectRoot) {
            throw new Error('No Flutter project found (pubspec.yaml not found)');
        }

        const testDir = path.dirname(testFile);

        // Inject the flutter_test_config.dart
        await this.injectTestConfig(testDir, projectRoot);

        // Calculate physical dimensions for the test
        const physicalWidth = Math.round(resolution.width * resolution.devicePixelRatio);
        const physicalHeight = Math.round(resolution.height * resolution.devicePixelRatio);

        this.outputChannel.appendLine(`Running test: ${testName}`);
        this.outputChannel.appendLine(`File: ${testFile}`);
        this.outputChannel.appendLine(`CWD: ${projectRoot}`);
        this.outputChannel.appendLine(`Fonts path: ${this.fontsPath}`);
        if (this.flutterSdkPath) {
            this.outputChannel.appendLine(`Flutter SDK: ${this.flutterSdkPath}`);
        }
        this.outputChannel.appendLine(`Resolution: ${resolution.name} - ${resolution.width}×${resolution.height} logical, ${physicalWidth}×${physicalHeight} physical @${resolution.devicePixelRatio}x`);

        return new Promise((resolve, reject) => {
            const args = [
                'test',
                testFile,
                '--name', `"${testName}"`,
                '--dart-define=ENABLE_PREVIEW=true',
                `--dart-define=PREVIEW_FONTS_PATH=${this.fontsPath}`,
                `--dart-define=PREVIEW_WIDTH=${resolution.width}`,
                `--dart-define=PREVIEW_HEIGHT=${resolution.height}`,
                `--dart-define=PREVIEW_DEVICE_PIXEL_RATIO=${resolution.devicePixelRatio}`,
            ];

            // Add Flutter SDK path if available
            if (this.flutterSdkPath) {
                args.push(`--dart-define=PREVIEW_FLUTTER_SDK_PATH=${this.flutterSdkPath}`);
            }

            this.outputChannel.appendLine(`Command: flutter ${args.join(' ')}`);

            this.testProcess = spawn('flutter', args, {
                cwd: projectRoot,
                shell: true,
                env: { ...process.env },
            });

            let grpcPort: number | undefined;
            let resolved = false;

            this.testProcess.stdout?.on('data', (data: Buffer) => {
                const output = data.toString();
                this.outputChannel.append(output);

                // Look for gRPC server port announcement
                const portMatch = output.match(/GRPC_SERVER_STARTED:(\d+)/);
                if (portMatch && !resolved) {
                    grpcPort = parseInt(portMatch[1], 10);
                    this.outputChannel.appendLine(`\ngRPC server started on port ${grpcPort}`);
                    resolved = true;
                    // Test execution is done, cleanup injected files now
                    // The gRPC server will continue serving frames from memory
                    this.cleanupInjectedConfig();
                    resolve(grpcPort);
                }

                // Alternative format
                const previewMatch = output.match(/PREVIEW_SERVER_STARTED:grpc:\/\/localhost:(\d+)/);
                if (previewMatch && !resolved) {
                    grpcPort = parseInt(previewMatch[1], 10);
                    this.outputChannel.appendLine(`\nPreview server started on port ${grpcPort}`);
                    resolved = true;
                    // Test execution is done, cleanup injected files now
                    this.cleanupInjectedConfig();
                    resolve(grpcPort);
                }
            });

            this.testProcess.stderr?.on('data', (data: Buffer) => {
                this.outputChannel.append(data.toString());
            });

            this.testProcess.on('error', (error: Error) => {
                this.outputChannel.appendLine(`Test process error: ${error.message}`);
                if (!resolved) {
                    resolved = true;
                    reject(error);
                }
            });

            this.testProcess.on('close', (code: number | null) => {
                this.outputChannel.appendLine(`Test process exited with code ${code}`);
                // Cleanup in case it wasn't done yet (e.g., test failed before gRPC started)
                this.cleanupInjectedConfig();
                if (!resolved) {
                    resolved = true;
                    if (code === 0) {
                        resolve(undefined);
                    } else {
                        reject(new Error(`Test process exited with code ${code}`));
                    }
                }
            });

            // Timeout after 30 seconds
            setTimeout(() => {
                if (!resolved) {
                    resolved = true;
                    reject(new Error('Timeout waiting for gRPC server to start (30s)'));
                }
            }, 30000);
        });
    }

    async startViewer(grpcPort: number, webPort: number): Promise<void> {
        // Stop any existing viewer process gracefully
        if (this.viewerProcess) {
            const proc = this.viewerProcess;
            this.viewerProcess = undefined;
            await this.killProcess(proc, 'Old viewer');
        }

        // Kill any stale processes that might be using our port
        await this.killProcessOnPort(webPort);

        // Small extra delay to ensure port is fully released
        await new Promise<void>((resolve) => setTimeout(resolve, 200));

        // The viewer package is inside the extension folder
        const viewerPackagePath = path.join(this.extensionPath, 'packages', 'preview_viewer');

        // Path to the shared HTML template
        const templatePath = path.join(this.extensionPath, 'templates', 'viewer.html');

        this.outputChannel.appendLine(`Starting viewer...`);
        this.outputChannel.appendLine(`  Viewer path: ${viewerPackagePath}`);
        this.outputChannel.appendLine(`  Template path: ${templatePath}`);
        this.outputChannel.appendLine(`  gRPC port: ${grpcPort}`);
        this.outputChannel.appendLine(`  Web port: ${webPort}`);

        return new Promise((resolve, reject) => {
            this.viewerProcess = spawn(
                'dart',
                [
                    'run',
                    'bin/preview_viewer.dart',
                    '--grpc-port', grpcPort.toString(),
                    '--web-port', webPort.toString(),
                    '--template', templatePath,
                ],
                {
                    cwd: viewerPackagePath,
                    shell: true,
                    env: { ...process.env },
                }
            );

            let resolved = false;

            this.viewerProcess.stdout?.on('data', (data: Buffer) => {
                const output = data.toString();
                this.outputChannel.append(`[viewer] ${output}`);

                // Wait for the actual server ready signal
                if (!resolved && output.includes('VIEWER_SERVER_STARTED')) {
                    resolved = true;
                    this.outputChannel.appendLine('Viewer server is ready!');
                    resolve();
                }
            });

            this.viewerProcess.stderr?.on('data', (data: Buffer) => {
                this.outputChannel.append(`[viewer] ${data.toString()}`);
            });

            this.viewerProcess.on('error', (error: Error) => {
                this.outputChannel.appendLine(`Viewer error: ${error.message}`);
                if (!resolved) {
                    resolved = true;
                    reject(error);
                }
            });

            this.viewerProcess.on('close', (code: number | null) => {
                if (!resolved) {
                    resolved = true;
                    reject(new Error(`Viewer process exited with code ${code} before server started`));
                }
            });

            // Timeout after 30 seconds
            setTimeout(() => {
                if (!resolved) {
                    resolved = true;
                    this.outputChannel.appendLine('Warning: Timeout waiting for viewer server, continuing anyway...');
                    resolve();
                }
            }, 30000);
        });
    }

    async stop(): Promise<void> {
        // Cleanup injected files first
        this.cleanupInjectedConfig();

        const stopPromises: Promise<void>[] = [];

        if (this.testProcess) {
            const proc = this.testProcess;
            this.testProcess = undefined;
            stopPromises.push(this.killProcess(proc, 'Test'));
        }

        if (this.viewerProcess) {
            const proc = this.viewerProcess;
            this.viewerProcess = undefined;
            stopPromises.push(this.killProcess(proc, 'Viewer'));
        }

        // Wait for all processes to die
        await Promise.all(stopPromises);
    }

    private killProcess(proc: ChildProcess, name: string): Promise<void> {
        return new Promise((resolve) => {
            // If already dead, resolve immediately
            if (proc.killed || proc.exitCode !== null) {
                this.outputChannel.appendLine(`${name} process already stopped`);
                resolve();
                return;
            }

            // Set up listener for process exit
            const onExit = () => {
                this.outputChannel.appendLine(`${name} process stopped`);
                resolve();
            };

            proc.once('exit', onExit);
            proc.once('close', onExit);

            // Try graceful SIGTERM first
            proc.kill('SIGTERM');

            // Force kill after 1 second if still alive
            setTimeout(() => {
                if (!proc.killed && proc.exitCode === null) {
                    this.outputChannel.appendLine(`${name} process didn't respond to SIGTERM, using SIGKILL`);
                    proc.kill('SIGKILL');
                }
            }, 1000);

            // Safety timeout - resolve anyway after 2 seconds
            setTimeout(() => {
                resolve();
            }, 2000);
        });
    }

    /**
     * Kill any processes using a specific port.
     * This is a fallback when our tracked processes don't match what's actually running.
     */
    async killProcessOnPort(port: number): Promise<void> {
        return new Promise((resolve) => {
            // Use lsof to find processes on the port and kill them
            const findProcess = spawn('lsof', ['-ti', `:${port}`], { shell: true });

            let pids = '';
            findProcess.stdout?.on('data', (data: Buffer) => {
                pids += data.toString();
            });

            findProcess.on('close', () => {
                const pidList = pids.trim().split('\n').filter(p => p);
                if (pidList.length > 0) {
                    this.outputChannel.appendLine(`Found processes on port ${port}: ${pidList.join(', ')}`);
                    for (const pid of pidList) {
                        try {
                            process.kill(parseInt(pid, 10), 'SIGKILL');
                            this.outputChannel.appendLine(`Killed process ${pid}`);
                        } catch (e) {
                            // Process might already be dead
                        }
                    }
                    // Give time for port to be released
                    setTimeout(resolve, 500);
                } else {
                    resolve();
                }
            });

            findProcess.on('error', () => {
                resolve(); // Ignore errors from lsof not being available
            });
        });
    }
}
