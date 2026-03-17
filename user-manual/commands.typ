= Command line interface commands

== `doc` - viewing documentation for cores

The `doc` command allows viewing documentation for coers automatically discovered by the `hbs`.
The command displays the message passed to the `hbs::Register` procedure during the core registration.


== `dump` - dumping cores information in Tcl dictionary format

The `dump` command allows dumping information about found cores into Tcl dictionary format.
The generated data can be easily used for further processing by other tools utilizing Tcl.
For example, the `graph` command utilizes data from dump to generate the dependency graph.


== `dump-json` - dumping cores information in JSON format

The `dump-json` command allows dumping information about found cores into JSON format.
The generated JSON data can be used for further processing by other tools.
For example, if you do not like the default behavior of some `hbs` commands, you can implement your custom wrapper.
Simply utilize dumped JSON data as a stream from `hbs` to your wrapper.


== `graph` - generating target dependency graph

The `graph` command allows generating target dependency graphs in #link("https://graphviz.org/doc/info/lang.html")[Graphviz dot] format.
To generate the graph in a graphical format you can use the `dot` program which is usually installed as a part of the `graphviz` package.


The `graph` command requires information about cores in the Tcl dictionary format.
This implies that the user must execute the `dump`, `run` or `dry-run` command before generating a dependency graph.
However, this is not a major issue in practice.
Dumping cores, even for large designs, does not take more than a few seconds, as the `dump` command does not run the target tool flow.
The `dry-run` command is also very fast, as it does not execute or evaluate any commands.

The following figure presents an example dependency graph generated for VSC8211 (Ethernet PHY) chip tester design:
#align(center)[
  #image("images/vsc8211-graph.pdf", width: 100%)
]


== `help` - displaying help message for commands

The `help` command serves as a standard help message display command.
If no argument is provided, then the help message regards the `hbs` general use.
If argument is provided for the `help` command, then it must be a valid command name.
In such a case, `hbs` prints help message for the provided command.
The following snippet presents help message for the `run` command:
```
[user@host tmp] hbs help run
Run provided target.

  hbs run <target-path> [target-args...]

The target path must be absolute target path containing the core path
and target name. Target arguments are forwarded to the target proc call.

Example:
  hbs run your::core::path::target-name synthesis
```


== `info` - viewing HBS API documentation

The `info` command was added to ease viewing information on HBS Tcl public API symbols or EDA tools.
If no argument is provided for the `info` command, then `hbs` prints a list of all HBS Tcl public symbols and supported EDA tools.
To get more information on the particular symbol, simply provide it as an argument for the `info` command.
The following snippet presents an example of `info` command output:
```
[user@host ~] hbs info SetStd
# Sets standard revision for HDL files.
#
# To get the value of currently set standard revision simply
# read the value of hbs::Std variable.
#
# Standard revision for a given file must be set before adding a file.
# For example:
#   hbs::SetStd 2008
#   hbs::AddFile entity.vhd
proc SetStd {std}
```


== `ls-cores` - listing cores found in hbs files

The `ls-cores` command allows listing all cores discovered by the HBS.
The following snippet presents an output for listing all cores in the #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library]:
```
[user@ahost apb] hbs ls-cores
vhdl::amba5::apb::bfm
vhdl::amba5::apb::cdc-bridge
vhdl::amba5::apb::checker
vhdl::amba5::apb::crossbar
vhdl::amba5::apb::mock-completer
vhdl::amba5::apb::pkg
vhdl::amba5::apb::serial-bridge
vhdl::amba5::apb::shared-bus
```
The following snippet presents an output for listing various bridge cores in the same APB library:
```
[user@ahost apb] hbs ls-cores bridge
vhdl::amba5::apb::cdc-bridge
vhdl::amba5::apb::serial-bridge
```
Please note that you can provided arbitrary strings to the `ls-cores` command.
The core is listed if its core path contains at least one string provided in arguments.
For example, the following snippet presents an output for listing all cores containg the `bri` or `bar` string in the same APB library:
```
[user@host apb] hbs ls-cores bri bar
vhdl::amba5::apb::cdc-bridge
vhdl::amba5::apb::crossbar
vhdl::amba5::apb::serial-bridge
```

