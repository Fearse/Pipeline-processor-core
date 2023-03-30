`timescale 1ns / 1ps

module test();

reg clk, reset;
wire [9:0] pc;

always #5 clk <= ~clk;

initial begin
    clk = 0;
    reset = 0;
end

cpu_conv3 cpu_conv3(
    .clk_in(clk), 
    .reset(reset), 
    .pc(pc)
);

endmodule
