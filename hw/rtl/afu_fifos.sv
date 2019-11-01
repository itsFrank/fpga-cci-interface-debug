`ifndef AFU_FIFOS_SV 
`define AFU_FIFOS_SV

/*
    This file contains the FIFO definitions for all the FIFOS that reside in the top-level module
    I put them here to de-clutter the main file since most of this FIFO stuff is very repetitive and obvious
*/

// Imports unecessary since this file will be included in the top level module
// import afu_base::*;
// import interface_debug::*;

localparam FIFO_ALM_FULL_BUFFER = 16;

// FIFO depth config
localparam READ_RESP_FIFO_DEPTH = 512;

// FIFO data config
localparam READ_RESP_FIFO_DATA_WIDTH = $bits(t_cci_clData);
localparam READ_RESP_FIFO_COUNT_WIDTH = $clog2(READ_RESP_FIFO_DEPTH);

// FIFO signals
// Read Response FIFO
i_fifo #(.DATA_WIDTH(READ_RESP_FIFO_DATA_WIDTH), .COUNT_WIDTH(READ_RESP_FIFO_COUNT_WIDTH)) rd_resp_fifo();

// FIFO Reset logic
always_ff @(posedge clk) begin
    rd_resp_fifo.reset <= 0;

    if (afu_state == AFU_CTRL) begin
        rd_resp_fifo.reset <= 1;
    end
end

SCFIFO
#(
    .FWFT("ON"),
    .DEPTH(READ_RESP_FIFO_DEPTH),
    .DATA_WIDTH(READ_RESP_FIFO_DATA_WIDTH),
    .COUNT_WIDTH(READ_RESP_FIFO_COUNT_WIDTH),
    .ALM_EMPTY_DIFF(2)
) READ_RESP_FIFO (
    .clock (clk),
    .fifo_if(rd_resp_fifo)
);

`endif