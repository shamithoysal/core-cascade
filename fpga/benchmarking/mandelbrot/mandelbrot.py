import time
from collections import Counter

# Nexys 4 VGA Resolution
WIDTH = 800
HEIGHT = 600

# Q8.24 Decoded Config Regs
START_X = -2.75
START_Y = -1.50
DX = 0.005078125
DY = 0.005078125
MAX_ITER = 255

print(f"Generating Mandelbrot Golden Model ({WIDTH}x{HEIGHT})...")
start_time = time.time()

escape_histogram = Counter()
total_iterations_required = 0

for py in range(HEIGHT):
    y0 = START_Y + (py * DY)
    for px in range(WIDTH):
        x0 = START_X + (px * DX)
        
        x = 0.0
        y = 0.0
        iteration = 0
        
        # The exact math your ALU runs
        while (x*x + y*y <= 4.0) and (iteration < MAX_ITER):
            xtemp = x*x - y*y + x0
            y = 2*x*y + y0
            x = xtemp
            iteration += 1
            
        escape_histogram[iteration] += 1
        total_iterations_required += iteration

print(f"Done in {time.time() - start_time:.2f} seconds.\n")

# --- THE METRICS FOR YOUR REPORT ---
print("=== ARCHITECTURAL METRICS ===")
print(f"Total Pixels Computed: {WIDTH * HEIGHT:,}")
print(f"Absolute Minimum Iterations Required: {total_iterations_required:,}")

# Each iteration is roughly 7 math ops (3 mults, 3 adds, 1 cmp)
total_ops = total_iterations_required * 7
print(f"Minimum Operations Performed: {total_ops:,} Operations")

print("\n=== ESCAPE HISTOGRAM (TOP 10) ===")
print("Iter | Pixel Count | Percentage")
print("-" * 35)
for iter_val, count in escape_histogram.most_common(10):
    pct = (count / (WIDTH * HEIGHT)) * 100
    print(f"{iter_val:>4} | {count:>11,} | {pct:>5.1f}%")

print(f"\nPixels that hit MAX_ITER (255): {escape_histogram[255]:,}")