#!/bin/bash

set -e  # Exit on error

echo "🚀 Starting intelligent PyCOLMAP Docker setup..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "Visit: https://docs.docker.com/engine/install/"
    exit 1
fi

# Check Docker version
DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+' | head -1)
REQUIRED_VERSION=19.03
if (( $(echo "$DOCKER_VERSION < $REQUIRED_VERSION" | bc -l) )); then
    echo "❌ Docker version $DOCKER_VERSION is too old. Please upgrade to $REQUIRED_VERSION or higher."
    exit 1
fi
echo "✅ Docker version: $DOCKER_VERSION"

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA driver not found. Installing..."
    sudo apt update
    sudo ubuntu-drivers autoinstall
    echo "⚠️  System reboot required after driver installation."
    echo "After reboot, run this script again: ./setup-pycolmap.sh"
    exit 0
fi

# Check if reboot is needed
if [ -f /var/run/reboot-required ]; then
    echo "⚠️  System reboot required. Please reboot and run this script again."
    echo "After reboot, run: ./setup-pycolmap.sh"
    exit 0
fi

echo "🔍 Detecting NVIDIA driver version..."
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
echo "✅ Found NVIDIA driver: $DRIVER_VERSION"

# Function to determine compatible CUDA version
get_compatible_cuda_version() {
    local driver_ver=$1
    local major_ver=$(echo $driver_ver | cut -d'.' -f1)
    
    if [ $major_ver -ge 565 ]; then
        echo "12.9.0"
    elif [ $major_ver -ge 560 ]; then
        echo "12.6.0"
    elif [ $major_ver -ge 555 ]; then
        echo "12.5.0"
    elif [ $major_ver -ge 550 ]; then
        echo "12.4.0"
    elif [ $major_ver -ge 535 ]; then
        echo "12.2.0"
    elif [ $major_ver -ge 525 ]; then
        echo "12.0.0"
    else
        echo "11.8.0"
    fi
}

COMPATIBLE_CUDA=$(get_compatible_cuda_version $DRIVER_VERSION)
echo "✅ Compatible CUDA version: $COMPATIBLE_CUDA"

# Install nvidia-container-toolkit if not present
if ! command -v nvidia-ctk &> /dev/null; then
    echo "📦 Installing nvidia-container-toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    
    echo "📦 Configuring Docker..."
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    echo "✅ nvidia-container-toolkit installed and configured"
else
    echo "✅ nvidia-container-toolkit already installed"
fi

# Find available CUDA images
echo "🔍 Finding latest CUDA $COMPATIBLE_CUDA image..."
MAJOR_MINOR=$(echo $COMPATIBLE_CUDA | cut -d'.' -f1,2)

# Try Ubuntu 24.04 first
AVAILABLE_VERSIONS=$(curl -s "https://registry.hub.docker.com/v2/repositories/nvidia/cuda/tags/?page_size=100" | \
    jq -r '.results[].name' | \
    grep -E "^${MAJOR_MINOR}\.[0-9]+-devel-ubuntu24\.04$" | \
    head -1)

UBUNTU_VERSION="24.04"
if [ -z "$AVAILABLE_VERSIONS" ]; then
    echo "⚠️  No CUDA $MAJOR_MINOR images found for Ubuntu 24.04, trying Ubuntu 22.04..."
    AVAILABLE_VERSIONS=$(curl -s "https://registry.hub.docker.com/v2/repositories/nvidia/cuda/tags/?page_size=100" | \
        jq -r '.results[].name' | \
        grep -E "^${MAJOR_MINOR}\.[0-9]+-devel-ubuntu22\.04$" | \
        head -1)
    UBUNTU_VERSION="22.04"
fi

if [ -n "$AVAILABLE_VERSIONS" ]; then
    FULL_CUDA_VERSION=$(echo "$AVAILABLE_VERSIONS" | cut -d'-' -f1)
    echo "✅ Found CUDA version: $FULL_CUDA_VERSION for Ubuntu $UBUNTU_VERSION"
else
    echo "❌ No compatible CUDA images found"
    exit 1
fi

# Update Dockerfile with detected versions
if [ -f "Dockerfile" ]; then
    echo "📝 Updating Dockerfile with CUDA $FULL_CUDA_VERSION and Ubuntu $UBUNTU_VERSION..."
    sed -i "s/ARG NVIDIA_CUDA_VERSION=.*/ARG NVIDIA_CUDA_VERSION=${FULL_CUDA_VERSION}/" Dockerfile
    sed -i "s/ARG UBUNTU_VERSION=.*/ARG UBUNTU_VERSION=${UBUNTU_VERSION}/" Dockerfile
    echo "✅ Dockerfile updated"
else
    echo "❌ Dockerfile not found in current directory"
    exit 1
fi

# Test NVIDIA Docker runtime
echo "🧪 Testing NVIDIA Docker runtime..."
if docker run --rm --runtime=nvidia nvidia/cuda:${FULL_CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION} nvidia-smi; then
    echo "✅ GPU support working!"
else
    echo "❌ GPU test failed"
    exit 1
fi

echo ""
echo "✅ Setup complete! You can now build the PyCOLMAP Docker image."
echo ""
echo "Next steps:"
echo "  1. Build the image:    ./build-pycolmap.sh"
echo "  2. Run your scripts:   ./run-pycolmap.sh /path/to/your/workspace"
echo ""