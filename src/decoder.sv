`default_nettype none
`timescale 1ns/1ns

module decoder (
    input wire clk,
    input wire reset,
    input reg [2:0] core_state,
    input reg [15:0] instruction,
    // Instruction Signals
    output reg [3:0] decoded_rd_address,
    output reg [3:0] decoded_rs_address,
    output reg [3:0] decoded_rt_address,
    output reg [2:0] decoded_nzp,
    output reg [7:0] decoded_immediate,
    // Control Signals
    output reg decoded_reg_write_enable,
    output reg decoded_mem_read_enable,
    output reg decoded_mem_write_enable,
    output reg decoded_nzp_write_enable,
    output reg [1:0] decoded_reg_input_mux,
    
    // UPDATE 1: Widen this signal to 3 bits to match Shamit's ALU
    output reg [2:0] decoded_alu_arithmetic_mux, 
    
    output reg decoded_alu_output_mux,
    output reg decoded_pc_mux,
    output reg decoded_ret
);

    // UPDATE 2: Add the new Opcodes from the Upgrade Log
    localparam NOP       = 4'b0000,
               BRnzp     = 4'b0001,
               CMP       = 4'b0010,
               ADD       = 4'b0011,
               SUB       = 4'b0100,
               MUL       = 4'b0101,
               DIV       = 4'b0110,
               LDR       = 4'b0111,
               STR       = 4'b1000,
               CONST     = 4'b1001,
               FIXED_MUL = 4'b1010, // New Opcode
               SLL       = 4'b1011, // New Opcode
               SRL       = 4'b1100, // New Opcode
               SRA       = 4'b1101, // New Opcode
               RET       = 4'b1111;

    always @(posedge clk) begin
        if (reset) begin
            // Reset all signals
            decoded_rd_address <= 0;
            decoded_rs_address <= 0;
            decoded_rt_address <= 0;
            decoded_immediate <= 0;
            decoded_nzp <= 0;
            decoded_reg_write_enable <= 0;
            decoded_mem_read_enable <= 0;
            decoded_mem_write_enable <= 0;
            decoded_nzp_write_enable <= 0;
            decoded_reg_input_mux <= 0;
            decoded_alu_arithmetic_mux <= 0;
            decoded_alu_output_mux <= 0;
            decoded_pc_mux <= 0;
            decoded_ret <= 0;
        end else begin
            if (core_state == 3'b010) begin
                // Decode Instruction Fields
                decoded_rd_address <= instruction[11:8];
                decoded_rs_address <= instruction[7:4];
                decoded_rt_address <= instruction[3:0];
                decoded_immediate <= instruction[7:0];
                decoded_nzp <= instruction[11:9];

                // Defaults
                decoded_reg_write_enable <= 0;
                decoded_mem_read_enable <= 0;
                decoded_mem_write_enable <= 0;
                decoded_nzp_write_enable <= 0;
                decoded_reg_input_mux <= 0;
                decoded_alu_arithmetic_mux <= 0;
                decoded_alu_output_mux <= 0;
                decoded_pc_mux <= 0;
                decoded_ret <= 0;

                // UPDATE 3: Map Opcodes to the new 3-bit ALU Select Codes
                case (instruction[15:12])
                    NOP: begin end
                    BRnzp: decoded_pc_mux <= 1;
                    CMP: begin
                        decoded_alu_output_mux <= 1;
                        decoded_nzp_write_enable <= 1;
                    end
                    ADD: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 3'b000; // Matches ALU ADD
                    end
                    SUB: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 3'b001; // Matches ALU SUB
                    end
                    MUL: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 3'b010; // Matches ALU MUL
                    end
                    DIV: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        // CRITICAL FIX: Old DIV was 2'b11. New ALU DIV is 3'b111. 
                        // If you kept 2'b11, it would be 3'b011 (FIXED_MUL) and break logic.
                        decoded_alu_arithmetic_mux <= 3'b111; 
                    end
                    
                    // NEW INSTRUCTIONS
                    FIXED_MUL: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 3'b011; // Matches ALU FIXED_MUL
                    end
                    SLL: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 3'b100; // Matches ALU SLL
                    end
                    SRL: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 3'b101; // Matches ALU SRL
                    end
                    SRA: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b00;
                        decoded_alu_arithmetic_mux <= 3'b110; // Matches ALU SRA
                    end

                    LDR: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b01;
                        decoded_mem_read_enable <= 1;
                    end
                    STR: begin
                        decoded_mem_write_enable <= 1;
                    end
                    CONST: begin
                        decoded_reg_write_enable <= 1;
                        decoded_reg_input_mux <= 2'b10;
                    end
                    RET: begin
                        decoded_ret <= 1;
                    end
                endcase
            end
        end
    end
endmodule