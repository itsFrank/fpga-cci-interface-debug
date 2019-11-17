`include "cci_mpf_if.vh"
`include "csr_mgr.vh"

import afu_base::*;
import interface_debug::*;

module app_afu (
    input logic clk,

    // Connection toward the host.  Reset comes in here.
    cci_mpf_if.to_fiu fiu,

    // CSR connections
    app_csrs.app csrs,

    // MPF tracks outstanding requests.  These will be true as long as
    // reads or unacknowledged writes are still in flight.
    input  logic c0NotEmpty,
    input  logic c1NotEmpty
);

    // Local reset to reduce fan-out
    logic reset = 1'b1;
    always_ff @(posedge clk) begin
        reset <= fiu.reset;
    end

    // The start control signal
    reg start;

	/********************************************/
	/*  GLOBAL SIGNALS							*/
	/********************************************/
	e_afu_state afu_state;

	// FROM CSRs
    t_ccip_clAddr afu_ctrl_addr; // REG 1 - Control word from CPU to AFU (used by CPU to tell AFU to begin a kernel run)
    t_ccip_clAddr afu_stts_addr; // REG 2 - Control word from AFU to CPU (used by AFU to tell CPU it has completed a kernel run)

	// Request Headers
		// Read
		logic 				rd_interface_busy; // Asserted when there are un-acknowledged requests
		logic 				rd_valid;
		rd_req_hdr_config_t rd_hdr;                  
		
		t_uint32 rd_resp_fifo_overflow_risk; // Tracks if additional outstanding reads would risk overflowing the FIFO 

		// Write 
		logic 				wr_interface_busy; // Asserted when there requests still not committed to the channel
		logic 				wr_valid;
		t_cci_clData 		wr_data;
		wr_req_hdr_config_t wr_hdr;

	logic 			ctrl_resp_valid;
	t_cci_clData 	ctrl_resp_data;
	ctrl_resp_if 	ctrl_resp(clk, reset, ctrl_resp_valid, ctrl_resp_data);

	//------ CSRs From CPU ------
	reg [63:0] cpu_wr_csrs[7:0];

	always_ff @(posedge clk) begin
		afu_ctrl_addr <= byteAddrToClAddr(cpu_wr_csrs[1]);
		afu_stts_addr <= byteAddrToClAddr(cpu_wr_csrs[2]);
	end

	/********************************************/
	/*  AFU Compute Logic						*/
	/********************************************/

	// You will probably want to have modules here to consume the contents of the read response FIFO
	// Currently the AFU simply writes the requested CLs back to a second buffer
	// Any CL in the rd resp FIFO is just forwarded to the wr data FIFO
	
	logic [4:0] afu_done_counter;
	t_uint32 num_cls_processed;

	assign rd_resp_fifo.rd_en = ~rd_resp_fifo.empty && ~wr_data_fifo.alm_full;

	always_ff @(posedge clk) begin
		wr_data_fifo.wr_en 		<= 0;
		wr_data_fifo.data_in 	<= rd_resp_fifo.data_out;

		if (~rd_resp_fifo.empty && ~wr_data_fifo.alm_full) begin // data in rd FIFO and space in wr FIFO
			wr_data_fifo.wr_en <= 1;
		end

		unique case(afu_state)
			AFU_RUN: begin
				if (~rd_resp_fifo.empty && ~wr_data_fifo.alm_full) begin // data in rd FIFO and space in wr FIFO
					wr_data_fifo.wr_en <= 1;
					num_cls_processed <= num_cls_processed + 1;
				end

				if (num_cls_processed == ctrl_resp.num_cls && wr_data_fifo.empty) begin
					afu_done_counter <= afu_done_counter + 1;
				end
				else begin
					afu_done_counter <= '0;
				end
			end

			default: begin
				num_cls_processed 	<= '0;
				afu_done_counter	<= '0;
			end
		endcase
	end


	/********************************************/
	/*  AFU FIFOs								*/
	/********************************************/

	`include "afu_fifos.sv" // FIFO definition and basic logic

	/********************************************/
	/*  AFU State Control						*/
	/********************************************/
	logic afu_run_done;
	e_afu_state afu_next_state;

	always_ff @(posedge clk) begin
		afu_run_done <= afu_done_counter >= 4'd8;

		if (reset) begin
			afu_state <= AFU_IDLE;
		end
		else begin
			afu_state <= afu_next_state;
		end
	end

	always_comb begin
		afu_next_state = afu_state; 

		unique case(afu_state)
			AFU_IDLE: begin
				if (start) 
					afu_next_state = AFU_CTRL;
			end

			AFU_CTRL: begin
				if (ctrl_resp.valid) begin
					if (ctrl_resp.code == CONTROL_START_RUN)
						afu_next_state = AFU_RUN;
					if (ctrl_resp.code == CONTROL_AFU_SHUTDOWN)
						afu_next_state = AFU_SHUTDOWN_WAIT; 
				end
			end

			AFU_RUN: begin
				if (afu_run_done)
					afu_next_state = AFU_DONE;
			end

			AFU_DONE: begin
				if (~rd_interface_busy && ~wr_interface_busy) // Wait for both rd and wr interfaces to clear before returning to control state
					afu_next_state = AFU_CTRL;
			end

			AFU_SHUTDOWN_WAIT: begin
				if (~rd_interface_busy && ~wr_interface_busy) // Wait for both rd and wr interfaces to clear before shutting down
					afu_next_state = AFU_SHUTDOWN;
			end

			AFU_SHUTDOWN: begin
				afu_next_state = AFU_SHUTDOWN; // The only way out of this state is through a reset
			end

			default: begin
				afu_next_state = AFU_IDLE;
			end
		endcase
	end

	/********************************************/
	/*  AFU Response Handling					*/
	/********************************************/
	t_uint32 num_cls_recieved;

	always_ff @(posedge clk) begin
		ctrl_resp_valid <= 0;
		ctrl_resp_data 	<= fiu.c0Rx.data;

		rd_resp_fifo.wr_en		<= 0;
		rd_resp_fifo.data_in	<= fiu.c0Rx.data;

		if (cci_c0Rx_isReadRsp(fiu.c0Rx) && (fiu.c0Rx.hdr.mdata == READ_CTRL_MDATA)) begin                                                          
			ctrl_resp_valid <= 1;
		end

		if (reset) begin
			num_cls_recieved <= '0;
		end
		else if (cci_c0Rx_isReadRsp(fiu.c0Rx) && (fiu.c0Rx.hdr.mdata == READ_RUN_MDATA)) begin                                                          
			rd_resp_fifo.wr_en <= 1;
			num_cls_recieved <= num_cls_recieved + 1;
			$display("Recieved CL # %d - first data: %d", num_cls_recieved + 1, fiu.c0Rx.data[63:0]);
		end

		if (cci_c1Rx_isWriteRsp(fiu.c1Rx)) begin
		end 
	end

	/********************************************/
	/*  AFU Submodules							*/
	/********************************************/

	READ_ENGINE read_engine_mod (
		.clk(clk),
		.stall(fiu.c0TxAlmFull || rd_resp_fifo_overflow_risk),

		.afu_state(afu_state),
		.ctrl_addr(afu_ctrl_addr),
		.ctrl_resp(ctrl_resp),

		.rd_valid(rd_valid),
		.rd_mdata(rd_hdr.metadata),
		.rd_addr(rd_hdr.addr)
	);

	// Register run state check to alleviate routing
	logic wr_engine_reset;
	always_ff @(posedge clk) begin
		wr_engine_reset <= afu_next_state != AFU_RUN;
	end

	WRITE_ENGINE write_engine_mod (
		.clk(clk),
		.stall(fiu.c1TxAlmFull),

		.afu_state(afu_state),
    	.stts_addr(afu_stts_addr),

		.wr_start_addr(ctrl_resp.wr_addr),
		.wr_data_fifo(wr_data_fifo),

		.wr_valid(wr_valid),
		.wr_addr(wr_hdr.addr),
		.wr_data(wr_data)
	);

	/********************************************/
	/*  HOUSE KEEPING							*/
	/********************************************/

	// This AFU never handles MMIO reads.  MMIO is managed in the CSR module.
	assign fiu.c2Tx.mmioRdValid = 1'b0;
	// This AFU makes no read requests
	// assign fiu.c0Tx.valid = 1'b0;
	//This AFU makes no write requests
	// assign fiu.c1Tx.valid = 1'b0;

 	always_comb begin
		// The AFU ID is a unique ID for a given program.
		csrs.afu_id = 128'h092a3e62_81c5_499a_ae2c_62ff4788fadd;
		                 //092a3e62_81c5_499a_ae2c_62ff4788fadd

		csrs.cpu_rd_csrs[0].data = 64'(afu_state); // Used to confirm AFU is properly shutdown
		csrs.cpu_rd_csrs[1].data = cpu_wr_csrs[1]; // Return AFU ctrl addr so CPU can make sure it has been latched
		csrs.cpu_rd_csrs[2].data = cpu_wr_csrs[2]; // Return CPU ctrl addr so CPU can make sure it has been latched
		csrs.cpu_rd_csrs[3].data = '0;
		csrs.cpu_rd_csrs[4].data = '0;
		csrs.cpu_rd_csrs[5].data = '0;
		csrs.cpu_rd_csrs[6].data = '0;
		csrs.cpu_rd_csrs[7].data = 64'(ctrl_resp.last_nonce); // Should not be necessary, but in case the CPU does not know the previous nonce value; it can get it here

		//Read header generation
		rd_hdr.params = cci_mpf_defaultReqHdrParams(1);     
		rd_hdr.params.vc_sel = eVC_VA;             
		rd_hdr.params.cl_len = eCL_LEN_1;
		rd_hdr.hint = eREQ_RDLINE_I;   
		rd_hdr.hdr = cci_mpf_c0_genReqHdr(rd_hdr.hint, rd_hdr.addr, rd_hdr.metadata, rd_hdr.params);                                                  

		//Write header generation
		wr_hdr.params = cci_mpf_defaultReqHdrParams(1);
		wr_hdr.params.vc_sel = eVC_VA;
		wr_hdr.params.cl_len = eCL_LEN_1;
		wr_hdr.hint = eREQ_WRLINE_I;
		wr_hdr.metadata = '0;
		wr_hdr.hdr = cci_mpf_c1_genReqHdr(wr_hdr.hint, wr_hdr.addr, wr_hdr.metadata, wr_hdr.params);
	end

	always_ff @(posedge clk) begin
		// Send read requests
		fiu.c0Tx.valid 	<= rd_valid;
		fiu.c0Tx 		<= cci_mpf_genC0TxReadReq(rd_hdr.hdr, rd_valid);

		// Send write requests
		fiu.c1Tx.valid  <= wr_valid;
		fiu.c1Tx        <= cci_mpf_genC1TxWriteReq(wr_hdr.hdr, wr_data, wr_valid);                                                           
	end

	//CSR READ Control
    genvar c;
    generate
        for (c = 0; c < 8; c = c + 1) begin: test
            always_ff @(posedge clk) begin
                if (reset)
                    cpu_wr_csrs[c] <= 64'b0;
                else if (csrs.cpu_wr_csrs[c].en)
                    cpu_wr_csrs[c] <= csrs.cpu_wr_csrs[c].data;
            end
        end
    endgenerate

	//AFU Start control
    always_ff @(posedge clk) begin
		if (reset) begin
			start <= 0;
		end
		else begin
			if (cpu_wr_csrs[0][0]) begin
				start <= 1;
			end
		end
    end

	/********************************************/
	/*  Request Counting & FIFO Overflow		*/
	/********************************************/

	// 	Request counting
	//	Here we count outgoing and incoming data requests to keep track of outstanding requests for the FIFO overflow calculation
	t_uint32 data_reqs_sent;
	t_uint32 data_reqs_ackd;
	t_uint32 data_reqs_outstanding;

	always_ff @(posedge clk) begin
		data_reqs_outstanding <= data_reqs_sent - data_reqs_ackd;

		unique case(afu_state)
            AFU_RUN: begin
                if (rd_valid && rd_hdr.metadata == READ_RUN_MDATA) begin
					data_reqs_sent <= data_reqs_sent + 1;
				end

				if (cci_c0Rx_isReadRsp(fiu.c0Rx) && (fiu.c0Rx.hdr.mdata == READ_CTRL_MDATA)) begin  
					data_reqs_ackd <= data_reqs_ackd + 1;
				end
            end

            default: begin
                data_reqs_sent <= '0;
                data_reqs_ackd <= '0;
            end
        endcase
	end

	// Read FIFO overflow check
    // Logic to pre-emptively stall read engines when potential inflight requests + fifo data count could overflow the response FIFO
    //      Heavy pipelining (this logic is expensive and usually a routing nightmare)
    //      This way to do it is the best I have found yet
    //      Because of heavy pipelining, FIFO_ALM_FULL_BUFFER parameter bust be at least > # pipeline stages in the computation
    //      However because the request interface is also pipelined, I add a few more to be safe
    //      FIFO_ALM_FULL_BUFFER is found in afu_fifos.sv
    
    t_uint32 rd_resp_fifo_count_intermediate;
    always_ff @(posedge clk) begin
        // Sum in-fligh with FIFO count
        rd_resp_fifo_count_intermediate <= data_reqs_outstanding + rd_resp_fifo.count;

        // Check if intermediate count is greater than stall threshold
        rd_resp_fifo_overflow_risk <= rd_resp_fifo_count_intermediate > t_uint32'(READ_RESP_FIFO_DEPTH - FIFO_ALM_FULL_BUFFER);
    end

	// Tracks outstanding (un-ackd) request counts for read / write interface
    // Run state will not end until:
    //      - All read requests have recieved a matching response
    //      - All write requests have been comitted to the channel
    request_tracker request_tracker_mod
    (
        .clk(clk),
        .reset(reset),

        .c0_req(fiu.c0Tx.valid),
        .c1_req(fiu.c1Tx.valid),
        .c0_resp(cci_c0Rx_isReadRsp(fiu.c0Rx)),
        .c1_resp(cci_c1Rx_isWriteRsp(fiu.c1Rx)),

        .c0_busy(rd_interface_busy),
        .c1_busy(wr_interface_busy)
    );

endmodule
