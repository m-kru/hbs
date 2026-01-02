# ![Logo](user-manual/images/hbs.svg) HBS - Hardware Build System

HBS is a Tcl-based, minimal common abstraction build system for hardware design projects.

## Documentation

Please check the official [HBS user manual](https://github.com/m-kru/hbs/blob/master/user-manual/hbs-user-manual.pdf).

## Supported tools

- ghdl,
- gowin,
- modelsim - set tool to questa,
- nvc,
- questa,
- vivado-prj - Vivado project mode,
- xsim - Vivado simulator.

# Changelog

## [Unreleased]

### Added

- Questa simulator support.
- `HBS_BUILD_DIR` environment variable for enforcing build directory.
- `HBS_TOOL` environment variable for enforcing tool.
- `HBS_STD` environment variable for enforcing HDL standard revision.
- `-onerror quit` argument for xsim.
- `hbs::ExitSeverity` variable for unifying exit condition in simulators.

### Changed
- Improved error messages.

### Fixed
- Generics handling for xsim.
