<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	set x$i 0
	set y$i 0
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.x$i $ff.y$i
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff
	set x$i 0
	set y$i 0
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.x$i $ff.y$i
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff
	set x$i 0
	set y$i 0
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.x$i $ff.y$i
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.x$i $ff.y$i -side left
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.x$i $ff.y$i -side left
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.x$i $ff.y$i -side left
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go 
pack $f.go -side top
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1 "
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "$M" green
	LWDAQ_print $t "$y" purple


}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1 "
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M: $M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM: $MM" orange

}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n $M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n $MM" orange

}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n$M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange

}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n$M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange
	set a 0
	foreach i {0 1 2} {
		set a [expr [lindex $MM $i]*[lindex $y $i]]
	}
	LWDAQ_print $t $a 
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n$M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange
	foreach j {0 3 6} {
		set a 0
		foreach i {0 1 2} {
			set a [expr [lindex $MM [expr $i+$j]]*[lindex $y [expr $i + $j]]]
		}
		LWDAQ_print $t $a
	}
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n$M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange
	foreach j {0 3 6} {
		set a 0
		foreach i {0 1 2} {
			set a [expr [lindex $MM [expr $i+$j]]*[lindex $y $i]]
		}
		LWDAQ_print $t $a
	}
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	set x$i 0
	set y$i 0
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n$M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange
	foreach j {0 3 6} {
		set a 0
		foreach i {0 1 2} {
			set a [expr $a + [lindex $MM [expr $i+$j]]*[lindex $y $i]]
		}
		LWDAQ_print $t $a
	}
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n$M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange
	foreach j {0 3 6} {
		set a 0
		foreach i {0 1 2} {
			set a [expr $a + [lindex $MM [expr $i+$j]]*[lindex $y $i]]
		}
		LWDAQ_print $t "Constant $j = $a"
	}
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n$M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange
	foreach j {0 3 6} {
		set a 0
		foreach i {0 1 2} {
			set a [expr $a + [lindex $MM [expr $i+$j]]*[lindex $y $i]]
		}
		LWDAQ_print $t "Constant $j = [format %6.2f $a]"
	}
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		LWDAQ_print $t "x$i = [set x$i], y$i = [set y$i]" blue
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	LWDAQ_print $t "M:\n$M" green
	LWDAQ_print $t "y: $y" purple
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange
	foreach j {0 3 6} {
		set a 0
		foreach i {0 1 2} {
			set a [expr $a + [lindex $MM [expr $i+$j]]*[lindex $y $i]]
		}
		LWDAQ_print $t "Constant $j = [format %6.2f $a]"
	}
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		LWDAQ_print $t "x$i = [set x$i], y$i = [set y$i]" blue
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	
	set MM [lwdaq matrix_inverse $M]
	LWDAQ_print $t "MM:\n$MM" orange
	foreach j {0 3 6} {
		set a 0
		foreach i {0 1 2} {
			set a [expr $a + [lindex $MM [expr $i+$j]]*[lindex $y $i]]
		}
		LWDAQ_print $t "Constant $j = [format %6.2f $a]"
	}
}
</script>

<script>
foreach i {1 2 3} {
	set ff [frame $f.f$i]
	pack $ff -side top
	label $ff.label -text "x$i y$i" -fg green
	entry $ff.x$i -textvariable x$i
	entry $ff.y$i -textvariable y$i
	pack $ff.label $ff.x$i $ff.y$i -side left
}
button $f.go -command Go -text "Go"
pack $f.go -side top


proc Go {} {
	global t
	set M ""
	set y ""
	foreach i {1 2 3} {
		global x$i y$i
		LWDAQ_print $t "x$i = [set x$i], y$i = [set y$i]" blue
		append M "[expr [set x$i]*[set x$i]] [set x$i] 1\n"
		append y "[set y$i] "
	}
	set M [string trim $M]
	set y [string trim $y]
	set MM [lwdaq matrix_inverse $M]

	set count 1
	foreach j {0 3 6} {
		set a 0
		foreach i {0 1 2} {
			set a [expr $a + [lindex $MM [expr $i+$j]]*[lindex $y $i]]
		}
		LWDAQ_print $t "Constant $count = [format %6.2f $a]"
		incr count
	}
}
</script>

