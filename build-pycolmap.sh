#!/bin/bash

set -e

echo "🔨 Building PyCOLMAP Docker image..."

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found in current directory"
    exit 1
fi

# Extract versions from Dockerfile
CUDA_VERSION=$(grep "ARG NVIDIA_CUDA_VERSION=" Dockerfile | cut -d'=' -f2)
UBUNTU_VERSION=$(grep "ARG UBUNTU_VERSION=" Dockerfile | cut -d'=' -f2)

echo "📦 Building with:"
echo "   CUDA: $CUDA_VERSION"
echo "   Ubuntu: $UBUNTU_VERSION"
echo ""

# Build the image
docker build \
    --build-arg CUDA_ARCHITECTURES=all-major \
    --build-arg COLMAP_GIT_COMMIT=main \
    --build-arg PYTHON_VERSION=3.11 \
    -t pycolmap:latest \
    -t pycolmap:cuda${CUDA_VERSION} \
    .

echo ""
echo "✅ Build complete!"
echo ""
echo "Image tags created:"
echo "  - pycolmap:latest"
echo "  - pycolmap:cuda${CUDA_VERSION}"
echo ""
echo "Next step: Run your scripts with ./run-pycolmap.sh /path/to/workspace"
echo ""