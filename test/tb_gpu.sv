`timescale 1ns/1ns
`default_nettype none

module tb_gpu;
    localparam DATA_MEM_ADDR_BITS = 8;
    localparam DATA_MEM_DATA_BITS = 8;
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
    logic device_control_write_enable;
    logic [7:0] device_control_data;
    logic [2:0] core_state;
    logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid;
    logic [PROGRAM_MEM_ADDR_BITS-1:0]
        program_mem_read_address [PROGRAM_MEM_NUM_CHANNELS-1:0];
    logic [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready;
    logic [PROGRAM_MEM_DATA_BITS-1:0]
        program_mem_read_data [PROGRAM_MEM_NUM_CHANNELS-1:0];

    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid;
    logic [DATA_MEM_ADDR_BITS-1:0]
        data_mem_read_address [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready;
    logic [DATA_MEM_DATA_BITS-1:0]
        data_mem_read_data [DATA_MEM_NUM_CHANNELS-1:0];

    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid;
    logic [DATA_MEM_ADDR_BITS-1:0]
        data_mem_write_address [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_DATA_BITS-1:0]
        data_mem_write_data [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready;
    logic [7:0] blocks_dispatched; // How many blocks have been sent to cores?
    logic [7:0] blocks_done; // How many blocks have finished processing?

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

    reg [PROGRAM_MEM_DATA_BITS-1:0] program_mem [0:15]; // just for testing 16 instructions for now

    // initial begin
    //     // Replace with real kernel
         
    initial begin
        $display("Loading program.hex...");
        $readmemh("program_mem.hex", program_mem);
        $display("program.hex loaded");
    end
        

    always_comb begin
        program_mem_read_ready = '1;
        for (int i = 0; i < PROGRAM_MEM_NUM_CHANNELS; i++) begin
            program_mem_read_data[i] =
                program_mem[program_mem_read_address[i]];
        end
    end


    reg [DATA_MEM_DATA_BITS-1:0] data_mem [0:255];
    
    initial begin
        $display("Loading data_mem.hex...");
        $readmemh("data_mem.hex", data_mem);
        $display("data_mem.hex loaded");
    end
    

    always_comb begin
        data_mem_read_ready  = '1;
        data_mem_write_ready = '1;
    end

    always_ff @(posedge clk) begin
        // Reads
        for (int i = 0; i < DATA_MEM_NUM_CHANNELS; i++) begin
            if (data_mem_read_valid[i]) begin
                data_mem_read_data[i] <=
                    data_mem[data_mem_read_address[i]];
            end
        end

        // Writes
        for (int i = 0; i < DATA_MEM_NUM_CHANNELS; i++) begin
            if (data_mem_write_valid[i]) begin
                data_mem[data_mem_write_address[i]] <=
                    data_mem_write_data[i];
            end
        end
    end

    // -----------------------------
    // Test Sequence
    // -----------------------------
    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        device_control_write_enable = 0;
        device_control_data = 0;

        repeat (5) @(posedge clk);
        reset = 0;

        // Program thread count
        @(posedge clk);
        device_control_write_enable = 1;
        device_control_data = 8'd16; // example
        @(posedge clk);
        device_control_write_enable = 0;

        // Start kernel
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for GPU completion
        wait (done);

        $display("GPU execution finished.");
        $finish;
    end

endmodule