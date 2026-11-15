set P $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd

read_lef     $P/techlef/sky130_fd_sc_hd__nom.tlef
read_lef     $P/lef/sky130_fd_sc_hd.lef
read_liberty $P/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog build/netlist.v
link_design  systolic_array
read_sdc     constraints.sdc

# floorplan
initialize_floorplan -utilization 40 -aspect_ratio 1 -core_space 10 -site unithd

# routing tracks (the Sky130 tech LEF does not define them)
make_tracks li1  -x_offset 0.23 -x_pitch 0.46 -y_offset 0.17 -y_pitch 0.34
make_tracks met1 -x_offset 0.17 -x_pitch 0.34 -y_offset 0.17 -y_pitch 0.34
make_tracks met2 -x_offset 0.23 -x_pitch 0.46 -y_offset 0.17 -y_pitch 0.34
make_tracks met3 -x_offset 0.34 -x_pitch 0.68 -y_offset 0.34 -y_pitch 0.68
make_tracks met4 -x_offset 0.46 -x_pitch 0.92 -y_offset 0.46 -y_pitch 0.92
make_tracks met5 -x_offset 1.70 -x_pitch 3.40 -y_offset 1.70 -y_pitch 3.40

place_pins -hor_layers met3 -ver_layers met2

# tap cells
tapcell -distance 14 -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1

# power grid
add_global_connection -net VDD -pin_pattern {^VPWR$} -power
add_global_connection -net VDD -pin_pattern {^VPB$}  -power
add_global_connection -net VSS -pin_pattern {^VGND$} -ground
add_global_connection -net VSS -pin_pattern {^VNB$}  -ground

set_voltage_domain -name CORE -power VDD -ground VSS
define_pdn_grid -name grid -voltage_domains CORE
add_pdn_stripe  -layer met1 -followpins -width 0.48
add_pdn_stripe  -layer met4 -width 1.6 -pitch 27.14 -offset 13.57
add_pdn_stripe  -layer met5 -width 1.6 -pitch 27.2  -offset 13.6
add_pdn_connect -layers {met1 met4}
add_pdn_connect -layers {met4 met5}
pdngen

# wire RC for parasitic estimates (drop these two lines if they error)
set_wire_rc -signal -layer met2
set_wire_rc -clock  -layer met5

# placement + design repair
global_placement -timing_driven -density 0.5
estimate_parasitics -placement
repair_design
detailed_placement

estimate_parasitics -placement
repair_design
repair_timing -setup

# clock tree + timing repair
clock_tree_synthesis -root_buf sky130_fd_sc_hd__clkbuf_4 -buf_list sky130_fd_sc_hd__clkbuf_4
set_propagated_clock [all_clocks]
estimate_parasitics -placement
repair_timing -setup
repair_timing -hold
detailed_placement

# routing
set_routing_layers -signal met1-met5 -clock met1-met5
global_route
detailed_route

filler_placement "sky130_fd_sc_hd__fill_*"

# reports and outputs
estimate_parasitics -global_routing
report_power
report_design_area
report_wns
report_worst_slack -max
report_worst_slack -min
report_checks -path_delay max
report_checks -path_delay max -from [all_registers -clock_pins] -to [all_registers -data_pins]
report_checks -path_delay min

write_def build/final.def
write_db  build/final.odb