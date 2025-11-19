# HW2 實驗報告

**學號**: 314551007
**作業**: Linux Thread Scheduling Demo

---

## 1. Describe how you implemented the program in detail. (10%)

### 整體架構

程式分為兩個主要部分：main thread 和 worker threads。

### main thread 實作細節

#### (1) parse command-line options
使用 `getopt()` 函數 parse 四個參數：
- `-n <num_threads>`: number of threads to run simultaneously
- `-t <time_wait>`: duration of "busy" period
- `-s <policies>`: scheduling policy for each thread, SCHED_FIFO or SCHED_NORMAL
- `-p <priorities>`: real-time thread priority for real-time threads

```c
while ((opt = getopt(argc, argv, "n:t:s:p:")) != -1) {
    switch (opt) {
        case 'n': num_threads = atoi(optarg); break;
        case 't': time_wait = atof(optarg); break;
        case 's': policies_str = strdup(optarg); break;
        case 'p': priorities_str = strdup(optarg); break;
    }
}
```

#### (2) CPU Affinity Setting
將所有 Threads 綁定到同一個 CPU（CPU 0) 上

```c
cpu_set_t cpuset;
CPU_ZERO(&cpuset);
CPU_SET(0, &cpuset);
sched_setaffinity(0, sizeof(cpu_set_t), &cpuset);
```


#### (3)  Set the attributes to each thread


```c
pthread_attr_init(&attrs[i]);

// 設定排程的繼承模式
pthread_attr_setinheritsched(&attrs[i], PTHREAD_EXPLICIT_SCHED);

// 設定排程的策略
pthread_attr_setschedpolicy(&attrs[i], policies[i]); // 使用 SCHED_OTHER 或 SCHED_FIFO

//對使用 FIFO 的 Thread 設定 priority  
if (policies[i] == SCHED_FIFO && priorities[i] > 0) {
    struct sched_param param;
    param.sched_priority = priorities[i];
    pthread_attr_setschedparam(&attrs[i], &param);
}
```



#### (4) 設定 Threads 的同步機制

因為如果一個一個的開始所有 Threads 有可能會產生錯誤的 output
因此使用 `pthread_barrier` 確保所有 Threads 同時開始執行，讓其同步啟動確保測試結果的一致性

```c
pthread_barrier_init(&barrier, NULL, num_threads);
```


### Worker thread 實作細節

每個 worker thread 的執行流程：

```c
void *thread_func(void *arg) {
    thread_info_t *info = (thread_info_t *)arg;

    /* 1. Wait until all threads are ready */

    pthread_barrier_wait(&barrier);

    /* 2. Do the task */ 
    for (int i = 0; i < 3; i++) {
        printf("Thread %d is running\n", info->thread_id);
        busy_wait(info->time_wait);  // busy waiting
    }

    // 3. 結束 Threads
    pthread_exit(NULL);
}
```

### Memory management

最後是釋放掉 allocate 的記憶體空間，避免 memory leak
```c
    pthread_barrier_destroy(&barrier);
    
    free(threads);
    free(thread_infos);
    free(attrs);
    free(policies);
    free(priorities);
    free(policies_str);
    free(priorities_str);
```

---

## 2. Describe the results of ./sched_demo -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30 and what causes that. (10%)

### 輸出結果

```
Thread 2 is running
Thread 2 is running
Thread 2 is running
Thread 1 is running
Thread 1 is running
Thread 1 is running
Thread 0 is running
Thread 0 is running
Thread 0 is running
```
原因為 NORMAL threads 的優先度會低於 FIFO threads，且 sched_rt_runtime_us 為 -1 real-time task 可以完全佔用 CPU 時間
而 real-time thread 會先執行(thread 2 and thread 1)，然後 thread 2 優先度比 threads 1 高，因此執行順序為 thread 2 > thread 1 > thread 0 (NORMAL threads)

## 3. 描述 `./sched_demo -n 4 -t 0.5 -s NORMAL,FIFO,NORMAL,FIFO -p -1,10,-1,30` 的結果及其原因 (10%)

### 3.1 執行緒配置

- **Thread 0**: SCHED_NORMAL, 優先權 N/A
- **Thread 1**: SCHED_FIFO, 優先權 10
- **Thread 2**: SCHED_NORMAL, 優先權 N/A
- **Thread 3**: SCHED_FIFO, 優先權 30（最高）

### 3.2 預期輸出結果

```
Thread 3 is running
Thread 3 is running
Thread 3 is running
Thread 1 is running
Thread 1 is running
Thread 1 is running
Thread 0 is running
Thread 2 is running
Thread 0 is running
Thread 2 is running
Thread 0 is running
Thread 2 is running
```

或者（Thread 0 和 Thread 2 的順序可能交錯）：

```
Thread 3 is running
Thread 3 is running
Thread 3 is running
Thread 1 is running
Thread 1 is running
Thread 1 is running
Thread 2 is running
Thread 0 is running
Thread 2 is running
Thread 0 is running
Thread 2 is running
Thread 0 is running
```

