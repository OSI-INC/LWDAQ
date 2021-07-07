# Neruorecorder.tcl spawns a child process containing the recorder section
# of the Neuroarchiver Tool.
#
# Copyright (C) 2021 Kevan Hashemi, Open Source Instruments Inc.
#

cd $LWDAQ_Info(program_dir)
puts "Spawning child process..."
set ch [open "| [info nameofexecutable]" w+]
fconfigure $ch -translation auto -buffering line -blocking 0
lappend LWDAQ_Info(children) "$ch Neurorecorder"
puts "Child process initialized, using channel $ch\."
puts $ch {if {![info exists LWDAQ_Info]} {source LWDAQ.app/Contents/LWDAQ/Init.tcl}}
puts "Configuring child process as stand-alone Neurorecorder..."
puts $ch {set Neuroarchiver_mode Recorder}
puts $ch {LWDAQ_run_tool Neuroarchiver.tcl}
switch $LWDAQ_Info(os) {
	"MacOS" {
		puts $ch "destroy .menubar.instruments"
		puts $ch "destroy .menubar.tools"
		puts $ch "destroy .menubar.spawn"
	}
	"Windows" {
		puts $ch "destroy .menubar"
	}
	"Linux" {
	}
}
return "SUCCESS"
