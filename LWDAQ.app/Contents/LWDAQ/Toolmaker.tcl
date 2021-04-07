<script>
set instructions {nop        0x00   jp nn      0x01   jp nz,nn   0x02   jp z,nn    0x03   
jp nc,nn   0x04   jp c,nn    0x05   jp np,nn   0x06   jp p,nn    0x07   
call nn    0x08   int        0x09   ret        0x0A   rti        0x0B   
wait       0x0C   clri       0x0D   seti       0x0E   ld A,n     0x10   
ld IX,nn   0x11   ld IY,nn   0x12   ld HL,nn   0x13   ld A,(nn)  0x14   
ld (nn),A  0x15   ld A,(IX)  0x16   ld A,(IY)  0x17   ld (IX),A  0x18   
ld (IY),A  0x19   ld HL,SP   0x1A   ld SP,HL   0x1B   ld HL,PC   0x1C   
ld PC,HL   0x1D   push A     0x20   push B     0x21   push C     0x22   
push D     0x23   push E     0x24   push H     0x25   push L     0x26   
push F     0x27   push IX    0x28   push IY    0x29   pop A      0x30   
pop B      0x31   pop C      0x32   pop D      0x33   pop E      0x34   
pop H      0x35   pop L      0x36   pop F      0x37   pop IX     0x38   
pop IY     0x39   add A,B    0x40   add A,n    0x41   adc A,B    0x42   
adc A,n    0x43   sub A,B    0x44   sub A,n    0x45   sbc A,B    0x46   
sbc A,n    0x47   clrf       0x4F   inc A      0x50   inc B      0x51   
inc C      0x52   inc D      0x53   inc E      0x54   inc H      0x55   
inc L      0x56   inc SP     0x57   inc IX     0x59   inc IY     0x5A   
dec A      0x60   dec B      0x61   dec C      0x62   dec D      0x63   
dec E      0x64   dec H      0x65   dec L      0x66   dly A      0x67   
dec SP     0x68   dec IX     0x69   dec IY     0x6A   and A,B    0x70   
and A,n    0x71   or A,B     0x72   or A,n     0x73   xor A,B    0x74   
xor A,n    0x75   rl A       0x78   rlc A      0x79   rr A       0x7A   
rrc A      0x7B   sla A      0x7C   sra A      0x7D   srl A      0x7E}

foreach {p h} $instructions {
	LWDAQ_print $t "$p $h" brown
}
</script>

<script>
set instructions {nop        0x00   jp nn      0x01   jp nz,nn   0x02   jp z,nn    0x03   
jp nc,nn   0x04   jp c,nn    0x05   jp np,nn   0x06   jp p,nn    0x07   
call nn    0x08   int        0x09   ret        0x0A   rti        0x0B   
wait       0x0C   clri       0x0D   seti       0x0E   ld A,n     0x10   
ld IX,nn   0x11   ld IY,nn   0x12   ld HL,nn   0x13   ld A,(nn)  0x14   
ld (nn),A  0x15   ld A,(IX)  0x16   ld A,(IY)  0x17   ld (IX),A  0x18   
ld (IY),A  0x19   ld HL,SP   0x1A   ld SP,HL   0x1B   ld HL,PC   0x1C   
ld PC,HL   0x1D   push A     0x20   push B     0x21   push C     0x22   
push D     0x23   push E     0x24   push H     0x25   push L     0x26   
push F     0x27   push IX    0x28   push IY    0x29   pop A      0x30   
pop B      0x31   pop C      0x32   pop D      0x33   pop E      0x34   
pop H      0x35   pop L      0x36   pop F      0x37   pop IX     0x38   
pop IY     0x39   add A,B    0x40   add A,n    0x41   adc A,B    0x42   
adc A,n    0x43   sub A,B    0x44   sub A,n    0x45   sbc A,B    0x46   
sbc A,n    0x47   clrf       0x4F   inc A      0x50   inc B      0x51   
inc C      0x52   inc D      0x53   inc E      0x54   inc H      0x55   
inc L      0x56   inc SP     0x57   inc IX     0x59   inc IY     0x5A   
dec A      0x60   dec B      0x61   dec C      0x62   dec D      0x63   
dec E      0x64   dec H      0x65   dec L      0x66   dly A      0x67   
dec SP     0x68   dec IX     0x69   dec IY     0x6A   and A,B    0x70   
and A,n    0x71   or A,B     0x72   or A,n     0x73   xor A,B    0x74   
xor A,n    0x75   rl A       0x78   rlc A      0x79   rr A       0x7A   
rrc A      0x7B   sla A      0x7C   sra A      0x7D   srl A      0x7E}

