module PE #(
    parameter INT_WIDTH = 8,
    parameter ACCUM_WIDTH = 32
) (
    input logic clk, nrst,
    input logic  signed [INT_WIDTH-1:0] a_in, b_in,

    output logic signed [INT_WIDTH-1:0] a_out, b_out, 
    output logic signed [ACCUM_WIDTH-1:0] result
);

    always_ff @(posedge clk) begin
        if(!nrst) begin
            a_out <= '0;
            b_out <= '0;
            result <= '0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            result <= result + (a_in * b_in);
        end
    end
endmodule