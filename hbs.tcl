#!/bin/tclsh

# Public API
namespace eval hbs {
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

	proc SetBuildDir {path} {
		set hbs::BuildDir $path
	}

	proc SetDevice {dev} {
		set hbs::Device $dev
	}

	proc SetLib {lib} {
		set hbs::Lib $lib
	}

	proc SetStd {std} {
		set hbs::Std $std
	}

	proc SetTop {top} {
		set hbs::Top $top
	}

	proc SetTool {tool} {
			if {$hbs::Tool !=  ""} {
			puts stderr "hbs::SeTool: can't set tool to $tool, tool already set to $hbs::Tool"
			exit 1
		}

		switch $tool {
			"ghdl" {
				set hbs::Tool $tool
			}
			"vivado" {
				# Check if the script is already run by Vivado
				if {[catch {version} ver] == 0} {
					if {[string match "Vivado*" $ver]} {
						# Vivado already runs the script
						set hbs::Tool "vivado"

						set hbs::targetDir [regsub :: "$hbs::BuildDir/$hbs::thisCore/$hbs::thisTarget" /]
						set prjName [regsub -all :: "$hbs::thisCore\:\:$hbs::thisTarget" -]
						create_project -force $prjName $hbs::targetDir
						set_property part $hbs::Device [current_project]
					}
				} else {
					# Run the script with Vivado
					set prjDir [regsub :: "$hbs::BuildDir/$hbs::thisCore/$hbs::thisTarget" /]
					file mkdir $prjDir

					set cmd "vivado \
							-mode batch \
							-source [file normalize [info script]] \
							-journal $prjDir/vivado.jou \
							-log $prjDir/vivado.log \
							-tclargs run $hbs::thisCore\:\:$hbs::thisTarget \
							>@ stdout"
					if {[catch {eval exec -ignorestderr $cmd} output] == 0} {
						exit 0
					} else {
						puts "hbs: $output"
						puts stderr "hbs: vivado exited with error"
						exit 1
					}
				}
			}
			default {
				puts stderr "hbs: unknown tool $tool, supported tools: ghdl, vivado"
				exit 1
			}
		}
	}

	# GetToolType reutrns type of the currently set tool.
	# Possible values are:
	#   - formal,
	#   - simulation,
	#   - synthesis.
	proc GetToolType {} {
			switch $hbs::Tool {
			"ghdl" {
				return "simulation"
			}
			"vivado" {
				return "synthesis"
			}
			default {
				puts -stderr "hbs::GetToolType: hbs::Tool not set"
				exit 1
			}
		}
	}

