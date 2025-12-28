= Tcl tips

== Support for arrow keys in `tclsh`

If you every tried to use `tclsh` to REPL (read-eval-print-loop), you probably realized that `tclsh` by default does not support arrow keys.
You can't fix a typo in a line without deleting some line content.
There is also no command history support.
However, this can be improved.
The first solution is install the `rlwrap` programm and call `rlwrap tclsh` instead of `tclsh`.
To make it shorter to type, you can define an alias for your shell of choice, for example, for bash alias `tclsh='rlwrap tclsh'`.
The second option is to install the Tcl `tclreadline` package.
This package often comes as OS distro package.
For example, on Debian/Ubuntu, you can install it with `apt install tcl-tclreadline`.
Once installed, create `.tclshrc` file in your home directory and add the following content:
```
package require tclreadline
tclreadline::Loop
```
Not only you will get support for arrow keys and command history, but also improved prompt.


== Passing variadic arguments to proc

To pass variadic arguments to a proc, the last proc parameter must be called `args`.
You can then easily iterate over the arguments using the `foreach` loop.
The following example is taken directly from the hbs Tcl source code:
```tcl
proc AddFileIgnoreRegex {args} {
  foreach reg $args {
    hbs::dbg "adding ignore regex $reg"
    lappend hbs::FileIgnoreRegexes $reg
  }
}
```
