`default_nettype none
`timescale 1ns/1ns

// REGISTER FILE
// > Each thread within each core has it's own register file with 13 free registers and 3 read-only registers
// > Read-only registers hold the familiar %blockIdx, %blockDim, and %threadIdx values critical to SIMD
module registers #(
    parameter THREADS_PER_BLOCK = 4,
    parameter THREAD_ID = 0,
    parameter DATA_BITS = 32
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [7:0] block_id, // Wire is fine for inputs
    input wire [2:0] core_state,
    input wire [3:0] decoded_rd_address,
    input wire [3:0] decoded_rs_address,
    input wire [3:0] decoded_rt_address,
    input wire decoded_reg_write_enable,
    input wire [1:0] decoded_reg_input_mux,
    input wire [DATA_BITS-1:0] decoded_immediate,
    input wire [DATA_BITS-1:0] alu_out,
    input wire [DATA_BITS-1:0] lsu_out,
    output reg [DATA_BITS-1:0] rs,
    output reg [DATA_BITS-1:0] rt
);
    localparam ARITHMETIC = 2'b00, MEMORY = 2'b01, CONSTANT = 2'b10;

    // 16 registers of 32-bits each
    reg [DATA_BITS-1:0] registers[15:0];
    
    // FIX: Declare loop variable 'k' here, outside the always block
    integer k;

    always @(posedge clk) begin
        if (reset) begin
            rs <= 0;
            rt <= 0;
            // Clear General Purpose Registers (R0-R12)
            for(k=0; k<13; k=k+1) begin
                registers[k] <= 0;
            end
            
            // Read-Only Registers (R13-R15)
            // Note: R13 is block_id (updated dynamically), R14/R15 are static
            registers[1] <= 0; 
            registers[2] <= THREADS_PER_BLOCK; 
            registers[3] <= THREAD_ID; 
        end else if (enable) begin
            // Update Block ID register (R13)
            registers[1] <= block_id; 

            // READ (Output to ALU/LSU)
            if (core_state == 3'b011) begin
                rs <= registers[decoded_rs_address];
                rt <= registers[decoded_rt_address];
            end

            // WRITE (Input from ALU/LSU/Immediate)
            if (core_state == 3'b110) begin
                if (decoded_reg_write_enable && decoded_rd_address < 13) begin
                    case (decoded_reg_input_mux)
                        ARITHMETIC: registers[decoded_rd_address] <= alu_out;
                        MEMORY:     registers[decoded_rd_address] <= lsu_out;
                        CONSTANT:   registers[decoded_rd_address] <= decoded_immediate;
                    endcase
                end
            end
        end
    end
endmodule
