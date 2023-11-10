
//Be careful with port names, Verilog is case sensitive
module KeyboardToRS232(
    input wire PS2_DAT,        // PS/2 data pin
    input wire PS2_CLK,        // PS/2 clock pin
	 
	 //Baud Rate is 115200, 8 data bits, no parity check bit, 1 stop bit, flow control on
	 //MAX232 Transceiver Chip
	 input wire UART_RXD,       // Reciever 
	 output wire UART_TXD,      // Transmitter
	 
    input wire CLOCK_50,       // 50 MHz system clock
    output wire [9:0] LEDR,    // Red LEDs output (10 bits)
    output wire [7:0] LEDG,    // Green LEDs output (8 bits)
    output wire [6:0] HEX0     // 7-segment hex display
);

// UART parameters
parameter BAUD_RATE = 115200;
parameter DATA_BITS = 8;
parameter STOP_BITS = 1;
parameter START_BITS = 1;
parameter UART_CLK_DIVIDER = 50_000_000 / (BAUD_RATE + 1); // Calculate clock divider for baud rate

// UART transmitter signals
reg [DATA_BITS + START_BITS + STOP_BITS - 1:0] tx_data; // Data to transmit with start and stop bits
reg tx_valid; // Signal that data is valid
reg tx_busy;  // Transmitter is busy
reg [2:0] tx_state; // Transmitter state
reg [7:0] tx_shift_reg;        // Shift register for transmitting data

reg [10:0] shift_reg = 11'b00000000000; // Shift register
reg inverted_ps2_clock;                 // Inverted PS/2 clock signal
reg [10:0] synchronized_shift_reg;      // Shift register content synchronized with the system clock
reg [6:0] decoded_scan_code;            // Register to signal tap off of
reg [7:0] binary_scan_code;             // Register to signal tap off of

// Function to decode the 11-bit scan code
function [6:0] decoder_code;
    input [10:0] code;
    begin
        case(code)
            // Top Row Of Numbers
            11'b01010001001: decoder_code = 7'b1000000; // 0
            11'b00110100001: decoder_code = 7'b1111001; // 1
            11'b00111100011: decoder_code = 7'b0100100; // 2
            11'b00110010001: decoder_code = 7'b0110000; // 3
            11'b01010010001: decoder_code = 7'b0011001; // 4
            11'b00111010011: decoder_code = 7'b0010010; // 5
            11'b00110110011: decoder_code = 7'b0000010; // 6
            11'b01011110001: decoder_code = 7'b1111000; // 7
            11'b00111110001: decoder_code = 7'b0000000; // 8
            11'b00110001001: decoder_code = 7'b0010000; // 9

            // Key Pad
            11'b00000111001: decoder_code = 7'b1000000; // 0
            11'b01001011011: decoder_code = 7'b1111001; // 1
            11'b00100111011: decoder_code = 7'b0100100; // 2
            11'b00101111001: decoder_code = 7'b0110000; // 3
            11'b01101011001: decoder_code = 7'b0011001; // 4
            11'b01100111001: decoder_code = 7'b0010010; // 5
            11'b00010111011: decoder_code = 7'b0000010; // 6
            11'b00011011011: decoder_code = 7'b1111000; // 7
            11'b01010111001: decoder_code = 7'b0000000; // 8
            11'b01011111011: decoder_code = 7'b0010000; // 9
            default: decoder_code = 7'b1111111; // Default (blank display)
        endcase
    end
endfunction

