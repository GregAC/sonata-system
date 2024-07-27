/*
 * ----------------------------------------------------------------------------
 *  Project:  OpenHBMC
 *  Filename: hbmc_dfifo.v
 *  Purpose:  Downstream data FIFO. Stores data to be written to the memory.
 * ----------------------------------------------------------------------------
 *  Copyright © 2020-2022, Vaagn Oganesyan <ovgn@protonmail.com>
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 * ----------------------------------------------------------------------------
 */


`default_nettype none
`timescale 1ps / 1ps

`ifndef PRIM_DEFAULT_IMPL
  `define PRIM_DEFAULT_IMPL prim_pkg::ImplGeneric
`endif

module hbmc_dfifo #
(
    parameter integer DATA_WIDTH = 32
)
(
    input   wire                            fifo_arst,

    input   wire                            fifo_wr_clk,
    input   wire    [DATA_WIDTH - 1:0]      fifo_wr_din,
    input   wire    [DATA_WIDTH/8 - 1:0]    fifo_wr_strb,
    input   wire                            fifo_wr_ena,
    output  wire                            fifo_wr_full,

    input   wire                            fifo_rd_clk,
    output  wire    [15:0]                  fifo_rd_dout,
    output  wire    [1:0]                   fifo_rd_strb,
    input   wire                            fifo_rd_ena,
    output  wire                            fifo_rd_empty
);

    parameter prim_pkg::impl_e Impl = `PRIM_DEFAULT_IMPL;
    wire    [17:0]  dout;
    assign  fifo_rd_dout = dout[15:0];
    assign  fifo_rd_strb = dout[17:16];

    localparam pDATA_IN_WIDTH = 36;
    localparam pDATA_OUT_WIDTH = 18;
    localparam  FIFO_RD_DEPTH = 512;
    wire    [35:0]  din =   {
                                fifo_wr_strb[1:0], fifo_wr_din[15:0],
                                fifo_wr_strb[3:2], fifo_wr_din[31:16]
                            };

    // handle I/O width conversion:
    wire [pDATA_IN_WIDTH-1:0] dout_wide;
    reg  [pDATA_IN_WIDTH-1:0] dout_wide_r;
    reg wide_read_cnt = 1'b0;
    wire fifo_wide_read = fifo_rd_ena & ~wide_read_cnt;
    assign dout = wide_read_cnt ? dout_wide_r[pDATA_OUT_WIDTH-1:0] : dout_wide[pDATA_OUT_WIDTH*2-1 : pDATA_OUT_WIDTH];
    always @(posedge fifo_rd_clk) begin
        if (fifo_rd_ena) begin
            wide_read_cnt <= ~wide_read_cnt;
            if (fifo_wide_read)
                dout_wide_r <= dout_wide;
        end
    end


    // to avoid timing violations on reset net:
    wire fifo_arst_wsync;
    hbmc_arst_sync # (
        .C_SYNC_STAGES ( 3 )
    ) hbmc_arst_sync_inst (
        .clk  ( fifo_wr_clk   ),
        .arst ( fifo_arst     ),
        .rst  ( fifo_arst_wsync )
    );

    logic fifo_wready, fifo_rvalid;

    assign fifo_wr_full = ~fifo_wready;
    assign fifo_rd_empty = ~fifo_rvalid;

    prim_fifo_async #(
      .Width(pDATA_IN_WIDTH),
      .Depth(4)
    ) u_fifo (
      .clk_wr_i(fifo_wr_clk),
      .rst_wr_ni(~fifo_arst),
      .wvalid_i(fifo_wr_ena),
      .wready_o(fifo_wready),
      .wdata_i(din),
      .wdepth_o(),

      .clk_rd_i(fifo_rd_clk),
      .rst_rd_ni(~fifo_arst),
      .rvalid_o(fifo_rvalid),
      .rready_i(fifo_wide_read),
      .rdata_o(dout_wide),
      .rdepth_o()
    );


endmodule

/*----------------------------------------------------------------------------------------------------------------------------*/

`default_nettype wire
