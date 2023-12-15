# HBS - Hardware Build System

HBS is a build system for hardware description projects.
HBS was created out of frustration with all existing build systems for hardware description.

Existing hardware build systems can be divided into two classes.

The first class directly utilizes Tcl (the Tcl approach), examples:
- [vivado-build-system](https://github.com/missinglinkelectronics/vivado-build-system),
- [vextproj](https://github.com/wzab/vextproj),
- [OSVVM-Scripts](https://github.com/OSVVM/OSVVM-Scripts).

The second class tries to abstract away the underlying Tcl commands using declarative formats (the declarative approach), examples:
- [FuseSoC](https://github.com/olofk/fusesoc),
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

## Running targets

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

		if {$hbs::Tool == "vivado"} {
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
For example, the `hbs::Tool` can be `ghdl`, `vivado` etc.
The `hbs::GetToolType` proc can return `formal`, `simulation`, or `synthesis`.
The points of this is to avoid error cases when one core maintainer sets the tool to `Vivado`, but another core maintainer has for example following condition in one of the targets `if {$hbs::Tool == "vivado"}`.
The expression would evaluate to false, although the tool is Vivado.
The `hbs::Set*` procs make sure users provide lowercase names.

### Core and target names

There is no restriction on core and target names placed in `.hbs` files.
Everything accepted by the Tcl is valid.
However, it is recommended to use lowercase and separate words with hyphen character `-`.