== `ls-targets` - listing targets for discovered cores

The `ls-targets` command allows listing all targets discovered by the HBS.
The command is analogous to the `ls-cores` command but works on targets instead of cores.
The following snippet presents an output for listing `src` targets in the #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library]:
```
[user@host apb] hbs ls-targets src
vhdl::amba5::apb::bfm::src
vhdl::amba5::apb::cdc-bridge::src
vhdl::amba5::apb::checker::src
vhdl::amba5::apb::crossbar::src
vhdl::amba5::apb::mock-completer::src
vhdl::amba5::apb::pkg::src
vhdl::amba5::apb::serial-bridge::src
vhdl::amba5::apb::shared-bus::src
```
The name "src" is preferred name for a core target if the core has only one target containing all sources required for core utilization.
However, this is not a formal requirement, so feel free to name your targets however you want.

== `ls-tb` - listing testbench targets

The `ls-tb` command allows listing all testbench targets discovered by HBS.
The `ls-tb` command is analogous to the `ls-targets` command, but it works solely on testbench targets instead of all targets.
The following snippet presents an output for listing testbench targets for bridges in the #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library]:
```
[user@host apb] hbs ls-tb bridge
vhdl::amba5::apb::cdc-bridge::tb-to-faster
vhdl::amba5::apb::cdc-bridge::tb-similar-slower
vhdl::amba5::apb::cdc-bridge::tb-similar-faster
vhdl::amba5::apb::cdc-bridge::tb-to-slower
vhdl::amba5::apb::serial-bridge::tb-write
vhdl::amba5::apb::serial-bridge::tb-read
```
If no arguments are provided for the `ls-tb` command, then all testbench targets for all discovered cores are listed.


== `run` - running targets

The `run` command allows running target procedures.
Usually, targets are run to carry out the build process or simulation.
However, the user is free to carry out any action in the target being run.
You can, for example, use targets for software recompilation.

Running targets is described in @arch-running-targets, @arch-target-parameters, and @arch-target-context.


== `dry-run` - running target without executing and evaluating commands

The `dry-run` command runs a given target without executing and evaluating commands.
It only prints the commands to the standard output for previewing the actions carried out by the target.

In the dry run, the following things change compared to the actual run:
+ `hbs` does not bootstrap itself with a proper Tcl shell from the EDA tool.
+ Shell, or EDA Tcl commands, are not executed or evaluated.
  They are only printed to the standard output.

The `dry-run` command is useful in the following scenarios:
+ When you want to generate a dependency graph without running any tool flow.
  Running targets including synthesis, or place and route, stages might be time-consuming.
  A dry run allows for quickly dumping cores into `.json` file for further dependency graph generation.
+ When you debug your hbs files or the build flow.
  The `dry-run` command allows for a quick preview of all commands that are executed or evaluated during the actual run.
+ When you want to generate a Tcl or shell script for building a project or running a simulation.
  Executing the `dry-run` command is like taking a snapshot of your build procedure.
  For example, you think you have found a bug in a simulator, and you would like to open an issue on GitHub.
  The project maintainer requires you to provide an example for reproducing the bug.
  However, the bug reproducing requires multiple files and shell commands to be executed.
  You can't expect the simulator developer to utilize HBS as a build system.
  To deliver shell commands for bug reproducing, you can simply copy the `dry-run` output.
+ For implementing HBS internal regression tests.

=== Supporting dry runs in hbs files

All the `hbs` internal code supports dry runs by default.
However, if you want your hbs files to also support dry runs, you must obey some extra rules.
You cannot directly call EDA Tcl custom commands.
This is because `hbs` does not bootstrap itself with a proper Tcl shell from the EDA tool in the dry run.
For example, let's assume you build a project using Vivado, and you have the following command in your hbs file:
```tcl
set_msg_config -suppress -id "Synth 8-6014" -string {{REPORT_PREFIX}}
```
The command will simply fail during the dry run with the following message:
```
invalid command name "set_msg_config"
    while executing
...
```
Your OS Tcl shell (`tclsh`) does not have the built-in `set_msg_config` command.
This is a Vivado custom command.

