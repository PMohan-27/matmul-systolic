set LIB $::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

yosys read_liberty -lib $LIB
yosys read_verilog -sv build/design.v
yosys chparam -set N 2 systolic_array
yosys hierarchy -check -top systolic_array

yosys proc
yosys flatten
yosys opt_expr
yosys opt_clean
yosys check
yosys opt -nodffe -nosdff
yosys fsm
yosys opt
yosys wreduce
yosys peepopt
yosys opt_clean

yosys alumacc
yosys share
yosys opt
yosys opt_share
yosys memory -nomap
yosys opt_clean

yosys techmap -map +/techmap.v
yosys opt -fast -full

yosys dfflibmap -liberty $LIB
yosys abc -liberty $LIB -D 3000
yosys opt_clean -purge

yosys stat -liberty $LIB
yosys rename -top systolic_array
yosys write_verilog -noattr -noexpr -nohex -nodec build/netlist.v
