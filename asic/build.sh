./sv2v ../rtl/PE.sv ../rtl/systolic_array.sv  -w build/design.v
yosys -c synth.tcl
openroad -exit pnr.tcl 2>&1 | tee build/pnr.log
magic -dnull -noconsole -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc def2gds.tcl

ls -l build/systolic_array.gds

for g in feol beol offgrid; do
  klayout -b -r "$KDRC" -rd input="$PWD/build/systolic_array.gds" -rd report="$PWD/build/drc_$g.xml" -rd $g=true
  echo "== $g"
  grep -o "<category>[^<]*</category>" build/drc_$g.xml | sort | uniq -c | sort -rn || true
done