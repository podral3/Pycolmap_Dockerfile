ARG UBUNTU_VERSION=24.04
ARG NVIDIA_CUDA_VERSION=12.6.0

#
# Docker builder stage - Build COLMAP and PyCOLMAP
#
FROM nvidia/cuda:${NVIDIA_CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder

ARG COLMAP_GIT_COMMIT=main
ARG CUDA_ARCHITECTURES=all-major
ARG PYTHON_VERSION=3.11

ENV QT_XCB_GL_INTEGRATION=xcb_egl
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies for COLMAP and Python
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
    software-properties-common \
    wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python from deadsnakes PPA for Ubuntu
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Python as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1

# Upgrade pip
RUN python3 -m pip install --upgrade pip setuptools wheel

# Build and install COLMAP
RUN git clone https://github.com/colmap/colmap.git /colmap_src
RUN cd /colmap_src && \
    git fetch https://github.com/colmap/colmap.git ${COLMAP_GIT_COMMIT} && \
    git checkout FETCH_HEAD && \
    mkdir build && \
    cd build && \
    cmake .. \
    -GNinja \
    -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
    -DCMAKE_INSTALL_PREFIX=/colmap-install \
    -DBLA_VENDOR=Intel10_64lp && \
    ninja install

# Install PyCOLMAP build dependencies
RUN python3 -m pip install --no-cache-dir \
    pybind11 \
    numpy

# Build and install PyCOLMAP from source
RUN cd /colmap_src && \
    python3 -m pip install --no-cache-dir .

#
# Docker runtime stage - Minimal image for running PyCOLMAP scripts
#
FROM nvidia/cuda:${NVIDIA_CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION} AS runtime

ARG PYTHON_VERSION=3.11

ENV DEBIAN_FRONTEND=noninteractive
ENV QT_XCB_GL_INTEGRATION=xcb_egl

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
    software-properties-common \
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
    libmkl-core && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python runtime
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Python as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1

# Copy COLMAP installation from builder
COPY --from=builder /colmap-install/ /usr/local/

# Copy Python site-packages with PyCOLMAP from builder
COPY --from=builder /usr/local/lib/python${PYTHON_VERSION}/dist-packages/ /usr/local/lib/python${PYTHON_VERSION}/dist-packages/

# Install common Python packages for working with PyCOLMAP
RUN python3 -m pip install --no-cache-dir \
    numpy \
    pillow \
    scipy \
    matplotlib \
    opencv-python-headless

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]