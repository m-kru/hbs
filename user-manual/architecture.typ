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

== Targets parameters <arch-target-parameters>

== Target context <arch-target-context>

== Target dependencies

== EDA tool flow and stages

== EDA tool commands custom arguments


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
