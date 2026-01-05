#!/usr/bin/env tclsh

# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2023 Michał Kruszewski
# https://github.com/m-kru/hbs

# Public API
namespace eval hbs {
  # True (1) if tool is run in the dry mode.
  #
  # In the dry run the following things change:
  #   1. hbs.tcl does not bootstrap itself with a proper Tcl shell from EDA tool.
  #   2. Tool commands are printed to the stdout, but are not executed or evaluated.
  #
  # In the dry run cores are dumped to the .json file the same way they would be
  # dumped in the non-dry run. This is useful when you want to generate target
  # dependency graph without running any tool flow.
  set DryRun 0

  # Path of the core which target is currently being run.
  set ThisCorePath ""

  # Name of the core which target is currently being run.
  set ThisCoreName ""

  # Path of the target currently being run.
  set ThisTargetPath ""

  # Name of the target currently being run.
  set ThisTargetName ""

  # True (1) if BuildDir is set via the HBS_BUILD_DIR environment variable.
  set BuildDirEnvSet 0

  # BuildDir is the build directory path.
  #
  # You can enforce value of the BuildDir variable
  # by setting the HBS_BUILD_DIR environment variable.
  #
  # See also 'hbs doc SetBuildDir'.
  set BuildDir "build"

  # Device is target device. Often also called part.
  #
  # See also 'hbs doc SetDevice'.
  set Device ""

  # Lib is current library for adding files.
  #
  # See also 'hbs doc SetLib'.
  set Lib ""

  # True (1) if Std is set via the HBS_STD environment variable.
  set StdEnvSet 0

  # Std is current HDL standard revision for adding files.
  #
  # See also 'hbs doc SetStd'.
  set Std ""

  # True (1) if Tool is set via the HBS_TOOL environment variable.
  set ToolEnvSet 0

  # Tool is target tool name. It must be lowercase.
  #
  # You can enforce value of the Tool variable
  # by setting the HBS_TOOL environment variable.
  #
  # See also 'hbs doc SetTool'.
  set Tool ""

  # Top is name of the top entity/module. Often also called toplevel.
  #
  # See also 'hbs doc SetTop'.
  set Top ""

  # Exit severity level for simulators.
  #
  # ExitSeverity is not supported by xsim.
  # This is because xsim does not allow changing the assert level
  # at which the simulation should exit with an error.
  #
  # See also 'hbs doc SetExitSeverity'.
  set ExitSeverity "error"

  # Custom (set by user) arguments prefix inserted right after command or program name.
  #
  # See also 'hbs doc SetArgsPrefix'.
  set ArgsPrefix ""

  # Custom (set by user) arguments suffix placed at the end of command or program call
  # or before the final argument.
  #
  # See also 'hbs doc SetArgsSuffix'.
  set ArgsSuffix ""

  # Path of the top core being run.
  set TopCorePath ""

  # Name of the top core being run.
  set TopCoreName ""

  # Path of the top target being run.
  set TopTargetPath ""

  # Name of the top target being run.
  set TopTargetName ""

  # List with command line arguments passed to the top target.
  set TopTargetArgs ""

  # List containing regexes for excluding discovered .hbs files from being sourced.
  #
  # See also 'hbs doc AddFileIgnoreRegex'.
  set FileIgnoreRegexes {}

  # Sets build directory.
  # The default build directory is named 'build'.
  #
  # Be careful when setting directory for testbench targets in .hbs files.
  # The hbs Python wrapper is not aware of build directory changes within .hbs files.
  # Changing build directory within testbench target causes the 'output.txt' file
  # to be placed in a separate directory than the actual testbench build directory.
  # This potentially happens when a testbench target is run as a result of
  # 'hbs test' command execution. This problem does not exist when BuildDir is
  # enforced using the HBS_BUILD_DIR environment variable.
  #
  # A call to hbs::SetBuildDir has no effect if build directory was enforced
  # using the HBS_BUILD_DIR environment variable.
  proc SetBuildDir {path} {
    if {$hbs::BuildDirEnvSet} {
      return
    }

    set hbs::BuildDir $path
  }

  # Sets name of the device/part.
  #
  # To get the name of currently set Device simply
  # read the value of hbs::Device variable.
  proc SetDevice {dev} {
    set hbs::Device $dev
  }

  # Sets name of the HDL library.
  #
  # To get the name of currently set library simply
  # read the value of hbs::Lib variable.
  #
  # Library for a given file must be set before adding a file.
  # For example:
  #   hbs::SetLib lib
  #   hbs::AddFile entity.vhd
  proc SetLib {lib} {
    if {[string index $lib 0] == "_"} {
      hbs::panic "invalid library name '$lib', library name can't start with '_' character"
    }
    if {[hbs::stringHasUTF $lib] == 1} {
      hbs::panic "invalid library name '$lib', library name can't have UTF characters"
    }

    set hbs::Lib $lib
  }

  # Sets standard revision for HDL files.
  #
  # To get the value of currently set standard revision simply
  # read the value of hbs::Std variable.
  #
  # Standard revision for a given file must be set before adding a file.
  # For example:
  #   hbs::SetStd 2008
  #   hbs::AddFile entity.vhd
  #
  # A call to hbs::SetStd has no effect if standard was enforced
  # using the HBS_STD environment variable.
  proc SetStd {std} {
    if {$hbs::StdEnvSet} {
      return
    }

    set err [hbs::isValidStd $std]
    if {$err ne ""} {
      hbs::panic $err
    }

    set hbs::Std $std
  }

  proc isValidVhdlStd {std} {
    switch $std {
      ""     -
      "1987" -
      "1993" -
      "2000" -
      "2002" -
      "2008" -
      "2019" { return "" }
    }
    return "invalid VHDL standard '$std', valid standards are: '1987', '1993', '2000', '2002' '2008', '2019'"
  }

  proc isValidVerilogStd {std} {
    switch $std {
      ""     -
      "1995" -
      "2001" -
      "2005" -
      "2009" -
      "2012" -
      "2017" -
      "2023" { return "" }
    }
    return "invalid Verilog/SystemVerilog standard '$std', valid standards are: '1995', '2001', '2005', '2009' '2012', '2017', '2023'"
  }

  proc isValidStd {std} {
    if {[hbs::isValidVhdlStd $std] eq "" || [hbs::isValidVerilogStd $std] eq ""} {
      return ""
    }
    return "invalid VHDL and Verilog/SystemVerilog standard '$std'"
  }

  # Sets name of the top entity/module.
  #
  # To get the name of currently set Top simply
  # read the value of hbs::Top variable.
  proc SetTop {top} {
    set hbs::Top $top
  }

  # Sets simulator exit severity level.
  #
  # If simulator does not support exit severity changing, for example xsim,
  # then a call to this function has no effect.
  proc SetExitSeverity {sev} {
    set err [hbs::isValidExitSeverity $sev]
    if {$err ne ""} {
      hbs::panic "$err"
    }

    set hbs::ExitSeverity $sev
  }

  proc invalidExitSeverityMsg {sev} {
    return "invalid exit severity '$sev', valid exit severities are: 'note', 'warning', 'error', 'failure'"
  }

  proc isValidExitSeverity {sev} {
    switch $sev {
      "note"    -
      "warning" -
      "error"   -
      "failure" { return "" }
    }
    return [hbs::invalidExitSeverityMsg $sev]
  }

  # Sets arguments prefix string.
  proc SetArgsPrefix {prefix} {
    set hbs::ArgsPrefix $prefix
  }

  # Clears arguments prefix string.
  proc ClearArgsPrefix {} {
    set hbs::ArgsPrefix ""
  }

  # Sets arguments suffix string.
  proc SetArgsSuffix {suffix} {
    set hbs::ArgsSuffix $suffix
  }

  # Clears arguments suffix string.
  proc ClearArgsSuffix {} {
    set hbs::ArgsSuffix ""
  }

  # Clears arguments affixes strings (prefix and suffix).
  #
  # Calling this procedure is equivalent to calling both
  # hbs::ClearArgsPrefix and hbs::ClearArgsSuffix.
  proc ClearArgsAffixes {} {
    set hbs::ArgsPrefix ""
    set hbs::ArgsSuffix ""
  }

  # Sets the Tool.
  #
  # To get the name of currently set Tool simply
  # read the value of hbs::Tool variable.
  #
  # If the tool is run in non-dry mode, then this procedure bootstraps
  # the script if it is run with the OS tclsh, but the provided tool requires
  # a specific EDA tool. For example, if you set the tool to 'gowin', the script
  # will be bootstrapped with the gw_sh.
  #
  # If the set tool requires project creation via a custom Tcl command,
  # for example, 'vivado-prj' or 'gowin' do, the Tcl command responsible for
  # the project creation is called within this procedure.
  #
  # All the tool names are typed in lowercase.
  # Remember about this rule if you add support for a new tool.
  #
  # A call to hbs::SetTool does not modify the hbs::Tool variable
  # if tool was enforced using the HBS_TOOL environment variable.
  #
  # Currently supported tools include:
  #   - ghdl,
  #   - gowin,
  #   - modelsim - set tool to questa,
  #   - nvc,
  #   - questa,
  #   - vivado-prj - Vivado project mode,
  #   - xsim - Vivado simulator.
  proc SetTool {tool} {
    set err [hbs::isValidTool $tool]
    if {$err ne ""} {
      hbs::panic "$err"
    }

    if {!$hbs::ToolEnvSet} {
      if {$hbs::Tool ne ""} {
        hbs::panic "can't set tool to '$tool', tool already set to '$hbs::Tool'"
      }
      set hbs::Tool $tool
    }

    switch $hbs::Tool {
      "ghdl"       { hbs::ghdl::setTool }
      "gowin"      { hbs::gowin::setTool }
      "nvc"        { ; }
      "questa"     { ; }
      "vivado-prj" { hbs::vivado-prj::setTool }
      "xsim"       { ; }
      default      { hbs::panic "[unknownToolMsg $tool]" }
    }
  }

