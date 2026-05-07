/*
 * Copyright (c) 2026 Tiny Tapeout LTD
 * SPDX-License-Identifier: Apache-2.0
 * Author: Jakub Rachon
 */

`default_nettype none

parameter LOGO_SIZE = 128;  // Size of the logo in pixels
parameter DISPLAY_WIDTH = 640;  // VGA display width
parameter DISPLAY_HEIGHT = 480;  // VGA display height

`define COLOR_WHITE 3'd7
`define PIX_BLACK 2'b00
`define PIX_WHITE 2'b01
`define PIX_RED   2'b11
// 2'b10 unused / transparent (optional)

module tt_um_magnetofield_hs3  (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  reg [1:0] R;
  reg [1:0] G;
  reg [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // Configuration
  wire cfg_tile = ui_in[0];
  wire cfg_color = ui_in[1];
  
  // TinyVGA PMOD
  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in[7:2], uio_in};

  reg [9:0] prev_y;

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  reg [9:0] logo_left;
  reg [9:0] logo_top;
  reg dir_x;
  reg dir_y;

  wire [1:0] pixel_value;
  reg [2:0] color_index;
  wire [5:0] color;

  wire [9:0] x = pix_x - logo_left;
  wire [9:0] y = pix_y - logo_top;
  wire logo_pixels = cfg_tile || (x[9:7] == 0 && y[9:6] == 0);

  bitmap_rom rom1 (
      .x(x[6:0]),
      .y(y[5:0]),
      .pixel(pixel_value)
      
  );

  palette palette_inst (
      .color_index(cfg_color ? color_index : `COLOR_WHITE),
      .rrggbb(color)
  );

  // RGB output logic
  always @(posedge clk) begin
    if (~rst_n) begin
      R <= 0;
      G <= 0;
      B <= 0;
    end else begin
      R <= 0;
      G <= 0;
      B <= 0;
  if (video_active && logo_pixels && !cfg_color) begin
      case (pixel_value)
        `PIX_BLACK: begin R<=0;       G<=0;       B<=0;       end
        `PIX_WHITE: begin R<=2'b11;   G<=2'b11;   B<=2'b11;   end
        `PIX_RED:   begin R<=2'b11;   G<=0;       B<=0;       end
        default:    begin R<=0;       G<=0;       B<=0;       end
      endcase
      end else if( video_active && cfg_color && logo_pixels) begin
        R <= pixel_value[0] ? color[5:4] : 0;
        G <= pixel_value[0] ? color[3:2] : 0;
        B <= pixel_value[0] ? color[1:0] : 0;
      end
    end
  end

  // Bouncing logic
  always @(posedge clk) begin
    if (~rst_n) begin
      logo_left <= 64;
      logo_top <= 64;
      prev_y <= 0;
      dir_y <= 0;
      dir_x <= 1;
      color_index <= 0;
    end else begin
      prev_y <= pix_y;
      if (pix_y == 0 && prev_y != pix_y) begin
        logo_left <= logo_left + (dir_x ? 1 : -1);
        logo_top  <= logo_top + (dir_y ? 1 : -1);
        if (logo_left - 1 == 0 && !dir_x) begin
          dir_x <= 1;
          color_index <= color_index + 1;
        end
        if (logo_left + 1 == DISPLAY_WIDTH - LOGO_SIZE && dir_x) begin
          dir_x <= 0;
          color_index <= color_index + 1;
        end
        if (logo_top - 1 == 0 && !dir_y) begin
          dir_y <= 1;
          color_index <= color_index + 1;
        end
          if (logo_top + 1 == DISPLAY_HEIGHT - 64 && dir_y) begin
          dir_y <= 0;
          color_index <= color_index + 1;
        end
      end
    end
  end

endmodule
