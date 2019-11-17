import afu_base::*;
import interface_debug::*;
import cci_mpf_if_pkg::*;

module READ_ENGINE (
    input logic clk,
    input logic stall,

    input e_afu_state       afu_state,
    input t_cci_clAddr      ctrl_addr,
    ctrl_resp_if.to_module  ctrl_resp,

    output logic        rd_valid,
    output t_cci_mdata  rd_mdata,
    output t_cci_clAddr rd_addr,

    output logic run_done
);
    
    // Run logic
    logic        r_rd_valid;
    t_cci_mdata  r_mdata;
    t_cci_clAddr r_addr;

    t_cci_clAddr    last_cl;
    t_cci_clAddr    current_cl;
    t_cci_clAddr    run_start_addr;
    t_uint32        run_num_cls;

    logic           rd_valid_s1;
    logic           rd_valid_s2;
    t_cci_clAddr    r_addr_s1;
    t_cci_clAddr    r_addr_s2;
    always_ff @(posedge clk) begin
        rd_valid_s1  <= 0;

        r_rd_valid  <= rd_valid_s2 && ~run_done;
        r_mdata     <= READ_RUN_MDATA;
        r_addr      <= r_addr_s2;

        last_cl     <= run_start_addr + run_num_cls;
        run_done    <= current_cl > last_cl;
        
        rd_valid_s2 <= rd_valid_s1;
        r_addr_s2   <= r_addr_s1;

        unique case(afu_state)
            AFU_RUN: begin
                if (~stall) begin
                    rd_valid_s1     <= 1;
                    r_addr_s1       <= current_cl;
                    current_cl      <= current_cl + 1;
                end
            end

            AFU_CTRL: begin
                if (ctrl_resp.valid && ctrl_resp.code == CONTROL_START_RUN) begin
                    current_cl      <= ctrl_resp.rd_addr;
                    run_start_addr  <= ctrl_resp.rd_addr;
                    run_num_cls     <= ctrl_resp.num_cls;
                end
            end

            default: begin
            end
        endcase
    end

    // Control polling logic
    logic wait_ctrl_resp;

    logic        c_rd_valid;
    t_cci_mdata  c_mdata;
    t_cci_clAddr c_addr;

    always_ff @(posedge clk) begin
        c_rd_valid  <= 0;
        c_addr      <= ctrl_addr;
        c_mdata     <= READ_CTRL_MDATA;
        
        unique case(afu_state)
            AFU_CTRL: begin
                if (~wait_ctrl_resp && ~stall) begin
                    c_rd_valid          <= 1;
                    wait_ctrl_resp      <= 1;
                end
                else if (ctrl_resp.ack) begin
                    wait_ctrl_resp <= 0;             
                end
            end

            default: begin
                wait_ctrl_resp <= 0;
            end
        endcase
    end

    // Select rd signals based on state
    always_ff @(posedge clk) begin
        unique case(afu_state)
            AFU_CTRL: begin
                rd_valid    <= c_rd_valid;
                rd_mdata    <= c_mdata;
                rd_addr     <= c_addr;
            end

            AFU_RUN: begin
                rd_valid    <= r_rd_valid;
                rd_mdata    <= r_mdata;
                rd_addr     <= r_addr;
            end

            default: begin
                rd_valid    <= 0;
            end
        endcase
    end
endmodule