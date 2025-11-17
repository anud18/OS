# HW2: Linux Thread Scheduling Demo

This assignment implements a program to demonstrate different scheduling policies on threads in Linux.

## Files

### Implementation Files
- `sched_demo.c` - Main implementation file
- `Makefile` - Build configuration for RISC-V cross-compilation
- `Makefile.local` - Local x86_64 build configuration for testing

### Documentation
- `README.md` - This file (overview and usage)
- `QUICK_START.md` - 5-minute quick start guide
- `IMPLEMENTATION_NOTES.md` - Technical details and design decisions
- `TESTING_GUIDE.md` - Comprehensive testing instructions

### Test Files (from GitHub)
- `sched_demo` - Reference RISC-V binary (652 KB)
- `sched_test.sh` - Automated test script

### Helper Scripts
- `deploy.sh` - Automated deployment script for QEMU
- `setup_env.sh` - Environment setup and verification script

## Prerequisites

In your Docker container, you should have:
- RISC-V cross-compiler: `riscv64-linux-gnu-gcc`
- QEMU for RISC-V: `qemu-system-riscv64`
- Linux kernel image: `/home/ubuntu/linux/arch/riscv/boot/Image`
- Root filesystem: `/home/ubuntu/initramfs/`

## Building the Program

1. Set your student ID and build:
```bash
cd /home/ubuntu/hw2
make STUDENT_ID=your_student_id
```

This will create an executable named `sched_demo_<your_student_id>`.

2. To clean build artifacts:
```bash
make clean
```

## Deployment to QEMU

1. Copy the compiled program to initramfs:
```bash
cp sched_demo_<your_student_id> /home/ubuntu/initramfs/
```

2. Copy the test script (if you have it) to initramfs:
```bash
cp sched_test.sh /home/ubuntu/initramfs/
cp sched_demo /home/ubuntu/initramfs/  # reference implementation
```

3. Repack the initramfs:
```bash
cd /home/ubuntu/initramfs/
find . | cpio -o -H newc | gzip > ../initramfs.cpio.gz
cd ..
```

4. Boot QEMU:
```bash
qemu-system-riscv64 -nographic -machine virt -m 1024 -smp 4 \
  -kernel linux/arch/riscv/boot/Image \
  -initrd initramfs.cpio.gz \
  -append "console=ttyS0 loglevel=3"
```

## Running the Program

**IMPORTANT**: Before running the program inside QEMU, disable RT throttling:
```bash
echo -1 > /proc/sys/kernel/sched_rt_runtime_us
```

### Usage

```bash
./sched_demo_<student_id> -n <num_threads> -t <time_wait> -s <policies> -p <priorities>
```

### Arguments

- `-n <num_threads>`: Number of threads to run simultaneously
- `-t <time_wait>`: Duration of "busy" period in seconds
- `-s <policies>`: Comma-separated scheduling policies (NORMAL or FIFO)
- `-p <priorities>`: Comma-separated priorities (-1 for NORMAL, 1-99 for FIFO)

### Example

```bash
./sched_demo_<student_id> -n 4 -t 0.5 -s NORMAL,FIFO,NORMAL,FIFO -p -1,10,-1,30
```

Expected output:
```
Thread 3 is running
Thread 3 is running
Thread 3 is running
Thread 1 is running
Thread 1 is running
Thread 1 is running
Thread 2 is running
Thread 0 is running
...
```

## Testing

The repository includes test files from the assignment:
- `sched_demo` - Reference RISC-V binary
- `sched_test.sh` - Automated test script

### Quick Test

Inside QEMU, run:

```bash
chmod +x sched_test.sh sched_demo sched_demo_<student_id>
./sched_test.sh ./sched_demo ./sched_demo_<student_id>
```

### Test Cases

1. Single NORMAL thread: `-n 1 -t 0.5 -s NORMAL -p -1`
2. Two FIFO threads: `-n 2 -t 0.5 -s FIFO,FIFO -p 10,20`
3. Mixed policies: `-n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30`

**For detailed testing instructions, see [TESTING_GUIDE.md](TESTING_GUIDE.md)**

## How It Works

1. **Main Thread**:
   - Parses command-line arguments
   - Sets CPU affinity to pin all threads to CPU 0
   - Creates worker threads with specified scheduling policies
   - Waits for all threads to complete

2. **Worker Threads**:
   - Synchronize startup using pthread_barrier
   - Run 3 iterations of busy-wait loop
   - Print status message at each iteration
   - Use CPU time (not wall time) for busy-waiting

3. **Scheduling**:
   - `SCHED_NORMAL` (SCHED_OTHER): Fair scheduling (CFS)
   - `SCHED_FIFO`: Real-time FIFO scheduling
   - Higher priority FIFO threads preempt lower priority ones
   - FIFO threads preempt NORMAL threads

## Implementation Details

- Uses `pthread_barrier_wait()` to synchronize thread startup
- Uses `clock_gettime(CLOCK_THREAD_CPUTIME_ID)` for accurate CPU time measurement
- Uses `pthread_attr_setinheritsched()` with `PTHREAD_EXPLICIT_SCHED` to set custom scheduling
- Uses `sched_setaffinity()` to pin all threads to the same CPU
- Implements true busy-waiting (CPU-bound loop) instead of sleep

## Troubleshooting

1. **Permission denied for RT scheduling**:
   - Make sure to run: `echo -1 > /proc/sys/kernel/sched_rt_runtime_us`

2. **Cross-compilation errors**:
   - Verify RISC-V toolchain: `riscv64-linux-gnu-gcc -v`
   - Make sure you're using `-static` flag for standalone execution

3. **Threads not behaving as expected**:
   - Ensure all threads are pinned to the same CPU
   - Check that RT throttling is disabled
   - Verify scheduling policies and priorities are set correctly
