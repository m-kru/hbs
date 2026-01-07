#!/usr/bin/env bash

echo  "ghdl -a FileAnalPrefix --std=08  -Plib_a --work=lib_a --workdir=lib_a FileAnalSuffix $HBS_TESTS_DIR/dry-run/ghdl/a.vhd
ghdl -a  --std=08  -Plib_a -Plib_b --work=lib_b --workdir=lib_b  $HBS_TESTS_DIR/dry-run/ghdl/b.vhd
ghdl -a  --std=08  -Plib_a -Plib_b -Pwork --work=work --workdir=work  $HBS_TESTS_DIR/dry-run/ghdl/c.vhd
ghdl -e ElabArgsPrefix --std=08 --workdir=work  -Plib_a -Plib_b -Pwork ElabArgsSuffix TopEntity
./TopEntity SimArgsPrefix --wave=TopEntity.ghw  -gGEN=64 --assert-level=error SimArgsSuffix" > golden.txt


export HBS_TOOL=ghdl
../../../hbs dry-run core-c::src > output.txt