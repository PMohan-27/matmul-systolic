import os
import random

import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

N = int(os.environ.get("N", "2"))
IW = int(os.environ.get("INT_WIDTH", "8"))
AW = int(os.environ.get("ACCUM_WIDTH", "18"))
MAX_WAIT = 30   # extra cycles allowed for the pipeline to drain


def to_signed(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v


async def run(dut, A, B):
    """Reset, stream skewed A and B, then poll until c_out matches A @ B.
    Returns (matched, cycles from first input to the first match)."""
    K = A.shape[1]
    exp = A @ B
    mask = (1 << IW) - 1

    dut.nrst.value = 0
    for i in range(N):
        dut.a_edge[i].value = 0
        dut.b_edge[i].value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.nrst.value = 1

    def read():
        return np.array([[to_signed(int(dut.c_out[i][j].value), AW) for j in range(N)]
                         for i in range(N)], dtype=np.int64)

    cycles = 0
    for t in range(K + N - 1):                    # skewed feed
        await FallingEdge(dut.clk)
        for i in range(N):
            k = t - i
            dut.a_edge[i].value = (int(A[i][k]) & mask) if 0 <= k < K else 0
            dut.b_edge[i].value = (int(B[k][i]) & mask) if 0 <= k < K else 0
        cycles += 1

    await FallingEdge(dut.clk)                    # let the last slice get clocked in
    cycles += 1
    for i in range(N):                            # drain with explicit zeros
        dut.a_edge[i].value = 0
        dut.b_edge[i].value = 0

    for _ in range(MAX_WAIT):
        await FallingEdge(dut.clk)
        cycles += 1
        if np.array_equal(read(), exp):
            for _ in range(3):                    # result must stay stable
                await FallingEdge(dut.clk)
                if not np.array_equal(read(), exp):
                    return False, cycles
            return True, cycles
    return False, cycles


def rand_mat(r, c, lo=-128, hi=127):
    return np.array([[random.randint(lo, hi) for _ in range(c)] for _ in range(r)], dtype=np.int64)


async def check(dut, A, B, name):
    ok, cycles = await run(dut, A, B)
    assert ok, f"{name}: mismatch\nA=\n{A}\nB=\n{B}\nexpected=\n{A @ B}"
    return cycles


@cocotb.test()
async def test_directed(dut):
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    K = 4
    ones = np.ones((N, K), dtype=np.int64)
    await check(dut, np.zeros((N, K), dtype=np.int64), np.ones((K, N), dtype=np.int64), "zeros")
    await check(dut, 127 * ones, 127 * ones.T, "all 127")
    await check(dut, -128 * ones, 127 * ones.T, "all -128 x 127")
    await check(dut, -128 * ones, -128 * ones.T, "all -128 x -128, K=4")
    A = rand_mat(N, N)
    await check(dut, A, np.eye(N, dtype=np.int64), "A x I")
    await check(dut, np.eye(N, dtype=np.int64), A, "I x A")


@cocotb.test()
async def test_random(dut):
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    random.seed(1)
    trials = 0
    lat = None
    for K in sorted({1, 2, N, 5, 8}):             # K <= 8 keeps sums within 18 bits
        for _ in range(25):
            lat = await check(dut, rand_mat(N, K), rand_mat(K, N), f"random K={K}")
            trials += 1
    dut._log.info(f"{trials} random trials passed at N={N}; last run: {lat} cycles to settle (K={K})")