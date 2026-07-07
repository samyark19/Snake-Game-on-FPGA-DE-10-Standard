module ps2_keyboard (
    input        CLOCK_50,
    input        PS2_CLK,
    input        PS2_DAT,
    output reg [7:0] scan_code = 8'h00,
    output reg       scan_ready = 1'b0,
    output reg       extended = 1'b0,
    output reg       break_code = 1'b0
);

    // Sinkronisasi 3-stage untuk menghindari metastability
    reg [2:0] clk_sync = 3'b111;
    reg [2:0] dat_sync = 3'b111;

    // Deteksi falling edge PS2_CLK
    wire falling_edge = (clk_sync[2:1] == 2'b10);

    // Register geser 11-bit dan penghitung bit
    reg [10:0] shift_reg = 11'h7FF;   // inisialisasi stop bit = 1
    reg [3:0]  bit_count = 4'd0;

    // Flag sementara
    reg ext_flag = 1'b0;
    reg brk_flag = 1'b0;

    always @(posedge CLOCK_50) begin
        // Sinkronisasi input
        clk_sync <= {clk_sync[1:0], PS2_CLK};
        dat_sync <= {dat_sync[1:0], PS2_DAT};

        // Default output
        scan_ready <= 1'b0;

        if (falling_edge) begin
            // Geser data masuk (LSB dulu)
            shift_reg <= {dat_sync[2], shift_reg[10:1]};

            if (bit_count == 4'd10) begin
                // Selesai menerima 11 bit
                bit_count <= 4'd0;

                // Hanya cek start bit (0) dan stop bit (1)
                if (shift_reg[0] == 1'b0 && shift_reg[10] == 1'b1) begin
                    // Ambil byte data
                    case (shift_reg[8:1])
                        8'hE0: ext_flag <= 1'b1;
                        8'hF0: brk_flag <= 1'b1;
                        default: begin
                            scan_code <= shift_reg[8:1];
                            extended  <= ext_flag;
                            break_code <= brk_flag;
                            scan_ready <= 1'b1;
                            ext_flag <= 1'b0;
                            brk_flag <= 1'b0;
                        end
                    endcase
                end
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end
    end

endmodule