= Examples

This section contains some examples of HBS usage.
It barely presents some primary features of HBS.
If you want to discover full capabilities of HBS, then run `hbs doc` command.
The command lists all HBS API public symbols.
To get more information on a given symbol, run `hbs run <symbol>` command.


== Single file simulation

Let us assume we want to simulate the following minimal VHDL example:
```vhdl
entity example is end entity;

architecture test of example is
begin
  main : process is
  begin
    report "Hello from example!";
    std.env.finish;
  end process;
end architecture;
```
A minimal hbs file looks as follows:
```tcl
namespace eval example {
  proc sim {} {
    hbs::SetTool "nvc" ;# We must set some tool.
    hbs::AddFile "example.vhd" ;# This is required, we want to simulate this file.
    hbs::SetTop "example" ;# Let the simulator know what is the top entity.
    hbs::Run ;# Run the flow for set tool.
  }
  hbs::Register ;# This is required to register the core.
}
```
Nothing from the above hbs file can be removed, except comments and preceding semicolons.
The example simply won't work.
Now, we can run the simulation what is shown in the below snippet:
```
[user@host test] hbs run example::sim
nvc  --std=2019 -L. --work=work -a /tmp/test/example.vhd
nvc  --std=2019 -L. -e example
nvc  --std=2019 -L. -r example --wave
** Note: writing FST waveform data to example.fst
** Note: 0ms+0: Hello from example!
   Process :example:main at /tmp/test/example.vhd:5
** Note: 0ms+0: FINISH called
   Procedure FINISH [] at ../lib/std.19/env-body.vhd:48
   Process :example:main at /tmp/test/example.vhd:8
[user@host test] echo $?
0
```
As can be seen the returned status is 0.
The simulation finished successfully.
The HBS always forwards the EDA tool exist status to you.
Thanks to this, you can easily check if the target proc you run succeeded.

=== Placing the module in custom library

Low, let us assume we want to place our module in a custom library named `lib`.
All we need is to add a call to the `hbs::SetLib` procedure.
A new hbs file is presented below.
```tcl
namespace eval example {
  proc sim {{tool "nvc"}} {
    hbs::SetTool $tool
    hbs::SetLib "lib"; # A new call to change the library.
    hbs::AddFile "example.vhd"
    hbs::SetTop "example"
    hbs::Run
  }
  hbs::Register
}
```
The below snippet shows output from running the target:
```
[user@host test] hbs run example::sim
nvc  --std=2019 -L. --work=lib -a /tmp/test/example.vhd
nvc  --std=2019 -L. -e example
nvc  --std=2019 -L. -r example --wave
** Note: writing FST waveform data to example.fst
** Note: 0ms+0: Hello from example!
   Process :example:main at /tmp/test/example.vhd:5
** Note: 0ms+0: FINISH called
   Procedure FINISH [] at ../lib/std.19/env-body.vhd:48
   Process :example:main at /tmp/test/example.vhd:8
```
As can be seen, the library has been changed to `lib` (`--work=lib`).


=== Changing the simulator via command line

Low, let us assume we want to be able to easily change the simulator.
We would like to define the simulator when executing the target.
The simplest way is to add a parameter to the target.
Below snippet presents modified hbs files.
```tcl
namespace eval example {
  proc sim {{tool "nvc"}} {
    hbs::SetTool $tool ;# Now we use proc parameter to set desired tool.
    hbs::AddFile "example.vhd"
    hbs::SetTop "example"
    hbs::Run
  }
  hbs::Register
}
```
The parameter is named `tool` and has the default value equal `"nvc"`.
The below snippet presents how to run simulation using different simulators.
```
[user@host test] hbs run example::sim
nvc  --std=2019 -L. --work=work -a /tmp/test/example.vhd
nvc  --std=2019 -L. -e example
nvc  --std=2019 -L. -r example --wave
** Note: writing FST waveform data to example.fst
** Note: 0ms+0: Hello from example!
   Process :example:main at /tmp/test/example.vhd:5
** Note: 0ms+0: FINISH called
   Procedure FINISH [] at ../lib/std.19/env-body.vhd:48
   Process :example:main at /tmp/test/example.vhd:8

[user@host test] hbs run example::sim ghdl
ghdl -a  --std=08  -Pwork --work=work --workdir=work  /tmp/test/example.vhd
ghdl -e  --std=08 --workdir=work  -Pwork  example
./example  --wave=example.ghw
/tmp/test/example.vhd:7:5:@0ms:(report note): Hello from example!
simulation finished @0ms

[user@host test] hbs run example::sim xsim
xvhdl  -work work --2008 /tmp/test/example.vhd
INFO: [VRFC 10-163] Analyzing VHDL file "/tmp/test/example.vhd" into library work
INFO: [VRFC 10-3107] analyzing entity 'example'
...
## exit
INFO: xsimkernel Simulation Memory Usage: 277636 KB (Peak: 335168 KB), Simulation CPU Usage: 630 ms
INFO: [Common 17-206] Exiting xsim at Tue Dec 23 11:44:03 2025...
```
The log from the `xsim` is very verbose, that is why it has been trimmed.


== Constraints scoped to module


== More examples

If you have some interesting exmaple of HBS usage, feel free to prepare a pull request with extension the below list.

- #link("https://github.com/m-kru/vhdl-amba5/tree/master/apb")[VHDL APB library],
- #link("https://github.com/m-kru/vsc8211-tester")[VSC8211 Tester].
