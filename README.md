[![Tests](https://github.com/m-kru/hbs/actions/workflows/tests.yml/badge.svg?branch=master)](https://github.com/m-kru/hbs/actions?query=master)

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

- `dry-run` command for dry run and previewing commands.
- Questa simulator support.
- `HBS_DEBUG` environment variable for debugging prints.
- `HBS_DEVICE` environment variable for enforcing device.
- `HBS_BUILD_DIR` environment variable for enforcing build directory.
- `HBS_TOOL` environment variable for enforcing tool.
- `HBS_STD` environment variable for enforcing HDL standard revision.
- `-onerror quit` argument for xsim.
- `hbs::ExitSeverity` variable for unifying exit condition in simulators.

### Changed
- Improved error messages.
- Improved regex for errors and warnings.

### Fixed
- Generics handling for xsim.
- `test` command returns an error if any test fails.
