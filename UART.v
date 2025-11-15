module transmitter #(parameter BAUD = 9600, parameter [1:0] PARITY_TYPE = 0, parameter STOP = 0) (data,send,clk,out,sending);
	localparam [27:0] BAUD_COUNT = 28'd50000000 / BAUD;
	localparam PARITY_ = (PARITY_TYPE > 2) ? 2'b0 : PARITY_TYPE; //0-No, 1-Even, 2-Odd
	localparam STOP_   = (STOP > 1) ? 1'b0 : STOP; //0-1 stop, 1-2 stops;
	
	localparam IDLE   = 4'd0;
	localparam START  = 4'd1;
	localparam B0     = 4'd2;
	localparam B7     = 4'd9;
	localparam PARITY = 4'd10;
	localparam STOP1  = 4'd11;
	localparam STOP2  = 4'd12;
	
	input [7:0] data;
	input send;
	input clk;
	output sending;
	output out;
	
	reg [3:0] state;
	reg parityTracker;
	reg prev_send;
	reg [27:0] baud_count;
	
	wire parity_out = (PARITY_ == 2'd1) ? parityTracker : ~parityTracker;
	wire data_out   = (state >= B0 && state <= B7) ? data[state - B0] : 1'b1;
	
	assign sending = state != IDLE;
	assign out = (state == START)                     ? 1'b0
				  : (state >= B0 && state <= B7)         ? data_out
				  : (state == PARITY && PARITY_ != 2'b0) ? parity_out
				  : 1'b1;
			
				  
	always @(posedge clk) begin
		//Rising Edge Detection for Send
		prev_send <= send;
		if(prev_send && !send && !sending) 
			state <= START;
		else if(baud_count == BAUD_COUNT) begin
			if(state ==  START) 
				parityTracker <=  1'b0;
			else parityTracker <= parityTracker ^ out; //Essentially adds the current bit
																	 //to the parity tracker			
			if(state == B7 && PARITY_ == 2'b0)
				state <= STOP1;
			else if(state == STOP1 && STOP_)
				state <= STOP2;
			else if(state == STOP1 || state == STOP2)
				state <= IDLE;
			else state <= state + 4'd1;
		end
		
		if(sending) begin
			if(baud_count == BAUD_COUNT)
				baud_count <= 28'd0;
			else baud_count <= baud_count + 1'b1;
		end else baud_count <= 28'd0;
	end
endmodule	


module receiver #(parameter BAUD = 9600, parameter [1:0] PARITY_TYPE = 0, parameter STOP = 0) (in,clk,data_out,received,error);
	localparam [27:0] BAUD_COUNT = 28'd50000000 / BAUD;
	localparam PARITY_ = (PARITY_TYPE > 2) ? 2'b0 : PARITY_TYPE; //0-No, 1-Even, 2-Odd
	localparam STOP_   = (STOP > 1) ? 1'b0 : STOP; //0-1 stop, 1-2 stops;
	
	localparam IDLE   		= 4'd0;
	localparam HALF_START    = 4'd1; //Half gap between low detected and measuring start bit
	localparam B0     		= 4'd2, B1 = 4'd3, B2 = 4'd4, B3 = 4'd5;
	localparam B4     		= 4'd6, B5 = 4'd7, B6 = 4'd8, B7 = 4'd9;
	localparam PARITY 		= 4'd10;
	localparam STOP1  		= 4'd11;
	localparam STOP2  		= 4'd12;
	localparam END_HALF     = 4'd13;
	
	input in;
	input clk;
	output reg [7:0] data_out;
	output reg received; //Stays on from end of reception til start of next reception
	output reg error;	  //Same as received
		
	reg [3:0] state;
	reg parityTracker;
	reg [26:0] gap_counter;
	reg [27:0] half_counter;
	
	wire recieving = state != IDLE;	
	wire expected_parity = (PARITY_ == 2'd1) ? parityTracker : ~parityTracker;

	wire expectedBit = (state == HALF_START)                ? 1'b0
				        : (state == PARITY && PARITY_ != 2'b0) ? expected_parity
				        : (state == STOP1 || state == STOP2)   ? 1'b1
						  : 1'b1; //Bits/Idle, won't be used
  
				  
	always @(posedge clk) begin
		if(!in && !recieving) begin
			state <= HALF_START;
			received <= 1'b0; //Reset Received and Error
			error <= 1'b0;
		end			
			
		if(half_counter == (BAUD_COUNT >> 1)) begin
			if(state == HALF_START) begin
				if(in != expectedBit) 
					state <= IDLE; //If the start bit isn't located, most likely due to low spike, no error
				else begin
					state <= B0;
					parityTracker <= 1'b0;
				end
			end
			else state <= IDLE; //state = END_HALF
		end
			
	
		if(gap_counter == BAUD_COUNT) begin
			case(state)
				B0,B1,B2,B3,B4,B5,B6: begin
							parityTracker <= parityTracker ^ in; //Adds current bit to parityTracker
							data_out <= {in, data_out[7:1]};
							state <= state + 4'd1;
				end
							
				B7: begin
							parityTracker <= parityTracker ^ in; //Adds current bit to parityTracker
							data_out <= {in, data_out[7:1]};
							state <= (PARITY_ == 2'b0) ? STOP1 : PARITY;
				end
				
				PARITY: begin
							if(in != expectedBit)
								error <= 1'b1;
							state <= STOP1;
				end
							
				STOP1,STOP2: begin
							if(in != expectedBit)
								error <= 1'b1;
							if(state == STOP1 && STOP_)
									state <= STOP2;
							else begin
								received <= 1'b1;
								state <= END_HALF;
							end
				end
			endcase
					
		end
		
		//Two Counters
		if(recieving) begin
			if(state == HALF_START || state == END_HALF) begin  //Half gap counter
				if(half_counter == (BAUD_COUNT >> 1))
					half_counter <= 27'd0;
				else half_counter <= half_counter + 1'b1;
			end
			else if(gap_counter == BAUD_COUNT) //Full gap counter
				gap_counter <= 28'd0;
			else gap_counter <= gap_counter + 1'b1;
		end else begin              
			half_counter <= 27'd0;
			gap_counter <= 28'd0;
		end
	end
endmodule
	
	
