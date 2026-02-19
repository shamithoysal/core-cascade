`default_nettype none
`timescale 1ns/1ns

module alu (
    input wire logic clk,
    input wire logic reset,
    input wire logic enable,

    // 3'b101 (5) is the EXECUTE state
    input wire logic [2:0] core_state,

    // Control Signals
    input wire logic [2:0] decoded_alu_arithmetic_mux,
    input wire logic decoded_alu_output_mux,

    // Data Inputs (Signed for Fixed-Point and SRA)
    input wire logic signed [31:0] rs,
    input wire logic signed [31:0] rt,

    // Data Output
    output logic [31:0] alu_out
);

    // Operation Map
    localparam ADD = 3'b000;
    localparam SUB = 3'b001;
    localparam MUL = 3'b010; // Standard 32-bit Mul
    localparam FIXED_MUL = 3'b011; // Q8.24 Fixed-Point Mul
    localparam SLL = 3'b100; // Shift Left Logical
    localparam SRL = 3'b101; // Shift Right Logical
    localparam SRA = 3'b110; // Shift Right Arithmetic
    localparam DIV = 3'b111; // Standard Div

    // Internal Signals
    logic [31:0] alu_out_reg;
    logic signed [63:0] full_mult_result;
    always_comb full_mult_result = rs * rt;


    assign alu_out = alu_out_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            alu_out_reg <= 32'b0;
        end else if (enable) begin
            // Only update results during the EXECUTE stage
            if (core_state == 3'b101) begin
                if (decoded_alu_output_mux == 1'b1) begin
                    // COMPARISON MODE (Flags for Branching)
                    // Output: {29'b0, GT, EQ, LT}
                    alu_out_reg <= {29'b0, (rs > rt), (rs == rt), (rs < rt)};
                end else begin
                    // ARITHMETIC MODE
                    case (decoded_alu_arithmetic_mux)
                        ADD: alu_out_reg <= rs + rt;
                        SUB: alu_out_reg <= rs - rt;
                        MUL: alu_out_reg <= full_mult_result[31:0];
                        FIXED_MUL: alu_out_reg <= full_mult_result[55:24];
                        SLL: alu_out_reg <= rs << rt[4:0];
                        SRL: alu_out_reg <= rs >> rt[4:0];
                        SRA: alu_out_reg <= rs >>> rt[4:0];
                        DIV: alu_out_reg <= rs / rt;
                    endcase
                end
            end
        end
    end
endmodule