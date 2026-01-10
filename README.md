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
- `HBS_EXIT_SEVERITY` environment variable for enforcing exit severity.
- `HBS_BUILD_DIR` environment variable for enforcing build directory.
- `HBS_TOOL` environment variable for enforcing tool.
- `HBS_STD` environment variable for enforcing HDL standard revision.
- `-onerror quit` argument for xsim.
- `hbs::ExitSeverity` variable for unifying exit condition in simulators.

### Changed
- Improved error messages.
- Improved regex for errors and warnings.
- `vivado-prj`: Part is set immediately as `hbs::SetDevice` is called.
- `vivado-prj`: Bitstream file name changed from current project name to `hbs::Top`.
  This is required for `write_hw_platform -include_bit` command to work without any extra actions.

### Fixed
- Generics handling for xsim.
- `test` command returns an error if any test fails.
