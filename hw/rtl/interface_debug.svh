package interface_debug;
    import afu_base::*;
    import cci_mpf_if_pkg::*;

    // Read request metadata values
    localparam READ_CTRL_MDATA  = 16'd3;
    localparam READ_RUN_MDATA   = 16'd5;

    // AFU states
    typedef enum logic[2:0] {  
        AFU_IDLE            = 3'd0,
        AFU_CTRL            = 3'd1,
        AFU_RUN             = 3'd2,
        AFU_DONE            = 3'd3,
        AFU_SHUTDOWN        = 3'd4,
        AFU_SHUTDOWN_WAIT   = 3'd5
    } e_afu_state;

    // Control codes recieved from CPU
    typedef enum logic[2:0] {  
        CONTROL_NONE            = 3'd0,
        CONTROL_START_RUN       = 3'd1,
        CONTROL_AFU_SHUTDOWN    = 3'd2
    } e_control_code;

    // Status codes sent to CPU
    typedef enum logic[2:0] {  
        STATUS_NONE = 3'd0,
        STATUS_DONE = 3'd3
    } e_status_code;

    function automatic t_cci_clData constructStatusCL(e_status_code status_code, t_uint32 run_cls_sent);
        return {384'(0), 64'(run_cls_sent), 64'(status_code)};
    endfunction

endpackage

import afu_base::*;
import cci_mpf_if_pkg::*;
import interface_debug::*;

interface ctrl_resp_if(
    input logic         clk, 
    input logic         reset, 
    input logic         ctrl_resp_valid,
    input t_cci_clData  rd_resp_data 
);

// BEGIN - Interface Ports
    logic valid;
    logic ack;

    // Control word data
    e_control_code  code;       // Tells the AFU what kernel to run
    t_cci_clAddr    rd_addr;    // Kernel parameter
    t_cci_clAddr    wr_addr;    // Kernel parameter
    t_uint32        num_cls;    // Kernel parameter

    modport to_module (
        input valid,
        input ack,
        input code,
        input rd_addr,
        input wr_addr,
        input num_cls
    );
// END - Interface Ports

    t_uint8 last_nonce;     // Used to differentiate valid control response from stale responses
    t_uint8 current_nonce;  // Used to differentiate valid control response from stale responses

    t_uint64 [7:0] rd_resp_u64;

    assign rd_resp_u64      = rd_resp_data;
    assign current_nonce    = rd_resp_u64[7][63:56];
    
    always_ff @(posedge clk) begin
        valid   <= ctrl_resp_valid && (current_nonce != last_nonce); // If current nonce is same as last nonce this is a stale control instruction
        ack     <= ctrl_resp_valid; // Used by read engine to determine when to re-request control_word

        // Initialize and assign last_nonce 
        if (reset)
            last_nonce <= '0;
        else if (ctrl_resp_valid)
            last_nonce <= current_nonce;

        // Assign control data when word is valid
    if (ctrl_resp_valid) begin
            code    <= e_control_code'(rd_resp_u64[0][2:0]);
            rd_addr <= byteAddrToClAddr(rd_resp_u64[1]);
            wr_addr <= byteAddrToClAddr(rd_resp_u64[2]);
            num_cls <= rd_resp_u64[3];

            // Display control information
            if (current_nonce != last_nonce) begin
                $display("[RD CTRL] - Recieved new control instructions");
                $display("[RD CTRL] - code:    %d", e_control_code'(rd_resp_u64[0][2:0]));
                $display("[RD CTRL] - rd_addr: (byte) 0x%16h / (cl) 0x%16h", rd_resp_u64[1], byteAddrToClAddr(rd_resp_u64[1]));
                $display("[RD CTRL] - wr_addr: (byte) 0x%16h / (cl) 0x%16h", rd_resp_u64[2], byteAddrToClAddr(rd_resp_u64[2]));
                $display("[RD CTRL] - num_cls: %d", rd_resp_u64[3]);
            end
        end
    end
endinterface //ctrl_resp_if

