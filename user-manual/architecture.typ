= Internal architecture

It was decided that HBS will be implemented using Tcl language because of the following reasons:
+ Implementing a hardware build system in Tcl allows the execution of build system code during the EDA tool flow.
  This, in turn, gives direct access to all EDA tool custom commands.
  Moreover, these custom commands can be evaluated in arbitrary places.
+ If the EDA tool provides the Tcl interface, then the Tcl shell is provided by the EDA tool vendor.
  The shell is nstalled during the installation of vendor tools.
  This implies that, in some cases, the build system user does not even have to install additional programs.
+ Executing arbitrary programs in arbitrary places in Tcl is very simple.
  There is a dedicated `exec` command for invoking subprocesses.
  If executing a subprocess requires prior dynamic arguments evaluation, the `exec` command call must be prepended with the `eval` command.
  Even in Python, invoking a subprocess is not so straighforward.

One of the most important things while designing the HBS was the separation of common build process operations that would constitute a common abstraction layer over EDA tools.
At the end, it was decided that the following actions should constitute the common abstraction layer:
+ Target device setting - some EDA tools use the term “part” instead of “device,” for example, Vivado.
  Simulation EDA tools do not require a device setting.
  However, all synthesis EDA tools require information on the target device.
  This is why setting the device became part of the common abstraction layer.
+ File addition - this includes support for adding files of all formats supported by a given EDA tool.
+ Library setting - setting HDL file library.
+ HDL standard setting - setting HDL file standard revision.
  The build system has to manage this because some tools can not handle analyzing different design units using different standard revisions, for example, nvc.
  In such a case, the build system must decide what the common standard revision shall be used for analyzing all HDL files.
+ Dependency specification - this is the core feature of any build system.
+ Generics/parameters setting - configuring parametric designs must be an inherent feature of any hardware build system.
+ Design top module setting - all EDA tools carrying out simulation or synthesis requires information on the top module.
+ Exit severity setting - testbenches are designed to exit with an error code when a specific severity message occurs.
  This is independent of the simulator being used, hence it should be hidden under the build system abstraction.
+ Code generation - a hardware build system must provide a simple way for automatic arbitrary code generation.
  This is further explained in @code-generation.


== General structure

The HBS is implemented in two files `hbs.tcl` and `hbs`.
The first is implemented in Tcl, and the second in Python.
The `hbs.tcl` file implements all the core features related directly to the interaction with the EDA tools.
The `hbs.tcl` provides the following functions:
+ Dumping information about detected cores in JSON format.
+ Listing cores found in hbs files.
+ Listing targets for a given core.
+ Running target provided as a command line argument.

The `hbs` is a wrapper for the `hbs.tcl` and serves the following additional functions:
+ Showing documentation for hbs Tcl symbols.
+ Generating dependency graph.
+ Listing testbench targets.
+ Running testbench targets.

By default, the user calls the `hbs` program.
However, if none of the additional functions are required, the user can call the `hbs.tcl` directly.
In such a case, the whole build system is limited to a single file.


== Tcl naming conventions

Understanding Tcl naming conventions is crucial for using or contributing to the HBS.
All HBS code is hidden under the `hbs` namespace.
Code related to a particular tool is further hidden in the `hbs::{tool}` namespace.

Tcl does not allow defining private symbols within namespaces; all symbols are public.
However, `hbs.tcl` differentiates between public and private symbols.
Public symbols start with an uppercase letter, and private symbols begin with a lowercase letter.

The user should only use public symbols within hbs files.
Although using private symbols is discouraged, it is not forbidden, and if you really know what you do, feel free to use them.

The `hbs` namespace consists of variables and procs.
Even though some variables are public, the user shall not set them directly.
They are public because they can be safely read from the hbs files.
However, setting them might require some additional actions.
For example, `hbs::Tool` is a public variable, but the user shall use `hbs::SetTool` function for setting the tool.
There is no such requirement for getting the value of a public variable.

All variables representing choices (enumeration) use lowercase strings.
For example, the `hbs::Tool` can be `"ghdl"`, `"vivado-prj"`, etc.
The `hbs::ToolType` can equal `"formal"`, `"simulation"`, or `"synthesis"`.
The point of this is to avoid error cases when one core maintainer sets the tool to GHDL, but another core maintainer has, for example, the following condition in one of the targets:
```tcl
if {$hbs::Tool eq "ghdl"}
```
The expression would evaluate to false, although the tool is GHDL.
Most `hbs::Set*` procedures assert that users provide lowercase names.