	# Register registers given core.
	# This proc must be called as the last in the given core namespace.
	proc Register {} {
			set file [file normalize [info script]]
		set core [uplevel 1 [list namespace current]]
		set targets [uplevel 1 [list info procs]]
		if {$hbs::debug} {
			puts stderr "hbs: registering core $core with following [llength $targets] targets:"
			foreach target $targets {
				puts "  $target"
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

	# AddDep adds target dependencies.
	proc AddDep {args} {
		set core [uplevel 1 [list namespace current]]
		set target [hbs::getTargetFromTargetPath [lindex [info level -1] 0]]

		set ctx [hbs::saveContext]

		foreach targetPath $args {
			# Add dependency to the core info dictionary
			set deps [dict get $hbs::cores "::hbs::$hbs::thisCore" targets $hbs::thisTarget dependencies]
			lappend deps $targetPath
			dict set hbs::cores "::hbs::$hbs::thisCore" targets $hbs::thisTarget dependencies $deps

			# Run dependency target
			hbs::clearContext
			set hbs::thisCore [hbs::getCoreFromTargetPath $targetPath]
			set hbs::thisTarget [hbs::getTargetFromTargetPath $targetPath]
			hbs::$targetPath
		}
	
		hbs::restoreContext $ctx
	}

	# AddFile add files to the tool flow.
	# Multiple files with different extensions can be added in a single call.
	# args is the list of patterns used for globbing files.
	# The file paths are relative to the `.hbs` file path where the proc is called.
	proc AddFile {args} {
		set core [uplevel 1 [list namespace current]]
		set dir [file dirname [dict get [dict get $hbs::cores $core] file]]

		if {$args == {}} {
			set target [hbs::getTargetFromTargetPath [lindex [info level -1] 0]]
			puts stderr "hbs::AddFile: no files provided, core '[string replace $core 0 6 ""]' target '$target'"
			exit 1
		}

		set files {}

		foreach pattern $args {
			foreach file [glob -nocomplain -path "$dir/" $pattern] {
				lappend files $file
			}
		}

		set targetFiles [dict get $hbs::cores "::hbs::$hbs::thisCore" targets $hbs::thisTarget files]
		foreach file $files {
			lappend targetFiles $file
		}
		dict set hbs::cores "::hbs::$hbs::thisCore" targets $hbs::thisTarget files $targetFiles

		switch $hbs::Tool {
			"ghdl" {
				hbs::ghdl::AddFile $files
			}
			"vivado" {
				hbs::vivado::AddFile $files
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

	# Run runs target in which it is called.
	# The stage parameter controls when the tool stops and must be one of:
	#   analysis - stop after file analysis,
	#   bitstream - stop after bitstream generation,
	#   elaboration - stop after design elaboration,
	#   implementation - stop after implementation,
	#   project - stop after project creation,
	#   simulation - stop after simulation,
	#   synthesis - stop after synthesis.
	# Not all tools supports all stages. Check documantation for "hbs::{tool}::run".
	proc Run {{stage ""}} {
		switch $stage {
			"" -
			"synthesis" -
			"implementation" {
				;
			}
			default {
				"hbs::Run: invalid stage $stage"
			}
		}
		switch $hbs::Tool {
			"ghdl" {
				hbs::ghdl::run $stage
			}
			"vivado" {
				hbs::vivado::run $stage
			}
		}
	}
}

# Private API
namespace eval hbs {
	set debug 0

	# Core and target currently being run
	set thisCore ""
	set thisTarget ""

	set targetDir ""

	set fileList {}
	set cores [dict create]

	proc init {} {
		set hbs::fileList [findFiles . *.hbs]

		if {$hbs::debug} {
			puts stderr "hbs: found [llength $hbs::fileList] core files:"
			foreach fileName $hbs::fileList {
				puts "  $fileName"
			}
		}

		foreach fileName $hbs::fileList {
			source $fileName
		}
	}

	proc runTarget {targetPath} {
		hbs::clearContext
		set core [hbs::getCoreFromTargetPath $targetPath]
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

		set hbs::thisCore $core
		set hbs::thisTarget $target

		hbs::$targetPath
	}

	proc clearContext {} {
		set hbs::Lib ""
		set hbs::Std ""
		set hbs::Top ""
		set hbs::thisCore ""
		set hbs::thisTarget ""
	}

	proc saveContext {} {
		set ctx [dict create \
				Lib $hbs::Lib \
				Std $hbs::Std \
				Top $hbs::Top \
				thisCore $hbs::thisCore \
				thisTarget $hbs::thisTarget]
		return $ctx
	}

	proc restoreContext {ctx} {
		set hbs::Lib [dict get $ctx Lib]
		set hbs::Std [dict get $ctx Std]
		set hbs::Top [dict get $ctx Top]
		set hbs::thisCore [dict get $ctx thisCore]
		set hbs::thisTarget [dict get $ctx thisTarget]
	}

	# dumpCoreInfo dumps single core info into JSON
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
				puts $chnnl "\t\t\t\}, "
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

	# getCoreFromTargetPath returns core path from the target path
	proc getCoreFromTargetPath {path} {
		set parts [split $path ::]
		# Remove target
		set parts [lreplace $parts end end]
		# Remove {}
		set parts [lreplace $parts end end]
		# TCL split command leaves {} in places of splits.
		# Hence, one ':' is enough here.
		return [join $parts :]
	}

	# getTargetFromTargetPath returns target name from the target path
	proc getTargetFromTargetPath {path} {
		return [lindex [split $path ::] end]
	}

	# findFiles
	# basedir - the directory to start looking in
	# pattern - A pattern, as defined by the glob command, that the files must match
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
}

namespace eval hbs::ghdl {
	set vhdlFiles [dict create]
	set libDirs [dict create]

	proc AddFile {files} {
		foreach file $files {
			set extension [file extension $file]
			switch $extension {
				".vhd" -
				".vhdl" {
					hbs::ghdl::AddVHDLFile $file
				}
				default {
					puts stderr "ghdl: unhandled file extension '$extension'"
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
			# 2008 is the default one
			""     { return "08" }
			"1987" { return "87" }
			"1993" { return "93" }
			"2000" { return "00" }
			"2002" { return "02" }
			"2008" { return "08" }
			default {
				puts stderr "ghdl: invalid hbs::Std $hbs::Std"
				exit 1
			}
		}
	}

	proc libs {} {
		set libs ""
		foreach libDir [dict keys $hbs::ghdl::libDirs] {
			set libs "$libs -P$libDir"
		}
		return $libs
	}

	proc AddVHDLFile {file} {
		if {$hbs::debug} {
			puts "ghdl: adding file $file"
		}

		set lib [hbs::ghdl::library]
		dict append hbs::ghdl::vhdlFiles $file \
				[dict create std [hbs::ghdl::standard] work $lib workdir $lib]
	}

	proc analyze {} {
		if {$hbs::debug} {
			puts "ghdl: starting files analysis"
		}

		dict for {file args} $hbs::ghdl::vhdlFiles {
			set libDir [file normalize "$hbs::targetDir/[dict get $args workdir]"]

			# Create library directory if it doesn't exist
			if {[file exist $libDir] eq 0} {
				file mkdir $libDir
			}
			dict set hbs::ghdl::libDirs $libDir ""

			set cmd "ghdl -a --std=[dict get $args std] --work=[dict get $args work] --workdir=$libDir [hbs::ghdl::libs] $file"
			puts $cmd
			set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
			if {$exitStatus != 0} {
				puts stderr "hbs::ghdl::analyze: $file analysis failed with exit status $exitStatus"
				exit 1
			}
		}
	}

	proc elaborate {} {
		set workDir [pwd]
		cd $hbs::targetDir
		set cmd "ghdl -e --std=[hbs::ghdl::standard] --workdir=[hbs::ghdl::library] [hbs::ghdl::libs] $hbs::Top"
		puts $cmd
		set exitStatus [catch {eval exec -ignorestderr $cmd >@ stdout}]
		if {$exitStatus != 0} {
			puts stderr "hbs::ghdl::elaborate: $hbs::Top elaboration failed with exit status $exitStatus"
			exit 1
		}
		cd $workDir
	}

	proc checkStage {stage} {
		switch $stage {
			"analysis" -
			"elaboration" -
			"simulation" -
			"" -
			default {
				puts "hbs::ghdl::run: invalid stage '$stage', valid stage are: analysis, elaboration and simulation"
			}
		}
	}

	# ghdl::run supports following stages:
	#   - analysis,
	#   - elaboration,
	#   - simulation.
	proc run {stage} {
		hbs::ghdl::checkStage $stage

		set hbs::targetDir [regsub :: "$hbs::BuildDir/$hbs::thisCore/$hbs::thisTarget" /]

		hbs::ghdl::analyze
		if {$stage == "analysis"} {
			exit 0
		}

		hbs::ghdl::elaborate
		if {$stage == "elaboration"} {
			exit 0
		}

		set workDir [pwd]
		cd $hbs::targetDir

		set cmd "./$hbs::Top --wave=ghdl.ghw"
		puts $cmd
		if {[catch {eval exec -ignorestderr $cmd} output] eq 0} {
			puts $output
		} else {
			puts stderr $output
			exit 1
		}

		set hbsJSON [open hbs.json w]
		hbs::dumpCores $hbsJSON

		cd $workDir
	}
}

namespace eval hbs::vivado {
	proc AddFile {files} {
		foreach file $files {
			if {$hbs::debug} {
				puts "vivado: adding file $file"
			}

			set extension [file extension $file]
			switch $extension {
				".bd" {
					hbs::vivado:AddBlockDesignFile $file
				}
				".mem" {
					hbs::vivado::AddMemFile $file
				}
				".v" {
					hbs::vivado::AddVerilogFile $file
				}
				".sv" {
					hbs::vivado::AddSystemVerilogFile $file
				}
				".vhd" -
				".vhdl" {
					hbs::vivado::AddVHDLFile $file
				}
				".tcl" {
					hbs::vivado::AddTclFile $file
				}
				".xci" {
					hbs::vivado::AddXCIFile $file
				}
				".xdc" {
					hbs::vivado::AddXDCFile $file
				}
				default {
					puts stderr "vivado: unhandled file extension '$extension'"
					exit 1
				}
			}
		}
	}

	proc library {} {
		if {$hbs::Lib eq ""} {
			return "xil_defaultlib"
		}
		return $hbs::Lib
	}

	proc VHDLStandard {} {
		switch $hbs::Std {
			# 2008 is the default one
			""     { return "-vhdl2008" }
			"2008" { return "-vhdl2008" }
			"2019" { return "-vhdl2019" }
			default {
				puts stderr "vivado: invalid hbs::Std $hbs::Std for VHDL file"
				exit 1
			}
		}
	}

	proc AddBlockDesignFile {file} {
		read_bd $file
	}

	proc AddMemFile {file} {
		read_mem $file
	}

	proc AddTclFile {file} {
		source $file
	}

	proc AddXCIFile {file} {
		read_ip $file
	}

	proc AddXDCFile {file} {
		read_xdc $file
	}

	proc AddVerilogFile {file} {
		read_vhdl -library [hbs::vivado::library] $file
	}

	proc AddSystemVerilogFile {file} {
		read_vhdl -library [hbs::vivado::library] -sv $file
	}

	proc AddVHDLFile {file} {
		read_vhdl -library [hbs::vivado::library] [hbs::vivado::VHDLStandard] $file
	}

	proc run {stage} {
		set hbsJSON [open "$hbs::targetDir/hbs.json" w]
		hbs::dumpCores $hbsJSON

		set_property top $hbs::Top [current_fileset]

		if {$stage == "project"} {
			close_project
			exit 0
		}
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
}

if {$argv0 eq [info script]} {
	if {$argc < 1 } {
		puts "missing command, check help"
		exit 1
	}

	set cmd [lindex $argv 0]
	if {$cmd eq "help"} {
		hbs::PrintHelp
		exit 0
	}

	set targetPath [lindex $argv [expr {$argc - 1}]]

	hbs::init

	switch $cmd {
		"dump-cores" {
			hbs::dumpCores
		}
		"list-cores" {
			hbs::listCores
		}
		"list-targets" {
			# In this case the targetPath argument is actually the corePath.
			hbs::listTargets $targetPath
		}
		"run" {
			hbs::runTarget $targetPath
		}
		default {
			puts stderr "unknown command $cmd, check help"
			exit 1
		}
	}
}