HBS provides three procedures supporting implementing dry run compatible user hbs files, the `hbs::Eval`, `hbs::Exec`, and `hbs::ExecInCoreDir`.
The `hbs::Eval` procedure prints the command to the standard output and evaluates it only if the current run is not a dry run.
All you have to do is to prepend EDA tool custom command with a call to the `hbs::Eval` procedure and pass your command with arguments as a string.
The following snippet presents an example:
```tcl
hbs::Eval {set_msg_config -suppress -id "Synth 8-6014" -string {{REPORT_PREFIX}}}
```
The `hbs::Eval` procedure has an optional `-force-in-dry` flag, which allows for forcing command evaluation in the dry run.
See `'hbs doc Eval'` for more information.

The `hbs::Exec` and `hbs::ExecInCoreDir` procedures work analogously, but they execute commands instead of evaluating them.
Moreover, they return the exit status, allowing you to check if commands succeed.
Check `'hbs doc Exec'` and `'hbs doc ExecInCoreDir'` for more details.

An alternative approach for writing dry-run-compatible hbs files is to explicitly execute some actions in your hbs files only if the current run is not a dry run.
The following snippet presents an example:
```tcl
if {!$hbs::DryRun} {
  set_msg_config -suppress -id "Synth 8-6014" -string {{REPORT_PREFIX}}
}
```
If you use this technique, the output produced by the dry run will not create a valid script for building a project.
However, this technique still allows for generating a dependency graph without running any tool flow.

Writing hbs files compatible with dry runs adds some boilerplate.
Not a lot, but still.
Most projects do not require hbs files compatible with dry runs.
If you implement a core that you want to share with others, then it is a good idea to assume they might require dry runs.
However, if you implement a project only for yourself or the company you work for, then it is advised to write dry-run-compatible hbs files only if you know you will need dry runs.
If it later turns out you were wrong, and you need dry runs, you can easily adjust your hbs files.
Adapting dry run incompatible hbs files is quite simple, as dry runs simply fail with an error message when they encounter an unknown command.


== `test` - running testbench targets

The `test` command allows running all automatically discovered testbench targets.
By default, testbench targets are run in parallel.
The default number of workers equals the number of threads on your CPU.
If you provide extra arguments to the `test` command, only testbench targets which path contain at least one of the provided strings are run.
The following snippet presents an output for running all testbenched of the bus functional model in the #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library].
```
[user@host ap] hbs test bfm
running 4 targets with 16 workers

vhdl::amba5::apb::bfm::tb-readb   passed  warnings: 1
vhdl::amba5::apb::bfm::tb-read    passed  warnings: 1
vhdl::amba5::apb::bfm::tb-write   passed  warnings: 1
vhdl::amba5::apb::bfm::tb-writeb  passed  warnings: 1

time:     0 h 0 min 0 s
targets:  4
passed:   4
failed:   0
errors:   0
warnings: 4
```


== `version` - displaying HBS version

The `version` command displays version of installed HBS.
This might be helpful if the same build procedure works on one machine, but does not work on another.
Based on the versoin and changelog, you can quickly discover differences.
The blow snippet shows an example output for the `version` command.
```
[user@host ~ 0] hbs version
1.0
```


== `where` - locating cores definition

The `where` command allows easily locating .hbs files in which given cores are defined
The following snippet presents an example of locating core definition:
```
[user@host vsc8211-tester] hbs where serial-bridge
vhdl::amba5::apb::serial-bridge  /tmp/vsc8211-tester/gw/apb/apb.hbs
```
You can locate multiple cores in a single call by providing multiple arguments to the command.
The following snippet presents an example:
```
[user@host vsc8211-tester] hbs where bridge mdio
vhdl::amba5::apb::serial-bridge  /tmp/vsc8211-tester/gw/apb/apb.hbs
vhdl::ethernet::mdio             /tmp/vsc8211-tester/gw/vhdl-ethernet/ethernet.hbs
```
