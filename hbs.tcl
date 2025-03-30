#!/bin/tclsh

# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2023 Michał Kruszewski
# https://github.com/m-kru/hbs

# Public API
namespace eval hbs {
  # Path of the core which target is currently being run.
  set ThisCore ""

  # Name of the target currently being run.
  set ThisTarget ""

  # BuildDir is the build directory path.
  set BuildDir "build"

  # Device is target device. Often also called part.
  set Device ""

  # Lib is current library for adding files.
  set Lib ""

  # Std is current standard for adding files.
  set Std ""

  # Tool is target tool name. It must be lowercase.
  set Tool ""

  # Top is name of the top entity/module. Often also called toplevel.
  set Top ""

  # Custom (set by user) arguments prefix inserted right after command or program name.
  set ArgsPrefix ""

  # Custom (set by user) arguments suffix placed at the end of command or program call
  # or before the final argument.
  set ArgsSuffix ""

  # Path of the top core being run.
  set TopCorePath ""

  # Path of the top target being run.
  set TopTargetPath ""

  # Name of the top target being run.
  set TopTarget ""

  # List with command line arguments passed to the top target.
  set TopTargetArgs ""

  proc SetBuildDir {path} {
    set hbs::BuildDir $path
  }

  # Sets name of the device/part.
  #
  # To get the name of currently set Device simply
  # read the value of hbs::Device variable.
  proc SetDevice {dev} {
    set hbs::Device $dev
  }

  proc SetLib {lib} {
    set hbs::Lib $lib
  }

  proc SetStd {std} {
    set hbs::Std $std
  }

  # Sets name of the top entity/module.
  #
  # To get the name of currently set Top simply
  # read the value of hbs::Top variable.
  proc SetTop {top} {
    set hbs::Top $top
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
  # Calling this procedure is equivalent bo calling both
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
  # All the tool names are typed in lowercase.
  # Remember about this rule if you add support for a new tool.
  #
  # Currently supported tools include:
  #   - ghdl,
  #   - nvc,
  #   - vivado-prj - Vivado project mode,
  #   - xim - Vivado simulator.
  proc SetTool {tool} {
    if {$hbs::Tool !=  ""} {
      puts stderr "hbs::SeTool: core '$hbs::ThisCore', target '$hbs::ThisTarget', can't set tool to '$tool', tool already set to '$hbs::Tool'"
      exit 1
    }

    switch $tool {
      "ghdl" {
        set hbs::Tool $tool
        hbs::ghdl::init
      }
      "nvc" {
        set hbs::Tool $tool
      }
      "vivado-prj" {
        # Check if the script is already run by Vivado
        if {[catch {version} ver] == 0} {
          if {[string match "Vivado*" $ver]} {
            # Vivado already runs the script
            set hbs::Tool "vivado-prj"

            hbs::dbg "creating vivado project"

            set hbs::targetDir [regsub -all :: "$hbs::BuildDir/$hbs::ThisCore/$hbs::ThisTarget" /]
            set prjName [regsub -all :: "$hbs::ThisCore\:\:$hbs::ThisTarget" -]
            set cmd "create_project $hbs::ArgsPrefix -force $prjName $hbs::targetDir $hbs::ArgsSuffix"
            puts $cmd
            eval $cmd

            hbs::dbg "vivado project created successfully"
          }
        } else {
          # Run the script with Vivado
          set prjDir [regsub -all :: "$hbs::BuildDir/$hbs::ThisCore/$hbs::ThisTarget" /]
          file mkdir $prjDir

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
            puts stderr "hbs::SetTool: vivado exited with status $exitStatus"
            exit 1
          }
        }
      }
      "xsim" {
        set hbs::Tool $tool
      }
      default {
        puts stderr "hbs::SetTool: [unknownToolMsg $tool]"
        exit 1
      }
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
      "xsim" {
        return "simulation"
      }
      "vivado-prj" {
        return "synthesis"
      }
      default {
        puts stderr "hbs::ToolType: hbs::Tool not set"
        exit 1
      }
    }
  }

