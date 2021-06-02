//-----------------------------------------------------------------------------
// AES Encrypt Module
//  
//-----------------------------------------------------------------------------
//`default_nettype none
module AESTop
(
  input  wire [   0:0] clk,
  input  wire [   0:0] rst,
  input  wire [   0:0] input_valid,
  input  wire [   0:0] output_ready,
  input  wire [   6:0] opcode,
  input  wire [ 255:0] data_in,

  output wire [ 127:0] data_out,
  output wire [   0:0] input_ready,
  output wire [   0:0] output_valid,
  output wire [   0:0] busy
);

  reg  [   0: 0] encrypt_ready, decrypt_ready, key_ready;
  wire [   0: 0] encrypt_valid, decrypt_valid, key_valid;
  reg  [  127:0] encrypt_in, decrypt_in; 
  reg  [  255:0] key_in; 
  wire [  127:0] encrypt_out, decrypt_out; 
  reg  [  127:0] data_temp; 
  wire [  127:0] key_out [14:0];


  AESEncrypt AESEncrypt_inst
    (
      .clk(clk),
      .rst(rst),
      .ready(encrypt_ready),
      .data_in(encrypt_in),
      .key(key_out),
      .data_out(encrypt_out),
      .valid(encrypt_valid)
    );

    AESDecrypt AESDecrypt_inst
    (
      .clk(clk),
      .rst(rst),
      .ready(decrypt_ready),
      .data_in(decrypt_in),
      .key(key_out),
      .data_out(decrypt_out),
      .valid(decrypt_valid)
    );

    ExpandKey ExpandKey_inst
    (
      .clk(clk),
      .rst(rst),
      .ready(key_ready),
      .key_in(key_in),
      .key_out(key_out),
      .valid(key_valid)
    );


   reg [1:0]               state;   

   localparam WAIT = 2'b00, RUN = 2'b01, FINAL = 2'b10;

   assign input_ready = state == WAIT;
   assign output_valid = state == FINAL;
   assign busy = state != WAIT;


   always @(posedge clk or posedge rst) begin
      if (rst) begin
        state <= WAIT;
      end else if (state == WAIT && input_valid)
        state <= RUN;
      else if (state == RUN) begin
        if ((opcode == 7'd0 && key_valid) || 
            (opcode == 7'd1 && encrypt_valid)|| 
            (opcode == 7'd2 && decrypt_valid))
          state <= FINAL;
        else 
          state <= RUN;
      end else if (state == FINAL)
        state <= WAIT;
   end

  assign data_out = data_temp;
  always @(posedge clk) begin
    if (state == WAIT && input_valid) begin
      if (opcode == 7'd0) begin
        key_in <= data_in;
        key_ready <= 1'd1; 
      end else if (opcode == 7'd1) begin
        encrypt_in <= data_in[255:128];
        encrypt_ready <= 1'd1; 
      end else if (opcode == 7'd2) begin
        decrypt_in <= data_in[255:128];
        decrypt_ready <= 1'd1;
      end 
    end else if (state == RUN) begin 
      key_ready <= 1'b0;
      encrypt_ready <= 1'b0;
      decrypt_ready <= 1'b0; 
      if (rst)
        data_temp <= 128'd0;
      else if (opcode == 7'd0 && key_valid)
        data_temp <= 128'd0;
      else if (opcode == 7'd1 && encrypt_valid)
        data_temp <= encrypt_out;
      else if (opcode == 7'd2 && decrypt_valid)
        data_temp <= decrypt_out;
    end
  end
endmodule // mainUnit
`default_nettype wire
//-----------------------------------------------------------------------------
// AES Encrypt Module
//  
//-----------------------------------------------------------------------------


//`default_nettype none
module AESEncrypt
(
  input  wire [   0:0] clk,
  input  wire [   0:0] rst,
  input  wire [   0:0] ready,
  input  wire [ 127:0] data_in,
  input  wire [ 127:0] key [14:0],

  output wire [ 127:0] data_out,
  output wire [   0:0] valid
);

  //---------
  // INPUT OUTPUT 
  // - this is for storing input and output data 
  //---------
  reg [ 127: 0] temp_data  [5:0];
  reg [   0: 0] temp_ready;
  reg [   0: 0] valid_final;
  reg [ 127: 0] temp_key;
  reg [   1: 0] state;
  reg [   3: 0] counter;
  localparam WAIT = 2'd0, ENCRYPT = 2'd1, FINAL = 2'd2;


  EncryptInitRound  Round0 (.data_in(temp_data[0]), .key(key[0]),
                            .data_out(temp_data[1]));

  EncryptRound      EncryptRound (.data_in(temp_data[2]), .key(temp_key),
                                  .data_out(temp_data[3]));


  EncryptLastRound  Round14 (.data_in(temp_data[4]), .key(key[14]),
                             .data_out(temp_data[5]));


  //---------
  // FSM
  //---------
  assign data_out = temp_data[5];
  assign valid = valid_final;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      valid_final <= 1'b0; 
      state <= WAIT;
    end
    else begin
      case(state)
        WAIT: begin
          if (ready) begin
            state <= ENCRYPT;
            temp_data[0] <= data_in;
          end 
          valid_final <= 1'd0;
          counter <= 4'd1;
        end
        ENCRYPT: begin
          counter <= counter + 4'd1;
          if(counter == 4'd1) begin
            temp_data[2] <= temp_data[1];
            temp_key <= key[1];
          end else if(counter < 4'd14) begin
            temp_data[2] <= temp_data[3];
            temp_key <= key[counter];
          end else if(counter == 4'd14) begin
            temp_data[4] <= temp_data[3];
            state <= FINAL;
            valid_final <= 1'd1;
          end
        end
        FINAL: begin
          valid_final <= 1'd0;
          state <= WAIT; 
        end
      endcase
    end
  end

endmodule // mainUnit
`default_nettype wire

//-----------------------------------------------------------------------------
// AES Decrypt Module
//  
//-----------------------------------------------------------------------------

//`default_nettype none
module AESDecrypt
(
  input  wire [   0:0] clk,
  input  wire [   0:0] rst,
  input  wire [   0:0] ready,
  input  wire [ 127:0] data_in,
  input  wire [ 127:0] key [14:0],

  output wire [ 127:0] data_out,
  output wire [   0:0] valid
);

  //---------
  // INPUT OUTPUT 
  // - this is for storing input and output data 
  //---------
  reg [ 127: 0] temp_data  [5:0];
  reg [   0: 0] temp_ready;
  reg [   0: 0] valid_final;
  reg [ 127: 0] temp_key;
  reg [   1: 0] state;
  reg [   3: 0] counter;
  localparam WAIT = 2'd0, DECRYPT = 2'd1, FINAL = 2'd2;

  DecryptInitRound  Round0 (.data_in(temp_data[0]), .key(key[14]),
                            .data_out(temp_data[1]));

  DecryptRound  DecryptRound (.data_in(temp_data[2]), .key(temp_key),
                              .data_out(temp_data[3]));

  DecryptLastRound  Round14 (.data_in(temp_data[4]), .key(key[0]),
                             .data_out(temp_data[5]));



  //---------
  // FSM
  //---------
  assign data_out = temp_data[5];
  assign valid = valid_final;

    always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      valid_final <= 1'b0; 
      state <= WAIT;
    end
    else begin
      case(state)
        WAIT: begin
          if (ready) begin
            state <= DECRYPT;
            temp_data[0] <= data_in;
          end 
          valid_final <= 1'd0;
          counter <= 4'd1;
        end
        DECRYPT: begin
          counter <= counter + 4'd1;
          if(counter == 4'd1) begin
            temp_data[2] <= temp_data[1];
            temp_key <= key[4'd13];
          end else if(counter < 4'd14) begin
            temp_data[2] <= temp_data[3];
            temp_key <= key[4'd14 - counter];
          end else if(counter == 4'd14) begin
            temp_data[4] <= temp_data[3];
            state <= FINAL;
            valid_final <= 1'd1;
          end
        end
        FINAL: begin
          valid_final <= 1'd0;
          state <= WAIT; 
        end
      endcase
    end
  end


endmodule // mainUnit
`default_nettype wire

//-----------------------------------------------------------------------------
// AddRoundKey Module
// 
//-----------------------------------------------------------------------------

`default_nettype none
module AddRoundKey
(
  input  wire [  127:0] in,
  input  wire [  127:0] key,
  output  wire [  127:0] out
);

  assign out = in ^ key;
endmodule

//-----------------------------------------------------------------------------
// Round definitions
//  
//-----------------------------------------------------------------------------

`default_nettype none
module DecryptRound
(
  input  wire [ 127:0] data_in,
  input  wire [ 127:0] key,
  output wire [ 127:0] data_out
);

  reg [ 127: 0] temp_data  [3:0];

  InvShiftRows InvShiftRows(.in(data_in), .out(temp_data[1]));
  InvSubBytes InvSubBytes(.in(temp_data[1]), .out(temp_data[2]));
  AddRoundKey AddRoundKey(.in(temp_data[2]),.key(key), .out(temp_data[3]));
  InvMixColumns InvMixColumns(.in(temp_data[3]), .out(data_out));

endmodule // mainUnit
`default_nettype wire


`default_nettype none
module DecryptInitRound
(
  input  wire [ 127:0] data_in,
  input  wire [ 127:0] key,
  output wire [ 127:0] data_out
);

  AddRoundKey AddRoundKey(.in(data_in),.key(key), .out(data_out));


endmodule // mainUnit
`default_nettype wire

`default_nettype none
module DecryptLastRound
(
  input  wire [ 127:0] data_in,
  input  wire [ 127:0] key,
  output wire [ 127:0] data_out
);

  reg [ 127: 0] temp_data  [2:0];

  InvShiftRows InvShiftRows(.in(data_in), .out(temp_data[1]));
  InvSubBytes InvSubBytes(.in(temp_data[1]), .out(temp_data[2]));
  AddRoundKey AddRoundKey(.in(temp_data[2]), .key(key), .out(data_out));


endmodule // mainUnit
`default_nettype wire

//-----------------------------------------------------------------------------
// Round definitions
//  
//-----------------------------------------------------------------------------

`default_nettype none
module EncryptRound
(
  input  wire [ 127:0] data_in,
  input  wire [ 127:0] key,
  output wire [ 127:0] data_out
);

  reg [ 127: 0] temp_data  [3:0];

  SubBytes SubBytes(.in(data_in), .out(temp_data[1]));
  ShiftRows ShiftRows(.in(temp_data[1]), .out(temp_data[2]));
  MixColumns MixColumns(.in(temp_data[2]), .out(temp_data[3]));
  AddRoundKey AddRoundKey(.in(temp_data[3]),.key(key), .out(data_out));


endmodule // encrypt
`default_nettype wire


`default_nettype none
module EncryptInitRound
(
  input  wire [ 127:0] data_in,
  input  wire [ 127:0] key,
  output wire [ 127:0] data_out
);

  AddRoundKey AddRoundKey(.in(data_in),.key(key), .out(data_out));

endmodule // init
`default_nettype wire

`default_nettype none
module EncryptLastRound
(
  input  wire [ 127:0] data_in,
  input  wire [ 127:0] key,
  output wire [ 127:0] data_out
);

  reg [ 127: 0] temp_data  [2:0];

  SubBytes SubBytes(.in(data_in), .out(temp_data[1]));
  ShiftRows ShiftRows(.in(temp_data[1]), .out(temp_data[2]));
  AddRoundKey AddRoundKey(.in(temp_data[2]),.key(key), .out(data_out));


endmodule // final
`default_nettype wire

//-----------------------------------------------------------------------------
// ExpandKey Module
// 
// the first round 
//-----------------------------------------------------------------------------
`define I 0
`define GENERATE_STATE 1

`default_nettype none
module ExpandKey
(
  input  wire [    0:0] clk,
  input  wire [    0:0] rst,
  input  wire [    0:0] ready,
  input  wire [  255:0] key_in,

  output wire [  127:0] key_out [14:0],
  output wire [    0:0] valid
);

  wire [127:0] temp_key [1:0];

  reg  [127:0] temp_out [14:0];
  reg  [255:0] next_key [3:0]; 
  reg  [  0:0] temp_ready;
  reg  [  0:0] valid_final;
  reg  [  1:0] state;
  reg  [  3:0] counter;
  reg  [  7:0] temp_rcon;
  localparam WAIT = 2'd0, EXPAND = 2'd1, FINAL = 2'd2;
  //---------
  // FSM
  //---------
  assign key_out = temp_out;
  assign valid = valid_final;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      temp_out <= '{128'd0,128'd0,128'd0,128'd0,128'd0,128'd0,128'd0,128'd0,
                    128'd0,128'd0,128'd0,128'd0,128'd0,128'd0,128'd0};
      valid_final <= 1'd0;
      state <= WAIT;
    end
    else begin
      case(state)
        WAIT: begin
          if (ready) begin
            state <= EXPAND;
            temp_out[0] <= key_in[255:128];
            temp_out[1] <= key_in[127:0]; 
            next_key[0] <= key_in;
            temp_rcon <= 8'h1;
          end 
          valid_final <= 1'd0;
          counter <= 4'd2;
        end
        EXPAND: begin
          counter <= counter + 4'd1;
          if(counter[0]) begin
            temp_out[counter + 4'd0] <= temp_key[1];
            next_key[0] <= next_key[3];
          end else begin 
            temp_out[counter + 4'd0] <= temp_key[0];
            next_key[2] <= next_key[1];
          end
          if(counter == 4'd14) begin
            state <= FINAL;
            valid_final <= 1'd1;
          end
          case(counter)
            4'd1: temp_rcon <= 8'h1;
            4'd2: temp_rcon <= 8'h1;
            4'd3: temp_rcon <= 8'h2;
            4'd4: temp_rcon <= 8'h2;
            4'd5: temp_rcon <= 8'h4;
            4'd6: temp_rcon <= 8'h4;
            4'd7: temp_rcon <= 8'h8;
            4'd8: temp_rcon <= 8'h8;
            4'd9: temp_rcon <= 8'h10;
            4'd10: temp_rcon <= 8'h10;
            4'd11: temp_rcon <= 8'h20;
            4'd12: temp_rcon <= 8'h20;
            4'd13: temp_rcon <= 8'h40;
            4'd14: temp_rcon <= 8'h40;
          endcase
        end
        FINAL: begin
          valid_final <= 1'd0;
          state <= WAIT; 
        end
      endcase
    end
  end


  ExpandKeyEvenHelper round2  (.in(next_key[0]), .rcon(temp_rcon), .next(next_key[1]), .out(temp_key[0]));
  ExpandKeyOddHelper  round3  (.in(next_key[2]), .next(next_key[3]), .out(temp_key[1]));

endmodule


module ExpandKeyEvenHelper
(
  input  wire [  255:0] in,
  input  wire     [7:0] rcon,
  output wire [  255:0] next,
  output wire [  127:0] out
);

    wire       [31:0]  k0, k1, k2, k3, k4, k5, k6, k7,
                       v0, v1, v2, v3;
    reg        [31:0]  k0a, k1a, k2a, k3a, k4a, k5a, k6a, k7a;
    wire       [31:0]  k0b, k1b, k2b, k3b, k4b, k5b, k6b, k7b, k8a;

    assign {k0, k1, k2, k3, k4, k5, k6, k7} = in;
    
    assign v0 = {k0[31:24] ^ rcon, k0[23:0]};
    assign v1 = v0 ^ k1;
    assign v2 = v1 ^ k2;
    assign v3 = v2 ^ k3;

    assign {k0a, k1a, k2a, k3a, k4a, k5a, k6a, k7a} = {v0, v1, v2, v3, k4, k5, k6, k7};
    SubWord SubWord ({k7[23:0], k7[31:24]}, k8a);

    assign k0b = k0a ^ k8a;
    assign k1b = k1a ^ k8a;
    assign k2b = k2a ^ k8a;
    assign k3b = k3a ^ k8a;
    assign {k4b, k5b, k6b, k7b} = {k4a, k5a, k6a, k7a};

    assign next = {k0b, k1b, k2b, k3b, k4b, k5b, k6b, k7b};

    assign out = {k0b, k1b, k2b, k3b};
endmodule

module ExpandKeyOddHelper
(
  input  wire [  255:0] in,
  output wire [  255:0] next,
  output wire [  127:0] out
);
  wire       [31:0]  k0, k1, k2, k3, k4, k5, k6, k7,
                     v5, v6, v7;
  reg        [31:0]  k0a, k1a, k2a, k3a, k4a, k5a, k6a, k7a;
  wire       [31:0]  k0b, k1b, k2b, k3b, k4b, k5b, k6b, k7b, k8a;

  assign {k0, k1, k2, k3, k4, k5, k6, k7} = in;
  
  assign v5 = k4 ^ k5;
  assign v6 = v5 ^ k6;
  assign v7 = v6 ^ k7;

  assign {k0a, k1a, k2a, k3a, k4a, k5a, k6a, k7a} = {k0, k1, k2, k3, k4, v5, v6, v7};

  SubWord SubWord (k3, k8a);

  assign {k0b, k1b, k2b, k3b} = {k0a, k1a, k2a, k3a};
  assign k4b = k4a ^ k8a;
  assign k5b = k5a ^ k8a;
  assign k6b = k6a ^ k8a;
  assign k7b = k7a ^ k8a;

  assign next = {k0b, k1b, k2b, k3b, k4b, k5b, k6b, k7b};
  assign out = {k4b, k5b, k6b, k7b};

endmodule
//---------------------------------------------------------------------------------------
//
//  Inv Mix Columns 
//
//  Description:
//    This file includes all functions implemented in the mix_columns.v original file 
//    but implemented as modules. 
//
//  Author(s):
//      - Moti Litochevski
//
//---------------------------------------------------------------------------------------
module xtimes (
  input  wire [7:0] in,
  output wire [7:0] out
);
 
 
wire [3:0] xt;

assign xt[3] = in[7];
assign xt[2] = in[7];
assign xt[1] = 1'b0;
assign xt[0] = in[7];

assign out[7:5] = in[6:4];
assign out[4:1] = xt[3:0] ^ in[3:0];
assign out[0]   = in[7];

endmodule

module MUL3 (
  input  wire [7:0] in,
  output wire [7:0] out
);
 
wire [7:0] xt;

xtimes xt_u (.in(in), .out(xt));

assign out = xt ^ in;

endmodule

module MULE (
  input wire [7:0] in,
  output wire [7:0] out
);
 
 
wire [7:0] xt1, xt2, xt3;

xtimes xt_u1 (.in(in), .out(xt1));
xtimes xt_u2 (.in(xt1), .out(xt2));
xtimes xt_u3 (.in(xt2), .out(xt3));

assign out = xt3 ^ xt2 ^ xt1;

endmodule

module MULB (
  input wire [7:0] in,
  output wire [7:0] out
);
 
 
wire [7:0] xt1, xt2, xt3;

xtimes xt_u1 (.in(in), .out(xt1));
xtimes xt_u2 (.in(xt1), .out(xt2));
xtimes xt_u3 (.in(xt2), .out(xt3));

assign out = xt3 ^ xt1 ^ in;

endmodule

module MULD (
  input wire [7:0] in,
  output wire [7:0] out
);
 
 
wire [7:0] xt1, xt2, xt3;

xtimes xt_u1 (.in(in), .out(xt1));
xtimes xt_u2 (.in(xt1), .out(xt2));
xtimes xt_u3 (.in(xt2), .out(xt3));

assign out = xt3 ^ xt2 ^ in;

endmodule

module MUL9 (
  input wire [7:0] in,
  output wire [7:0] out
);
 
 
wire [7:0] xt1, xt2, xt3;

xtimes xt_u1 (.in(in), .out(xt1));
xtimes xt_u2 (.in(xt1), .out(xt2));
xtimes xt_u3 (.in(xt2), .out(xt3));

assign out = xt3 ^ in;

endmodule

module InvByteMixColumns (
  input wire [7:0] a,
  input wire [7:0] b,
  input wire [7:0] c,
  input wire [7:0] d,
  output wire [7:0] out
);
 
wire [7:0] mule, mulb, muld, mul9;

MULE mule_u (.in(a), .out(mule));
MULB mulb_u (.in(b), .out(mulb));
MULD muld_u (.in(c), .out(muld));
MUL9 mul9_u (.in(d), .out(mul9));

assign out = mule ^ mulb ^ muld ^ mul9;

endmodule

module InvWordMixColumns (
  input wire [31:0] in,
  output wire [31:0] out
);
 
wire [7:0] si0,si1,si2,si3;
wire [7:0] so0,so1,so2,so3;

assign si0 = in[31:24];
assign si1 = in[23:16];
assign si2 = in[15:8];
assign si3 = in[7:0];
  
InvByteMixColumns so0_u (.a(si0), .b(si1), .c(si2), .d(si3), .out(so0));
InvByteMixColumns so1_u (.a(si1), .b(si2), .c(si3), .d(si0), .out(so1));
InvByteMixColumns so2_u (.a(si2), .b(si3), .c(si0), .d(si1), .out(so2));
InvByteMixColumns so3_u (.a(si3), .b(si0), .c(si1), .d(si2), .out(so3));
  
assign out = {so0, so1, so2, so3};

endmodule

module InvMixColumns 
(
  input  wire [  127:0] in,
  output  wire [  127:0] out
);
 

wire [31:0] so0,so1,so2,so3;

InvWordMixColumns so0_u (.in(in[127:96]), .out(so0));
InvWordMixColumns so1_u (.in(in[95:64]),  .out(so1));
InvWordMixColumns so2_u (.in(in[63:32]),  .out(so2));
InvWordMixColumns so3_u (.in(in[31:0]),   .out(so3));

assign out = {so0, so1, so2, so3};

endmodule
//---------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Inv_S_Box Module
// not similar to an Xbox 
//-----------------------------------------------------------------------------

`default_nettype none
module InvSBox
(
  input  wire [   7:0] in,
  output  wire [   7:0] out
);
    
  reg [7:0] out_temp;
  assign out = out_temp;
    
  always @(in)
    case (in)
      8'h00: out_temp = 8'h52;
      8'h01: out_temp = 8'h09;
      8'h02: out_temp = 8'h6a;
      8'h03: out_temp = 8'hd5;
      8'h04: out_temp = 8'h30;
      8'h05: out_temp = 8'h36;
      8'h06: out_temp = 8'ha5;
      8'h07: out_temp = 8'h38;
      8'h08: out_temp = 8'hbf;
      8'h09: out_temp = 8'h40;
      8'h0a: out_temp = 8'ha3;
      8'h0b: out_temp = 8'h9e;
      8'h0c: out_temp = 8'h81;
      8'h0d: out_temp = 8'hf3;
      8'h0e: out_temp = 8'hd7;
      8'h0f: out_temp = 8'hfb;
      8'h10: out_temp = 8'h7c;
      8'h11: out_temp = 8'he3;
      8'h12: out_temp = 8'h39;
      8'h13: out_temp = 8'h82;
      8'h14: out_temp = 8'h9b;
      8'h15: out_temp = 8'h2f;
      8'h16: out_temp = 8'hff;
      8'h17: out_temp = 8'h87;
      8'h18: out_temp = 8'h34;
      8'h19: out_temp = 8'h8e;
      8'h1a: out_temp = 8'h43;
      8'h1b: out_temp = 8'h44;
      8'h1c: out_temp = 8'hc4;
      8'h1d: out_temp = 8'hde;
      8'h1e: out_temp = 8'he9;
      8'h1f: out_temp = 8'hcb;
      8'h20: out_temp = 8'h54;
      8'h21: out_temp = 8'h7b;
      8'h22: out_temp = 8'h94;
      8'h23: out_temp = 8'h32;
      8'h24: out_temp = 8'ha6;
      8'h25: out_temp = 8'hc2;
      8'h26: out_temp = 8'h23;
      8'h27: out_temp = 8'h3d;
      8'h28: out_temp = 8'hee;
      8'h29: out_temp = 8'h4c;
      8'h2a: out_temp = 8'h95;
      8'h2b: out_temp = 8'h0b;
      8'h2c: out_temp = 8'h42;
      8'h2d: out_temp = 8'hfa;
      8'h2e: out_temp = 8'hc3;
      8'h2f: out_temp = 8'h4e;
      8'h30: out_temp = 8'h08;
      8'h31: out_temp = 8'h2e;
      8'h32: out_temp = 8'ha1;
      8'h33: out_temp = 8'h66;
      8'h34: out_temp = 8'h28;
      8'h35: out_temp = 8'hd9;
      8'h36: out_temp = 8'h24;
      8'h37: out_temp = 8'hb2;
      8'h38: out_temp = 8'h76;
      8'h39: out_temp = 8'h5b;
      8'h3a: out_temp = 8'ha2;
      8'h3b: out_temp = 8'h49;
      8'h3c: out_temp = 8'h6d;
      8'h3d: out_temp = 8'h8b;
      8'h3e: out_temp = 8'hd1;
      8'h3f: out_temp = 8'h25;
      8'h40: out_temp = 8'h72;
      8'h41: out_temp = 8'hf8;
      8'h42: out_temp = 8'hf6;
      8'h43: out_temp = 8'h64;
      8'h44: out_temp = 8'h86;
      8'h45: out_temp = 8'h68;
      8'h46: out_temp = 8'h98;
      8'h47: out_temp = 8'h16;
      8'h48: out_temp = 8'hd4;
      8'h49: out_temp = 8'ha4;
      8'h4a: out_temp = 8'h5c;
      8'h4b: out_temp = 8'hcc;
      8'h4c: out_temp = 8'h5d;
      8'h4d: out_temp = 8'h65;
      8'h4e: out_temp = 8'hb6;
      8'h4f: out_temp = 8'h92;
      8'h50: out_temp = 8'h6c;
      8'h51: out_temp = 8'h70;
      8'h52: out_temp = 8'h48;
      8'h53: out_temp = 8'h50;
      8'h54: out_temp = 8'hfd;
      8'h55: out_temp = 8'hed;
      8'h56: out_temp = 8'hb9;
      8'h57: out_temp = 8'hda;
      8'h58: out_temp = 8'h5e;
      8'h59: out_temp = 8'h15;
      8'h5a: out_temp = 8'h46;
      8'h5b: out_temp = 8'h57;
      8'h5c: out_temp = 8'ha7;
      8'h5d: out_temp = 8'h8d;
      8'h5e: out_temp = 8'h9d;
      8'h5f: out_temp = 8'h84;
      8'h60: out_temp = 8'h90;
      8'h61: out_temp = 8'hd8;
      8'h62: out_temp = 8'hab;
      8'h63: out_temp = 8'h00;
      8'h64: out_temp = 8'h8c;
      8'h65: out_temp = 8'hbc;
      8'h66: out_temp = 8'hd3;
      8'h67: out_temp = 8'h0a;
      8'h68: out_temp = 8'hf7;
      8'h69: out_temp = 8'he4;
      8'h6a: out_temp = 8'h58;
      8'h6b: out_temp = 8'h05;
      8'h6c: out_temp = 8'hb8;
      8'h6d: out_temp = 8'hb3;
      8'h6e: out_temp = 8'h45;
      8'h6f: out_temp = 8'h06;
      8'h70: out_temp = 8'hd0;
      8'h71: out_temp = 8'h2c;
      8'h72: out_temp = 8'h1e;
      8'h73: out_temp = 8'h8f;
      8'h74: out_temp = 8'hca;
      8'h75: out_temp = 8'h3f;
      8'h76: out_temp = 8'h0f;
      8'h77: out_temp = 8'h02;
      8'h78: out_temp = 8'hc1;
      8'h79: out_temp = 8'haf;
      8'h7a: out_temp = 8'hbd;
      8'h7b: out_temp = 8'h03;
      8'h7c: out_temp = 8'h01;
      8'h7d: out_temp = 8'h13;
      8'h7e: out_temp = 8'h8a;
      8'h7f: out_temp = 8'h6b;
      8'h80: out_temp = 8'h3a;
      8'h81: out_temp = 8'h91;
      8'h82: out_temp = 8'h11;
      8'h83: out_temp = 8'h41;
      8'h84: out_temp = 8'h4f;
      8'h85: out_temp = 8'h67;
      8'h86: out_temp = 8'hdc;
      8'h87: out_temp = 8'hea;
      8'h88: out_temp = 8'h97;
      8'h89: out_temp = 8'hf2;
      8'h8a: out_temp = 8'hcf;
      8'h8b: out_temp = 8'hce;
      8'h8c: out_temp = 8'hf0;
      8'h8d: out_temp = 8'hb4;
      8'h8e: out_temp = 8'he6;
      8'h8f: out_temp = 8'h73;
      8'h90: out_temp = 8'h96;
      8'h91: out_temp = 8'hac;
      8'h92: out_temp = 8'h74;
      8'h93: out_temp = 8'h22;
      8'h94: out_temp = 8'he7;
      8'h95: out_temp = 8'had;
      8'h96: out_temp = 8'h35;
      8'h97: out_temp = 8'h85;
      8'h98: out_temp = 8'he2;
      8'h99: out_temp = 8'hf9;
      8'h9a: out_temp = 8'h37;
      8'h9b: out_temp = 8'he8;
      8'h9c: out_temp = 8'h1c;
      8'h9d: out_temp = 8'h75;
      8'h9e: out_temp = 8'hdf;
      8'h9f: out_temp = 8'h6e;
      8'ha0: out_temp = 8'h47;
      8'ha1: out_temp = 8'hf1;
      8'ha2: out_temp = 8'h1a;
      8'ha3: out_temp = 8'h71;
      8'ha4: out_temp = 8'h1d;
      8'ha5: out_temp = 8'h29;
      8'ha6: out_temp = 8'hc5;
      8'ha7: out_temp = 8'h89;
      8'ha8: out_temp = 8'h6f;
      8'ha9: out_temp = 8'hb7;
      8'haa: out_temp = 8'h62;
      8'hab: out_temp = 8'h0e;
      8'hac: out_temp = 8'haa;
      8'had: out_temp = 8'h18;
      8'hae: out_temp = 8'hbe;
      8'haf: out_temp = 8'h1b;
      8'hb0: out_temp = 8'hfc;
      8'hb1: out_temp = 8'h56;
      8'hb2: out_temp = 8'h3e;
      8'hb3: out_temp = 8'h4b;
      8'hb4: out_temp = 8'hc6;
      8'hb5: out_temp = 8'hd2;
      8'hb6: out_temp = 8'h79;
      8'hb7: out_temp = 8'h20;
      8'hb8: out_temp = 8'h9a;
      8'hb9: out_temp = 8'hdb;
      8'hba: out_temp = 8'hc0;
      8'hbb: out_temp = 8'hfe;
      8'hbc: out_temp = 8'h78;
      8'hbd: out_temp = 8'hcd;
      8'hbe: out_temp = 8'h5a;
      8'hbf: out_temp = 8'hf4;
      8'hc0: out_temp = 8'h1f;
      8'hc1: out_temp = 8'hdd;
      8'hc2: out_temp = 8'ha8;
      8'hc3: out_temp = 8'h33;
      8'hc4: out_temp = 8'h88;
      8'hc5: out_temp = 8'h07;
      8'hc6: out_temp = 8'hc7;
      8'hc7: out_temp = 8'h31;
      8'hc8: out_temp = 8'hb1;
      8'hc9: out_temp = 8'h12;
      8'hca: out_temp = 8'h10;
      8'hcb: out_temp = 8'h59;
      8'hcc: out_temp = 8'h27;
      8'hcd: out_temp = 8'h80;
      8'hce: out_temp = 8'hec;
      8'hcf: out_temp = 8'h5f;
      8'hd0: out_temp = 8'h60;
      8'hd1: out_temp = 8'h51;
      8'hd2: out_temp = 8'h7f;
      8'hd3: out_temp = 8'ha9;
      8'hd4: out_temp = 8'h19;
      8'hd5: out_temp = 8'hb5;
      8'hd6: out_temp = 8'h4a;
      8'hd7: out_temp = 8'h0d;
      8'hd8: out_temp = 8'h2d;
      8'hd9: out_temp = 8'he5;
      8'hda: out_temp = 8'h7a;
      8'hdb: out_temp = 8'h9f;
      8'hdc: out_temp = 8'h93;
      8'hdd: out_temp = 8'hc9;
      8'hde: out_temp = 8'h9c;
      8'hdf: out_temp = 8'hef;
      8'he0: out_temp = 8'ha0;
      8'he1: out_temp = 8'he0;
      8'he2: out_temp = 8'h3b;
      8'he3: out_temp = 8'h4d;
      8'he4: out_temp = 8'hae;
      8'he5: out_temp = 8'h2a;
      8'he6: out_temp = 8'hf5;
      8'he7: out_temp = 8'hb0;
      8'he8: out_temp = 8'hc8;
      8'he9: out_temp = 8'heb;
      8'hea: out_temp = 8'hbb;
      8'heb: out_temp = 8'h3c;
      8'hec: out_temp = 8'h83;
      8'hed: out_temp = 8'h53;
      8'hee: out_temp = 8'h99;
      8'hef: out_temp = 8'h61;
      8'hf0: out_temp = 8'h17;
      8'hf1: out_temp = 8'h2b;
      8'hf2: out_temp = 8'h04;
      8'hf3: out_temp = 8'h7e;
      8'hf4: out_temp = 8'hba;
      8'hf5: out_temp = 8'h77;
      8'hf6: out_temp = 8'hd6;
      8'hf7: out_temp = 8'h26;
      8'hf8: out_temp = 8'he1;
      8'hf9: out_temp = 8'h69;
      8'hfa: out_temp = 8'h14;
      8'hfb: out_temp = 8'h63;
      8'hfc: out_temp = 8'h55;
      8'hfd: out_temp = 8'h21;
      8'hfe: out_temp = 8'h0c;
      8'hff: out_temp = 8'h7d;
      default: out_temp = 8'h00;
  endcase
endmodule
`default_nettype wire

//-----------------------------------------------------------------------------
// Inv ShiftRows Module
// 
//-----------------------------------------------------------------------------

`default_nettype none
module InvShiftRows
(
  input  wire [  127:0] in,
  output  wire [  127:0] out
);
  assign          out[127:120] = in[127:120];  
  assign          out[87:80] = in[119:112];
  assign          out[47:40] = in[111:104];
  assign          out[7:0] = in[103:96];
     
  assign          out[95:88] = in[95:88];
  assign          out[55:48] = in[87:80];
  assign          out[15:8] = in[79:72];
  assign          out[103:96] = in[71:64];
     
  assign          out[63:56] = in[63:56];
  assign          out[23:16] = in[55:48];
  assign          out[111:104] = in[47:40];
  assign          out[71:64] = in[39:32];
     
  assign          out[31:24] = in[31:24];
  assign          out[119:112] = in[23:16];

  assign          out[79:72] = in[15:8];
  assign          out[39:32] = in[7:0]; 

endmodule

//-----------------------------------------------------------------------------
// InvSubBytes Module
// 
//-----------------------------------------------------------------------------

`default_nettype none
module InvSubBytes
(
  input  wire [  127:0] in,
  output  wire [  127:0] out
);
    
  genvar i;
  generate
      for (i=0; i<=120; i=i+8) begin : inv_sub_all_bytes 
      InvSBox InvSBox (
          .in(in[i + 7:i]),
          .out(out[i + 7:i])
      );
  end 
  endgenerate

endmodule
`default_nettype wire

//-----------------------------------------------------------------------------
// MixColumns Module
// 
//-----------------------------------------------------------------------------

`default_nettype none
module MixColumns
(
  input  wire [  127:0] in,
  output  wire [  127:0] out
);

  assign out[127:120]= mixcolumnshelper (in[127:120],in[119:112],in[111:104],in[103:96]);
  assign out[119:112]= mixcolumnshelper (in[119:112],in[111:104],in[103:96],in[127:120]);
  assign out[111:104]= mixcolumnshelper (in[111:104],in[103:96],in[127:120],in[119:112]);
  assign out[103:96]= mixcolumnshelper (in[103:96],in[127:120],in[119:112],in[111:104]);

  assign out[95:88]= mixcolumnshelper (in[95:88],in[87:80],in[79:72],in[71:64]);
  assign out[87:80]= mixcolumnshelper (in[87:80],in[79:72],in[71:64],in[95:88]);
  assign out[79:72]= mixcolumnshelper (in[79:72],in[71:64],in[95:88],in[87:80]);
  assign out[71:64]= mixcolumnshelper (in[71:64],in[95:88],in[87:80],in[79:72]);

  assign out[63:56]= mixcolumnshelper (in[63:56],in[55:48],in[47:40],in[39:32]);
  assign out[55:48]= mixcolumnshelper (in[55:48],in[47:40],in[39:32],in[63:56]);
  assign out[47:40]= mixcolumnshelper (in[47:40],in[39:32],in[63:56],in[55:48]);
  assign out[39:32]= mixcolumnshelper (in[39:32],in[63:56],in[55:48],in[47:40]);

  assign out[31:24]= mixcolumnshelper (in[31:24],in[23:16],in[15:8],in[7:0]);
  assign out[23:16]= mixcolumnshelper (in[23:16],in[15:8],in[7:0],in[31:24]);
  assign out[15:8]= mixcolumnshelper (in[15:8],in[7:0],in[31:24],in[23:16]);
  assign out[7:0]= mixcolumnshelper (in[7:0],in[31:24],in[23:16],in[15:8]);


  function [7:0] mixcolumnshelper(input [7:0] in1, input [7:0] in2, input [7:0] in3, 
                 input [7:0] in4);
    begin
      mixcolumnshelper[7]=in1[6] ^ in2[6] ^ in2[7] ^ in3[7] ^ in4[7];
      mixcolumnshelper[6]=in1[5] ^ in2[5] ^ in2[6] ^ in3[6] ^ in4[6];
      mixcolumnshelper[5]=in1[4] ^ in2[4] ^ in2[5] ^ in3[5] ^ in4[5];
      mixcolumnshelper[4]=in1[3] ^ in1[7] ^ in2[3] ^ in2[4] ^ in2[7] ^ in3[4] ^ in4[4];
      mixcolumnshelper[3]=in1[2] ^ in1[7] ^ in2[2] ^ in2[3] ^ in2[7] ^ in3[3] ^ in4[3];
      mixcolumnshelper[2]=in1[1] ^ in2[1] ^ in2[2] ^ in3[2] ^ in4[2];
      mixcolumnshelper[1]=in1[0] ^ in1[7] ^ in2[0] ^ in2[1] ^ in2[7] ^ in3[1] ^ in4[1];
      mixcolumnshelper[0]=in1[7] ^ in2[7] ^ in2[0] ^ in3[0] ^ in4[0];
    end
  endfunction
endmodule

//-----------------------------------------------------------------------------
// S_Box Module
// similar to an Xbox but also very different
//-----------------------------------------------------------------------------

`default_nettype none
module SBox
(
  input  wire [   7:0] in,
  output  wire [   7:0] out
);
    
  reg [7:0] out_temp;
  assign out = out_temp;
    
  always @(in)
    case (in)
     8'h00: out_temp = 8'h63;
     8'h01: out_temp = 8'h7c;
     8'h02: out_temp = 8'h77;
     8'h03: out_temp = 8'h7b;
     8'h04: out_temp = 8'hf2;
     8'h05: out_temp = 8'h6b;
     8'h06: out_temp = 8'h6f;
     8'h07: out_temp = 8'hc5;
     8'h08: out_temp = 8'h30;
     8'h09: out_temp = 8'h01;
     8'h0a: out_temp = 8'h67;
     8'h0b: out_temp = 8'h2b;
     8'h0c: out_temp = 8'hfe;
     8'h0d: out_temp = 8'hd7;
     8'h0e: out_temp = 8'hab;
     8'h0f: out_temp = 8'h76;
     8'h10: out_temp = 8'hca;
     8'h11: out_temp = 8'h82;
     8'h12: out_temp = 8'hc9;
     8'h13: out_temp = 8'h7d;
     8'h14: out_temp = 8'hfa;
     8'h15: out_temp = 8'h59;
     8'h16: out_temp = 8'h47;
     8'h17: out_temp = 8'hf0;
     8'h18: out_temp = 8'had;
     8'h19: out_temp = 8'hd4;
     8'h1a: out_temp = 8'ha2;
     8'h1b: out_temp = 8'haf;
     8'h1c: out_temp = 8'h9c;
     8'h1d: out_temp = 8'ha4;
     8'h1e: out_temp = 8'h72;
     8'h1f: out_temp = 8'hc0;
     8'h20: out_temp = 8'hb7;
     8'h21: out_temp = 8'hfd;
     8'h22: out_temp = 8'h93;
     8'h23: out_temp = 8'h26;
     8'h24: out_temp = 8'h36;
     8'h25: out_temp = 8'h3f;
     8'h26: out_temp = 8'hf7;
     8'h27: out_temp = 8'hcc;
     8'h28: out_temp = 8'h34;
     8'h29: out_temp = 8'ha5;
     8'h2a: out_temp = 8'he5;
     8'h2b: out_temp = 8'hf1;
     8'h2c: out_temp = 8'h71;
     8'h2d: out_temp = 8'hd8;
     8'h2e: out_temp = 8'h31;
     8'h2f: out_temp = 8'h15;
     8'h30: out_temp = 8'h04;
     8'h31: out_temp = 8'hc7;
     8'h32: out_temp = 8'h23;
     8'h33: out_temp = 8'hc3;
     8'h34: out_temp = 8'h18;
     8'h35: out_temp = 8'h96;
     8'h36: out_temp = 8'h05;
     8'h37: out_temp = 8'h9a;
     8'h38: out_temp = 8'h07;
     8'h39: out_temp = 8'h12;
     8'h3a: out_temp = 8'h80;
     8'h3b: out_temp = 8'he2;
     8'h3c: out_temp = 8'heb;
     8'h3d: out_temp = 8'h27;
     8'h3e: out_temp = 8'hb2;
     8'h3f: out_temp = 8'h75;
     8'h40: out_temp = 8'h09;
     8'h41: out_temp = 8'h83;
     8'h42: out_temp = 8'h2c;
     8'h43: out_temp = 8'h1a;
     8'h44: out_temp = 8'h1b;
     8'h45: out_temp = 8'h6e;
     8'h46: out_temp = 8'h5a;
     8'h47: out_temp = 8'ha0;
     8'h48: out_temp = 8'h52;
     8'h49: out_temp = 8'h3b;
     8'h4a: out_temp = 8'hd6;
     8'h4b: out_temp = 8'hb3;
     8'h4c: out_temp = 8'h29;
     8'h4d: out_temp = 8'he3;
     8'h4e: out_temp = 8'h2f;
     8'h4f: out_temp = 8'h84;
     8'h50: out_temp = 8'h53;
     8'h51: out_temp = 8'hd1;
     8'h52: out_temp = 8'h00;
     8'h53: out_temp = 8'hed;
     8'h54: out_temp = 8'h20;
     8'h55: out_temp = 8'hfc;
     8'h56: out_temp = 8'hb1;
     8'h57: out_temp = 8'h5b;
     8'h58: out_temp = 8'h6a;
     8'h59: out_temp = 8'hcb;
     8'h5a: out_temp = 8'hbe;
     8'h5b: out_temp = 8'h39;
     8'h5c: out_temp = 8'h4a;
     8'h5d: out_temp = 8'h4c;
     8'h5e: out_temp = 8'h58;
     8'h5f: out_temp = 8'hcf;
     8'h60: out_temp = 8'hd0;
     8'h61: out_temp = 8'hef;
     8'h62: out_temp = 8'haa;
     8'h63: out_temp = 8'hfb;
     8'h64: out_temp = 8'h43;
     8'h65: out_temp = 8'h4d;
     8'h66: out_temp = 8'h33;
     8'h67: out_temp = 8'h85;
     8'h68: out_temp = 8'h45;
     8'h69: out_temp = 8'hf9;
     8'h6a: out_temp = 8'h02;
     8'h6b: out_temp = 8'h7f;
     8'h6c: out_temp = 8'h50;
     8'h6d: out_temp = 8'h3c;
     8'h6e: out_temp = 8'h9f;
     8'h6f: out_temp = 8'ha8;
     8'h70: out_temp = 8'h51;
     8'h71: out_temp = 8'ha3;
     8'h72: out_temp = 8'h40;
     8'h73: out_temp = 8'h8f;
     8'h74: out_temp = 8'h92;
     8'h75: out_temp = 8'h9d;
     8'h76: out_temp = 8'h38;
     8'h77: out_temp = 8'hf5;
     8'h78: out_temp = 8'hbc;
     8'h79: out_temp = 8'hb6;
     8'h7a: out_temp = 8'hda;
     8'h7b: out_temp = 8'h21;
     8'h7c: out_temp = 8'h10;
     8'h7d: out_temp = 8'hff;
     8'h7e: out_temp = 8'hf3;
     8'h7f: out_temp = 8'hd2;
     8'h80: out_temp = 8'hcd;
     8'h81: out_temp = 8'h0c;
     8'h82: out_temp = 8'h13;
     8'h83: out_temp = 8'hec;
     8'h84: out_temp = 8'h5f;
     8'h85: out_temp = 8'h97;
     8'h86: out_temp = 8'h44;
     8'h87: out_temp = 8'h17;
     8'h88: out_temp = 8'hc4;
     8'h89: out_temp = 8'ha7;
     8'h8a: out_temp = 8'h7e;
     8'h8b: out_temp = 8'h3d;
     8'h8c: out_temp = 8'h64;
     8'h8d: out_temp = 8'h5d;
     8'h8e: out_temp = 8'h19;
     8'h8f: out_temp = 8'h73;
     8'h90: out_temp = 8'h60;
     8'h91: out_temp = 8'h81;
     8'h92: out_temp = 8'h4f;
     8'h93: out_temp = 8'hdc;
     8'h94: out_temp = 8'h22;
     8'h95: out_temp = 8'h2a;
     8'h96: out_temp = 8'h90;
     8'h97: out_temp = 8'h88;
     8'h98: out_temp = 8'h46;
     8'h99: out_temp = 8'hee;
     8'h9a: out_temp = 8'hb8;
     8'h9b: out_temp = 8'h14;
     8'h9c: out_temp = 8'hde;
     8'h9d: out_temp = 8'h5e;
     8'h9e: out_temp = 8'h0b;
     8'h9f: out_temp = 8'hdb;
     8'ha0: out_temp = 8'he0;
     8'ha1: out_temp = 8'h32;
     8'ha2: out_temp = 8'h3a;
     8'ha3: out_temp = 8'h0a;
     8'ha4: out_temp = 8'h49;
     8'ha5: out_temp = 8'h06;
     8'ha6: out_temp = 8'h24;
     8'ha7: out_temp = 8'h5c;
     8'ha8: out_temp = 8'hc2;
     8'ha9: out_temp = 8'hd3;
     8'haa: out_temp = 8'hac;
     8'hab: out_temp = 8'h62;
     8'hac: out_temp = 8'h91;
     8'had: out_temp = 8'h95;
     8'hae: out_temp = 8'he4;
     8'haf: out_temp = 8'h79;
     8'hb0: out_temp = 8'he7;
     8'hb1: out_temp = 8'hc8;
     8'hb2: out_temp = 8'h37;
     8'hb3: out_temp = 8'h6d;
     8'hb4: out_temp = 8'h8d;
     8'hb5: out_temp = 8'hd5;
     8'hb6: out_temp = 8'h4e;
     8'hb7: out_temp = 8'ha9;
     8'hb8: out_temp = 8'h6c;
     8'hb9: out_temp = 8'h56;
     8'hba: out_temp = 8'hf4;
     8'hbb: out_temp = 8'hea;
     8'hbc: out_temp = 8'h65;
     8'hbd: out_temp = 8'h7a;
     8'hbe: out_temp = 8'hae;
     8'hbf: out_temp = 8'h08;
     8'hc0: out_temp = 8'hba;
     8'hc1: out_temp = 8'h78;
     8'hc2: out_temp = 8'h25;
     8'hc3: out_temp = 8'h2e;
     8'hc4: out_temp = 8'h1c;
     8'hc5: out_temp = 8'ha6;
     8'hc6: out_temp = 8'hb4;
     8'hc7: out_temp = 8'hc6;
     8'hc8: out_temp = 8'he8;
     8'hc9: out_temp = 8'hdd;
     8'hca: out_temp = 8'h74;
     8'hcb: out_temp = 8'h1f;
     8'hcc: out_temp = 8'h4b;
     8'hcd: out_temp = 8'hbd;
     8'hce: out_temp = 8'h8b;
     8'hcf: out_temp = 8'h8a;
     8'hd0: out_temp = 8'h70;
     8'hd1: out_temp = 8'h3e;
     8'hd2: out_temp = 8'hb5;
     8'hd3: out_temp = 8'h66;
     8'hd4: out_temp = 8'h48;
     8'hd5: out_temp = 8'h03;
     8'hd6: out_temp = 8'hf6;
     8'hd7: out_temp = 8'h0e;
     8'hd8: out_temp = 8'h61;
     8'hd9: out_temp = 8'h35;
     8'hda: out_temp = 8'h57;
     8'hdb: out_temp = 8'hb9;
     8'hdc: out_temp = 8'h86;
     8'hdd: out_temp = 8'hc1;
     8'hde: out_temp = 8'h1d;
     8'hdf: out_temp = 8'h9e;
     8'he0: out_temp = 8'he1;
     8'he1: out_temp = 8'hf8;
     8'he2: out_temp = 8'h98;
     8'he3: out_temp = 8'h11;
     8'he4: out_temp = 8'h69;
     8'he5: out_temp = 8'hd9;
     8'he6: out_temp = 8'h8e;
     8'he7: out_temp = 8'h94;
     8'he8: out_temp = 8'h9b;
     8'he9: out_temp = 8'h1e;
     8'hea: out_temp = 8'h87;
     8'heb: out_temp = 8'he9;
     8'hec: out_temp = 8'hce;
     8'hed: out_temp = 8'h55;
     8'hee: out_temp = 8'h28;
     8'hef: out_temp = 8'hdf;
     8'hf0: out_temp = 8'h8c;
     8'hf1: out_temp = 8'ha1;
     8'hf2: out_temp = 8'h89;
     8'hf3: out_temp = 8'h0d;
     8'hf4: out_temp = 8'hbf;
     8'hf5: out_temp = 8'he6;
     8'hf6: out_temp = 8'h42;
     8'hf7: out_temp = 8'h68;
     8'hf8: out_temp = 8'h41;
     8'hf9: out_temp = 8'h99;
     8'hfa: out_temp = 8'h2d;
     8'hfb: out_temp = 8'h0f;
     8'hfc: out_temp = 8'hb0;
     8'hfd: out_temp = 8'h54;
     8'hfe: out_temp = 8'hbb;
     8'hff: out_temp = 8'h16;
     default: out_temp = 8'h00;
  endcase
endmodule
`default_nettype wire

//-----------------------------------------------------------------------------
// ShiftRows Module
// 
//-----------------------------------------------------------------------------

`default_nettype none
module ShiftRows
(
  input  wire [  127:0] in,
  output  wire [  127:0] out
);
  assign         out[127:120] = in[127:120];  
  assign         out[119:112] = in[87:80];
  assign         out[111:104] = in[47:40];
  assign         out[103:96] = in[7:0];
     
  assign          out[95:88] = in[95:88];
  assign          out[87:80] = in[55:48];
  assign          out[79:72] = in[15:8];
  assign          out[71:64] = in[103:96];
     
  assign          out[63:56] = in[63:56];
  assign          out[55:48] = in[23:16];
  assign          out[47:40] = in[111:104];
  assign          out[39:32] = in[71:64];
     
  assign          out[31:24] = in[31:24];
  assign          out[23:16] = in[119:112];
  assign          out[15:8] = in[79:72];
  assign          out[7:0] = in[39:32]; 

endmodule

//-----------------------------------------------------------------------------
// SubBytes Module
// 
//-----------------------------------------------------------------------------

`default_nettype none
module SubBytes
(
  input  wire [  127:0] in,
  output  wire [  127:0] out
);
    
  genvar i;
  generate
      for (i=0; i<=120; i=i+8) begin : sub_all_bytes 
      SBox SBox (
          .in(in[i + 7:i]),
          .out(out[i + 7:i])
      );
  end 
  endgenerate

endmodule
`default_nettype wire

//-----------------------------------------------------------------------------
// SubWord Module
// 
//-----------------------------------------------------------------------------

`default_nettype none
module SubWord
(
  input  wire  [  31:0] in,
  output  wire [  31:0] out
);

  SBox SBox1 (in[31:24], out[31:24]);
  SBox SBox2 (in[23:16], out[23:16]);
  SBox SBox3 (in[15:8],  out[15:8] );
  SBox SBox4 (in[7:0],   out[7:0]  );
endmodule 
