#!/bin/bash

# Check if workspace path is provided
if [ -z "$1" ]; then
    echo "Usage: ./run-pycolmap.sh /path/to/your/workspace"
    echo ""
    echo "Example:"
    echo "  ./run-pycolmap.sh /home/user/my_colmap_project"
    echo ""
    echo "The workspace directory will be mounted to /workspace inside the container."
    exit 1
fi

WORKSPACE_PATH=$(realpath "$1")

# Check if path exists
if [ ! -d "$WORKSPACE_PATH" ]; then
    echo "❌ Directory does not exist: $WORKSPACE_PATH"
    exit 1
fi

echo "🚀 Starting PyCOLMAP container..."
echo "📁 Workspace: $WORKSPACE_PATH"
echo ""

# Run the container with GPU support
docker run \
    --rm \
    -it \
    --runtime=nvidia \
    --gpus all \
    -v "$WORKSPACE_PATH:/workspace" \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    pycolmap:latest \
    /bin/bash

echo ""
echo "✅ Container exited"