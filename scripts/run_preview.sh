#!/usr/bin/env bash
#
# run_preview.sh — Run a Flutter widget test with preview binding from the CLI.
#
# Replicates the VS Code extension's "Preview Widget Test" button without
# needing to build or install the extension.
#
# Usage:
#   ./scripts/run_preview.sh <project_path> <test_file_path> \
#       [--name "test name"] [--width 393] [--height 852] \
#       [--dpr 3.0] [--web-port 9090]

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXTENSION_DIR="$REPO_ROOT/extension"
FONTS_PATH="$EXTENSION_DIR/fonts"
TEMPLATES_DIR="$EXTENSION_DIR/templates"
VIEWER_PACKAGE_DIR="$REPO_ROOT/packages/preview_viewer"
PREVIEW_BINDING_DIR="$REPO_ROOT/packages/preview_binding"
VIEWER_TEMPLATE="$TEMPLATES_DIR/viewer.html"
TEST_CONFIG_TEMPLATE="$TEMPLATES_DIR/flutter_test_config.dart"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
WIDTH=393
HEIGHT=852
DPR=3.0
WEB_PORT=9090
TEST_NAME=""

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
if [[ $# -lt 2 ]]; then
    cat <<EOF
Usage: $0 <project_path> <test_file_path> [options]

Options:
  --name  "test name"   Name filter passed to flutter test --name
  --width  N            Logical width  (default: $WIDTH)
  --height N            Logical height (default: $HEIGHT)
  --dpr    N            Device pixel ratio (default: $DPR)
  --web-port N          Web server port for the viewer (default: $WEB_PORT)

Example:
  $0 /path/to/my_app test/widget_test.dart --name "my widget renders"
EOF
    exit 1
fi

PROJECT_PATH="$(cd "$1" && pwd)"
TEST_FILE="$2"
shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)   TEST_NAME="$2"; shift 2 ;;
        --width)  WIDTH="$2"; shift 2 ;;
        --height) HEIGHT="$2"; shift 2 ;;
        --dpr)    DPR="$2"; shift 2 ;;
        --web-port) WEB_PORT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Resolve test file to absolute path
