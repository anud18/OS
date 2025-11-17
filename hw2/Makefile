# Makefile for sched_demo RISC-V cross-compilation

# Set your student ID here (or override with: make STUDENT_ID=your_id)
STUDENT_ID ?= student_id

# Cross-compiler for RISC-V
CC = riscv64-linux-gnu-gcc

# Compiler flags
CFLAGS = -Wall -Wextra -O2 -static
LDFLAGS = -pthread

# Source and target
SOURCE = sched_demo.c
TARGET = sched_demo_$(STUDENT_ID)

# Output options for dependency generation
OUTPUT_OPTION = -MMD -MP -o $@

# Object and dependency files
OBJS = $(SOURCE:.c=.o)
DEPS = $(SOURCE:.c=.d)

.PHONY: all clean

# Default target
all: $(TARGET)

# Import dependencies
-include $(DEPS)

# Link the final executable
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@
	@echo "Build complete: $(TARGET)"

# Compile source files to object files
%.o: %.c
	$(CC) $(CFLAGS) -c $< $(OUTPUT_OPTION)

# Clean build artifacts
clean:
	@rm -f $(TARGET) $(OBJS) $(DEPS) sched_demo_*
	@echo "Clean complete"

# Help target
help:
	@echo "Usage:"
	@echo "  make                    - Build the program with default student ID"
	@echo "  make STUDENT_ID=123456  - Build with specific student ID"
	@echo "  make clean              - Remove build artifacts"
