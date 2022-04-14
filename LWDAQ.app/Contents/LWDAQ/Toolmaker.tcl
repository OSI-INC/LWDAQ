<script>

</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn]
set contents [read $f]
close $f
set ofn "~/Desktop/Out.txt"

set point_num 0-
while {[gets $f line] >= 0} {
	LWDAQ_print -nonewline $ofn "[lrange $line 4 end] "
	incr point_num
	if {$point_num % 9 == 0} {LWDAQ_print $ofn}
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn]
set ofn "~/Desktop/Out.txt"

set point_num 0-
while {[gets $f line] >= 0} {
	LWDAQ_print -nonewline $ofn "[lrange $line 4 end] "
	incr point_num
	if {$point_num % 9 == 0} {LWDAQ_print $ofn}
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn]
set ofn "~/Desktop/Out.txt"

set point_num 0
while {[gets $f line] >= 0} {
	LWDAQ_print -nonewline $ofn "[lrange $line 4 end] "
	incr point_num
	if {$point_num % 9 == 0} {LWDAQ_print $ofn}
}

close $f
</script>

