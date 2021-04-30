`define RING_OSC_FREQ_HZ 20e6
`define INVERTER_DELAY_NS 0.1
`timescale 1ns/1ps

module lhca #(
    parameter int 	      WIDTH = 32,
    parameter bit [WIDTH-1:0] DIAGONAL = WIDTH'(0)
) (
   input logic 		    clk,
   input logic 		    rst,
   input logic [WIDTH-1:0]  source,
   output logic [WIDTH-1:0] state
  );


   logic [WIDTH-1:0] 	    diagonal, next_state;


   always_ff @(posedge clk)
     state <= next_state;



   integer 		    i;

   generate
      always_comb
	begin
	   if (!rst) begin
	      for (i = 0; i < WIDTH; i++)
		begin
		   if (i != 0)
		     next_state[i] = state[i - 1];

		   next_state[i] = next_state[i] ^ source[i] ^ (diagonal[i] && state[i]);


		   if (i != WIDTH - 1)
		     next_state[i] = next_state[i] ^ state[i + 1];

		end
	   end
	   else begin
	      for (i = 0; i < WIDTH; i++)
		begin
		   if (i != 0)
		     next_state[i] = 0;

		   next_state[i] = 0 ^ source[i] ^ 0;


		   if (i != WIDTH - 1)
		     next_state[i] = 0;

		end
	   end
	end
   endgenerate

   generate
      if (DIAGONAL != WIDTH'(0))
	assign diagonal = DIAGONAL;

      else
	begin
	   case(WIDTH)
	     2: assign diagonal = 2'h1;

	     3: assign diagonal = 3'h1;

	     4: assign diagonal = 4'h5;

	     5: assign diagonal = 5'h01;

	     6: assign diagonal = 6'h01;

	     7: assign diagonal = 7'h04;

	     8: assign diagonal = 8'hEF;

	     9: assign diagonal = 9'h1F9;

	     10: assign diagonal = 10'h3D7;

	     11: assign diagonal = 11'h7F9;

	     12: assign diagonal = 12'hFC1;

	     13: assign diagonal = 13'h1FF1;

	     14: assign diagonal = 14'h3FE9;

	     15: assign diagonal = 15'h7FFB;

	     16: assign diagonal = 16'hFFE5;

	     17: assign diagonal = 17'h1FFEF;

	     18: assign diagonal = 18'h3FFF7;

	     19: assign diagonal = 19'h7FFFB;

	     20: assign diagonal = 20'hFFFF9;

	     21: assign diagonal = 21'h1FFFCD;

	     22: assign diagonal = 22'h3FFFEF;

	     23: assign diagonal = 23'h7FFFF3;

	     24: assign diagonal = 24'hFFFFF9;

	     25: assign diagonal = 25'h1FFFFDB;

	     26: assign diagonal = 26'h3FFFFF9;

	     27: assign diagonal = 27'h7FFFFE3;

	     28: assign diagonal = 28'hFFFFFFB;

	     29: assign diagonal = 29'h1FFFFF8D;

	     30: assign diagonal = 30'h3FFFFFC1;

	     31: assign diagonal = 31'h7FFFFFE5;

	     32: assign diagonal = 32'hFFFFFFBB;

	     33: assign diagonal = 33'h1FFFFFFCF;

	     34: assign diagonal = 34'h3FFFFFFEB;

	     35: assign diagonal = 35'h7FFFFFFF3;

	     36: assign diagonal = 36'hFFFFFFFED;

	     37: assign diagonal = 37'h1FFFFFFFD9;

	     38: assign diagonal = 38'h3FFFFFFFF9;

	     39: assign diagonal = 39'h7FFFFFFFFB;

	     40: assign diagonal = 40'hFFFFFFFFBD;

	     41: assign diagonal = 41'h1FFFFFFFFEF;

	     42: assign diagonal = 42'h3FFFFFFFF9F;

	     43: assign diagonal = 43'h7FFFFFFFFFB;

	     44: assign diagonal = 44'hFFFFFFFFF73;

	     45: assign diagonal = 45'h1FFFFFFFFFF9;

	     46: assign diagonal = 46'h3FFFFFFFFF6B;

	     47: assign diagonal = 47'h7FFFFFFFFF9B;

	     48: assign diagonal = 48'hFFFFFFFFFFFB;

	     49: assign diagonal = 49'h1FFFFFFFFFFAB;

	     50: assign diagonal = 50'h3FFFFFFFFFFE7;

	     51: assign diagonal = 51'h7FFFFFFFFFFE7;

	     52: assign diagonal = 52'hFFFFFFFFFFE9F;

	     53: assign diagonal = 53'h1FFFFFFFFFFFEF;

	     54: assign diagonal = 54'h3FFFFFFFFFFFF9;

	     55: assign diagonal = 55'h7FFFFFFFFFFFDB;

	     56: assign diagonal = 56'hFFFFFFFFFFFF31;

	     57: assign diagonal = 57'h1FFFFFFFFFFFFA9;

	     58: assign diagonal = 58'h3FFFFFFFFFFFEF7;

	     59: assign diagonal = 59'h7FFFFFFFFFFFF97;

	     60: assign diagonal = 60'hFFFFFFFFFFFFFB7;

	     61: assign diagonal = 61'h1FFFFFFFFFFFFFD9;

	     62: assign diagonal = 62'h3FFFFFFFFFFFFFC9;

	     63: assign diagonal = 63'h7FFFFFFFFFFFFFE5;

	     64: assign diagonal = 64'hFFFFFFFFFFFFFFFB;

	   endcase
	end
   endgenerate
endmodule


module ring_oscillator#(
                        parameter NO_STAGES=3, // No of inverter stage
			parameter INV_DELAY_ns=2       // Delay of single inverter in ns
                        )(
                          input wire  en,
                          output wire clk_out
                          );

   wire [NO_STAGES:0] 			wi;
   assign wi[0] = en ? wi[NO_STAGES] : 0;
   assign clk_out = en ? wi[NO_STAGES] : 0;

   genvar 				i;
    generate
       for(i = 0; i < NO_STAGES; i = i+1) begin
            if(i==0) begin
                `ifndef R_OSC_SYNTHESIS
               not #(INV_DELAY_ns) (wi[i+1], wi[0]);

                `else
               not (wi[i+1], wi[0]);

                `endif
            end
            else if(i>= NO_STAGES) begin
                `ifndef R_OSC_SYNTHESIS
               not #(INV_DELAY_ns) (wi[i+1], wi[i]);

                `else
               not (wi[i+1], wi[i]);

                `endif
            end
            else begin
                `ifndef R_OSC_SYNTHESIS
               not #(INV_DELAY_ns) (wi[i+1], wi[i]);

                `else
               not (wi[i+1], wi[i]);

                `endif
            end
        end
    endgenerate
endmodule


module rng_top #(
		 parameter NUM_INV = 32
)(
  input 	       clk,
  input 	       rst,
  input 	       en_i,
  output [NUM_INV-1:0] out_random_num
);

   genvar i;
   logic [NUM_INV-1:0] clk_o;

   // generate
   //    for (i = 0; i < NUM_INV; i++) begin
   // 	 ring_oscillator #(
   // 			   .NO_STAGES(3+i*2),
   //                         .INV_DELAY_ns(`INVERTER_DELAY_NS)
   // 			   ) DUT (
   // 				  .en(en_i),
   // 				  .clk_out(clk_o[i])
   // 				  );

   //    end
   // endgenerate

   lhca #(.WIDTH(NUM_INV)) lhca(.clk(clk), .rst(rst), .source(1010101010), .state(out_random_num));
endmodule
