#!/bin/python3

import json
import multiprocessing
import os
import subprocess
import sys

this_script_dir = os.path.dirname(os.path.abspath(__file__))
workers = multiprocessing.cpu_count()

help_help = """Usage:
    
  hbs.py <command> [arguments]

The command is one of:

  help          Print help message
  dep-graph     Output dependency graph for given target
  dump-cores    Dump info about cores in JSON format
  list-cores    List cores found in .hbs files
  list-targets  List targets for given core
  run           Run given target
  test          Run testbenches matching given target path

Type 'hbs.py help <command>' to obtain more information about particular command."""

list_cores_help = """Usage:

  hbs.py list-cores

List cores found in .hbs files."""

list_targets_help = """Usage:

  hbs.py list-targets core-path

List targets for given core. Core path must be absolute."""

run_help = """Usage:
        
  hbs.py run <target-path>

Run provided target. The target path must be absolute target path containing
the core path and target name.

Example:

  hbs.py run your::core::path::target-name"""

test_help = """Usage:

  hbs.py test [-workers N] [target-path-patterns...]

Run test targets. Test targets are detected automatically.
A test target is a target which name:
  - starts with "tb-" or "tb_",
  - ends with "-tb" or "_tb".
  - equals "tb".

-workers specifies the number of targets to run simultaneously (in parallel).
N must be a positive integer. -workers must be provided before target path patterns.
Otherwise, it will be treated as one of the target path patterns.
By default the number of workers equals the number of available CPUs.

If target path patterns are not provided, all test targets are run.
If target path patterns are provided, only targets whose paths contain
at least one pattern are run."""

if len(sys.argv) < 2:
    print("missing command, check help", file=sys.stderr)
    exit(1)

def hbs_help(cmd):
    if cmd == "" or cmd == "help":
        print(help_help)
    elif cmd == "list-cores":
        print(list_cores_help)
    elif cmd == "list-targets":
        print(list_targets_help)
    elif cmd == "run":
        print(run_help)
    elif cmd == "test":
        print(test_help)

def target_path_has_pattern(path, patterns):
    if len(patterns) == 0:
        return True

    for pattern in patterns:
        if pattern in path:
            return True
    return False

def test(patterns):
    """patterns are target path patterns"""
    hbs_json = subprocess.check_output([os.path.join(this_script_dir, 'hbs.tcl'), 'dump-cores'])
    cores = json.loads(hbs_json.decode("utf-8"))

    test_targets = []
    for core, core_info in cores.items():
        for target in core_info['targets']:
            if not (
                target == 'tb' or
                target.startswith('tb_') or target.startswith('tb-') or
                target.endswith('_tb') or target.endswith('-tb')
            ):
                continue

            target_path = core + '::' + target
            if target_path_has_pattern(target_path, patterns):
                test_targets.append(target_path)

    test_targets.sort()
    print(test_targets)

    workers_count = multiprocessing.cpu_count()
    print(f"running {len(test_targets)} verification targets with {workers_count} workers")

cmd = sys.argv[1]

if cmd == "help":
    if len(sys.argv) == 2:
        hbs_help('')
    elif len(sys.argv) == 3:
        hbs_help(sys.argv[2])
    else:
        print("help command accepts one or no argument", file=sys.stderr)
        exit(1)
elif cmd == "dump-cores":
    if len(sys.argv) > 2:
        print("dump-cores command does not accept any arguments", file=sys.stderr)
        exit(1)
    subprocess.run([os.path.join(this_script_dir, 'hbs.tcl'), 'dump-cores'])

elif cmd == "list-cores":
    if len(sys.argv) > 2:
        print("list-cores command does not accept any arguments", file=sys.stderr)
        exit(1)
    subprocess.run([os.path.join(this_script_dir, 'hbs.tcl'), 'list-cores'])
elif cmd == "list-targets":
    if len(sys.argv) < 3:
        print("list-targets command requires core path", file=sys.stderr)
        exit(1)
    elif len(sys.argv) > 3:
        print("list-targets command accepts only one core path", file=sys.stderr)
        exit(1)
    subprocess.run([os.path.join(this_script_dir, 'hbs.tcl'), 'list-targets', sys.argv[2]])
elif cmd == "test":
    test(sys.argv[2:])
else:
    print(f"invalid command '{cmd}', check help")
    exit(1)