foreach {p h} $instructions {
	LWDAQ_print $t "<p id=\"$p\"><b>$p\ ($h)</b> " brown
}
</script>

<script>
set instructions {
nop        0x00   jp nn      0x01   jp nz,nn   0x02   jp z,nn    0x03   
jp nc,nn   0x04   jp c,nn    0x05   jp np,nn   0x06   jp p,nn    0x07   
call nn    0x08   int        0x09   ret        0x0A   rti        0x0B   
wait       0x0C   clri       0x0D   seti       0x0E   ld A,n     0x10   
ld IX,nn   0x11   ld IY,nn   0x12   ld HL,nn   0x13   ld A,(nn)  0x14   
ld (nn),A  0x15   ld A,(IX)  0x16   ld A,(IY)  0x17   ld (IX),A  0x18   
ld (IY),A  0x19   ld HL,SP   0x1A   ld SP,HL   0x1B   ld HL,PC   0x1C   
ld PC,HL   0x1D   push A     0x20   push B     0x21   push C     0x22   
push D     0x23   push E     0x24   push H     0x25   push L     0x26   
push F     0x27   push IX    0x28   push IY    0x29   pop A      0x30   
pop B      0x31   pop C      0x32   pop D      0x33   pop E      0x34   
pop H      0x35   pop L      0x36   pop F      0x37   pop IX     0x38   
pop IY     0x39   add A,B    0x40   add A,n    0x41   adc A,B    0x42   
adc A,n    0x43   sub A,B    0x44   sub A,n    0x45   sbc A,B    0x46   
sbc A,n    0x47   clrf       0x4F   inc A      0x50   inc B      0x51   
inc C      0x52   inc D      0x53   inc E      0x54   inc H      0x55   
inc L      0x56   inc SP     0x57   inc IX     0x59   inc IY     0x5A   
dec A      0x60   dec B      0x61   dec C      0x62   dec D      0x63   
dec E      0x64   dec H      0x65   dec L      0x66   dly A      0x67   
dec SP     0x68   dec IX     0x69   dec IY     0x6A   and A,B    0x70   
and A,n    0x71   or A,B     0x72   or A,n     0x73   xor A,B    0x74   
xor A,n    0x75   rl A       0x78   rlc A      0x79   rr A       0x7A   
rrc A      0x7B   sla A      0x7C   sra A      0x7D   srl A      0x7E
}
set instructions [regsub {0x[0-9A-F]+} $instructions "\t"]
set instructions [split $instructions \t]

foreach {p} $instructions {
	LWDAQ_print $t "<p id=\"$p\"><b>$p</b> " brown
}
</script>

<script>
set instructions {
nop        0x00   jp nn      0x01   jp nz,nn   0x02   jp z,nn    0x03   
jp nc,nn   0x04   jp c,nn    0x05   jp np,nn   0x06   jp p,nn    0x07   
call nn    0x08   int        0x09   ret        0x0A   rti        0x0B   
wait       0x0C   clri       0x0D   seti       0x0E   ld A,n     0x10   
ld IX,nn   0x11   ld IY,nn   0x12   ld HL,nn   0x13   ld A,(nn)  0x14   
ld (nn),A  0x15   ld A,(IX)  0x16   ld A,(IY)  0x17   ld (IX),A  0x18   
ld (IY),A  0x19   ld HL,SP   0x1A   ld SP,HL   0x1B   ld HL,PC   0x1C   
ld PC,HL   0x1D   push A     0x20   push B     0x21   push C     0x22   
push D     0x23   push E     0x24   push H     0x25   push L     0x26   
push F     0x27   push IX    0x28   push IY    0x29   pop A      0x30   
pop B      0x31   pop C      0x32   pop D      0x33   pop E      0x34   
pop H      0x35   pop L      0x36   pop F      0x37   pop IX     0x38   
pop IY     0x39   add A,B    0x40   add A,n    0x41   adc A,B    0x42   
adc A,n    0x43   sub A,B    0x44   sub A,n    0x45   sbc A,B    0x46   
sbc A,n    0x47   clrf       0x4F   inc A      0x50   inc B      0x51   
inc C      0x52   inc D      0x53   inc E      0x54   inc H      0x55   
inc L      0x56   inc SP     0x57   inc IX     0x59   inc IY     0x5A   
dec A      0x60   dec B      0x61   dec C      0x62   dec D      0x63   
dec E      0x64   dec H      0x65   dec L      0x66   dly A      0x67   
dec SP     0x68   dec IX     0x69   dec IY     0x6A   and A,B    0x70   
and A,n    0x71   or A,B     0x72   or A,n     0x73   xor A,B    0x74   
xor A,n    0x75   rl A       0x78   rlc A      0x79   rr A       0x7A   
rrc A      0x7B   sla A      0x7C   sra A      0x7D   srl A      0x7E
}
set instructions [regsub {0x[0-9A-F]+} $instructions "\t"]
set instructions [split $instructions \t]

