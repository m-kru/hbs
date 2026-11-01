#!/usr/bin/env bash

set -euo pipefail

: > output.txt
for tool in ghdl nvc questa xsim; do
  echo "$tool" >> output.txt
  ../../../hbs dry-run core::target "$tool" | sed 's|[^ ]*/a\.vhd|a.vhd|g' >> output.txt
done