== Cores and cores detection <cores-and-cores-detection>

When the user calls `hbs` (or `hbs.tcl`), all directories, starting from the working directory, are recursively scanned to discover all files with the `.hbs` extension (symbolic links are also scanned).
Files with the `.hbs` extension are regular Tcl files that are sourced by the `hbs.tcl` script.
However, before sourcing hbs files, the file list is sorted so that scripts with shorter path depth are sourced as the first ones.
For example, let us assume the following three hbs files were found:
- `a/b/c/foo.hbs`,
- `d/bar.hbs`,
- `e/f/zaz.hbs`.

Then, they would be sourced in the following order:
+ `d/bar.hbs`,
+ `e/f/zaz.hbs`,
+ `a/b/c/foo.hbs`.

Such an approach allows controlling when custom symbols (Tcl variables and procedures) are ready to use.
For example, if the user has a custom procedure used in multiple hbs files, then the user can create separate `utils.hbs` file contaning utility procedures, and place it in the the project root directory.
This guarantees that `utils.hbs` will be sourced before any hbs file in subdirectories.
Within hbs files, the user usually defines cores and targets, although the user is free to have any valid Tcl code in hbs files.


The following snippet presents a very basic flip-flop core definition:
```tcl
namespace eval flip-flop {
  proc src {} {
    hbs::AddFile flip-flop.vhd
  }
  hbs::Register
}
```
The flip-flop core has a single target named `src`.
The core consists of a single VHDL file.

To register a core, the user must explicitly call `hbs::Register` procedure at the end of the core namespace.
Such a mechanism helps to distinguish regular Tcl namespaces from Tcl namespaces representing core definitions.
If the user forgets to register a core, the build system gives a potential hint.
An example error message is presented in the following snippet:

```
[user@host tmp] hbs run lib::core::tb
checkTargetExists: core 'lib::core' not found, maybe the core is not:
  1. registered 'hbs doc hbs::Register',
  2. sourced 'hbs doc hbs::FileIgnoreRegexes'.
```

Each core is identified by its unique path.
The core path is equivalent to the namespace path in which `hbs::Register` is called.
Using the namespace path as the core path gives the following possibilities:
+ The user can easily stick to the VLNV identifiers if required.
  This is presented in the following snippet:
  In this case, the flip-flop core path is `vendor::library::flip-flop::1.0`.
  ```tcl
  namespace eval vendor::library::flip-flop::1.0 {
    proc src {} {
      hbs::AddFile flip-flop.vhd
    }
    hbs::Register
  }
  ```
+ The user can define arbitrary deep core paths (limited by the Tcl shell).
  This is presented in the following snippet:
  In this case, the core path consists of seven parts.
  ```tcl
  namespace eval a::b::c::d::e::f::flip-flop {
    proc src {} {
      hbs::AddFile flip-flop.vhd
    }
    hbs::Register
  }
  ```
+ The user can nest namespaces to imitate the structure of libraries and packages.
  This is presented in following snippet.
  ```tcl
  namespace eval lib {
    namespace eval pkg1 {
      namespace eval d-flip-flop {
        proc src {} {
          hbs::AddFile d-flip-flop.vhd
        }
        hbs::Register
      }
      namespace eval t-flip-flop {
        proc src {} {
          hbs::AddFile t-flip-flop.vhd
        }
        hbs::Register
      }
    }
    namespace eval pkg2 {
      namespace eval jk-flip-flop {
        proc src {} {
          hbs::AddFile jk-flip-flop.vhd
        }
        hbs::Register
      }
    }
  }
  ```
  Three flip-flop cores are defined in the snippet.
  The following snippet presents output for listing flip-flop cores:
  ```
  [user@host tmp]$ hbs list-cores
  lib::pkg1::d-flip-flop
  lib::pkg1::t-flip-flop
  lib::pkg2::jk-flip-flop
  ```

=== Excluding hbs files from being sourced

Sometimes a file with the `.hbs` extension is not a valid hbs file, or maybe you want to temporarily disable valid hbs files from being sourced.
HBS provides a built-in mechanism for excluding files with the `.hbs` extension from being sourced.
This is achieved using the `hbs::AddFileIgnoreRegex` function.
You just have to call this function in one of valid hbs files.
The function will be executed once the file containing the call is sourced.

