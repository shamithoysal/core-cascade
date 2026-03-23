`default_nettype none
`timescale 1ns/1ns

module gpu_system (
    input wire clk,
    input wire reset,
    input wire start,
    input wire device_control_write_enable,
    input wire [31:0] device_control_data,
    output wire done,
    
    input wire [18:0] host_read_address,
    output logic [31:0] host_read_data,

    // Debug X-Ray Ports
    output wire [7:0] current_pc,
    output wire [2:0] core_state,
    output wire decoded_ret,
    output wire [31:0] blocks_dispatched,
    output wire [31:0] blocks_done
);

    localparam DATA_MEM_ADDR_BITS = 19; 
    localparam DATA_MEM_DATA_BITS = 32; 
    localparam DATA_MEM_NUM_CHANNELS = 4; 
    localparam PROGRAM_MEM_ADDR_BITS = 8;
    localparam PROGRAM_MEM_DATA_BITS = 16;
    localparam PROGRAM_MEM_NUM_CHANNELS = 1;

    logic [PROGRAM_MEM_NUM_CHANNELS-1:0] p_read_valid;
    logic [PROGRAM_MEM_ADDR_BITS-1:0] p_read_addr [PROGRAM_MEM_NUM_CHANNELS-1:0];
    logic [PROGRAM_MEM_DATA_BITS-1:0] p_read_data [PROGRAM_MEM_NUM_CHANNELS-1:0];
    
    logic [DATA_MEM_NUM_CHANNELS-1:0] d_read_valid, d_write_valid;
    logic [DATA_MEM_ADDR_BITS-1:0] d_read_addr [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_ADDR_BITS-1:0] d_write_addr [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_DATA_BITS-1:0] d_read_data [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_DATA_BITS-1:0] d_write_data [DATA_MEM_NUM_CHANNELS-1:0];

    gpu #(
        .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS), .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS), .DATA_MEM_NUM_CHANNELS(DATA_MEM_NUM_CHANNELS),
        .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS), .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS), .PROGRAM_MEM_NUM_CHANNELS(PROGRAM_MEM_NUM_CHANNELS)
    ) core (
        .clk(clk), .reset(reset), .start(start), .done(done),
        .device_control_write_enable(device_control_write_enable), .device_control_data(device_control_data),
        .program_mem_read_valid(p_read_valid), .program_mem_read_address(p_read_addr), .program_mem_read_ready('1), .program_mem_read_data(p_read_data),
        .data_mem_read_valid(d_read_valid), .data_mem_read_address(d_read_addr), .data_mem_read_ready('1), .data_mem_read_data(d_read_data),
        .data_mem_write_valid(d_write_valid), .data_mem_write_address(d_write_addr), .data_mem_write_data(d_write_data), .data_mem_write_ready('1),
        .current_pc(current_pc), .core_state(core_state), .decoded_ret(decoded_ret), .blocks_dispatched(blocks_dispatched), .blocks_done(blocks_done)
    );

    reg [PROGRAM_MEM_DATA_BITS-1:0] program_mem [0:255];
    reg [DATA_MEM_DATA_BITS-1:0] data_mem [0:524287];

    initial begin
        for (int k = 0; k < 256; k++) program_mem[k] = 0;
        for (int k = 0; k < 524288; k++) data_mem[k] = 0;

        // Ensure these paths are correct for your WSL setup
        $readmemh("/mnt/d/Data/CoreCascade/core-cascade/test/program_mem.hex", program_mem);
        $readmemh("/mnt/d/Data/CoreCascade/core-cascade/test/data_mem.hex", data_mem);

        // HARD OVERRIDE FOR FULL SCALE
        data_mem[2] = 32'h00013333; // DX (High-res step)
        data_mem[3] = 32'h00011111; // DY (High-res step)
        data_mem[6] = 32'h00000280; // Width = 640
    end

    always_comb begin
        p_read_data[0] = program_mem[p_read_addr[0]];
    end

    always_ff @(posedge clk) begin
        for (int i = 0; i < DATA_MEM_NUM_CHANNELS; i++) begin
            if (d_read_valid[i]) d_read_data[i] <= data_mem[d_read_addr[i]];
            if (d_write_valid[i]) data_mem[d_write_addr[i]] <= d_write_data[i];
        end
        host_read_data <= data_mem[host_read_address];
    end
endmodule