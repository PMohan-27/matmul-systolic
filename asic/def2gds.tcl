set P $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd
gds read $P/gds/sky130_fd_sc_hd.gds
lef read $P/lef/sky130_fd_sc_hd.lef
def read build/final.def
load systolic_array
gds write build/systolic_array.gds
quit