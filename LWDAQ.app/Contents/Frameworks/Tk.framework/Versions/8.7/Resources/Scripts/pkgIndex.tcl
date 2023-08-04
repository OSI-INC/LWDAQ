if {![package vsatisfies [package provide Tcl] 8.6-]} return
if {[package vsatisfies [package provide Tcl] 9.0]} {
    package ifneeded tk 8.7a5 [list load [file normalize [file join $dir .. .. Tk]]]
} else {
    package ifneeded tk 8.7a5 [list load [file normalize [file join $dir .. .. Tk]]]
}
package ifneeded Tk 8.7a5 [list package require -exact tk 8.7a5]
