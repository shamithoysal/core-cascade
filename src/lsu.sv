`default_nettype none
`timescale 1ns/1ns

// LOAD-STORE UNIT
// > Handles asynchronous memory load and store operations and waits for response
// > Each thread in each core has it's own LSU
// > LDR, STR instructions are executed here
module lsu #(
    parameter DATA_BITS = 32 // DEFAULT TO 32
) (
    input wire clk,
    input wire reset,
    input wire enable,
    // State
    input reg [2:0] core_state,
    // Memory Control Signals
    input reg decoded_mem_read_enable,
    input reg decoded_mem_write_enable,
    // Registers (32-bit inputs)
    input reg [DATA_BITS-1:0] rs,
    input reg [DATA_BITS-1:0] rt,
    // Data Memory
    output reg mem_read_valid,
    output reg [7:0] mem_read_address, // Address width usually separate
    input reg mem_read_ready,
    input reg [DATA_BITS-1:0] mem_read_data,
    output reg mem_write_valid,
    output reg [7:0] mem_write_address,
    output reg [DATA_BITS-1:0] mem_write_data,
    input reg mem_write_ready,
    // LSU Outputs
    output reg [1:0] lsu_state,
    output reg [DATA_BITS-1:0] lsu_out
);
    localparam IDLE = 2'b00, REQUESTING = 2'b01, WAITING = 2'b10, DONE = 2'b11;

    always @(posedge clk) begin
        if (reset) begin
            lsu_state <= IDLE;
            lsu_out <= 0;
            mem_read_valid <= 0;
            mem_read_address <= 0;
            mem_write_valid <= 0;
            mem_write_address <= 0;
            mem_write_data <= 0;
        end else if (enable) begin
            // LDR Instruction
            if (decoded_mem_read_enable) begin
                case (lsu_state)
                    IDLE: begin
                        if (core_state == 3'b011) lsu_state <= REQUESTING;
                    end
                    REQUESTING: begin
                        mem_read_valid <= 1;
                        mem_read_address <= rs[7:0]; // Truncate 32-bit reg to 8-bit addr
                        lsu_state <= WAITING;
                    end
                    WAITING: begin
                        if (mem_read_ready == 1) begin
                            mem_read_valid <= 0;
                            lsu_out <= mem_read_data; // Capture 32-bit data
                            lsu_state <= DONE;
                        end
                    end
                    DONE: begin
                        if (core_state == 3'b110) lsu_state <= IDLE;
                    end
                endcase
            end
            
            // STR Instruction
            if (decoded_mem_write_enable) begin
                case (lsu_state)
                    IDLE: begin
                        if (core_state == 3'b011) lsu_state <= REQUESTING;
                    end
                    REQUESTING: begin
                        mem_write_valid <= 1;
                        mem_write_address <= rs[7:0]; // Addr from RS
                        mem_write_data <= rt;         // Data from RT (32-bit)
                        lsu_state <= WAITING;
                    end
                    WAITING: begin
                        if (mem_write_ready) begin
                            mem_write_valid <= 0;
                            lsu_state <= DONE;
                        end
                    end
                    DONE: begin
                        if (core_state == 3'b110) lsu_state <= IDLE;
                    end
                endcase
            end
        end
    end
endmodule
