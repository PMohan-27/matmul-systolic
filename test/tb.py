import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

A_SK = [[1, 0], [2, 3], [0, 4], [0, 0]]
B_SK = [[5, 0], [7, 6], [0, 8], [0, 0]]
C = [[19, 22], [43, 50]]


@cocotb.test()
async def test(dut):

    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    dut.nrst.value = 0

    for i in range(2):
        dut.a_edge[i].value = 0
        dut.b_edge[i].value = 0
    await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)

    dut.nrst.value = 1

    for t in range(4):
        await FallingEdge(dut.clk)
        for i in range(2):
            dut.a_edge[i].value = A_SK[t][i]
            dut.b_edge[i].value = B_SK[t][i]
            
    await FallingEdge(dut.clk)

    for i in range(2):
        for j in range(2):
            assert int(dut.c_out[i][j].value) == C[i][j]