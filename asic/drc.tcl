gds read build/systolic_array.gds
load systolic_array
select top cell
drc style drc(full)
drc check
drc catchup
puts "TOTAL: [drc count total]"
foreach {why boxes} [drc listall why] {
    puts "[llength $boxes] x $why"
}
quit