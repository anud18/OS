STUDENT_ID = 314551007

CC = riscv64-linux-gnu-gcc

CFLAGS = -Wall -Wextra -O2 -static
LDFLAGS = -pthread

SOURCE = sched_demo.c
TARGET = sched_demo_$(STUDENT_ID)

OUTPUT_OPTION = -MMD -MP -o $@

OBJS = $(SOURCE:.c=.o)
DEPS = $(SOURCE:.c=.d)

.PHONY: all clean

all: $(TARGET)

-include $(DEPS)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@
	@echo "Build complete: $(TARGET)"

%.o: %.c
	$(CC) $(CFLAGS) -c $< $(OUTPUT_OPTION)

clean:
	@rm -f $(TARGET) $(OBJS) $(DEPS) sched_demo_*
	@echo "Clean complete"

