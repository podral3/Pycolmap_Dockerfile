ARG UBUNTU_VERSION=20.04
ARG NVIDIA_CUDA_VERSION=11.2.2

# Builder stage
FROM nvidia/cuda:${NVIDIA_CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder
ARG COLMAP_GIT_COMMIT=main
ARG CUDA_ARCHITECTURES=all-major
ENV QT_XCB_GL_INTEGRATION=xcb_egl
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies including Python
RUN apt-get update && \
    apt-get install -y \
        git \
        cmake \
        ninja-build \
        build-essential \
        libboost-program-options-dev \
        libboost-graph-dev \
        libboost-system-dev \
        libeigen3-dev \
        libfreeimage-dev \
        libmetis-dev \
        libgoogle-glog-dev \
        libgtest-dev \
        libgmock-dev \
        libsqlite3-dev \
        libglew-dev \
        qt6-base-dev \
        libqt6opengl6-dev \
        libqt6openglwidgets6 \
        libcgal-dev \
        libceres-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libmkl-full-dev \
        python3 \
        python3-pip \
        python3-dev \
        python3-venv \
        ca-certificates && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure git for better SSL handling
RUN git config --global http.sslVerify true && \
    git config --global http.postBuffer 524288000

# Clone COLMAP
RUN git clone https://github.com/colmap/colmap.git

# Build and install COLMAP
RUN cd colmap && \
    git fetch https://github.com/colmap/colmap.git ${COLMAP_GIT_COMMIT} && \
    git checkout FETCH_HEAD && \
    mkdir build && \
    cd build && \
    cmake .. \
        -GNinja \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
        -DCMAKE_INSTALL_PREFIX=/colmap-install \
        -DBLA_VENDOR=Intel10_64lp \
        -DFETCHCONTENT_QUIET=OFF && \
    ninja install -j4

# Build PyColmap (from the same COLMAP source directory)
# Using a virtual environment to isolate Python packages
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN cd colmap && \
    pip install --upgrade pip && \
    git config --global http.sslVerify true && \
    CMAKE_PREFIX_PATH=/colmap-install pip install . --verbose

# Runtime stage
FROM nvidia/cuda:${NVIDIA_CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION} AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies including Python
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        libboost-program-options1.83.0 \
        libc6 \
        libomp5 \
        libopengl0 \
        libmetis5 \
        libceres4t64 \
        libfreeimage3 \
        libgcc-s1 \
        libgl1 \
        libglew2.2 \
        libgoogle-glog0v6t64 \
        libqt6core6 \
        libqt6gui6 \
        libqt6widgets6 \
        libqt6openglwidgets6 \
        libcurl4 \
        libssl3t64 \
        libmkl-locale \
        libmkl-intel-lp64 \
        libmkl-intel-thread \
        libmkl-core \
        python3 \
        python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy COLMAP installation
COPY --from=builder /colmap-install/ /usr/local/

# Copy Python virtual environment with PyColmap
COPY --from=builder /opt/venv /opt/venv

# Activate virtual environment by default
ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"

# Set working directory
WORKDIR /workspace

# Verify installations
RUN colmap -h > /dev/null 2>&1 && echo "COLMAP installed successfully" && \
    python3 -c "import pycolmap; print(f'PyColmap version: {pycolmap.__version__}')"
