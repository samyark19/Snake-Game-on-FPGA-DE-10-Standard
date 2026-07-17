`timescale 1ns / 1ns
`default_nettype none

`include "resolution.v"

module vga_demo (CLOCK_50, KEY, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, VGA_X, VGA_Y, VGA_COLOR, plot);

    parameter nX = `ifdef VGA_640_480 10 `elsif VGA_320_240 9 `else 8 `endif ; // VGA x bitwidth
    parameter nY = nX - 1;
    
    parameter COLS = `ifdef VGA_640_480 640 `elsif VGA_320_240 320 `else 160 `endif ;
    parameter ROWS = `ifdef VGA_640_480 480 `elsif VGA_320_240 240 `else 120 `endif ;

    input wire CLOCK_50;            // Clock 50 MHz
    input wire [3:0] KEY;           // Tombol (KEY[0] untuk reset)
    output wire [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0; 
    output wire [nX-1:0] VGA_X;     // Koordinat X
    output wire [nY-1:0] VGA_Y;     // Koordinat Y
    output wire [23:0] VGA_COLOR;   // Warna 24-bit
    output wire plot;               // Sinyal gambar (selalu 1)

    wire Resetn;
    assign Resetn = KEY[0];

    reg [nX-1:0] x_reg;
    reg [nY-1:0] y_reg;

    // Logika Pemindaian Layar (Scanning)
    always @(posedge CLOCK_50) begin
        if (Resetn == 0) begin
            x_reg <= 'b0;
            y_reg <= 'b0;
        end
        else begin
            if (x_reg < COLS - 1) begin
                x_reg <= x_reg + 1'b1;
            end
            else begin
                x_reg <= 'b0;
                if (y_reg < ROWS - 1)
                    y_reg <= y_reg + 1'b1;
                else
                    y_reg <= 'b0;
            end
        end
    end

    assign VGA_COLOR = (y_reg < (ROWS >> 1)) ? 24'hFF0000 : 24'hFFFFFF;

    assign VGA_X = x_reg;
    assign VGA_Y = y_reg;
    assign plot = 1'b1;

    assign HEX0 = 7'b1111111;
    assign HEX1 = 7'b1111111;
    assign HEX2 = 7'b1111111;
    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;

endmodule
