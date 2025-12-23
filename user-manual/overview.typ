= Overview

Hardware Build System (HBS) is a build system for hardware design projects.
A build system for hardware design collects and processes files required for FPGA programming, ASIC production, running functional simulation, or carrying out formal verification.
The files required to obtain the desired output usually include much more than just classic hardware description files, such as VHDL or SystemVerilog sources.
For example, any synthesis or place and route tool requires design constraints, at least for pin location and timing closure analysis.
Moreover, most real projects are not implemented from scratch and utilize third-party IP cores.
Those IP cores might be provided in different formats.
Sometimes, they might even be encrypted.
HBS tries to support all files that might potentially be required to generate a final result.
HBS is not limited to managing only pure hardware description files.

HBS can be described as a Tcl-based, minimal common abstraction approach for build system for hardware designs.
This is because HBS implements a common abstraction layer that is:
- minimal,
- limited to the primary common features,
- implemented in Tcl.
However, do not be misled by the word minimal.
Only the common abstraction layer is minimal.
HBS is designed in such a way that it is straightforward to utilize EDA tools' exclusive features.
This was achieved by implementing HBS in Tcl.
The HBS build system code is executed directly by the Tcl shell embedded in EDA tools.
This, in turn, grants direct access to the EDA tools' Tcl commands during the build execution.
HBS is not a tool for preparing Tcl code that is later executed by EDA tools.
HBS is a tool which code is executed by EDA tools.
