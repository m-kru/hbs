#!/usr/bin/env bash

echo "set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name VHDL_FILE /home/mkru/data/workspace/hbs/tests/dry-run/quartus/a.vhd -library lib_a
set_global_assignment -name VHDL_FILE /home/mkru/data/workspace/hbs/tests/dry-run/quartus/b.vhd -library lib_b
set_global_assignment -name VERILOG_FILE /home/mkru/data/workspace/hbs/tests/dry-run/quartus/c.v -library work
set_global_assignment -name SYSTEMVERILOG_FILE /home/mkru/data/workspace/hbs/tests/dry-run/quartus/d.sv -library work
set_parameter -name GEN 64
set_global_assignment -name TOP_LEVEL_ENTITY TopEntity
set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008
set_global_assignment -name VERILOG_INPUT_VERSION SYSTEMVERILOG_2005
load_package flow
execute_flow ElabArgsPrefix -analysis_and_elaboration ElabArgsSuffix
execute_flow ImplArgsPrefix -compile ImplArgsSuffix" > golden.txt

export HBS_TOOL=quartus
../../../hbs dry-run core-c::src > output.txt
