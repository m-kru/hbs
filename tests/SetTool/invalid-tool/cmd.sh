#!/usr/bin/env bash
../../../hbs run my-core::my-target 2> output.txt
if [[ $? == 1 ]]; then
	exit 0
else
	exit 1
fi
