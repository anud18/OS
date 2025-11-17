#!/bin/bash

# Environment setup script for HW2
# This script helps set up the RISC-V Linux environment

set -e

echo "======================================"
echo "HW2 Environment Setup Script"
echo "======================================"

# Default directories (adjust as needed)
BASE_DIR="${BASE_DIR:-/home/ubuntu}"
LINUX_DIR="${LINUX_DIR:-${BASE_DIR}/linux}"
INITRAMFS_DIR="${INITRAMFS_DIR:-${BASE_DIR}/initramfs}"

echo "Base directory: ${BASE_DIR}"
echo "Linux source: ${LINUX_DIR}"
echo "Initramfs: ${INITRAMFS_DIR}"
echo ""

# Check if running in correct environment
if [ ! -d "${BASE_DIR}" ]; then
    echo "Warning: ${BASE_DIR} does not exist"
    echo "Are you running inside the Docker container?"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check RISC-V toolchain
echo "Checking RISC-V toolchain..."
if command -v riscv64-linux-gnu-gcc &> /dev/null; then
    echo "✓ RISC-V GCC found:"
    riscv64-linux-gnu-gcc --version | head -1
else
    echo "✗ RISC-V GCC not found"
    echo "Installing RISC-V toolchain..."
    sudo apt update
    sudo apt install -y gcc-riscv64-linux-gnu
fi

# Check QEMU
echo ""
echo "Checking QEMU for RISC-V..."
if command -v qemu-system-riscv64 &> /dev/null; then
    echo "✓ QEMU RISC-V found:"
    qemu-system-riscv64 --version | head -1
else
    echo "✗ QEMU RISC-V not found"
    echo "Installing QEMU..."
    sudo apt update
    sudo apt install -y qemu-system-misc
fi

# Check/Clone Linux kernel
echo ""
echo "Checking Linux kernel source..."
if [ -d "${LINUX_DIR}" ]; then
    echo "✓ Linux source found at ${LINUX_DIR}"
    if [ -f "${LINUX_DIR}/arch/riscv/boot/Image" ]; then
        echo "✓ Kernel image found"
    else
        echo "✗ Kernel image not found"
        echo "You may need to build the kernel"
    fi
else
    echo "✗ Linux source not found"
    read -p "Clone Linux kernel v6.1? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Cloning Linux kernel v6.1..."
        git clone https://github.com/torvalds/linux --branch v6.1 --depth 1 "${LINUX_DIR}"
        echo "✓ Linux kernel cloned"
        echo "Note: You still need to build the kernel for RISC-V"
    fi
fi

# Check/Create initramfs
echo ""
echo "Checking initramfs..."
if [ -d "${INITRAMFS_DIR}" ]; then
    echo "✓ Initramfs directory found at ${INITRAMFS_DIR}"
else
    echo "✗ Initramfs directory not found"
    read -p "Create initramfs directory structure? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Creating initramfs structure..."
        mkdir -p "${INITRAMFS_DIR}"/{bin,sbin,etc,proc,sys,usr/{bin,sbin},dev}
        echo "✓ Initramfs directory structure created"
        echo "Note: You need to populate it with busybox and other tools"
    fi
fi

echo ""
echo "======================================"
echo "Environment check complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Build your program: cd hw2 && make STUDENT_ID=<your_id>"
echo "2. Deploy to QEMU: ./deploy.sh <your_id>"
echo "3. Boot QEMU and test"
echo ""
