# Implementation Notes for HW2: Thread Scheduling Demo

## Overview

This document describes the implementation details and design decisions for the thread scheduling demonstration program.

## Key Implementation Details

### 1. Thread Synchronization

**Problem**: Starting threads one-by-one causes them to begin execution at different times, leading to unpredictable scheduling behavior.

**Solution**: Use `pthread_barrier_wait()` to synchronize all threads at startup.

```c
pthread_barrier_t barrier;
pthread_barrier_init(&barrier, NULL, num_threads);

// In each thread:
pthread_barrier_wait(&barrier);  // All threads wait here
// Now all threads start together
```

### 2. Busy Waiting Implementation

**Problem**: Cannot use `sleep()` or `nanosleep()` as they make threads enter sleeping state, which doesn't demonstrate scheduling behavior properly.

**Solution**: Implement true busy-waiting using CPU time measurement.

```c
void busy_wait(double seconds) {
    struct timespec start, current;
    double elapsed;

    // Use CLOCK_THREAD_CPUTIME_ID to measure only CPU time
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &start);

    do {
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &current);
        elapsed = (current.tv_sec - start.tv_sec) +
                  (current.tv_nsec - start.tv_nsec) / 1e9;
    } while (elapsed < seconds);
}
```

**Why CLOCK_THREAD_CPUTIME_ID?**
- Measures actual CPU time consumed by the thread
- Excludes time when thread is preempted or blocked
- Ensures accurate timing regardless of scheduling

### 3. Thread Attribute Configuration

**Setting Scheduling Policy and Priority**:

```c
pthread_attr_t attr;
pthread_attr_init(&attr);

// CRITICAL: Set explicit scheduling inheritance
pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);

// Set scheduling policy
pthread_attr_setschedpolicy(&attr, SCHED_FIFO);  // or SCHED_OTHER

// Set priority for real-time threads
struct sched_param param;
param.sched_priority = 10;  // 1-99 for FIFO
pthread_attr_setschedparam(&attr, &param);
```

**Important**: `PTHREAD_EXPLICIT_SCHED` is essential! Without it, threads inherit the scheduling policy from the creating thread instead of using the specified policy.

### 4. CPU Affinity

**Why set CPU affinity?**
- Ensures all threads run on the same CPU
- Makes scheduling behavior more predictable
- Demonstrates scheduling policy effects more clearly

```c
cpu_set_t cpuset;
CPU_ZERO(&cpuset);
CPU_SET(0, &cpuset);  // Pin to CPU 0
sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
```

All child threads inherit this affinity.

### 5. RT Throttling

**Problem**: Linux has real-time throttling to prevent RT threads from starving the system.

**Solution**: Disable RT throttling before running:
```bash
echo -1 > /proc/sys/kernel/sched_rt_runtime_us
```

Default value allows RT threads to use only 95% of CPU time (950000 μs per second).

## Scheduling Behavior Explained

### SCHED_NORMAL (CFS - Completely Fair Scheduler)

- Time-sharing policy
- No static priority (uses nice values)
- All SCHED_NORMAL threads share CPU fairly
- Can be preempted by SCHED_FIFO threads

### SCHED_FIFO (Real-Time FIFO)

- Real-time policy without time slicing
- Priority range: 1-99 (higher number = higher priority)
- Runs until:
  1. Blocked (I/O, mutex, etc.)
  2. Preempted by higher priority RT thread
  3. Voluntarily yields (sched_yield)
- Always preempts SCHED_NORMAL threads

### Expected Behavior

Example: `-n 4 -t 0.5 -s NORMAL,FIFO,NORMAL,FIFO -p -1,10,-1,30`

```
Thread 0: SCHED_NORMAL, priority N/A
Thread 1: SCHED_FIFO, priority 10
Thread 2: SCHED_NORMAL, priority N/A
Thread 3: SCHED_FIFO, priority 30 (highest)
```

