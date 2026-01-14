#!/usr/bin/env bash
export HBS_DRY_RUN=1
echo "core::target: hbs::gowin::addVerilogFile: $HBS_TESTS_DIR/SetStd/gowin-invalid-verilog-std/abc.v: invalid Verilog/SystemVerilog standard '2008', valid standards are: '1995', '2001', '2005', '2009' '2012', '2017', '2023'" > golden.txt
../../../hbs dry-run core::target 1>/dev/null 2> output.txt
if [[ $? == 1 ]]; then
  exit 0
else
  exit 1
fi