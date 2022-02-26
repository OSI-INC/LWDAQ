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

<script>
set f [open ~/Desktop/Spiral.txt w]
set angle 0
set radius 120.0
set pi 3.14159
while {$radius >= 0} {
	set n [expr round($radius * cos($angle)) + 133]
	set s [expr 255 - $n]
	set e [expr round($radius * sin($angle)) + 133]
	set w [expr 255 - $e]
	puts $f "$n $s $e $w"
	set radius [expr $radius - 10]
}


close $f
</script>

<script>
set f [open ~/Desktop/Spiral_Reset.txt w]
set angle 0
set radius 120.0
set pi 3.14159
while {$radius >= 0} {
	set n [expr round($radius * cos($angle)) + 133]
	set s [expr 255 - $n]
	set e [expr round($radius * sin($angle)) + 133]
	set w [expr 255 - $e]
	puts $f "$n $s $e $w"
	set radius [expr $radius - 5]
}


close $f
</script>

<script>
set f [open ~/Desktop/Spiral_Reset.txt w]
set angle 0
set radius 120.0
set pi 3.14159
while {$radius >= 0} {
	set n [expr 133 + round($radius * cos($angle))]
	set s [expr 133 - round($radius * cos($angle))]
	set e [expr 133 + round($radius * sin($angle))]
	set w [expr 133 - round($radius * sin($angle))]
	puts $f "$n $s $e $w"
	set radius [expr $radius - 5]
}


close $f
</script>

<script>
set f [open ~/Desktop/Spiral_Reset.txt w]
set angle 0
set radius 120.0
set pi 3.14159
while {$radius >= 0} {
	set n [expr 133 + round($radius * cos($angle))]
	set s [expr 133 - round($radius * cos($angle))]
	set e [expr 133 + round($radius * sin($angle))]
	set w [expr 133 - round($radius * sin($angle))]
	puts $f "$n $s $e $w"
	set radius [expr $radius - 5]
	set angle [expr $angle + ($pi / 8)
}


close $f
</script>

<script>
set f [open ~/Desktop/Spiral_Reset.txt w]
set angle 0
set radius 120.0
set pi 3.14159
while {$radius >= 0} {
	set n [expr 133 + round($radius * cos($angle))]
	set s [expr 133 - round($radius * cos($angle))]
	set e [expr 133 + round($radius * sin($angle))]
	set w [expr 133 - round($radius * sin($angle))]
	puts $f "$n $s $e $w"
	set radius [expr $radius - 5]
	set angle [expr $angle + ($pi / 8)]
}


close $f
</script>

<script>
set f [open ~/Desktop/Spiral_Reset.txt w]
set angle 0
set radius 120.0
set pi 3.14159
while {$radius >= 0} {
	set n [expr 133 + round($radius * cos($angle))]
	set s [expr 133 - round($radius * cos($angle))]
	set e [expr 133 + round($radius * sin($angle))]
	set w [expr 133 - round($radius * sin($angle))]
	puts $f "$n $s $e $w"
	set radius [expr $radius - 5]
	set angle [expr $angle + ($pi / 4)]
}


close $f
</script>

