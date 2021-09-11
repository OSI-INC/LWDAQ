<script>
set fnl [LWDAQ_get_file_name 1]
set histogram [list]
foreach fn $fnl {
	set f [open $fn r]
	set contents [split [string trim [read $f]] \n]
	close $f

	foreach interval $contents {
		foreach channel [lrange $interval 2 end] {
			set index [lsearch -index 0 $histogram $channel]
			if {$index >= 0} {
				set count [expr [lindex $histogram $index 1] + 1]
				set histogram [lreplace $histogram $index $index "$channel $count"]
			} else {
				lappend histogram "$channel 1"
			}
		}
	}

	LWDAQ_print $t $histogram
}
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
set histogram [list]
foreach fn $fnl {
	set f [open $fn r]
	set contents [split [string trim [read $f]] \n]
	close $f

	foreach interval $contents {
		foreach channel [lrange $interval 2 end] {
			set index [lsearch -index 0 $histogram $channel]
			if {$index >= 0} {
				set count [expr [lindex $histogram $index 1] + 1]
				set histogram [lreplace $histogram $index $index "$channel $count"]
			} else {
				lappend histogram "$channel 1"
			}
		}
	}
}

LWDAQ_print $t "Found loss in [llength $histogram] channels."

set histogram [lsort -increasing -index 0 $histogram]
LWDAQ_print $t $histogram
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
set histogram [list]
foreach fn $fnl {
	set f [open $fn r]
	set contents [split [string trim [read $f]] \n]
	close $f

	foreach interval $contents {
		foreach channel [lrange $interval 2 end] {
			set index [lsearch -index 0 $histogram $channel]
			if {$index >= 0} {
				set count [expr [lindex $histogram $index 1] + 1]
				set histogram [lreplace $histogram $index $index "$channel $count"]
			} else {
				lappend histogram "$channel 1"
			}
		}
	}
}

LWDAQ_print $t "Found loss in [llength $histogram] channels."

set histogram [lsort -increasing -index 0 $histogram]
foreach record $histogram {
	LWDAQ_print $t $record
}
</script>

<script>
set fnl [LWDAQ_get_file_name 1]
set histogram [list]
foreach fn $fnl {
	set f [open $fn r]
	set contents [split [string trim [read $f]] \n]
	close $f

	foreach interval $contents {
		foreach channel [lrange $interval 2 end] {
			set index [lsearch -index 0 $histogram $channel]
			if {$index >= 0} {
				set count [expr [lindex $histogram $index 1] + 1]
				set histogram [lreplace $histogram $index $index "$channel $count"]
			} else {
				lappend histogram "$channel 1"
			}
		}
	}
}

LWDAQ_print $t "Found loss in [llength $histogram] channels."

set histogram [lsort -increasing -index 0 $histogram]
foreach record $histogram {
	LWDAQ_print $t $record
}
</script>