if [[ "$TEST_FILE" != /* ]]; then
    TEST_FILE="$PROJECT_PATH/$TEST_FILE"
fi

TEST_DIR="$(dirname "$TEST_FILE")"

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------
[[ -f "$TEST_FILE" ]]           || { echo "ERROR: Test file not found: $TEST_FILE"; exit 1; }
[[ -f "$PROJECT_PATH/pubspec.yaml" ]] || { echo "ERROR: No pubspec.yaml in $PROJECT_PATH"; exit 1; }
[[ -d "$VIEWER_PACKAGE_DIR" ]]  || { echo "ERROR: Viewer package not found at $VIEWER_PACKAGE_DIR"; exit 1; }
[[ -f "$VIEWER_TEMPLATE" ]]     || { echo "ERROR: Viewer template not found at $VIEWER_TEMPLATE"; exit 1; }
[[ -f "$TEST_CONFIG_TEMPLATE" ]] || { echo "ERROR: flutter_test_config.dart template not found at $TEST_CONFIG_TEMPLATE"; exit 1; }

# Detect Flutter SDK path
FLUTTER_SDK_PATH="$(dirname "$(dirname "$(which flutter)")")"

# ---------------------------------------------------------------------------
# State tracking for cleanup
# ---------------------------------------------------------------------------
INJECTED_CONFIG=""
PUBSPEC_BACKUP=""
PUBSPEC_LOCK_BACKUP=""
TEST_PID=""
VIEWER_PID=""
TAIL_PID=""
TEST_LOG=""
VIEWER_LOG=""

# Kill any processes using a specific port
kill_port() {
    local port="$1"
    local pids
    pids=$(lsof -ti ":$port" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        echo "  Killing stale processes on port $port: $pids"
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 0.5
    fi
}

cleanup() {
    echo ""
    echo "Cleaning up..."

    # Kill tail -f (log streamer)
    if [[ -n "$TAIL_PID" ]] && kill -0 "$TAIL_PID" 2>/dev/null; then
        kill "$TAIL_PID" 2>/dev/null || true
        wait "$TAIL_PID" 2>/dev/null || true
    fi

    # Kill test process
    if [[ -n "$TEST_PID" ]] && kill -0 "$TEST_PID" 2>/dev/null; then
        kill "$TEST_PID" 2>/dev/null || true
        wait "$TEST_PID" 2>/dev/null || true
        echo "  Stopped test process ($TEST_PID)"
    fi

    # Kill viewer process
    if [[ -n "$VIEWER_PID" ]] && kill -0 "$VIEWER_PID" 2>/dev/null; then
        kill "$VIEWER_PID" 2>/dev/null || true
        wait "$VIEWER_PID" 2>/dev/null || true
        echo "  Stopped viewer process ($VIEWER_PID)"
    fi

    # Remove injected flutter_test_config.dart
    if [[ -n "$INJECTED_CONFIG" && -f "$INJECTED_CONFIG" ]]; then
        rm -f "$INJECTED_CONFIG"
        echo "  Removed $INJECTED_CONFIG"
    fi

    # Restore pubspec.yaml from backup
    if [[ -n "$PUBSPEC_BACKUP" && -f "$PUBSPEC_BACKUP" ]]; then
        mv "$PUBSPEC_BACKUP" "$PROJECT_PATH/pubspec.yaml"
        echo "  Restored pubspec.yaml"
    fi

    # Restore pubspec.lock from backup
    if [[ -n "$PUBSPEC_LOCK_BACKUP" && -f "$PUBSPEC_LOCK_BACKUP" ]]; then
        mv "$PUBSPEC_LOCK_BACKUP" "$PROJECT_PATH/pubspec.lock"
        echo "  Restored pubspec.lock"
    fi

    # Remove temp log files
    [[ -n "$TEST_LOG" && -f "$TEST_LOG" ]] && rm -f "$TEST_LOG"
    [[ -n "$VIEWER_LOG" && -f "$VIEWER_LOG" ]] && rm -f "$VIEWER_LOG"

    echo "Done."
}

trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# 1. Inject flutter_test_config.dart
# ---------------------------------------------------------------------------
CONFIG_DEST="$TEST_DIR/flutter_test_config.dart"

if [[ -f "$CONFIG_DEST" ]]; then
    if grep -q "Fontes Widget Viewer" "$CONFIG_DEST" 2>/dev/null; then
        echo "flutter_test_config.dart already present (ours) — skipping copy"
    else
        echo "WARNING: flutter_test_config.dart exists but is not ours — leaving it in place"
    fi
else
    cp "$TEST_CONFIG_TEMPLATE" "$CONFIG_DEST"
    INJECTED_CONFIG="$CONFIG_DEST"
    echo "Injected flutter_test_config.dart into $TEST_DIR"
fi

# ---------------------------------------------------------------------------
# 2. Ensure preview_binding dependency in pubspec.yaml
# ---------------------------------------------------------------------------
PUBSPEC="$PROJECT_PATH/pubspec.yaml"

if grep -q "preview_binding:" "$PUBSPEC" 2>/dev/null; then
    echo "preview_binding already in pubspec.yaml — skipping injection"
else
    echo "Adding preview_binding to pubspec.yaml..."
    PUBSPEC_BACKUP="$PUBSPEC.run_preview_backup"
    cp "$PUBSPEC" "$PUBSPEC_BACKUP"

    # Also backup pubspec.lock if it exists
    if [[ -f "$PROJECT_PATH/pubspec.lock" ]]; then
        PUBSPEC_LOCK_BACKUP="$PROJECT_PATH/pubspec.lock.run_preview_backup"
        cp "$PROJECT_PATH/pubspec.lock" "$PUBSPEC_LOCK_BACKUP"
    fi

    BINDING_PATH="$(cd "$PREVIEW_BINDING_DIR" && pwd)"

    if grep -q "^dev_dependencies:" "$PUBSPEC"; then
        # Insert after dev_dependencies: line
        sed -i.sedtmp '/^dev_dependencies:/a\
  preview_binding:\
    path: '"$BINDING_PATH"'
' "$PUBSPEC"
        rm -f "$PUBSPEC.sedtmp"
    else
        # Append dev_dependencies section
        printf '\ndev_dependencies:\n  preview_binding:\n    path: %s\n' "$BINDING_PATH" >> "$PUBSPEC"
    fi

    echo "  Added preview_binding path dependency"
fi

# ---------------------------------------------------------------------------
# 3. flutter pub get
# ---------------------------------------------------------------------------
echo "Running flutter pub get..."
(cd "$PROJECT_PATH" && flutter pub get) || { echo "ERROR: flutter pub get failed"; exit 1; }

# ---------------------------------------------------------------------------
# 4. Start flutter test in the background
# ---------------------------------------------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Starting preview test"
echo "  File:       $TEST_FILE"
echo "  Resolution: ${WIDTH}×${HEIGHT} @${DPR}x"
echo "  Fonts:      $FONTS_PATH"
echo "  Flutter SDK: $FLUTTER_SDK_PATH"
echo "═══════════════════════════════════════════════════════════"
echo ""

FLUTTER_ARGS=(
    test
    "$TEST_FILE"
    "--dart-define=ENABLE_PREVIEW=true"
    "--dart-define=PREVIEW_FONTS_PATH=$FONTS_PATH"
    "--dart-define=PREVIEW_WIDTH=$WIDTH"
    "--dart-define=PREVIEW_HEIGHT=$HEIGHT"
    "--dart-define=PREVIEW_DEVICE_PIXEL_RATIO=$DPR"
    "--dart-define=PREVIEW_FLUTTER_SDK_PATH=$FLUTTER_SDK_PATH"
)

if [[ -n "$TEST_NAME" ]]; then
    FLUTTER_ARGS+=(--name "$TEST_NAME")
fi

# ---------------------------------------------------------------------------
# Use a log file so the test process never gets SIGPIPE.
# tail -f streams everything to the terminal in real-time.
# We poll the log file for the gRPC port separately.
# ---------------------------------------------------------------------------
TEST_LOG=$(mktemp "${TMPDIR:-/tmp}/preview_test.XXXXXX.log")

# Start the test process, all output goes to the log file
(cd "$PROJECT_PATH" && flutter "${FLUTTER_ARGS[@]}" > "$TEST_LOG" 2>&1) &
TEST_PID=$!

# Stream the log to the terminal in real-time
tail -f "$TEST_LOG" &
TAIL_PID=$!

# Poll the log file for the gRPC port (timeout after 120s)
GRPC_PORT=""
ELAPSED=0
TIMEOUT=120
while [[ -z "$GRPC_PORT" ]] && kill -0 "$TEST_PID" 2>/dev/null; do
    # Check for GRPC_SERVER_STARTED:<port>
    if grep -qE 'GRPC_SERVER_STARTED:[0-9]+' "$TEST_LOG" 2>/dev/null; then
        GRPC_PORT=$(grep -oE 'GRPC_SERVER_STARTED:([0-9]+)' "$TEST_LOG" | head -1 | cut -d: -f2)
    fi
    # Check for PREVIEW_SERVER_STARTED:grpc://localhost:<port>
    if [[ -z "$GRPC_PORT" ]] && grep -qE 'PREVIEW_SERVER_STARTED:grpc://localhost:[0-9]+' "$TEST_LOG" 2>/dev/null; then
        GRPC_PORT=$(grep -oE 'PREVIEW_SERVER_STARTED:grpc://localhost:([0-9]+)' "$TEST_LOG" | head -1 | grep -oE '[0-9]+$')
    fi
    if [[ -z "$GRPC_PORT" ]]; then
        sleep 0.5
        ELAPSED=$((ELAPSED + 1))
        if [[ $ELAPSED -ge $((TIMEOUT * 2)) ]]; then
            echo ""
            echo "ERROR: Timeout (${TIMEOUT}s) waiting for gRPC server to start."
            exit 1
        fi
    fi
done

if [[ -z "$GRPC_PORT" ]]; then
    echo ""
    echo "ERROR: Test process exited before gRPC server started."
    echo "       Check the test output above for errors."
    exit 1
fi

echo ""
echo ">>> gRPC server started on port $GRPC_PORT"
echo ""

# ---------------------------------------------------------------------------
# 5. Start the viewer
# ---------------------------------------------------------------------------

# Kill any stale processes on the web port first
kill_port "$WEB_PORT"

echo "Starting viewer (gRPC port: $GRPC_PORT, web port: $WEB_PORT)..."

VIEWER_LOG=$(mktemp "${TMPDIR:-/tmp}/preview_viewer.XXXXXX.log")

(cd "$VIEWER_PACKAGE_DIR" && dart run bin/preview_viewer.dart \
    --grpc-port "$GRPC_PORT" \
    --web-port "$WEB_PORT" \
    --template "$VIEWER_TEMPLATE" >> "$VIEWER_LOG" 2>&1) &
VIEWER_PID=$!

# Stream viewer log to terminal (prefixed so it's distinguishable)
(tail -f "$VIEWER_LOG" 2>/dev/null | sed 's/^/[viewer] /') &
VIEWER_TAIL_PID=$!

# Wait for VIEWER_SERVER_STARTED in the viewer log (timeout 30s)
VIEWER_READY=0
for i in $(seq 1 60); do
    if ! kill -0 "$VIEWER_PID" 2>/dev/null; then
        echo ""
        echo "ERROR: Viewer process exited unexpectedly. Log:"
        cat "$VIEWER_LOG"
        exit 1
    fi
    if grep -q 'VIEWER_SERVER_STARTED' "$VIEWER_LOG" 2>/dev/null; then
        VIEWER_READY=1
        break
    fi
    sleep 0.5
done

# Kill the viewer tail now that we're past the wait
kill "$VIEWER_TAIL_PID" 2>/dev/null || true
wait "$VIEWER_TAIL_PID" 2>/dev/null || true

if [[ $VIEWER_READY -eq 0 ]]; then
    echo ""
    echo "WARNING: Timeout waiting for viewer to start (30s). Continuing anyway..."
fi

# ---------------------------------------------------------------------------
# 6. Open the browser
# ---------------------------------------------------------------------------
URL="http://localhost:$WEB_PORT"
echo ""
echo "═══════════════════════════════════════════"
echo "  Opening preview: $URL"
echo "═══════════════════════════════════════════"
echo ""

if command -v open &>/dev/null; then
    open "$URL"
elif command -v xdg-open &>/dev/null; then
    xdg-open "$URL"
else
    echo "Open $URL in your browser manually."
fi

# ---------------------------------------------------------------------------
# 7. Wait for the test process to finish (logs keep streaming via tail -f)
# ---------------------------------------------------------------------------
echo "Press Ctrl+C to stop."
echo ""

TEST_EXIT=0
wait "$TEST_PID" 2>/dev/null || TEST_EXIT=$?

# Give tail a moment to flush remaining output
sleep 1

# Kill the tail process now that the test is done
if kill -0 "$TAIL_PID" 2>/dev/null; then
    kill "$TAIL_PID" 2>/dev/null || true
    wait "$TAIL_PID" 2>/dev/null || true
fi
TAIL_PID=""

echo ""
if [[ $TEST_EXIT -eq 0 ]]; then
    echo "═══════════════════════════════════════════"
    echo "  TEST PASSED"
    echo "═══════════════════════════════════════════"
else
    echo "═══════════════════════════════════════════"
    echo "  TEST FAILED (exit code $TEST_EXIT)"
    echo "═══════════════════════════════════════════"
fi
echo ""

# Give viewer a moment to deliver remaining frames, then stop
sleep 2
if [[ -n "$VIEWER_PID" ]] && kill -0 "$VIEWER_PID" 2>/dev/null; then
    echo "Stopping viewer..."
    kill "$VIEWER_PID" 2>/dev/null || true
    wait "$VIEWER_PID" 2>/dev/null || true
fi

# Cleanup will happen via the EXIT trap