foreach {p} $instructions {
	LWDAQ_print $t "<p id=\"$p\"><b>$p</b> " brown
}
</script>

<script>
set instructions {
nop        0x00   jp nn      0x01   jp nz,nn   0x02   jp z,nn    0x03   
jp nc,nn   0x04   jp c,nn    0x05   jp np,nn   0x06   jp p,nn    0x07   
call nn    0x08   int        0x09   ret        0x0A   rti        0x0B   
wait       0x0C   clri       0x0D   seti       0x0E   ld A,n     0x10   
ld IX,nn   0x11   ld IY,nn   0x12   ld HL,nn   0x13   ld A,(nn)  0x14   
ld (nn),A  0x15   ld A,(IX)  0x16   ld A,(IY)  0x17   ld (IX),A  0x18   
ld (IY),A  0x19   ld HL,SP   0x1A   ld SP,HL   0x1B   ld HL,PC   0x1C   
ld PC,HL   0x1D   push A     0x20   push B     0x21   push C     0x22   
push D     0x23   push E     0x24   push H     0x25   push L     0x26   
push F     0x27   push IX    0x28   push IY    0x29   pop A      0x30   
pop B      0x31   pop C      0x32   pop D      0x33   pop E      0x34   
pop H      0x35   pop L      0x36   pop F      0x37   pop IX     0x38   
pop IY     0x39   add A,B    0x40   add A,n    0x41   adc A,B    0x42   
adc A,n    0x43   sub A,B    0x44   sub A,n    0x45   sbc A,B    0x46   
sbc A,n    0x47   clrf       0x4F   inc A      0x50   inc B      0x51   
inc C      0x52   inc D      0x53   inc E      0x54   inc H      0x55   
inc L      0x56   inc SP     0x57   inc IX     0x59   inc IY     0x5A   
dec A      0x60   dec B      0x61   dec C      0x62   dec D      0x63   
dec E      0x64   dec H      0x65   dec L      0x66   dly A      0x67   
dec SP     0x68   dec IX     0x69   dec IY     0x6A   and A,B    0x70   
and A,n    0x71   or A,B     0x72   or A,n     0x73   xor A,B    0x74   
xor A,n    0x75   rl A       0x78   rlc A      0x79   rr A       0x7A   
rrc A      0x7B   sla A      0x7C   sra A      0x7D   srl A      0x7E
}
set instructions [regsub -all {0x[0-9A-F]+} $instructions "\t"]
set instructions [split $instructions \t]

foreach {p} $instructions {
	LWDAQ_print $t "<p id=\"$p\"><b>$p</b> " brown
}
</script>

<script>
set instructions {
nop        0x00   jp nn      0x01   jp nz,nn   0x02   jp z,nn    0x03   
jp nc,nn   0x04   jp c,nn    0x05   jp np,nn   0x06   jp p,nn    0x07   
call nn    0x08   int        0x09   ret        0x0A   rti        0x0B   
wait       0x0C   clri       0x0D   seti       0x0E   ld A,n     0x10   
ld IX,nn   0x11   ld IY,nn   0x12   ld HL,nn   0x13   ld A,(nn)  0x14   
ld (nn),A  0x15   ld A,(IX)  0x16   ld A,(IY)  0x17   ld (IX),A  0x18   
ld (IY),A  0x19   ld HL,SP   0x1A   ld SP,HL   0x1B   ld HL,PC   0x1C   
ld PC,HL   0x1D   push A     0x20   push B     0x21   push C     0x22   
push D     0x23   push E     0x24   push H     0x25   push L     0x26   
push F     0x27   push IX    0x28   push IY    0x29   pop A      0x30   
pop B      0x31   pop C      0x32   pop D      0x33   pop E      0x34   
pop H      0x35   pop L      0x36   pop F      0x37   pop IX     0x38   
pop IY     0x39   add A,B    0x40   add A,n    0x41   adc A,B    0x42   
adc A,n    0x43   sub A,B    0x44   sub A,n    0x45   sbc A,B    0x46   
sbc A,n    0x47   clrf       0x4F   inc A      0x50   inc B      0x51   
inc C      0x52   inc D      0x53   inc E      0x54   inc H      0x55   
inc L      0x56   inc SP     0x57   inc IX     0x59   inc IY     0x5A   
dec A      0x60   dec B      0x61   dec C      0x62   dec D      0x63   
dec E      0x64   dec H      0x65   dec L      0x66   dly A      0x67   
dec SP     0x68   dec IX     0x69   dec IY     0x6A   and A,B    0x70   
and A,n    0x71   or A,B     0x72   or A,n     0x73   xor A,B    0x74   
xor A,n    0x75   rl A       0x78   rlc A      0x79   rr A       0x7A   
rrc A      0x7B   sla A      0x7C   sra A      0x7D   srl A      0x7E
}
set instructions [regsub -all {0x[0-9A-F]+} $instructions "\t"]
set instructions [split $instructions \t]

