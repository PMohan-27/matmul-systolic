module PE #(
    parameter INT_WIDTH   = 8,
    parameter ACCUM_WIDTH = 18
) (
    input  logic clk, nrst,
    input  logic signed [INT_WIDTH-1:0]   a_in, b_in,
    output logic signed [INT_WIDTH-1:0]   a_out, b_out,
    output logic signed [ACCUM_WIDTH-1:0] result
);
    localparam int H = INT_WIDTH/2;

    wire signed [H:0]   b_lo = {1'b0, b_in[H-1:0]};   // low half, unsigned value
    wire signed [H-1:0] b_hi = b_in[INT_WIDTH-1:H];   // high half, signed

    logic signed [INT_WIDTH+H:0]   p_lo;
    logic signed [INT_WIDTH+H-1:0] p_hi;
    logic signed [2*INT_WIDTH-1:0] prod;

    always_ff @(posedge clk) begin
        if (!nrst) begin
            a_out <= '0; b_out <= '0;
            p_lo  <= '0; p_hi  <= '0;
            prod  <= '0;
        end else begin
            a_out  <= a_in;
            b_out  <= b_in;
            p_lo   <= a_in * b_lo;
            p_hi   <= a_in * b_hi;
            prod   <= (p_hi <<< H) + p_lo;
        end
    end

    localparam int LW = ACCUM_WIDTH/2;
    localparam int HW = ACCUM_WIDTH - LW;

    logic signed [ACCUM_WIDTH-1:0] prod_ext;
    assign prod_ext = prod;

    logic [LW-1:0] acc_lo;
    logic [HW-1:0] acc_hi, prod_hi_q;
    logic          carry_q;

    always_ff @(posedge clk) begin
        if (!nrst) begin
            acc_lo <= '0; acc_hi <= '0; carry_q <= 1'b0; prod_hi_q <= '0;
        end else begin
            {carry_q, acc_lo} <= {1'b0, acc_lo} + {1'b0, prod_ext[LW-1:0]};   // low half
            prod_hi_q         <= prod_ext[ACCUM_WIDTH-1:LW];                  // delay high bits one cycle
            acc_hi            <= acc_hi + prod_hi_q + carry_q;                // high half uses last cycle's carry
        end
    end

    assign result = {acc_hi, acc_lo};
endmodule