`default_nettype none

module seven_seg (
    input wire clk,
    input wire [31:0] data,
    output reg [7:0] anode,
    output reg [7:0] cathode
);
    reg [19:0] count = 0;
    wire [2:0] digit = count[19:17];
    reg [3:0] hex_val;

    always @(posedge clk) count <= count + 1;

    always @(*) begin
        case(digit)
            0: hex_val = data[3:0];   1: hex_val = data[7:4];
            2: hex_val = data[11:8];  3: hex_val = data[15:12];
            4: hex_val = data[19:16]; 5: hex_val = data[23:20];
            6: hex_val = data[27:24]; 7: hex_val = data[31:28];
        endcase
    end

    always @(*) begin
        case(hex_val)
            4'h0: cathode = 8'hC0; 4'h1: cathode = 8'hF9;
            4'h2: cathode = 8'hA4; 4'h3: cathode = 8'hB0;
            4'h4: cathode = 8'h99; 4'h5: cathode = 8'h92;
            4'h6: cathode = 8'h82; 4'h7: cathode = 8'hF8;
            4'h8: cathode = 8'h80; 4'h9: cathode = 8'h90;
            4'hA: cathode = 8'h88; 4'hB: cathode = 8'h83;
            4'hC: cathode = 8'hC6; 4'hD: cathode = 8'hA1;
            4'hE: cathode = 8'h86; 4'hF: cathode = 8'h8E;
        endcase
    end

    always @(*) begin
        anode = 8'hFF; 
        anode[digit] = 1'b0; 
    end
endmodule