foreach {p} $instructions {
	set p [string trim $p]
	LWDAQ_print $t "<p id=\"$p\"><b>$p</b> " brown
}
</script>

<script>
set instructions {
nop        0x00   jp nn      0x01   jp nz,nn   0x02   jp z,nn    0x03   
jp nc,nn   0x04   jp c,nn    0x05   jp np,nn   0x06   jp p,nn    0x07   
call nn    0x08   int        0x09   ret        0x0A   rti        0x0B   
wait       0x0C   clri       0x0D   seti       0x0E   ld A,n     0x10   
ld IX,nn   0x11   ld IY,nn   0x12   ld HL,nn   0x13   ld A,(nn)  0x14   
ld (nn),A  0x15   ld A,(IX)  0x16   ld A,(IY)  0x17   ld (IX),A  0x18   
ld (IY),A  0x19   ld HL,SP   0x1A   ld SP,HL   0x1B   ld HL,PC   0x1C   
ld PC,HL   0x1D   push A     0x20   push B     0x21   push C     0x22   
push D     0x23   push E     0x24   push H     0x25   push L     0x26   
push F     0x27   push IX    0x28   push IY    0x29   pop A      0x30   
pop B      0x31   pop C      0x32   pop D      0x33   pop E      0x34   
pop H      0x35   pop L      0x36   pop F      0x37   pop IX     0x38   
pop IY     0x39   add A,B    0x40   add A,n    0x41   adc A,B    0x42   
adc A,n    0x43   sub A,B    0x44   sub A,n    0x45   sbc A,B    0x46   
sbc A,n    0x47   clrf       0x4F   inc A      0x50   inc B      0x51   
inc C      0x52   inc D      0x53   inc E      0x54   inc H      0x55   
inc L      0x56   inc SP     0x57   inc IX     0x59   inc IY     0x5A   
dec A      0x60   dec B      0x61   dec C      0x62   dec D      0x63   
dec E      0x64   dec H      0x65   dec L      0x66   dly A      0x67   
dec SP     0x68   dec IX     0x69   dec IY     0x6A   and A,B    0x70   
and A,n    0x71   or A,B     0x72   or A,n     0x73   xor A,B    0x74   
xor A,n    0x75   rl A       0x78   rlc A      0x79   rr A       0x7A   
rrc A      0x7B   sla A      0x7C   sra A      0x7D   srl A      0x7E
}
set instructions [regsub -all {0x[0-9A-F]+} [string trim $instructions] "\t"]
set instructions [split $instructions \t]

foreach {p} $instructions {
	set p [string trim $p]
	LWDAQ_print $t "<p id=\"$p\"><b>$p\:</b> </p>\n\n" brown
}
</script>

