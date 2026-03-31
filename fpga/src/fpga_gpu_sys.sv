`default_nettype none
`timescale 1ns/1ns

module fpga_gpu_sys (
    input wire clk,
    input wire reset,
    input wire start,
    output wire done,
    output wire [31:0] debug_pixel_out,
    
    // VGA Output Ports
    output wire [11:0] vga_color_out,
    output wire hsync,
    output wire vsync
);

    // --- 1. PROGRAM MEMORY (ROM) ---
    (* ram_style = "distributed" *) reg [15:0] program_mem [0:255];
    initial $readmemh("program_mem.hex", program_mem);
    
    logic [7:0] p_read_addr [0:0]; 
    logic [15:0] p_read_data [0:0]; 
    logic [0:0] p_read_valid; 
        
    always_comb begin
        p_read_data[0] = program_mem[p_read_addr[0]];
    end

    // --- 2. CONFIGURATION REGISTERS ---
    reg [31:0] config_regs [0:7];
    initial $readmemh("config_regs.hex", config_regs);

    // --- 3. THE FRAMEBUFFER (1-Channel Monolithic BRAM) ---
    logic [0:0] d_write_valid;
    logic [0:0] d_read_valid; 
    logic [18:0] d_read_addr [0:0];
    logic [18:0] d_write_addr [0:0];
    logic [31:0] d_write_data [0:0];
    
    logic [31:0] bram_read_data [0:0]; 
    logic [31:0] final_read_data [0:0];

    wire [7:0] bram_dout_8bit; 
    wire [7:0] bram_portb_out;
    
    logic [0:0] d_read_ready_delayed; 
    always_ff @(posedge clk) begin
        d_read_ready_delayed[0] <= d_read_valid[0];
    end

    bram #(
        .ADDR_WIDTH(19),  
        .DATA_WIDTH(8)    
    ) fb_bram (
        .clka(clk),
        .wea(d_write_valid[0]),
        .addra(d_write_valid[0] ? d_write_addr[0][18:0] : d_read_addr[0][18:0]),
        .dina(d_write_data[0][7:0]), 
        .douta(bram_dout_8bit),
        
        .clkb(clk_40mhz), 
        .web(1'b0),
        .addrb(pixel_index[18:0]), 
        .dinb(8'h0),
        .doutb(bram_portb_out)
    );

    assign bram_read_data[0] = {24'd0, bram_dout_8bit};
    assign final_read_data[0] = (d_read_addr[0] < 19'd10) ? config_regs[d_read_addr[0]] : bram_read_data[0];

    // --- 4. VGA DISPLAY SUBSYSTEM ---
    wire clk_40mhz;
    
    clk_wiz_0 pixel_clock_gen (
        .clk_in1(clk),
        .clk_out1(clk_40mhz)
    );

    wire video_on_raw, hsync_raw, vsync_raw;
    wire [10:0] vga_x, vga_y;
    
    vga_controller vga_ctrl (
        .clk_40MHz(clk_40mhz),
        .reset(reset),
        .hsync(hsync_raw),
        .vsync(vsync_raw),
        .video_on(video_on_raw),
        .x(vga_x),
        .y(vga_y)
    );

    reg video_on_d;
    reg hsync_reg, vsync_reg;

    always_ff @(posedge clk_40mhz) begin
        video_on_d <= video_on_raw;
        hsync_reg  <= hsync_raw;
        vsync_reg  <= vsync_raw;
    end

    assign hsync = hsync_reg;
    assign vsync = vsync_reg;

    wire [19:0] pixel_index = (vga_y * 800) + vga_x; 

    wire [11:0] mapped_color;
    color_mapper cmap (
        .iter_count(video_on_d ? bram_portb_out : 8'h00),
        .vga_color(mapped_color)
    );

    assign vga_color_out = video_on_d ? mapped_color : 12'h000;

    // --- 5. AUTOLOADER FOR DCR ---
    reg [1:0] boot_state = 0;
    always_ff @(posedge clk) begin
        if (reset) begin
            boot_state <= 0;
        end else if (boot_state < 2) begin
            boot_state <= boot_state + 1;
        end
    end
    wire auto_we = (boot_state == 2'd1);

    // --- 6. THE GPU CORE ---
    gpu #(
        .DATA_MEM_ADDR_BITS(19), 
        .DATA_MEM_DATA_BITS(32), 
        .DATA_MEM_NUM_CHANNELS(1), 
        .PROGRAM_MEM_ADDR_BITS(8), 
        .PROGRAM_MEM_DATA_BITS(16), 
        .PROGRAM_MEM_NUM_CHANNELS(1)
    ) core (
        .clk(clk), .reset(reset), .start(start), .done(done),
        
        .device_control_write_enable(auto_we), 
        .device_control_data(32'd480000),  
        
        .program_mem_read_valid(p_read_valid), .program_mem_read_address(p_read_addr), 
        .program_mem_read_ready(1'b1), .program_mem_read_data(p_read_data),
        
        .data_mem_read_valid(d_read_valid), .data_mem_read_address(d_read_addr), 
        .data_mem_read_ready(d_read_ready_delayed), .data_mem_read_data(final_read_data), 
        
        .data_mem_write_valid(d_write_valid), .data_mem_write_address(d_write_addr), 
        .data_mem_write_data(d_write_data), .data_mem_write_ready(1'b1)
    );

    assign debug_pixel_out = bram_read_data[0];
    
endmodule