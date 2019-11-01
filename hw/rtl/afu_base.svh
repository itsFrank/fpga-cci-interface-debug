package afu_base;
    import ccip_if_pkg::*;
    import cci_mpf_if_pkg::*;

    localparam CL_BYTE_IDX_BITS = 6;
    typedef logic [$bits(t_cci_clAddr) + CL_BYTE_IDX_BITS - 1 : 0] t_byteAddr;

    function automatic t_cci_clAddr byteAddrToClAddr(t_byteAddr addr);
        return addr[CL_BYTE_IDX_BITS +: $bits(t_cci_clAddr)];
    endfunction

    function automatic t_byteAddr clAddrToByteAddr(t_cci_clAddr addr);
        return {addr, CL_BYTE_IDX_BITS'(0)};
    endfunction

    // The size of a cache line in bits
    localparam CACHE_WIDTH = 512;

    typedef logic [31:0]    t_float;
    typedef logic [31:0]    t_uint32;
    typedef logic [63:0]    t_uint64;
    typedef logic [7:0]     t_uint8;

    typedef struct {
        t_cci_mpf_c0_ReqMemHdr hdr;
        t_cci_clAddr addr;                       
        t_cci_mpf_ReqMemHdrParams params;        
        t_cci_mdata metadata = 16'd0;               
        t_cci_c0_req hint = eREQ_RDLINE_I;
    } rd_req_hdr_config_t;

    typedef struct {
        t_cci_mpf_c1_ReqMemHdr hdr;
        t_cci_clAddr addr;
        t_cci_mpf_ReqMemHdrParams params;
        t_cci_mdata metadata = 16'd0;               
        t_cci_c1_req hint = eREQ_WRLINE_I;
    } wr_req_hdr_config_t;

endpackage
