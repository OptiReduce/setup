FROM nvidia/cuda:12.4.1-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN ulimit -s unlimited || true

# Copy patch file for later
COPY patches/gloo.patch /tmp/gloo.patch

# Install base system packages
RUN apt-get update -qq && apt-get install -yq \
    apt-utils \
    redis-server \
    libhiredis-dev \
    curl \
    wget \
    gnupg \
    lsb-release \
    build-essential \
    ninja-build \
    meson \
    libnuma-dev \
    pkg-config \
    libpcap-dev \
    git \
    screen \
    nano \
    net-tools \
    software-properties-common \
    linux-headers-$(uname -r)

# Setup Python 3.9 and pip
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt update && apt install -y python3.9 python3.9-dev python3.9-venv && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9 && \
    ln -sf /usr/local/bin/pip3 /usr/bin/pip && \
    ln -sf /usr/bin/python3 /usr/bin/python

# Install MLNX OFED
WORKDIR /tmp
RUN wget https://content.mellanox.com/ofed/MLNX_OFED-24.10-3.2.5.0/MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu20.04-x86_64.tgz && \
    tar -xzf MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu20.04-x86_64.tgz && \
    cd MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu20.04-x86_64 && \
    yes y | ./mlnxofedinstall || true

# Build and install DPDK
WORKDIR /usr/src
RUN git clone https://github.com/DPDK/dpdk.git && \
    cd dpdk && \
    git checkout v20.11 && \
    meson build --prefix=/usr/local -Dexamples=all -Ddrivers=net/mlx5 && \
    ninja -C build && ninja -C build install && \
    ldconfig && \
    echo 'export LD_LIBRARY_PATH=/usr/local/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH' >> ~/.bashrc

# Clone OptiReduce and patch Gloo
WORKDIR /usr/src
RUN git clone https://github.com/pytorch/pytorch.git && \
    cd pytorch && \
    git checkout 0acbf8039abccfc17f9c8529d217209db5a7cc85 && \
    git submodule sync && git submodule update --init --recursive && \
    cp /tmp/gloo.patch third_party/gloo/ && \
    cd third_party/gloo && git apply gloo.patch

# Install Python dependencies and PyTorch
WORKDIR /usr/src/pytorch
RUN pip install -r requirements.txt && \
    pip install cmake==3.25.0 && \
    pip install transformers==4.53.1 && \
    pip install pillow pandas tqdm && \ 
    pip install --no-deps torchvision && \ 
    echo 'export PYTHONPATH=/usr/lib/python3.9/site-packages:$PYTHONPATH' >> ~/.bashrc
#    CUDACXX=/usr/local/cuda/bin/nvcc BUILD_BINARY=0 BUILD_TEST=0 python3 setup.py install

# Build and install torchvision
#WORKDIR /usr/src
#RUN git clone https://github.com/pytorch/vision.git
#    cd vision && \
#    CUDACXX=/usr/local/cuda/bin/nvcc python3 setup.py install


# Build and install benchmark
WORKDIR /root
RUN git clone https://github.com/OptiReduce/benchmark.git && \
    git clone https://github.com/facebookincubator/gloo.git && \
    cd gloo && git checkout e6d509b527712a143996f2f59a10480efa804f8b && \
    mkdir build && cd build && \
    cmake .. -DUSE_REDIS=1 -DBUILD_BENCHMARK=1 -DCMAKE_CXX_STANDARD=17 && \
    make -j$(nproc)

# Defer installation of OptiReduce
RUN echo '#!/bin/bash\n\
if [ ! -d /usr/local/lib/python3.9/dist-packages/torch ]; then\n\
  echo "One-time OptiReduce & Torchvision install..."\n\
  cd /usr/src/pytorch && CUDACXX=/usr/local/cuda/bin/nvcc BUILD_BINARY=0 BUILD_TEST=0 python3 setup.py install\n\
  cd /usr/src/vision && CUDACXX=/usr/local/cuda/bin/nvcc python3 setup.py install\n\
  /usr/src/dpdk/usertools/dpdk-hugepages.py -p 2M --setup 16G\n\
fi\n\
exec "$@"' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