  proc invalidToolMsg {tool} {
    return "invalid tool '$tool', supported tools: 'ghdl', 'gowin', 'nvc', 'questa', 'vivado-prj' \(project mode\), 'xsim'"
  }

  proc isValidTool {tool} {
    switch $tool {
      "ghdl"       -
      "gowin"      -
      "nvc"        -
      "questa"     -
      "vivado-prj" -
      "xsim"       { return "" }
      default      { return [hbs::invalidToolMsg $tool] }
    }
  }

  # ToolType reutrns type of the currently set tool.
  # Possible values are:
  #   - formal,
  #   - simulation,
  #   - synthesis.
  proc ToolType {} {
    switch $hbs::Tool {
      "ghdl" -
      "nvc" -
      "questa" -
      "xsim" {
        return "simulation"
      }
      "gowin" -
      "vivado-prj" {
        return "synthesis"
      }
      default {
        hbs::panic "hbs::Tool not set"
      }
    }
  }

  # Registers a given Tcl namespace as a core.
  #
  # Only Tcl namespaces with the hbs::Register call are treated as cores.
  # If the user forgets to register a core, then it is impossible to run
  # targets of this core with the 'hbs run' command.
  #
  # This procedure must be called as the last in the given core namespace.
  proc Register {} {
    set file [file normalize [info script]]
    set core [uplevel 1 [list namespace current]]

    if {[dict exists $hbs::cores $core]} {
      hbs::panic "can't register core '[string replace $core 0 6 ""]' in $file, core with the same path already registered in [dict get $hbs::cores $core file]"
    }

    set targets [uplevel 1 [list info procs]]
    if {$hbs::debug} {
      puts stderr "hbs::Register: registering core [string replace $core 0 6 ""] with following [llength $targets] targets:"
      foreach target $targets {
        puts stderr "  $target"
      }
    }

    set targetsDict [dict create]
    foreach target $targets {
      # Ignore targets starting with the floor '_' character
      if {[string match "_*" $target]} {
        continue
      }

      dict append targetsDict $target [dict create files {} dependencies {}]
    }

    dict append hbs::cores $core [dict create file $file targets $targetsDict]
  }

  # Adds target dependency.
  #
  # The first argument is the dependency target path.
  # All remaining arguments are passed to
  # the target path procedure as arguments.
  #
  # Bear in mind, that a given dependency target procedure with a given
  # argument values is run only once.
  proc AddDep {args} {
    set core [uplevel 1 [list namespace current]]
    set target [hbs::getNameFromPath [lindex [info level -1] 0]]

    set targetPath [lindex $args 0]
    set args [lreplace $args 0 0]

    checkTargetExists $targetPath

    # Add dependency to the core info dictionary.
    set deps [dict get $hbs::cores "::hbs::$hbs::ThisCorePath" targets $hbs::ThisTargetName dependencies]
    lappend deps $targetPath
    dict set hbs::cores "::hbs::$hbs::ThisCorePath" targets $hbs::ThisTargetName dependencies $deps

    # If the given target with given arguments has already been run, don't run it again.
    if {[dict exists $hbs::runTargets $targetPath] == 1} {
      foreach prevArgs [dict get $hbs::runTargets $targetPath] {
        if {$prevArgs == $args} {
          return
        }
      }
    } else {
      dict append hbs::runTargets $targetPath {}
    }

    # Add current arguments to the list of arguemnts the target has already been run with.
    set argsList [dict get $hbs::runTargets $targetPath]
    lappend argsList $args
    dict set hbs::runTargets $targetPath $argsList

    set ctx [hbs::saveContext]

    # Run dependency target.
    hbs::clearContext
    set hbs::ThisCorePath [hbs::getCorePathFromTargetPath $targetPath]
    set hbs::ThisCoreName [hbs::getNameFromPath $hbs::ThisCorePath]
    set hbs::ThisTargetName [hbs::getNameFromPath $targetPath]
    set hbs::ThisTargetPath $targetPath

    hbs::$targetPath {*}$args

    hbs::restoreContext $ctx
  }

  # Adds files to the tool flow.
  #
  # Multiple files with different extensions can be added in a single call.
  # args is the list of patterns used for globbing files.
  # The file paths are relative to the `.hbs` file path where the procedure is called.
  proc AddFile {args} {
    if {$args == {}} {
      hbs::panic "no file provided"
    }

    set hbsFileDir [file dirname [dict get [dict get $hbs::cores ::hbs::$hbs::ThisCorePath] file]]

    set files {}

    foreach pattern $args {
      set filePaths {}

      # Append hbsFileDir only in the case of relative paths.
      if {[string match "/*" $pattern]} {
        set filePaths [glob -nocomplain $pattern]
      } else {
        set filePaths [glob -nocomplain -path "$hbsFileDir/" $pattern]
      }

      if {[llength $filePaths] == 0} {
        hbs::panic "pattern '$pattern' doesn't resolve to any file"
      }

      foreach file $filePaths {
        lappend files $file
      }
    }

    set targetFiles [dict get $hbs::cores "::hbs::$hbs::ThisCorePath" targets $hbs::ThisTargetName files]
    foreach file $files {
      lappend targetFiles $file
    }
    dict set hbs::cores "::hbs::$hbs::ThisCorePath" targets $hbs::ThisTargetName files $targetFiles

    switch $hbs::Tool {
      "ghdl"       { hbs::ghdl::addFile $files }
      "gowin"      { hbs::gowin::addFile $files }
      "nvc"        { hbs::nvc::addFile $files }
      "questa"     { hbs::questa::addFile $files }
      "vivado-prj" { hbs::vivado-prj::addFile $files }
      "xsim"       { hbs::xsim::addFile $files }
      "" {
        hbs::panic "can't add file $file, hbs::Tool not set"
      }
      default {
        hbs::panic "uknown tool $hbs::Tool"
      }
    }
  }

  # Runs flow for currently set tool.
  #
  # The stage parameter controls when the tool stops.
  # Valid values of the stage include:
  #   analysis - stop after file analysis,
  #   bitstream - stop after bitstream generation,
  #   elaboration - stop after design elaboration,
  #   implementation - stop after implementation,
  #   project - stop after project creation,
  #   simulation - stop after simulation,
  #   synthesis - stop after synthesis.
  # The order is alphabetical. Not all tools support all stages.
  # To check stages of a given tool, view the documentation for that tool,
  # hbs doc {tool} or hbs doc hbs::{tool}".
  # hbs::{tool} documentation must provide run stages in the logical order.
  #
  # The default stage of a given tool is always the last stage of that tool.
  proc Run {{stage ""}} {
    switch $stage {
      "" -
      "analysis" -
      "bitstream" -
      "elaboration" -
      "implementation" -
      "project" -
      "simulation" -
      "synthesis" {
        ;
      }
      default {
        hbs::panic "invalid stage '$stage'"
      }
    }

    if {$hbs::cmd eq "dump-cores"} { return }

    if {$hbs::targetDir == ""} {
      set prjName [regsub -all :: "$hbs::ThisCorePath\:\:$hbs::ThisTargetName" --]
      set hbs::targetDir [file join $hbs::BuildDir $prjName]
    }
    if {[file exist $hbs::targetDir] eq 0} {
      file mkdir $hbs::targetDir
    }

    # Dump cores to JSON file.
    #
    # Replace "::" with "--".
    # Glib does not support ':' in file names.
    set fileName [string map {"::" "--"} $hbs::TopTargetPath].json
    set filePath [file join $hbs::targetDir $fileName]
    switch $hbs::Tool {
      # gw_sh changes working directory to project directory.
      "gowin" {
        set filePath $fileName
      }
    }
    hbs::dumpCores [open $filePath w]

    switch $hbs::Tool {
      "ghdl"       { hbs::ghdl::run $stage }
      "gowin"      { hbs::gowin::run $stage }
      "nvc"        { hbs::nvc::run $stage }
      "questa"     { hbs::questa::run $stage }
      "vivado-prj" { hbs::vivado-prj::run $stage }
      "xsim"       { hbs::xsim::run $stage }
      default      { hbs::panic [hbs::invalidToolMsg $hbs::Tool]}
    }
  }

