<script>

</script>

<script>
set f [open ~/ramp.txt w]
for {set i 0} {$i < 256} {incr i} {
	puts $f "$i $i $i $i"
}
close $f
</script>

<script>
set f [open ~/ramp.txt w]
for {set i 0} {$i < 256} {incr i 2} {
	puts $f "$i $i $i $i"
}
close $f
</script>

<script>
set f [open ~/ramp.txt w]
for {set i 0} {$i < 256} {incr i 2} {
	puts $f "$i $i $i $i"
}
close $f
</script>

<script>
set f [open ~/ramp.txt w]
for {set i 0} {$i < 256} {incr i 1} {
	puts $f "$i $i $i $i"
}
close $f
</script>

<script>
set f [open ~/Desktop/ramp.txt w]
for {set i 0} {$i < 256} {incr i 1} {
	puts $f "$i [expr 255 - $i]"
}
close $f
</script>

<script>
set f [open ~/Desktop/ramp.txt w]
for {set i 64} {$i < 192} {incr i 2} {
	puts $f "$i [expr 255 - $i]"
}
close $f
</script>

