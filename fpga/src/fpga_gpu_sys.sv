`default_nettype none

module fpga_gpu_sys (
    input wire clk,
    input wire reset,
    input wire start,
    output wire done,
    output wire [31:0] debug_pixel_out
);

    // --- 1. PROGRAM MEMORY (ROM) ---
    (* ram_style = "block" *) reg [15:0] program_mem [0:255];
    initial $readmemh("program_mem.hex", program_mem);
    
    // UNPACKED ARRAYS (For the buses)
    logic [7:0] p_read_addr [0:0]; 
    logic [15:0] p_read_data [0:0]; 
        
    always_ff @(posedge clk) begin
        p_read_data[0] <= program_mem[p_read_addr[0]];
    end

    // --- 2. CONFIGURATION REGISTERS ---
    reg [31:0] config_regs [0:6];
    initial $readmemh("config_regs.hex", config_regs);

    // --- 3. THE FRAMEBUFFER (True Dual-Port BRAM) ---
    // PACKED VECTOR (For the flat valid signal)
    logic [3:0] d_write_valid;
    
    // UNPACKED ARRAYS (For the data and address buses)
    logic [18:0] d_read_addr [0:3];
    logic [18:0] d_write_addr [0:3];
    logic [31:0] d_write_data [0:3];
    
    logic [31:0] bram_read_data [0:3]; 
    logic [31:0] final_read_data [0:3];

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : bram_channels
            
            wire [7:0] bram_dout_8bit; // Cleanly catch the 8-bit output
            
            bram #(
                .ADDR_WIDTH(17), // 131,072 depth per channel (Fits 640x480 total)
                .DATA_WIDTH(8)   // TRUNCATED TO 8 BITS
            ) fb_bram (
                .clka(clk),
                .wea(d_write_valid[i]),
                .addra(d_write_valid[i] ? d_write_addr[i][16:0] : d_read_addr[i][16:0]),
                
                // SLICE THE 32-BIT ALU DATA DOWN TO 8 BITS BEFORE WRITING
                .dina(d_write_data[i][7:0]), 
                
                .douta(bram_dout_8bit),
                
                .clkb(clk),
                .addrb(17'd0), // VGA side tied off for now
                .doutb()
            );

            // Zero-extend the 8-bit BRAM output back to 32 bits for the GPU read bus
            assign bram_read_data[i] = {24'd0, bram_dout_8bit};

            // THE TRAFFIC COP (The MUX)
            assign final_read_data[i] = (d_read_addr[i] < 19'd10) ? config_regs[d_read_addr[i]] : bram_read_data[i];
        end
    endgenerate

    // --- AUTOLOADER FOR DCR ---
    // Waits for reset to drop, pulses write_enable for 1 cycle, then goes to sleep.
    reg [1:0] boot_state = 0;
    always_ff @(posedge clk) begin
        if (reset) begin
            boot_state <= 0;
        end else if (boot_state < 2) begin
            boot_state <= boot_state + 1;
        end
    end
    
    wire auto_we = (boot_state == 2'd1);

    // --- 4. THE GPU CORE ---
    gpu #(
        .DATA_MEM_ADDR_BITS(19), .DATA_MEM_DATA_BITS(32), .DATA_MEM_NUM_CHANNELS(4),
        .PROGRAM_MEM_ADDR_BITS(8), .PROGRAM_MEM_DATA_BITS(16), .PROGRAM_MEM_NUM_CHANNELS(1)
    ) core (
        .clk(clk), .reset(reset), .start(start), .done(done),
        
        .device_control_write_enable(auto_we), // Uses the autoloader pulse
        .device_control_data(32'd307200),      // FULL 640x480 THREAD COUNT!     
        // .device_control_address(32'd0),     // UNCOMMENT IF YOUR GPU REQUIRES AN ADDRESS PORT
        
        .program_mem_read_valid(), .program_mem_read_address(p_read_addr), 
        .program_mem_read_ready('1), .program_mem_read_data(p_read_data),
        
        .data_mem_read_valid(), .data_mem_read_address(d_read_addr), 
        .data_mem_read_ready('1), .data_mem_read_data(final_read_data), 
        
        .data_mem_write_valid(d_write_valid), .data_mem_write_address(d_write_addr), 
        .data_mem_write_data(d_write_data), .data_mem_write_ready('1)
    );

    assign debug_pixel_out = bram_read_data[0];
    
endmodule