  # SetGeneric sets generic (Verilog parameter) value. The actual action might
  # be postponed, as for example, for GHDL the generic values are provided
  # as command line arguments when running the simulation.
  #
  # The proc is named "SetGeneric", not "SetParam" or "SetParameters", because
  # the term parameter often refers to the EDA tool internal parameters.
  # The term "generic" is less ambiguous than the term "parameter".
  # For example, Vivado for setting Verilog parameters also uses the term
  # generic, https://support.xilinx.com/s/article/52217?language=en_US.
  proc SetGeneric {name value} {
    switch $hbs::Tool {
      "" {
        hbs::panic "can't set generic '$name', hbs::Tool not set"
      }
      "ghdl" {
        dict append hbs::ghdl::generics $name $value
      }
      "nvc" {
        dict append hbs::nvc::generics $name $value
      }
      "questa" {
        dict append hbs::questa::generics $name $value
      }
      "vivado-prj" {
        set_property generic $name=$value [current_fileset]
      }
      "xsim" {
        dict append hbs::xsim::generics $name $value
      }
      default {
        hbs::panic [hbs::invalidToolMsg $hbs::Tool]
      }
    }
  }

  # Adds pre analysis stage callback.
  proc AddPreAnalCb {args} {
    lappend hbs::preAnalCbs $args
  }

  # Removes all callbacks from the pre analysis callback list.
  proc ClearPreAnalCbList {} {
    set hbs::preAnalCbs []
  }

  # Adds post analysis stage callback.
  proc AddPostAnalCb {args} {
    lappend hbs::postAnalCbs $args
  }

  # Removes all callbacks from the post analysis callback list.
  proc ClearPostAnalCbList {} {
    set hbs::postAnalCbs []
  }

  # Adds pre bitstream generation stage callback.
  proc AddPreBitCb {args} {
    lappend hbs::preBitCbs $args
  }

  # Removes all callbacks from the pre bitstream callback list.
  proc ClearPreBitCbList {} {
    set hbs::preBitCbs []
  }

  # Adds post bitstream generation stage callback.
  proc AddPostBitCb {args} {
    lappend hbs::postBitCbs $args
  }

  # Removes all callbacks from the post bitstream callback list.
  proc ClearPostBitCbList {} {
    set hbs::postBitCbs []
  }

  # Adds pre elaboration stage callback.
  proc AddPreElabCb {args} {
    lappend hbs::preElabCbs $args
  }

  # Removes all callbacks from the pre elaboration callback list.
  proc ClearPreElabCbList {} {
    set hbs::preElabCbs []
  }

  # Adds post elaboration stage callback.
  proc AddPostElabCb {args} {
    lappend hbs::postElabCbs $args
  }

  # Removes all callbacks from the post elaboration callback list.
  proc ClearPostElabCbList {} {
    set hbs::postElabCbs []
  }

  # Adds pre implementation stage callback.
  proc AddPreImplCb {args} {
    lappend hbs::preImplCbs $args
  }

  # Removes all callbacks from the pre implementation callback list.
  proc ClearPreImplCbList {} {
    set hbs::preImplCbs []
  }

  # Adds post implementation stage callback.
  proc AddPostImplCb {args} {
    lappend hbs::postImplCbs $args
  }

  # Removes all callbacks from the post implementation callback list.
  proc ClearPostImplCbList {} {
    set hbs::postImplCbs []
  }

  # Adds pre project creation stage callback.
  proc AddPrePrjCb {args} {
    lappend hbs::prePrjCbs $args
  }

  # Removes all callbacks from the pre project callback list.
  proc ClearPrePrjCbList {} {
    set hbs::prePrjCbs []
  }

  # Adds post project creation stage callback.
  proc AddPostPrjCb {args} {
    lappend hbs::postPrjCbs $args
  }

  # Removes all callbacks from the post project callback list.
  proc ClearPostPrjCbList {} {
    set hbs::postPrjCbs []
  }

  # Adds pre simulation stage callback.
  proc AddPreSimCb {args} {
    lappend hbs::preSimCbs $args
  }

  # Removes all callbacks from the pre simulation callback list.
  proc ClearPreSimCbList {} {
    set hbs::preSimCbs []
  }

  # Adds post simulation stage callback.
  proc AddPostSimCb {args} {
    lappend hbs::postSimCbs $args
  }

  # Removes all callbacks from the post simulation callback list.
  proc ClearPostSimCbList {} {
    set hbs::postSimCbs []
  }

  # Adds pre synthesis stage callback.
  proc AddPreSynthCb {args} {
    lappend hbs::preSynthCbs $args
  }

  # Removes all callbacks from the pre synthesis callback list.
  proc ClearPreSynthCbList {} {
    set hbs::preSynthCbs []
  }

  # Adds post synthesis stage callback.
  proc AddPostSynthCb {args} {
    lappend hbs::postSynthCbs $args
  }

  # Removes all callbacks from the post synthesis callback list.
  proc ClearPostSynthCbList {} {
    set hbs::postSynthCbs []
  }

  # Prints command to the standard output and evaluates it using
  # the standard `eval` command if hbs::DryRun is false.
  #
  # To force command evaluation in the dry run, set forceInDryRun to true.
  proc Eval {cmd {forceInDryRun 0}} {
    puts $cmd
    if {!$hbs::DryRun || $forceInDryRun} {
      return [eval $cmd]
    }
  }

  # Prints command to the standard output and executes it using
  # the standard `exec` command if hbs::DryRun is false.
  #
  # To force command execution in the dry run, set forceInDryRun to true.
  #
  # The proc returns catched exit status.
  proc Exec {cmd {forceInDryRun 0}} {
    puts $cmd
    if {$hbs::DryRun && !$forceInDryRun} {
      return 0
    }

    set err [catch { eval exec -ignorestderr $cmd }]
    return $err
  }

  # Prints command to the standard output and executes it using the standard 'exec'
  # if hbs::DryRun is false in the working directory changed to the core directory
  # (the directory in which .hbs file with given core is defined).
  # After the 'exec' the working directory is restored.
  #
  # To force command execution in the dry run, set forceInDryRun to true.
  #
  # The proc returns catched exit status.
  proc ExecInCoreDir {cmd {forceInDryRun 0}} {
    puts $cmd
    if {$hbs::DryRun && !$forceInDryRun} {
      return 0
    }

    set workDir [pwd]

    set hbsFileDir [file dirname [dict get $hbs::cores ::hbs::$hbs::ThisCorePath file]]
    cd $hbsFileDir

    set err [catch { eval exec -ignorestderr $cmd }]

    cd $workDir
    return $err
  }

  # Returns directory of file in which current core is defined.
  proc CoreDir {} {
    return [file dirname [dict get $hbs::cores ::hbs::$hbs::ThisCorePath file]]
  }

  # Adds regexes to the FileIgnoreRegexes list.
  # Multiple regexes can be separated with space.
  proc AddFileIgnoreRegex {args} {
    foreach reg $args {
      hbs::dbg "adding ignore regex $reg"
      lappend hbs::FileIgnoreRegexes $reg
    }
  }

  # Returns true (1) if ext is recognized as Verilog/SystemVerilog file extension.
  proc isVerilogExtension {ext} {
    switch $ext {
      ".v"       -
      ".vh"      -
      ".vlg"     -
      ".verilog" -
      ".sv"      -
      ".svh"     { return 1 }
    }
    return 0
  }

  # Returns true (1) if ext is recognized as VHDL file extension.
  proc isVhdlExtension {ext} {
    switch $ext {
      ".vhd"  -
      ".vhdl" { return 1 }
    }
    return 0
  }
}

# Private API
#
# Only use this API directly in user hbs files if you _really_ know what you are doing.
namespace eval hbs {
  set debug 0

  # The command provided to the hbs from the command line.
  set cmd ""

  # Formats and prints debug message if hbs::debug is not 0.
  proc dbg {msg} {
    if {$hbs::debug == 0} { return }
    puts stderr "[lindex [info level -1] 0]: $msg"
  }

  proc panic {msg} {
    set prefix ""
    if {$hbs::ThisTargetPath ne ""} {
      set prefix "$hbs::ThisTargetPath: "
    }
    puts stderr "$prefix[lindex [info level -1] 0]: $msg"
    exit 1
  }

  # Target output directory.
  set targetDir ""

  # Stage callbacks
  set preAnalCbs   []
  set postAnalCbs  []
  set preBitCbs    []
  set postBitCbs   []
  set preElabCbs   []
  set postElabCbs  []
  set preImplCbs   []
  set postImplCbs  []
  set prePrjCbs    []
  set postPrjCbs   []
  set preSimCbs    []
  set postSimCbs   []
  set preSynthCbs  []
  set postSynthCbs []

  proc evalPreAnalCbs   {} { foreach cb $hbs::preAnalCbs   { eval $cb } }
  proc evalPostAnalCbs  {} { foreach cb $hbs::postAnalCbs  { eval $cb } }
  proc evalPreBitCbs    {} { foreach cb $hbs::preBitCbs    { eval $cb } }
  proc evalPostBitCbs   {} { foreach cb $hbs::postBitCbs   { eval $cb } }
  proc evalPreElabCbs   {} { foreach cb $hbs::preElabCbs   { eval $cb } }
  proc evalPostElabCbs  {} { foreach cb $hbs::postElabCbs  { eval $cb } }
  proc evalPreImplCbs   {} { foreach cb $hbs::preImplCbs   { eval $cb } }
  proc evalPostImplCbs  {} { foreach cb $hbs::postImplCbs  { eval $cb } }
  proc evalPrePrjCbs    {} { foreach cb $hbs::prePrjCbs    { eval $cb } }
  proc evalPostPrjCbs   {} { foreach cb $hbs::postPrjCbs   { eval $cb } }
  proc evalPreSimCbs    {} { foreach cb $hbs::preSimCbs    { eval $cb } }
  proc evalPostSimCbs   {} { foreach cb $hbs::postSimCbs   { eval $cb } }
  proc evalPreSynthCbs  {} { foreach cb $hbs::preSynthCbs  { eval $cb } }
  proc evalPostSynthCbs {} { foreach cb $hbs::postSynthCbs { eval $cb } }

