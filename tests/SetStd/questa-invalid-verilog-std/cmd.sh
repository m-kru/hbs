#!/usr/bin/env bash
echo "core::target: hbs::questa::addHdlFile: $HBS_TESTS_DIR/SetStd/questa-invalid-verilog-std/abc.v: invalid Verilog/SystemVerilog standard '2008', valid standards are: '1995', '2001', '2005', '2009' '2012', '2017', '2023'" > golden.txt
../../../hbs run core::target 2> output.txt
if [[ $? == 1 ]]; then
  exit 0
else
  exit 1
fi