### 3.3 原因分析

#### 階段 1: Thread 3 先執行（FIFO 30）

**原因**：
- Thread 3 有最高優先權（FIFO 30）
- 會完整執行 3 次迴圈
- 其他所有執行緒都在等待

#### 階段 2: Thread 1 接著執行（FIFO 10）

**原因**：
- Thread 3 完成後，Thread 1 是優先權最高的執行緒
- 會完整執行 3 次迴圈
- Thread 0 和 Thread 2（NORMAL）仍在等待

#### 階段 3: Thread 0 和 Thread 2 交替執行（NORMAL）

**原因**：
- 兩個執行緒都使用 SCHED_NORMAL（CFS）
- CFS 會在它們之間**公平分配** CPU 時間
- 因為兩個執行緒優先權相同，會輪流執行
- 每個執行緒執行一段時間後會被排程器切換

### 3.4 NORMAL 執行緒的排程行為

**為什麼 Thread 0 和 Thread 2 會交錯？**

1. **CFS（完全公平排程器）的特性**：
   - 追蹤每個執行緒的 CPU 使用時間（vruntime）
   - 總是選擇 vruntime 最小的執行緒執行
   - 確保所有執行緒獲得公平的 CPU 時間

2. **時間切片機制**：
   - NORMAL 執行緒有時間切片
   - 執行一段時間後會被搶佔，讓其他 NORMAL 執行緒執行
   - 這與 FIFO 執行緒不同（FIFO 會持續執行直到完成）

3. **實際執行流程**：
   ```
   Thread 0 執行 → 時間片用完 → 切換到 Thread 2
   Thread 2 執行 → 時間片用完 → 切換到 Thread 0
   如此重複，直到兩個執行緒都完成
   ```

### 3.5 與測試案例 2 的差異

**測試案例 2** (3 個執行緒)：
- 2 個 FIFO + 1 個 NORMAL
- NORMAL 執行緒獨自執行，沒有競爭

**測試案例 3** (4 個執行緒)：
- 2 個 FIFO + 2 個 NORMAL
- 2 個 NORMAL 執行緒會**相互競爭** CPU 時間
- 展示了 CFS 的公平性

### 3.6 關鍵概念總結

```
執行順序：
1. Thread 3 (FIFO 30) - 完整執行 3 次
2. Thread 1 (FIFO 10) - 完整執行 3 次
3. Thread 0 和 Thread 2 (NORMAL) - 交錯執行，各執行 3 次

時間分配：
- FIFO 執行緒：獨佔 CPU，不會被同優先權或低優先權執行緒打斷
- NORMAL 執行緒：公平分享 CPU，會被定期切換
```

---

## 4. 描述如何實作 n 秒忙碌等待 (10%)

### 4.1 實作方法

使用 `clock_gettime()` 搭配 `CLOCK_THREAD_CPUTIME_ID` 實作精確的忙碌等待：

```c
void busy_wait(double seconds) {
    struct timespec start, current;
    double elapsed;

    // 取得執行緒的 CPU 時間（不是掛鐘時間）
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &start);

    do {
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &current);
        elapsed = (current.tv_sec - start.tv_sec) +
                  (current.tv_nsec - start.tv_nsec) / 1e9;
    } while (elapsed < seconds);
}
```

### 4.2 為什麼選擇 CLOCK_THREAD_CPUTIME_ID

#### (1) CPU 時間 vs 掛鐘時間

**CPU 時間（CLOCK_THREAD_CPUTIME_ID）**：
- 只計算執行緒**實際在 CPU 上執行**的時間
- **不包括**執行緒被搶佔或等待的時間
- 當執行緒被排程器切換出去時，時鐘會暫停

**掛鐘時間（CLOCK_REALTIME）**：
- 計算實際經過的物理時間
- **包括**執行緒被搶佔、等待的時間
- 即使執行緒沒有執行，時鐘仍會繼續

#### (2) 範例說明差異

假設執行緒要忙碌等待 1 秒：

**使用 CLOCK_REALTIME（錯誤）**：
```
0.0s: 執行緒開始執行
0.3s: 執行緒被搶佔，進入等待
1.5s: 執行緒恢復執行
1.5s: elapsed = 1.5s >= 1.0s，結束
→ 實際只使用了 0.3s CPU 時間！
```

**使用 CLOCK_THREAD_CPUTIME_ID（正確）**：
```
CPU 0.0s: 執行緒開始執行
CPU 0.3s: 執行緒被搶佔（CPU 時鐘暫停）
CPU 0.3s: 執行緒恢復執行（CPU 時鐘繼續）
CPU 1.0s: elapsed = 1.0s，結束
→ 精確使用了 1.0s CPU 時間
```

### 4.3 為什麼不能使用 sleep()

```c
// 錯誤的做法
void wrong_busy_wait(double seconds) {
    sleep(seconds);  // ❌ 錯誤！
}
```