  set fileList {}
  set cores [dict create]

  # Dictionary containing targets that already have been run.
  # During the single flow, single target can be run only once with a given argument values.
  set runTargets [dict create]

  proc init {} {
    set hbs::fileList [findFiles . *.hbs]
    hbs::sortFileList

    if {$hbs::debug} {
      puts stderr "hbs::init: found [llength $hbs::fileList] hbs files:"
      foreach fileName $hbs::fileList {
        puts "  $fileName"
      }
    }

    # Handle HBS_BUILD_DIR environment variable.
    if {[info exists ::env(HBS_BUILD_DIR)]} {
      set hbs::BuildDirEnvSet 1
      set hbs::BuildDir $::env(HBS_BUILD_DIR)
    }

    # Handle HBS_STD environment variable.
    if {[info exists ::env(HBS_STD)]} {
      set std $::env(HBS_STD)
      set err [hbs::isValidStd $std]
      if {$err ne ""} {
        hbs::panic "can't set standard from HBS_STD environment variable: $err"
      }
      set hbs::StdEnvSet 1
      set hbs::Std $std
    }

    # Handle HBS_TOOL environment variable.
    if {[info exists ::env(HBS_TOOL)]} {
      set tool $::env(HBS_TOOL)
      set err [isValidTool $tool]
      if {$err ne ""} {
        hbs::panic "can't set tool from HBS_TOOL environment variable: $err"
      }
      set hbs::ToolEnvSet 1
      set hbs::Tool $tool
    }

    foreach fileName $hbs::fileList {
      set ignore 0
      foreach reg $hbs::FileIgnoreRegexes {
        if {[regexp $reg $fileName]} {
            set ignore 1
            break
        }
      }
      if {$ignore} {
        continue
      }
      source $fileName
    }
  }

  proc checkTargetExists {targetPath} {
    set core [hbs::getCorePathFromTargetPath $targetPath]
    set target [hbs::getNameFromPath $targetPath]

    if {[dict exists $hbs::cores ::hbs::$core] == 0} {
      hbs::panic "core '$core' not found, maybe the core is not:\n \
        1. registered 'hbs doc hbs::Register',\n \
        2. sourced 'hbs doc hbs::FileIgnoreRegexes'."
    }
    if {[dict exists $hbs::cores ::hbs::$core targets $target] == 0} {
      puts stderr "core '$core' found, but it doesn't have target '$target', '$core' has following targets:"
      hbs::listTargets $core stderr
      exit 1
    }
  }

  proc runTarget {targetPath args} {
    checkTargetExists $targetPath

    hbs::clearContext

    set hbs::ThisCorePath [hbs::getCorePathFromTargetPath $targetPath]
    set hbs::ThisCoreName [hbs::getNameFromPath $hbs::ThisCorePath]
    set hbs::ThisTargetName [hbs::getNameFromPath $targetPath]
    set hbs::ThisTargetPath $targetPath

    dict append hbs::runTargets $targetPath

    # Below check is required to make default values for target arguments
    # work as expected. Otherwise empty list is passed when there are no args,
    # and the default value of first argument is overwritten to be "".
    if {[llength $args] == 0} {
      hbs::$targetPath
    } else {
      hbs::$targetPath {*}$args
    }
  }

  proc clearContext {} {
    set hbs::Lib ""
    set hbs::Top ""
    set hbs::ThisCorePath ""
    set hbs::ThisCoreName ""
    set hbs::ThisTargetPath ""
    set hbs::ThisTargetName ""
    set hbs::ArgsPrefix ""
    set hbs::ArgsSuffix ""

    if {!$hbs::StdEnvSet} {
      set hbs::Std ""
    }
  }

  proc saveContext {} {
    set ctx [dict create \
      Lib $hbs::Lib \
      Std $hbs::Std \
      Top $hbs::Top \
      ThisCorePath $hbs::ThisCorePath \
      ThisCoreName $hbs::ThisCoreName \
      ThisTargetPath $hbs::ThisTargetPath \
      ThisTargetName $hbs::ThisTargetName \
      ArgsPrefix $hbs::ArgsPrefix \
      ArgsSuffix $hbs::ArgsSuffix]
    return $ctx
  }

  proc restoreContext {ctx} {
    set hbs::Lib [dict get $ctx Lib]
    set hbs::Std [dict get $ctx Std]
    set hbs::Top [dict get $ctx Top]
    set hbs::ThisCorePath [dict get $ctx ThisCorePath]
    set hbs::ThisCoreName [dict get $ctx ThisCoreName]
    set hbs::ThisTargetPath [dict get $ctx ThisTargetPath]
    set hbs::ThisTargetName [dict get $ctx ThisTargetName]
    set hbs::ArgsPrefix [dict get $ctx ArgsPrefix]
    set hbs::ArgsSuffix [dict get $ctx ArgsSuffix]
  }

  # Dumps single core info into JSON.
  proc dumpCoreInfo {info chnnl} {
    # file
    puts $chnnl "\t\t\"file\": \"[dict get $info file]\","

    # targets
    puts $chnnl "\t\t\"targets\": \{"
    set targets [dict get $info targets]
    set targetsSize [dict size $targets]
    set t 0
    foreach {target filesAndDeps} $targets {
      puts $chnnl "\t\t\t\"$target\": \{"

      # Dump dependencies
      set deps [dict get $filesAndDeps dependencies]
      set depsLen [llength $deps]

      if {$depsLen > 0} {
        puts $chnnl "\t\t\t\t\"dependencies\": \["
      } else {
        puts $chnnl "\t\t\t\t\"dependencies\": \[\],"
      }

      set d 0
      foreach dep $deps {
        puts -nonewline $chnnl "\t\t\t\t\t\"$dep\""
        incr d
        if {$d < $depsLen} {
          puts $chnnl ", "
        }
      }

      if {$depsLen > 0} {
        puts $chnnl "\n\t\t\t\t\],"
      }

      # Dump files
      set files [dict get $filesAndDeps files]
      set filesLen [llength $files]

      if {$filesLen > 0} {
        puts $chnnl "\t\t\t\t\"files\": \["
      } else {
        puts $chnnl "\t\t\t\t\"files\": \[\]"
      }

      set f 0
      foreach file $files {
        puts -nonewline $chnnl "\t\t\t\t\t\"$file\""
        incr f
        if {$f < $filesLen} {
          puts $chnnl ", "
        }
      }

      if {$filesLen > 0} {
        puts $chnnl "\n\t\t\t\t\]"
      }

      incr t
      if {$t < $targetsSize} {
        puts $chnnl "\t\t\t\},"
      } else {
        puts $chnnl "\t\t\t\}"
      }
    }
    puts $chnnl "\t\t\}"
  }

  proc dumpCores {{chnnl stdout}} {
    puts $chnnl "\{"

    set coresSize [dict size $hbs::cores]
    set c 0
    dict for {core info} $hbs::cores {
      puts $chnnl "\t\"[string replace $core 0 6 ""]\": \{"
      hbs::dumpCoreInfo $info $chnnl

      incr c
      if { $c < $coresSize } {
        puts $chnnl "\t\},"
      } else {
        puts $chnnl "\t\}"
      }
    }

    puts $chnnl "\}"
  }

  proc listCores {} {
    set cores [lsort [dict keys $hbs::cores]]
    foreach core $cores {
      # Drop the "::hbs::" prefix
      puts [string replace $core 0 6 ""]
    }
  }

  proc listTargets {corePath {chnnl stdout}} {
    if {[dict exists $hbs::cores ::hbs::$corePath] == 0} {
      hbs::panic "core '$corePath' not found, maybe the core is not registered \(hsb::Register\)"
    }

    set core [dict get $hbs::cores ::hbs::$corePath]
    set targets [dict get $core targets]

    foreach target [dict keys $targets] {
        puts $chnnl $target
    }
  }

  # Returns core path from the target path.
  proc getCorePathFromTargetPath {path} {
    set parts [split $path ::]
    # Remove target
    set parts [lreplace $parts end end]
    # Remove {}
    set parts [lreplace $parts end end]
    # TCL split command leaves {} in places of splits.
    # Hence, one ':' is enough here.
    return [join $parts :]
  }

  # Returns target name from the target path.
  proc getNameFromPath {path} {
    return [lindex [split $path ::] end]
  }

  # Finds files in the file system.
  # basedir - the directory to start looking in.
  # pattern - A pattern, as defined by the glob command, that the files must match.
  proc findFiles { basedir pattern } {
    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory seperator
    set basedir [string trimright [file join [file normalize $basedir] { }]]
    set fileList {}

    # Look in the current directory for matching files, -type {f r}
    # means ony readable normal files are looked at, -nocomplain stops
    # an error being thrown if the returned list is empty
    foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
      lappend fileList $fileName
    }

