#!/usr/bin/env bash

echo "create_project   -name core-c--src  -dir build  -pn GW1NR-9C  -force -device_version NA
add_file FileAnalPrefix $HBS_TESTS_DIR/dry-run/gowin/a.vhd FileAnalSuffix
set_file_prop -lib lib_a $HBS_TESTS_DIR/dry-run/gowin/a.vhd
add_file  $HBS_TESTS_DIR/dry-run/gowin/b.vhd
set_file_prop -lib lib_b $HBS_TESTS_DIR/dry-run/gowin/b.vhd
add_file  $HBS_TESTS_DIR/dry-run/gowin/c.sv
set_file_prop -lib work $HBS_TESTS_DIR/dry-run/gowin/c.sv
set_option -generic {GEN=64}
set_option -top_module TopEntity
set_option -vhdl_std vhd2008
set_option -verilog_std sysv2017
set err [catch {eval \"::run SynthArgsPrefix syn SynthArgsSuffix\"} errMsg]
if {\$err} {
  error \$errMsg
}
set err [catch {eval \"::run ImplArgsPrefix pnr ImplArgsSuffix\"} errMsg]
if {\$err} {
  error \$errMsg
}" > golden.txt

../../../hbs dry-run core-c::src > output.txt