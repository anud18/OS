#!/bin/bash

# Deployment script for sched_demo to QEMU RISC-V environment
# This script automates the process of deploying the compiled program to initramfs

set -e  # Exit on error

# Configuration
STUDENT_ID="${1:-student_id}"
INITRAMFS_DIR="${INITRAMFS_DIR:-/home/ubuntu/initramfs}"
LINUX_DIR="${LINUX_DIR:-/home/ubuntu/linux}"
PROGRAM_NAME="sched_demo_${STUDENT_ID}"

echo "======================================"
echo "RISC-V Deployment Script"
echo "======================================"
echo "Student ID: ${STUDENT_ID}"
echo "Program: ${PROGRAM_NAME}"
echo "Initramfs: ${INITRAMFS_DIR}"
echo "======================================"

# Check if program exists
if [ ! -f "${PROGRAM_NAME}" ]; then
    echo "Error: ${PROGRAM_NAME} not found!"
    echo "Please build it first with: make STUDENT_ID=${STUDENT_ID}"
    exit 1
fi

# Check if initramfs directory exists
if [ ! -d "${INITRAMFS_DIR}" ]; then
    echo "Error: Initramfs directory not found at ${INITRAMFS_DIR}"
    echo "Please set INITRAMFS_DIR environment variable or create the directory"
    exit 1
fi

# Copy program to initramfs
echo "Copying ${PROGRAM_NAME} to ${INITRAMFS_DIR}..."
cp "${PROGRAM_NAME}" "${INITRAMFS_DIR}/"
chmod +x "${INITRAMFS_DIR}/${PROGRAM_NAME}"

# Copy test files if they exist
if [ -f "sched_test.sh" ]; then
    echo "Copying sched_test.sh..."
    cp sched_test.sh "${INITRAMFS_DIR}/"
    chmod +x "${INITRAMFS_DIR}/sched_test.sh"
fi

if [ -f "sched_demo" ]; then
    echo "Copying reference sched_demo..."
    cp sched_demo "${INITRAMFS_DIR}/"
    chmod +x "${INITRAMFS_DIR}/sched_demo"
fi

# Repack initramfs
echo "Repacking initramfs..."
cd "${INITRAMFS_DIR}"
find . | cpio -o -H newc 2>/dev/null | gzip > ../initramfs.cpio.gz
cd - > /dev/null

echo "======================================"
echo "Deployment complete!"
echo "======================================"
echo ""
echo "To boot QEMU, run:"
echo ""
echo "qemu-system-riscv64 -nographic -machine virt -m 1024 -smp 4 \\"
echo "  -kernel ${LINUX_DIR}/arch/riscv/boot/Image \\"
echo "  -initrd ${INITRAMFS_DIR}/../initramfs.cpio.gz \\"
echo "  -append \"console=ttyS0 loglevel=3\""
echo ""
echo "After booting, remember to disable RT throttling:"
echo "  echo -1 > /proc/sys/kernel/sched_rt_runtime_us"
echo ""
echo "Then run your program:"
echo "  ./${PROGRAM_NAME} -n 4 -t 0.5 -s NORMAL,FIFO,NORMAL,FIFO -p -1,10,-1,30"
echo ""
