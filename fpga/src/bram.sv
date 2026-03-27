`default_nettype none

module bram #(
    parameter ADDR_WIDTH = 12, 
    parameter DATA_WIDTH = 32
)(
    // PORT A: GPU Write (100 MHz)
    input wire clka,
    input wire wea,
    input wire [ADDR_WIDTH-1:0] addra,
    input wire [DATA_WIDTH-1:0] dina,
    output reg [DATA_WIDTH-1:0] douta,

    // PORT B: VGA Read (Future - Tied off for now)
    input wire clkb,
    input wire [ADDR_WIDTH-1:0] addrb,
    output reg [DATA_WIDTH-1:0] doutb
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram [0:(2**ADDR_WIDTH)-1];

    always_ff @(posedge clka) begin
        if (wea) ram[addra] <= dina;
        douta <= ram[addra]; // GPU doesn't technically read this, but good practice
    end

    always_ff @(posedge clkb) begin
        doutb <= ram[addrb];
    end

endmodule