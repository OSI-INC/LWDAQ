<script>

</script>

<script>
# Analyze creep output file. We look at every advance of x and y separately for the
# available fibers. We fit a straight line to the position with respect to the log
# of time from 10 s to 200 s and use it to estimate the position at time 1000 s, 
# calculate the error.
set fn ~/Desktop/Creep_Out.txt
set f [open $fn]
set data [split [read $f] \n]
close $f
lwdaq_config -fsd 3
set index 0
while {$index < [llength $data]-9} {
	for {set column 1} {$column <= 6} {incr column} {
		set points ""
		for {set i [expr $index+2]} {$i <= [expr $index+8]} {incr i} {
			set log_time [format %.3f [expr log10([lindex $data $i 0])]]
			append points "$log_time [lindex $data $i $column] " 
		}
		LWDAQ_print $t "[lwdaq straight_line_fit [lrange $points 0 end-4]] [lindex $points end]"
	}
	set index [expr $index + 9]
}
</script>

