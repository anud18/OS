# Quick Reference for Student ID: 314551007

This file contains all the commands you need with your student ID already filled in.

## 1. Build the Program

```bash
cd /home/ubuntu/hw2
make
```

This will create: `sched_demo_314551007`

## 2. Deploy to QEMU

### Option A: Automated (Recommended)
```bash
./deploy.sh 314551007
```

### Option B: Manual
```bash
# Copy files to initramfs
cp sched_demo_314551007 /home/ubuntu/initramfs/
cp sched_demo /home/ubuntu/initramfs/
cp sched_test.sh /home/ubuntu/initramfs/

# Repack initramfs
cd /home/ubuntu/initramfs/
find . | cpio -o -H newc | gzip > ../initramfs.cpio.gz
cd /home/ubuntu
```

## 3. Boot QEMU

```bash
qemu-system-riscv64 -nographic -machine virt -m 1024 -smp 4 \
  -kernel /home/ubuntu/linux/arch/riscv/boot/Image \
  -initrd /home/ubuntu/initramfs.cpio.gz \
  -append "console=ttyS0 loglevel=3"
```

## 4. Inside QEMU - Run Tests

```bash
# Disable RT throttling (IMPORTANT!)
echo -1 > /proc/sys/kernel/sched_rt_runtime_us

# Make files executable
chmod +x sched_demo sched_test.sh sched_demo_314551007

# Run automated tests
./sched_test.sh ./sched_demo ./sched_demo_314551007
```

## 5. Manual Testing Examples

```bash
# Test 1: Single NORMAL thread
./sched_demo_314551007 -n 1 -t 0.5 -s NORMAL -p -1

# Test 2: Two FIFO threads
./sched_demo_314551007 -n 2 -t 0.5 -s FIFO,FIFO -p 10,20

# Test 3: Mixed policies
./sched_demo_314551007 -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30

# Test 4: Four threads example
./sched_demo_314551007 -n 4 -t 0.5 -s NORMAL,FIFO,NORMAL,FIFO -p -1,10,-1,30
```

## 6. Clean Build

```bash
make clean
```

## 7. Exit QEMU

Press: `Ctrl-A` then `X`

## Complete Workflow (Copy-Paste Ready)

```bash
# In Docker container on host
cd /home/ubuntu/hw2
make
./deploy.sh 314551007

# Boot QEMU
qemu-system-riscv64 -nographic -machine virt -m 1024 -smp 4 \
  -kernel /home/ubuntu/linux/arch/riscv/boot/Image \
  -initrd /home/ubuntu/initramfs.cpio.gz \
  -append "console=ttyS0 loglevel=3"

# Inside QEMU after boot
echo -1 > /proc/sys/kernel/sched_rt_runtime_us
chmod +x sched_demo sched_test.sh sched_demo_314551007
./sched_test.sh ./sched_demo ./sched_demo_314551007
```

## Expected Test Output

```
Running testcase 1: ./sched_demo -n 1 -t 0.5 -s NORMAL -p -1
Result: Success!
Running testcase 2: ./sched_demo -n 2 -t 0.5 -s FIFO,FIFO -p 10,20
Result: Success!
Running testcase 3: ./sched_demo -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30
Result: Success!
```

## Files to Submit

- `sched_demo.c` - Your source code
- `Makefile` - Build configuration
- `sched_demo_314551007` - Compiled RISC-V binary

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Operation not permitted" | Run: `echo -1 > /proc/sys/kernel/sched_rt_runtime_us` |
| "command not found: riscv64-linux-gnu-gcc" | Install: `sudo apt install gcc-riscv64-linux-gnu` |
| Wrong thread order | Check TESTING_GUIDE.md for debugging tips |

Good luck! 🚀
