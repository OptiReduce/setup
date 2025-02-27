# Versions
DPDK_VERSION = v20.11
PYTORCH_VERSION = 0acbf8039abccfc17f9c8529d217209db5a7cc85

# Installation directory
INSTALL_DIR = /usr/src

# Conda installation
CONDA_VERSION ?= 3-2023.09-0
CONDA_INSTALLER ?= Anaconda$(CONDA_VERSION)-Linux-x86_64.sh
CONDA_URL ?= https://repo.anaconda.com/archive/$(CONDA_INSTALLER)
DEFAULT_CONDA_DIR ?= /opt/anaconda3
CONDA_DIR := $(shell command -v conda >/dev/null 2>&1 && dirname $(shell dirname $$(command -v conda)) || echo $(DEFAULT_CONDA_DIR))

# DPDK build options
DPDK_FLAGS = -Dexamples=all

.PHONY: all install clean dpdk optireduce hadamard env

all: install

# Install everything
install: env dpdk optireduce hadamard

# Set up conda environment
env:
	@echo "Checking for Conda installation..."
	@if ! command -v conda >/dev/null 2>&1; then \
	    echo "Conda not found. Downloading and installing..."; \
	    wget -O /tmp/$(CONDA_INSTALLER) $(CONDA_URL); \
	    chmod +x /tmp/$(CONDA_INSTALLER); \
	    /tmp/$(CONDA_INSTALLER) -b -p $(DEFAULT_CONDA_DIR); \
	    rm /tmp/$(CONDA_INSTALLER); \
	    CONDA_DIR=$(DEFAULT_CONDA_DIR); \
	else \
	    echo "Conda found at $(CONDA_DIR)"; \
	fi

	@echo "Setting up Conda environment..."
	. $(CONDA_DIR)/bin/activate && \
	$(CONDA_DIR)/bin/conda init bash && \
	$(CONDA_DIR)/bin/conda create --name optireduce python=3.9.19 -y && \
	$(CONDA_DIR)/bin/conda install -y pandas pyyaml torchvision meson cmake ninja && \
	$(CONDA_DIR)/bin/conda install -c pytorch -y libpng libjpeg-turbo magma-cuda110
	@echo "Conda environment setup complete!"

# Clone and build DPDK
dpdk:
	@echo "Building DPDK..."
	cd $(INSTALL_DIR) && git clone https://github.com/DPDK/dpdk.git || (cd dpdk && git fetch)
	cd $(INSTALL_DIR)/dpdk && git checkout $(DPDK_VERSION)
	cd $(INSTALL_DIR)/dpdk && source $(CONDA_DIR)/bin/activate optireduce && \
		meson $(DPDK_FLAGS) build && \
		ninja -j$$(nproc) -C build && \
		ninja -j$$(nproc) -C build install
	cd $(INSTALL_DIR)/dpdk && ./usertools/dpdk-hugepages.py -p 1G --setup 32G
	@echo "DPDK installation complete"

# Clone and setup PyTorch with OptiReduce
optireduce:
	@echo "Setting up OptiReduce..."
	cd $(INSTALL_DIR) && git clone https://github.com/pytorch/pytorch.git || (cd pytorch && git fetch)
	cd $(INSTALL_DIR)/pytorch && git checkout $(PYTORCH_VERSION)
	cd $(INSTALL_DIR)/pytorch && git submodule sync && git submodule update --init --recursive
	cp patches/pytorch.patch $(INSTALL_DIR)/pytorch/
	cp patches/gloo_experimental.patch $(INSTALL_DIR)/pytorch/third_party/gloo/
	cd $(INSTALL_DIR)/pytorch/ && git apply pytorch.patch
	cd $(INSTALL_DIR)/pytorch/third_party/gloo/ && git apply gloo_experimental.patch
	cd $(INSTALL_DIR)/pytorch && source $(CONDA_DIR)/bin/activate optireduce && \
		pip install -r requirements.txt && \
		CUDACXX=/usr/local/cuda/bin/nvcc BUILD_BINARY=0 BUILD_TEST=0 python setup.py install
	@echo "OptiReduce setup complete"

# Clone and build Hadamard CUDA
hadamard:
	@echo "Building Hadamard CUDA..."
	cd $(INSTALL_DIR) && git clone https://github.com/HazyResearch/structured-nets.git || (cd structured-nets && git fetch)
	cd $(INSTALL_DIR)/structured-nets/pytorch/structure/hadamard_cuda && \
		source $(CONDA_DIR)/bin/activate optireduce && \
		CUDACXX=/usr/local/cuda/bin/nvcc BUILD_BINARY=0 BUILD_TEST=0 python setup.py install
	@echo "Hadamard CUDA installation complete"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(INSTALL_DIR)/dpdk/build
	@echo "Clean complete"

# Clean everything including repositories
distclean: clean
	@echo "Removing all installed components..."
	rm -rf $(INSTALL_DIR)/dpdk
	rm -rf $(INSTALL_DIR)/pytorch
	rm -rf $(INSTALL_DIR)/structured-nets
	@echo "Full cleanup complete"

# Status check
status:
	@echo "Checking installations..."
	@echo "\nChecking DPDK..."
	@if [ -d "$(INSTALL_DIR)/dpdk/build" ]; then \
		echo "DPDK appears to be built"; \
	else \
		echo "DPDK build not found"; \
	fi
	@echo "\nChecking OptiReduce..."
	@if [ -d "$(INSTALL_DIR)/pytorch" ]; then \
		echo "OptiReduce appears to be set up"; \
	else \
		echo "OptiReduce not found"; \
	fi
	@echo "\nChecking Hadamard CUDA..."
	@if [ -d "$(INSTALL_DIR)/structured-nets" ]; then \
		echo "Hadamard CUDA appears to be installed"; \
	else \
		echo "Hadamard CUDA not found"; \
	fi

# Help
help:
	@echo "Available targets:"
	@echo "  make install   - Install all components"
	@echo "  make env       - Set up conda environment"
	@echo "  make dpdk      - Install DPDK only"
	@echo "  make optireduce   - Set up OptiReduce only"
	@echo "  make hadamard  - Install Hadamard CUDA only"
	@echo "  make clean     - Remove build artifacts"
	@echo "  make distclean - Remove all components"
	@echo "  make status    - Check installation status"
	@echo "  make help      - Show this help message"