<script>
set instructions {
nop        0x00   jp nn      0x01   jp nz,nn   0x02   jp z,nn    0x03   
jp nc,nn   0x04   jp c,nn    0x05   jp np,nn   0x06   jp p,nn    0x07   
call nn    0x08   int        0x09   ret        0x0A   rti        0x0B   
wait       0x0C   clri       0x0D   seti       0x0E   ld A,n     0x10   
ld IX,nn   0x11   ld IY,nn   0x12   ld HL,nn   0x13   ld A,(nn)  0x14   
ld (nn),A  0x15   ld A,(IX)  0x16   ld A,(IY)  0x17   ld (IX),A  0x18   
ld (IY),A  0x19   ld HL,SP   0x1A   ld SP,HL   0x1B   ld HL,PC   0x1C   
ld PC,HL   0x1D   push A     0x20   push B     0x21   push C     0x22   
push D     0x23   push E     0x24   push H     0x25   push L     0x26   
push F     0x27   push IX    0x28   push IY    0x29   pop A      0x30   
pop B      0x31   pop C      0x32   pop D      0x33   pop E      0x34   
pop H      0x35   pop L      0x36   pop F      0x37   pop IX     0x38   
pop IY     0x39   add A,B    0x40   add A,n    0x41   adc A,B    0x42   
adc A,n    0x43   sub A,B    0x44   sub A,n    0x45   sbc A,B    0x46   
sbc A,n    0x47   clrf       0x4F   inc A      0x50   inc B      0x51   
inc C      0x52   inc D      0x53   inc E      0x54   inc H      0x55   
inc L      0x56   inc SP     0x57   inc IX     0x59   inc IY     0x5A   
dec A      0x60   dec B      0x61   dec C      0x62   dec D      0x63   
dec E      0x64   dec H      0x65   dec L      0x66   dly A      0x67   
dec SP     0x68   dec IX     0x69   dec IY     0x6A   and A,B    0x70   
and A,n    0x71   or A,B     0x72   or A,n     0x73   xor A,B    0x74   
xor A,n    0x75   rl A       0x78   rlc A      0x79   rr A       0x7A   
rrc A      0x7B   sla A      0x7C   sra A      0x7D   srl A      0x7E
}
set instructions [regsub -all {0x[0-9A-F]+} [string trim $instructions] "\t"]
set instructions [split $instructions \t]

foreach {p} $instructions {
	set p [string trim $p]
	LWDAQ_print $t "<p id=\"$p\"><b>$p\:</b> </p>\n"
}
</script>

<script>
foreach {i} $OSR8_Assembler_info(instructions) {
	set syntax [lindex $i 0]
	set opcode [lindex $i 1]
	LWDAQ_print $t "<td><a href=\"#$p\">$p</a></td><td>0x$opcode</td>"
}
</script>

<script>
foreach {i} $OSR8_Assembler_info(instructions) {
	set syntax [lindex $i 0]
	set opcode [lindex $i 1]
	LWDAQ_print $t "<td><a href=\"#$syntax\">$syntax</a></td><td>0x$opcode</td>"
}
</script>

<script>
set count 0
foreach {i} $OSR8_Assembler_info(instructions) {
	if {$count % 4 = 0} {LWDAQ_print -nonewline $t "<tr>"
	set syntax [lindex $i 0]
	set opcode [lindex $i 1]
	LWDAQ_print -nonewline $t "<td><a href=\"#$syntax\">$syntax</a></td><td>0x$opcode</td>"
	if {$count % 4 = 3} {LWDAQ_print $t "</tr>"
  incr count
}
</script>

<script>
set count 0
foreach {i} $OSR8_Assembler_info(instructions) {
	if {$count % 4 = 0} {LWDAQ_print -nonewline $t "<tr>"}
	set syntax [lindex $i 0]
	set opcode [lindex $i 1]
	LWDAQ_print -nonewline $t "<td><a href=\"#$syntax\">$syntax</a></td><td>0x$opcode</td>"
	if {$count % 4 = 3} {LWDAQ_print $t "</tr>"
  incr count
}
</script>

<script>
set count 0
foreach {i} $OSR8_Assembler_info(instructions) {
	if {$count % 4 = 0} {LWDAQ_print -nonewline $t "<tr>"}
	set syntax [lindex $i 0]
	set opcode [lindex $i 1]
	LWDAQ_print -nonewline $t "<td><a href=\"#$syntax\">$syntax</a></td><td>0x$opcode</td>"
	if {$count % 4 = 3} {LWDAQ_print $t "</tr>"}
  incr count
}
</script>

<script>
set count 0
foreach {i} $OSR8_Assembler_info(instructions) {
	if {$count % 4 == 0} {LWDAQ_print -nonewline $t "<tr>"}
	set syntax [lindex $i 0]
	set opcode [lindex $i 1]
	LWDAQ_print -nonewline $t "<td><a href=\"#$syntax\">$syntax</a></td><td>0x$opcode</td>"
	if {$count % 4 == 3} {LWDAQ_print $t "</tr>"}
  incr count
}
</script>

<script>
set count 0
foreach {i} $OSR8_Assembler_info(instructions) {
	if {$count % 4 = 0} {LWDAQ_print -nonewline $t "<tr>"}
	set syntax [lindex $i 0]
	set opcode [lindex $i 1]
	LWDAQ_print -nonewline $t "<td><a href=\"#$syntax\">$syntax</a></td><td>0x$opcode</td>"
	if {$count % 4 = 3} {LWDAQ_print $t "</tr>"}
  incr count
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 0] == $s} {
			lappend $sa [lindex $line 4]
		}
	}
}

