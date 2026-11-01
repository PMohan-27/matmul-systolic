module systolic_array #(
    parameter N = 2,
    parameter INT_WIDTH = 8,
    parameter ACCUM_WIDTH = 32
) (

    input logic clk, nrst,
    input logic signed [INT_WIDTH-1:0] a_edge [0:N-1],
    input logic signed [INT_WIDTH-1:0] b_edge [0:N-1],

    output logic signed [ACCUM_WIDTH-1:0] c_out [0:N-1][0:N-1]
);

    logic signed [INT_WIDTH-1:0] a_wire [0:N-1][0:N];
    logic signed [INT_WIDTH-1:0] b_wire [0:N][0:N-1];

    for (genvar i = 0; i < N; i++) begin
        assign a_wire[i][0] = a_edge[i];
    end
    for (genvar j = 0; j < N; j++) begin
        assign b_wire[0][j] = b_edge[j];
    end

    for(genvar i = 0; i < N; i++) begin
        for(genvar j = 0; j < N; j++) begin
            PE #(
                .INT_WIDTH(INT_WIDTH),
                .ACCUM_WIDTH(ACCUM_WIDTH)
            ) u_pe (
                .clk(clk),
                .nrst(nrst),
                .a_in(a_wire[i][j]),
                .b_in(b_wire[i][j]),
                .a_out(a_wire[i][j+1]),
                .b_out(b_wire[i+1][j]),
                .result(c_out[i][j])
            );
        end
    end

endmodule