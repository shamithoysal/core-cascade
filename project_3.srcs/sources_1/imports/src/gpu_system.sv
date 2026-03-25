`timescale 1ns / 1ps
`default_nettype none

module gpu_system (
    // ==========================================
    // GPU CLOCK DOMAIN (e.g., 100 MHz)
    // ==========================================
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire device_control_write_enable,
    input  wire [31:0] device_control_data,
    output logic done,
    
    // ==========================================
    // VGA CLOCK DOMAIN (e.g., 25 MHz)
    // ==========================================
    input  wire clk_vga,
    input  wire [18:0] vga_address,
    output logic [31:0] vga_read_data,

    // ==========================================
    // DEBUG PORTS
    // ==========================================
    output logic [7:0] current_pc,
    output logic [2:0] core_state,
    output logic decoded_ret,
    output logic [31:0] blocks_dispatched,
    output logic [31:0] blocks_done
);

    // ---------------------------------------------------------
    // SYSTEM PARAMETERS
    // Note: DATA_MEM_NUM_CHANNELS is strictly 1 to match the single GPU port of the BRAM
    // ---------------------------------------------------------
    localparam int DATA_MEM_ADDR_BITS = 19; 
    localparam int DATA_MEM_DATA_BITS = 32; 
    localparam int DATA_MEM_NUM_CHANNELS = 1; 
    
    localparam int PROGRAM_MEM_ADDR_BITS = 8;
    localparam int PROGRAM_MEM_DATA_BITS = 16;
    localparam int PROGRAM_MEM_NUM_CHANNELS = 1;

    // ---------------------------------------------------------
    // INTERNAL BUSSES (Using SV logic)
    // ---------------------------------------------------------
    logic [PROGRAM_MEM_NUM_CHANNELS-1:0] p_read_valid;
    logic [PROGRAM_MEM_ADDR_BITS-1:0]    p_read_addr [PROGRAM_MEM_NUM_CHANNELS-1:0];
    logic [PROGRAM_MEM_DATA_BITS-1:0]    p_read_data [PROGRAM_MEM_NUM_CHANNELS-1:0];
    
    logic [DATA_MEM_NUM_CHANNELS-1:0]    d_read_valid;
    logic [DATA_MEM_NUM_CHANNELS-1:0]    d_write_valid;
    logic [DATA_MEM_NUM_CHANNELS-1:0]    d_read_ready;
    logic [DATA_MEM_NUM_CHANNELS-1:0]    d_write_ready;
    
    logic [DATA_MEM_ADDR_BITS-1:0]       d_read_addr  [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_ADDR_BITS-1:0]       d_write_addr [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_DATA_BITS-1:0]       d_read_data  [DATA_MEM_NUM_CHANNELS-1:0];
    logic [DATA_MEM_DATA_BITS-1:0]       d_write_data [DATA_MEM_NUM_CHANNELS-1:0];

    // ---------------------------------------------------------
    // GPU CORE INSTANTIATION
    // ---------------------------------------------------------
    gpu #(
        .DATA_MEM_ADDR_BITS(DATA_MEM_ADDR_BITS), 
        .DATA_MEM_DATA_BITS(DATA_MEM_DATA_BITS), 
        .DATA_MEM_NUM_CHANNELS(DATA_MEM_NUM_CHANNELS),
        .PROGRAM_MEM_ADDR_BITS(PROGRAM_MEM_ADDR_BITS), 
        .PROGRAM_MEM_DATA_BITS(PROGRAM_MEM_DATA_BITS), 
        .PROGRAM_MEM_NUM_CHANNELS(PROGRAM_MEM_NUM_CHANNELS)
    ) core (
        .clk(clk), 
        .reset(reset), 
        .start(start), 
        .done(done),
        .device_control_write_enable(device_control_write_enable), 
        .device_control_data(device_control_data),
        
        // Program Memory Bus
        .program_mem_read_valid(p_read_valid), 
        .program_mem_read_address(p_read_addr), 
        .program_mem_read_ready('1), // ROM is physically always ready
        .program_mem_read_data(p_read_data),
        
        // Data Memory Bus (Now hooked up to BRAM Handshakes)
        .data_mem_read_valid(d_read_valid), 
        .data_mem_read_address(d_read_addr), 
        .data_mem_read_ready(d_read_ready), 
        .data_mem_read_data(d_read_data),
        
        .data_mem_write_valid(d_write_valid), 
        .data_mem_write_address(d_write_addr), 
        .data_mem_write_data(d_write_data), 
        .data_mem_write_ready(d_write_ready),
        
        // Debug
        .current_pc(current_pc), 
        .core_state(core_state), 
        .decoded_ret(decoded_ret), 
        .blocks_dispatched(blocks_dispatched), 
        .blocks_done(blocks_done)
    );

    // ---------------------------------------------------------
    // PROGRAM MEMORY (ROM)
    // ---------------------------------------------------------
    // We retain this localized ROM because your GPU still needs 
    // a place to read its assembly instructions from!
    logic [PROGRAM_MEM_DATA_BITS-1:0] program_mem [0:255];

    initial begin
        // NOTE: Ensure 'program_mem.hex' is added to your Vivado project sources!
        $readmemh("program_mem.hex", program_mem);
    end

    always_comb begin
        p_read_data[0] = program_mem[p_read_addr[0]];
    end

    // ---------------------------------------------------------
    // TRUE DUAL-PORT FRAMEBUFFER BRAM INSTANTIATION
    // ---------------------------------------------------------
    // The BRAM handles its own data_mem.hex initialization internally.
    framebuffer_bram fb_inst (
        // PORT 1 & 2: GPU (e.g., 100 MHz)
        .clk_gpu(clk),
        
        // GPU Write Channel 0
        .mem_write_valid(d_write_valid[0]),
        .mem_write_address(d_write_addr[0]),
        .mem_write_data(d_write_data[0]),
        .mem_write_ready(d_write_ready[0]),

        // GPU Read Channel 0
        .mem_read_valid(d_read_valid[0]),
        .mem_read_address(d_read_addr[0]),
        .mem_read_data(d_read_data[0]),
        .mem_read_ready(d_read_ready[0]),

        // PORT 3: VGA Controller (e.g., 25 MHz)
        .clk_vga(clk_vga),
        .vga_address(vga_address),
        .vga_read_data(vga_read_data)
    );

endmodule