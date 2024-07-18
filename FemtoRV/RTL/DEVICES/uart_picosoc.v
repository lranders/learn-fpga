/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

 // October 2019, Matthias Koch: Renamed wires
 // December 2020, Bruno Levy: parameterization with freq and bauds

module buart #(
   parameter FREQ_MHZ = 60
  ,parameter BAUDS    = 115200
)(
   input wire clk
  ,input wire resetq

  ,output wire tx
  ,input  wire rx

  ,input  wire wr
  ,input  wire rd
  ,input  wire [7:0] tx_data
  ,output wire [7:0] rx_data

  ,output wire busy
  ,output wire valid
);

   localparam divider = FREQ_MHZ * 1000000 / BAUDS;

   reg [$clog2(divider)-1:0] recv_divcnt;   // Counts to divider. Reserve enough bytes !
   reg [7:0] recv_pattern;
   reg [7:0] recv_buf_data;
   reg recv_buf_valid;

   reg [9:0] send_pattern;
   reg send_dummy;
   reg [3:0] send_bitcnt;
   reg [$clog2(divider)-1:0] send_divcnt;   // Counts to divider. Reserve enough bytes !

   assign rx_data = recv_buf_data;
   assign valid = recv_buf_valid;
   assign busy = (send_bitcnt || send_dummy);

   reg [3:0] recv_state;

   localparam [3:0] STATE_INIT          =  4'd0;
   localparam [3:0] STATE_WAIT_HALF_BIT =  4'd1;
   localparam [3:0] STATE_BYTE_READY    = 4'd10;

   always @(posedge clk) begin
      if (!resetq) begin

         recv_state     <= STATE_INIT;
         recv_divcnt    <= 0;
         recv_pattern   <= 8'b0;
         recv_buf_data  <= 8'b0;
         recv_buf_valid <= 1'b0;

      end else begin
         recv_divcnt <= recv_divcnt + 1'b1;

         if (rd) recv_buf_valid <= 1'b0;

         case (recv_state)

            STATE_INIT: begin
               if (!rx)
                  recv_state <= STATE_WAIT_HALF_BIT;
            end

            STATE_WAIT_HALF_BIT: begin
               if (recv_divcnt > (divider/2)) begin
                  recv_state <= 4'd2;
                  recv_divcnt <= 0;
               end
            end

            STATE_BYTE_READY: begin
               if (recv_divcnt > divider) begin
                  recv_buf_data <= recv_pattern;
                  recv_buf_valid <= 1'b1;
                  recv_state <= STATE_INIT;
               end
            end

            default: begin
               if (recv_divcnt > divider) begin
                  recv_pattern <= { rx, recv_pattern[7:1] };
                  recv_state <= recv_state + 4'd1;
                  recv_divcnt <= 0;
               end
            end

         endcase
      end
   end

   assign tx = send_pattern[0];

   always @(posedge clk) begin
      send_divcnt <= send_divcnt + 1;
      if (!resetq) begin

         send_pattern <= ~0;
         send_bitcnt <= 0;
         send_divcnt <= 0;
         send_dummy <= 1;

      end else begin
         if (send_dummy && !send_bitcnt) begin
            send_pattern <= ~0;
            send_bitcnt <= 15;
            send_divcnt <= 0;
            send_dummy <= 0;
         end else if (wr && !send_bitcnt) begin
            send_pattern <= {1'b1, tx_data[7:0], 1'b0};
            send_bitcnt <= 10;
            send_divcnt <= 0;
         end else if (send_divcnt > divider && send_bitcnt) begin
            send_pattern <= {1'b1, send_pattern[9:1]};
            send_bitcnt <= send_bitcnt - 1;
            send_divcnt <= 0;
         end
      end 
   end

endmodule


