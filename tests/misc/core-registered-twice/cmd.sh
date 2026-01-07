#!/usr/bin/env bash
echo "hbs::Register: cannot register core 'my-core' in $HBS_TESTS_DIR/misc/core-registered-twice/subdir/core2.hbs, core with the same path already registered in $HBS_TESTS_DIR/misc/core-registered-twice/core1.hbs" > golden.txt
../../../hbs list-cores 2> output.txt
if [[ $? == 1 ]]; then
	exit 0
else
	exit 1
fi
