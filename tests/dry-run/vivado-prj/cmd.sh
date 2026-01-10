#!/usr/bin/env bash

echo "set_property part xc7z020clg400-1 [current_project]
read_vhdl -library lib_a -vhdl2008 $HBS_TESTS_DIR/dry-run/vivado-prj/a.vhd
read_vhdl -library lib_b -vhdl2008 $HBS_TESTS_DIR/dry-run/vivado-prj/b.vhd
read_verilog -library xil_defaultlib -sv $HBS_TESTS_DIR/dry-run/vivado-prj/c.sv
set_property generic GEN=64 [current_fileset]
set_property top TopEntity [current_fileset]
launch_runs SynthArgsPrefix synth_1 SynthArgsSuffix
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != \"100%\"} {
  error \"synth_1 failed\"
}
launch_runs ImplArgsPrefix impl_1 ImplArgsSuffix
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != \"100%\"} {
  error \"impl_1 failed\"
}
open_run impl_1
write_bitstream BitArgsPrefix [get_property DIRECTORY [current_run]]/TopEntity.bit BitArgsSuffix" > golden.txt

export HBS_TOOL=vivado-prj
../../../hbs dry-run core-c::src > output.txt