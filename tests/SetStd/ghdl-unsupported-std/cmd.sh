#!/usr/bin/env bash
echo "core::target: hbs::ghdl::addVhdlFile: $HBS_TESTS_DIR/SetStd/ghdl-unsupported-std/abc.vhd: ghdl doesn't support VHDL standard '2019'" > golden.txt
../../../hbs run core::target 2> output.txt
if [[ $? == 1 ]]; then
  exit 0
else
  exit 1
fi