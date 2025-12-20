= Command line interface commands

== `doc` - viewing HBS API documentation

== `dump-cores` - dumping cores information

== `graph` - generating dependency graph


== `help` - displaying help message for commands

The `help` command serves as a standard help message display command.
If no argument is provided, then the help message regards the `hbs` general use.
If argument is provided for the `help` command, then it must be a valid command name.
In such a case, `hbs` prints help message for the provided command.


== `list-cores` - listing cores found in hbs files

The `list-cores` command allows listing all cores discovered by the HBS.
You can run `hbs help list-cores` to see help message for the command.
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


== `list-tb` - listing testbench targets

The `list-tb` command allows listing all testbench targets discovered by HBS.
You can run `hbs help list-tb` to see help message for the command.
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
You can run `hbs help run` to see help message for the command.
Usually, targets are run to carry out the build process or simulation.
However, the user is free to carry out any action in the target being run.
You can, for example, use targets for software recompilation.

Running targets is described in @arch-running-targets, @arch-target-parameters, and @arch-target-context.

== `test` - running testbench targets


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