  # Registers given core.
  #
  # This procedure must be called as the last in the given core namespace.
  proc Register {} {
    set file [file normalize [info script]]
    set core [uplevel 1 [list namespace current]]

    if {[dict exists $hbs::cores $core]} {
      puts stderr "can't register core '[string replace $core 0 6 ""]' in $file, core with the same path already registered in [dict get $hbs::cores $core file]"
      exit 1
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
    set target [hbs::getTargetFromTargetPath [lindex [info level -1] 0]]

    set targetPath [lindex $args 0]
    set args [lreplace $args 0 0]

    checkTargetExists $targetPath

    # Add dependency to the core info dictionary.
    set deps [dict get $hbs::cores "::hbs::$hbs::ThisCore" targets $hbs::ThisTarget dependencies]
    lappend deps $targetPath
    dict set hbs::cores "::hbs::$hbs::ThisCore" targets $hbs::ThisTarget dependencies $deps

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
    set hbs::ThisCore [hbs::getCorePathFromTargetPath $targetPath]
    set hbs::ThisTarget [hbs::getTargetFromTargetPath $targetPath]

    hbs::$targetPath {*}$args

    hbs::restoreContext $ctx
  }

  # Adds files to the tool flow.
  #
  # Multiple files with different extensions can be added in a single call.
  # args is the list of patterns used for globbing files.
  # The file paths are relative to the `.hbs` file path where the procedure is called.
  proc AddFile {args} {
    set hbsFileDir [file dirname [dict get [dict get $hbs::cores ::hbs::$hbs::ThisCore] file]]

    if {$args == {}} {
      set target [hbs::getTargetFromTargetPath [lindex [info level -1] 0]]
      puts stderr "hbs::AddFile: no files provided, core '$hbs::ThisCore' target '$target'"
      exit 1
    }

    set files {}

    foreach pattern $args {
      # Append hbsFileDir only in the case of relative paths.
      if {[string match "/*" $pattern]} {
        foreach file [glob -nocomplain $pattern] {
          lappend files $file
        }
      } else {
        foreach file [glob -nocomplain -path "$hbsFileDir/" $pattern] {
          lappend files $file
        }
      }
    }

    set targetFiles [dict get $hbs::cores "::hbs::$hbs::ThisCore" targets $hbs::ThisTarget files]
    foreach file $files {
      lappend targetFiles $file
    }
    dict set hbs::cores "::hbs::$hbs::ThisCore" targets $hbs::ThisTarget files $targetFiles

    switch $hbs::Tool {
      "ghdl" {
        hbs::ghdl::addFile $files
      }
      "nvc" {
        hbs::nvc::addFile $files
      }
      "vivado-prj" {
        hbs::vivado-prj::addFile $files
      }
      "xsim" {
        hbs::xsim::addFile $files
      }
      "" {
        puts stderr "hbs: can't add file $file, hbs::Tool not set"
        exit 1
      }
      default {
        puts stderr "hbs: uknown tool $hbs::Tool"
        exit 1
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
        puts stderr "hbs::Run: invalid stage '$stage'"
        exit 1
      }
    }

    if {$hbs::cmd eq "dump-cores"} { return }

    set hbs::targetDir [regsub -all :: "$hbs::BuildDir/$hbs::ThisCore/$hbs::ThisTarget" /]
    if {[file exist $hbs::targetDir] eq 0} {
      file mkdir $hbs::targetDir
    }

    # Replace "::" with "--".
    # Glib does not support ':' in file names.
    set fileName [string map {"::" "--"} $hbs::TopTargetPath]
    hbs::dumpCores [open "$hbs::targetDir/$fileName.json" w]

    switch $hbs::Tool {
      "ghdl" {
        hbs::ghdl::run $stage
      }
      "nvc" {
        hbs::nvc::run $stage
      }
      "vivado-prj" {
        hbs::vivado-prj::run $stage
      }
      "xsim" {
        hbs::xsim::run $stage
      }
      default {
        puts stderr "hbs::Run: [unknownToolMsg $hbs::Tool]"
        exit 1
      }
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
        puts -stderr "hbs::SetGeneric: can't set generic '$name', hbs::Tool not set"
        exit 1
      }
      "ghdl" {
        dict append hbs::ghdl::generics $name $value
      }
      "nvc" {
        dict append hbs::nvc::generics $name $value
      }
      "vivado-prj" {
        set_property generic $name=$value [current_fileset]
      }
      "xsim" {
        dict append hbs::xsim::generics $name $value
      }
    default {
        puts -stderr "hbs::SetGeneric: [unknownToolMsg $hbs::Tool]"
        exit 1
      }
    }
  }

