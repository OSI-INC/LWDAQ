if {[package vsatisfies [package present Tcl] 8.5]} {
	package ifneeded tls 1.8.0 [list apply {{dir} {
		if {{shared} eq "static"} {
			load {} Tls
		} else {
			load [file join $dir tcltls.dll] Tls
		}

		set tlsTclInitScript [file join $dir tls.tcl]
		if {[file exists $tlsTclInitScript]} {
			source $tlsTclInitScript
		}
	}} $dir]
} elseif {[package vsatisfies [package present Tcl] 8.4]} {
	package ifneeded tls 1.8.0 [list load [file join $dir tcltls.dll] Tls]
}
