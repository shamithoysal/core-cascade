`timescale 1ns/1ns
`default_nettype none

module tb_gpu;
    localparam DATA_MEM_ADDR_BITS = 19; // Expanded for 640x480 (524,288 addresses max)
    localparam DATA_MEM_DATA_BITS = 32; 
    localparam DATA_MEM_NUM_CHANNELS = 4;
    
    localparam PROGRAM_MEM_ADDR_BITS = 8;
    localparam PROGRAM_MEM_DATA_BITS = 16;
    localparam PROGRAM_MEM_NUM_CHANNELS = 1;

    localparam NUM_CORES = 2;
    localparam THREADS_PER_BLOCK = 4;

    logic clk;
    logic reset;
    always #5 clk = ~clk;

    logic start;
    logic done;

    logic decoded_ret;
    logic [7:0] current_pc;
    logic [2:0] core_state;
    logic [31:0] blocks_dispatched;
    logic [31:0] blocks_done;
    logic device_control_write_enable;
    logic [31:0] device_control_data; 

    // Program Mem Wires
    logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid;
    logic [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address [PROGRAM_MEM_NUM_CHANNELS-1:0];
    logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready;
    logic [PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data [PROGRAM_MEM_NUM_CHANNELS-1:0];

    // Data Mem Wires (12-bit addresses)
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid;
    logic [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready;
    logic [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid;
    logic [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready;

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
        .current_pc(current_pc),
        .core_state(core_state),
        .decoded_ret(decoded_ret),
        .blocks_dispatched(blocks_dispatched),
        .blocks_done(blocks_done)
    );

    // SIMULATED MEMORY
    reg [PROGRAM_MEM_DATA_BITS-1:0] program_mem [0:255];
    reg [DATA_MEM_DATA_BITS-1:0] data_mem [0:524287];

    initial begin
        for (int k = 0; k < 256; k++) program_mem[k] = 0;
        for (int k = 0; k < 524288; k++) data_mem[k] = 0;
        $readmemh("program_mem.hex", program_mem);
        $readmemh("data_mem.hex", data_mem);
    end

    always_comb begin
        program_mem_read_ready = '1;
        for (int i = 0; i < PROGRAM_MEM_NUM_CHANNELS; i++) begin
            program_mem_read_data[i] = program_mem[program_mem_read_address[i]];
        end
        data_mem_read_ready = '1;
        data_mem_write_ready = '1;
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < DATA_MEM_NUM_CHANNELS; i++) begin
            if (data_mem_read_valid[i]) data_mem_read_data[i] <= data_mem[data_mem_read_address[i]];
            if (data_mem_write_valid[i]) data_mem[data_mem_write_address[i]] <= data_mem_write_data[i];
        end
    end

    // TEST SEQUENCE
    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        device_control_write_enable = 0;
        device_control_data = 0;

        repeat (5) @(posedge clk);
        reset = 0;

        // Disptach 307200 threads (640x480 resolution)
        @(posedge clk);
        device_control_write_enable = 1;
        device_control_data = 32'd3072; // 64 x 48 threads
        @(posedge clk);
        device_control_write_enable = 0;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        fork
            begin
                wait (done);
                $display("GPU execution finished successfully at time %0t.", $time);
                // DUMP THE FRAMEBUFFER TO HEX FILE -- Dump exactly 307,200 pixels (Addresses 10 to 307209)
                $writememh("output_frame.hex", data_mem, 10, 3081);
                $display("Frame saved to output_frame.hex!");
            end
            begin
                // FIX: Bypass the 32-bit integer limit by repeating 1 billion ns, 10 times.
                repeat (10) #1000000000; 
                $display("ERROR: Simulation timed out!");
            end
        join_any
        $finish;
    end
endmodule