    # Now look for any sub direcories in the current directory
    foreach dirName [glob -nocomplain -type {d r} -path $basedir *] {
      # Recusively call the routine on the sub directory and append any
      # new files to the results
      set subDirList [findFiles $dirName $pattern]
      if { [llength $subDirList] > 0 } {
        foreach subDirFile $subDirList {
          lappend fileList $subDirFile
        }
      }
    }
    return $fileList
  }

  # Sorts .hbs file list in such a way, that files with shorter
  # path depth are sourced as the first ones.
  proc sortFileList {} {
    proc cmp {l r} {
      set li [llength [split $l /]]
      set ri [llength [split $r /]]
      if {$li < $ri} {
        return -1
      } elseif {$li > $ri} {
        return 1
      } elseif {[string compare $l $r] < 0} { # Sort alphabetically
        return -1
      }
      return 1
    }
    set hbs::fileList [lsort -command cmp $hbs::fileList]
  }

  proc stringHasUTF {str} {
    if {[regexp {[^\x00-\x7F]} $str]} {
      return 1
    }
    return 0
  }
}

# GHDL simulator
#
# HBS requires that GHDL is compiled with the LLVM or GCC backend.
# It does not support GHDL with mcode backend.
#
# GHDL supports the following stages:
#   - analysis,
#   - elaboration,
#   - simulation.
namespace eval hbs::ghdl {
  set vhdlFiles [dict create]

  # Library search paths (-PDIR arguemnt).
  set libs ""

  set generics [dict create]

  proc setTool {} {
    # Check for pre-analyzed libraries
    set defaultVendorsDir "/usr/local/lib/ghdl/vendors"
    if {[file exist $defaultVendorsDir]} {
      set hbs::ghdl::libs "$hbs::ghdl::libs -P$defaultVendorsDir -frelaxed-rules"
    }
  }

  proc addFile {files} {
    foreach file $files {
      set extension [file extension $file]
      switch $extension {
        ".vhd" -
        ".vhdl" {
          hbs::ghdl::addVhdlFile $file
        }
        default {
          hbs::panic "unhandled file extension '$extension'"
        }
      }
    }
  }

  proc library {} {
    if {$hbs::Lib eq ""} { return "work" }
    return $hbs::Lib
  }

  proc isSupportedStd {std} {
    switch $std {
      ""      -
      "1987"  -
      "1993"  -
      "2000"  -
      "2002"  -
      "2008"  { return "" }
      default { return "ghdl doesn't support VHDL standard '$std'" }
    }
  }

  proc std {} {
    switch $hbs::Std {
      # 2008 is the default one
      ""     { return "08" }
      "1987" { return "87" }
      "1993" { return "93" }
      "2000" { return "00" }
      "2002" { return "02" }
      "2008" { return "08" }
    }
  }

  proc genericArgs {} {
    set args ""
    dict for {name value} $hbs::ghdl::generics {
      set args "$args -g$name=$value"
    }
    return $args
  }

  proc addVhdlFile {file} {
    hbs::dbg "adding file $file"

    set err [hbs::isValidVhdlStd $hbs::Std]
    if {$err ne ""} {
      hbs::panic "$file: $err"
    }

    set err [hbs::ghdl::isSupportedStd $hbs::Std]
    if {$err ne ""} {
      hbs::panic "$file: $err"
    }

    set lib [hbs::ghdl::library]
    dict append hbs::ghdl::vhdlFiles $file \
        [dict create \
        std [hbs::ghdl::std] \
        lib $lib \
        argsPrefix $hbs::ArgsPrefix \
        argsSuffix $hbs::ArgsSuffix]
  }

  proc analyze {} {
    hbs::dbg "starting files analysis"

    set workDir [pwd]
    cd $hbs::targetDir

    dict for {file args} $hbs::ghdl::vhdlFiles {
      set lib [dict get $args lib]

      if {[string first "-P$lib" $hbs::ghdl::libs] == -1} {
          file mkdir $lib
          append hbs::ghdl::libs " -P$lib"
      }

      set cmd "ghdl -a [dict get $args argsPrefix] --std=[dict get $args std] $hbs::ghdl::libs --work=$lib --workdir=$lib [dict get $args argsSuffix] $file"
      set err [hbs::Exec $cmd]
      if {$err} {
        hbs::panic "$file analysis failed with exit status $err"
      }
    }

    cd $workDir
  }

  proc elaborate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "ghdl -e $hbs::ArgsPrefix --std=[hbs::ghdl::std] --workdir=work $hbs::ghdl::libs $hbs::ArgsSuffix $hbs::Top"
    set err [hbs::Exec $cmd]
    if {$err} {
      hbs::panic "$hbs::Top elaboration failed with exit status $err"
    }

    cd $workDir
  }

  proc simulate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "./$hbs::Top $hbs::ArgsPrefix --wave=$hbs::Top.ghw [hbs::ghdl::genericArgs] --assert-level=$hbs::ExitSeverity $hbs::ArgsSuffix"
    set err [hbs::Exec $cmd]
    if {$err} {
      hbs::panic "simulation failed with exit status $err"
    }

    cd $workDir
  }

  proc checkStage {stage} {
    switch $stage {
      "" -
      "analysis" -
      "elaboration" -
      "simulation" {
        ;
      }
      default {
        hbs::panic "invalid stage '$stage', valid ghdl stages are: 'analysis', 'elaboration', 'simulation'"
      }
    }
  }

  proc run {stage} {
    hbs::ghdl::checkStage $stage

    # Analysis
    hbs::evalPreAnalCbs
    hbs::ghdl::analyze
    hbs::evalPostAnalCbs
    if {$stage == "analysis"} { return }

    # Elaboration
    hbs::evalPreElabCbs
    hbs::ghdl::elaborate
    hbs::evalPostElabCbs
    if {$stage == "elaboration"} { return }

    # Simulation
    hbs::evalPreSimCbs
    hbs::ghdl::simulate
    hbs::evalPostSimCbs
  }
}

# GOWIN
#
# gowin supports the following stages:
#   - project,
#   - synthesis,
#   - implementation (place and route).
# In GOWIN IDE, bitstream file generatino is a part of the place and route stage.
# The bitstream file has .fs, .bin or .binx extension.
#
# Setting tool to gowin must be wrapped by setting arguments suffix to proper device version.
# This is because each device in GOWIN also has associated device version.
# Example:
#   hbs::SetArgsSuffix "-device_version NA"
#   hbs::SetTool "gowin"
#   hbs::ClearArgsSuffix
namespace eval hbs::gowin {
  # Highest set VHDL standard revision.
  set vhdlStandard ""

  # Highest set (System)Verilog standard revision.
  set verilogStandard ""

  proc setTool {} {
    # gw_sh automatically creates project directory.
    set prjName [regsub -all :: "$hbs::ThisCorePath\:\:$hbs::ThisTargetName" --]
    set create_prj_cmd "create_project $hbs::ArgsPrefix \
      -name $prjName \
      -dir $hbs::BuildDir \
      -pn $hbs::Device \
      -force $hbs::ArgsSuffix"
    if {$hbs::DryRun} {
      hbs::Eval $create_prj_cmd
      return
    }

    # Check if the script is already run by GOWIN
    if {[info exists ::env(HBS_TOOL_BOOTSTRAP)] == 1} {
      # gw_sh already runs the script

      hbs::dbg "creating gowin project"
      hbs::Eval $create_prj_cmd

      # Set target directory for later use.
      set hbs::targetDir [file join $hbs::BuildDir $prjName]

      hbs::dbg "gowin project created successfully"
    } else {
      # Run the script with gw_sh
      set ::env(HBS_TOOL_BOOTSTRAP) 1

      set cmd "gw_sh \
        [file normalize [info script]] \
        $hbs::cmd $hbs::TopTargetPath $hbs::TopTargetArgs"
      set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
      if {$exitStatus == 0} {
        exit 0
      } else {
        hbs::panic "gw_sh exited with status $exitStatus"
      }
    }
  }

  proc addFile {files} {
    foreach file $files {
      hbs::dbg "adding file $file"

      set extension [file extension $file]
      switch $extension {
        ".vhd" -
        ".vhdl" {
          hbs::gowin::addVhdlFile $file
        }
        ".v" -
        ".vh" -
        ".vlg" -
        ".verilog" -
        ".sv" -
        ".svh" {
          hbs::gowin::addVerilogFile $file
        }
        default {
          set cmd "add_file $hbs::ArgsPrefix $file"
          puts $cmd
          eval $cmd
        }
      }
    }
  }

  proc vhdlStd {} {
    switch $hbs::gowin::vhdlStandard {
      # 2008 is the default one
      ""     { return "vhd2008" }
      "1987" -
      "1993" { return "vhd1993" }
      "2000" -
      "2002" -
      "2008" { return "vhd2008" }
      "2019" { return "vhd2019" }
    }
  }

  proc addVhdlFile {file} {
    set err [hbs::isValidVhdlStd $hbs::Std]
    if {$err ne ""} {
      hbs::panic "$file: $err"
    }

    set cmd "add_file $hbs::ArgsPrefix $file $hbs::ArgsSuffix"
    puts $cmd
    eval $cmd

    set lib $hbs::Lib
    if {$lib == ""} {
      set lib "work"
    }

    set cmd "set_file_prop -lib $lib $file"
    puts $cmd
    eval $cmd

    if {$hbs::Std > $hbs::gowin::vhdlStandard} {
      set hbs::gowin::vhdlStandard $hbs::Std
    }
  }

