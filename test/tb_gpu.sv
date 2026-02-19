`timescale 1ns/1ns
`default_nettype none

module tb_gpu;

    // -------------------------------------------------------------------------
    // PARAMETERS (UPDATED FOR 32-BIT & FIXED POINT)
    // -------------------------------------------------------------------------
    localparam DATA_MEM_ADDR_BITS = 8;
    localparam DATA_MEM_DATA_BITS = 32; // UPDATE: Changed from 8 to 32 for Fixed-Point
    localparam DATA_MEM_NUM_CHANNELS = 4;
    
    localparam PROGRAM_MEM_ADDR_BITS = 8;
    localparam PROGRAM_MEM_DATA_BITS = 16;
    localparam PROGRAM_MEM_NUM_CHANNELS = 1;
    
    localparam NUM_CORES = 2;
    localparam THREADS_PER_BLOCK = 4;

    // -------------------------------------------------------------------------
    // SIGNALS
    // -------------------------------------------------------------------------
    logic clk;
    logic reset;
    
    // Clock Generation (100MHz equivalent)
    always #5 clk = ~clk;

    logic start;
    logic done;
    
    // Debug Signals
    logic decoded_ret;
    logic [7:0] current_pc;
    logic [2:0] core_state;
    logic [7:0] blocks_dispatched; 
    logic [7:0] blocks_done; 

    // Device Control (Thread Count)
    logic device_control_write_enable;
    logic [7:0] device_control_data;

    // Program Memory Interface
    logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid;
    logic [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address [PROGRAM_MEM_NUM_CHANNELS-1:0];
    logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready;
    logic [PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data [PROGRAM_MEM_NUM_CHANNELS-1:0];

    // Data Memory Interface
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid;
    logic [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready;
    logic [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid;
    logic [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready;

    // -------------------------------------------------------------------------
    // GPU INSTANTIATION (DUT)
    // -------------------------------------------------------------------------
    gpu #(
        .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS),
        .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS),
        .DATA_MEM_NUM_CHANNELS(DATA_MEM_NUM_CHANNELS),
        .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS),
        .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS),
        .PROGRAM_MEM_NUM_CHANNELS(PROGRAM_MEM_NUM_CHANNELS),
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done(done),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        
        // Memory Ports
        .program_mem_read_valid(program_mem_read_valid),
        .program_mem_read_address(program_mem_read_address),
        .program_mem_read_ready(program_mem_read_ready),
        .program_mem_read_data(program_mem_read_data),
        
        .data_mem_read_valid(data_mem_read_valid),
        .data_mem_read_address(data_mem_read_address),
        .data_mem_read_ready(data_mem_read_ready),
        .data_mem_read_data(data_mem_read_data),
        .data_mem_write_valid(data_mem_write_valid),
        .data_mem_write_address(data_mem_write_address),
        .data_mem_write_data(data_mem_write_data),
        .data_mem_write_ready(data_mem_write_ready),
        
        // Debug Ports
        .current_pc(current_pc),
        .core_state(core_state),
        .decoded_ret(decoded_ret),
        .blocks_dispatched(blocks_dispatched),
        .blocks_done(blocks_done)
    );

    // -------------------------------------------------------------------------
    // MEMORY SIMULATION
    // -------------------------------------------------------------------------
    
    // UPDATE: Increased size to 256 to prevent out-of-bounds "ghost instruction" loops
    reg [PROGRAM_MEM_DATA_BITS-1:0] program_mem [0:255]; 

    initial begin
        // Initialize memory with NOPs (0) to be safe
        for (int k = 0; k < 256; k++) program_mem[k] = 0;
        
        $display("Loading program_mem.hex...");
        // Ensure this file exists in your sim folder!
        $readmemh("program_mem.hex", program_mem); 
        $display("program.hex loaded");
    end

    // Program Memory Read Logic (Combinational for low latency simulation)
    always_comb begin
        program_mem_read_ready = '1;
        for (int i = 0; i < PROGRAM_MEM_NUM_CHANNELS; i++) begin
            program_mem_read_data[i] = program_mem[program_mem_read_address[i]];
        end
    end

    // Data Memory (32-bit width)
    reg [DATA_MEM_DATA_BITS-1:0] data_mem [0:255];

    initial begin
        // Initialize with zeros
        for (int k = 0; k < 256; k++) data_mem[k] = 0;

        $display("Loading data_mem.hex...");
        // Ensure this file uses 32-bit hex values!
        $readmemh("data_mem.hex", data_mem); 
        $display("data_mem.hex loaded");
    end

    always_comb begin
        data_mem_read_ready = '1;
        data_mem_write_ready = '1;
    end

    // Data Memory Read/Write Logic (Synchronous)
    always_ff @(posedge clk) begin
        // Reads
        for (int i = 0; i < DATA_MEM_NUM_CHANNELS; i++) begin
            if (data_mem_read_valid[i]) begin
                data_mem_read_data[i] <= data_mem[data_mem_read_address[i]];
            end
        end
        // Writes
        for (int i = 0; i < DATA_MEM_NUM_CHANNELS; i++) begin
            if (data_mem_write_valid[i]) begin
                data_mem[data_mem_write_address[i]] <= data_mem_write_data[i];
                // Optional: Print writes to console for debug
                // $display("Time %0t: Wrote %h to Addr %h", $time, data_mem_write_data[i], data_mem_write_address[i]);
            end
        end
    end

    // -------------------------------------------------------------------------
    // TEST SEQUENCE
    // -------------------------------------------------------------------------
    initial begin
        // 1. Initialize
        clk = 0;
        reset = 1;
        start = 0;
        device_control_write_enable = 0;
        device_control_data = 0;
        
        // 2. Reset Pulse
        repeat (5) @(posedge clk);
        reset = 0;

        // 3. Configure GPU (Set Thread Count)
        @(posedge clk);
        device_control_write_enable = 1;
        device_control_data = 8'd16; // Execute 16 threads
        @(posedge clk);
        device_control_write_enable = 0;

        // 4. Start Kernel
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // 5. Wait for Completion
        // Add a timeout to prevent infinite hanging if bug persists
        fork
            begin
                wait (done);
                $display("GPU execution finished successfully at time %0t.", $time);
                // Print Result at Address 2 (Expect 0.25 -> 0x00400000 if using test_fixed.hex)
                $display("Result at Addr 2: %h", data_mem[1]); 
            end
            begin
                #100000; // 100,000 ns timeout
                $display("ERROR: Simulation timed out! GPU never asserted 'done'.");
                $display("Debug Info: PC=%h, State=%h, BlocksDone=%d", current_pc, core_state, blocks_done);
            end
        join_any
        
        $finish;
    end

endmodule