Usually the hbs file containing calls to the `hbs::AddFileIgnoreRegex` proc is placed in the project root directory.
This is becuase hbs files placed in the project root directory are sourced before hbs files placed in subdirectories.
Order of hbs files sourcing is described in @cores-and-cores-detection.

Arguments provided to the `hbs::AddFileIgnoreRegex` proc are treated as regular expressions.
This allows for ignoring multiple paths using a single regex.
However, you are free to provide multiple ignore regex, and all of them will be checked while sourcing hbs files.

=== Explicitly sourcing hbs files

Sometimes there might be a need to explicitly source an hbs file.
For example, when you generate core code and would like also to generate the hbs file for the core.
HBS automatically searches for hbs files only when `hbs.tcl` file starts running.
If you generate code within hbs files, the newly generated hbs file will not be automatically discovered.
However, you can easily source the newly generated hbs file.
Simply use the Tcl built-in `source` command.


== Targets and targets detection

HBS automatically detects targets.
Targets are all Tcl procedures defined in the scope of core namespaces (namespaces with a call to `hbs::Register`).
However, to allow users to define custom utility procedures within cores, procedures with names starting with the floor character (`_`) are not treated as core targets.
The following snippet presents an example edge detector core definition:
```tcl
namespace eval vhdl::simple::edge-detector {
  proc src {} {
    hbs::SetLib "simple"
    hbs::AddFile src/edge_detector.vhd
  }
  proc _tb {top} {
    hbs::SetTool "ghdl"
    hbs::SetTop $top
    src
    hbs::SetLib ""
  }
  proc tb-sync {} {
    _tb "tb_edge_detector_sync"
    hbs::AddFile tb/tb_sync.vhd
    hbs::Run
  }
  proc tb-comb {} {
    _tb "tb_edge_detector_comb"
    hbs::AddFile tb/tb_comb.vhd
    hbs::Run
  }
  hbs::Register
}
```

The core path is `vhdl::simple::edge-detector`.
The core has three targets: `src`, `tb-sync`, `tb-comb`, and one utility procedure `_tb`.
The `_tb` procedure was defined to share calls common for testbench targets `tb-sync` and `tb-comb`.
Moreover, all target procedures are also regular Tcl procedures.
Such an approach allows for calling them in arbitrary places.
The `_tb` procedure calls the `src` procedure because the `edge_detector.vhd` file is required for running testbench targets.

All targets are represented by a unique target path.
Target path consists of the core path and target name.
For example, the `src` target of the edge detector has the following path `vhdl::simple::edge-detector::src`.


== Testbench targets

HBS is capable of automatically detecting testbench targets.
Testbench targets are targets which names:
+ start with the `tb-` or `tb_` prefix,
+ end with the `-tb` or `_tb` suffix,
+ equal `tb`.

For example, for the following hbs file:
```tcl
namespace eval my-core {
  proc tb {} {
    puts "Hello from tb"
  }
  proc my-tb {} {
    puts "Hello from my-tb"
  }
  proc tb_my {} {
    puts "Hello from tb_my"
  }
  hbs::Register
}
```
The `hbs` program detects the following testbench targets:
```
[user@host tmp] hbs list-tb
my-core::my-tb
my-core::tb
my-core::tb_my
```


== Running targets <arch-running-targets>

HBS allows running any target of registered cores.
Even if the target itself has nothing to do with the hardware design.
For example, running target `print` from the following snippet:
```tcl
namespace eval core {
  proc print {} {
    puts "Hello!"
  }
  hbs::Register
}
```
Results with the following output:
```
[user@host tmp]$ hbs run core::print
Hello!
```

However, in most cases, you want to run a target related to the flow of the set EDA tool.
In such a case, instead of manually calling all of the required tool commands, you can call the `hbs::Run` procedure in the core target procedure.
The `hbs::Run` procedure has an optional argument accepting the stage after which the tool flow should stop.
This is further described in @eda-tool-flow-and-stages.
After `hbs::Run` returns, the user can continue processing.
For example, the user can run scripts analyzing code coverage or preparing additional reports.


== Target parameters <arch-target-parameters>

As core targets are just Tcl procedures, they can have parameters.
Moreover, parameters can have optional default values.
Additionally, HBS allows to provide command line arguments to the run target.
This is a very convenient feature in build systems.
The blow snippet presents a very simplified example.
```tcl
namespace eval core {
  proc target {{stage "bitstream"}} {
    puts "Running until $stage"
    # hbs::Run commented out because this is just an example.
    #hbs::Run $stage
  }
  hbs::Register
}
```