for {set i 0} {$i <  [llength MA]} {incr i} {
	foreach sa {MA FL GA MN NY CA TX} {
		LWDAQ_print -nonewline $t [lindex $sa $i]
	}
	LWDAQ_print $t
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 0] == $sn} {
			lappend $sa [lindex $line 4]
		}
	}
}

for {set i 0} {$i <  [llength MA]} {incr i} {
	foreach sa {MA FL GA MN NY CA TX} {
		LWDAQ_print -nonewline $t [lindex $sa $i]
	}
	LWDAQ_print $t
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 0] == $sn} {
			lappend $sa [lindex $line 4]
		}
	}
}

for {set i 0} {$i <  [llength MA]} {incr i} {
	foreach sa {MA FL GA MN NY CA TX} {
		LWDAQ_print -nonewline $t [lindex [set $sa] $i]
	}
	LWDAQ_print $t
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 0] == $sn} {
			lappend $sa [lindex $line 4]
		}
	}
}

for {set i 0} {$i <  [llength [set MA]]} {incr i} {
	foreach sa {MA FL GA MN NY CA TX} {
		LWDAQ_print -nonewline $t "[lindex [set $sa] $i] "
	}
	LWDAQ_print $t
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" \
	SD "South Dakota" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 0] == $sn} {
			lappend $sa [lindex $line 4]
		}
	}
}

for {set i 0} {$i <  [llength [set MA]]} {incr i} {
	foreach sa {MA FL GA MN NY CA TX} {
		LWDAQ_print -nonewline $t "[lindex [set $sa] $i] "
	}
	LWDAQ_print $t
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" \
	SD "South Dakota" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 0] == $sn} {
			lappend $sa [lindex $line 4]
		}
	}
}

for {set i 0} {$i <  [llength [set MA]]} {incr i} {
	foreach sa {MA FL GA MN NY SD CA TX} {
		LWDAQ_print -nonewline $t "[lindex [set $sa] $i] "
	}
	LWDAQ_print $t
}
</script>

<script>
# Get the number of frames in a video.
set fnl [lsort -increasing [LWDAQ_get_file_name 1]]
foreach fn $fnl {
	catch {exec /usr/local/bin/ffmpeg -i $fn -c copy -f null -} result
	regexp {frame= *([0-9]+)} $result match numf
	LWDAQ_print $t "$fn $numf"
}
</script>

<script>
set fn [LWDAQ_get_file_name]
set f [open $fn r]
set contents [split [read $f] \n]
close $f

foreach {sa sn} {MA "Massachusetts" FL "Florida" GA "Georgia" \
	MN "Minnesota" NY "New York" CA "California" \
	SD "South Dakota" TX "Texas"} {
	set $sa [list]
	foreach line $contents {
		set line [split $line ","]
		if {[lindex $line 0] == $sn} {
			lappend $sa [lindex $line 4]
		}
	}
}

for {set i 0} {$i <  [llength [set MA]]} {incr i} {
	foreach sa {MA FL GA MN NY SD CA TX} {
		LWDAQ_print -nonewline $t "[lindex [set $sa] $i] "
	}
	LWDAQ_print $t
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
Nignog and Rikard lower a ladder made of conjured wood into the shaft. The conjured wood is transparent, but there are pieces of rock and grass embedded within it so that the sides and steps are visible, assuming you know what you are looking at. The ladder rests upon the bottom of the shaft and sticks two meters up in the air at the top. Nignog checks that the ladder is sitting well. He tightens his sword belt and ties his shield to his back. Upon his helmet is a luminous stone, held in place by invisible conjured matter.

Ping stands with a conjuring wand in her hand. She made the ladder. Zar placed the grass and stones in the conjured wood. He is an expert at this sort of thing. The grass and stones need to be placed on the surface of the wood, or else they weaken the structure. All four of the adventurers have their luminous stones, those made by the great Alfonso Bongo, fastened to their helmets.
}

set len [string length $passage]
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n > 0} { 
		LWDAQ_print -nonewline [lindex $encoded $n]	
  } else {
		LWDAQ_print -nonewline [lindex $passage $index]
  }
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
Nignog and Rikard lower a ladder made of conjured wood into the shaft. The conjured wood is transparent, but there are pieces of rock and grass embedded within it so that the sides and steps are visible, assuming you know what you are looking at. The ladder rests upon the bottom of the shaft and sticks two meters up in the air at the top. Nignog checks that the ladder is sitting well. He tightens his sword belt and ties his shield to his back. Upon his helmet is a luminous stone, held in place by invisible conjured matter.

