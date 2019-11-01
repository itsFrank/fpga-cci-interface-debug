module lpm_counter ( 
    q, 
    data, 
    clock, 
    cin, 
    cout, 
    clk_en, 
    cnt_en, 
    updown,
    aset,
    aclr,
    aload,
    sset,
    sclr,
    sload,
    eq
);
parameter lpm_type = "lpm_counter";
parameter lpm_width = 1;
parameter lpm_modulus = 0;
parameter lpm_direction = "UNUSED";
parameter lpm_avalue = "UNUSED";
parameter lpm_svalue = "UNUSED";
parameter lpm_pvalue = "UNUSED";
parameter lpm_port_updown = "PORT_CONNECTIVITY";
parameter lpm_hint = "UNUSED";
output [lpm_width-1:0] q;
output cout;
output [15:0] eq;
input  cin;
input  [lpm_width-1:0] data;
input  clock, clk_en, cnt_en, updown;
input  aset, aclr, aload;
input  sset, sclr, sload;
endmodule