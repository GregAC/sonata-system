`timescale 1ns/1ps

module hyperram_tb;
  import tlul_pkg::*;

  wire [7:0] HYPERRAM_DQ;
  wire       HYPERRAM_RWDS;
  wire       HYPERRAM_CKP;
  wire       HYPERRAM_CKN;
  wire       HYPERRAM_nRST;
  wire       HYPERRAM_CS;

  reg clk_peri;
  reg clk_hr;
  reg clk_hr90p;
  reg clk_hr3x;
  reg rst_peri_n;
  reg rst_hr;

  tl_h2d_t test_tl_i;
  tl_d2h_t test_tl_o;

  logic do_xfer, do_read, tag_bit;
  logic [31:0] address;

  assign test_tl_i.a_valid = do_xfer;
  assign test_tl_i.a_opcode = do_read ? Get : PutFullData;
  assign test_tl_i.a_param = '0;
  assign test_tl_i.a_size = 2;
  assign test_tl_i.a_source = '0;
  assign test_tl_i.a_address = address;
  assign test_tl_i.a_mask = '1;
  assign test_tl_i.a_data = {16'hDEAD, address[17:2]};
  assign test_tl_i.a_user = '{capability: tag_bit, default: '0};
  assign test_tl_i.d_ready = 1'b1;


  initial begin
    rst_peri_n = 1'b0;
    rst_hr = 1'b1;
    #2;
    rst_peri_n = 1'b1;
    rst_hr = 1'b0;
    #27;
    rst_peri_n = 1'b0;
    rst_hr = 1'b1;
    #35;
    rst_peri_n = 1'b1;
    rst_hr = 1'b0;
  end

  initial begin
    clk_peri = 1'b0;
    forever begin
      #10 clk_peri = ~clk_peri;
    end
  end

  initial begin
    clk_hr    = 1'b0;
    clk_hr90p = 1'b0;
    clk_hr3x  = 1'b0;

    fork
      forever begin
        #5 clk_hr = ~clk_hr;
      end
      begin
        #2.5;
        forever begin
          #5 clk_hr90p = ~clk_hr90p;
        end
      end
      forever begin
        #1.66 clk_hr3x = ~clk_hr3x;
        #1.67 clk_hr3x = ~clk_hr3x;
        #1.67 clk_hr3x = ~clk_hr3x;
      end
    join
  end

  logic [5:0] start_count;

  always @(posedge clk_peri or negedge rst_peri_n) begin
    if (!rst_peri_n) begin
      do_read     <= 1'b0;
      do_xfer     <= 1'b0;
      tag_bit     <= 1'b0;
      address     <= '0;
      start_count <= '0;
    end else if (start_count != 6'h3f) begin
      start_count <= start_count + 6'd1;
      if (start_count == 6'h3e) begin
        do_xfer <= 1'b1;
      end
    end else begin
      if (do_xfer && test_tl_o.a_ready) begin
        if (do_read) begin
          address <= address + 32'd4;
          tag_bit <= ~tag_bit;
        end
        do_xfer <= 1'b0;
        do_read <= ~do_read;
      end else if (test_tl_o.d_valid) begin
        do_xfer <= 1'b1;
      end
    end
  end

  OpenHBMC u_hbmc (
    .clk_i      (clk_peri),
    .rst_ni     (rst_peri_n),

    .clk_hbmc_0 (clk_hr),
    .clk_hbmc_90(clk_hr90p),
    .clk_iserdes(clk_hr3x),

    // TL:
    .tl_i        (test_tl_i),
    .tl_o        (test_tl_o),

    // HR:
    .hb_dq     (HYPERRAM_DQ),
    .hb_rwds   (HYPERRAM_RWDS),
    .hb_ck_p   (HYPERRAM_CKP),
    .hb_ck_n   (HYPERRAM_CKN),
    .hb_reset_n(HYPERRAM_nRST),
    .hb_cs_n   (HYPERRAM_CS)
  );

  s27kl0642 bfm(
    .DQ7(HYPERRAM_DQ[7]),
    .DQ6(HYPERRAM_DQ[6]),
    .DQ5(HYPERRAM_DQ[5]),
    .DQ4(HYPERRAM_DQ[4]),
    .DQ3(HYPERRAM_DQ[3]),
    .DQ2(HYPERRAM_DQ[2]),
    .DQ1(HYPERRAM_DQ[1]),
    .DQ0(HYPERRAM_DQ[0]),
    .RWDS(HYPERRAM_RWDS),
    .CSNeg(HYPERRAM_CS),
    .CK(HYPERRAM_CKP),
  	.CKn(HYPERRAM_CKN),
    .RESETNeg(HYPERRAM_nRST)
  );

  //supply1 vcc;
  //supply0 vss;

  //W956D8MBYA u_hr_bfm (
  //  .adq(HYPERRAM_DQ),
  //  .clk(HYPERRAM_CKP),
  //  .clk_n(HYPERRAM_CKN),
  //  .csb(HYPERRAM_CS),
  //  .rwds(HYPERRAM_RWDS),
  //  .VCC(vcc),
  //  .VSS(vss),
  //  .resetb(HYPERRAM_nRST)
  //);
endmodule
