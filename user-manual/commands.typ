= Command line interface commands

== `doc` - viewing HBS API documentation

== `dump-cores` - dumping cores information

== `graph` - generating dependency graph

== `help` - displaying help message for commands


== `list-cores` - listing cores found in hbs files

The `list-cores` command allows listing all cores discovered by the HBS.
You can run `hbs help list-cores` to see help message for the command.
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
The below snippet presents an output for listing various bridge cores in the same APB library:
```
[user@ahost apb] hbs list-cores bridge
vhdl::amba5::apb::cdc-bridge
vhdl::amba5::apb::serial-bridge
```
Please note that you can provided arbitrary strings to the `list-cores` command.
The core is listed if its core path contains at least one string provided in arguments.
For example, the below snippet presents an output for listing all cores containg the `bri` or `bar` string in the same APB library:
```
[user@host apb] hbs list-cores bri bar
vhdl::amba5::apb::cdc-bridge
vhdl::amba5::apb::crossbar
vhdl::amba5::apb::serial-bridge
```

== `list-targets` - listing targets for discovered cores

== `list-tb` - listing testbench targets

== `run` - running targets

== `test` - running testbench targets

== `version` - displaying HBS version

== `whereis` - locating cores definition
