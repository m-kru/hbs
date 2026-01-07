#!/usr/bin/env bash
../../../hbs run core::target > output.txt
../../../hbs run core::target foo >> output.txt
../../../hbs run core::target foo bar >> output.txt
