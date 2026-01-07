#!/usr/bin/env bash
echo "core::target: hbs::AddFile: cannot add file $HBS_TESTS_DIR/AddFile/tool-not-set/abc.vhd, hbs::Tool not set" > golden.txt
../../../hbs run core::target 2> output.txt
if [[ $? == 1 ]]; then
	exit 0
else
	exit 1
fi