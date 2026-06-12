import random

# Benchmark Configuration
N = 5000
SCALAR_A_FLOAT = 1.5
MIN_VAL = -5.0
MAX_VAL = 5.0

def float_to_q8_24(f_val):
    """Converts a Python float into a 32-bit Q8.24 Fixed-Point Hex"""
    int_val = int(round(f_val * (1 << 24)))
    # Apply 32-bit 2's complement mask for negative numbers
    return int_val & 0xFFFFFFFF

def hardware_math_emulation(a_q8, x_q8, y_q8):
    """Mathematically emulates your Verilog ALU exactly"""
    # 1. Convert unsigned 32-bit integers back to Python signed integers
    def to_signed(val):
        return val - (1 << 32) if val & (1 << 31) else val
    
    a_signed = to_signed(a_q8)
    x_signed = to_signed(x_q8)
    y_signed = to_signed(y_q8)

    # 2. Emulate the FIXED_MUL instruction (64-bit mult, shifted right by 24)
    mult_64 = a_signed * x_signed
    fixed_mul_res = mult_64 >> 24
    
    # 3. Emulate the ADD instruction
    z_signed = fixed_mul_res + y_signed
    
    # Return masked 32-bit hex
    return z_signed & 0xFFFFFFFF

print("Generating SAXPY Golden Model...")

# 1. Generate the random floating-point arrays
X_floats = [random.uniform(MIN_VAL, MAX_VAL) for _ in range(N)]
Y_floats = [random.uniform(MIN_VAL, MAX_VAL) for _ in range(N)]

# 2. Setup the Data Memory Array (data_mem.hex)
data_mem = []

# --- CONFIG REGISTERS (The Pointers) ---
base_x = 4
base_y = base_x + N
base_z = base_y + N

data_mem.append(f"{base_x:08X}")                # Address 0: BASE_X
data_mem.append(f"{base_y:08X}")                # Address 1: BASE_Y
data_mem.append(f"{base_z:08X}")                # Address 2: BASE_Z
data_mem.append(f"{float_to_q8_24(SCALAR_A_FLOAT):08X}") # Address 3: SCALAR_A

# --- DATA ARRAYS ---
# Append Array X
for f in X_floats:
    data_mem.append(f"{float_to_q8_24(f):08X}")

# Append Array Y
for f in Y_floats:
    data_mem.append(f"{float_to_q8_24(f):08X}")

# Append empty slots for Array Z (The FPGA will overwrite these)
for _ in range(N):
    data_mem.append(f"{0:08X}")

# Pad the rest of the BRAM up to 524,288 if needed by Vivado, 
# but usually $readmemh stops when the file ends.

# Write data_mem.hex
with open("data_mem.hex", "w") as f:
    f.write("\n".join(data_mem) + "\n")
print(f"-> Created saxpy/data_mem.hex")

# 3. Calculate the Expected Results (expected_z.hex)
expected_z = []
for i in range(N):
    x_q8 = float_to_q8_24(X_floats[i])
    y_q8 = float_to_q8_24(Y_floats[i])
    a_q8 = float_to_q8_24(SCALAR_A_FLOAT)
    
    z_q8 = hardware_math_emulation(a_q8, x_q8, y_q8)
    expected_z.append(f"{z_q8:08X}")

# Write expected_z.hex
with open("expected_z.hex", "w") as f:
    f.write("\n".join(expected_z) + "\n")
print(f"-> Created saxpy/expected_z.hex")

print("\nGolden Model Generation Complete.")
print(f"Total elements per array: {N}")
print(f"Total Threads Required: {N} threads ({N//4} blocks)")