**Execution order**:
1. Thread 3 runs first (highest priority FIFO)
2. Thread 1 runs next (lower priority FIFO)
3. Threads 0 and 2 share remaining time (NORMAL)

## Common Pitfalls and Solutions

### Pitfall 1: Incorrect Busy Wait

❌ **Wrong**:
```c
sleep(time_wait);  // Thread goes to sleep, doesn't show scheduling
```

✓ **Correct**:
```c
busy_wait(time_wait);  // Thread actively uses CPU
```

### Pitfall 2: Not Synchronizing Thread Start

❌ **Wrong**:
```c
for (int i = 0; i < n; i++) {
    pthread_create(&threads[i], &attrs[i], func, &info[i]);
}
```
Threads start at different times, leading to unpredictable output.

✓ **Correct**:
```c
// Create all threads
for (int i = 0; i < n; i++) {
    pthread_create(&threads[i], &attrs[i], func, &info[i]);
}

// In thread function:
pthread_barrier_wait(&barrier);  // Synchronize start
```

### Pitfall 3: Forgetting PTHREAD_EXPLICIT_SCHED

❌ **Wrong**:
```c
pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
pthread_create(...);  // Thread inherits parent's policy instead!
```

✓ **Correct**:
```c
pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
pthread_create(...);
```

### Pitfall 4: Static Linking for RISC-V

For RISC-V QEMU without full system libraries:

❌ **Wrong**:
```makefile
CC = riscv64-linux-gnu-gcc
LDFLAGS = -pthread
```
May fail at runtime due to missing libraries.

✓ **Correct**:
```makefile
CC = riscv64-linux-gnu-gcc
CFLAGS = -static
LDFLAGS = -pthread
```

## Testing Strategy

### Local Testing (x86_64)

1. Build with local compiler:
   ```bash
   make -f Makefile.local STUDENT_ID=test
   ```

2. Test with sudo (required for SCHED_FIFO):
   ```bash
   sudo ./sched_demo_test_local -n 2 -t 0.5 -s FIFO,FIFO -p 10,20
   ```

### RISC-V Testing

1. Cross-compile:
   ```bash
   make STUDENT_ID=<your_id>
   ```

2. Deploy to QEMU:
   ```bash
   ./deploy.sh <your_id>
   ```

3. Boot and test:
   ```bash
   echo -1 > /proc/sys/kernel/sched_rt_runtime_us
   ./sched_demo_<your_id> -n 4 -t 0.5 -s NORMAL,FIFO,NORMAL,FIFO -p -1,10,-1,30
   ```

## Performance Considerations

- **CPU Time vs Wall Time**: The total execution time should be approximately:
  ```
  time_wait × num_threads × 3 iterations
  ```

- **Verification**: Use `time` command:
  ```bash
  time ./sched_demo -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30
  ```
  Should show ~9 seconds of user time (3 threads × 1s × 3 iterations)

## References

- `sched(7)` - Overview of Linux scheduling
- `pthread_create(3)` - Thread creation
- `pthread_attr_setschedpolicy(3)` - Setting thread scheduling policy
- `pthread_barrier_wait(3)` - Thread barrier operations
- `clock_gettime(2)` - High-resolution time measurement
- `sched_setaffinity(2)` - Setting CPU affinity

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Operation not permitted" | Need root for SCHED_FIFO | Run with sudo or in QEMU |
| Unexpected thread order | RT throttling enabled | `echo -1 > /proc/sys/kernel/sched_rt_runtime_us` |
| Threads don't start together | No barrier synchronization | Add `pthread_barrier_wait()` |
| Wrong execution time | Using sleep instead of busy wait | Use CPU time-based busy wait |
| Policy not applied | Missing PTHREAD_EXPLICIT_SCHED | Set explicit scheduling inheritance |

## Code Quality

The implementation follows best practices:
- ✓ Proper error handling (check return values)
- ✓ Resource cleanup (free memory, destroy barriers)
- ✓ Clear variable naming
- ✓ Comprehensive comments
- ✓ No memory leaks
- ✓ Thread-safe operations
