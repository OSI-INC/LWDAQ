<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq"]
while {[gets $ch line] > 0} {LWDAQ_print $t $line}

close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq &"]
while {[gets $ch line] > 0} {LWDAQ_print $t $line}

close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq" w]
while {[gets $ch line] > 0} {LWDAQ_print $t $line}

close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq" rw]
while {[gets $ch line] > 0} {LWDAQ_print $t $line}

close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq" r+]
while {[gets $ch line] > 0} {LWDAQ_print $t $line}

close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui &" r+]
while {[gets $ch line] > 0} {LWDAQ_print $t $line}

close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui" r+]
LWDAQ_print $ch
#while {[gets $ch line] > 0} {LWDAQ_print $t $line}

close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui" r+]
LWDAQ_print $ch
#while {[gets $ch line] > 0} {LWDAQ_print $t $line}

#close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui" r+]
LWDAQ_print $t $ch
#while {[gets $ch line] > 0} {LWDAQ_print $t $line}
#close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui" r+]
fconfigure $ch -buffering line -blocking 0
LWDAQ_print $t $ch
#while {[gets $ch line] > 0} {LWDAQ_print $t $line}
#close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui" w+]
fconfigure $ch -buffering line -blocking 0
LWDAQ_print $t $ch
#while {[gets $ch line] > 0} {LWDAQ_print $t $line}
#close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui"]
fconfigure $ch -buffering line -blocking 0
LWDAQ_print $t $ch
while {[gets $ch line] > 0} {LWDAQ_print $t $line}
#close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui"]
fconfigure $ch -buffering line -blocking 0
LWDAQ_print $t $ch
LWDAQ_delay_ms 1000
while {[gets $ch line] > 0} {LWDAQ_print $t $line}
#close $ch
</script>

<script>
cd $LWDAQ_Info(program_dir)
set ch [open "| ./lwdaq --gui"]
fconfigure $ch -buffering line -blocking 0
LWDAQ_print $t $ch
LWDAQ_wait_ms 1000
while {[gets $ch line] > 0} {LWDAQ_print $t $line}
#close $ch
</script>

