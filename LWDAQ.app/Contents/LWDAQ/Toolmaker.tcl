<script>
set num_columns 4
set c 1
for {set i 3001} {$i <= 3039} {incr i} {
	if {$c == 1} {
		LWDAQ_print $t "<tr>"
	}
	LWDAQ_print $t "<td><a href=\"A$i\">A$i</a>: Name</td>"
	if {$c == $num_columns} {
		LWDAQ_print $t "</tr>"
		set c 1
	} else {
		incr c
	}
}
</script>

<script>
set num_columns 4
set c 1
for {set i 3001} {$i <= 3039} {incr i} {
	if {$c == 1} {
		LWDAQ_print $t "<tr>"
	}
	LWDAQ_print $t "<td><a href=\"A$i/M$i\.html\">A$i</a>: Name</td>"
	if {$c == $num_columns} {
		LWDAQ_print $t "</tr>"
		set c 1
	} else {
		incr c
	}
}
</script>

<script>
set num_columns 3
set c 1
for {set i 3001} {$i <= 3039} {incr i} {
	if {$c == 1} {
		LWDAQ_print $t "<tr>"
	}
	LWDAQ_print $t "<td><a href=\"A$i/M$i\.html\">A$i</a>: Name</td>"
	if {$c == $num_columns} {
		LWDAQ_print $t "</tr>"
		set c 1
	} else {
		incr c
	}
}
</script>

