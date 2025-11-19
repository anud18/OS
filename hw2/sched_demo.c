#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sched.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

typedef struct {
    int thread_id;
    int policy;
    int priority;
    double time_wait;
} thread_info_t;

pthread_barrier_t barrier;

void busy_wait(double seconds) {
    struct timespec start, current;
    double elapsed;

    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &start);

    do {
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &current);
        elapsed = (current.tv_sec - start.tv_sec) + (current.tv_nsec - start.tv_nsec) / 1e9;
    } while (elapsed < seconds);
}

void *thread_func(void *arg) {
    thread_info_t *info = (thread_info_t *)arg;

    /* 1. Wait until all threads are ready */
    pthread_barrier_wait(&barrier);

    /* 2. Do the task - run loop 3 times */
    for (int i = 0; i < 3; i++) {
        printf("Thread %d is running\n", info->thread_id);
        /* Busy for <time_wait> seconds */
        busy_wait(info->time_wait);
        
    }

    /* 3. Exit the function */
    pthread_exit(NULL);
}

int parse_policy(const char *policy_str) {
    if (strcmp(policy_str, "NORMAL") == 0) {
        return SCHED_OTHER;
    } else if (strcmp(policy_str, "FIFO") == 0) {
        return SCHED_FIFO;
    } else {
        fprintf(stderr, "Unknown policy: %s\n", policy_str);
        exit(1);
    }
}

int main(int argc, char *argv[]) {
    int num_threads = 0;
    double time_wait = 0.0;
    char *policies_str = NULL;
    char *priorities_str = NULL;
    int opt;

    while ((opt = getopt(argc, argv, "n:t:s:p:")) != -1) {
        switch (opt) {
            case 'n':
                num_threads = atoi(optarg);
                break;
            case 't':
                time_wait = atof(optarg);
                break;
            case 's':
                policies_str = strdup(optarg);
                break;
            case 'p':
                priorities_str = strdup(optarg);
                break;
            default:
                fprintf(stderr, "Usage: %s -n <num_threads> -t <time_wait> -s <policies> -p <priorities>\n", argv[0]);
                exit(1);
        }
    }

    if (num_threads <= 0 || time_wait <= 0 || !policies_str || !priorities_str) {
        fprintf(stderr, "Missing required arguments\n");
        exit(1);
    }

    pthread_t *threads = malloc(num_threads * sizeof(pthread_t));
    thread_info_t *thread_infos = malloc(num_threads * sizeof(thread_info_t));
    pthread_attr_t *attrs = malloc(num_threads * sizeof(pthread_attr_t));

    int *policies = malloc(num_threads * sizeof(int));
    char *token = strtok(policies_str, ",");
    for (int i = 0; i < num_threads && token != NULL; i++) {
        policies[i] = parse_policy(token);
        token = strtok(NULL, ",");
    }

    int *priorities = malloc(num_threads * sizeof(int));
    token = strtok(priorities_str, ",");
    for (int i = 0; i < num_threads && token != NULL; i++) {
        priorities[i] = atoi(token);
        token = strtok(NULL, ",");
    }

    pthread_barrier_init(&barrier, NULL, num_threads);

    //  Set CPU affinity 
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(0, &cpuset); 

    if (sched_setaffinity(0, sizeof(cpu_set_t), &cpuset) != 0) {
        perror("sched_setaffinity");
        exit(1);
    }

    // Create  threads 
    for (int i = 0; i < num_threads; i++) {
        thread_infos[i].thread_id = i;
        thread_infos[i].policy = policies[i];
        thread_infos[i].priority = priorities[i];
        thread_infos[i].time_wait = time_wait;

        pthread_attr_init(&attrs[i]);
        pthread_attr_setinheritsched(&attrs[i], PTHREAD_EXPLICIT_SCHED);
        pthread_attr_setschedpolicy(&attrs[i], policies[i]);

        if (policies[i] == SCHED_FIFO && priorities[i] > 0) {
            struct sched_param param;
            param.sched_priority = priorities[i];
            pthread_attr_setschedparam(&attrs[i], &param);
        }

        if (pthread_create(&threads[i], &attrs[i], thread_func, &thread_infos[i]) != 0) {
            perror("pthread_create");
            exit(1);
        }
    }

    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
        pthread_attr_destroy(&attrs[i]);
    }

    pthread_barrier_destroy(&barrier);
    
    free(threads);
    free(thread_infos);
    free(attrs);
    free(policies);
    free(priorities);
    free(policies_str);
    free(priorities_str);

    return 0;
}
