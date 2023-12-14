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

dump_cores_help = """Usage:

  hbs.py dump-cores

Dump info about cores found in the .hbs files in JSON format.
The info is dumped to the stdout. A user can redirect to a file on his own."""

list_cores_help = """Usage:

  hbs.py list-cores [core-path-patterns...]

List cores found in .hbs files.
If core path patterns are not provided, all cores are listed.
If core path patterns are provided, only cores whose paths contain
at least one pattern are listed."""

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
    elif cmd == "dump-cores":
        print(dump_cores_help)
    elif cmd == "list-cores":
        print(list_cores_help)
    elif cmd == "run":
        print(run_help)
    elif cmd == "test":
        print(test_help)
    else:
        print(f"invalid command '{cmd}', check help", file=sys.stderr)
        exit(1)

def str_has_substr(string, substrings):
    """ str_has_substr returns True if given string contains at least one of substrings. """
    if len(substrings) == 0:
            return True
    for ss in substrings:
        if ss in string:
            return True
    return False

def list_cores(patterns):
    output = subprocess.check_output([os.path.join(this_script_dir, 'hbs.tcl'), 'list-cores'])
    output = output.decode('utf-8')
    if len(patterns) == 0:
        print(output, end='')
    else:
        cores = output.split('\n')
        for core in cores:
            if str_has_substr(core, patterns):
                print(core)

def test(patterns):
    """patterns are target path patterns"""
    hbs_json = subprocess.check_output([os.path.join(this_script_dir, 'hbs.tcl'), 'dump-cores'])
    cores = json.loads(hbs_json.decode('utf-8'))

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
            if str_has_substr(target_path, patterns):
                test_targets.append(target_path)

    test_targets.sort()
    print(test_targets)

    workers_count = multiprocessing.cpu_count()
    print(f"running {len(test_targets)} targets with {workers_count} workers")

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
    list_cores(sys.argv[2:])
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
