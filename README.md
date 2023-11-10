# PS-2-DSP-Interfaced-To-Python-Terasic-DE1-Altera-Development-Board-With-RS-232-To-USB-Output
Digital Signal Processing of PS/2 signals through Verilog. Processed data sent to Python via RS-232 to USB protocol conversion for the Terasic DE1 Altera Development Board.

Provided is the Quartus II project files, Verilog file to be included in the project, and the pin assignments needed to run the code properly on the board.

"KeyboardToRS232" is the main file.

"RS-232 Interface.py" is a Python file included (using PySerial) which allows you to read the data coming from the RS-232 port on the FPGA board, assuming you have a RS-232 to USB converter.
