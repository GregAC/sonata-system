`timescale 1ns/1ps

import tlul_pkg::*;
import top_pkg::*;

`define LOG_PRIO 0
`define LOG_FAIL 1
`define LOG_WARN 2
`define LOG_INFO 3
`define LOG_DEBUG 4

`define LOG_VERBOSITY `LOG_INFO

function string verbosity_to_str(int verbosity);
  case (verbosity)
    `LOG_PRIO:  return "PRIO";
    `LOG_FAIL:  return "FAIL";
    `LOG_WARN:  return "WARN";
    `LOG_INFO:  return "INFO";
    `LOG_DEBUG: return "DBG ";
    default:    return "UNKN";
  endcase
endfunction

`define TB_LOG(verbosity, message) if (verbosity <= `LOG_VERBOSITY) begin \
  $display("%t: [%s] %s", $realtime(), verbosity_to_str(verbosity), message); \
end

class tl_req;
  rand bit [31:0]       addr;
  rand bit [TL_AIW-1:0] id;
  rand bit [31:0]       data;
  rand bit              write;
  rand bit              capability;
  rand bit [3:0]        mask;

  constraint addr_aligned {
    addr[1:0] == 2'b00;
  }

  constraint mask_valid {
    if (write) mask inside {4'b0001, 4'b0010, 4'b0100, 4'b1000, 4'b0011, 4'b1100, 4'b1111};
    else mask == 4'b1111;

    solve write before mask;
  }

  function string to_string();
    return $sformatf("Addr: %x\nID: %x\nData: %x\nMask: %b\nWrite: %b", addr, id, data, mask,
      write);
  endfunction

  function bit check_expected(tl_d2h_t tl_d2h, output string failure_info);
    if (tl_d2h.d_opcode == AccessAckData) begin
      bit [31:0] full_mask;

      full_mask = {{8{mask[3]}}, {8{mask[2]}}, {8{mask[1]}}, {8{mask[0]}}};

      if (write) begin
        failure_info = $sformatf("Saw read response expected write response for address %08x",
          addr);
        return 1;
      end

      if ((tl_d2h.d_data & full_mask) != (data & full_mask)) begin
        failure_info =
          $sformatf("Expected read data %08x, got read data %08x for address %08x, mask %08x",
            data, tl_d2h.d_data, addr, full_mask);
        return 1;
      end

      if (tl_d2h.d_user.capability != capability) begin
        failure_info = $sformatf("Expected cap bit %b, got cap bit %b for address %08x",
          capability, tl_d2h.d_user.capability, addr);
        return 1;
      end
    end

    if (tl_d2h.d_source != id) begin
      failure_info = $sformatf("Expected source ID %x, got ID %x for address %08x",
        id, tl_d2h.d_source, addr);
      return 1;
    end

    return 0;
  endfunction
endclass

virtual class req_gen;
  pure virtual function tl_req gen_req();
endclass

class sequential_wr_rd_req_gen extends req_gen;
  bit [31:0] start_addr;
  bit [31:0] cur_addr;
  bit        interleave;
  int        length;
  bit        full_writes;

  bit        write;
  int        reqs_this_phase;

  function new(bit [31:0] start_addr_, int length_, bit interleave_, bit full_writes_);
    start_addr      = start_addr_;
    cur_addr        = start_addr_;
    interleave      = interleave_;
    length          = length_;
    full_writes     = full_writes_;

    write           = 1'b1;
    reqs_this_phase = 0;
  endfunction

  virtual function tl_req gen_req();
    tl_req req = new();

    req.randomize() with {
      if (full_writes) mask == 4'b1111;
      addr == cur_addr;
    };

    req.write = write;

    if (interleave) begin
      if (write) begin
        write = 1'b0;
      end else begin
        write = 1'b1;
        reqs_this_phase++;

        if (reqs_this_phase == length) begin
          cur_addr = start_addr;
          reqs_this_phase = 0;
        end else begin
          cur_addr += 32'd4;
        end
      end
    end else begin
      reqs_this_phase++;

      if (reqs_this_phase == length) begin
        write = ~write;
        cur_addr = start_addr;
        reqs_this_phase = 0;
      end else begin
        cur_addr += 32'd4;
      end
    end

    return req;
  endfunction
endclass

class random_wr_rd_req_gen extends req_gen;
  bit [3:0] addresses_written [bit[31:0]];
  bit [31:0] addresses_written_queue[$];

  bit [31:0] lower_addr_bound;
  bit [31:0] upper_addr_bound;

  bit only_read_written;

  function new(bit[31:0] lower_addr_bound_, bit[31:0] upper_addr_bound_, bit only_read_written_);
    lower_addr_bound  = lower_addr_bound_;
    upper_addr_bound  = upper_addr_bound_;
    only_read_written = only_read_written_;
  endfunction

  virtual function tl_req gen_req();
    tl_req req = new();

    req.randomize() with {
      addr >= lower_addr_bound;
      addr < upper_addr_bound;

      if (only_read_written && addresses_written.size() == 0)
        write == 1;
    };

    if (only_read_written) begin
      if (req.write) begin
        if(addresses_written.exists(req.addr)) begin
          addresses_written[req.addr] |= req.mask;
        end else begin
          addresses_written[req.addr] = req.mask;
          addresses_written_queue.push_back(req.addr);
        end
      end else begin
        int address_idx = $urandom_range(addresses_written_queue.size() - 1, 0);
        req.addr = addresses_written_queue[address_idx];
        req.mask = addresses_written[req.addr];
      end
    end

    return req;
  endfunction
endclass

function bit [31:0] mask_write(bit [31:0] original, bit [31:0] wr_data, bit [3:0] wr_mask);
  return {wr_mask[3] ? wr_data[31:24] : original[31:24],
          wr_mask[2] ? wr_data[23:16] : original[23:16],
          wr_mask[1] ? wr_data[15:8]  : original[15:8],
          wr_mask[0] ? wr_data[7:0]   : original[7:0]};
endfunction

module tl_agent #(
  parameter int unsigned MemSize = (1 * 1024 * 1024) / 4
) (
  input  clk_i,
  input  rst_ni,

  output tl_h2d_t tl_h2d_o,
  input  tl_d2h_t tl_d2h_i
);
  localparam int MemAddrW = $clog2(MemSize);

  logic [31:0] mem [MemSize];
  logic tag_bits [MemSize/2];
  int failures;

  tl_req   expected_queue [$];
  tl_h2d_t tl_h2d_req;
  logic    d_ready;

  always_comb begin
    tl_h2d_o         = tl_h2d_req;
    tl_h2d_o.d_ready = d_ready;
  end

  initial begin
    tl_h2d_req = '0;
  end

  task run_requests(req_gen rg, int num_requests);
    int requests_sent;
    requests_sent = 0;

    @(posedge clk_i);

    while (requests_sent != num_requests) begin
      int send_delay;
      tl_req next_req;

      send_delay = $urandom_range(10, 0);
      next_req = rg.gen_req();

      `TB_LOG(`LOG_DEBUG, $sformatf("Got req\n%s", next_req.to_string()))

      repeat (send_delay) @(posedge clk_i);

      tl_h2d_req.a_valid           <= 1'b1;
      tl_h2d_req.a_address         <= next_req.addr;

      if (next_req.write) begin
        if (&next_req.mask) begin
          tl_h2d_req.a_opcode <= PutFullData;
        end else begin
          tl_h2d_req.a_opcode <= PutPartialData;
        end
      end else begin
        tl_h2d_req.a_opcode <= Get;
      end

      tl_h2d_req.a_opcode          <= next_req.write ? PutFullData : Get;
      tl_h2d_req.a_data            <= next_req.data;
      tl_h2d_req.a_user.capability <= next_req.capability;
      tl_h2d_req.a_mask            <= next_req.mask;
      tl_h2d_req.a_source          <= next_req.id;

      @(posedge clk_i);
      while (!tl_d2h_i.a_ready) @(posedge clk_i);

      if (next_req.write) begin
        mem[next_req.addr[MemAddrW+1:2]] <= mask_write(mem[next_req.addr[MemAddrW+1:2]],
          next_req.data, next_req.mask);
        tag_bits[next_req.addr[MemAddrW+1:3]] <= next_req.capability;
      end else begin
        next_req.data = mem[next_req.addr[MemAddrW+1:2]];
        next_req.capability = tag_bits[next_req.addr[MemAddrW+1:3]];
        `TB_LOG(`LOG_DEBUG, $sformatf("Expected data %08x cap bit %b mask %b for read from %08x",
          next_req.data, next_req.capability, next_req.mask, next_req.addr))
      end

      expected_queue.push_back(next_req);

      tl_h2d_req.a_valid <= 1'b0;

      requests_sent += 1;

      if ((requests_sent % 1000) == 0) begin
        `TB_LOG(`LOG_INFO, $sformatf("%d requests sent", requests_sent))
      end

    end
  endtask

  task wait_idle();
    forever begin
      @(posedge clk_i);
      if (expected_queue.size() == 0) begin
        return;
      end
    end
  endtask

  initial begin
    failures = 0;
    forever begin
      @(posedge clk_i);
      if (tl_d2h_i.d_valid && tl_h2d_o.d_ready) begin
        string failure_string;
        tl_req expected_req;

        if (expected_queue.size() == 0) begin
          failures += 1;
          `TB_LOG(`LOG_FAIL, $sformatf("Saw a response but none were expected"))
          continue;
        end

        expected_req = expected_queue.pop_front();

        `TB_LOG(`LOG_DEBUG, $sformatf("Got a response expected is: %s", expected_req.to_string()))

        if (expected_req.check_expected(tl_d2h_i, failure_string)) begin
          `TB_LOG(`LOG_FAIL, $sformatf("Response did not match expectation: %s", failure_string))
          failures += 1;
        end else begin
          `TB_LOG(`LOG_DEBUG, "Response was correct")
        end
      end
    end
  end

  initial begin
    int wait_cycles;
    d_ready = 1'b0;
    forever begin
      wait_cycles = $urandom_range(10, 1);
      repeat (wait_cycles) @(posedge clk_i);
      d_ready <= ~d_ready;
    end
  end
endmodule

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

  initial begin
    $timeformat(-9, 1, " ns", 13);
  end

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

  localparam int SeqSequenceMemSize = 128 * 1024;
  localparam int MemModelSizeBytes = 1024 * 1024;

  tl_agent #(
    .MemSize(MemModelSizeBytes / 4)
  ) u_tl_agent (
    .clk_i(clk_peri),
    .rst_ni(rst_peri_n),
    .tl_h2d_o(test_tl_i),
    .tl_d2h_i(test_tl_o)
  );

  initial begin
    sequential_wr_rd_req_gen seq_rg;
    random_wr_rd_req_gen rnd_rg;

    seq_rg = new(0, SeqSequenceMemSize / 4, 1'b0, 1'b1);

    repeat (32) @(posedge clk_peri);

    `TB_LOG(`LOG_INFO, "Doing sequential write/read for first 128k");
    u_tl_agent.run_requests(seq_rg, SeqSequenceMemSize / 2);

    seq_rg  = new(0, SeqSequenceMemSize / 4, 1'b1, 1'b0); // First 128k
    `TB_LOG(`LOG_INFO, "Doing interleaved write/read for first 128k");
    u_tl_agent.run_requests(seq_rg, SeqSequenceMemSize / 2);

    rnd_rg = new(0, SeqSequenceMemSize, 1'b0);
    `TB_LOG(`LOG_INFO, "Doing random write/read for first 128k");
    u_tl_agent.run_requests(rnd_rg, SeqSequenceMemSize / 2);

    rnd_rg = new(0, MemModelSizeBytes, 1'b1);
    `TB_LOG(`LOG_INFO, "Doing full random write/read");
    u_tl_agent.run_requests(rnd_rg, SeqSequenceMemSize / 2);

    u_tl_agent.wait_idle();

    if (u_tl_agent.failures == 0) begin
      `TB_LOG(`LOG_PRIO, "PASS! No failures seen")
    end else begin
      `TB_LOG(`LOG_FAIL, $sformatf("FAIL! Saw %d failures", u_tl_agent.failures))
    end

    $finish();
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
