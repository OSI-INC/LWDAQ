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

<script>
set f [open ~/Desktop/ramp.txt w]
for {set i 0} {$i < 255} {incr i 4} {
	puts $f "$i [expr 255 - $i] $i [expr 255 - $i]"
}
close $f
</script>

<script>
set f [open ~/Desktop/Perimiter.txt w]
foreach i {0 32 64 96 128 160 192 224 255} {
	puts $f "$i [expr 255 - $i] 0 255"
}
foreach i {0 32 64 96 128 160 192 224 255} {
	puts $f "255 0 $i [expr 255 - $i]"
}
foreach i {255 224 192 160 128 96 64 32 0} {
	puts $f "$i [expr 255 - $i] 255 0"
}
foreach i {255 224 192 160 128 96 64 32 0} {
	puts $f "0 255	$i [expr 255 - $i]"
}
close $f
</script>

<script>
set f [open ~/Desktop/Hysteresis_NS.txt w]
foreach i {0 32 64 96 128 160 192 224 255} {
	puts $f "$i [expr 255 - $i] 133 133"
}
foreach i {255 224 192 160 128 96 64 32 0} {
	puts $f "$i [expr 255 - $i] 133 133"
}
close $f
</script>

<script>
set f [open ~/Desktop/Hysteresis_EW.txt w]
foreach i {0 32 64 96 128 160 192 224 255} {
	puts $f "133 133 $i [expr 255 - $i]"
}
foreach i {255 224 192 160 128 96 64 32 0} {
	puts $f "133 133 $i [expr 255 - $i]"
}
close $f
</script>

<script>
set f [open ~/Desktop/Hysteresis_NS.txt w]
for {set i 0} {$i < 256} {incr 4} {
	puts $f "$i [expr 255 - $i] 133 133"
}
for {set i 0} {$i < 256} {incr 4} {
	puts $f "[expr 255 - $i] $i 133 133"
}
close $f
</script>

<script>
set f [open ~/Desktop/Hysteresis_NS.txt w]
for {set i 0} {$i < 256} {incr i 4} {
	puts $f "$i [expr 255 - $i] 133 133"
}
for {set i 0} {$i < 256} {incr i 4} {
	puts $f "[expr 255 - $i] $i 133 133"
}
close $f
</script>

<script>
set f [open ~/Desktop/Hysteresis_EW.txt w]
for {set i 0} {$i < 256} {incr i 4} {
	puts $f "133 133 $i [expr 255 - $i]"
}
for {set i 0} {$i < 256} {incr i 4} {
	puts $f "133 133 [expr 255 - $i] $i"
}
close $f
</script>