  proc verilogStd {} {
    switch $hbs::gowin::verilogStandard {
      # 2012 is the default one, but it is not supported so use 2017
      ""      { return "sysv2017" }
      "1995"  { return "v1995" }
      "2001"  { return "v2001" }
      "2005"  -
      "2009"  -
      "2012"  -
      "2017"  { return "sysv2017" }
      default { hbs::panic "gowin doesn't support Verilog/SystemVerilog standard '$hbs::gowin::verilogStandard'" }
    }
  }

  proc addVerilogFile {file} {
    set err [hbs::isValidVerilogStd $hbs::Std]
    if {$err ne ""} {
      hbs::panic "$file: $err"
    }

    set cmd "add_file $hbs::ArgsPrefix $file $hbs::ArgsSuffix"
    puts $cmd
    eval $cmd

    set lib $hbs::Lib
    if {$lib == ""} {
      set lib "work"
    }

    set cmd "set_file_prop -lib $lib $file"
    puts $cmd
    eval $cmd

    if {$hbs::Std > $hbs::gowin::verilogStd} {
      set hbs::gowin::verilogStd $hbs::Std
    }
  }

  proc checkStage {stage} {
    switch $stage {
      "" -
      "project" -
      "synthesis" -
      "implementation" {
        ;
      }
      default {
        hbs::panic "invalid stage '$stage', valid gowin stages are: 'project', 'synthesis', 'implementation'"
      }
    }
  }

  proc run {stage} {
    hbs::gowin::checkStage $stage

    #
    # Project
    #
    hbs::evalPrePrjCbs
    if {$hbs::Top == ""} {
      hbs::panic "cannot set top, hbs::Top not set"
    }
    set cmd "set_option -top_module $hbs::Top"
    puts $cmd
    eval $cmd
    set cmd "set_option -vhdl_std [hbs::gowin::vhdlStd]"
    puts $cmd
    eval $cmd
    set cmd "set_option -verilog_std [hbs::gowin::verilogStd]"
    puts $cmd
    eval $cmd
    hbs::evalPostPrjCbs
    if {$stage == "project"} { return }

    #
    # Synthesis
    #
    hbs::evalPreSynthCbs
    set cmd "::run $hbs::ArgsPrefix syn $hbs::ArgsSuffix"
    puts $cmd
    set err [catch {eval $cmd} errMsg]
    if {$err != 0} {
      hbs::panic $errMsg
    }
    hbs::evalPostSynthCbs
    if {$stage == "synthesis"} { return }

    #
    # Implementation
    #
    hbs::evalPreImplCbs
    set cmd "::run $hbs::ArgsPrefix pnr $hbs::ArgsSuffix"
    puts $cmd
    set err [catch {eval $cmd} errMsg]
    if {$err != 0} {
      hbs::panic $errMsg
    }
    hbs::evalPostImplCbs
  }
}

# nvc simulator
#
# nvc supports the following stages:
#   - analysis,
#   - elaboration,
#   - simulation.
namespace eval hbs::nvc {
  set vhdlFiles [dict create]

  # Library search paths.
  set libs "-L."

  set generics [dict create]

  # The highest set standard revision.
  # nvc does not allow analyzing different files with different standard revisions.
  # This is why the highest set standard revision must be tracked.
  set std ""

  proc addFile {files} {
    foreach file $files {
      set ext [file extension $file]
      if {[hbs::isVhdlExtension $ext]} {
        hbs::nvc::addVhdlFile $file
      } else {
        hbs::panic "unhandled file extension '$ext'"
      }
    }
  }

  proc library {} {
    if {$hbs::Lib eq ""} {
      return "work"
    }
    return $hbs::Lib
  }

  proc genericArgs {} {
    set args ""
    dict for {name value} $hbs::nvc::generics {
      set args "$args -g $name=$value"
    }
    return $args
  }

  proc addVhdlFile {file} {
    hbs::dbg "adding file $file"

    set err [hbs::isValidVhdlStd $hbs::Std]
    if {$err ne ""} {
      hbs::panic "$file: $err"
    }

    set lib [hbs::nvc::library]
    dict append hbs::nvc::vhdlFiles $file \
        [dict create \
        lib $lib \
        std $hbs::Std \
        argsPrefix $hbs::ArgsPrefix \
        argsSuffix $hbs::ArgsSuffix]
  }

  proc analyze {} {
    hbs::dbg "starting files analysis"

    set workDir [pwd]
    cd $hbs::targetDir

    dict for {file args} $hbs::nvc::vhdlFiles {
      set lib [dict get $args lib]
      set cmd "nvc [dict get $args argsPrefix] --std=$hbs::nvc::std $hbs::nvc::libs --work=$lib -a $file [dict get $args argsSuffix]"
      set err [hbs::Exec $cmd]
      if {$err} {
        hbs::panic "$file analysis failed with exit status $err"
      }
    }

    cd $workDir
  }

  proc elaborate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "nvc $hbs::ArgsPrefix --std=$hbs::nvc::std $hbs::nvc::libs -e $hbs::Top [hbs::nvc::genericArgs] $hbs::ArgsSuffix"
    set err [hbs::Exec $cmd]
    if {$err} {
      hbs::panic "$hbs::Top elaboration failed with exit status $err"
    }

    cd $workDir
  }

  proc simulate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "nvc $hbs::ArgsPrefix --std=$hbs::nvc::std $hbs::nvc::libs -r $hbs::Top --wave --exit-severity=$hbs::ExitSeverity $hbs::ArgsSuffix"
    set err [hbs::Exec $cmd]
    if {$err} {
      hbs::panic "simulation failed with exit status $err"
    }

    cd $workDir
  }

  proc checkStage {stage} {
    switch $stage {
      "" -
      "analysis" -
      "elaboration" -
      "simulation" {
        ;
      }
      default {
        hbs::panic "invalid stage '$stage', valid nvc stages are: 'analysis', 'elaboration', 'simulation'"
      }
    }
  }

  proc run {stage} {
    hbs::nvc::checkStage $stage

    # Determine standard revision that should be used for all files.
    dict for {file args} $hbs::nvc::vhdlFiles {
      set std [dict get $args std]
      if {$std != "" && $std > $hbs::nvc::std} {
          set hbs::nvc::std $hbs::Std
      }
    }

    # If none of the targets enforced a standard revision, use 2008 as the default.
    if {$hbs::nvc::std == ""} {
      set hbs::nvc::std "2008"
    }

    # Analysis
    hbs::evalPreAnalCbs
    hbs::nvc::analyze
    hbs::evalPostAnalCbs
    if {$stage == "analysis"} { return }

    # Elaboration
    hbs::evalPreElabCbs
    hbs::nvc::elaborate
    hbs::evalPostElabCbs
    if {$stage == "elaboration"} { return }

    # Simulation
    hbs::evalPreSimCbs
    hbs::nvc::simulate
    hbs::evalPostSimCbs
  }
}

# Vivado (Project Mode)
#
# vivado-prj supports the following stages:
#   - project,
#   - synthesis,
#   - implementation.
#   - bitstream.
namespace eval hbs::vivado-prj {
  proc setTool {} {
    set prjName [regsub -all :: "$hbs::ThisCorePath\:\:$hbs::ThisTargetName" --]
    set hbs::targetDir [file join $hbs::BuildDir $prjName]
    set create_prj_cmd "create_project $hbs::ArgsPrefix -force $prjName $hbs::targetDir $hbs::ArgsSuffix"
    if {$hbs::DryRun} {
      hbs::Eval $create_prj_cmd
      return
    }

    # Check if the script is already run by Vivado
    if {[info exists ::env(HBS_TOOL_BOOTSTRAP)] == 1} {
      # Vivado already runs the script
      set hbs::Tool "vivado-prj"

      hbs::dbg "creating vivado project"
      hbs::Eval $create_prj_cmd
      hbs::dbg "vivado project created successfully"
    } else {
      # Run the script with Vivado
      set prjName [regsub -all :: "$hbs::ThisCorePath\:\:$hbs::ThisTargetName" --]
      set prjDir [file join $hbs::BuildDir $prjName]
      file mkdir $prjDir

      set ::env(HBS_TOOL_BOOTSTRAP) 1

      set cmd "vivado \
          -mode batch \
          -source [file normalize [info script]] \
          -journal $prjDir/vivado.jou \
          -log $prjDir/vivado.log \
          -tclargs $hbs::cmd $hbs::TopTargetPath $hbs::TopTargetArgs"
      set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
      if {$exitStatus == 0} {
        exit 0
      } else {
        hbs::panic "vivado exited with status $exitStatus"
      }
    }
  }

  proc addFile {files} {
    foreach file $files {
      hbs::dbg "adding file $file"

      set extension [file extension $file]
      switch $extension {
        ".bd"   { hbs::vivado-prj:addBlockDesignFile $file }
        ".mem"  { hbs::vivado-prj::addMemFile $file }
        ".v"       -
        ".vh"      -
        ".vlg"     -
        ".verilog" { hbs::vivado-prj::addVerilogFile $file }
        ".sv"   -
        ".svh"  { hbs::vivado-prj::addSystemVerilogFile $file }
        ".vhd"  -
        ".vhdl" { hbs::vivado-prj::addVhdlFile $file }
        ".tcl"  { hbs::vivado-prj::addTclFile $file }
        ".xci"  { hbs::vivado-prj::addXciFile $file }
        ".xdc"  { hbs::vivado-prj::addXdcFile $file }
        default { hbs::panic "unhandled file extension '$extension'" }
      }
    }
  }

