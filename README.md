## Prerequisites

### Network Interface Card (NIC) Requirements

OptiReduce works best with Mellanox ConnectX NICs as they support DPDK flow bifurcation. This allows:
- Single NIC operation for both PyTorch/Gloo TCP-based communication and OptiReduce DPDK-based communication
- Efficient packet steering and processing
- Optimal performance with hardware offloading capabilities

If not using Mellanox ConnectX NICs, you will need:
1. One NIC for standard TCP-based PyTorch and Gloo communication
2. A separate DPDK-compatible NIC for OptiReduce

Note: DPDK v20.11 will be installed automatically as part of OptiReduce.

Note: While CUDA and cuDNN are supported for GPU training, they are not required for OptiReduce to work. OptiReduce can also be used with CPU-only training.

## Installation

There are two ways to install OptiReduce and its dependencies:

### Option 1: Using Ansible (Recommended)

For automated deployment across multiple nodes:

```bash
git clone https://github.com/OptiReduce/ansible.git
cd ansible
make optireduce-full
```

For detailed instructions on using the Ansible deployment, visit our [Ansible documentation](http://optireduce.github.io/ansible).

### Option 2: Manual Installation

1. Install prerequisites:
   - Mellanox OFED drivers (if using Mellanox NICs)
   - Anaconda
   - CUDA and cuDNN (optional, for GPU training)

2. Install OptiReduce components:
```bash
# Clone the optireduce setup repository
git clone https://github.com/OptiReduce/setup.git
cd setup

# Install all components
make install

# Or install specific components
make dpdk        # Install DPDK only
make optireduce  # Setup OptiReduce only
make hadamard    # Install Hadamard CUDA only
```

Use `make help` to see all available installation options.

## Directory Structure

```
setup/
├── Makefile          # Build and installation scripts
├── patches/          # Required patches for OptiReduce 
```

## Usage Guide

For detailed instructions on using OptiReduce in your distributed training setup, please refer to our [usage guide](http://optireduce.github.io/usage).

## Performance Evaluation

To evaluate OptiReduce's performance and compare different communication schemes in your environment, please refer to our [benchmarking guide](http://optireduce.github.io/benchmarks).

## Components

OptiReduce consists of several repositories:
- [setup](https://github.com/OptiReduce/setup) (this repo) - Main implementation
- [ansible](https://github.com/OptiReduce/ansible) - Automated deployment
- [benchmark](https://github.com/OptiReduce/benchmark) - Benchmarking suite

## Documentation

- [Getting Started](http://optireduce.github.io/getting-started)
- [Technical Details](http://optireduce.github.io/technical-details)
- [Performance Benchmarks](http://optireduce.github.io/benchmarks)
- [Usage Instructions](http://optireduce.github.io/usage)

## Support

For issues:
1. Check our [documentation](http://optireduce.github.io/)
2. Review existing issues
3. Open a new issue with a minimal example

## Reference
Please cite this paper when using OptiReduce:

```bibtex
@inproceedings{warraich2025optireduce,
    title={OptiReduce: Resilient and Tail-Optimal AllReduce for Distributed Deep Learning in the Cloud},
    author={Warraich, Ertza and Shabtai, Omer and Manaa, Khalid and Vargaftik, Shay and Piasetzky, Yonatan and Kadosh, Matty and Suresh, Lalith and Shahbaz, Muhammad},
    booktitle={22nd USENIX Symposium on Networked Systems Design and Implementation (NSDI 25)},
    year={2025},
    publisher={USENIX Association}
}
```

## License

This deployment code is part of the OptiReduce project. Please refer to the main project page for license information.