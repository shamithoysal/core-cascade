`default_nettype none

module color_mapper (
    input wire [7:0] iter_count,
    output reg [11:0] vga_color 
);
    always_comb begin
        if (iter_count == 8'hFF) begin 
            vga_color = 12'h000; 
        end else begin
            vga_color = {iter_count[7:4], iter_count[3:0], iter_count[7:4]};
        end
    end
endmodule