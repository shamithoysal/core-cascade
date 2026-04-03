set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }];

set_property -dict { PACKAGE_PIN U9    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN U8    IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN R7    IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN R6    IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];
set_property -dict { PACKAGE_PIN R5    IOSTANDARD LVCMOS33 } [get_ports { sw[4] }];
set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { sw[5] }];
set_property -dict { PACKAGE_PIN V6    IOSTANDARD LVCMOS33 } [get_ports { sw[6] }];
set_property -dict { PACKAGE_PIN V5    IOSTANDARD LVCMOS33 } [get_ports { sw[7] }];
set_property -dict { PACKAGE_PIN U4    IOSTANDARD LVCMOS33 } [get_ports { sw[8] }];
set_property -dict { PACKAGE_PIN V2    IOSTANDARD LVCMOS33 } [get_ports { sw[9] }];
set_property -dict { PACKAGE_PIN U2    IOSTANDARD LVCMOS33 } [get_ports { sw[10] }];
set_property -dict { PACKAGE_PIN T3    IOSTANDARD LVCMOS33 } [get_ports { sw[11] }];
set_property -dict { PACKAGE_PIN T1    IOSTANDARD LVCMOS33 } [get_ports { sw[12] }];
set_property -dict { PACKAGE_PIN R3    IOSTANDARD LVCMOS33 } [get_ports { sw[13] }];
set_property -dict { PACKAGE_PIN P3    IOSTANDARD LVCMOS33 } [get_ports { sw[14] }];
set_property -dict { PACKAGE_PIN P4    IOSTANDARD LVCMOS33 } [get_ports { sw[15] }];

set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { btnC }];
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { btnU }];
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { btnD }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { btnL }];
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { btnR }];

set_property -dict { PACKAGE_PIN T8    IOSTANDARD LVCMOS33 } [get_ports { led0 }];
set_property -dict { PACKAGE_PIN P5    IOSTANDARD LVCMOS33 } [get_ports { led14 }];
set_property -dict { PACKAGE_PIN U1    IOSTANDARD LVCMOS33 } [get_ports { led15 }];

set_property -dict { PACKAGE_PIN L3    IOSTANDARD LVCMOS33 } [get_ports { cathode[0] }]; 
set_property -dict { PACKAGE_PIN N1    IOSTANDARD LVCMOS33 } [get_ports { cathode[1] }]; 
set_property -dict { PACKAGE_PIN L5    IOSTANDARD LVCMOS33 } [get_ports { cathode[2] }]; 
set_property -dict { PACKAGE_PIN L4    IOSTANDARD LVCMOS33 } [get_ports { cathode[3] }]; 
set_property -dict { PACKAGE_PIN K3    IOSTANDARD LVCMOS33 } [get_ports { cathode[4] }]; 
set_property -dict { PACKAGE_PIN M2    IOSTANDARD LVCMOS33 } [get_ports { cathode[5] }]; 
set_property -dict { PACKAGE_PIN L6    IOSTANDARD LVCMOS33 } [get_ports { cathode[6] }]; 
set_property -dict { PACKAGE_PIN M4    IOSTANDARD LVCMOS33 } [get_ports { cathode[7] }]; 

set_property -dict { PACKAGE_PIN N6    IOSTANDARD LVCMOS33 } [get_ports { anode[0] }];
set_property -dict { PACKAGE_PIN M6    IOSTANDARD LVCMOS33 } [get_ports { anode[1] }];
set_property -dict { PACKAGE_PIN M3    IOSTANDARD LVCMOS33 } [get_ports { anode[2] }];
set_property -dict { PACKAGE_PIN N5    IOSTANDARD LVCMOS33 } [get_ports { anode[3] }];
set_property -dict { PACKAGE_PIN N2    IOSTANDARD LVCMOS33 } [get_ports { anode[4] }];
set_property -dict { PACKAGE_PIN N4    IOSTANDARD LVCMOS33 } [get_ports { anode[5] }];
set_property -dict { PACKAGE_PIN L1    IOSTANDARD LVCMOS33 } [get_ports { anode[6] }];
set_property -dict { PACKAGE_PIN M1    IOSTANDARD LVCMOS33 } [get_ports { anode[7] }];

set_property -dict { PACKAGE_PIN A3    IOSTANDARD LVCMOS33 } [get_ports { VGA_R[0] }];
set_property -dict { PACKAGE_PIN B4    IOSTANDARD LVCMOS33 } [get_ports { VGA_R[1] }];
set_property -dict { PACKAGE_PIN C5    IOSTANDARD LVCMOS33 } [get_ports { VGA_R[2] }];
set_property -dict { PACKAGE_PIN A4    IOSTANDARD LVCMOS33 } [get_ports { VGA_R[3] }];

set_property -dict { PACKAGE_PIN C6    IOSTANDARD LVCMOS33 } [get_ports { VGA_G[0] }];
set_property -dict { PACKAGE_PIN A5    IOSTANDARD LVCMOS33 } [get_ports { VGA_G[1] }];
set_property -dict { PACKAGE_PIN B6    IOSTANDARD LVCMOS33 } [get_ports { VGA_G[2] }];
set_property -dict { PACKAGE_PIN A6    IOSTANDARD LVCMOS33 } [get_ports { VGA_G[3] }];

set_property -dict { PACKAGE_PIN B7    IOSTANDARD LVCMOS33 } [get_ports { VGA_B[0] }];
set_property -dict { PACKAGE_PIN C7    IOSTANDARD LVCMOS33 } [get_ports { VGA_B[1] }];
set_property -dict { PACKAGE_PIN D7    IOSTANDARD LVCMOS33 } [get_ports { VGA_B[2] }];
set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { VGA_B[3] }];

set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { VGA_HS }];
set_property -dict { PACKAGE_PIN B12   IOSTANDARD LVCMOS33 } [get_ports { VGA_VS }];

set_clock_groups -asynchronous -group [get_clocks *clk_out1*] -group [get_clocks *clk_out2*]