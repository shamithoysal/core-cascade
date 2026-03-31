`default_nettype none
`timescale 1ns/1ns

module bram #(
    parameter ADDR_WIDTH = 19,
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 524288
)(
    // Port A (GPU Read/Write)
    input  wire clka,
    input  wire wea,
    input  wire [ADDR_WIDTH-1:0] addra,
    input  wire [DATA_WIDTH-1:0] dina,
    output reg  [DATA_WIDTH-1:0] douta,

    // Port B (VGA Read)
    input  wire clkb,
    input  wire web,
    input  wire [ADDR_WIDTH-1:0] addrb,
    input  wire [DATA_WIDTH-1:0] dinb,
    output reg  [DATA_WIDTH-1:0] doutb
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    // Initialize to black
    initial begin
        for (int i = 0; i < DEPTH; i = i + 1) begin
            ram[i] = {DATA_WIDTH{1'b0}};
        end
    end

    // Port A
    always @(posedge clka) begin
        if (wea) begin
            ram[addra] <= dina;
        end
        douta <= ram[addra];
    end

    // Port B
    always @(posedge clkb) begin
        if (web) begin
            ram[addrb] <= dinb;
        end
        doutb <= ram[addrb];
    end

endmodule