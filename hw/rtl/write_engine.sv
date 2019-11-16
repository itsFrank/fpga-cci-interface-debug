import afu_base::*;
import interface_debug::*;
import cci_mpf_if_pkg::*;

module WRITE_ENGINE (
    input logic clk,
    input logic reset, // reset will be asserted whenever the afu is not in the run state
    input logic stall,

    input t_cci_clAddr  wr_start_addr,
    i_fifo.to_consumer  wr_data_fifo,

    output logic        wr_valid,
    output t_cci_clAddr wr_addr,
    output t_cci_clData wr_data
);

t_uint32 wr_offset; 

logic           valid_s1;
t_cci_clData     wr_data_s1;

assign wr_data_fifo.rd_en = ~stall && ~wr_data_fifo.empty && ~reset;

always_ff @(posedge clk) begin
    wr_valid    <= valid_s1;
    wr_addr     <= wr_offset + wr_start_addr;
    wr_data     <= wr_data_fifo.data_out;

    valid_s1    <= 0;
    
    if (reset) begin
        if (~stall && ~wr_data_fifo.empty) begin
            valid_s1    <= 1;
            wr_offset   <= wr_offset + 1;
        end
    end
    else begin
        wr_offset <= '0; // wr_offset resets when not in run state
    end
end
endmodule