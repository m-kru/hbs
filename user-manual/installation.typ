= Installation

All installation methods require that `hbs` and `hbs.tcl` files are placed in the same directory.
There are four preferred installation methods.

+ Copy `hbs` and `hbs.tcl` files to your project.
  This is preferred if you want to modify HBS source files change its default behavior.
  It is not advised to change the default behavior, but if you need, feel free to adjust the build system to your project needs.
+ Copy `hbs` and `hbs.tcl` files to one of the directories in the `$PATH` environment variable.
+ Clone the repository and add its path to the `$PATH` environment variable.
+ Clone the repository and add an alias to the `hbs` file in `.bashrc` file (or equivalent).

== HBS Dependencies

HBS has three dependencies, one mandatory and two optional.
+ `tclsh (version >= 8.5)`.
+ `python3` - required for testbench target detection, automatic testbench running and dependency graph generation.
  If mentioned functionalites are not required, you can directly used `hbs.tcl` script instead of the `hbs` Python wrapper.
+ `graphviz` - required only if user wants to generate a dependency graph.
