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

HBS was created out of frustration with all existing build systems for hardware designs.