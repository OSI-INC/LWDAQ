set Neuroarchiver_mode "Recorder"
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