// Function to convert decoded to binary
function [7:0] binary_converter;
    input [10:0] code;
    begin
        case(code)
            // Top Row Of Numbers
            11'b01010001001: binary_converter = 8'b00000000; // 0
            11'b00110100001: binary_converter = 8'b00000001; // 1
            11'b00111100011: binary_converter = 8'b00000010; // 2
            11'b00110010001: binary_converter = 8'b00000011; // 3
            11'b01010010001: binary_converter = 8'b00000100; // 4
            11'b00111010011: binary_converter = 8'b00000101; // 5
            11'b00110110011: binary_converter = 8'b00000110; // 6
            11'b01011110001: binary_converter = 8'b00000111; // 7
            11'b00111110001: binary_converter = 8'b00001000; // 8
            11'b00110001001: binary_converter = 8'b00001001; // 9

            // Key Pad
            11'b00000111001: binary_converter = 8'b00000000; // 0
            11'b01001011011: binary_converter = 8'b00000001; // 1
            11'b00100111011: binary_converter = 8'b00000010; // 2
            11'b00101111001: binary_converter = 8'b00000011; // 3
            11'b01101011001: binary_converter = 8'b00000100; // 4
            11'b01100111001: binary_converter = 8'b00000101; // 5
            11'b00010111011: binary_converter = 8'b00000110; // 6
            11'b00011011011: binary_converter = 8'b00000111; // 7
            11'b01010111001: binary_converter = 8'b00001000; // 8
            11'b01011111011: binary_converter = 8'b00001001; // 9
            default: binary_converter = 8'b00000000; // Default (0)
        endcase
    end
endfunction

// Initialize signals
initial begin
    tx_data = {1'b0, 8'b0, 1'b1}; // Initial idle state (marking condition)
    tx_valid = 0;
    tx_busy = 0;
    tx_state = 3'b000; // Initial state
    tx_shift_reg = 8'hFF; // Idle state
end

// UART transmitter state machine
always @(posedge CLOCK_50) begin
    case (tx_state)
        2'b00: begin // Idle state (marking condition)
            if (tx_valid) begin
                tx_shift_reg = {1'b0, tx_data, 1'b1}; // Start bit, data, stop bit
                tx_state = 2'b01; // Move to the start bit state
            end
        end

        2'b01: begin // Transmit start bit
            tx_shift_reg = {1'b0, tx_shift_reg[7:1]}; // Shift the data
            tx_state = 2'b10; // Move to the data bit state
        end

        2'b10: begin // Transmit data bits
            tx_shift_reg = {1'b0, tx_shift_reg[7:1]}; // Shift the data
            if (tx_shift_reg[0]) begin
                tx_state = 2'b11; // Move to the stop bit state
            end
        end

        2'b11: begin // Transmit stop bit
            tx_shift_reg = 8'hFF; // Restore to idle state (marking condition)
            tx_state = 2'b00; // Move back to the idle state
            tx_valid = 0; // Data transmission is complete
        end
    endcase
end

// Connect UART_TXD to the most significant bit of tx_data
assign UART_TXD = tx_data[DATA_BITS + START_BITS + STOP_BITS - 1]; // Sends full bits needed for UART

// Update the transmitter control signals with the data you want to send
always @(posedge CLOCK_50) begin
    // && key pressed event
    if (!tx_busy) begin
        tx_data = {1'b0, binary_converter(synchronized_shift_reg), 1'b1}; // Include start and stop bits + Assigning binary conversion to data bits
        tx_busy = 1; // Signal that the transmitter is busy
    end
end

always @(posedge CLOCK_50) begin
    inverted_ps2_clock <= ~PS2_CLK; // Invert the PS/2 clock signal on the rising edge of the 50 MHz clock
end

always @(posedge inverted_ps2_clock) begin
    shift_reg <= {shift_reg[9:0], PS2_DAT}; // Shift and concatenate new data bit on the inverted PS/2 clock's rising edge
end

always @(posedge CLOCK_50) begin
    synchronized_shift_reg <= shift_reg; // Capture the shift register's content on the rising edge of the 50 MHz system clock
	 decoded_scan_code <= decoder_code(synchronized_shift_reg);
	 binary_scan_code <= binary_converter(synchronized_shift_reg);
end

assign LEDR = synchronized_shift_reg[9:0]; // Output the first 10 bits of the synchronized data to the red LEDs
assign LEDG[7] = synchronized_shift_reg[10]; // Output the 11th bit to the green LED (ledg7)
assign HEX0 = decoder_code(synchronized_shift_reg); // Decode the 11-bit scan code and display on the rightmost 7-segment hex display

endmodule
