# Quick Start Guide

## For Students: Getting Started in 5 Minutes

### Step 1: Set Your Student ID

Edit the `Makefile` or use the command-line option:

```bash
# Option 1: Edit Makefile
nano Makefile
# Change: STUDENT_ID ?= student_id
# To:     STUDENT_ID ?= your_actual_id

# Option 2: Use command-line
make STUDENT_ID=your_actual_id
```

### Step 2: Build the Program

**In Docker container with RISC-V toolchain:**

```bash
cd /home/ubuntu/hw2
make STUDENT_ID=your_id
```

You should see: `sched_demo_your_id` created.

### Step 3: Deploy to QEMU

```bash
# Automated deployment
./deploy.sh your_id

# Or manual deployment:
cp sched_demo_your_id /home/ubuntu/initramfs/
cd /home/ubuntu/initramfs/
find . | cpio -o -H newc | gzip > ../initramfs.cpio.gz
```

### Step 4: Boot QEMU

```bash
cd /home/ubuntu
qemu-system-riscv64 -nographic -machine virt -m 1024 -smp 4 \
  -kernel linux/arch/riscv/boot/Image \
  -initrd initramfs.cpio.gz \
  -append "console=ttyS0 loglevel=3"
```

### Step 5: Run Inside QEMU

```bash
# IMPORTANT: Disable RT throttling first!
echo -1 > /proc/sys/kernel/sched_rt_runtime_us

# Test with example command
./sched_demo_your_id -n 4 -t 0.5 -s NORMAL,FIFO,NORMAL,FIFO -p -1,10,-1,30
```

### Step 6: Run Tests (if you have test files)

```bash
chmod +x sched_test.sh sched_demo sched_demo_your_id
./sched_test.sh ./sched_demo ./sched_demo_your_id
```

## Common Commands

```bash
# Build
make STUDENT_ID=B12345678

# Clean
make clean

# Local testing (x86_64, before cross-compile)
make -f Makefile.local STUDENT_ID=test
sudo ./sched_demo_test_local -n 2 -t 0.5 -s FIFO,FIFO -p 10,20

# View processes with RT priority in QEMU
ps -eo state,uid,pid,ppid,rtprio,time,comm

# Exit QEMU
# Press: Ctrl-A, then X
```

## Understanding the Output

Example command:
```bash
./sched_demo_B12345678 -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30
```

Expected output:
```
Thread 2 is running    # Priority 30 (highest FIFO)
Thread 2 is running
Thread 2 is running
Thread 1 is running    # Priority 10 (lower FIFO)
Thread 1 is running
Thread 1 is running
Thread 0 is running    # SCHED_NORMAL (runs last)
Thread 0 is running
Thread 0 is running
```

**Why this order?**
1. Thread 2 has highest priority (FIFO priority 30)
2. Thread 1 has medium priority (FIFO priority 10)
3. Thread 0 uses SCHED_NORMAL (preempted by FIFO threads)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Operation not permitted" | Run with sudo or disable RT throttling |
| "riscv64-linux-gnu-gcc: not found" | Install toolchain: `sudo apt install gcc-riscv64-linux-gnu` |
| Unexpected thread order | Did you run `echo -1 > /proc/sys/kernel/sched_rt_runtime_us`? |
| Threads don't run | Check that you're using the correct number of CPUs (min 1) |

## File Checklist

Before submission, ensure you have:
- [ ] `sched_demo.c` - Your implementation
- [ ] `Makefile` - Build configuration
- [ ] `sched_demo_<your_id>` - Compiled RISC-V binary
- [ ] Test results showing all tests pass

## Expected Time

- Build time: < 10 seconds
- Deployment time: < 30 seconds
- Boot QEMU: < 1 minute
- Run tests: < 1 minute per test

**Total**: ~5 minutes from build to results!

## Need Help?

1. Check `README.md` for detailed instructions
2. Check `IMPLEMENTATION_NOTES.md` for technical details
3. Review the assignment requirements
4. Check error messages carefully

Good luck! 🚀
