import random

# GEMM Configuration
N = 32
MIN_VAL = -2.0
MAX_VAL = 2.0

def float_to_q8_24(f_val):
    int_val = int(round(f_val * (1 << 24)))
    return int_val & 0xFFFFFFFF

def hardware_mac(acc_q8, a_q8, b_q8):
    def to_signed(val):
        return val - (1 << 32) if val & (1 << 31) else val
    
    a_signed = to_signed(a_q8)
    b_signed = to_signed(b_q8)
    acc_signed = to_signed(acc_q8)

    # FIXED_MUL Emulation
    mult_64 = a_signed * b_signed
    fixed_mul_res = mult_64 >> 24
    
    # ADD Emulation
    new_acc = acc_signed + fixed_mul_res
    return new_acc & 0xFFFFFFFF

print(f"Generating GEMM {N}x{N} Golden Model...")

# 1. Generate Matrices
A_floats = [[random.uniform(MIN_VAL, MAX_VAL) for _ in range(N)] for _ in range(N)]
B_floats = [[random.uniform(MIN_VAL, MAX_VAL) for _ in range(N)] for _ in range(N)]

A_q8 = [float_to_q8_24(val) for row in A_floats for val in row]
B_q8 = [float_to_q8_24(val) for row in B_floats for val in row]

# 2. Setup Data Memory (Pointers + Arrays)
base_a = 4
base_b = base_a + (N * N)
base_c = base_b + (N * N)

data_mem = []
data_mem.append(f"{base_a:08X}")
data_mem.append(f"{base_b:08X}")
data_mem.append(f"{base_c:08X}")
data_mem.append(f"{N:08X}")

for val in A_q8: data_mem.append(f"{val:08X}")
for val in B_q8: data_mem.append(f"{val:08X}")
for _ in range(N * N): data_mem.append(f"{0:08X}")

with open("data_mem.hex", "w") as f:
    f.write("\n".join(data_mem) + "\n")
print("-> Created data_mem.hex")

# 3. Calculate Expected Output (Matrix C)
expected_c = []
for row in range(N):
    for col in range(N):
        acc = 0
        for k in range(N):
            a_val = A_q8[row * N + k]
            b_val = B_q8[k * N + col]
            acc = hardware_mac(acc, a_val, b_val)
        expected_c.append(f"{acc:08X}")

with open("expected_c.hex", "w") as f:
    f.write("\n".join(expected_c) + "\n")
print("-> Created expected_c.hex")
print(f"Total Threads Required: {N*N}")