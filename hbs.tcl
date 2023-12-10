namespace eval hbs {
    set Debug 1

    set Library ""
    set Standard ""
    set Tool ""
    set Top ""

    set fileList {}
    set cores [dict create]

    proc Init {} {
        set hbs::fileList [findFiles . *.hbs]

        if {$hbs::Debug} {
            puts "Found [llength $hbs::fileList] core files:"
            foreach fileName $hbs::fileList {
                puts "  $fileName"
            }
        }

        foreach fileName $hbs::fileList {
            source $fileName
        }
    }

    proc Register {} {
        set file [uplevel 1 [list file normalize [info script]]]
        set core [uplevel 1 [list namespace current]]
        set targets [uplevel 1 [list info procs]]
        if {$hbs::Debug} {
            puts "Registering core $core with following [llength $targets] targets:"
            foreach target $targets {
                puts "  $target"
            }
        }

        dict append hbs::cores $core [dict create file $file targets $targets]
        #puts $hbs::cores
    }

    proc AddDependency {} {

    }

    proc AddFile {files} {
        switch $hbs::Tool {
           "ghdl" -
           "GHDL" {
              hbs::ghdl::AddFile $files
           }
           "Vivado" -
           "vivado" {
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

    proc Library {} {
        if {$hbs::Library eq "" } {
            return "work"
        }
        return $hbs::Library
    }

    proc Standard {} {
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
        set lib [hbs::ghdl::Library]
        dict append hbs::ghdl::vhdlFiles $file \
                [dict create std [hbs::ghdl::Standard] lib $lib worklib $lib]
        puts $hbs::ghdl::vhdlFiles
    }
}