Ping stands with a conjuring wand in her hand. She made the ladder. Zar placed the grass and stones in the conjured wood. He is an expert at this sort of thing. The grass and stones need to be placed on the surface of the wood, or else they weaken the structure. All four of the adventurers have their luminous stones, those made by the great Alfonso Bongo, fastened to their helmets.
}

set len [string length $passage]
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n > 0} { 
		LWDAQ_print -nonewline $t [lindex $encoded $n]	
  } else {
		LWDAQ_print -nonewline $t [lindex $passage $index]
  }
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
Nignog and Rikard lower a ladder made of conjured wood into the shaft. The conjured wood is transparent, but there are pieces of rock and grass embedded within it so that the sides and steps are visible, assuming you know what you are looking at. The ladder rests upon the bottom of the shaft and sticks two meters up in the air at the top. Nignog checks that the ladder is sitting well. He tightens his sword belt and ties his shield to his back. Upon his helmet is a luminous stone, held in place by invisible conjured matter.

Ping stands with a conjuring wand in her hand. She made the ladder. Zar placed the grass and stones in the conjured wood. He is an expert at this sort of thing. The grass and stones need to be placed on the surface of the wood, or else they weaken the structure. All four of the adventurers have their luminous stones, those made by the great Alfonso Bongo, fastened to their helmets.
}

set len [string length $passage]
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n > 0} { 
		LWDAQ_print -nonewline $t [lindex $encoded $n]	
  } else {
		LWDAQ_print -nonewline $t [lindex $passage $index]
  }
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
Nignog and Rikard lower a ladder made of conjured wood into the shaft. The conjured wood is transparent, but there are pieces of rock and grass embedded within it so that the sides and steps are visible, assuming you know what you are looking at. The ladder rests upon the bottom of the shaft and sticks two meters up in the air at the top. Nignog checks that the ladder is sitting well. He tightens his sword belt and ties his shield to his back. Upon his helmet is a luminous stone, held in place by invisible conjured matter.

Ping stands with a conjuring wand in her hand. She made the ladder. Zar placed the grass and stones in the conjured wood. He is an expert at this sort of thing. The grass and stones need to be placed on the surface of the wood, or else they weaken the structure. All four of the adventurers have their luminous stones, those made by the great Alfonso Bongo, fastened to their helmets.
}

set len [string length $passage]
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n >= 0} { 
		LWDAQ_print -nonewline $t [lindex $encoded $n]	
  } else {
		LWDAQ_print -nonewline $t [lindex $passage $index] purple
  }
	LWDAQ_update
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
On the very same day that Ping is sitting and talking with Throm Beausex in Machay, indeed: at almost exactly the same time, Zar sees a kobold poking around his camp. We call it a camp, but he calls it his house and garden. He lives in the forest in the Borderlands south of Caravel, five minutes walk from the center of Voisson Village. He did not buy the land. He just found a clearing, killed the bushes in it by burning them, and made a conjured shelter. You may be curious to know what he does for toilets and baths, but you'll have to ask him yourself, because we want to get on with the exciting part of the story, which is the kobold poking around in his camp.
}

set len [string length $passage]
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n >= 0} { 
		LWDAQ_print -nonewline $t [lindex $encoded $n]	
  } else {
		LWDAQ_print -nonewline $t [lindex $passage $index] purple
  }
	LWDAQ_update
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
On the very same day that Ping is sitting and talking with Throm Beausex in Machay, indeed: at almost exactly the same time, Zar sees a kobold poking around his camp. We call it a camp, but he calls it his house and garden. He lives in the forest in the Borderlands south of Caravel, five minutes walk from the center of Voisson Village. He did not buy the land. He just found a clearing, killed the bushes in it by burning them, and made a conjured shelter. You may be curious to know what he does for toilets and baths, but you'll have to ask him yourself, because we want to get on with the exciting part of the story, which is the kobold poking around in his camp.
}

