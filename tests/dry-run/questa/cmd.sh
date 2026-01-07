#!/usr/bin/env bash

echo "vcom FileAnalPrefix -work lib_a -2008 $HBS_TESTS_DIR/dry-run/questa/a.vhd FileAnalSuffix
vcom  -work lib_b -2008 $HBS_TESTS_DIR/dry-run/questa/b.vhd
vlog  -work work -sv -sv12compat $HBS_TESTS_DIR/dry-run/questa/c.sv
vsim SimArgsPrefix  -GGEN=64 TopEntity -c -stats -vcddump TopEntity.vcd -do run.do SimArgsSuffix" > golden.txt

export HBS_TOOL=questa
../../../hbs dry-run core-c::src > output.txt