The core does not build any hardware design.
However, the example shows how the build stage can be passed from the command line to an EDA tool.
The blow snippet presents output from running the target with different `stage` parameter values.
```
[user@host tmp]$ hbs run core::target
Running until bitstream
[user@host tmp]$ hbs run core::target synthesis
Running until synthesis
```

Another practical example of target parameters usage is setting the simulator for testbench target from the command line or changing the top-level module.
What target parameters are used for is limited only by your imagination, and Tcl semantics.

== Target context <arch-target-context>

As an engineer implementing a given core, you control the dependencies of the core.
However, you do not control who will use the core and how.
As targets are regular Tcl procedures, there is a need for a mechanism allowing the core author to evaluate the target procedure in the invariant environment.
Such a mechanism in HBS is called the target context.

The target context assures that the following variables are not affected by dependee or dependency target execution:
+ HDL library,
+ HDL standard,
+ top module name,
+ arguments prefix,
+ arguments suffix,
+ the core path,
+ the core name,
+ the target path,
+ the target name.

The following snippet presents an example of the target context mechanism:
```tcl
namespace eval pkg {
  namespace eval foo {
    proc src-foo {} {
      hbs::SetLib "lib-foo"
      hbs::AddDep pkg::bar::src-bar
      puts "foo lib: $hbs::Lib"
      puts "foo core: $hbs::ThisCorePath"
      puts "foo target: $hbs::ThisTarget"
    }
    hbs::Register
  }
  namespace eval bar {
    proc src-bar {} {
      hbs::SetLib "lib-bar"
      puts "bar lib: $hbs::Lib"
      puts "bar core: $hbs::ThisCorePath"
      puts "bar target: $hbs::ThisTarget"
    }
    hbs::Register
  }
}
```
The following snippet presents the output from running the `pkg::foo:src-foo` target:
```
[user@host tmp] hbs run pkg::foo::src-foo
bar lib: lib-bar
bar core: pkg::bar
bar target: src-bar
foo lib: lib-foo
foo core: pkg::foo
foo target: src-foo
```
As can be seen, setting library in a target of one core, does not affect library in the target of another core.


== Target dependencies

In HBS, targets might depend on other targets instead of cores depending on cores.
Such an approach allows for fine-grained control of dependencies.

To declare target dependency, you must call the `hbs::AddDep` procedure within the target procedure.
The first argument is the dependency path.
The remaining arguments are optional and are passed to the dependency procedure as arguments.

To add multiple distinct dependencies, the user must call `hbs::AddDep` multiple times.
The ability to pass custom arguments to dependency was evaluated as much more advantageous than the ability to add multiple dependencies with a single `hbs::AddDep` call.

The `hbs::AddDep` internally calls the dependency procedure with the provided arguments.
It also tracks dependencies so that generating a dependency graph is possible.
Within a single flow, each target procedure can be run at most once with a particular set of arguments.
This implies that if multiple target procedures add the same dependency with the same arguments, the dependency procedure is run only once during the first `hbs::AddDep` call.
To enforce some target procedure rerun, the user can always directly call the target.
However, enforcing target procedure rerun usually is an alert that a regular Tcl procedure shall be used instead of the core target procedure.

The bloew snippet contains an example core definitions for presenting target dependency rules.
```tcl
namespace eval core-a {
  proc target {} {
    hbs::AddDep core-b::target
    hbs::AddDep core-c::target
    hbs::AddDep generator-core::gen a
    hbs::AddDep generator-core::gen x
    puts "core-a::target"
  }
  hbs::Register
}
namespace eval core-b {
  proc target {} {
    hbs::AddDep core-c::target
    hbs::AddDep generator-core::gen b
    hbs::AddDep generator-core::gen x
    puts "core-b::target"
  }
  hbs::Register
}
namespace eval core-c {
  proc target {} {
    puts "core-c::target"
  }
  hbs::Register
}
namespace eval generator-core {
  proc gen {arg} {
    puts "generator-core::gen $arg"
  }
  hbs::Register
}
```
There are four cores: `core-a`, `core-b`, `core-c`, `generator-core`.
`core-a` depends on `core-b` and `core-c`.
`core-b` depends on `core-c`.
Moreover, cores `core-a` and `core-b` depend on the `generator-core`.
However, they use different argument values for generation.

