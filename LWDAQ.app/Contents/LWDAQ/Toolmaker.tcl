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

