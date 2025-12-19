#import "vars.typ"

#v(2cm)

#set align(center)

#image("hbs.svg", width: 20%)

#v(2cm)

#text(18pt)[
*Hardware Build System* \
*User Manual*
]

#text(11pt)[
Revision #vars.rev

#datetime.today().display("[day padding:none] [month repr:long] [year]")
]

#v(2cm)

#text(12pt)[
_Abstract_
]

#set align(left)

#par(justify: true)[
This document serves as the official user manual for Hardware Build System (HBS).
HBS is a Tcl-based, minimal common abstraction approach for build system for hardware designs.
The main goals of the system include simplicity, readability, a minimal number of dependencies, and ease of integration with the existing Electronic Design Automation (EDA) tools.
]

#v(2cm)

#par(justify: true)[
*keywords*:
automation,
hardware build system,
hardware design,
hardware synthesis,
project maintenance,
testbench runner,
simulation,
FPGA,
ASIC,
productivity
]

#pagebreak()
