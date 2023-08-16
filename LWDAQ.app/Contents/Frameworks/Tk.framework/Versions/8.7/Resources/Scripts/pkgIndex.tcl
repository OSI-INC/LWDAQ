if {[catch {package present Tcl 8.6-}]} return
package ifneeded Tk 8.7a3 [list load [file normalize [file join $dir .. .. Tk]] Tk]
