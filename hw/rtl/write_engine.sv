import afu_base::*;
import interface_debug::*;
import cci_mpf_if_pkg::*;

module WRITE_ENGINE (
    input logic clk,
    input logic stall, // Temporairly prevent writes (must be able to handle at least 3 requests after assertion)
    
    input e_afu_state   afu_state,
    input t_cci_clAddr  stts_addr,
    
    input t_cci_clAddr  wr_start_addr, // Output is streamed starting at this address
    i_fifo.to_consumer  wr_data_fifo,

    output logic        wr_valid,
    output t_cci_clAddr wr_addr,
    output t_cci_clData wr_data
);

    // Run Logic
    logic           r_wr_valid;
    t_cci_clAddr    r_wr_addr;
    t_cci_clData    r_wr_data;

    t_uint32        wr_offset; 
    t_uint32        run_cls_sent; 

    logic           valid_s1;
    t_cci_clData    wr_data_s1;

    assign wr_data_fifo.rd_en = ~stall && ~wr_data_fifo.empty;

    always_ff @(posedge clk) begin
        r_wr_valid  <= 0;
        r_wr_addr   <= wr_offset + wr_start_addr;
        r_wr_data   <= wr_data_fifo.data_out;
        
        unique case(afu_state)
            AFU_RUN: begin
                if (~stall && ~wr_data_fifo.empty) begin
                    r_wr_valid  <= 1;
                    wr_offset   <= wr_offset + 1;
                end
            end

            AFU_DONE: begin
                run_cls_sent <= wr_offset;
            end

            default: begin
                wr_offset <= '0; // wr_offset resets when not in run state
            end
        endcase
    end

    // Control logic
    logic        c_wr_valid;
    t_cci_clAddr c_wr_addr;
    t_cci_clData c_wr_data;

    logic to_send_stts_cl;

    always_ff @(posedge clk) begin
        c_wr_valid  <= 0;
        c_wr_addr   <= stts_addr;
        c_wr_data   <= constructStatusCL(STATUS_DONE, run_cls_sent);

        
        unique case(afu_state)
            AFU_CTRL: begin
                if (to_send_stts_cl && ~stall) begin // send status CL only once
                    c_wr_valid      <= 1;
                    to_send_stts_cl <= 0;
                end
            end

            AFU_DONE: begin
                to_send_stts_cl <= 1; // Only send status cl after a kernel run
            end

            default: begin
                to_send_stts_cl <= 0;
            end
        endcase
    end

    // Select wr signals based on state
    always_ff @(posedge clk) begin
        unique case(afu_state)
            AFU_CTRL: begin
                wr_valid    <= c_wr_valid;
                wr_addr     <= c_wr_addr;
                wr_data     <= c_wr_data;
            end

            AFU_RUN: begin
                wr_valid    <= r_wr_valid;
                wr_addr     <= r_wr_addr;
                wr_data     <= r_wr_data;
            end

            default: begin
                wr_valid    <= 0;
            end
        endcase
    end

endmodule