// Standard fifo interface
interface i_fifo
#(
    parameter DATA_WIDTH = 512,
    parameter COUNT_WIDTH = 32
);
    logic reset;
    logic wr_en;
    logic rd_en;
    logic [DATA_WIDTH - 1:0] data_in;
    
    logic full;
    logic empty;
    logic alm_full;
    logic alm_empty;
    logic [DATA_WIDTH - 1:0] data_out;
    logic [COUNT_WIDTH - 1:0] count;

    modport to_fifo (
        input reset,
        input wr_en,
        input rd_en,
        input data_in,
        
        output full,
        output alm_full,
        output empty,
        output alm_empty,
        output data_out,
        output count
    );

    modport to_consumer (
        output rd_en, 
        input empty,
        input alm_empty,
        input data_out,
        input count
    );

    modport as_output (
        input rd_en, 
        output empty,
        output alm_empty,
        output data_out,
        output count
    );

    modport to_producer (
        input wr_en,
        input data_in,
        output full,
        output alm_full,
        output count
    );
endinterface // i_fifo