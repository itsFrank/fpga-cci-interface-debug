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

// Read FIFO config
localparam READ_RESP_FIFO_DEPTH         = 1024;
localparam READ_RESP_FIFO_DATA_WIDTH    = $bits(t_cci_clData);
localparam READ_RESP_FIFO_COUNT_WIDTH = $clog2(READ_RESP_FIFO_DEPTH);

// Write FIFO config
localparam WRITE_DATA_FIFO_DEPTH        = 64;
localparam WRITE_DATA_FIFO_DATA_WIDTH   = $bits(t_cci_clData);
localparam WRITE_DATA_FIFO_COUNT_WIDTH = $clog2(WRITE_DATA_FIFO_DEPTH);

// FIFO signals
// Read Response FIFO
i_fifo #(.DATA_WIDTH(READ_RESP_FIFO_DATA_WIDTH),    .COUNT_WIDTH(READ_RESP_FIFO_COUNT_WIDTH))   rd_resp_fifo();
i_fifo #(.DATA_WIDTH(WRITE_DATA_FIFO_DATA_WIDTH),   .COUNT_WIDTH(WRITE_DATA_FIFO_COUNT_WIDTH))  wr_data_fifo();
i_fifo #(.DATA_WIDTH(WRITE_DATA_FIFO_DATA_WIDTH),   .COUNT_WIDTH(WRITE_DATA_FIFO_COUNT_WIDTH))  dummy_data_fifo();

// FIFO Reset logic
always_ff @(posedge clk) begin
    rd_resp_fifo.reset  <= 0;
    wr_data_fifo.reset  <= 0;

    if (afu_state == AFU_CTRL) begin
        rd_resp_fifo.reset  <= 1;
        wr_data_fifo.reset  <= 1;
    end
end

// Read FIFO instance
SCFIFO
#(
    .FWFT("ON"),
    .DEPTH(READ_RESP_FIFO_DEPTH),
    .DATA_WIDTH(READ_RESP_FIFO_DATA_WIDTH),
    .COUNT_WIDTH(READ_RESP_FIFO_COUNT_WIDTH)
) READ_RESP_FIFO (
    .clock (clk),
    .fifo_if(rd_resp_fifo)
);

// Write FIFO instance
SCFIFO
#(
    .FWFT("ON"),
    .DEPTH(WRITE_DATA_FIFO_DEPTH),
    .DATA_WIDTH(WRITE_DATA_FIFO_DATA_WIDTH),
    .COUNT_WIDTH(WRITE_DATA_FIFO_COUNT_WIDTH),
    .ALM_FULL_DIFF(FIFO_ALM_FULL_BUFFER)
) WRITE_DATA_FIFO (
    .clock (clk),
    .fifo_if(wr_data_fifo)
);

`endif