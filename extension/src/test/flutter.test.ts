import * as assert from 'assert';
import * as path from 'path';
import { detectFlutterSdkPath, FlutterDetectionDeps } from '../flutter';

/**
 * Create mock dependencies for testing detectFlutterSdkPath.
 */
function createMockDeps(overrides: Partial<FlutterDetectionDeps> = {}): FlutterDetectionDeps {
    return {
        env: {},
        existsSync: () => false,
        realpathSync: (p) => p,
        execSync: () => { throw new Error('command not found'); },
        ...overrides,
    };
}

describe('detectFlutterSdkPath', () => {
    describe('FLUTTER_ROOT environment variable', () => {
        it('should detect Flutter SDK from FLUTTER_ROOT', () => {
            const deps = createMockDeps({
                env: { FLUTTER_ROOT: '/usr/local/flutter' },
                existsSync: (p) => p === '/usr/local/flutter/bin/flutter',
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/usr/local/flutter');
        });

        it('should detect Flutter SDK from FLUTTER_ROOT with spaces in path', () => {
            const deps = createMockDeps({
                env: { FLUTTER_ROOT: '/Users/John Doe/Development/flutter sdk' },
                existsSync: (p) => p === '/Users/John Doe/Development/flutter sdk/bin/flutter',
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/Users/John Doe/Development/flutter sdk');
        });

        it('should detect Flutter SDK from FLUTTER_ROOT with special characters', () => {
            const deps = createMockDeps({
                env: { FLUTTER_ROOT: '/home/user/dev/flutter-3.19.0' },
                existsSync: (p) => p === '/home/user/dev/flutter-3.19.0/bin/flutter',
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/home/user/dev/flutter-3.19.0');
        });

        it('should skip invalid FLUTTER_ROOT if bin/flutter does not exist', () => {
            const deps = createMockDeps({
                env: { FLUTTER_ROOT: '/invalid/path' },
                existsSync: () => false,
                execSync: () => '/usr/bin/flutter',
                realpathSync: (p) => p === '/usr/bin/flutter' ? '/home/user/flutter/bin/flutter' : p,
            });

            // Since FLUTTER_ROOT is invalid, it should try which flutter
            // But execSync returns a path, and existsSync returns false, so no result
            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, undefined);
        });
    });

    describe('which flutter command', () => {
        it('should detect Flutter SDK from which flutter', () => {
            const deps = createMockDeps({
                env: {},
                execSync: () => '/usr/local/bin/flutter\n',
                realpathSync: (p) => p === '/usr/local/bin/flutter'
                    ? '/opt/flutter/bin/flutter'
                    : p,
                existsSync: (p) => p === '/opt/flutter/bin/flutter',
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/opt/flutter');
        });

        it('should detect Flutter SDK from symlinked flutter command', () => {
            const deps = createMockDeps({
                env: {},
                execSync: () => '/home/user/.local/bin/flutter',
                realpathSync: (p) => p === '/home/user/.local/bin/flutter'
                    ? '/home/user/development/flutter-stable/bin/flutter'
                    : p,
                existsSync: (p) => p === '/home/user/development/flutter-stable/bin/flutter',
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/home/user/development/flutter-stable');
        });

        it('should detect Flutter SDK with odd directory names', () => {
            const deps = createMockDeps({
                env: {},
                execSync: () => '/Users/dev user/my flutter (beta)/bin/flutter',
                realpathSync: (p) => p,
                existsSync: (p) => p === '/Users/dev user/my flutter (beta)/bin/flutter',
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/Users/dev user/my flutter (beta)');
        });

        it('should detect Flutter SDK with unicode characters in path', () => {
            const deps = createMockDeps({
                env: {},
                execSync: () => '/home/用户/フラッター/bin/flutter',
                realpathSync: (p) => p,
                existsSync: (p) => p === '/home/用户/フラッター/bin/flutter',
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/home/用户/フラッター');
        });

        it('should handle which flutter failure gracefully', () => {
            const deps = createMockDeps({
                env: {},
                execSync: () => { throw new Error('flutter: command not found'); },
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, undefined);
        });
    });

    describe('FVM paths', () => {
        it('should detect Flutter SDK from FVM default path', () => {
            const deps = createMockDeps({
                env: { HOME: '/home/user' },
                execSync: () => { throw new Error('not found'); },
                existsSync: (p) => p === '/home/user/fvm/default/bin/flutter',
                realpathSync: (p) => p === '/home/user/fvm/default'
                    ? '/home/user/fvm/versions/3.19.0'
                    : p,
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/home/user/fvm/versions/3.19.0');
        });

        it('should detect Flutter SDK from FVM with spaces in HOME', () => {
            const deps = createMockDeps({
                env: { HOME: '/Users/John Smith' },
                execSync: () => { throw new Error('not found'); },
                existsSync: (p) => p === '/Users/John Smith/fvm/default/bin/flutter',
                realpathSync: (p) => p === '/Users/John Smith/fvm/default'
                    ? '/Users/John Smith/fvm/versions/stable'
                    : p,
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/Users/John Smith/fvm/versions/stable');
        });
    });

    describe('priority order', () => {
        it('should prefer FLUTTER_ROOT over which flutter', () => {
            const deps = createMockDeps({
                env: { FLUTTER_ROOT: '/priority/flutter' },
                existsSync: (p) =>
                    p === '/priority/flutter/bin/flutter' ||
                    p === '/which/flutter/bin/flutter',
                execSync: () => '/which/flutter/bin/flutter',
                realpathSync: (p) => p,
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/priority/flutter');
        });

        it('should prefer which flutter over FVM', () => {
            const deps = createMockDeps({
                env: { HOME: '/home/user' },
                existsSync: (p) =>
                    p === '/which/flutter/bin/flutter' ||
                    p === '/home/user/fvm/default/bin/flutter',
                execSync: () => '/which/flutter/bin/flutter',
                realpathSync: (p) => p,
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, '/which/flutter');
        });
    });

    describe('edge cases', () => {
        it('should return undefined when no Flutter SDK is found', () => {
            const deps = createMockDeps({
                env: {},
                existsSync: () => false,
                execSync: () => { throw new Error('not found'); },
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, undefined);
        });

        it('should handle empty HOME environment variable', () => {
            const deps = createMockDeps({
                env: { HOME: '' },
                existsSync: () => false,
                execSync: () => { throw new Error('not found'); },
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, undefined);
        });

        it('should handle missing HOME environment variable', () => {
            const deps = createMockDeps({
                env: {},
                existsSync: () => false,
                execSync: () => { throw new Error('not found'); },
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, undefined);
        });

        it('should handle very long paths', () => {
            const longPath = '/home/user/' + 'deeply/nested/'.repeat(50) + 'flutter';
            const deps = createMockDeps({
                env: { FLUTTER_ROOT: longPath },
                existsSync: (p) => p === path.join(longPath, 'bin', 'flutter'),
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, longPath);
        });

        it('should handle Windows-style paths (when on Windows)', () => {
            // This simulates running on Windows where path.join uses backslashes
            const deps = createMockDeps({
                env: { FLUTTER_ROOT: 'C:\\Users\\Developer\\flutter' },
                existsSync: (p) => {
                    // path.join will use the OS separator, so we need to handle both
                    return p.includes('flutter') && p.includes('bin');
                },
            });

            const result = detectFlutterSdkPath(deps);
            assert.strictEqual(result, 'C:\\Users\\Developer\\flutter');
        });
    });
});