  # ClearPostAnalCbList removes all callbacks from the post analysis callback list.
  proc ClearPostAnalCbList {} {
    set hbs::postAnalCbs []
  }

  # AddPostAnalCb adds post analysis stage callback to the post analysis callback list.
  proc AddPostAnalCb {args} {
    lappend hbs::postAnalCbs $args
  }

  # ClearPostElabCbList removes all callbacks from the post elaboration callback list.
  proc ClearPostElabCbList {} {
    set hbs::postElabCbs []
  }

  # AddPostElabCb adds post elaboration stage callback to the post elaboration callback list.
  proc AddPostElabCb {args} {
    lappend hbs::postElabCbs $args
  }

  # ClearPostSimCbList removes all callbacks from the post simulation callback list.
  proc ClearPostSimCbList {} {
    set hbs::postSimCbs []
  }

  # AddPostSimCb adds post simulation stage callback to the post simulation callback list.
  proc AddPostSimCb {args} {
    lappend hbs::postSimCbs args
  }

  # ClearPostPrjCbList removes all callbacks from the post project callback list.
  proc ClearPostPrjCbList {} {
    set hbs::postPrjCbs []
  }

  # AddPostPrjCb adds post project creation stage callback to the post project callback list.
  proc AddPostPrjCb {args} {
    lappend hbs::postPrjCbs $args
  }

  # ClearPostSynthCbList removes all callbacks from the post synthesis callback list.
  proc ClearPostSynthCbList {} {
    set hbs::postSynthCbs []
  }

  # AddPostSynthCb adds post synthesis stage callback to the post synthesis callback list.
  proc AddPostSynthCb {args} {
    lappend hbs::postSynthCbs $args
  }

  # ClearPostImplCbList removes all callbacks from the post implementation callback list.
  proc ClearPostImplCbList {} {
    set hbs::postImplCbs []
  }

  # AddPostImplCb adds post implementation stage callback to the post implementation callback list.
  proc AddPostImplCb {args} {
    lappend hbs::postImplCbs $args
  }

  # ClearPostBitCbList removes all callbacks from the post bitstream callback list.
  proc ClearPostBitCbList {} {
    set hbs::postBitCbs []
  }

  # AddPostBitCb adds post bitstream generation stage callback to the post bitstream callback list.
  proc AddPostBitCb {args} {
    lappend hbs::postBitCbs $args
  }

  # Exec evaluates Tcl 'exec' command but with working directory changed to the directory
  # in which .hbs file with given core is defined. After the 'exec' the working directory is restored.
  proc Exec {args} {
    set workDir [pwd]

    set hbsFileDir [file dirname [dict get $hbs::cores ::hbs::$hbs::ThisCore file]]
    cd $hbsFileDir

    exec {*}$args

    cd $workDir
  }

