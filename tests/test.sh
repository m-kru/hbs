#!/bin/bash

set -e

HBS_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export HBS_TESTS_DIR

test_count=0

for dir in $(find . -maxdepth 2 -mindepth 2 -type d | sort);
do
	if [[ $dir == ./.git* ]]; then
		continue
	fi
	echo "$dir"
	cd "$dir"
	./cmd.sh
	diff --color -Z output.txt golden.txt
	rm output.txt
	cd - > /dev/null
	test_count=$(expr $test_count + 1)
done

echo -e "\nAll ($test_count) \e[1;32mPASSED\e[0m!"
