// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package rgbled_ctrl_reg_pkg;

  // Address widths within the block
  parameter int BlockAw = 4;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    struct packed {
      logic [7:0]  q;
      logic        qe;
    } b;
    struct packed {
      logic [7:0]  q;
      logic        qe;
    } g;
    struct packed {
      logic [7:0]  q;
      logic        qe;
    } r;
  } rgbled_ctrl_reg2hw_rgbled0_reg_t;

  typedef struct packed {
    struct packed {
      logic [7:0]  q;
      logic        qe;
    } b;
    struct packed {
      logic [7:0]  q;
      logic        qe;
    } g;
    struct packed {
      logic [7:0]  q;
      logic        qe;
    } r;
  } rgbled_ctrl_reg2hw_rgbled1_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
      logic        qe;
    } off;
    struct packed {
      logic        q;
      logic        qe;
    } setrgb;
  } rgbled_ctrl_reg2hw_ctrl_reg_t;

  typedef struct packed {
    logic        d;
  } rgbled_ctrl_hw2reg_status_reg_t;

  // Register -> HW type
  typedef struct packed {
    rgbled_ctrl_reg2hw_rgbled0_reg_t rgbled0; // [57:31]
    rgbled_ctrl_reg2hw_rgbled1_reg_t rgbled1; // [30:4]
    rgbled_ctrl_reg2hw_ctrl_reg_t ctrl; // [3:0]
  } rgbled_ctrl_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    rgbled_ctrl_hw2reg_status_reg_t status; // [0:0]
  } rgbled_ctrl_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] RGBLED_CTRL_RGBLED0_OFFSET = 4'h 0;
  parameter logic [BlockAw-1:0] RGBLED_CTRL_RGBLED1_OFFSET = 4'h 4;
  parameter logic [BlockAw-1:0] RGBLED_CTRL_CTRL_OFFSET = 4'h 8;
  parameter logic [BlockAw-1:0] RGBLED_CTRL_STATUS_OFFSET = 4'h c;

  // Reset values for hwext registers and their fields
  parameter logic [23:0] RGBLED_CTRL_RGBLED0_RESVAL = 24'h 0;
  parameter logic [7:0] RGBLED_CTRL_RGBLED0_R_RESVAL = 8'h 0;
  parameter logic [7:0] RGBLED_CTRL_RGBLED0_G_RESVAL = 8'h 0;
  parameter logic [7:0] RGBLED_CTRL_RGBLED0_B_RESVAL = 8'h 0;
  parameter logic [23:0] RGBLED_CTRL_RGBLED1_RESVAL = 24'h 0;
  parameter logic [7:0] RGBLED_CTRL_RGBLED1_R_RESVAL = 8'h 0;
  parameter logic [7:0] RGBLED_CTRL_RGBLED1_G_RESVAL = 8'h 0;
  parameter logic [7:0] RGBLED_CTRL_RGBLED1_B_RESVAL = 8'h 0;
  parameter logic [1:0] RGBLED_CTRL_CTRL_RESVAL = 2'h 0;
  parameter logic [0:0] RGBLED_CTRL_STATUS_RESVAL = 1'h 0;

  // Register index
  typedef enum int {
    RGBLED_CTRL_RGBLED0,
    RGBLED_CTRL_RGBLED1,
    RGBLED_CTRL_CTRL,
    RGBLED_CTRL_STATUS
  } rgbled_ctrl_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] RGBLED_CTRL_PERMIT [4] = '{
    4'b 0111, // index[0] RGBLED_CTRL_RGBLED0
    4'b 0111, // index[1] RGBLED_CTRL_RGBLED1
    4'b 0001, // index[2] RGBLED_CTRL_CTRL
    4'b 0001  // index[3] RGBLED_CTRL_STATUS
  };

endpackage
