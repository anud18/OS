# Testing Guide for HW2

## Overview

This guide explains how to test your `sched_demo` implementation using the provided reference binary and test script.

## Test Files

- **`sched_demo`**: Reference RISC-V binary (652 KB, statically linked)
- **`sched_test.sh`**: Automated test script that compares your implementation with the reference

## Architecture Note

The reference `sched_demo` binary is compiled for RISC-V 64-bit:
```
$ file sched_demo
sched_demo: ELF 64-bit LSB executable, UCB RISC-V, RVC, double-float ABI, version 1 (SYSV), statically linked
```

**This means testing must be done inside the QEMU RISC-V environment, NOT on your host machine.**

## Test Cases

The test script runs 3 test cases:

### Test Case 1: Single NORMAL Thread
```bash
./sched_demo -n 1 -t 0.5 -s NORMAL -p -1
```
**Expected**: Thread 0 runs 3 times

### Test Case 2: Two FIFO Threads
```bash
./sched_demo -n 2 -t 0.5 -s FIFO,FIFO -p 10,20
```
**Expected**: Thread 1 (priority 20) runs first, then Thread 0 (priority 10)

### Test Case 3: Mixed Policies
```bash
./sched_demo -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30
```
**Expected**:
- Thread 2 (FIFO priority 30) runs first
- Thread 1 (FIFO priority 10) runs second
- Thread 0 (NORMAL) runs last

## Step-by-Step Testing in QEMU

### 1. Build Your Implementation

In your Docker container on the **host machine**:

```bash
cd /home/ubuntu/hw2
make STUDENT_ID=<your_student_id>
```

This creates: `sched_demo_<your_student_id>`

### 2. Deploy to QEMU

```bash
# Copy all test files to initramfs
cp sched_demo /home/ubuntu/initramfs/
cp sched_test.sh /home/ubuntu/initramfs/
cp sched_demo_<your_student_id> /home/ubuntu/initramfs/

# Repack initramfs
cd /home/ubuntu/initramfs/
find . | cpio -o -H newc | gzip > ../initramfs.cpio.gz
cd ..
```

Or use the automated deployment script:
```bash
./deploy.sh <your_student_id>
# Then manually copy the reference files
cp sched_demo /home/ubuntu/initramfs/
cp sched_test.sh /home/ubuntu/initramfs/
cd /home/ubuntu/initramfs/
find . | cpio -o -H newc | gzip > ../initramfs.cpio.gz
```

### 3. Boot QEMU

```bash
qemu-system-riscv64 -nographic -machine virt -m 1024 -smp 4 \
  -kernel /home/ubuntu/linux/arch/riscv/boot/Image \
  -initrd /home/ubuntu/initramfs.cpio.gz \
  -append "console=ttyS0 loglevel=3"
```

### 4. Run Tests Inside QEMU

Once booted into QEMU:

```bash
# Give execute permissions
chmod +x sched_demo sched_test.sh sched_demo_<your_student_id>

# Run the automated test
./sched_test.sh ./sched_demo ./sched_demo_<your_student_id>
```

## Understanding Test Results

### Success Output

```
Running testcase 1: ./sched_demo -n 1 -t 0.5 -s NORMAL -p -1
Result: Success!
Running testcase 2: ./sched_demo -n 2 -t 0.5 -s FIFO,FIFO -p 10,20
Result: Success!
Running testcase 3: ./sched_demo -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30
Result: Success!
```

### Failure Output

If a test fails, you'll see a diff:

```
Running testcase 2: ./sched_demo -n 2 -t 0.5 -s FIFO,FIFO -p 10,20
===== diff (demo vs test) =====
--- /tmp/tmp.abc123    2025-11-17 12:34:56.000000000 +0000
+++ /tmp/tmp.xyz789    2025-11-17 12:34:56.000000000 +0000
@@ -1,6 +1,6 @@
+Thread 1 is running
+Thread 1 is running
+Thread 1 is running
-Thread 0 is running
-Thread 0 is running
-Thread 0 is running
Result: Failed...
```

This means:
- **Left side (---)**: Reference output (expected)
- **Right side (+++)**: Your output (actual)
- The diff shows your thread ordering is incorrect

## Manual Testing

You can also test individual commands manually:

```bash
# Test 1
./sched_demo -n 1 -t 0.5 -s NORMAL -p -1
./sched_demo_<your_id> -n 1 -t 0.5 -s NORMAL -p -1

# Test 2
./sched_demo -n 2 -t 0.5 -s FIFO,FIFO -p 10,20
./sched_demo_<your_id> -n 2 -t 0.5 -s FIFO,FIFO -p 10,20

# Test 3
./sched_demo -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30
./sched_demo_<your_id> -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30
```

Compare the outputs visually.

## Important Notes

### RT Throttling

The test script automatically handles RT throttling by:
1. Saving the original value
2. Setting it to -1 (disabled)
3. Running tests
4. Restoring the original value

If you run tests manually, remember:
```bash
echo -1 > /proc/sys/kernel/sched_rt_runtime_us
```

### Timing Considerations

- Tests may take several seconds to run due to busy-waiting
- Test 1: ~1.5 seconds (1 thread × 0.5s × 3 iterations)
- Test 2: ~3 seconds (2 threads × 0.5s × 3 iterations)
- Test 3: ~9 seconds (3 threads × 1.0s × 3 iterations)

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Permission denied" | Files not executable | `chmod +x sched_demo sched_test.sh sched_demo_*` |
| "Operation not permitted" | RT throttling enabled | Script handles this, but check manually if needed |
| Wrong thread order | Implementation bug | Check barrier synchronization, thread attributes |
| Inconsistent results | Timing issue | Ensure using CLOCK_THREAD_CPUTIME_ID |

## Debugging Failed Tests

If your tests fail:

1. **Check thread synchronization**
   - Are all threads starting at the same time?
   - Is pthread_barrier_wait() being used correctly?

2. **Check scheduling attributes**
   - Is PTHREAD_EXPLICIT_SCHED set?
   - Are policies set correctly (SCHED_OTHER vs SCHED_FIFO)?
   - Are priorities set for FIFO threads?

3. **Check CPU affinity**
   - Are all threads pinned to the same CPU?

4. **Check busy-wait implementation**
   - Using CLOCK_THREAD_CPUTIME_ID (not wall clock)?
   - Not using sleep()?

5. **Run with verbose output**
   - Add debug prints to see thread creation order
   - Print scheduling policy and priority in each thread

## Adding Custom Tests

You can add your own test cases by editing `sched_test.sh`:

```bash
for CASE in \
"-n 1 -t 0.5 -s NORMAL -p -1" \
"-n 2 -t 0.5 -s FIFO,FIFO -p 10,20" \
"-n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30" \
"-n 4 -t 0.5 -s NORMAL,FIFO,NORMAL,FIFO -p -1,10,-1,30"  # Your custom test
do
  # ...
done
```

## Exit QEMU

To exit QEMU after testing:
```
Press: Ctrl-A, then X
```

## Summary Checklist

Before submission, verify:
- [ ] All 3 test cases pass
- [ ] Output matches reference binary exactly
- [ ] No compilation warnings
- [ ] Code is well-commented
- [ ] Makefile works with STUDENT_ID parameter
- [ ] Binary is statically linked for RISC-V

Good luck with your testing! 🧪
