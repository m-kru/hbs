#!/bin/tclsh

namespace eval hbs {
	set Debug 0

	set BuildDir "build"
	set Device ""
	set Library ""
	set Standard ""
	set Tool ""
	set Top ""

	# Core and target currently being run
	set thisCore ""
	set thisTarget ""

	set fileList {}
	set cores [dict create]

	proc SetTool {tool} {
		if {$hbs::Tool !=  ""} {
			puts stderr "hbs: can't set tool to $tool, tool already set to $hbs::Tool"
			exit 1
		}

		switch $tool {
			"GHDL" {
				set hbs::Tool $tool
			}
			"Vivado" {
				# Check if the script is already run by Vivado
				if {[catch {version} ver] == 0} {
					if {[string match "Vivado*" $ver]} {
						# Vivado already runs the script
						set hbs::Tool "Vivado"

						set prjDir [regsub :: "$hbs::BuildDir/$hbs::thisCore/$hbs::thisTarget" -]
						set prjName [regsub -all :: "$hbs::thisCore\:\:$hbs::thisTarget" -]
						create_project -force $prjName $prjDir
						set_property part $hbs::Device [current_project]
					}
				} else {
					# Run the script with Vivado
					set prjDir [regsub :: "$hbs::BuildDir/$hbs::thisCore/$hbs::thisTarget" -]
					file mkdir $prjDir

					set cmd "vivado \
							-mode batch \
							-source [file normalize [info script]] \
							-journal $prjDir/vivado.jou \
							-log $prjDir/vivado.log \
							-tclargs run $hbs::thisCore\:\:$hbs::thisTarget \
							>@ stdout"
					if {[catch {eval exec $cmd} output] == 0} {
						exit 0
					} else {
						puts "hbs: $output"
						puts stderr "hbs: vivado exited with error"
						exit 1
					}
				}
			}
			default {
				puts stderr "hbs: unknown tool $tool"
				exit 1
			}
		}
	}

	proc SetTop {top} {
		set hbs::Top $top
	}

	proc Init {} {
			set hbs::fileList [findFiles . *.hbs]

		if {$hbs::Debug} {
			puts stderr "hbs: found [llength $hbs::fileList] core files:"
			foreach fileName $hbs::fileList {
				puts "  $fileName"
			}
		}

		foreach fileName $hbs::fileList {
			source $fileName
		}
	}

	proc Register {} {
		set file [file normalize [info script]]
		set core [uplevel 1 [list namespace current]]
		set targets [uplevel 1 [list info procs]]
		if {$hbs::Debug} {
			puts stderr "hbs: registering core $core with following [llength $targets] targets:"
			foreach target $targets {
				puts "  $target"
			}
		}

		set targetsDict [dict create]
		foreach target $targets {
			dict append targetsDict $target [dict create files {} dependencies {}]
		}

		dict append hbs::cores $core [dict create file $file targets $targetsDict]

		#puts $hbs::cores
	}

	# AddDep adds target dependencies.
	proc AddDep {args} {
		set core [uplevel 1 [list namespace current]]
		set target [hbs::getTargetFromTargetPath [lindex [info level -1] 0]]

		#puts "core: $core, target: $target"

		set parentCore $hbs::thisCore
		set parentTarget $hbs::thisTarget

		set ctx [hbs::saveContext]

		foreach target $args {
			hbs::clearContext

			set hbs::thisCore [hbs::getCoreFromTargetPath $target]
			set hbs::thisTarget [hbs::getTargetFromTargetPath $target]

		}
	
		hbs::restoreContext $ctx
	}

