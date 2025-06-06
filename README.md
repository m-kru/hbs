# ![Logo](hbs.svg) HBS - Hardware Build System

HBS is a build system for hardware design projects.
HBS was created out of frustration with all existing build systems for hardware description.

This README contains a practical description.
More theoretical and conceptual description can be found in [HBS - Hardware Build System: A Tcl-based, minimal common abstraction approach for build system for hardware designs](https://www.arxiv.org/pdf/2504.09642).

Existing hardware build systems can be divided into two classes.

The first class directly utilizes Tcl (the direct Tcl approach), examples:
- [vivado-build-system](https://github.com/missinglinkelectronics/vivado-build-system) - works with Vivado only,
- [vextproj](https://github.com/wzab/vextproj) - works with Vivado only,
- [OSVVM-Scripts](https://github.com/OSVVM/OSVVM-Scripts) - works with multiple tools, but targets only simulation.

The second class tries to abstract away the underlying Tcl commands usually using declarative formats (the indirect abstract approach), examples:
- [Blockwork](https://blockwork.intuity.io/),
- [flgen](https://github.com/pezy-computing/flgen) - filelist generator only,
- [FuseSoC](https://github.com/olofk/fusesoc),
- [Hog](https://gitlab.com/hog-cern/Hog) - intended to be used with git only,
- [Hdlmake](https://ohwr.org/project/hdl-make),
- [bender](https://github.com/pulp-platform/bender),
- [bazel_rules_hdl](https://github.com/hdl/bazel_rules_hdl),
- [SiliconCompiler](https://github.com/siliconcompiler/siliconcompiler),
- [HAMMER](https://github.com/ucb-bar/hammer),
- [orbit](https://github.com/cdotrus/orbit) - package manager only.

EDA tools are built around Tcl.
The discussion of whether it is good or bad makes no sense
I is how it is.
Most people don't like Tcl.
I don't understand why because when you understand its paradigm, you will think that it is actually quite well-designed.

The idea of using some wrapper abstract approach seems to be the solution to all problems.
At first ...
However, executing arbitrary Tcl commands in arbitrary places is a relatively complex task in the indirect abstract approach.
Moreover, the tools that represent this approach are overly complex (opinion).
Just look at the number of files in their repositories.
And that is not all, as they also have external dependencies.
The indirect abstract approach is structured of multiple layers of abstractions.
You can spend hours trying to figure out how to do some uncommon things, only to find out later that what you want to do is not yet possible.
You end up `sed`ing automatically generated Tcl scripts or Makefiles.
The readability of the project decreases.

There is no official package or dependency manager for hardware description projects (something like `pip` for Python, `npm` for Node.js, or `cargo` for Rust).
As a result, we end up doing the so-called in-tree dependency management.
In practice, people just manually or semi-automatedly copy dependencies to the project sources (the dependencies sources are kept in the tree of project directory, hence "in-tree").
Personally, I really like the in-tree dependency management, as it forces you to be really conscious about what is included in the project.
It also helps to avoid bloat.
Declarative formats are not optimal for in-tree dependency management (opinion).
Different dependencies might require completely different commands to be executed to fetch them and prepare them for use.
In such a case, the procedural approach is desired.
In most of the declarative approaches, the user declares a script that has to be called to execute those commands, instead of simply calling the commands.
This adds an unnecessary intermediate layer and increases complexity.

The above drawbacks of the indirect abstract approach determined that HBS should directly utilize Tcl.
Calling external programs from a Tcl script is much easier than injecting arbitrary Tcl code into arbitrary places in an automatically generated script.

I think the following sentences accurately describe what HBS is like:
> HBS makes simple things insignificantly harder, but makes complex things exceptionally easy.
> It tries to be smart, but not to outsmart the user.

Or more satiristically:
> Developers hate him, he implemented hardware build system with single Tcl script.

## Examples

- [VHDL APB library](https://github.com/m-kru/vhdl-amba5/tree/master/apb)
- [VSC8211 PHY tester](https://github.com/m-kru/vsc8211-tester)

## Core features

- Consists solely of one Tcl script and one Python wrapper script. The Python script is required only for automatic tests run and dependency graph generation.
- Core targets depend on other cores targets, not solely on cores.
- Tcl script executed directly by EDA tools, which makes custom commands execution straightforward.
- Support for globbing when adding files.
- Easy injection of custom command arguments.
- Automatic detection of test targets.
- Parallel execution of test targets.
- Dependency graph generation.
- Only two mandatory dependencies `tclsh` (`>= 8.5`) and `python3`, and one optional `graphviz` (required only if user wants to generate dependency graph).
- Arbitrarily deep core paths, no VLNV restriction.
- Support for arguments passing from command line to target being run.
- Support for arguments passing to dependency targets.
- Version control system agnosticity.
- The same command line interface on local machine and remote (CI/CD).

## Supported tools

- [GHDL](https://github.com/ghdl/ghdl)
- [GOWIN](https://www.gowinsemi.com/en/)
- [NVC](https://github.com/nickg/nvc)
- [Vivado](https://www.xilinx.com/products/design-tools/vivado.html) (currently only project mode is supported)
- xsim

Adding support for a new tool is trivial once you are familiar with the tool interface.
If you want to add support for a tool you have to create a new namespace called `hbs::<tool>`.
In theory the tool must provide implementation of only two procs, `addFile` for handling files with extensions supported by the tool, and `run` for running the tool flow.
In practice, it is useful to have additional helper procs.
Within the tool namespace any valid Tcl code is allowed.
Try to adjust flow stages to the existing stages (check `hbs doc Run` for documentation on existing stages).
However, if you feel more stages are required feel free to propose them.
In the case of tools utilizing Tcl internally the script has to be run by the embedded Tcl interpreter.
This is achieved by recursively rerunning the script.
A good example is the snippet for the `vivado-prj` tool inside the `SetTool` proc.

## Installation

All installation methods require that `hbs` and `hbs.tcl` are placed in the same directory.
There are 3 preferred installation methods.

1. Copy `hbs` and `hbs.tcl` to your project. This is preferred if you want to modify the `hbs.tcl` to change the default behavior. It is not advised to change the default behavior, but if you need, feel free to do so.
2. Copy `hbs` and `hbs.tcl` to one of the directories in `$PATH`.
3. Clone the repository and add an alias to the `hbs` in `.bashrc` (or equivalent).

### Dependencies

Mandatory:
- `tclsh` (`>= 8.5`).

Optional:
- `python3` - required only for testbench target detection, automatic testbench running and dependency graph generation,
- `graphviz` - required only if user wants to generate dependency graph.

## HBS Tcl API

To get the list of public symbols constituting the HBS Tcl API run the `hbs doc` command.
To get documentation for a given symbol, simply run `hbs doc <symbol-name>`.

## Glossary

- **hbs file** - file with `.hbs` extension containing valid Tcl code.
- **proc** - Tcl proc.
- **core** - Tcl namespace in which `hbs::Register` proc is called.
- **core path** - Tcl namespace path for the core. For example, if `hbs::Register` is called in namespace `lib::pkg::core`, then `lib::pkg::core` is the core path.
- **core name** - name of the Tcl namespace in which `hbs::Register` is called. For example, if `hbs::Register` is called in namespace `lib::pkg::core`, then `core` is the core name.
- **target** - proc, which name does not start with the floor character (`_`), defined in core.
- **target path** - Tcl path for the target. For example, if proc `target` is defined in the core with core path `lib::pkg::core`, then the target path is `lib::pkg::core::target`.
- **target name** - name of the target in the target path. For example, if the target path is `lib::pkg::core::target`, then the target name is `target`.
- **to run a target** - to execute commands defined in the target.
- **depender** - a target depending on at least one another target. Within a depender body the `hbs::AddDep` proc is called at least once.
- **dependency** - a target on which at least one other target depends. The dependency is an argument for at least one `hbs::AddDep` proc call.
- **tool** - a software capable of processing hardware description sources or output from another tool. Example tools are: [GHDL](https://github.com/ghdl/ghdl), [Verilator](https://github.com/verilator/verilator), [yosys](https://github.com/YosysHQ/yosys), [Vivado](https://www.xilinx.com/products/design-tools/vivado.html), etc.
- **flow** - an ordered set of actions taken by a tool to produce a result specified by a user.
- **stage** - a piece of a tool flow with a clearly defined task and output. The number and types of stages depend on a tool. For example, the GHDL has *analysis*, *elaboration* and *simulation* stages.

## How it works

### Cores detection

When user executes `hbs` (or `hbs.tcl`) all directories, starting from the working directory, are recursively scanned to discover `.hbs`  files (symbolic links are also scanned).
Files with the `.hbs` extension are regular Tcl files that are sourced by the `hbs.tcl` script.
However, before sourcing `.hbs` files, the file list is sorted in such a way, that script with shorter path depth are sourced before script with longer path depth.
For example, if following 3 `.hbs` file were found: `a/b/c/foo.hbs`, `d/bar.hbs`, `e/f/baz.hbs`, they would be sourced in the following order: `d/bar.hbs`, `e/f/baz.hbs`, `a/b/c/foo.hbs`.
Such an approach allows controlling when custom symbols (variables and procs) are ready to use.
For example, if you have custom proc used in multiple `.hbs` files, then you can create separate `utils.hbs` file containg utility procs, and place it in the the project root directory.
Within `.hbs` files user defines cores and targets, although user is free to have any valid Tcl code in `.hbs` files.

To register a core user must call `hbs::Register` within the core namespace.
The simplest possible example is shown below:
```Tcl
namespace eval my-core {
  proc my-target {} {
    hbs::AddFile core.vhd
  }
  hbs::Register
}
```
This snippet defines one core named `my-core` containing single target named `my-target`.
The core path is `my-core` and the target path is `my-core::my-target`.
`hbs::Register` must be called at the end of the core namespace.
A common mistake is to forget to register a core.
However, `hbs` tries to remind about cores registration, for example:
```
[user@host tmp]$ hbs run lib::core::tb
core 'lib::core' not found, maybe the core is not registered (hsb::Register)
```

The core path can be arbitrarily deep, for example:
```Tcl
namespace eval my-lib::my-core {
  proc my-target {} {
    hbs::AddFile core.vhd
  }
  hbs::Register
}
```
In this case the core path is `my-lib::my-core`, and the target path is `my-lib::my-core::my-target`.
The core name is `my-core`, and the target name is `my-target`.

Multiple cores can be dfined in the same namespace.
In such a case it might be more convenient to use nested namespaces, for example:
```Tcl
namespace eval my-lib {
  namespace eval my-core1 {
    proc my-target {} {
      hbs::AddFile core.vhd
    }
    hbs::Register
  }
  namespace eval my-core2 {
    proc my-target {} {
      hbs::AddFile core.vhd
    }
    hbs::Register
  }
}
```
Above snippets defines 2 cores.
The first one with core path `my-lib::my-core1`, core name `my-core1`, target path `my-lib::my-core1::my-target`, and target name `my-target.`
The second one with core path `my-lib::my-core2`, core name `my-core2`, target path `my-lib::my-core2::my-target`, and target name `my-target.`
`hbs::Register` must be called once for every core.

### Targets detection

Hbs automatically detects targets.
Targets are all procs defined in the scope of namespaces containing a call to the `hbs::Register`.
However, to allow user to define custom helpful procs, procs with names starting with the floor character (`_`) are not treated as core targets.
The example:
```Tcl
namespace eval vhdl-simple::edge-detector {
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
  proc tb {} {
    _tb "tb_edge_detector"
    hbs::AddFile tb/tb.vhd
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
The `_tb` proc is a simple proc defined to share calls common for `tb` and `tb-comb` test targets.
Moreover, all target procs are also regular Tcl procs.
Such an approach allows for calling them in arbitrarily places.
The `_tb` proc calls `src` proc because core source files are definitely needed for core testbenches.

### Test targets

Test targets are detected automatically.
A test target is a target which name:
- starts with `tb-` or `tb_`,
- ends with `-tb` or `_tb`,
- equals `tb`.

### Running targets

Hbs allows running any target of registered cores.
Even if the target itself has nothing to do with the hardware design.
For example, running the following target:
```Tcl
namespace eval my-core {
  proc my-target {} {
    exec echo "Hello World!" >@ stdout
  }
}
```
Results with:
```
[user@host tmp]$ hbs run my-core::my-target
Hello World!
```

However, in most cases the user wants to run target related to the flow of set tool.
In such a case, instead of calling all of the required tool commands manually, the user can call `hbs::Run`.
`hbs::Run` as an optional arguments accepts the stage after which the tool flow should stop.
For more details check `hbs::Run` documentation in the `hbs.tcl` file.
After `hbs::Run` returns user can continue processing.
For example, scripts analysing code coverage, or preparing additional reports can be run.

If you are dissatisfied with what the run for your tool does by default, you can always define custom flow within the target, or as a completely separate proc.

Targets can accept arguments provided from the command line.
This is very useful for example for running flow only to the stage specified from the command line.
For example below core accept stage arguments.
```Tcl
namespace eval core {
  proc target {{stage "bitstream"}} {
    puts "Running until $stage"
    # Below line commented because this is just example.
    #hbs::Run $stage
  }
  hbs::Register
}
```
It can be run with the `stage` value specified as follows.
```
[user@host hbs]$ hbs run core::target
Running until bitstream
[user@host hbs]$ hbs run core::target synthesis
Running until synthesis
```
Other useful examples of target arguments usage is setting the simulator for test target from the command line, or changing the top level.
What the target arguments are used for is limited by the user's imagination.

## Dependencies

In HBS targets might depend on other targets (instead of cores depending on cores).
Such an approach allows for fine grained control of dependencies.
To declare target dependency user musr call `hbs::AddDep` proc within the target proc.
The first argument is dependency path.
The remaining arguments are optional and are passed to the dependency proc as arguments.
The add N distinct dependencies user must call `hbs::AddDep` N times.
The ability to pass arguments to dependency was evaluated as much more advantageous than the ability to add multiple dependencies with single `hbs::AddDep` call.

`hbs::AddDep` internally simply calls the dependency proc with provided arguments.
It also tracks dependencies so that generating dependency graph is possible.
Within single flow each target can be run at most once with particular set of arguments.
This implies, that if multiple targets add the same dependency with the same arguments, then the dependency proc is run only once, during the first `hbs::AddDep` call.
To enforce some target rerun, user can always directly call the target.

## Code generation

## Custom arguments

Commands and external programs called by the hbs under the hood have numerous flags and parameters.
Hbs uses only some of them with some sane default values.
However, the user is capable of adding extra arguments, which is achieved with `hbs::ArgsPrefix` and `hbs::ArgsSuffix` variables.
The user shall use `hbs::SetArgsPrefix`, `hbs::ClearArgsPrefix`, `hbs::SetArgsSuffix`, `hbs::ClearArgsSuffix` and `hbs::ClearArgsAffixes` procs to manipulate those variables.
The `hbs::ArgsPrefix` is inserted right after the command or program name, and `hbs::ArgsSuffix` is placed at the end of command or program call or before the final argument.
If hbs arguments affixes are insufficient, the user is always free to call commands or programs on his own.

## Naming conventions

### Internal symbol names

Understanding naming conventions is curcial for using or contributing to the hbs.
All hbs code is hidden under the `hbs` namespace.
Code related to particular tool is further hidden in the `hbs::{tool}` namespace.

Tcl doesn't allow defining private symbols within namespaces, all symbols are public.
However, hbs differentiate between public and private symbols.
Public symbols start with an uppercase letter and private symbols start with a lowercase latter.
The user shall only use public symbols within `.hbs` files.
Although using private symbols is discouraged, it is not forbidden, and if you really know what you do feel free to use them.

Hbs namespace consists of variables and procs.
Even though some varaibles are public, the user shall not set them directly.
They are public, because they can be safely read from the `.hbs` files, but setting them might require some additional actions.
For example, `hbs::Tool` is public varaible, but the user shall use `hbs::SetTool` function for setting.
There is no such requirement for getting value of a public variable.
For example, see the below snippet:
```Tcl
namespace eval vhdl-simple::reset-synchronizer {
  proc src {} {
    hbs::SetLib "simple"
    hbs::AddFile src/reset_synchronizer.vhd

    if {$hbs::Tool == "vivado-prj"} {
      hbs:AddFile constr/reset_synchronizer.xdc
      set_property SCOPED_TO_REF Reset_Synchronizer [get_files reset_synchronizer.xdc]
    } else {
      error "vhdl-simple: reset-synchronizer core misses constraint file for your tool"
    }
  }

  hbs::Register
}
```
If the tool executing the code is "vivado", then additional constraint file is added attached to particular module.
Every public `hbs::Variable` has corresponding `hbs::SetVariable` function for setting value of the variable.

All variables representing choices (enumeration) user lowercase strings.
For example, the `hbs::Tool` can be `ghdl`, `vivado-prj` etc.
The `hbs::ToolType` proc can return `formal`, `simulation`, or `synthesis`.
The points of this is to avoid error cases when one core maintainer sets the tool to `GHDL`, but another core maintainer has, for example, following condition in one of the targets `if {$hbs::Tool == "ghdl"}`.
The expression would evaluate to false, although the tool is GHDL.
The `hbs::Set*` procs make sure users provide lowercase names.

### Core and target names

There is no restriction on core and target names placed in `.hbs` files.
Everything accepted by the Tcl is valid.
However, it is recommended to use lowercase and separate words with hyphen character `-`.

## Tcl tips

- If you every tried to use `tclsh` to REPL (read-eval-print-loop), you probably realized that `tclsh` by default does not support arrow keys.
  You can't fix a typo in a line without deleting some line content.
  There is also no command history support.
  However, this can be improved.
  The first solution is install `rlwrap` programm and call `rlwrap tclsh` instead of `tclsh`.
  To make it shorter to type, you can define an alias for your shell of choice, for example, for bash `alias tclsh='rlwrap tclsh'`.
  The second option is to install Tcl `tclreadline` package.
  This package often comes as OS distro package.
  For example, on Ubuntu, you can install it with `apt install tcl-tclreadline`.
  Once installed, create `.tclshrc` file in your home directory and add the following content:
  ```
  package require tclreadline
  tclreadline::Loop
  ```
  Not only you will get support for arrow keys and command history, but also improved prompt.