  proc library {} {
    if {$hbs::Lib eq ""} { return "xil_defaultlib" }
    return $hbs::Lib
  }

  proc vhdlStandard {} {
    switch $hbs::Std {
      # 2008 is the default one
      ""     { return "-vhdl2008" }
      "1987" -
      "1993" { return "" }
      "2000" -
      "2002" -
      "2008" { return "-vhdl2008" }
      "2019" { return "-vhdl2019" }
      default {
        hbs::panic "invalid hbs::Std $hbs::Std for VHDL file"
      }
    }
  }

  proc addBlockDesignFile {file} {
    hbs::Eval "read_bd $file"
  }

  proc addMemFile {file} {
    hbs::Eval "read_mem $file"
  }

  proc addTclFile {file} {
    hbs::Eval "source $file"
  }

  proc addXciFile {file} {
    hbs::Eval "read_ip $file"
  }

  proc addXdcFile {file} {
    hbs::Eval "read_xdc $file"
  }

  proc addVerilogFile {file} {
    hbs::Eval "read_verilog -library [hbs::vivado-prj::library] $file"
  }

  proc addSystemVerilogFile {file} {
    hbs::Eval "read_verilog -library [hbs::vivado-prj::library] -sv $file"
  }

  proc addVhdlFile {file} {
    hbs::Eval "read_vhdl -library [hbs::vivado-prj::library] [hbs::vivado-prj::vhdlStandard] $file"
  }

  proc checkStage {stage} {
    switch $stage {
      "" -
      "project" -
      "synthesis" -
      "implementation" -
      "bitstream" {
        ;
      }
      default {
        hbs::panic "invalid stage '$stage', valid vivado-prj stages are: 'project', 'synthesis', 'implementation', 'bitstream'"
      }
    }
  }

  proc run {stage} {
    hbs::vivado-prj::checkStage $stage

    #
    # Project
    #
    hbs::evalPrePrjCbs
    if {$hbs::Device == ""} {
      hbs::panic "cannot set part, hbs::Device not set"
    }
    hbs::Eval "set_property part $hbs::Device \[current_project\]"

    if {$hbs::Top == ""} {
      hbs::panic "cannot set top, hbs::Top not set"
    }
    hbs::Eval "set_property top $hbs::Top \[current_fileset\]"

    hbs::evalPostPrjCbs
    if {$stage == "project"} { return }

    #
    # Synthesis
    #
    hbs::evalPreSynthCbs
    hbs::Eval "launch_runs $hbs::ArgsPrefix synth_1 $hbs::ArgsSuffix"
    hbs::Eval "wait_on_run synth_1"
    hbs::Eval {if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
  error "ERROR: synth_1 failed"
}}
    hbs::evalPostSynthCbs
    if {$stage == "synthesis"} { return }

    #
    # Implementation
    #
    hbs::evalPreImplCbs
    hbs::Eval "launch_runs $hbs::ArgsPrefix impl_1 $hbs::ArgsSuffix"
    hbs::Eval "wait_on_run impl_1"
    hbs::Eval {if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
  error "ERROR: impl_1 failed"
}}
    hbs::evalPostImplCbs
    if {$stage == "implementation"} { return }

    #
    # Bitstream
    #
    hbs::evalPreBitCbs
    hbs::Eval "open_run impl_1"
    hbs::Eval "write_bitstream $hbs::ArgsPrefix \[get_property DIRECTORY \[current_run\]\]/\[current_project\].bit $hbs::ArgsSuffix"
    hbs::evalPostBitCbs
  }
}

# AMD xsim simulator.
#
# Custom Tcl batch script for running simulation can be added by adding .tcl file:
#   hbs::AddFile your-xsim-run.tcl
# Only one Tcl batch file can be set. Adding consecutive Tcl file results in error.
# If you want to change the Tcl batch file depending on the run, then implement
# the logic in the .hbs file.
#
# xsim does not support `hbs::ExitSeverity` variable.
# This is because xsim does not allow changing the assert level
# at which the simulation should exit with an error.
#
# xsim supports the following stages:
#   - analysis,
#   - elaboration,
#   - simulation.
namespace eval hbs::xsim {
  set hdlFiles [dict create]
  set tclBatchFile ""

  set generics [dict create]

  proc addFile {files} {
    foreach file $files {
      set extension [file extension $file]
      switch $extension {
        ".v" -
        ".sv" -
        ".vhd" -
        ".vhdl" {
          hbs::xsim::addHdlFile $file
        }
        ".tcl" {
          hbs::xsim::setTclBatchFile $file
        }
        default {
          hbs::panic "unhandled file extension '$extension'"
        }
      }
    }
  }

  proc setTclBatchFile {file} {
    if {$hbs::xsim::tclBatchFile != ""} {
      hbs::panic "cannot set file to $file, file already set to $hbs::xsim::tclBatchFile"
    }
    set hbs::xsim::tclBatchFile $file
  }

  proc library {} {
    if {$hbs::Lib eq ""} {
      return "work"
    }
    return $hbs::Lib
  }

  proc vhdlStd {std} {
    switch $std {
      # 2008 is the default one
      ""     { return "--2008" }
      "1987" -
      "1993" { return "" }
      "2000" -
      "2002" -
      "2008" { return "--2008" }
      "2019" { return "--2019" }
    }
  }

  proc verilogStd {std} {
    switch $std {
      # SystemVerilog is the default one
      ""     { return "-sv" }
      "1995" -
      "2001" { return "" }
      "2005" -
      "2009" -
      "2012" -
      "2017" -
      "2023" { return "-sv" }
    }
  }

  proc genericArgs {} {
    set args ""
    dict for {name value} $hbs::xsim::generics {
      set args "$args -generic_top $name=$value"
    }
    return $args
  }

  proc addHdlFile {file} {
    hbs::dbg "adding file $file"

    set lib [hbs::xsim::library]

    set std ""
    set ext [file extension $file]
    if {[hbs::isVhdlExtension $ext]} {
      set err [hbs::isValidVhdlStd $hbs::Std]
      if {$err ne ""} {
        hbs::panic "$file: $err"
      }
      set std [hbs::xsim::vhdlStd $hbs::Std]
    } elseif {[hbs::isVerilogExtension $ext]} {
      set err [hbs::isValidVerilogStd $hbs::Std]
      if {$err ne ""} {
        hbs::panic "$file: $err"
      }
      set std [hbs::xsim::verilogStd $hbs::Std]
    }

    dict append hbs::xsim::hdlFiles $file \
        [dict create \
        std $std \
        lib $lib \
        argsPrefix $hbs::ArgsPrefix \
        argsSuffix $hbs::ArgsSuffix]
  }

  proc analyzeVhdl {file args_} {
    set cmd "xvhdl [dict get $args_ argsPrefix] -work [dict get $args_ lib] [dict get $args_ std] $file [dict get $args_ argsSuffix]"
    set err [hbs::Exec $cmd]
    if {$err} {
      hbs::panic "$file analysis failed with exit status $err"
    }
  }

  proc analyzeVerilog {file args_} {
    set cmd "xvlog [dict get $args_ argsPrefix] -work [dict get $args_ lib] [dict get $args_ std] $file [dict get $args_ argsSuffix]"
    set err [hbs::Exec $cmd]
    if {$err} {
      hbs::panic "$file analysis failed with exit status $err"
    }
  }

  proc analyze {} {
    hbs::dbg "starting files analysis"

    set workDir [pwd]
    cd $hbs::targetDir

    dict for {file args} $hbs::xsim::hdlFiles {
      set ext [file extension $file]
      if {[hbs::isVhdlExtension $ext]} {
        hbs::xsim::analyzeVhdl $file $args
      } elseif {[hbs::isVerilogExtension $ext]} {
        hbs::xsim::analyzeVerilog $file $args
      }
    }

    cd $workDir
  }

  proc elaborate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "xelab $hbs::ArgsPrefix -debug all [hbs::xsim::genericArgs] $hbs::Top $hbs::ArgsSuffix"
    set err [hbs::Exec $cmd]
    if {$err} {
      hbs::panic "$hbs::Top elaboration failed with exit status $err"
    }

    cd $workDir
  }

  proc simulate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set batchFile $hbs::xsim::tclBatchFile
    if {$batchFile == ""} {
      exec -ignorestderr echo "log_wave -recursive *\nrun all\nexit" > run.tcl
      set batchFile "run.tcl"
    }

    set cmd "xsim $hbs::ArgsPrefix -stats -onerror quit -tclbatch $batchFile $hbs::Top $hbs::ArgsSuffix"
    set err [hbs::Exec $cmd]
    if {$err} {
      hbs::panic "simulation failed with exit status $err"
    }

    cd $workDir
  }

  proc checkStage {stage} {
    switch $stage {
      "" -
      "analysis" -
      "elaboration" -
      "simulation" {
        ;
      }
      default {
        hbs::panic "invalid stage '$stage', valid xsim stages are: 'analysis', 'elaboration', 'simulation'"
      }
    }
  }

  proc run {stage} {
    hbs::xsim::checkStage $stage

    if {!$hbs::DryRun} {
      set err [catch {eval exec -ignorestderr "which xsim"}]
      if {$err} {
        hbs::panic "xsim not found, probably vivado settings script is not sourced"
      }
    }

    # Analysis
    hbs::evalPreAnalCbs
    hbs::xsim::analyze
    hbs::evalPostAnalCbs
    if {$stage == "analysis"} { return }

    # Elaboration
    hbs::evalPreElabCbs
    hbs::xsim::elaborate
    hbs::evalPostElabCbs
    if {$stage == "elaboration"} { return }

    # Simulation
    hbs::evalPreSimCbs
    hbs::xsim::simulate
    hbs::evalPostSimCbs
  }
}

