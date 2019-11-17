import afu_base::*;

module request_tracker
# (
    COUNT_WIDTH = 32
)
(
    input logic clk,
    input logic reset,

    input logic c0_req,
    input logic c1_req,
    input logic c0_resp,
    input logic c1_resp,

    output logic c0_busy,
    output logic c1_busy
);

logic [COUNT_WIDTH - 1 : 0] c0_sent;
logic [COUNT_WIDTH - 1 : 0] c1_sent;
logic [COUNT_WIDTH - 1 : 0] c0_ackd;
logic [COUNT_WIDTH - 1 : 0] c1_ackd;

always_ff @(posedge clk) begin
    c0_busy <= c0_sent != c0_ackd;
    c1_busy <= c1_sent != c1_ackd;
    
    if (reset) begin
        c0_sent <= '0;
        c1_sent <= '0;
        c0_ackd <= '0;
        c1_ackd <= '0;
    end
    else begin
        if (c0_req) c0_sent <= c0_sent + 1;
        if (c1_req) c1_sent <= c1_sent + 1;

        if (c0_resp) c0_ackd <= c0_ackd + 1;
        if (c1_resp) c1_ackd <= c1_ackd + 1;
    end
end

endmodule