The following snippet presents output from running target `core-a::target`:
```
[user@host tmp]$ hbs run core-a::target
core-c::target
generator-core::gen b
generator-core::gen x
core-b::target
generator-core::gen a
core-a::target
```
As can be seen, the `core-c::target` is run only once, even though both `core-a::target` and `core-b::target` depend on it.
This is because `core-c::target` has no arguments and can be added as a dependency only once.
On the other hand, `generator-core::gen` is run three times.
This is because `generator-core::gen` is added as a dependency four times, and three times with a distinct argument value.


== EDA tool flow and stages <eda-tool-flow-and-stages>

The primary function of any hardware build system is to provide the ability to build a design.
What the term "build" actually means usually depends on the EDA tool.
For some, it is only synthesis; for others, it is synthesis and implementation, and yet for others it might be simulation or just code linting.
Each EDA tool is characterized by a distinct flow consisting of different stages.
To mimic this behavior, HBS supports the following stages (alphabetical order):
+ analysis - HDL files analysis,
+ bitstream - device bitstream generation,
+ elaboration - design elaboration,
+ implementation - design implementation,
+ project - project creation,
+ simulation - design simulation,
+ synthesis - design synthesis.

Not all stages make sense for all EDA tools.
Which stages are present in the given tool flow depends on that tool implementation.
Namely, on the implementation of the `hbs::<tool>::run` procedure.
This is a tool private procedure.
This procedure is called at the end of the `hbs::Run` procedure execution, which is a HBS public procedure.

The following figure shows the structure of the tool flow for the Vivado project mode (`vivado-prj`):
#align(center)[
  #image("images/vivado-flow.pdf", width: 50%)
]

There are four stages: project, synthesis, implementation and bitstream.
Each stage is wrapped by custom, user-defined callbacks.
The number of callbacks is unlimited.
Callbacks in any pre or post stage are executed in the order you add them.
You can add a callback by calling a dedicated HBS API procedure.
For example, to add a post synthesis callback you can call the `hbs::AddPostSynthCb` procedure.
Callbacks can be added with custom argument values.

The post stage callbacks and pre stage callbacks for adjacent stages were added for two reasons.
+ To clearly communicate which stage the callback refers to.
  For example, configuring implementation settings based on the synthesis results can be done in a post-synthesis callback or pre-implementation callback.
  However, as the callback modifies the implementation settings, it is probably better to add it using the `hbs::AddPreImplCb`, than `hbs::AddPostSynthCb`.
+ To introduce, to some extent, a manageable order of callbacks execution.
  The pre and post callbacks of a given stage are executed in the order they are added.
  If some nested dependencies add callbacks for the same pre or post stage, then the order of callbacks execution depends on the order of `hbs::AddDep` calls.
  However, if the result of one of the callbacks depends on the result of the other one, then relying on a user to call the `hbs::AddDep` procedures in proper order is error prone.
  In such a case, the callback that must be executed as the first one can be added to the post-synthesis callbacks, and the second callback can be added to the pre-implementation callbacks.
  Such an approach is immune to the order of `hbs::AddDep` calls.

You can utilize stage callbacks in any desired way.
However, the primary purpose of stage callbacks is to adjust the design build based on the results from a particular stage.
For example, you might want to configure additional implementation settings based on the synthesis results.
You might even terminate the tool flow in a given callback and report an error if certain conditions are not met.

To get to know stages supported by a given EDA tool you can call `'hbs doc <tool>'` command.
The following snippet presents documentation message for the GHDL simulator.
```
[user@host tmp] hbs doc ghdl
# GHDL simulator
#
# HBS requires that GHDL is compiled with the LLVM or GCC backend.
# It does not support GHDL with mcode backend.
#
# GHDL supports the following stages:
#   - analysis,
#   - elaboration,
#   - simulation.
```

== EDA tool commands custom arguments

The HBS has a minimal common abstraction layer.
You perform all the actions not covered by the abstraction layer by directly calling EDA tool commands.
For example, generating extra timing or clock network reports.
However, some of the actions are hidden under the HBS API.
For example, adding or analyzing HDL files.
EDA tool commands used to perform actions hidden under common API usually have some parameters that are not used by default.
Nevertheless, sometimes there is a need to specify additional parameters.
In such a case, there are two possible solutions.
+ The first option is to bypass the HBS API and directly call the underlying EDA tool command.
  The drawback of this approach is that the user must manually handle the current context.
  For example, when adding an HDL file, the user must manually specify the library or standard revision.
  Bypassing HBS API also bypasses the target context!
