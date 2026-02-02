import * as path from 'path';
import * as fs from 'fs';
import { execSync } from 'child_process';

/**
 * Dependencies for detectFlutterSdkPath, allows mocking in tests.
 */
export interface FlutterDetectionDeps {
    env: NodeJS.ProcessEnv;
    existsSync: (path: string) => boolean;
    realpathSync: (path: string) => string;
    execSync: (command: string, options?: { encoding: 'utf-8' }) => string;
}

/**
 * Default dependencies using real implementations.
 */
const defaultDeps: FlutterDetectionDeps = {
    env: process.env,
    existsSync: fs.existsSync,
    realpathSync: fs.realpathSync,
    execSync: (cmd, opts) => execSync(cmd, opts) as string,
};

/**
 * Detect the Flutter SDK path by resolving the flutter command.
 * Tries multiple methods: FLUTTER_ROOT env var, which command, common FVM paths.
 * 
 * @param deps - Optional dependencies for testing. Uses real fs/process by default.
 * @returns The Flutter SDK path, or undefined if not found.
 */
export function detectFlutterSdkPath(deps: FlutterDetectionDeps = defaultDeps): string | undefined {
    // Try FLUTTER_ROOT environment variable first
    if (deps.env.FLUTTER_ROOT) {
        const sdkPath = deps.env.FLUTTER_ROOT;
        if (deps.existsSync(path.join(sdkPath, 'bin', 'flutter'))) {
            return sdkPath;
        }
    }

    // Try to resolve 'flutter' command path
    try {
        const flutterPath = deps.execSync('which flutter', { encoding: 'utf-8' }).trim();
        if (flutterPath) {
            // flutter is typically at <SDK>/bin/flutter, so go up 2 levels
            const sdkPath = path.dirname(path.dirname(deps.realpathSync(flutterPath)));
            if (deps.existsSync(path.join(sdkPath, 'bin', 'flutter'))) {
                return sdkPath;
            }
        }
    } catch (e) {
        // which command failed, try other methods
    }

    // Try common FVM paths
    const homeDir = deps.env.HOME || '';
    const fvmPath = path.join(homeDir, 'fvm', 'default');
    if (deps.existsSync(path.join(fvmPath, 'bin', 'flutter'))) {
        return deps.realpathSync(fvmPath);
    }

    return undefined;
}
