<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

foreach xy $contents {
	scan $xy %f%f x y
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

foreach xy $contents {
	scan $xy %f%f x y
	puts $f "$x $y"
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

foreach xy $contents {
	scan $xy %f%f x y
	puts $f "$x $y"
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
foreach xy $contents {
	scan $xy %f%f x y
	puts $f "$x $y $xx $yy"
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
foreach xy $contents {
	scan $xy %f%f x y
	set xx [format %.3f [expr 0.8 * $xx + 0.2 * $x]]
	set yy [format %.3f [expr 0.8 * $yy + 0.2 * $y]]
	puts $f "$x $y $xx $yy"
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

set sps 16
set st 0.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
foreach xy $contents {
	scan $xy %f%f x y
	set xx [format %.3f [expr 0.8 * $xx + 0.2 * $x]]
	set yy [format %.3f [expr 0.8 * $yy + 0.2 * $y]]
	puts $f "$st $x $y $xx $yy"
	set st [expr $st + 1.0/sps]
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

set sps 16
set st 0.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
foreach xy $contents {
	scan $xy %f%f x y
	set xx [format %.3f [expr 0.8 * $xx + 0.2 * $x]]
	set yy [format %.3f [expr 0.8 * $yy + 0.2 * $y]]
	puts $f "$st $x $y $xx $yy"
	set st [expr $st + 1.0/$sps]
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

set sps 16
set st 1100.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
foreach xy $contents {
	scan $xy %f%f x y
	set xx [format %.3f [expr 0.8 * $xx + 0.2 * $x]]
	set yy [format %.3f [expr 0.8 * $yy + 0.2 * $y]]
	puts $f "$st $x $y $xx $yy"
	set st [expr $st + 1.0/$sps]
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

set sps 16
set st 1100.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d_lpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr 0.8 * $d_lpf + 0.2 * $d]]
	puts $f "$st $d $d_lpf"
	set st [expr $st + 1.0/$sps]
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [string trim [read $f]] \n]
close $f

set f [open ~/Desktop/Outfile.txt w]

set sps 16
set st 1100.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d_lpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr 0.8 * $d_lpf + 0.2 * $d]]
	puts $f "$st $d $d_lpf"
	set st [expr $st + 1.0/$sps]
}

close $f
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d_lpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr 0.8 * $d_lpf + 0.2 * $d]]
	puts $outfile "$st $d $d_lpf"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr 0.8 * $d_lpf + 0.2 * $d]]
	set d_hpf [format %.3f [expr 0.8*$d - 0.8*$d1 + 0.2*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr 0.8 * $d_lpf + 0.2 * $d]]
	set d_hpf [format %.3f [expr 0.8*$d - 0.8*$d1 + 0.2*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr 0.8 * $d_lpf + 0.2 * $d]]
	set d_hpf [format %.3f [expr 0.6*$d - 0.6*$d1 + 0.6*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr 0.9 * $d_lpf + 0.1 * $d]]
	set d_hpf [format %.3f [expr 0.7*$d - 0.7*$d1 + 0.4*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set lpf_a0 0.1
set hpf_a0 0.6
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.1
set d_hpf 0.6
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr (1.0-$lpf_a0) * $d_lpf + $lpf_a0 * $d]]
	set d_hpf [format %.3f [expr $hpf_a0*$d - $hpf_a0*$d1 + (2*$hpf_a0-1)*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set lpf_a0 0.05
set hpf_a0 0.5
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.1
set d_hpf 0.6
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr (1.0-$lpf_a0) * $d_lpf + $lpf_a0 * $d]]
	set d_hpf [format %.3f [expr $hpf_a0*$d - $hpf_a0*$d1 + (2*$hpf_a0-1)*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set lpf_a0 0.01
set hpf_a0 0.5
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.1
set d_hpf 0.6
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr (1.0-$lpf_a0) * $d_lpf + $lpf_a0 * $d]]
	set d_hpf [format %.3f [expr $hpf_a0*$d - $hpf_a0*$d1 + (2*$hpf_a0-1)*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set lpf_a0 0.1
set hpf_a0 0.9
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr (1.0-$lpf_a0) * $d_lpf + $lpf_a0 * $d]]
	set d_hpf [format %.3f [expr $hpf_a0*$d - $hpf_a0*$d1 + (2*$hpf_a0-1)*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set lpf_a0 0.05
set hpf_a0 0.6
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr (1.0-$lpf_a0) * $d_lpf + $lpf_a0 * $d]]
	set d_hpf [format %.3f [expr $hpf_a0*$d - $hpf_a0*$d1 + (2*$hpf_a0-1)*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set lpf_a0 0.01
set hpf_a0 0.6
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr (1.0-$lpf_a0) * $d_lpf + $lpf_a0 * $d]]
	set d_hpf [format %.3f [expr $hpf_a0*$d - $hpf_a0*$d1 + (2*$hpf_a0-1)*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set lpf_a0 0.1
set hpf_a0 0.6
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr (1.0-$lpf_a0) * $d_lpf + $lpf_a0 * $d]]
	set d_hpf [format %.3f [expr $hpf_a0*$d - $hpf_a0*$d1 + (2*$hpf_a0-1)*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

<script>
set fn [LWDAQ_get_file_name]
set infile [open $fn r]
set contents [split [string trim [read $infile]] \n]
close $infile

set outfile [open ~/Desktop/Outfile.txt w]
set sps 16
set st 1100.0
set lpf_a0 0.03
set hpf_a0 0.6
set xx [lindex $contents 0 0]
set yy [lindex $contents 0 1]
set d 0.0
set d_lpf 0.0
set d_hpf 0.0
foreach xy $contents {
	scan $xy %f%f x y
	set d1 $d
	set d [format %.3f [expr sqrt(($x-$xx)*($x-$xx)+($y-$yy)*($y-$yy))]]
	set xx $x
	set yy $y
	set d_lpf [format %.3f [expr (1.0-$lpf_a0) * $d_lpf + $lpf_a0 * $d]]
	set d_hpf [format %.3f [expr $hpf_a0*$d - $hpf_a0*$d1 + (2*$hpf_a0-1)*$d_hpf]]
	puts $outfile "$st $d $d_lpf $d_hpf [expr abs($d_hpf)]"
	set st [expr $st + 1.0/$sps]
}

close $outfile
</script>