  # CoreDir returns directory of file in which current core is defined.
  proc CoreDir {} {
    return [file dirname [dict get $hbs::cores ::hbs::$hbs::ThisCore file]]
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

  # Target output directory.
  set targetDir ""

  # Stage callbacks
  set postAnalCbs  []
  set postElabCbs  []
  set postSimCbs   []
  set postPrjCbs   []
  set postSynthCbs []
  set postImplCbs  []
  set postBitCbs   []

  proc evalPostAnalCbs  {} { foreach cb $hbs::postAnalCbs  { eval $cb } }
  proc evalPostElabCbs  {} { foreach cb $hbs::postElabCbs  { eval $cb } }
  proc evalPostSimCbs   {} { foreach cb $hbs::postSimCbs   { eval $cb } }
  proc evalPostPrjCbs   {} { foreach cb $hbs::postPrjCbs   { eval $cb } }
  proc evalPostSynthCbs {} { foreach cb $hbs::postSynthCbs { eval $cb } }
  proc evalPostImplCbs  {} { foreach cb $hbs::postImplCbs  { eval $cb } }
  proc evalPostBitCbs   {} { foreach cb $hbs::postBitCbs   { eval $cb } }

  set fileList {}
  set cores [dict create]

  # Dictionary containing targets that already have been run.
  # During the single flow, single target can be run only once with a given argument values.
  set runTargets [dict create]

  proc unknownToolMsg {tool} {
    return "core '$hbs::ThisCore', target '$hbs::ThisTarget', unknown tool '$tool', supported tools: 'ghdl', 'nvc', 'vivado-prj' \(project mode\), 'xsim'"
  }

  proc init {} {
    set hbs::fileList [findFiles . *.hbs]
    hbs::sortFileList

    if {$hbs::debug} {
      puts stderr "hbs::init: found [llength $hbs::fileList] hbs files:"
      foreach fileName $hbs::fileList {
        puts "  $fileName"
      }
    }

    foreach fileName $hbs::fileList {
      source $fileName
    }
  }

  proc checkTargetExists {targetPath} {
    set core [hbs::getCorePathFromTargetPath $targetPath]
    set target [hbs::getTargetFromTargetPath $targetPath]

    if {[dict exists $hbs::cores ::hbs::$core] == 0} {
      puts stderr "core '$core' not found, maybe the core is not registered \(hsb::Register\)"
      exit 1
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

    set hbs::ThisCore [hbs::getCorePathFromTargetPath $targetPath]
    set hbs::ThisTarget [hbs::getTargetFromTargetPath $targetPath]

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
    set hbs::Std ""
    set hbs::Top ""
    set hbs::ThisCore ""
    set hbs::ThisTarget ""
    set hbs::ArgsPrefix ""
    set hbs::ArgsSuffix ""
  }

  proc saveContext {} {
    set ctx [dict create \
        Lib $hbs::Lib \
        Std $hbs::Std \
        Top $hbs::Top \
        ThisCore $hbs::ThisCore \
        ThisTarget $hbs::ThisTarget \
        ArgsPrefix $hbs::ArgsPrefix \
        ArgsSuffix $hbs::ArgsSuffix]
    return $ctx
  }

  proc restoreContext {ctx} {
    set hbs::Lib [dict get $ctx Lib]
    set hbs::Std [dict get $ctx Std]
    set hbs::Top [dict get $ctx Top]
    set hbs::ThisCore [dict get $ctx ThisCore]
    set hbs::ThisTarget [dict get $ctx ThisTarget]
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
      puts stderr "core '$corePath' not found, maybe the core is not registered \(hsb::Register\)"
      exit 1
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
  proc getTargetFromTargetPath {path} {
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
      }
      return 0
    }
    set hbs::fileList [lsort -command cmp $hbs::fileList]
  }
}

# GHDL simulator
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

