#!/bin/tclsh

namespace eval hbs {
	set Debug 0

	set BuildDir "build"
	set Library ""
	set Standard ""
	set Tool ""
	set Top ""

	# Run target
	set target ""

	set fileList {}
	set cores [dict create]

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

		dict append hbs::cores $core [dict create file $file targets $targets]
		#puts $hbs::cores
	}

	proc AddDependency {} {

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

		switch $hbs::Tool {
			"GHDL" {
				hbs::ghdl::AddFile $files
			}
			"Vivado" {
				hbs::vivado::AddFile $files
			}
			"" {
				puts stderr "hbs::Tool not set"
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
		set hbs::target $target
		hbs::$target
	}

	proc clearContext {} {
		set hbs::Library ""
		set hbs::Standard ""
		set hbs::Tool ""
		set hbs::Top ""
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
		set buildDir "$hbs::BuildDir/$hbs::target/"
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
		set targetDir "$hbs::BuildDir/$hbs::target"
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
		set targetDir "$hbs::BuildDir/$hbs::target"
		cd $targetDir

		set cmd "./$hbs::Top --wave=ghdl.ghw"
		puts $cmd
		if {[catch {eval exec $cmd} output] eq 0} {
			puts $output
		} else {
			puts $output
			exit 1
		}

		cd $workDir
	}
}

proc hbs::PrintHelp {} {
	puts "Help message"
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
		"list-cores" {
			puts "unimplemented"
		}
		"run" {
			hbs::Run $target
		}
		default {
			puts stderr "unknown command $cmd"
			exit 1
		}
	}
}
