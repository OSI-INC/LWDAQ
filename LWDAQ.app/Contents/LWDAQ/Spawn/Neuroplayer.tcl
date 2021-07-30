if {![info exists LWDAQ_Info]} {
	source LWDAQ.app/Contents/LWDAQ/Init.tcl
}
set Neuroarchiver_mode "Player"
LWDAQ_run_tool Neuroarchiver.tcl
switch $LWDAQ_Info(os) {
	"MacOS" {
		destroy .menubar.instruments
		destroy .menubar.tools
		destroy .menubar.spawn
	}
	"Windows" {
		destroy .menubar.instruments
		destroy .menubar.tools
		destroy .menubar.spawn
		destroy .menubar
	}
	"Linux" {
	}
}