  proc init {} {
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
          puts stderr "ghdl::addFile: unhandled file extension '$extension'"
          exit 1
        }
      }
    }
  }

  proc library {} {
    if {$hbs::Lib eq ""} { return "work" }
    return $hbs::Lib
  }

  proc standard {} {
    switch $hbs::Std {
      # 2008 is the default one
      ""     { return "08" }
      "1987" { return "87" }
      "1993" { return "93" }
      "2000" { return "00" }
      "2002" { return "02" }
      "2008" { return "08" }
      default {
        puts stderr "ghdl::standard: invalid hbs::Std $hbs::Std"
        exit 1
      }
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
    hbs::dbg  "adding file $file"

    set lib [hbs::ghdl::library]
    dict append hbs::ghdl::vhdlFiles $file \
        [dict create \
        std [hbs::ghdl::standard] \
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
      puts $cmd
      set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
      if {$exitStatus != 0} {
        puts stderr "ghdl::analyze: $file analysis failed with exit status $exitStatus"
        exit 1
      }
    }

    cd $workDir
  }

  proc elaborate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "ghdl -e $hbs::ArgsPrefix --std=[hbs::ghdl::standard] --workdir=work $hbs::ghdl::libs $hbs::ArgsSuffix $hbs::Top"
    puts $cmd
    set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
    if {$exitStatus != 0} {
      puts stderr "ghdl::elaborate: $hbs::Top elaboration failed with exit status $exitStatus"
      exit 1
    }

    cd $workDir
  }

  proc simulate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "./$hbs::Top $hbs::ArgsPrefix --wave=$hbs::Top.ghw [hbs::ghdl::genericArgs] $hbs::ArgsSuffix"
    puts $cmd
    if {[catch {eval exec -ignorestderr $cmd} output] eq 0} {
      puts $output
    } else {
      puts stderr $output
      exit 1
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
        puts "ghdl::checkStage: invalid stage '$stage', valid ghdl stages are: analysis, elaboration and simulation"
        exit 1
      }
    }
  }

  proc run {stage} {
    hbs::ghdl::checkStage $stage

    hbs::ghdl::analyze
    hbs::evalPostAnalCbs
    if {$stage == "analysis"} { return }

    hbs::ghdl::elaborate
    hbs::evalPostElabCbs
    if {$stage == "elaboration"} { return }

    hbs::ghdl::simulate
    hbs::evalPostSimCbs
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

  proc addFile {files} {
    foreach file $files {
      set extension [file extension $file]
      switch $extension {
        ".vhd" -
        ".vhdl" {
          hbs::nvc::addVhdlFile $file
        }
        default {
          puts stderr "nvc::addFile: unhandled file extension '$extension'"
          exit 1
        }
      }
    }
  }

  proc library {} {
    if {$hbs::Lib eq ""} {
      return "work"
    }
    return $hbs::Lib
  }

  proc standard {} {
    switch $hbs::Std {
      # 2019 is the default one
      ""     { return "2019" }
      "1993" { return "1993" }
      "2000" { return "2000" }
      "2002" { return "2002" }
      "2008" { return "2008" }
      "2019" { return "2019" }
      default {
        puts stderr "nvc::standard: invalid hbs::Std $hbs::Std"
        exit 1
      }
    }
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

    set lib [hbs::nvc::library]
    dict append hbs::nvc::vhdlFiles $file \
        [dict create \
        std [hbs::nvc::standard] \
        lib $lib \
        argsPrefix $hbs::ArgsPrefix \
        argsSuffix $hbs::ArgsSuffix]
  }

  proc analyze {} {
    hbs::dbg "starting files analysis"

    set workDir [pwd]
    cd $hbs::targetDir

    dict for {file args} $hbs::nvc::vhdlFiles {
      set lib [dict get $args lib]
      set cmd "nvc [dict get $args argsPrefix] --std=[dict get $args std] $hbs::nvc::libs --work=$lib -a $file [dict get $args argsSuffix]"
      puts $cmd
      set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
      if {$exitStatus != 0} {
        puts stderr "nvc::analyze: $file analysis failed with exit status $exitStatus"
        exit 1
      }
    }

    cd $workDir
  }

  proc elaborate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "nvc $hbs::ArgsPrefix --std=[hbs::nvc::standard] $hbs::nvc::libs -e $hbs::Top [hbs::nvc::genericArgs] $hbs::ArgsSuffix"
    puts $cmd
    set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
    if {$exitStatus != 0} {
      puts stderr "nvc::elaborate: $hbs::Top elaboration failed with exit status $exitStatus"
      exit 1
    }

    cd $workDir
  }

  proc simulate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "nvc $hbs::ArgsPrefix --std=[hbs::nvc::standard] $hbs::nvc::libs -r $hbs::Top --wave $hbs::ArgsSuffix"
    puts $cmd
    if {[catch {eval exec -ignorestderr $cmd} output] eq 0} {
      puts $output
    } else {
      puts stderr $output
      exit 1
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
        puts "nvc::checkStage: invalid stage '$stage', valid nvc stages are: analysis, elaboration and simulation"
        exit 1
      }
    }
  }

  proc run {stage} {
    hbs::nvc::checkStage $stage

    hbs::nvc::analyze
    hbs::evalPostAnalCbs
    if {$stage == "analysis"} { return }

    hbs::nvc::elaborate
    hbs::evalPostElabCbs
    if {$stage == "elaboration"} { return }

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
  proc addFile {files} {
    foreach file $files {
      hbs::dbg "adding file $file"

      set extension [file extension $file]
      switch $extension {
        ".bd" {
          hbs::vivado-prj:addBlockDesignFile $file
        }
        ".mem" {
          hbs::vivado-prj::addMemFile $file
        }
        ".v" {
          hbs::vivado-prj::addVerilogFile $file
        }
        ".sv" {
          hbs::vivado-prj::addSystemVerilogFile $file
        }
        ".vhd" -
        ".vhdl" {
          hbs::vivado-prj::addVhdlFile $file
        }
        ".tcl" {
          hbs::vivado-prj::addTclFile $file
        }
        ".xci" {
          hbs::vivado-prj::addXciFile $file
        }
        ".xdc" {
          hbs::vivado-prj::addXdcFile $file
        }
        default {
          puts stderr "vivado: unhandled file extension '$extension'"
          exit 1
        }
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
      "1993" { return "" }
      "2000" { return "" }
      "2002" { return "" }
      "2008" { return "-vhdl2008" }
      "2019" { return "-vhdl2019" }
      default {
        puts stderr "vivado: invalid hbs::Std $hbs::Std for VHDL file"
        exit 1
      }
    }
  }

  proc addBlockDesignFile {file} {
    read_bd $file
  }

  proc addMemFile {file} {
    read_mem $file
  }

  proc addTclFile {file} {
    source $file
  }

  proc addXciFile {file} {
    read_ip $file
  }

  proc addXdcFile {file} {
    read_xdc $file
  }

  proc addVerilogFile {file} {
    read_verilog -library [hbs::vivado-prj::library] $file
  }

  proc addSystemVerilogFile {file} {
    read_verilog -library [hbs::vivado-prj::library] -sv $file
  }

  proc addVhdlFile {file} {
    read_vhdl -library [hbs::vivado-prj::library] [hbs::vivado-prj::vhdlStandard] $file
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
        puts "vivado-prj::checkStage: invalid stage '$stage', valid vivado-prj stages are: project, synthesis, implementation and bitstream"
        exit 1
      }
    }
  }

  proc run {stage} {
    hbs::vivado-prj::checkStage $stage

    #
    # Project
    #
    if {$hbs::Device == ""} {
      puts "hbs::vivado-prj::run: cannot set part, hbs::Device not set"
      exit 1
    }
    set cmd "set_property part $hbs::Device \[current_project\]"
    puts $cmd
    eval $cmd

    if {$hbs::Top == ""} {
      puts "hbs::vivado-prj::run: cannot set top, hbs::Top not set"
      exit 1
    }
    set cmd "set_property top $hbs::Top \[current_fileset\]"
    puts $cmd
    eval $cmd

    hbs::evalPostPrjCbs
    if {$stage == "project"} { return }

    #
    # Synthesis
    #
    set cmd "launch_runs $hbs::ArgsPrefix synth_1 $hbs::ArgsSuffix"
    puts $cmd
    eval $cmd
    set cmd "wait_on_run synth_1"
    puts $cmd
    eval $cmd
    if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
      error "ERROR: synth_1 failed"
    }
    hbs::evalPostSynthCbs
    if {$stage == "synthesis"} { return }

    #
    # Implementation
    #
    set cmd "launch_runs $hbs::ArgsPrefix impl_1 $hbs::ArgsSuffix"
    puts $cmd
    eval $cmd
    set cmd "wait_on_run impl_1"
    puts $cmd
    eval $cmd
    if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
      error "ERROR: impl_1 failed"
    }
    hbs::evalPostImplCbs
    if {$stage == "implementation"} { return }

    #
    # Bitstream
    #
    set cmd "open_run impl_1"
    puts $cmd
    eval $cmd
    set cmd "write_bitstream $hbs::ArgsPrefix [get_property DIRECTORY [current_run]]/[current_project].bit $hbs::ArgsSuffix"
    puts $cmd
    eval $cmd
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
          puts stderr "xsim::addFile: unhandled file extension '$extension'"
          exit 1
        }
      }
    }
  }

  proc setTclBatchFile {file} {
    if {$hbs::xsim::tclBatchFile != ""} {
      puts stderr "xsim::setTclBatchFile: cannot set file to $file, file already set to $hbs::xsim::tclBatchFile"
      exit 1
    }
    set hbs::xsim::tclBatchFile $file
  }

  proc library {} {
    if {$hbs::Lib eq ""} {
      return "work"
    }
    return $hbs::Lib
  }

  proc standard {} {
    switch $hbs::Std {
      # 2019 is the default one
      ""     { return "--2008" }
      "1993" { return "" }
      "2000" { return "" }
      "2002" { return "" }
      "2008" { return "--2008" }
      "2019" { return "--2019" }
      default {
        puts stderr "xsim::standard: invalid hbs::Std $hbs::Std"
        exit 1
      }
    }
  }

  proc genericArgs {} {
    set args ""
    dict for {name value} $hbs::xsim::generics {
      set args "$args -d $name=$value"
    }
    return $args
  }

  proc addHdlFile {file} {
    hbs::dbg "adding file $file"

    set lib [hbs::xsim::library]
    # Verilog and SystemVerilog have no standard
    set std ""
    # Only VHDL has standard
    set extension [file extension $file]
    if {$extension == ".vhd" || $extension == ".vhdl"} {
      set std [hbs::xsim::standard]
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
    puts $cmd
    set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
    if {$exitStatus != 0} {
      puts stderr "xsim::analyzeVhdl: $file analysis failed with exit status $exitStatus"
      exit 1
    }
  }

  proc analyzeVerilog {file args_} {
    set lib [dict get $args_ lib]
    set cmd "xvlog [dict get $args_ argsPrefix] -work $lib $file [dict get $args_ argsSuffix]"
    puts $cmd
    set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
    if {$exitStatus != 0} {
      puts stderr "xsim::analyzeVerilog: $file analysis failed with exit status $exitStatus"
      exit 1
    }
  }

  proc analyzeSystemVerilog {file args_} {
    set lib [dict get $args_ lib]
    set cmd "xvlog -sv [dict get $args_ argsPrefix] -work $lib $file [dict get $args_ argsSuffix]"
    puts $cmd
    set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
    if {$exitStatus != 0} {
      puts stderr "xsim::analyzeSystemVerilog: $file analysis failed with exit status $exitStatus"
      exit 1
    }
  }

  proc analyze {} {
    hbs::dbg "starting files analysis"

    set workDir [pwd]
    cd $hbs::targetDir

    dict for {file args} $hbs::xsim::hdlFiles {
      switch [file extension $file] {
        ".v" {
          hbs::xsim::analyzeVerilog $file $args
        }
        ".sv" {
          hbs::xsim::analyzeSystemVerilog $file $args
        }
        ".vhd" -
        ".vhdl" {
          hbs::xsim::analyzeVhdl $file $args
        }
      }
    }

    cd $workDir
  }

  proc elaborate {} {
    set workDir [pwd]
    cd $hbs::targetDir

    set cmd "xelab $hbs::ArgsPrefix -debug all [hbs::xsim::genericArgs] $hbs::Top $hbs::ArgsSuffix"
    puts $cmd
    set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
    if {$exitStatus != 0} {
      puts stderr "xsim::elaborate: $hbs::Top elaboration failed with exit status $exitStatus"
      exit 1
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

    set cmd "xsim $hbs::ArgsPrefix -stats -tclbatch $batchFile $hbs::Top $hbs::ArgsSuffix"
    puts $cmd
    if {[catch {eval exec -ignorestderr $cmd} output] eq 0} {
      puts $output
    } else {
      puts stderr $output
      exit 1
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
        puts "xsim::checkStage: invalid stage '$stage', valid xsim stages are: analysis, elaboration and simulation"
        exit 1
      }
    }
  }

  proc run {stage} {
    hbs::xsim::checkStage $stage

    set exitStatus [catch {eval exec -ignorestderr "which xsim"}]
    if {$exitStatus != 0} {
      puts stderr "xsim::analyze: xsim not found, probably vivado settings script is not sourced"
      exit 1
    }

    hbs::xsim::analyze
    hbs::evalPostAnalCbs
    if {$stage == "analysis"} { return }

    hbs::xsim::elaborate
    hbs::evalPostElabCbs
    if {$stage == "elaboration"} { return }

    hbs::xsim::simulate
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
    puts "missing command, check help"
    exit 1
  }

  hbs::init

  set hbs::cmd [lindex $argv 0]

  switch $hbs::cmd {
    "help" {
      hbs::PrintHelp
    }
    "dump-cores" {
      hbs::dumpCores
    }
    "list-cores" {
      hbs::listCores
    }
    "list-targets" {
      set corePath [lindex $argv 1]
      hbs::listTargets $corePath
    }
    "run" {
      set hbs::TopTargetPath [lindex $argv 1]
      set hbs::TopTargetArgs [lreplace $argv 0 1]

      set hbs::TopCorePath [hbs::getCorePathFromTargetPath $hbs::TopTargetPath]
      set hbs::TopTarget [hbs::getTargetFromTargetPath $hbs::TopTargetPath]

      hbs::runTarget $hbs::TopTargetPath {*}$hbs::TopTargetArgs
    }
    "version" {
      puts 0.0
    }
    default {
      puts stderr "unknown command $cmd, check help"
      exit 1
    }
  }
}