**為什麼不行？**

1. **執行緒進入睡眠狀態**：
   - `sleep()` 會讓執行緒進入 `TASK_INTERRUPTIBLE` 狀態
   - 執行緒被移出執行佇列
   - 不會消耗 CPU 時間

2. **無法展示排程行為**：
   - 睡眠的執行緒不參與排程競爭
   - 無法展示 FIFO 或 NORMAL 的排程差異
   - 所有執行緒看起來會同時執行

3. **測試會失敗**：
   - 輸出順序會變得隨機
   - 無法預測哪個執行緒先完成
   - 不符合作業要求

### 4.4 忙碌等待的特性

#### 優點：
1. **精確的 CPU 時間測量**：確保每個執行緒真正使用指定的 CPU 時間
2. **展示排程行為**：執行緒持續處於可執行狀態，參與排程競爭
3. **可預測的結果**：高優先權執行緒會完整執行

#### 缺點：
1. **浪費 CPU 資源**：空轉消耗 CPU
2. **電力消耗**：持續使用 CPU
3. **只適合測試**：實際應用中應使用 sleep

### 4.5 時間計算細節

```c
elapsed = (current.tv_sec - start.tv_sec) +
          (current.tv_nsec - start.tv_nsec) / 1e9;
```

**說明**：
- `tv_sec`：秒數（整數）
- `tv_nsec`：奈秒數（0-999999999）
- 除以 `1e9` 將奈秒轉換為秒
- 兩者相加得到總經過時間（秒）

**精確度**：
- 奈秒級別（10^-9 秒）
- 遠高於作業要求（秒級別）

### 4.6 驗證方法

使用 `time` 命令驗證 CPU 時間：

```bash
time ./sched_demo_314551007 -n 3 -t 1.0 -s NORMAL,FIFO,FIFO -p -1,10,30
```

預期結果：
```
real    0m9.xxx s   # 實際經過時間（包含等待）
user    0m9.xxx s   # 用戶態 CPU 時間（3 執行緒 × 1 秒 × 3 次 = 9 秒）
sys     0m0.xxx s   # 核心態 CPU 時間（很少）
```

**驗證**：`user` 時間應該接近 `num_threads × time_wait × 3`

---

## 5. kernel.sched_rt_runtime_us 的效果及其影響 (10%)

### 5.1 什麼是 sched_rt_runtime_us
### What does the kernel.sched_rt_runtime_us effect? If this setting is changed (eg. 500000, 950000, 1000000), what will happen?(10%)


`sched_rt_runtime_us` 是 Linux 核心的 **RT throttling** 機制的參數，用來控制 real-time threads在每秒內最多可以使用多少 CPU 時間（微秒µs）
如果 sched_rt_runtime_us = 500000，那麼 real-time threads在 1 秒內最多只能使用 0.95 秒的 CPU，剩下的 0.05 秒保留給普通任務。
下面是讓 sched_rt_runtime_us 設定 400000 ( 1 秒內使用最多 0.4 秒) 跑出來的結果
```bash
./sched_demo  -n 3 -t 2 -s NORMAL,FIFO,FIFO -p -1,10,30
Thread 2 is running
Thread 0 is running
Thread 0 is running
Thread 2 is running
Thread 0 is running
Thread 2 is running
Thread 1 is running
Thread 1 is running
Thread 1 is running
```
這是設定 -1 的結果
```bash
./sched_demo  -n 3 -t 2 -s NORMAL,FIFO,FIFO -p -1,10,30
Thread 2 is running
Thread 2 is running
Thread 2 is running
Thread 1 is running
Thread 1 is running
Thread 1 is running
Thread 0 is running
Thread 0 is running
Thread 0 is running
```
可以看到設定為 400000 時順序變更了，因為第一秒內 real-time 只能最多使用 0.4 秒，因此在第一秒時 Thread 2 只能執行 0.4 秒就必須讓給 Thread 1 去執行了，另外 sched_rt_runtime_us 是 real-time task 共享的因此也不會輪到 Thread 0 去使用。
---

## 總結

本次作業深入探討了 Linux 的執行緒排程機制，主要學習重點包括：

1. **排程策略的實作**：
   - SCHED_NORMAL（CFS）：公平排程，適合一般程式
   - SCHED_FIFO：即時排程，嚴格按優先權執行

2. **執行緒同步**：
   - 使用 pthread_barrier 確保同步啟動
   - 使用 pthread_attr 正確配置執行緒屬性

3. **精確的時間測量**：
   - 使用 CLOCK_THREAD_CPUTIME_ID 測量真實 CPU 時間
   - 區分 CPU 時間與掛鐘時間

4. **系統安全機制**：
   - RT throttling 保護系統不被 RT 執行緒佔滿
   - 理解不同設定值的影響

透過這次實作，深入理解了作業系統排程器的運作原理，以及如何在 Linux 中控制執行緒的排程行為。