set len [string length $passage]
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n >= 0} { 
		LWDAQ_print -nonewline $t [lindex $encoded $n]	
  } else {
		LWDAQ_print $t ""
  }
	LWDAQ_update
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
On the very same day that Ping is sitting and talking with Throm Beausex in Machay, indeed: at almost exactly the same time, Zar sees a kobold poking around his camp. We call it a camp, but he calls it his house and garden. He lives in the forest in the Borderlands south of Caravel, five minutes walk from the center of Voisson Village. He did not buy the land. He just found a clearing, killed the bushes in it by burning them, and made a conjured shelter. You may be curious to know what he does for toilets and baths, but you'll have to ask him yourself, because we want to get on with the exciting part of the story, which is the kobold poking around in his camp.
}

set len [string length $passage]
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n >= 0} { 
		LWDAQ_print -nonewline $t [lindex $encoded $n]	
  } else {
		LWDAQ_print -nonewline $t " "
  }
	LWDAQ_update
}
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
On the very same day that Ping is sitting and talking with Throm Beausex in Machay, indeed: at almost exactly the same time, Zar sees a kobold poking around his camp. We call it a camp, but he calls it his house and garden. He lives in the forest in the Borderlands south of Caravel, five minutes walk from the center of Voisson Village. He did not buy the land. He just found a clearing, killed the bushes in it by burning them, and made a conjured shelter. You may be curious to know what he does for toilets and baths, but you'll have to ask him yourself, because we want to get on with the exciting part of the story, which is the kobold poking around in his camp.
}

set len [string length $passage]
set translated ""
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n >= 0} { 
		 append translated [lindex $encoded $n]	
  } else {
		 append translated [string index $passage $index]
 	}
}
LWDAQ_print $t $translated
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
On the very same day that Ping is sitting and talking with Throm Beausex in Machay, indeed: at almost exactly the same time, Zar sees a kobold poking around his camp. We call it a camp, but he calls it his house and garden. He lives in the forest in the Borderlands south of Caravel, five minutes walk from the center of Voisson Village. He did not buy the land. He just found a clearing, killed the bushes in it by burning them, and made a conjured shelter. You may be curious to know what he does for toilets and baths, but you'll have to ask him yourself, because we want to get on with the exciting part of the story, which is the kobold poking around in his camp.
}

set len [string length $passage]
set translated ""
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n >= 0} { 
		 append translated [lindex $encoded $n]	
  } else {
		 append translated [string index $passage $index]
 	}
}
LWDAQ_print $t $translated
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
On the very same day that Ping is sitting and talking with Throm Beausex in Machay, indeed: at almost exactly the same time, Zar sees a kobold poking around his camp. We call it a camp, but he calls it his house and garden. He lives in the forest in the Borderlands south of Caravel, five minutes walk from the center of Voisson Village. He did not buy the land. He just found a clearing, killed the bushes in it by burning them, and made a conjured shelter. You may be curious to know what he does for toilets and baths, but you'll have to ask him yourself, because we want to get on with the exciting part of the story, which is the kobold poking around in his camp.
}

set len [string length $passage]
set translated ""
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n >= 0} { 
		 append translated [lindex $encoded $n]	
  } else {
		 append translated [string index $passage $index]
 	}
}
LWDAQ_print $t $translated
</script>

<script>
set alphabet "a b c d e f g h i j k l m n o p q r s t u v w x y z"
set remaining $alphabet
set encoded ""
foreach letter $alphabet {
	set N [llength $remaining]
	set index [expr round(rand()*($N-0.5))]
	if {$index < 0} {set index 0}
	if {$index > $N - 1} {set index [expr $N - 1]}
	lappend encoded [lindex $remaining $index]
	set remaining [lreplace $remaining $index $index]
}
for {set index 0} {$index < [llength $alphabet]} {incr index} {
	LWDAQ_print $t "[lindex $alphabet $index] [lindex $encoded $index]"
}
set passage {
On the very same day that Ping is sitting and talking with Throm Beausex in Machay, indeed: at almost exactly the same time, Zar sees a kobold poking around his camp. We call it a camp, but he calls it his house and garden. He lives in the forest in the Borderlands south of Caravel, five minutes walk from the center of Voisson Village. He did not buy the land. He just found a clearing, killed the bushes in it by burning them, and made a conjured shelter. You may be curious to know what he does for toilets and baths, but you'll have to ask him yourself, because we want to get on with the exciting part of the story, which is the kobold poking around in his camp.
}

set len [string length $passage]
set translated ""
for {set index 0} {$index < $len} {incr index} {
	set n [lsearch $alphabet [string tolower [string index $passage $index]]]
	if { $n >= 0} { 
		 append translated [lindex $encoded $n]	
  } else {
		 append translated [string index $passage $index]
 	}
}
LWDAQ_print $t $translated
</script>

