<script>
# Simulate a sixteen-bit Galois linear feedback shift register (LFSR) and check that it
# produces no duplicate values.
set x "10100001"
set y "00100011"
set print_num 1000
set max_num 6553
set numbers [list]

LWDAQ_print $t "Generating numbers..." green
for {set i 0} {$i < $max_num} {incr i} {
	set c [string index $x end]
  set x "0[string range $x 0 end-1]"
	set cc [string index $y end]
	set y "$c[string range $y 0 end-1]"
  if {$cc} {
		set xx [expr $cc ^ [string index $x 0]]
		append xx [string index $x 1]
		append xx [expr $cc ^ [string index $x 2]]
		append xx [expr $cc ^ [string index $x 3]]
		append xx [string index $x 4]
		append xx [expr $cc ^ [string index $x 5]]
		append xx [string index $x 6]
		append xx [string index $x 7]
	} {
		set xx $x
	}
	set x $xx
  if {$i < $print_num} {LWDAQ_print $t "$i [expr 0b$x$y] [expr 0b$x] [expr 0b$y]"}
  lappend numbers [expr 0b$x$y]
  LWDAQ_support
}
LWDAQ_print -nonewline $t "Checking list..." brown
set count 0
for {set i 0} {$i < [llength $numbers]} {incr i} {
	set x [lindex $numbers $i]
	if {[lsearch -start [expr $i + 1] $numbers $x] >= 0} {
		LWDAQ_print $t "Multiple occurances of $x" orange
		incr count
	}
	if {$i % 1000 == 0} {LWDAQ_print -nonewline $t "." brown}
	LWDAQ_support
}
LWDAQ_print $t "Found $count duplicates."
</script>

<script>
# Simulate a sixteen-bit Galois linear feedback shift register (LFSR) and check that it
# produces no duplicate values.
set x "10100001"
set y "00100011"
set print_num 1000
set max_num 65536
set numbers [list]

LWDAQ_print $t "Generating numbers..." green
for {set i 0} {$i < $max_num} {incr i} {
	set c [string index $x end]
  set x "0[string range $x 0 end-1]"
	set cc [string index $y end]
	set y "$c[string range $y 0 end-1]"
  if {$cc} {
		set xx [expr $cc ^ [string index $x 0]]
		append xx [string index $x 1]
		append xx [expr $cc ^ [string index $x 2]]
		append xx [expr $cc ^ [string index $x 3]]
		append xx [string index $x 4]
		append xx [expr $cc ^ [string index $x 5]]
		append xx [string index $x 6]
		append xx [string index $x 7]
	} {
		set xx $x
	}
	set x $xx
  if {$i < $print_num} {LWDAQ_print $t "$i [expr 0b$x$y] [expr 0b$x] [expr 0b$y]"}
  lappend numbers [expr 0b$x$y]
  LWDAQ_support
}
LWDAQ_print -nonewline $t "Checking list..." brown
set count 0
for {set i 0} {$i < [llength $numbers]} {incr i} {
	set x [lindex $numbers $i]
	if {[lsearch -start [expr $i + 1] $numbers $x] >= 0} {
		LWDAQ_print $t "Multiple occurances of $x" orange
		incr count
	}
	if {$i % 1000 == 0} {LWDAQ_print -nonewline $t "." brown}
	LWDAQ_support
}
LWDAQ_print $t "Found $count duplicates."
</script>

<script>
# Simulate a sixteen-bit Galois linear feedback shift register (LFSR) and check that it
# produces no duplicate values.
set x "10100001"
set y "00100011"
set print_num 1000
set max_num 65536
set numbers [list]

LWDAQ_print $t "Generating numbers..." green
for {set i 0} {$i < $max_num} {incr i} {
	set c [string index $x end]
  set x "0[string range $x 0 end-1]"
	set cc [string index $y end]
	set y "$c[string range $y 0 end-1]"
  if {$cc} {
		set xx [expr $cc ^ [string index $x 0]]
		append xx [string index $x 1]
		append xx [expr $cc ^ [string index $x 2]]
		append xx [expr $cc ^ [string index $x 3]]
		append xx [string index $x 4]
		append xx [expr $cc ^ [string index $x 5]]
		append xx [string index $x 6]
		append xx [string index $x 7]
	} {
		set xx $x
	}
	set x $xx
  if {$i < $print_num} {LWDAQ_print $t "$i [expr 0b$x$y] [expr 0b$x] [expr 0b$y]"}
  lappend numbers [expr 0b$x$y]
  LWDAQ_support
}
LWDAQ_print -nonewline $t "Checking list..." brown
set count 0
for {set i 0} {$i < [llength $numbers]} {incr i} {
	set x [lindex $numbers $i]
	if {[lsearch -start [expr $i + 1] $numbers $x] >= 0} {
		LWDAQ_print $t "Multiple occurances of $x" orange
		incr count
	}
	LWDAQ_support
}
LWDAQ_print $t "Found $count duplicates."
</script>

<script>
# Simulate a sixteen-bit Galois linear feedback shift register (LFSR) and check that it
# produces no duplicate values.
set x "10100001"
set y "00100011"
set print_num 1000
set max_num 65535
set numbers [list]

LWDAQ_print $t "Generating numbers..." green
for {set i 0} {$i < $max_num} {incr i} {
	set c [string index $x end]
  set x "0[string range $x 0 end-1]"
	set cc [string index $y end]
	set y "$c[string range $y 0 end-1]"
  if {$cc} {
		set xx [expr $cc ^ [string index $x 0]]
		append xx [string index $x 1]
		append xx [expr $cc ^ [string index $x 2]]
		append xx [expr $cc ^ [string index $x 3]]
		append xx [string index $x 4]
		append xx [expr $cc ^ [string index $x 5]]
		append xx [string index $x 6]
		append xx [string index $x 7]
	} {
		set xx $x
	}
	set x $xx
  if {$i < $print_num} {LWDAQ_print $t "$i [expr 0b$x$y] [expr 0b$x] [expr 0b$y]"}
  lappend numbers [expr 0b$x$y]
  LWDAQ_support
}
LWDAQ_print $t "Checking list..." brown
set count 0
for {set i 0} {$i < [llength $numbers]} {incr i} {
	if {![winfo exists $t]} {break}
	set x [lindex $numbers $i]
	if {[lsearch -start [expr $i + 1] $numbers $x] >= 0} {
		LWDAQ_print $t "Multiple occurances of $x" orange
		incr count
	}
	LWDAQ_support
}
LWDAQ_print $t "Found $count duplicates."
</script>

