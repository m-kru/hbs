#!/usr/bin/env bash

set -e

: > output.txt
for worker_count in 0 -1; do
  status=0
  timeout 5 ../../../hbs test -workers "$worker_count" >> output.txt 2>&1 || status=$?
  if [[ $status != 1 ]]; then
    echo "Expected exit status 1 for worker count $worker_count, got $status" >&2
    exit 1
  fi
done
