ARG UBUNTU_VERSION=20.04
ARG NVIDIA_CUDA_VERSION=11.2.2

# Builder stage
FROM nvidia/cuda:${NVIDIA_CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS builder
ARG COLMAP_GIT_COMMIT=3.10
ARG CUDA_ARCHITECTURES=all-major
ENV QT_XCB_GL_INTEGRATION=xcb_egl
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies including Python
RUN apt-get update && \
    apt-get install -y \
        git \
        ninja-build \
        build-essential \
        wget \
        unzip \
        libboost-program-options-dev \
        libboost-filesystem-dev \
        libboost-graph-dev \
        libboost-system-dev \
        libeigen3-dev \
        libfreeimage-dev \
        libmetis-dev \
        libflann-dev \
        libgoogle-glog-dev \
        libgtest-dev \
        libgmock-dev \
        libsqlite3-dev \
        libglew-dev \
        qtbase5-dev \
        libqt5opengl5-dev \
        libcgal-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libatlas-base-dev \
        libsuitesparse-dev \
        python3 \
        python3-pip \
        python3-dev \
        python3-venv \
        ca-certificates && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install newer CMake (3.16 doesn't support CUDA17 dialect)
RUN wget -O cmake.sh https://github.com/Kitware/CMake/releases/download/v3.24.0/cmake-3.24.0-linux-x86_64.sh && \
    chmod +x cmake.sh && \
    ./cmake.sh --skip-license --prefix=/usr/local && \
    rm cmake.sh

# Configure git for better SSL handling
RUN git config --global http.sslVerify true && \
    git config --global http.postBuffer 524288000

# Build and install Ceres Solver (compatible with COLMAP 3.10)
RUN git clone https://github.com/ceres-solver/ceres-solver.git && \
    cd ceres-solver && \
    git checkout 2.2.0 && \
    mkdir build && \
    cd build && \
    cmake .. \
        -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_TESTING=OFF \
        -DBUILD_EXAMPLES=OFF && \
    ninja install && \
    # Replace FindGlog.cmake with a version that checks for existing target \
    echo 'if(NOT TARGET glog::glog)' > /tmp/patch.cmake && \
    cat /usr/local/lib/cmake/Ceres/FindGlog.cmake >> /tmp/patch.cmake && \
    echo 'endif()' >> /tmp/patch.cmake && \
    mv /tmp/patch.cmake /usr/local/lib/cmake/Ceres/FindGlog.cmake && \
    cd ../.. && \
    rm -rf ceres-solver

# Pre-download PoseLib to avoid SSL issues during CMake fetch
RUN wget https://github.com/PoseLib/PoseLib/archive/f119951fca625133112acde48daffa5f20eba451.zip -O /tmp/poselib.zip && \
    mkdir -p /tmp/poselib && \
    cd /tmp/poselib && \
    unzip /tmp/poselib.zip

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
        -DFETCHCONTENT_QUIET=OFF \
        -DFETCHCONTENT_SOURCE_DIR_POSELIB=/tmp/poselib/PoseLib-f119951fca625133112acde48daffa5f20eba451 && \
    ninja install -j4

# Build PyColmap (from the same COLMAP source directory)
# Using a virtual environment to isolate Python packages
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN cd colmap && \
    pip install --upgrade pip && \
    pip install scikit-build-core pybind11 numpy && \
    CMAKE_PREFIX_PATH=/colmap-install pip install --verbose ./pycolmap

# Runtime stage
FROM nvidia/cuda:${NVIDIA_CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION} AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies including Python
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        libboost-program-options1.71.0 \
        libboost-filesystem1.71.0 \
        libc6 \
        libomp5 \
        libopengl0 \
        libmetis5 \
        libfreeimage3 \
        libflann1.9 \
        libgcc-s1 \
        libgl1 \
        libglew2.1 \
        libgoogle-glog0v5 \
        libqt5core5a \
        libqt5gui5 \
        libqt5widgets5 \
        libqt5opengl5 \
        libcurl4 \
        libssl1.1 \
        libatlas3-base \
        libsuitesparseconfig5 \
        libcholmod3 \
        libcxsparse3 \
        libspqr2 \
        python3 \
        python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy Ceres installation from builder
COPY --from=builder /usr/local/lib/libceres* /usr/local/lib/
COPY --from=builder /usr/local/include/ceres /usr/local/include/ceres
RUN ldconfig

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
RUN colmap -h && \
    python3 -c "import pycolmap; print(f'PyColmap version: {pycolmap.__version__}')"