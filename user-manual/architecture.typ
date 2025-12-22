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


The below snippet presents a very basic flip-flop core definition.
The flip-flop core has a single target named `src`.
The core consists of a single VHDL file.

```tcl
namespace eval flip-flop {
  proc src {} {
    hbs::AddFile flip-flop.vhd
  }
  hbs::Register
}
```

To register a core, the user must explicitly call `hbs::Register` procedure at the end of the core namespace.
Such a mechanism helps to distinguish regular Tcl namespaces from Tcl namespaces representing core definitions.
If the user forgets to register a core, the build system gives a potential hint.
An example error message is presented below.

```
[user@host tmp] hbs run lib::core::tb
checkTargetExists: core 'lib::core' not found, maybe the core is not:
  1. registered 'hbs doc hbs::Register',
  2. sourced 'hbs doc hbs::IgnoreRegexes'.
```

Each core is identified by its unique path.
The core path is equivalent to the namespace path in which `hbs::Register` is called.
Using the namespace path as the core path gives the following possibilities:
+ The user can easily stick to the VLNV identifiers if required.
  This is presented in the below snippet.
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
  This is presented in the below snippet.
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
  The below snippet presents output for listing flip-flop cores.
  ```
  [user@host tmp]$ hbs list-cores
  lib::pkg1::d-flip-flop
  lib::pkg1::t-flip-flop
  lib::pkg2::jk-flip-flop
  ```

=== Excluding hbs files from being sourced

Sometimes a file with the `.hbs` extension is not a valid hbs file, or maybe you want to temporarily disable valid hbs files from being sourced.
HBS provides a built-in mechanism for excluding files with the `.hbs` extension from being sourced.
This is achieved using the `hbs::AddIgnoreRegex` function.
You just have to call this function in one of valid hbs files.
The function will be executed once the file containing the call is sourced.

Usually the hbs file containing calls to the `hbs::AddIgnoreRegex` proc is placed in the project root directory.
This is becuase hbs files placed in the project root directory are sourced before hbs files placed in subdirectories.
Order of hbs files sourcing is described in @cores-and-cores-detection.

Arguments provided to the `hbs::AddIgnoreRegex` proc are treated as regular expressions.
This allows for ignoring multiple paths using a single regex.
However, you are free to provide multiple ignore regex, and all of them will be checked while sourcing hbs files.


== Targets and targets detection

HBS automatically detects targets.
Targets are all Tcl procedures defined in the scope of core namespaces (namespaces with a call to `hbs::Register`).
However, to allow users to define custom utility procedures within cores, procedures with names starting with the floor character (`_`) are not treated as core targets.
The below snippet presents an example edge detector core definition.
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
the `hbs` program detects the following testbench targets:
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

An engineer implementing a given core, you control the dependencies of the core.
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
+ the target name,
+ the target path.

Below snippet presents an example of the target context mechanism.
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
The below snippet presents the output from running the `pkg::foo:src-foo` target.
As can be seen, setting library in a target of one core, does not affect library in the target of another core.
```
[user@host tmp] hbs run pkg::foo::src-foo
bar lib: lib-bar
bar core: pkg::bar
bar target: src-bar
foo lib: lib-foo
foo core: pkg::foo
foo target: src-foo
```


== Target dependencies

== EDA tool flow and stages

== EDA tool commands custom arguments <eda-tool-flow-and-stages>


== HBS API extra symbols

The HBS API consists not only of symbols related to the common EDA abstraction layer.
For example, there are extra `hbs::Exec` and `hbs::CoreDir` procedures.
The first one is a wrapper for the Tcl standard `exec` procedure.
Before calling `exec`, the `hbs::Exec` changes the working directory to the directory where the currently evaluated core is defined.
When `exec` returns, the `hbs::Exec` restores the working directory.
The `hbs::CoreDir` procedure allows the user to get the path of the directory in which the currently evaluated core is defined.

HBS also provides users with the following extra variables:
+ `hbs::ThisCorePath` - the path of the core which target is currently being run,
+ `hbs::ThisTargetPath` - the path of the target which is currently being run,
+ `hbs::ThisTargetName` - the name of the target which is currently being run,
+ `hbs::TopCorePath` - the path of the top core beign run,
+ `hbs::TopTargetPath` - the path of the top target being run,
+ `hbs::TopTarget` - the name of the top target being run,
+ `hbs::TopTargetArgs` - the list with command line arguments passed to the top target.

To get the list of all HBS public symbols you can run `hbs doc` command in the shell.


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

The below snippet presents an example of calling an external code generator tracked by the dependnecy system.
In actual usage, the call to the shell `echo` command would be replaced with a call to the proper code generator program.
Calls to the `hbs::AddFile}` are commented out because no EDA tool was set.
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

The following snippet presents how to achieve the same result without tracking the generator as a dependency.
This task is even more straightforward, as you can call an external generator program directly in the target procedure.
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