// KERNEL 1: SAXPY (Z[i] = A * X[i] + Y[i])
// Benchmarks the Round-Robin Arbiter under massive Read/Write traffic

// 1. Calculate Global Thread ID (global_tid = blockIdx * blockDim + threadIdx)
MUL R0, R13, R14    // R0 = block_id * threads_per_block
ADD R0, R0, R15     // R0 = R0 + local_tid (This is our array index 'i')

// 2. Load Configuration Registers (Addresses 0 to 3)
CONST R12, 0        
LDR R1, R12         // R1 = BASE_X
CONST R12, 1        
LDR R2, R12         // R2 = BASE_Y
CONST R12, 2        
LDR R3, R12         // R3 = BASE_Z
CONST R12, 3        
LDR R4, R12         // R4 = SCALAR_A (Q8.24 multiplier)

// 3. Calculate Exact Memory Pointers for this Thread
ADD R5, R1, R0      // R5 = Address of X[i]
ADD R6, R2, R0      // R6 = Address of Y[i]
ADD R7, R3, R0      // R7 = Address of Z[i]

// 4. Memory Fetch (These hammer the Arbiter)
LDR R8, R5          // R8 = X[i]
LDR R9, R6          // R9 = Y[i]

// 5. Arithmetic Execution
FIXED_MUL R10, R4, R8 // R10 = A * X[i] (Truncated to Q8.24)
ADD R11, R10, R9      // R11 = (A * X[i]) + Y[i]

// 6. Memory Writeback
STR R7, R11         // Store result in Z[i]

// 7. Terminate Thread
RET