# Output-Stationary Systolic Array Matrix Multiplier (SystemVerilog, RTL to GDS)

A parameterizable N×N systolic array for integer matrix multiplication, verified
with cocotb and taken through an open-source RTL-to-GDS flow on Sky130.

- **Dataflow:** output-stationary. PE(i,j) accumulates C[i][j] in place.
- **Arithmetic:** signed 8-bit inputs, 18-bit accumulators (parameters: `N`, `INT_WIDTH`, `ACCUM_WIDTH`).
- **Best closed timing:** 4.05 ns (247 MHz), post-route, with +0.01 ns setup slack. A marginal pass; see the table below for runs with more margin.

## Architecture

```
            b_edge[0]   b_edge[1]
               |           |
a_edge[0] --> PE(0,0) --> PE(0,1)
               |           |
a_edge[1] --> PE(1,0) --> PE(1,1)
```

- A enters from the left edge and flows right, B enters from the top edge and flows down, one hop per cycle.
- Row `i` of A and column `j` of B are skewed by `i` and `j` cycles respectively, so matching elements meet in the right PE at the right time. The skew is generated in the testbench.
- Each PE forwards `a`/`b` through registers and keeps a running sum of `a*b`.

### PE pipeline

The PE is pipelined to shorten the critical path (each change was driven by reading the critical path report):

1. **Split multiplier.** The 8-bit `b` is split into a low half (unsigned) and a high half (signed). Two 8×4 products are registered, then combined by a 16-bit add into `prod`.
2. **Split accumulator.** The 18-bit accumulator is two 9-bit halves. The low half adds the product's low bits and registers its carry. The high half adds the (delayed) high bits plus that carry one cycle later. This removes the 18-bit ripple-carry chain from the accumulate loop.

The cost is extra latency and flops: see results.

## Results

Configuration: **N = 2**, 8-bit inputs, 18-bit accumulators, Sky130 HD library, tt_025C_1v80 corner.

### Timing (post-route, estimated parasitics)

| Clock period | Design | Setup slack | Hold slack | Result |
|---|---|---|---|---|
| 8.0 ns | split multiplier | +0.70 ns | +0.18 ns | met |
| 7.3 ns | split multiplier | +0.08 ns | +0.46 ns | met |
| 7.3 ns | + split accumulator | +3.31 ns | +0.42 ns | met |
| 5.0 ns | + split accumulator | +1.01 ns | TODO | met |
| 4.05 ns | + split accumulator | +0.01 ns | TODO | met (marginal) |

For reference, the split-multiplier design with a single accumulator failed setup at tighter clocks
(about -0.15 ns at 7.0, 6.5, and 5.76 ns), limited by a 15-cell ripple-carry chain in the accumulate.

| Quantity | Value |
|---|---|
| Fmax (shortest period that closed) | 4.05 ns, 247 MHz |
| Input/output delay assumed in SDC | 0.5 ns |
| Routing violations (OpenROAD) | 0 |

### Area and power (N = 2)

| Design | Core area (post-route) | Utilization | Power (default activity) |
|---|---|---|---|
| split multiplier | 17,074 µm² | 43% | 3.76 mW |
| + split accumulator | 18,959 µm² | 43% | 3.96 mW |

Area and power at the tighter clock periods: TODO (fill in from `build/pnr.log`).

Power is the OpenROAD estimate at the tool's default switching activity, not measured from simulation traffic,
so treat it as a rough number. About half is sequential, about a fifth is the clock tree.

### Latency

Plain array: `K + 2N - 2` cycles from the first input to the last result. The PE pipeline adds extra cycles
before the accumulators are final. Measured latency for N=2, K=2: TODO cycles.

## Verification

- cocotb testbench, self-checking, compared against a NumPy reference (`A @ B`).
- Skewing is done in the testbench with `k = t - i` (rows) and `k = t - j` (columns), with explicit zeros on gap and drain cycles.
- Tests: directed (identity, negatives) and random full-range signed matrices at several K.
- Status on the final RTL: TODO (record pass/fail, number of random trials, and whether extreme values were tested).

Note on range: with 18-bit accumulators the signed range is ±131,071. A worst-case sum of eight (-128)×(-128) products is 131,072 and overflows by one, so increase `ACCUM_WIDTH` for larger K.

## Flow

| Stage | Tool |
|---|---|
| SystemVerilog to Verilog | sv2v |
| Synthesis | Yosys 0.33 (`abc` with the Sky130 HD liberty file) |
| Place and route | OpenROAD 26Q2 (floorplan, tap cells, power grid, global placement, CTS, repair, global and detailed routing) |
| DEF to GDS | Magic 8.3 |
| DRC | Magic (`drc(full)`) and KLayout (`sky130A_mr.drc`) |
| Simulation | Verilator with cocotb |

PDK: Sky130A, `sky130_fd_sc_hd`.

Notes on the flow:
- `sv2v` is used because Yosys 0.33's frontend rejects the unpacked-array ports.
- Synthesis target (`abc -D`) is set to match the SDC clock period for each run.
- Timing is estimated from global-route parasitics, in a single corner. It is not signoff.
- The SDC applies 0.5 ns input and output delays to the ports.

## DRC status

From the earlier N = 2 run (rerun on the final design: TODO):

- KLayout `sky130A_mr.drc`, off-grid: clean.
- BEOL: 82 minimum-area violations (m1.6, m2.6, m3.6), the same count and rules as in Magic's `drc(full)`.
- FEOL: implant-layer flags (hvtp, nsdm, psdm) on standard cell boundaries.

The layout is **not DRC clean**. The GDS is produced by Magic from the OpenROAD DEF. The metal minimum-area hits
may come from that conversion step, but the cause is unconfirmed. LVS has not been run.

## Limitations

- Results are for N = 2. The flat `c_out` bus makes pin count grow as N²; larger N needs an output readout (row mux or shift-out).
- No tiling: matrices larger than the array are not handled.
- `lpflow_*` low-power cells appear in the synthesized netlist. They were not excluded because Yosys 0.33's `abc` has no don't-use option.
- Hold and setup were checked at the typical corner only.

## Repository layout

```
rtl/    PE.sv, systolic_array.sv
tb/     cocotb tests and Makefile
asic/   synth.tcl, pnr.tcl, constraints.sdc, def2gds.tcl, drc.tcl, build.sh
build/  generated outputs (netlist, DEF, GDS, logs, DRC reports)
```

## How to run

Simulation:

```
cd tb
make N=2
```

RTL to GDS and DRC:

```
cd asic
./build.sh
```

Set the SDC period (`create_clock -period`) and the Yosys `abc -D` value (in picoseconds) together.
Inspect results with:

```
grep -i "worst slack" build/pnr.log
grep -i "design area" build/pnr.log
awk '/Startpoint/,/slack/' build/pnr.log | head -60
```