module Top (
    input              CLOCK_50,
    input      [9:0]   SW,
    input      [3:0]   KEY,
    inout              PS2_CLK,
    inout              PS2_DAT,
    output     [6:0]   HEX0,
    output     [6:0]   HEX1,
    output     [6:0]   HEX2,
    output     [6:0]   HEX3,
    output     [6:0]   HEX4,
    output     [6:0]   HEX5,
    output     [7:0]   VGA_R,
    output     [7:0]   VGA_G,
    output     [7:0]   VGA_B,
    output             VGA_HS,
    output             VGA_VS,
    output             VGA_CLK,
    output             VGA_BLANK_N,
    output             VGA_SYNC_N
);

    localparam H_ACTIVE = 10'd640;
    localparam H_FRONT  = 10'd16;
    localparam H_SYNC   = 10'd96;
    localparam H_BACK   = 10'd48;
    localparam H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;

    localparam V_ACTIVE = 10'd480;
    localparam V_FRONT  = 10'd10;
    localparam V_SYNC   = 10'd2;
    localparam V_BACK   = 10'd33;
    localparam V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

    reg pixel_clk_div = 1'b0;
    reg [9:0] h_count = 10'd0;
    reg [9:0] v_count = 10'd0;

    wire pixel_tick = pixel_clk_div;
    wire active_video = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    wire [8:0] draw_x = h_count[9:2];
    wire [7:0] draw_y = v_count[8:2];
    wire frame_tick = pixel_tick && (h_count == H_TOTAL - 1) && (v_count == V_TOTAL - 1);
    wire ps2_clk_in = PS2_CLK;
    wire ps2_dat_in = PS2_DAT;
    wire nios_rainbow_mode;
    wire nios_dir_override_en;
    wire [1:0] nios_dir;
    wire [3:0] nios_level_unused;

    assign PS2_CLK = 1'bz;
    assign PS2_DAT = 1'bz;

    assign VGA_CLK = pixel_clk_div;
    assign VGA_HS = ~((h_count >= H_ACTIVE + H_FRONT) &&
                      (h_count <  H_ACTIVE + H_FRONT + H_SYNC));
    assign VGA_VS = ~((v_count >= V_ACTIVE + V_FRONT) &&
                      (v_count <  V_ACTIVE + V_FRONT + V_SYNC));
    assign VGA_BLANK_N = active_video;
    assign VGA_SYNC_N = 1'b0;

    always @(posedge CLOCK_50) begin
        pixel_clk_div <= ~pixel_clk_div;

        if (pixel_tick) begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    reg [3:0] score_d0 = 0;
    reg [3:0] score_d1 = 0;
    reg [3:0] score_d2 = 0;
    reg [3:0] score_d3 = 0;
    wire [15:0] packed_score = {score_d3, score_d2, score_d1, score_d0};

    wire is_lvl2 = (score_d1 >= 5 || score_d2 > 0 || score_d3 > 0);
    localparam [3:0] LEVEL1_FRAME_DIV = 4'd8;
    localparam [3:0] LEVEL2_FRAME_DIV = 4'd5;
    wire [3:0] speed_threshold = is_lvl2 ? LEVEL2_FRAME_DIV : LEVEL1_FRAME_DIV;

    reg [3:0] frame_div_cnt = 4'd0;
    wire tick = frame_tick && (frame_div_cnt == speed_threshold - 1'b1);

    always @(posedge CLOCK_50) begin
        if (game_over) begin
            frame_div_cnt <= 4'd0;
        end else if (frame_tick) begin
            if (frame_div_cnt == speed_threshold - 1'b1)
                frame_div_cnt <= 4'd0;
            else
                frame_div_cnt <= frame_div_cnt + 1'b1;
        end
    end

    reg [1:0] dir = 2'd3;
    reg [8:0] h_x = 64;
    reg [7:0] h_y = 64;
    wire game_over;
    localparam [7:0] PS2_UP_ARROW    = 8'h75;
    localparam [7:0] PS2_DOWN_ARROW  = 8'h72;
    localparam [7:0] PS2_LEFT_ARROW  = 8'h6B;
    localparam [7:0] PS2_RIGHT_ARROW = 8'h74;
    wire [7:0] ps2_scan_code;
    wire ps2_scan_ready;
    wire ps2_scan_extended;
    wire ps2_scan_break;
    reg [1:0] ps2_dir = 2'd3;
    reg ps2_dir_valid = 1'b0;
    wire [3:0] current_lvl = is_lvl2 ? 4'd2 : 4'd1;
    wire rainbow_mode = SW[9] | nios_rainbow_mode;

    ps2_keyboard ps2_kbd (
        .CLOCK_50(CLOCK_50),
        .PS2_CLK(ps2_clk_in),
        .PS2_DAT(ps2_dat_in),
        .scan_code(ps2_scan_code),
        .scan_ready(ps2_scan_ready),
        .extended(ps2_scan_extended),
        .break_code(ps2_scan_break)
    );

    nios_system nios_sys (
        .clk_clk(CLOCK_50),
        .reset_reset_n(1'b1),
        .snake_dir_export(nios_dir),
        .snake_dir_override_en_export(nios_dir_override_en),
        .snake_game_over_export(game_over),
        .snake_level_in_port(current_lvl),
        .snake_level_out_port(nios_level_unused),
        .snake_ps2_last_code_export(ps2_scan_code),
        .snake_rainbow_mode_export(nios_rainbow_mode),
        .snake_score_bcd_export(packed_score)
    );

    always @(posedge CLOCK_50) begin
        ps2_dir_valid <= 1'b0;
        if (ps2_scan_ready && !ps2_scan_break) begin
            case (ps2_scan_code)
                8'h75: begin ps2_dir <= 2'd0; ps2_dir_valid <= 1'b1; end
                8'h72: begin ps2_dir <= 2'd1; ps2_dir_valid <= 1'b1; end
                8'h6B: begin ps2_dir <= 2'd2; ps2_dir_valid <= 1'b1; end
                8'h74: begin ps2_dir <= 2'd3; ps2_dir_valid <= 1'b1; end
                default: ;
            endcase
        end
    end

    assign game_over = tick && (
        (dir == 2'd0 && h_y <= 32)  ||
        (dir == 2'd1 && h_y >= 104) ||
        (dir == 2'd2 && h_x <= 8)   ||
        (dir == 2'd3 && h_x >= 144)
    );

    reg [4:0] rand_x = 1;
    reg [3:0] rand_y = 4;

    always @(posedge CLOCK_50) begin
        if (rand_x >= 18) begin
            rand_x <= 1;
            if (rand_y >= 13)
                rand_y <= 4;
            else
                rand_y <= rand_y + 1;
        end else begin
            rand_x <= rand_x + 1;
        end
    end

    reg [8:0] food_x = 112;
    reg [7:0] food_y = 48;
    wire snake_eat = tick && (h_x == food_x) && (h_y == food_y);

    always @(posedge CLOCK_50) begin
        if (game_over) begin
            food_x <= 112;
            food_y <= 48;
            score_d0 <= 0;
            score_d1 <= 0;
            score_d2 <= 0;
            score_d3 <= 0;
        end else if (snake_eat) begin
            food_x <= rand_x * 8;
            food_y <= rand_y * 8;
            if (score_d1 == 9) begin
                score_d1 <= 0;
                if (score_d2 == 9) begin
                    score_d2 <= 0;
                    score_d3 <= (score_d3 == 9) ? 0 : score_d3 + 1;
                end else begin
                    score_d2 <= score_d2 + 1;
                end
            end else begin
                score_d1 <= score_d1 + 1;
            end
        end
    end

    function [6:0] bcd2seg;
        input [3:0] bcd;
        begin
            case (bcd)
                4'd0: bcd2seg = 7'b1000000;
                4'd1: bcd2seg = 7'b1111001;
                4'd2: bcd2seg = 7'b0100100;
                4'd3: bcd2seg = 7'b0110000;
                4'd4: bcd2seg = 7'b0011001;
                4'd5: bcd2seg = 7'b0010010;
                4'd6: bcd2seg = 7'b0000010;
                4'd7: bcd2seg = 7'b1111000;
                4'd8: bcd2seg = 7'b0000000;
                4'd9: bcd2seg = 7'b0010000;
                default: bcd2seg = 7'b1111111;
            endcase
        end
    endfunction

    assign HEX0 = bcd2seg(score_d0);
    assign HEX1 = bcd2seg(score_d1);
    assign HEX2 = bcd2seg(score_d2);
    assign HEX3 = bcd2seg(score_d3);
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;

    reg [8:0] b1_x = 56;
    reg [7:0] b1_y = 64;
    reg [8:0] b2_x = 56;
    reg [7:0] b2_y = 72;
    reg [8:0] b3_x = 48;
    reg [7:0] b3_y = 72;

    always @(posedge CLOCK_50) begin
        if (game_over) begin
            dir <= 2'd3;
            h_x <= 64;
            h_y <= 64;
            b1_x <= 56; b1_y <= 64;
            b2_x <= 56; b2_y <= 72;
            b3_x <= 48; b3_y <= 72;
        end else begin
            if (nios_dir_override_en)
                dir <= nios_dir;
            else if (ps2_dir_valid)
                dir <= ps2_dir;
            else if (!KEY[3])
                dir <= 2'd0;
            else if (!KEY[0])
                dir <= 2'd1;
            else if (!KEY[2])
                dir <= 2'd2;
            else if (!KEY[1])
                dir <= 2'd3;

            if (tick) begin
                b3_x <= b2_x; b3_y <= b2_y;
                b2_x <= b1_x; b2_y <= b1_y;
                b1_x <= h_x;  b1_y <= h_y;
                case (dir)
                    2'd0: h_y <= h_y - 8;
                    2'd1: h_y <= h_y + 8;
                    2'd2: h_x <= h_x - 8;
                    2'd3: h_x <= h_x + 8;
                endcase
            end
        end
    end

    wire [3:0] cur_digit =
        (draw_x >= 10 && draw_x <= 16) ? score_d3 :
        (draw_x >= 20 && draw_x <= 26) ? score_d2 :
        (draw_x >= 30 && draw_x <= 36) ? score_d1 :
        (draw_x >= 40 && draw_x <= 46) ? score_d0 : 4'd15;

    wire [8:0] dx =
        (draw_x >= 10 && draw_x <= 16) ? draw_x - 10 :
        (draw_x >= 20 && draw_x <= 26) ? draw_x - 20 :
        (draw_x >= 30 && draw_x <= 36) ? draw_x - 30 :
        (draw_x >= 40 && draw_x <= 46) ? draw_x - 40 : 9'd500;

    wire [7:0] dy = draw_y - 2;

    wire segA = (dx <= 6) && (dy <= 2);
    wire segB = (dx >= 4 && dx <= 6 && dy <= 6);
    wire segC = (dx >= 4 && dx <= 6 && dy >= 6 && dy <= 12);
    wire segD = (dx <= 6 && dy >= 10 && dy <= 12);
    wire segE = (dx <= 2 && dy >= 6 && dy <= 12);
    wire segF = (dx <= 2 && dy <= 6);
    wire segG = (dx <= 6 && dy >= 5 && dy <= 7);

    wire digit_pixel =
        (cur_digit == 0) ? (segA | segB | segC | segD | segE | segF) :
        (cur_digit == 1) ? (segB | segC) :
        (cur_digit == 2) ? (segA | segB | segG | segE | segD) :
        (cur_digit == 3) ? (segA | segB | segG | segC | segD) :
        (cur_digit == 4) ? (segF | segG | segB | segC) :
        (cur_digit == 5) ? (segA | segF | segG | segC | segD) :
        (cur_digit == 6) ? (segA | segF | segE | segD | segC | segG) :
        (cur_digit == 7) ? (segA | segB | segC) :
        (cur_digit == 8) ? (segA | segB | segC | segD | segE | segF | segG) :
        (cur_digit == 9) ? (segA | segB | segC | segD | segF | segG) : 1'b0;

    reg [8:0] pixel_color;
    reg [8:0] rel_x;
    reg [7:0] rel_y;

    always @(*) begin
        pixel_color = 9'b110_111_100;
        rel_x = 9'd0;
        rel_y = 8'd0;

        if (rainbow_mode) begin
            if (draw_x < 23)
                pixel_color = 9'b111_000_000;
            else if (draw_x < 46)
                pixel_color = 9'b111_100_000;
            else if (draw_x < 69)
                pixel_color = 9'b111_111_000;
            else if (draw_x < 92)
                pixel_color = 9'b000_111_000;
            else if (draw_x < 115)
                pixel_color = 9'b000_111_111;
            else if (draw_x < 138)
                pixel_color = 9'b000_000_111;
            else
                pixel_color = 9'b111_000_111;
        end else begin
            if (draw_y >= 2 && draw_y <= 14 && cur_digit != 15 && digit_pixel) begin
                pixel_color = 9'b000_000_000;
            end else if (draw_y >= 2 && draw_y <= 14 && draw_x >= 60 && draw_x <= 116) begin
                // Menampilkan "LEVEL" + angka level
                // Slot: L(60-66), E(70-76), V(80-86), E(90-96), L(100-106), angka(110-116)
                rel_x = (draw_x >= 60 && draw_x <= 66) ? draw_x - 60 :
                        (draw_x >= 70 && draw_x <= 76) ? draw_x - 70 :
                        (draw_x >= 80 && draw_x <= 86) ? draw_x - 80 :
                        (draw_x >= 90 && draw_x <= 96) ? draw_x - 90 :
                        (draw_x >= 100 && draw_x <= 106) ? draw_x - 100 :
                        (draw_x >= 110 && draw_x <= 116) ? draw_x - 110 : 9'd500;
                rel_y = draw_y - 2;

                // Huruf L pertama (60-66)
                if (draw_x >= 60 && draw_x <= 66) begin
                    if ((rel_x <= 2) || (rel_y >= 10))
                        pixel_color = 9'b000_000_000;
                end
                // Huruf E pertama (70-76)
                else if (draw_x >= 70 && draw_x <= 76) begin
                    if ((rel_x <= 1) || (rel_y <= 1) || (rel_y >= 5 && rel_y <= 6) || (rel_y >= 10))
                        pixel_color = 9'b000_000_000;
                end
                // Huruf V (80-86) -- menggunakan metode yang sudah terbukti benar
                else if (draw_x >= 80 && draw_x <= 86) begin
                    if ((rel_x <= 1 && rel_y <= 8) ||
                        (rel_x >= 5 && rel_y <= 8) ||
                        (rel_y >= 10))
                        pixel_color = 9'b000_000_000;
                end
                // Huruf E kedua (90-96)
                else if (draw_x >= 90 && draw_x <= 96) begin
                    if ((rel_x <= 1) || (rel_y <= 1) || (rel_y >= 5 && rel_y <= 6) || (rel_y >= 10))
                        pixel_color = 9'b000_000_000;
                end
                // Huruf L kedua (100-106)
                else if (draw_x >= 100 && draw_x <= 106) begin
                    if ((rel_x <= 2) || (rel_y >= 10))
                        pixel_color = 9'b000_000_000;
                end
                // Angka level (110-116)
                else if (draw_x >= 110 && draw_x <= 116) begin
                    if (current_lvl == 1) begin
                        if (rel_x >= 4)
                            pixel_color = 9'b000_000_000;
                    end else begin
                        if ((rel_y <= 2) || (rel_y >= 10) ||
                            (rel_y >= 5 && rel_y <= 7) ||
                            (rel_x >= 4 && rel_y <= 5) ||
                            (rel_x <= 2 && rel_y >= 7))
                            pixel_color = 9'b000_000_000;
                    end
                end
            end else if (draw_y >= 18 && draw_y <= 19 &&
                         draw_x >= 4 && draw_x <= 155) begin
                pixel_color = 9'b000_000_000;
            end else if ((draw_y >= 24 && draw_y < 32) ||
                         (draw_y >= 112 && draw_y < 120) ||
                         (draw_x < 8 && draw_y >= 24 && draw_y < 120) ||
                         (draw_x >= 152 && draw_y >= 24 && draw_y < 120)) begin
                pixel_color = 9'b000_000_000;
            end else if (draw_x >= h_x && draw_x < h_x + 8 &&
                         draw_y >= h_y && draw_y < h_y + 8) begin
                rel_x = draw_x - h_x;
                rel_y = draw_y - h_y;
                if ((rel_x == 0 && rel_y == 0) || (rel_x == 7 && rel_y == 0) ||
                    (rel_x == 0 && rel_y == 7) || (rel_x == 7 && rel_y == 7)) begin
                    pixel_color = 9'b110_111_100;
                end else begin
                    pixel_color = 9'b000_000_000;
                    if (dir == 2'd3 && (rel_x == 5 || rel_x == 6) &&
                        (rel_y == 2 || rel_y == 5))
                        pixel_color = 9'b110_111_100;
                    else if (dir == 2'd2 && (rel_x == 1 || rel_x == 2) &&
                             (rel_y == 2 || rel_y == 5))
                        pixel_color = 9'b110_111_100;
                    else if (dir == 2'd0 && (rel_y == 1 || rel_y == 2) &&
                             (rel_x == 2 || rel_x == 5))
                        pixel_color = 9'b110_111_100;
                    else if (dir == 2'd1 && (rel_y == 5 || rel_y == 6) &&
                             (rel_x == 2 || rel_x == 5))
                        pixel_color = 9'b110_111_100;
                end
            end else if (draw_x >= b1_x && draw_x < b1_x + 8 &&
                         draw_y >= b1_y && draw_y < b1_y + 8) begin
                pixel_color = 9'b000_000_000;
                rel_x = draw_x - b1_x;
                rel_y = draw_y - b1_y;
                if (rel_x >= 3 && rel_x <= 4 && rel_y >= 3 && rel_y <= 4)
                    pixel_color = 9'b110_111_100;
            end else if (draw_x >= b2_x && draw_x < b2_x + 8 &&
                         draw_y >= b2_y && draw_y < b2_y + 8) begin
                pixel_color = 9'b000_000_000;
                rel_x = draw_x - b2_x;
                rel_y = draw_y - b2_y;
                if (rel_x >= 3 && rel_x <= 4 && rel_y >= 3 && rel_y <= 4)
                    pixel_color = 9'b110_111_100;
            end else if (draw_x >= b3_x && draw_x < b3_x + 8 &&
                         draw_y >= b3_y && draw_y < b3_y + 8) begin
                pixel_color = 9'b000_000_000;
                rel_x = draw_x - b3_x;
                rel_y = draw_y - b3_y;
                if (rel_x >= 3 && rel_x <= 4 && rel_y >= 3 && rel_y <= 4)
                    pixel_color = 9'b110_111_100;
            end else if (draw_x >= food_x && draw_x < food_x + 8 &&
                         draw_y >= food_y && draw_y < food_y + 8) begin
                rel_x = draw_x - food_x;
                rel_y = draw_y - food_y;
                if ((rel_x == 0 && rel_y == 0) || (rel_x == 7 && rel_y == 0) ||
                    (rel_x == 0 && rel_y == 7) || (rel_x == 7 && rel_y == 7)) begin
                    pixel_color = 9'b110_111_100;
                end else begin
                    pixel_color = 9'b000_000_000;
                    if (rel_x >= 3 && rel_x <= 4 && rel_y >= 3 && rel_y <= 4)
                        pixel_color = 9'b110_111_100;
                end
            end
        end
    end

    function [7:0] expand3to8;
        input [2:0] c;
        begin
            expand3to8 = {c, c, c[2:1]};
        end
    endfunction

    wire [8:0] visible_color = active_video ? pixel_color : 9'b000_000_000;

    assign VGA_R = expand3to8(visible_color[8:6]);
    assign VGA_G = expand3to8(visible_color[5:3]);
    assign VGA_B = expand3to8(visible_color[2:0]);

endmodule