# Siemens questa simulator.
#
# Custom do file for running simulation can be added by adding file with .do extension:
#   hbs::AddFile my-run.do
# Only one .do can be added. Adding consecutive .do file results in error.
# If you want to change the .do file depending on the run, then implement
# the logic in the .hbs file.
#
# questa supports the following stages:
#   - analysis,
#   - simulation.
# There is no elaboration stage as vsim performs elaboration as its first step.
namespace eval hbs::questa {
  set hdlFiles [dict create]
  set doFile ""

  set generics [dict create]

  proc addFile {files} {
    foreach file $files {
      set extension [file extension $file]
      switch $extension {
        ".v" -
        ".sv" -
        ".vhd" -
        ".vhdl" {
          hbs::questa::addHdlFile $file
        }
        ".tcl" {
          hbs::questa::setDoFile $file
        }
        default {
          hbs::panic "unhandled file extension '$extension'"
        }
      }
    }
  }

  proc setDoFile {file} {
    if {$hbs::questa::doFile != ""} {
      hbs::panic "cannot set file to $file, file already set to $hbs::questa::doFile"
    }
    set hbs::::doFile $file
  }

  proc library {} {
    if {$hbs::Lib eq ""} {
      return "work"
    }
    return $hbs::Lib
  }

  proc vhdlStd {} {
    switch $hbs::Std {
      # 2008 is the default one
      ""     { return "-2008" }
      "1987" { return "-87" }
      "1993" { return "-93" }
      "2000" { return "" }
      "2002" { return "-2002" }
      "2008" { return "-2008" }
      "2019" { return "-2019" }
    }
  }

  proc verilogStd {} {
    switch $hbs::Std {
      # 2012 is the default one
      ""     { return "-sv -sv12compat" }
      "1995" { return "vlog95compat" }
      "2001" { return "vlog01compat" }
      "2005" { return "-sv -sv05compat" }
      "2009" { return "-sv -sv09compat" }
      "2012" { return "-sv -sv12compat" }
      "2017" { return "-sv -sv17compat" }
      "2023" { return "-sv -sv23compat" }
    }
  }

  # Converts hbs::ExitSeverity into values understood by questa.
  proc exitSeverity {} {
    switch $hbs::ExitSeverity {
      "note"    { return "0" }
      "warning" { return "1" }
      "error"   { return "2" }
      "failure" { return "3" }
      default   { hbs::panic [hbs::invalidExitSeverityMsg $hbs::ExitSeverity] }
    }
  }

  proc genericArgs {} {
    set args ""
    dict for {name value} $hbs::questa::generics {
      set args "$args -G$name=$value"
    }
    return $args
  }

  proc addHdlFile {file} {
    hbs::dbg "adding file $file"

    set lib [hbs::questa::library]

    set std ""
    set ext [file extension $file]
    if {[hbs::isVhdlExtension $ext]} {
      set err [hbs::isValidVhdlStd $hbs::Std]
      if {$err ne ""} {
        hbs::panic "$file: $err"
      }
      set std [hbs::questa::vhdlStd]
    } elseif {[hbs::isVerilogExtension $ext]} {
      set err [hbs::isValidVerilogStd $hbs::Std]
      if {$err ne ""} {
        hbs::panic "$file: $err"
      }
      set std [hbs::questa::verilogStd]
    }

    dict append hbs::questa::hdlFiles $file \
        [dict create \
        std $std \
        lib $lib \
        argsPrefix $hbs::ArgsPrefix \
        argsSuffix $hbs::ArgsSuffix]
  }

  proc analyzeVhdl {file args_} {
    set cmd "vcom [dict get $args_ argsPrefix] -work [dict get $args_ lib] [dict get $args_ std] $file [dict get $args_ argsSuffix]"
    puts $cmd
    set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
    if {$exitStatus != 0} {
      hbs::panic "$file analysis failed with exit status $exitStatus"
    }
  }

  proc analyzeVerilog {file args_} {
    set cmd "vlog [dict get $args_ argsPrefix] -work [dict get $args_ lib] [dict get $args_ std] $file [dict get $args_ argsSuffix]"
    puts $cmd
    set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
    if {$exitStatus != 0} {
      hbs::panic "$file analysis failed with exit status $exitStatus"
    }
  }

  proc analyze {} {
    hbs::dbg "starting files analysis"

    set workDir [pwd]
    cd $hbs::targetDir

    dict for {file args} $hbs::questa::hdlFiles {
      set ext [file extension $file]
      if {[hbs::isVhdlExtension $ext]} {
        hbs::questa::analyzeVhdl $file $args
      } elseif {[hbs::isVerilogExtension $ext]} {
        hbs::questa::analyzeVerilog $file $args
      }
    }

    cd $workDir
  }

  proc simulate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set doFile $hbs::questa::doFile
    if {$doFile == ""} {
      exec -ignorestderr echo "vcd add -r /*; onbreak {quit -code 1}; onerror {quit -code 1}; set BreakOnAssertion [hbs::questa::exitSeverity]; run -all; quit" > run.do
      set doFile "run.do"
    }

    set cmd "vsim $hbs::ArgsPrefix [hbs::questa::genericArgs] $hbs::Top -c -stats -vcddump $hbs::Top.vcd -do $doFile $hbs::ArgsSuffix"
    puts $cmd
    if {[catch {eval exec -ignorestderr $cmd} output] eq 0} {
      puts $output
    } else {
      hbs::panic $output
    }

    cd $workDir
  }

  proc checkStage {stage} {
    switch $stage {
      "" -
      "analysis" -
      "simulation" {
        ;
      }
      default {
        hbs::panic "invalid stage '$stage', valid questa stages are: 'analysis', 'simulation'"
      }
    }
  }

  proc run {stage} {
    hbs::questa::checkStage $stage

    set exitStatus [catch {eval exec -ignorestderr "which vsim"}]
    if {$exitStatus != 0} {
      hbs::panic "vsim not found, make sure it is in your PATH"
    }

    # Analysis
    hbs::evalPreAnalCbs
    hbs::questa::analyze
    hbs::evalPostAnalCbs
    if {$stage == "analysis"} { return }

    # Simulation
    hbs::evalPreSimCbs
    hbs::questa::simulate
    hbs::evalPostSimCbs
  }
}

proc hbs::PrintHelp {} {
  puts "Usage"
  puts ""
  puts "  hbs.tcl <command> \[arguments\]"
  puts ""
  puts "The command is one of:"
  puts ""
  puts "  help          Print help message"
  puts "  dump-cores    Dump info about cores in JSON format"
  puts "  list-cores    List cores found in .hbs files"
  puts "  list-targets  List targets for given core"
  puts "  run           Run given target"
  puts "  version       Print hbs version"
}

if {$argv0 eq [info script]} {
  if {$argc < 1 } {
    puts stderr "missing command, check help"
    exit 1
  }

  set hbs::cmd [lindex $argv 0]

  if {$hbs::cmd ni {"help" "version"}} {
    hbs::init
  }

  switch $hbs::cmd {
    "help" {
      hbs::PrintHelp
    }
    "dump-cores" {
      set chnnl stdout

      # Target path was provided, so first carry out a fake run
      # to gather inormation on dependencies.
      if {[llength $argv] != 1} {
        set hbs::TopTargetPath [lindex $argv 1]
        set hbs::TopTargetArgs [lreplace $argv 0 1]

        set hbs::TopCorePath [hbs::getCorePathFromTargetPath $hbs::TopTargetPath]
        set hbs::TopCoreName [hbs::getCorePathFromTargetPath $hbs::TopCorePath]
        set hbs::TopTargetName [hbs::getNameFromPath $hbs::TopTargetPath]

        hbs::runTarget $hbs::TopTargetPath {*}$hbs::TopTargetArgs

        set fileName [string map {"::" "--"} $hbs::TopTargetPath]
        set chnnl [open "$fileName.json" w]
      }

      hbs::dumpCores $chnnl
    }
    "list-cores" {
      hbs::listCores
    }
    "list-targets" {
      set corePath [lindex $argv 1]
      hbs::listTargets $corePath
    }
    "run"     -
    "dry-run" {
      if {$hbs::cmd eq "dry-run"} {
        set hbs::DryRun 1
      }

      set hbs::TopTargetPath [lindex $argv 1]
      set hbs::TopTargetArgs [lreplace $argv 0 1]

      set hbs::TopCorePath [hbs::getCorePathFromTargetPath $hbs::TopTargetPath]
      set hbs::TopCoreName [hbs::getCorePathFromTargetPath $hbs::TopCorePath]
      set hbs::TopTargetName [hbs::getNameFromPath $hbs::TopTargetPath]

      hbs::runTarget $hbs::TopTargetPath {*}$hbs::TopTargetArgs
    }
    "version" {
      puts 1.0
    }
    default {
      puts stderr "invalid command '$hbs::cmd', check help"
      exit 1
    }
  }
}
