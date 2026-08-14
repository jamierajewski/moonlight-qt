#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILDS_DIR="$SCRIPT_DIR/builds"
mkdir -p "$BUILDS_DIR"
rm -f "$BUILDS_DIR/Moonlight-x86_64.AppImage"

echo "=== Building Linux AppImage ==="

# Check submodules
if [ ! -f moonlight-common-c/moonlight-common-c/CMakeLists.txt ]; then
    echo "Initializing submodules..."
    git submodule update --init --recursive
fi

# Build via Docker (multi-stage, artifact output)
echo "Building Docker image (this will take a while on first run)..."
DOCKER_BUILDKIT=1 docker build \
    --progress=plain \
    -f Dockerfile.linux \
    --target artifact \
    --output "type=local,dest=$BUILDS_DIR" \
    .

if [ -f "$BUILDS_DIR/Moonlight-x86_64.AppImage" ]; then
    echo "=== AppImage built successfully ==="
    echo "Output: $BUILDS_DIR/Moonlight-x86_64.AppImage"
else
    echo "ERROR: AppImage not found in output directory"
    exit 1
fi

echo ""
echo "=== Build artifacts in ./builds/ ==="
ls -lh "$BUILDS_DIR/"
