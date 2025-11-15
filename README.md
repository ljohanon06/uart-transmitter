# uart-transmitter
UART transmitter and receiver supporting custom baud rates and parity types. Uses verilog and runs on FPGAs.

2nd Verilog project so be kind please.

Included in the verilog files are two modules, transmitter and receiver. 
Both modules take baud rate, parity type, and number of stop bits as parameters. 
They are capable of transmitting 1 byte/8 bits of data per packet.
Both modules take a 50MHz clock as input and work on the rising edge, clock speed must be changed in the code itself.

Parameters:
BAUD: The baud rate of the code, must be less than clock speed. Default is 9600.
      Baud rates of 10,000,000 were tested to run cleanly. 
      Uses integer division of clock speed (50,000,000) / baud rate to make counter.

PARITY_TYPE: The parity type of the packet. 0-None, 1-Even, 2-Odd.
             Parities outside of this range go to default value of None.
             Error is flagged in receiver if parity doesn't match.

STOP: The number of stop bits, 0-1 stop bit, 1-2 stop bits. Default is 1 stop bit


Transmitter Ports:
clk: 50 MHz clock signal, works on rising edge of clock.
data: 8 bit data line, send from lsb to msb.
send: Send signal, works on **rising** edge of send, rising edge must not rise then fall between 1 clock cycle(20ns)
out: Serial data line out, idles high.
sending: Is high while transmitting data, from rising edge of send(start bit starts), to end of last stop bit.

Receiver Ports:
clk: 50 MHz clock signal, works on rising edge of clock.
in: Serial data line in, transmission is detected on start bit(input low), sampled every clock cycle.
    In is read at the center of where each expected data bit is.
data_out: 8 bit data out
received: Once data transmission is recieved, send a **rising** edge on this line. 
          Recieved is set to low whenever packet detected, set to high after last stop bit finishes.
          Recieved still sends a rising edge even if an error is detected.
error: Sends a **rising** edge if an error is detected in the parity bit or a stop bit.


Example Usage:
I was using a DE10-Lite board with an Altera MAX 10 FPGA on it for running and testing.
The following is my example testing code with GPIO 0 and GPIO 1 connected with a jumper cable.

transmitter #(.BAUD(20), .PARITY_TYPE(1), .STOP(0)) tx 
	(
		.data (SW[7:0]),
		.clk (MAX10_CLK1_50),
		.send (~KEY[0]),
		.out (GPIO[0])
	);
	
receiver #(.BAUD(20), .PARITY_TYPE(1), .STOP(0)) rx
	(
		.in (GPIO[1]),
		.clk (MAX10_CLK1_50),
		.data_out (LEDR[7:0]),
		.received(LEDR[8]),
		.error(LEDR[9])
	);

I used SW[7:0] as inputs, a button KEY[0] as my rising edge send input, and LEDR[7:0] as outputs.
Error was connected to LEDR[9], and recieved to LEDR[8].
This has a baud rate of 20 bits/s, even parity, and 1 stop bit.
