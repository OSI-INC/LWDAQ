<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for $fn..."
</script>

<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for $dfn..."
</script>

<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for [file tail $dfn]."
set f [file open $dfn r]
set contents [read $f]
close $f
LWDAQ_print $t "Read contents of [file tail $dfn]."
set contents [regsub -all "%P" $contents $LWDAQ_Info(program_dir)]
LWDAQ_print $t $contents
</script>

<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for [file tail $dfn]."
set f [open $dfn r]
set contents [read $f]
close $f
LWDAQ_print $t "Read contents of [file tail $dfn]."
set contents [regsub -all "%P" $contents $LWDAQ_Info(program_dir)]
LWDAQ_print $t $contents
</script>

<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for [file tail $dfn]." purple
set f [open $dfn r]
set contents [read $f]
close $f
LWDAQ_print $t "Read contents of [file tail $dfn]." purple
LWDAQ_print $t "Configuring desktop file for local installation." purple
set contents [regsub -all "%P" $contents $LWDAQ_Info(program_dir)]
LWDAQ_print $t $contents
LWDAQ_print $t "Writing desktop file to ~/Desktop."
set f [open ~/Desktop/lwdaq.desktop w]
puts $f $contents
close $f
</script>

<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for [file tail $dfn]." purple
set f [open $dfn r]
set contents [read $f]
close $f
LWDAQ_print $t "Read contents of [file tail $dfn]." purple
LWDAQ_print $t "Configuring desktop file for local installation." purple
set contents [regsub -all "%P" $contents $LWDAQ_Info(program_dir)]
set contents [string trim $contents]
LWDAQ_print $t $contents
LWDAQ_print $t "Writing desktop file to ~/Desktop."
set f [open ~/Desktop/lwdaq.desktop w]
puts $f $contents
close $f
</script>

<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for [file tail $dfn]." purple
set f [open $dfn r]
set contents [read $f]
close $f
LWDAQ_print $t "Read contents of [file tail $dfn]." purple
LWDAQ_print $t "Configuring desktop file for local installation." purple
set contents [regsub -all "%P" $contents $LWDAQ_Info(program_dir)]
set contents [string trim $contents]
LWDAQ_print $t $contents
LWDAQ_print $t "Writing desktop file to ~/Desktop." purple
set f [open ~/Desktop/lwdaq.desktop w]
puts $f $contents
close $f
LWDAQ_print $t "Installing desktop file in desktop database." purple
exec "sudo desktop-file-install ~/Desktop/lwdaq.desktop"
</script>

<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for [file tail $dfn]." purple
set f [open $dfn r]
set contents [read $f]
close $f
LWDAQ_print $t "Read contents of [file tail $dfn]." purple
LWDAQ_print $t "Configuring desktop file for local installation." purple
set contents [regsub -all "%P" $contents $LWDAQ_Info(program_dir)]
set contents [string trim $contents]
LWDAQ_print $t $contents
set dfn ~/Desktop/lwdaq.desktop
LWDAQ_print $t "Writing desktop file to $dfn" purple
set f [open $dfn w]
puts $f $contents
close $f
LWDAQ_print $t "Installing desktop file in database." purple
exec "sudo desktop-file-install $dfn"
</script>

<script>
set dfn [file join $LWDAQ_Info(program_dir) LWDAQ.app Contents Linux lwdaq.desktop]
LWDAQ_print $t "Looking for [file tail $dfn]." purple
set f [open $dfn r]
set contents [read $f]
close $f
LWDAQ_print $t "Read contents of [file tail $dfn]." purple
LWDAQ_print $t "Configuring desktop file for local installation." purple
set contents [regsub -all "%P" $contents $LWDAQ_Info(program_dir)]
set contents [string trim $contents]
LWDAQ_print $t $contents
set dfn [file normalize ~/Desktop/lwdaq.desktop]
LWDAQ_print $t "Writing desktop file to $dfn" purple
set f [open $dfn w]
puts $f $contents
close $f
LWDAQ_print $t "Installing desktop file in database." purple
exec "sudo desktop-file-install $dfn"
</script>

