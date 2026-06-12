// KERNEL 3: GEMM (C = A * B)
// Matrix Size: 32x32 (1,024 Threads)
// Benchmarks sustained MAC operations and spatial locality memory bottlenecks.

// 1. Calculate Global Thread ID
MUL R0, R13, R14    // R0 = block_id * threads_per_block
ADD R0, R0, R15     // R0 = global_id

// 2. Load Base Pointers and N from Config (Addresses 0-3)
CONST R12, 0
LDR R1, R12         // R1 = BASE_A
CONST R12, 1
LDR R2, R12         // R2 = BASE_B
CONST R12, 2
LDR R3, R12         // R3 = BASE_C
CONST R12, 3
LDR R4, R12         // R4 = N (32)

// 3. Calculate Row and Col (N=32, so shift right by 5)
CONST R12, 5
SRL R5, R0, R12     // R5 = row = (global_id >> 5)
SLL R11, R5, R12    // R11 = row * 32
SUB R6, R0, R11     // R6 = col = global_id - (row * 32)

// 4. Initialize Accumulator (C[row][col]) and Loop Counter (k)
CONST R10, 0        // R10 = accumulator = 0
CONST R7, 0         // R7 = k = 0

LOOP_START:
// 5. Loop Condition: if (k >= N) Break
CMP R7, R4          // Compare k to 32. (Does R7 - R4)
BRzp END_LOOP       // If Zero or Positive (k >= 32), jump to END_LOOP

// 6. Calculate Address A: BASE_A + (row * N) + k
MUL R8, R5, R4      // R8 = row * N
ADD R8, R8, R7      // R8 = (row * N) + k
ADD R8, R8, R1      // R8 = Address of A[row][k]

// 7. Calculate Address B: BASE_B + (k * N) + col
MUL R9, R7, R4      // R9 = k * N
ADD R9, R9, R6      // R9 = (k * N) + col
ADD R9, R9, R2      // R9 = Address of B[k][col]

// 8. Fetch Data
LDR R8, R8          // R8 = A[row][k]
LDR R9, R9          // R9 = B[k][col]

// 9. Multiply and Accumulate (Q8.24)
FIXED_MUL R11, R8, R9 // R11 = A * B
ADD R10, R10, R11     // accumulator += R11

// 10. Increment k and loop
CONST R12, 1
ADD R7, R7, R12     // k++
BRnzp LOOP_START    // Unconditional Jump

END_LOOP:
// 11. Store Final Accumulated Value
ADD R12, R3, R0     // R12 = BASE_C + global_id
STR R12, R10        // Store accumulator to memory

RET