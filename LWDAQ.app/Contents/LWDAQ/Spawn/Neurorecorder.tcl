set Neuroarchiver_mode "Recorder"
LWDAQ_run_tool Neuroarchiver.tcl
switch $LWDAQ_Info(os) {
	"MacOS" {
		.menubar delete 1 2
	}
	"Windows" {
		.menubar delete 3 4
	}
	"Linux" {
		.menubar delete 3 4
	}
}