	# args is the list of patterns used for globbing files.
	proc AddFile {args} {
		set core [uplevel 1 [list namespace current]]
		set dir [file dirname [dict get [dict get $hbs::cores $core] file]]

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
				"GHDL" {
				hbs::ghdl::AddFile $files
			}
			"Vivado" {
				hbs::vivado::AddFile $files
			}
			"" {
				puts stderr "hbs: can't add file, hbs::Tool not set"
				exit 1
			}
			default {
				puts stderr "uknown tool $hbs::Tool"
				exit 1
			}
		}
	}

	proc Run {target} {
		hbs::clearContext
		set hbs::thisCore [hbs::getCoreFromTargetPath $target]
		set hbs::thisTarget [hbs::getTargetFromTargetPath $target]
		hbs::$target
	}

	proc clearContext {} {
		set hbs::Library ""
		set hbs::Standard ""
		set hbs::Tool ""
		set hbs::Top ""
		set hbs::thisCore ""
		set hbs::thisTarget ""
	}

	proc saveContext {} {
		set ctx [dict create \
				Library $hbs::Library \
				Standard $hbs::Standard \
				Tool $hbs::Tool \
				Top $hbs::Top \
				thisCore $hbs::thisCore \
				thisTarget $hbs::thisTarget]
		return $ctx
	}

	proc restoreContext {ctx} {
		set hbs::Library [dict get $ctx Library]
		set hbs::Standard [dict get $ctx Standard]
		set hbs::Tool [dict get $ctx Tool]
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

			set deps [dict get $filesAndDeps dependencies]
			puts -nonewline $chnnl "\t\t\t\t\"dependencies\": \["
			set depsLen [llength $deps]
			set d 0
			foreach dep $deps {
				puts -nonewline $chnnl "\"$dep\""
				incr d
				if {$d < $depsLen} {
					puts $chnnl -nonewline ", "
				}
			}
			puts $chnnl "\],"

			set files [dict get $filesAndDeps files]
			puts -nonewline $chnnl "\t\t\t\t\"files\": \["
			set filesLen [llength $files]
			set f 0
			foreach file $files {
				puts -nonewline $chnnl "\"$file\""
				incr f
				if {$f < $filesLen} {
					puts -nonewline $chnnl ", "
				}
			}
			puts $chnnl "\]"

			incr t
			if {$t < $targetsSize} {
				puts $chnnl "\n\t\t\t\}, "
			} else {
				puts $chnnl "\n\t\t\t\}"
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

	# targetDir returns build directory for given target.
	proc targetDir {} {
		if {$hbs::BuildDir eq ""} {
			puts stderr "hbs: can't create target directory, hbs::BuildDir, not set"
			exit 1
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
		if {$hbs::Library eq ""} {
			return "work"
		}
		return $hbs::Library
	}

	proc standard {} {
		switch $hbs::Standard {
			# 2008 is the default one
			""     { return "08" }
			"1987" { return "87" }
			"1993" { return "93" }
			"2000" { return "00" }
			"2002" { return "02" }
			"2008" { return "08" }
			default {
				puts stderr "ghdl: invalid hbs::Standard $hbs::Standard"
				exit 1
			}
		}
	}

	proc AddVHDLFile {file} {
		if {$hbs::Debug} {
			puts "ghdl: adding file $file"
		}
		set lib [hbs::ghdl::library]
		dict append hbs::ghdl::vhdlFiles $file \
				[dict create std [hbs::ghdl::standard] work $lib workdir $lib]
	}

	proc analyze {} {
		if {$hbs::Debug} {
			puts "ghdl: starting files analysis"
		}
		set buildDir "$hbs::BuildDir/$hbs::thisCore/$hbs::thisTarget/"
		dict for {file args} $hbs::ghdl::vhdlFiles {
			set libDir "$buildDir[dict get $args workdir]"

			# Create library directory if it doesn't exist
			if {[file exist $libDir] eq 0} {
				file mkdir $libDir
			}

			set cmd "ghdl -a --std=[dict get $args std] --work=[dict get $args work] --workdir=$libDir $file"

			puts $cmd
			if {[catch {eval exec $cmd} output] ne 0} {
				puts $output
				exit 1
			}
		}
	}

	proc elaborate {} {
		set workDir [pwd]
		set targetDir "$hbs::BuildDir/$hbs::thisCore/$hbs::thisTarget"
		cd $targetDir
		set cmd "ghdl -e --std=[hbs::ghdl::standard] --workdir=[hbs::ghdl::library] $hbs::Top"
		puts $cmd
		if {[catch {eval exec $cmd} output] ne 0} {
			puts $output
			exit 1
		}
		cd $workDir
	}

	proc run {} {
		hbs::ghdl::analyze
		hbs::ghdl::elaborate

		set workDir [pwd]
		set targetDir "$hbs::BuildDir/$hbs::thisCore/$hbs::thisTarget"
		cd $targetDir

		set cmd "./$hbs::Top --wave=ghdl.ghw"
		puts $cmd
		if {[catch {eval exec $cmd} output] eq 0} {
			puts $output
		} else {
			puts $output
			exit 1
		}


		set coresJSON [open cores.json w]
		hbs::dumpCores $coresJSON

		cd $workDir
	}
}

namespace eval hbs::vivado {
	proc AddFile {files} {
		foreach file $files {
			set extension [file extension $file]
			switch $extension {
				".vhd" -
				".vhdl" {
					hbs::vivado::AddVHDLFile $file
				}
				default {
					puts stderr "vivado: unhandled file extension '$extension'"
					exit 1
				}
			}
		}
	}

	proc library {} {
		if {$hbs::Library eq ""} {
			return "xil_defaultlib"
		}
		return $hbs::Library
	}

	proc VHDLStandard {} {
		switch $hbs::Standard {
			# 2008 is the default one
			""     { return "-vhdl2008" }
			"2008" { return "-vhdl2008" }
			"2019" { return "-vhdl2019" }
			default {
				puts stderr "vivado: invalid hbs::Standard $hbs::Standard for VHDL file"
				exit 1
			}
		}
	}

	proc AddVHDLFile {file} {
		if {$hbs::Debug} {
			puts "vivado: adding file $file"
		}
		read_vhdl -library [hbs::vivado::library] [hbs::vivado::VHDLStandard] $file
	}

	proc run {} {
		set_property top $hbs::Top [current_fileset]
	}
}

proc hbs::PrintHelp {} {
	puts "Usage"
	puts ""
	puts "  hbs.tcl <command> \[arguments\]"
	puts ""
	puts "The commands are:"
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

	set target [lindex $argv [expr {$argc - 1}]]

	hbs::Init
	switch $cmd {
		"dump-cores" {
			hbs::dumpCores
		}
		"list-cores" {
			hbs::listCores
		}
		"list-targets" {
			puts "unimplemented"
		}
		"run" {
			hbs::Run $target
		}
		default {
			puts stderr "unknown command $cmd, check help"
			exit 1
		}
	}
}