+ The second option is to set the underlying command arguments prefix or suffix.
  This can be achieved with the `hbs::SetArgsPrefix` and `hbs::SetArgsSuffix` procedures.
  The argument prefix is always appended after the command name, and the argument suffix is always appended after all command arguments.

The following snippet presents Ethernet Management Data Input/Output (MDIO) core definition:
```tcl
namespace eval vhdl::ethernet {
  namespace eval mdio {
    proc src {} {
      hbs::SetLib "ethernet"
      hbs::AddFile mdio.vhd
    }
    proc tb {} {
      hbs::SetTool "nvc"
      hbs::AddPostElabCb hbs::SetArgsPrefix "--messages=compact"
      src

      hbs::SetLib ""
      hbs::AddFile tb/tb-mdio.vhd
      hbs::SetTop "tb_mdio"
      hbs::Run
    }
    hbs::Register
  }
}
```
The core has one testbench target utilizing the nvc simulator.
Nvc report messages occupy multiple lines by default.
However, this can be changed by specifying the `--messages=compact` argument when running the simulation.
As running the simulation is the last stage of the nvc flow, the call to `hbs::SetArgsPrefix` must be wrapped by the call to the `hbs::AddPostElabCb` procedure.

The following snippet shows commands executed by the HBS to run the simulation:
```
[user@host vhdl-ethernet]$ hbs run vhdl::ethernet::mdio::tb
nvc --std=2019 -L. --work=ethernet -a vhdl/vhdl-ethernet/mdio.vhd
nvc --std=2019 -L. --work=work -a vhdl/vhdl-ethernet/tb/tb-mdio.vhd
nvc --std=2019 -L. -e tb_mdio
nvc --messages=compact --std=2019 -L. -r tb_mdio --wave
```
The `--messages=compact` argument was appended right after the `nvc` command.


== HBS API extra symbols

The HBS API consists not only of symbols related to the common EDA abstraction layer.
For example, there are extra `hbs::Exec` and `hbs::CoreDir` procedures.
The first one is a wrapper for the Tcl standard `exec` procedure.
Before calling `exec`, the `hbs::Exec` changes the working directory to the directory where the currently evaluated core is defined.
When `exec` returns, the `hbs::Exec` restores the working directory.
The `hbs::CoreDir` procedure allows the user to get the path of the directory in which the currently evaluated core is defined.

HBS also provides users with the following extra variables:
+ `hbs::ThisCorePath` - the path of the core which target is currently being run,
+ `hbs::ThisCoreName` - the name of the core which target is currently being run,
+ `hbs::ThisTargetPath` - the path of the target which is currently being run,
+ `hbs::ThisTargetName` - the name of the target which is currently being run,
+ `hbs::RunCorePath` - the path of the run core,
+ `hbs::RunCoreName` - the name of the run core,
+ `hbs::RunTargetPath` - the path of the run target,
+ `hbs::RunTargetName` - the name of the run target,
+ `hbs::RunTargetArgs` - the list with command line arguments passed to the run target.

To get the list of all HBS public symbols you can run `'hbs doc'` command in the shell.


== Code generation <code-generation>

Code generation in the hardware design domain is omnipresent, as it significantly speeds up the implementation process.
For example, hardware-software co-design system on chip projects usually have some tool automatically generating register files.
Even in pure FPGA designs, it is common to generate descriptions at the register transfer level from some higher-level programming abstraction.
That is why it is important for any hardware build system to provide as simple mechanism for code generation as possible.

Some existing hardware build systems do not allow the direct calling of an arbitrary external program in arbitrary places during the build process.
Instead, you have to define so-called generators.
Only then can you call the generator wihtin core definitions.
However, such an approach has some drawbacks:
+ The generator call requires an extra layer of indirection.
  Generators are defined in different places than they are used, which decreases the readability of the description.
+ The generator call syntax does not resemble shell command call syntax.
  Generators are usually regular applications that can be executed in a shell.
  Calling a generator within the build system using syntax similar to shell seems natural.

In HBS, there is no formal concept of generator.
Anything can be a generator, as generators are just regular Tcl procedures.
This means that generators can be target procedures (tracked by dependency system) or core internal Tcl procedures (not tracked by the dependnecy system).

