#!/usr/bin/env bash

echo "xvhdl FileAnalPrefix -work lib_a --2008 $HBS_TESTS_DIR/dry-run/xsim/a.vhd FileAnalSuffix
xvhdl  -work lib_b --2008 $HBS_TESTS_DIR/dry-run/xsim/b.vhd
xvlog  -work work -sv $HBS_TESTS_DIR/dry-run/xsim/c.sv
xelab ElabArgsPrefix -debug all  -generic_top GEN=64 TopEntity ElabArgsSuffix
xsim SimArgsPrefix -stats -onerror quit -tclbatch run.tcl TopEntity SimArgsSuffix" > golden.txt

export HBS_TOOL=xsim
../../../hbs dry-run core-c::src > output.txt