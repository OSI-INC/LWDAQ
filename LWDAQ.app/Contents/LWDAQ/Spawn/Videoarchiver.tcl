set Videoarchiver_mode "Child"
LWDAQ_run_tool Videoarchiver.tcl
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