The bellow snippet presents an example of calling an external code generator tracked by the dependnecy system:
```tcl
namespace eval core {
  proc top {} {
    hbs::AddDep generator::gen "foo"
    puts "Adding file top.vhd"
    # hbs::AddFile top.vhd
  }
  hbs::Register
}
namespace eval generator {
  proc gen {name} {
    exec echo "Generating $name.vhd" >@ stdout
    puts "Adding file $name.vhd"
    # hbs::AddFile "$name.vhd"
  }
  hbs::Register
}
```
In actual usage, the call to the shell `echo` command would be replaced with a call to the proper code generator program.
Calls to the `hbs::AddFile` are commented out because no EDA tool was set.

The following snippet presents how to achieve the same result without tracking the generator as a dependency.
```tcl
namespace eval core {
  proc top {} {
    exec echo "Generating foo.vhd" >@ stdout
    puts "Adding file foo.vhd"
    # hbs::AddFile "foo.vhd"

    puts "Adding file top.vhd"
    # hbs::AddFile top.vhd
  }
  hbs::Register
}
```
This task is even more straightforward, as you can call an external generator program directly in the target procedure.


== HDL default standard revisions

There are numerous discrepancies between EDA tools in supporting various HDL standard revisions.
For example:
- the default standard revision might differ,
- the minimum supported standard revision might differ,
- the maximum supported standard revision might differ,
- the set of supported standard revisions might vary.
HBS tries to unify the default HDL standard revision in the least disruptive way.

For VHDL, the default standard revision is 2008.
The 2008 revision was a significant language modernization with numerous useful features being added.
Moreover, it was widely adopted and is supported in all actively maintained EDA tools.

For Verilog/SystemVerilog, the default standard revision is 2012.
This revision probably has the widest adoption.
Moreover, UVM was designed to work with revision 2012.
Some tools come with the standard revision 2017 being the default one.
However, most of them support only part of the things introduced in this revision.

When you set standard revision (`hbs::SetStd` procedure) in your hbs files, it might turn out that a particular tool does not support this standard, even if the set revision is a valid revision for a given language.
Two things might happen in this scenario.
+ If the tool does not support the standard revision you set and any higher standard revision, `hbs.tcl` will exit with an error.
  An example error message is presented in the following snippet:
  ```
  core::target: hbs::ghdl::addVhdlFile: /home/user/workspace/hbs-tests/SetStd/ghdl-unsupported-std/abc.vhd: ghdl doesn't support VHDL standard '2019'
  ```
+ If the tool supports any higher standard revision, the set standard revision will be automatically upgraded to the nearest standard supporting features present in the standard you set.
  For example, you cannot enforce compatibility with SystemVerilog standard revisions 2005, 2009, and 2012 in Gowin.
  However, Gowin claims support for SystemVerilog standard revision 2017.
  In such a case, if you set the standard to 2005, 2009, or 2012, it will be automatically upgraded to 2017.


== HBS environment variables

HBS utilizes some environment variables.
Some of them are used internally, for example, `HBS_TOOL_BOOTSTRAP`, and some can be set by the user to control HBS behavior.

=== HBS\_TOOL\_BOOTSTRAP - hbs.tcl bootstraps itself

The `HBS_TOOL_BOOTSTRAP` environment variable is entirely managed by the `hbs.tcl` file.
Do not set or unset this variable manually.
The variable is required because `hbs.tcl` sometimes must bootstrap itself.
For example, if `hbs::Tool` is set to `"vivado-prj"`, but `hbs.tcl` was run with the OS Tcl shell (`tclsh`), then `hbs.tcl` must bootstrap itself with the Tcl shell embedded in the Vivado.

=== HBS\_DEBUG - debugging build flow

By setting the `HBS_DEBUG` environment variable, you can enable debug messages.
Debug messages are printed to the standard error.
This means that you can enable debug messages in dry runs and still be able to redirect debug messages and tool commands independently.

You can extend debug messages with custom messages from your hbs files.
There is `hbs::Debug` procedure which you can use for conditionally printing messages when the `HBS_DEBUG` environment variable is set.
Messages printed with the `hbs::Debug` are always prefixed with the path of the procedure in which `hbs::Debug` is called.
See `'hbs doc Debug'` for more details.

If you need a more advanced logging mechanism with multiple levels, you can implement it on top of `hbs::Debug`.
Alternatively, you can implement a custom logging mechanism.
To check if the `HBS_DEBUG` environment variable is set you can check the value of the `hbs::DebugEnvSet` variable instead of calling `[info exists ::env(HBS_DEBUG)]`.
HBS is not planned to natively support multi-level logging mechanism.
The dry runs and `HBS_DEBUG` are probably more than enough for debugging build flows.

