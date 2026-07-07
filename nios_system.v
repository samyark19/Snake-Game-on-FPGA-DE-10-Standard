module nios_system (
    input  wire        clk_clk,
    input  wire        reset_reset_n,
    output wire [1:0]  snake_dir_export,
    output wire        snake_dir_override_en_export,
    input  wire        snake_game_over_export,
    input  wire [3:0]  snake_level_in_port,
    output wire [3:0]  snake_level_out_port,
    input  wire [7:0]  snake_ps2_last_code_export,
    output wire        snake_rainbow_mode_export,
    input  wire [15:0] snake_score_bcd_export
);

assign snake_dir_export = 2'b00;
assign snake_dir_override_en_export = 1'b0;
assign snake_level_out_port = 4'b0000;
assign snake_rainbow_mode_export = 1'b0;

endmodule