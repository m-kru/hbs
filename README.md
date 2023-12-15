# HBS - Hardware Build System

HBS is a build system for hardware description projects.
HBS was created out of frustration with all existing build systems for hardware description.

Existing hardware build systems can be divided into two classes.

The first class directly utilizes Tcl (the Tcl approach), examples:
- [vivado-build-system](https://github.com/missinglinkelectronics/vivado-build-system),
- [vextproj](https://github.com/wzab/vextproj),
- [OSVVM-Scripts](https://github.com/OSVVM/OSVVM-Scripts).

The second class tries to abstract away the underlying Tcl commands using declarative formats (the declarative approach), examples:
- [FuseSuc](https://github.com/olofk/fusesoc),
- [Hog](https://gitlab.com/hog-cern/Hog),
- [Hdlmake](https://ohwr.org/project/hdl-make),
- [bender](https://github.com/pulp-platform/bender).

EDA tools are built around Tcl.
The discussion whether it is good or bad makes no sense, it is how it is.
Most people don't like Tcl (I don't understand why because when you understand its paradigm it is actually quite well designed).

The idea of using some wrapper declarative format seems to be the solution of all problems, at first ...
However, executing arbitrary Tcl commands in arbitrary place in relatively complex task in the second class of build systems.
They are also overly complicated (my opinion).
Just look at the number of files in theirs repositories.
And that is not all, as all of them also have external dependencies.
This class of tools is structured of multiple layers of abstractions.
You can spend hours trying to figure out how to do some uncommon things, to only later find out that what you want to do is not yet possible.
You end up `sed`ing automatically generated Tcl scripts or Makefiles.
The readability of the project decreases.

There is no official package or dependency manager for hardware description projects (something like `pip` for Python, `npm` for Node.js, or `cargo` for Rust).
As a result we end up doing the so called in-tree dependency management.
In practice people just manually or in a semi-automated way copy dependencies to the project sources (the dependencies sources are kept in the tree of project directry, hence "in-tree").
Personally I really like the in-tree dependency management, as it forces you to be really conscious about what is included in the project.
It also help to avoid bloat.
Declarative formats are not optimal for in-tree dependency management (my opinion).
Different dependencies might require completely different commands to be executed to fetch them and prepare for use.
In such a case, the procedural approach is what is desired.
In most of the declarative approaches user declares a script that has to called to execute those commands, instead of simply calling the commands.
This adds an unnecessary intermediate layer, and increases complexity.

The above drawbacks of the declarative approach determined HBS to directly utilize Tcl.
Calling external programs from a Tcl script is much easier than injecting arbitrary Tcl code into arbitrary place in an automatically generated script.

However, the Tcl approach is not free of drawbacks.
As Tcl is procedural, sometimes user needs to call extra commands, for example, `hbs::Register`.
HBS tries to inform user that such call might be missing.

I think the following sentences accurately describe what HBS is like:
> HBS makes simple things insignificantly harder, but makes complex things exceptionally easy.
> It tries to be smart, but not to outsmart the user.

Or more satiristically:
> Developers hate him, he built hardware built system with single Tcl script.

## Core features

- Consists solely of one Tcl script and one Python wrapper script. The Python script is required only for tests run and dependency graph generation.
- Core targets depend on other cores targets, not solely on cores.
- Tcl script executed directly by EDA tools, which makes custom commands execution straightforward.
- Support for globbing when adding files.
- Automatic detection of test targets.
- Parallel execution of test targets.
- Dependency graph generation.
- Only 2 dependencies `tclsh` and `graphviz` (required only if user wants to generate dependency graph).
- Arbitrarily deep core paths, no VLNV restriction.

## Installation

All installation methods require that `hbs` and `hbs.tcl` are placed in the same directory.
There are 3 preferred installation methods.

1. Copy `hbs` and `hbs.tcl` to your project. This is preferred if you want to modify the `hbs.tcl` to change the default behavior. It is not advised to change the default behavior, but if you need, feel free to do so.
2. Copy `hbs` and `hbs.tcl` to one of directories in `$PATH`.
3. Clone the repo, and add an alias to the `hbs` in `.bashrc` (or equivalent).

## How it works

### Cores detection

When user executes `hbs` (or `hbs.tcl`) all directories, starting from the working directory, are recursively scanned to discover `.hbs`  files (symbolic links are also scanned).
Files with the `.hbs` extension are regular Tcl files that are sourced by the `hbs.tcl` script.
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

## Running targets

## Naming conventions

All