=== HBS\_DEVICE - enforcing device

By setting the `HBS_DEVICE` environment variable, you can enforce the value of the `hbs::Device`.
If `HBS_DEVICE` is set, then `hbs.tcl` during initialization (before any hbs file is sourced) sets the value of `hbs::Device` to the value of `HBS_DEVICE`.
If `HBS_DEVICE` is set, any call to the `hbs::SetDevice` is ignored.

The `HBS_DEVICE` variable might be useful for determining the target device for the build from the shell.
Similar functionality can be achieved using the target parameters described in @arch-target-parameters.
However, you may want to utilize target parameters for different purposes.

=== HBS\_EXIT\_SEVERITY - enforcing exit severity

By setting the `HBS_EXIT_SEVERITY` environment variable, you can enforce the value of the `hbs::ExitSeverity`.
If `HBS_EXIT_SEVERITY` is set, then `hbs.tcl` during initialization (before any hbs file is sourced) sets the value of `hbs::ExitSeverity` to the value of `HBS_EXIT_SEVERITY`.
If `HBS_EXIT_SEVERITY` is set, any call to the `hbs::ExitSeverity` is ignored.

The `HBS_EXIT_SEVERITY` environment variable is useful for quickly running testbenches with modified exit severity.
For example, your simulation suddenly starts failing, and you would like to stop it when the first warning is encountered.

=== HBS\_TOOL - enforcing tool <hbs-tool>

By setting the `HBS_TOOL` environment variable, you can enforce the value of the `hbs::Tool`.
If `HBS_TOOL` is set, then `hbs.tcl` during initialization (before any hbs file is sourced) sets the value of `hbs::Tool` to the value of `HBS_TOOL`.
If `HBS_TOOL` is set, any call to the `hbs::SetTool` is ignored.

The `HBS_TOOL` environment variable is helpful in running testbench targets with different simulators.
If you want to run just a single testbench target with multiple simulators, then you can use a target parameter (see @arch-target-parameters) for your testbench target, or you can set the `HBS_TOOL` environment variable.
However, if you want to run multiple testbench targets using the `'hbs test'` command, you must utilize the `HBS_TOOL` environment variable.
This is because `'hbs test'` does not support passing arguments to testbench targets.

*Be careful!*
Some simulators, for example, `nvc` and `questa`, might share some directories or file names.
If you run a testbench with one simulator, then running the same testbench with a different simulator in the same directory without cleaning it might result in errors.
It is advised to clean the build directory before running the same testbench with a different simulator.
If you run your testbenches with multiple simulators in the continuous integration pipeline, then you probably want to store all build results for all simulators.
In such a case, you can change the build directory for other simulators using the `HBS_BUILD_DIR` environment variable.
This is presented in the following snippet:
```sh
# Run all testbenches with nvc and place them in build-nvc directory.
export HBS_TOOL=nvc
export HBS_BUILD_DIR=build-nvc
hbs test
# Run the same testbenches with questa and place them in build-questa directory.
export HBS_TOOL=questa
export HBS_BUILD_DIR=build-questa
hbs test
```

=== HBS\_STD - enforcing HDL standard revision

By setting the `HBS_STD` environment variable, you can enforce the value of the `hbs::Std`.
If `HBS_STD` is set, then `hbs.tcl` during initialization (before any hbs file is sourced) sets the value of `hbs::Std` to the value of `HBS_STD`.
If `HBS_STD` is set, any call to the `hbs::SetStd` is ignored.

The `HBS_STD` environment variable is analogous to the `HBS_TOOL` environment variable.
However, running multiple, or even one, testbench targets with different HDL standard revisions is probably not useful.
The `HBS_STD` environment variable is rather handy for quickly checking if a given target can run with a different HDL standard revision.

=== HBS\_BUILD\_DIR - changing build directory

By setting the `HBS_BUILD_DIR` environment variable, you can enforce the value of the `hbs::BuildDir`.
If `HBS_BUILD_DIR` is set, then `hbs.tcl` during initialization (before any hbs file is sourced) sets the value of `hbs::BuildDir` to the value of `HBS_BUILD_DIR`.
If `HBS_BUILD_DIR` is set, any call to the `hbs::SetBuildDir` is ignored.
The usefulness and functionality of `HBS_BUILD_DIR` are described in @hbs-tool
