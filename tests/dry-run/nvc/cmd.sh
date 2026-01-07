#!/usr/bin/env bash

echo "nvc FileAnalPrefix --std=2008 -L. --work=lib_a -a $HBS_TESTS_DIR/dry-run/nvc/a.vhd FileAnalSuffix
nvc  --std=2008 -L. --work=lib_b -a $HBS_TESTS_DIR/dry-run/nvc/b.vhd
nvc  --std=2008 -L. --work=work -a $HBS_TESTS_DIR/dry-run/nvc/c.vhd
nvc ElabArgsPrefix --std=2008 -L. -e TopEntity  -g GEN=64 ElabArgsSuffix
nvc SimArgsPrefix --std=2008 -L. -r TopEntity --wave --exit-severity=error SimArgsSuffix" > golden.txt

export HBS_TOOL=nvc
../../../hbs dry-run core-c::src > output.txt