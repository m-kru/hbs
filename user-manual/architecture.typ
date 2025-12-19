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

== Cores and cores detection

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

== Targets and targets detection

== Testbench targets

== Running targets

== Targets parameters

== Target context

== Target dependencies

== EDA tool flow and stages

== EDA tool commands custom arguments

== HBS API extra symbols

== Code generation <code-generation>
