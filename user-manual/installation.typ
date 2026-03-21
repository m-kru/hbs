= Installation

There are the following four preferred installation methods:

+ Copy the `hbs` file to your project.
  This is preferred if you want to modify `hbs` default behavior.
  It is not advised to change the default behavior, but if you need, feel free to adjust the build system to your project needs.
+ Copy `hbs` file to one of the directories in the `$PATH` environment variable.
+ Clone the repository and add its path to the `$PATH` environment variable.
+ Clone the repository and add an alias to the `hbs` file in `.bashrc` file (or equivalent).

== HBS Dependencies

The HBS has only the following two dependencies, one mandatory and one optional:
+ `tclsh (version >= 8.5)`,
+ `graphviz` - required only if you want to generate a dependency graph.
