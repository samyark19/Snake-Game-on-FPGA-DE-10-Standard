# 🐍 Snake Game on FPGA

A classic Snake game implemented on an FPGA development board using Verilog HDL.  
It outputs VGA 640x480 graphics, is controlled by a PS/2 keyboard, and displays the score on both 7-segment displays and on-screen.

## ✨ Features
- VGA 640×480 @ 60 Hz output
- PS/2 keyboard control (arrow keys) or onboard push‑button alternatives
- 4-digit BCD score on 7‑segment displays and on‑screen
- Two speed levels based on score
- Rainbow color mode via a switch
- Dummy NIOS II system to simplify synthesis

## 🛠️ Tools & Hardware
- **FPGA Board**: DE10‑Lite (MAX 10), DE1‑SoC (Cyclone V), or compatible
- **Software**: Intel Quartus Prime Lite Edition (25.1 or later)
- **Peripherals**: VGA monitor, PS/2 keyboard

## 🚀 How to Compile & Upload
1. Clone this repository
2. Open Quartus, then open `quartus/snake_game.qpf`
3. Add all `.v` files from the `src/` folder to the project if they are not automatically detected
4. Adjust the pin assignments in `snake_game.qsf` to match your board (default is for DE10‑Lite)
5. Compile (`Ctrl+L`)
6. Open the Programmer, select `output_files/snake_game.sof`, and program the board

## 🎮 Controls
| PS/2 Key   | Board KEY | Action |
|------------|-----------|--------|
| Up Arrow   | KEY[3]    | Up     |
| Down Arrow | KEY[0]    | Down   |
| Left Arrow | KEY[1]    | Left   |
| Right Arrow| KEY[2]    | Right  |
| SW[9]      | –         | Toggle rainbow mode |

## 📸 Screenshot
![Gameplay Screenshot](docs/screenshot.png)

## 📜 License
This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.
