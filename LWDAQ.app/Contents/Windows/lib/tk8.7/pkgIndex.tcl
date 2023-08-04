if {![package vsatisfies [package provide Tcl] 8.7-]} return
if {($::tcl_platform(platform) eq "unix") && ([info exists ::env(DISPLAY)]
	|| ([info exists ::argv] && ("-display" in $::argv)))} {
    if {[package vsatisfies [package provide Tcl] 9.0]} {
	package ifneeded tk 8.7a6 [list load [file normalize [file join $dir .. .. bin libtcl9tk8.7.dll]]]
    } else {
	package ifneeded tk 8.7a6 [list load [file normalize [file join $dir .. .. bin libtk8.7.dll]]]
    }
} else {
    if {[package vsatisfies [package provide Tcl] 9.0]} {
	package ifneeded tk 8.7a6 [list load [file normalize [file join $dir .. .. bin tcl9tk87.dll]]]
    } else {
	package ifneeded tk 8.7a6 [list load [file normalize [file join $dir .. .. bin tk87.dll]]]
    }
}
package ifneeded Tk 8.7a6 [list package require -exact tk 8.7a6]
