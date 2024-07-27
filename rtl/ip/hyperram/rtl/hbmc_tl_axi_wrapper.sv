// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Wrapper for OpenHBMC HyperRAM controller; bridges AXI to TL .
module hbmc_tl_axi_wrapper import tlul_pkg::*; #(
  parameter int unsigned HRClkFreq = 100_000_000,
  parameter int unsigned HRSize    = 1024 * 1024
) (
  input logic               clk_peri_i,
  input logic               rst_peri_ni,

  input logic               clk_hr_i,
  input logic               clk_hr90p_i,
  input logic               clk_hr3x_i,
  input logic               rst_hrn_i,

  // Bus Interface
  input  tl_h2d_t tl_i,
  output tl_d2h_t tl_o,

  // HyperRAM:
  inout  wire [7:0]           HYPERRAM_DQ,
  inout  wire                 HYPERRAM_RWDS,
  output wire                 HYPERRAM_CKP,
  output wire                 HYPERRAM_CKN,
  output wire                 HYPERRAM_nRST,
  output wire                 HYPERRAM_CS
);
  localparam int unsigned HRAddrWidth = $clog2(HRSize);
  tl_d2h_t tl_o_pre;

  reg [1:0] state;
  localparam pS_IDLE            = 2'd0;
  localparam pS_WRITE           = 2'd1;
  localparam pS_READ            = 2'd2;
  localparam pS_ERROR           = 2'd3;

  reg axi_req_processed;

  reg  [31:0] awaddr;
  reg  awvalid;
  wire awready;
  // write data:
  reg  [31:0] wdata;
  reg         wuser;
  reg  wvalid;
  wire wready;
  // write response:
  wire [1:0] bresp;
  wire bvalid;
  wire bready;
  // read address:
  reg  [31:0] araddr;
  reg  arvalid;
  wire arready;
  // read data:
  wire [31:0] rdata;
  wire        ruser;
  wire [1:0] rresp;
  wire rvalid;
  wire rready;

  tl_d2h_t tl_o_int;


  // immutables:
  assign tl_o_int.d_source =  tl_i.a_source;
  assign tl_o_int.d_size =    tl_i.a_size;
  assign tl_o_int.d_param = 3'd0;
  assign tl_o_int.d_sink = 1'd0;
  assign tl_o_int.d_opcode = tl_o_pre.d_opcode;
  assign tl_o_int.a_ready = tl_o_pre.a_ready;
  assign tl_o_int.d_valid = tl_o_pre.d_valid;
  assign tl_o_int.d_data = tl_o_pre.d_data;
  assign tl_o_int.d_user = tl_o_pre.d_user;
  assign tl_o_int.d_error = tl_o_pre.d_error;

  tlul_rsp_intg_gen u_tlul_rsp_intg_gen (
    .tl_i(tl_o_int),
    .tl_o(tl_o)
  );

  wire awdone_condition = (awready && awvalid);
  wire wdone_condition = (wready && wvalid);
  wire ardone_condition = (arready && arvalid);
  reg awdone_r;
  reg wdone_r;
  reg ardone_r;
  wire awdone = awdone_r || awdone_condition;
  wire wdone  = wdone_r  || wdone_condition;
  wire ardone = ardone_r || ardone_condition;

  always @(posedge clk_peri_i) begin
      if (state == pS_IDLE) begin
          awdone_r <= 1'b0;
          wdone_r <= 1'b0;
          ardone_r <= 1'b0;
      end
      else begin
          if (awdone_condition)
              awdone_r <= 1'b1;
          if (wdone_condition)
              wdone_r <= 1'b1;
          if (ardone_condition)
              ardone_r <= 1'b1;
      end
  end

  localparam pTIMER_WIDTH = 18;
  reg [pTIMER_WIDTH-1:0] timer;

  always @(posedge clk_peri_i) begin
      if (~rst_peri_ni) begin
          // AXI defaults:
          awvalid <= 0;
          wvalid <= 0;
          arvalid <= 0;

          // TL defaults:
          tl_o_pre.a_ready <= 1'b1; // drive this low when not ready for a new request
          tl_o_pre.d_valid <= 1'b0;

          state <= pS_IDLE;
      end

      else begin
          case (state)

              pS_IDLE: begin
                  axi_req_processed <= 1'b0;
                  timer <= 0;
                  tl_o_pre.d_valid <= 1'b0;
                  if (tl_i.a_valid) begin
                      axi_req_processed <= 1'b0;
                      if ((tl_i.a_opcode == PutFullData) || (tl_i.a_opcode == PutPartialData)) begin
                          state <= pS_WRITE;
                          tl_o_pre.d_opcode <= AccessAck;
                          tl_o_pre.a_ready <= 1'b0;
                          //tl_o_pre.d_valid <= 1'b1; need to wait to see response first
                          wdata <= tl_i.a_data;
                          wuser <= tl_i.a_user.capability;
                          awaddr <= {{(32 - HRAddrWidth){1'b0}}, tl_i.a_address[HRAddrWidth-1:0]};
                          awvalid <= 1'b1;
                          wvalid <= 1'b1;
                      end

                      else if (tl_i.a_opcode == Get) begin
                          state <= pS_READ;
                          tl_o_pre.d_opcode <= AccessAckData;
                          araddr <= {{(32 - HRAddrWidth){1'b0}}, tl_i.a_address[HRAddrWidth-1:0]};
                          arvalid <= 1'b1;
                          tl_o_pre.a_ready <= 1'b0;
                      end

                      else begin
                          state <= pS_ERROR;
                          tl_o_pre.d_opcode <= AccessAck; // TODO: ?
                      end

                  end
                  else begin
                      tl_o_pre.a_ready <= 1'b1;
                  end
              end

              pS_WRITE: begin
                  // NOTE: could speed up here by assuming the write will go through? seems dangerous
                  timer <= timer + 1;
                  if (awready)
                      awvalid <= 0;
                  if (wready)
                      wvalid <= 0;
                  if (bvalid) begin
                      axi_req_processed <= 1'b1;
                      if (bresp == 0)
                          tl_o_pre.d_error <= 1'b0;
                      else
                          tl_o_pre.d_error <= 1'b1;
                  end
                  if (awdone && wdone && (bvalid || axi_req_processed))
                      tl_o_pre.d_valid <= 1'b1;
                      tl_o_pre.d_data <= rdata;
                      tl_o_pre.d_user <= '0;
                  if (timer == {pTIMER_WIDTH{1'b1}})
                      state <= pS_ERROR;
                  else if (tl_o_pre.d_valid && tl_i.d_ready) begin
                      state <= pS_IDLE;
                      tl_o_pre.d_valid <= 1'b0;
                      tl_o_pre.a_ready <= 1'b1;
                  end
              end

              pS_READ: begin
                  // this adds an additional cycle of latency on reads but keeps RTL simple
                  timer <= timer + 1;
                  if (arready)
                      arvalid <= 1'b0;
                  if (rvalid) begin
                      tl_o_pre.d_data  <= rdata;
                      tl_o_pre.d_user  <= '{capability: ruser, default: '0};
                      tl_o_pre.d_valid <= 1'b1;
                      axi_req_processed <= 1'b1;
                      if (rresp == 0)
                          tl_o_pre.d_error <= 1'b0;
                      else
                          tl_o_pre.d_error <= 1'b1;
                  end
                  if (timer == {pTIMER_WIDTH{1'b1}})
                      state <= pS_ERROR;
                  if (tl_i.d_ready && ardone && (rvalid || axi_req_processed)) begin
                      state <= pS_IDLE;
                      tl_o_pre.a_ready <= 1'b1;
                  end
              end

              pS_ERROR: begin
                  tl_o_pre.d_error <= 1'b1;
                  if (tl_i.d_ready) begin
                      state <= pS_IDLE;
                      tl_o_pre.d_valid <= 1'b1;
                  end
              end


          endcase
      end
  end

  assign bready = 1'b1;

  assign rready = state == pS_READ && 1'b1;


  OpenHBMC #(
    .HRClkFreq(HRClkFreq),
    .HRSize   (HRSize)
  ) U_HBMC (
    .clk_hbmc_0           (clk_hr_i   ),
    .clk_hbmc_90          (clk_hr90p_i),
    .clk_iserdes          (clk_hr3x_i ),

    .s_axi_aclk           (clk_peri_i),
    .s_axi_aresetn        (rst_hrn_i),

    .s_axi_awid           (0),
    .s_axi_awaddr         (awaddr),
    .s_axi_awlen          (0),
    .s_axi_awsize         (4),
    .s_axi_awburst        (0),
    .s_axi_awlock         (0),
    .s_axi_awregion       (0),
    .s_axi_awcache        (0),
    .s_axi_awqos          (0),
    .s_axi_awprot         (0),
    .s_axi_awvalid        (awvalid),
    .s_axi_awready        (awready),

    .s_axi_wdata          (wdata  ),
    .s_axi_wuser          (wuser  ),
    .s_axi_wstrb          (4'b1111),
    .s_axi_wlast          (1'b1   ),
    .s_axi_wvalid         (wvalid ),
    .s_axi_wready         (wready ),

    .s_axi_bid            (),             // unused (constant)
    .s_axi_bresp          (bresp  ),
    .s_axi_bvalid         (bvalid ),
    .s_axi_bready         (bready ),

    .s_axi_arid           (0),
    .s_axi_araddr         (araddr),
    .s_axi_arlen          (0),
    .s_axi_arsize         (4),
    .s_axi_arburst        (0),
    .s_axi_arlock         (0),
    .s_axi_arregion       (0),
    .s_axi_arcache        (0),
    .s_axi_arqos          (0),
    .s_axi_arprot         (0),
    .s_axi_arvalid        (arvalid),
    .s_axi_arready        (arready),

    .s_axi_rid            (),             // unused (constant)
    .s_axi_rdata          (rdata  ),
    .s_axi_ruser          (ruser  ),
    .s_axi_rresp          (rresp  ),
    .s_axi_rlast          (),             // unused (constant)
    .s_axi_rvalid         (rvalid ),
    .s_axi_rready         (rready ),

    .hb_dq                (HYPERRAM_DQ   ),
    .hb_rwds              (HYPERRAM_RWDS ),
    .hb_ck_p              (HYPERRAM_CKP  ),
    .hb_ck_n              (HYPERRAM_CKN  ),
    .hb_reset_n           (HYPERRAM_nRST ),
    .hb_cs_n              (HYPERRAM_CS   )
  );
endmodule
