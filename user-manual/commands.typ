= Command line interface commands

== `doc` - viewing HBS API documentation

The `doc` command was added to ease viewing documentation for HBS Tcl symbols.
The command is executed by the `hbs` file, so Python is required for the command to work.
If no argument is provided for the `doc` command, then `hbs` prints a list of all HBS Tcl public symbols.
To get more information on the particular symbol, simply provide it as an argument for the `doc` command.
The below snippet presents an example of `doc` command output.
```
[user@host ~] hbs doc SetStd
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


== `dump-cores` - dumping cores information

The `dump-cores` command allows dumping information about found cores into JSON format.
The generated JSON data can be used for further processing.
For example, the graph command utilizes data from JSON dump to generate the dependency graph.
The command is executed by the `hbs.tcl` file, so Python is not required for the command to work.
If you do not like the default behavior of the `hbs` Python wrapper, you can write your own.
Simply utilize dumped JSON data as a stream from `hbs.tcl` to your wrapper.


== `graph` - generating target dependency graph

The `graph` command allows generating target dependency graphs in PDF format.
The command is executed by the `hbs` file, so Python is required for the command to work.
Moreover, you must have `graphviz` installed on your machine.

The `graph` command requires information about cores in the JSON format.
This implies that the user must execute the `dump-cores` or `run` command before generating a dependency graph.
However, this is not a major issue in practice.
Dumping cores, even for large designs, does not take more than a few seconds, as the `dump-cores` command does not run the target tool flow.

The below figure presents an example dependency graph generated for VSC8211 (Ethernet PHY) chip tester design.
#align(center)[
  #image("images/vsc8211-graph.pdf", width: 100%)
]


== `help` - displaying help message for commands

The `help` command serves as a standard help message display command.
If no argument is provided, then the help message regards the `hbs` general use.
If argument is provided for the `help` command, then it must be a valid command name.
In such a case, `hbs` prints help message for the provided command.
The below snippets presents help message for the `dump-cores` command.
```
[user@host tmp] hbs help dump-cores
Dump info about cores found in .hbs files in JSON format.

  hbs dump-cores

The JSON is directed to stdout.
If you want to save it in a file simply redirect stdout.
```


== `list-cores` - listing cores found in hbs files

The `list-cores` command allows listing all cores discovered by the HBS.
The `list-cores` command is executed by the `hbs.tcl` file, so the command does not require Python to work.
The below snippet presents an output for listing all cores in the #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library].
```
[user@ahost apb] hbs list-cores
vhdl::amba5::apb::bfm
vhdl::amba5::apb::cdc-bridge
vhdl::amba5::apb::checker
vhdl::amba5::apb::crossbar
vhdl::amba5::apb::mock-completer
vhdl::amba5::apb::pkg
vhdl::amba5::apb::serial-bridge
vhdl::amba5::apb::shared-bus
```
The below snippet presents an output for listing various bridge cores in the same APB library.
```
[user@ahost apb] hbs list-cores bridge
vhdl::amba5::apb::cdc-bridge
vhdl::amba5::apb::serial-bridge
```
Please note that you can provided arbitrary strings to the `list-cores` command.
The core is listed if its core path contains at least one string provided in arguments.
For example, the below snippet presents an output for listing all cores containg the `bri` or `bar` string in the same APB library.
```
[user@host apb] hbs list-cores bri bar
vhdl::amba5::apb::cdc-bridge
vhdl::amba5::apb::crossbar
vhdl::amba5::apb::serial-bridge
```

== `list-targets` - listing targets for discovered cores

The `list-targets` command allows listing all targets discovered by the HBS.
The command is analogous to the `list-cores` command but works on targets instead of cores.
The `list-targets` command is executed by the `hbs.tcl` file, so the command does not require Python to work.
The below snippet presents an output for listing `src` targets in the #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library].
```
[user@host apb] hbs list-targets src
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

== `list-tb` - listing testbench targets

The `list-tb` command allows listing all testbench targets discovered by HBS.
The `list-tb` command is analogous to the `list-targets` command, but it works solely on testbench targets instead of all targets.
The command is executed by the `hbs` file and requires Python to work.
The below snippet presents an output for listing testbench targets for bridges in the #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library].
```
[user@host apb] hbs list-tb bridge
vhdl::amba5::apb::cdc-bridge::tb-to-faster
vhdl::amba5::apb::cdc-bridge::tb-similar-slower
vhdl::amba5::apb::cdc-bridge::tb-similar-faster
vhdl::amba5::apb::cdc-bridge::tb-to-slower
vhdl::amba5::apb::serial-bridge::tb-write
vhdl::amba5::apb::serial-bridge::tb-read
```
If no arguments are provided for the `list-tb` command, then all testbench targets for all discovered cores are listed.


== `run` - running targets

The `run` command allows running target procedures.
Usually, targets are run to carry out the build process or simulation.
However, the user is free to carry out any action in the target being run.
You can, for example, use targets for software recompilation.

Running targets is described in @arch-running-targets, @arch-target-parameters, and @arch-target-context.


== `test` - running testbench targets

The `test` command allows running all automatically discovered testbench targets.
The `test` command is executed by the `hbs` file and requires Python to work.
By default, testbench targets are run in parallel.
The default number of workers equals the number of threads on your CPU.
If you provide extra arguments to the `test` command, only testbench targets which path contain at least one of the provided strings are run.
The below snippet presents an output for running all testbenched of the bus functional model in the #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library].
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


== `whereis` - locating cores definition

The `whereis` command allows easily locating .hbs files in which given cores are defined
The `whereis` command is executed by the `hbs` file, so the command requires Python to work.
The below snippet presents an example of locating core definition.
```
[user@host vsc8211-tester] hbs whereis serial-bridge
vhdl::amba5::apb::serial-bridge  /tmp/vsc8211-tester/gw/apb/apb.hbs
```
You can locate multiple cores in a single call by providing multiple arguments to the command.
The below snippet presents an example:
```
[user@host vsc8211-tester] hbs whereis bridge mdio
vhdl::amba5::apb::serial-bridge  /tmp/vsc8211-tester/gw/apb/apb.hbs
vhdl::ethernet::mdio             /tmp/vsc8211-tester/gw/vhdl-ethernet/ethernet.hbs
```
