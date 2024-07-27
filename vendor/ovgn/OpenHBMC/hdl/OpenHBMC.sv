// (c) Copyright 1995-2024 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: OVGN:user:OpenHBMC:2.0
// IP Revision: 83

`timescale 1ns/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module OpenHBMC import tlul_pkg::*; #(
  parameter HRClkFreq=100_000_000,
  parameter HRSize=1024 * 1024
) (
  input             clk_i,
  input             rst_ni,
  input             clk_hbmc_0,
  input             clk_hbmc_90,
  input             clk_iserdes,

  input  tl_h2d_t   tl_i,
  output tl_d2h_t   tl_o,

  output wire       hb_ck_p,
  output wire       hb_ck_n,
  output wire       hb_reset_n,
  output wire       hb_cs_n,
  inout  wire       hb_rwds,
  inout  wire [7:0] hb_dq
);

  hbmc_tl_top #(
    .C_HBMC_CLOCK_HZ(HRClkFreq),
    .C_HBMC_CS_MAX_LOW_TIME_US(4),
    .C_HBMC_FIXED_LATENCY(1'B0),
    .C_IDELAYCTRL_INTEGRATED(1'B0),
    .C_IODELAY_GROUP_ID("HBMC"),
    .C_IODELAY_REFCLK_MHZ(200),
    .C_HBMC_FPGA_DRIVE_STRENGTH(8),
    .C_HBMC_MEM_DRIVE_STRENGTH(46),
    .C_HBMC_FPGA_SLEW_RATE("SLOW"),
    .C_RWDS_USE_IDELAY(1'B0),
    .C_DQ7_USE_IDELAY(1'B0),
    .C_DQ6_USE_IDELAY(1'B0),
    .C_DQ5_USE_IDELAY(1'B0),
    .C_DQ4_USE_IDELAY(1'B0),
    .C_DQ3_USE_IDELAY(1'B0),
    .C_DQ2_USE_IDELAY(1'B0),
    .C_DQ1_USE_IDELAY(1'B0),
    .C_DQ0_USE_IDELAY(1'B0),
    .C_RWDS_IDELAY_TAPS_VALUE(0),
    .C_DQ7_IDELAY_TAPS_VALUE(0),
    .C_DQ6_IDELAY_TAPS_VALUE(0),
    .C_DQ5_IDELAY_TAPS_VALUE(0),
    .C_DQ4_IDELAY_TAPS_VALUE(0),
    .C_DQ3_IDELAY_TAPS_VALUE(0),
    .C_DQ2_IDELAY_TAPS_VALUE(0),
    .C_DQ1_IDELAY_TAPS_VALUE(0),
    .C_DQ0_IDELAY_TAPS_VALUE(0),
    .C_ISERDES_CLOCKING_MODE(0),
    .HRSize(HRSize)
  ) inst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .clk_hbmc_0(clk_hbmc_0),
    .clk_hbmc_90(clk_hbmc_90),
    .clk_iserdes(clk_iserdes),
    .clk_idelay_ref(1'B0),
    .tl_i(tl_i),
    .tl_o(tl_o),
    .hb_ck_p(hb_ck_p),
    .hb_ck_n(hb_ck_n),
    .hb_reset_n(hb_reset_n),
    .hb_cs_n(hb_cs_n),
    .hb_rwds(hb_rwds),
    .hb_dq(hb_dq)
  );
endmodule
