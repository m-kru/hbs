#!/bin/python3

import os
import subprocess
import sys

this_script_dir = os.path.dirname(os.path.abspath(__file__))

def print_help():
    print("""Usage:

  hbs.py <command> [arguments]

The command is one of:

  dep-graph     Output dependency graph for given target
  dump-cores    Dump info about cores in JSON format
  list-cores    List cores found in .hbs files
  list-targets  List targets for given core
  run           Run given target
  test          Run testbenches matching given target path""")

if len(sys.argv) < 2:
    print("missing command, check help", file=sys.stderr)
    exit(1)

cmd = sys.argv[1]

if cmd == "help":
    print_help()
elif cmd == "dump-cores":
    if len(sys.argv) > 2:
        print("dump-cores command does not accept any arguments", file=sys.stderr)
        exit(1)
    subprocess.run([this_script_dir + '/hbs.tcl', 'dump-cores'])

elif cmd == "list-cores":
    if len(sys.argv) > 2:
        print("list-cores command does not accept any arguments", file=sys.stderr)
        exit(1)
    subprocess.run([this_script_dir + '/hbs.tcl', 'list-cores'])
elif cmd == "list-targets":
    if len(sys.argv) < 3:
        print("list-targets command requires core path", file=sys.stderr)
        exit(1)
    elif len(sys.argv) > 3:
        print("list-targets command accepts only one core path", file=sys.stderr)
        exit(1)
    subprocess.run([this_script_dir + '/hbs.tcl', 'list-targets', sys.argv[2]])
