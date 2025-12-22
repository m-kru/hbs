#text(16pt)[
*Glossary*
]

#set par(justify: true)

Not all terms defined in the glossary list are used in the user manual.
Some of them are formally defined because they are helpful when discussing, for example, core definition.

#v(0.5cm)

#set terms(separator: v(0cm), hanging-indent: 1em)

#block(breakable:false)[
/ API:
  Application Programming Interface
]

#block(breakable:false)[
/ core:
  Tcl namespace in which `hbs::Register` proc is called.
]

#block(breakable:false)[
/ core name:
  Name of the Tcl namespace in which `hbs::Register` is called.
  For example, if `hbs::Register` is called in namespace `lib::pkg::my-core`, then `my-core` is the core name.
]

#block(breakable:false)[
/ core path:
  Tcl namespace for the core.
  For example, if `hbs::Register` is called in namespace `lib::pkg::my-core`, then `lib::pkg::my-core` is the core path.
]

#block(breakable:false)[
/ dependency:
  A target on which at least one other target depends.
  The dependency is an argument for at least one `hbs::AddDep` proc call.
]

#block(breakable:false)[
/ depender:
  A target depending on at least one another target.
  Within a depender body the `hbs::AddDep` proc is called at least once.
]

#block(breakable:false)[
/ EDA:
  Electronic Design Automation
]

#block(breakable:false)[
/ flow:
  An ordered set of actions taken by a tool to produce a result specified by a user.
]

#block(breakable:false)[
/ hbs file:
  A file with `.hbs` extension containing valid Tcl code.
]

#block(breakable:false)[
/ proc:
  A Tcl procedure.
]

#block(breakable:false)[
/ stage:
  A piece of a tool flow with a clearly defined task and output.
  The number and types of stages depend on a tool.
  For example, the GHDL has analysis, elaboration and simulation stages.
]

#block(breakable:false)[
/ target:
  A proc, which name does not start with the floor character (\_), defined in core.
]

#block(breakable:false)[
/ target name:
  The name of the target in the target path.
  For example, if the target path is `lib::pkg::my-core::my-target`, then the target name is `my-target`.
]

#block(breakable:false)[
/ target path:
  The Tcl path for the target.
  For example, if proc `my-target` is defined in the core with the core path `lib::pkg::my-core`, then the target path is `lib::pkg::my-core::my-target`.
]

#block(breakable:false)[
/ tool:
  A software capable of processing hardware description sources or output from another tool.
  Example tools are: GHDL, Verilator, yosys, Vivado, nvc, etc.
]

#block(breakable:false)[
/ to run a target:
  To execute commands defined in the target.
]

#pagebreak()
