# Open-Source Reconfigurable Eight-Bit Central Porocessing Unit 
# Assembler and Dis-Assembler, a LWDAQ Tool.
#
# A LWDAQ Tool that converts text Open-Source, Reconfigurable,
# Eight-Bit Central Processing Unit (OSR8 CPU) assembler source code
# into text hexadecimal machine code for use by a firmware compiler such
# as the Lattice Diamond VHDL compiler.
#
# Copyright (C) 2020 Kevan Hashemi, Open Source Instruments Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


proc OSR8Asm_init {} {
	upvar #0 OSR8Asm_info info
	upvar #0 OSR8Asm_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "OSR8Asm" "1.1"
	if {[winfo exists $info(window)]} {
		raise $info(window)
		return "SUCCESS"
	}
	
	set config(ifn) "~/Desktop/Program.asm"
	set config(ofn) "~/Desktop/Program.mem"
	set info(ifn_ew) $info(window).iew
	set info(ofn_ew) $info(window).oew
	
	set config(opcode_color) "brown"
	set config(syntax_color) "green"
	
	set config(base_address) "0"
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	set data [string trim [LWDAQ_tool_data $info(name)]]
	set data [split $data \n]
	set info(instructions) [list]
	foreach d $data {
		if {[regexp {16#([0-9A-Fa-f]*)[^-]*-- *(.*)} $d dummy opcode syntax]} {
			lappend info(instructions) [list $syntax $opcode]
		}
	}	
	
	set info(error_list) [list]
	set info(warning_list) [list]
	set info(symbol_list) [list]
	set info(label_list) [list]
	
	return "SUCCESS"
}

proc OSR8Asm_pick {a} {
	upvar #0 OSR8Asm_config config
	upvar #0 OSR8Asm_info info

	set fn ""
	switch $a {
		"ifn" {set fn [LWDAQ_get_file_name]}
		"ofn" {set fn [LWDAQ_put_file_name Program.mem]}
	}
	if {$fn != ""} {
		set config($a) $fn
	} else {
		return "ABORT"
	}
	
	return "SUCCESS"
}

proc OSR8Asm_edit {a} {
	upvar #0 OSR8Asm_config config
	upvar #0 OSR8Asm_info info

	if {[winfo exists $info($a\_ew)]} {
		raise $info($a\_ew)
		return "SUCCESS"
	} else {
		set info($a\_ew) [LWDAQ_edit_script Open $config($a)]
	}
}

proc OSR8Asm_instructions {} {
	upvar #0 OSR8Asm_config config
	upvar #0 OSR8Asm_info info

	LWDAQ_print $info(text) "OSR8 Operation Codes and Instruction Syntax" purple
	LWDAQ_print $info(text) "n = eight-bit number, nn = sixteen-bit number" purple
	LWDAQ_print $info(text) "(nn) = value pointed to by address nn" purple
	LWDAQ_print $info(text) "(IX) = value pointed to by register IX" purple

	set index 0
	foreach i $info(instructions) {
		LWDAQ_print -nonewline $info(text) \
			"[format %-10s [lindex $i 0]] " $config(syntax_color)
		LWDAQ_print -nonewline $info(text) \
			"0x[lindex $i 1]   " $config(opcode_color)
		incr index
		if {$index % 4 == 0} {LWDAQ_print $info(text)}
		LWDAQ_support
	}
	if {$index % 4 != 0} {LWDAQ_print $info(text)}
	
	LWDAQ_print $info(text) "Number of Available Instructions\
		= [llength $info(instructions)].\n" purple
}

proc OSR8Asm_find_symbol {line} {
	upvar #0 OSR8Asm_config config
	upvar #0 OSR8Asm_info info

	if {[regexp -nocase {^\s*const\s*([\w]*)\s*([\w]*)} $line dummy symbol value]} {
		if {[regexp -nocase {^0x[0-9A-F]+$} $value]} {
			set value [expr $value]
		} elseif {[regexp {^[0-9]+$} $value]} {
			set value $value
		} else {
			return "ERROR: Bad value \"$value\" for \"$symbol\""
		}
		return [list $symbol $value]
	} else {
		return ""
	}
}

proc OSR8Asm_assemble {{asm  ""}} {
	upvar #0 OSR8Asm_config config
	upvar #0 OSR8Asm_info info

	LWDAQ_print $info(text) "Open-Source Reconfigurable\
		Eight-Bit CPU Assembler-Dissembler" purple
	LWDAQ_print $info(text) "(C) 2020 Kevan Hashemi,\
		Open Source Instruments Inc." purple	
	if {$asm == ""} {
		if {[file exists $config(ifn)]} {
			set f [open $config(ifn) r]
			set asm [split [read $f] \n]
			close $f
			LWDAQ_print $info(text) "Read assembler code from $config(ifn)."
		} else {
			LWDAQ_print $info(text) "ERROR: Cannot find $config(ifn)."
			return "FAIL"
		}
	} else {
		LWDAQ_print $info(text) "Received assembler code in string."
	}
	
	set info(error_list) [list]
	set info(warning_list) [list]
	set info(symbol_list) [list]
	LWDAQ_print $info(text) "Found [llength $asm] lines of code in source file."

	# Eliminate comments and make list of lines.
	set basm [list]
	foreach line $asm {
		set line [regsub {;.*} $line ""]
		set line [regsub { *, *} $line " "]
		set line [regsub -all {([\s]+)} $line { }]
		set line [string trim $line]
		lappend basm $line
	}	
	
	# Go through lines finding instructions.
	set mem ""
	set symbols [list]
	set line_index 0
	set num_errors 0
	foreach line $basm {
		incr line_index
		set match 0
		set code ""
		foreach inst $info(instructions) {
		
			# Set up instruction code in code and replace comma in prototype.
			set prototype [regsub {,} [lindex $inst 0] " "]
			set code "[lindex $inst 1] "
			
			# The line and instruction must have the same number of elements,
			# up to opcode, operand one, and operand two.
			if {[llength $line] != [llength $prototype]} {continue}
			
			# Their opcodes must match.
			if {![regexp -nocase [lindex $line 0] [lindex $prototype 0]]} {continue}

			# If there are no operands, we have found a match.
			if {[llength $prototype] == 1} {
				set match 1
				append mem $code
				break
			} 
			
			# Compare the first operands.
			set fo_match 0
			set po1 [lindex $prototype 1]
			set lo1 [lindex $line 1]
			if {[string match -nocase $po1 $lo1]} {
				set fo_match 1
			} elseif {$po1 == "(nn)"} {
				if {[regexp {^\(([\w]+)\)$} $lo1 dummy v]} {
					if {[regexp -nocase {^0x[0-9A-F]+$} $v]} {
						set value [format %04X [expr $v]]
						append code "[string range $value 0 1] "
						append code "[string range $value 2 3] "
						set fo_match 1
					} elseif {[regexp {^[0-9]+$} $v]} {
						set value [format %04X [expr $v]]
						append code "[string range $value 0 1] "
						append code "[string range $value 2 3] "
						set fo_match 1
					} else {
						foreach c $info(symbol_list) {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {[regexp -nocase $v $s]} {
								set value [format %04X $sv]
								append code "[string range $value 0 1] "
								append code "[string range $value 2 3] "
								set fo_match 1
							}
						}
						if {!$fo_match} {
							append code "$v "
							set fo_match 1
						}
					}
				}
			} elseif {$po1 == "nn"} {
				if {[regexp {^([\w]+)$} $lo1 dummy v]} {
					if {[regexp -nocase {^0x[0-9A-F]+$} $v]} {
						set value [format %04X [expr $v]]
						append code "[string range $value 0 1] "
						append code "[string range $value 2 3] "
						set fo_match 1
					} elseif {[regexp {^[0-9]+$} $v]} {
						set value [format %04X [expr $v]]
						append code "[string range $value 0 1] "
						append code "[string range $value 2 3] "
						set fo_match 1
					} else {
						foreach c $info(symbol_list) {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {[regexp -nocase $v $s]} {
								set value [format %04X $sv]
								append code "[string range $value 0 1] "
								append code "[string range $value 2 3] "
								set fo_match 1
							}
						}
						if {!$fo_match} {
							append code "$v "
							set fo_match 1
						}
					}
				}
			} elseif {$po1 == "n"} {
				if {[regexp {^([\w]+)$} $lo1 dummy v]} {
					if {[regexp -nocase {^0x[0-9A-F]+$} $v]} {
						set value [format %02X [expr $v]]
						append code "$value "
						set fo_match 1
					} elseif {[regexp {^[0-9]+$} $v]} {
						set value [format %02X [expr $v]]
						append code "$value "
						set fo_match 1
					} else {
						foreach c $info(symbol_list) {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {[regexp -nocase $v $s]} {
								set value [format %02X $sv]
								append code "$value "
								set fo_match 1
							}
						}
					}
				}
			} 
			
			# If the first operands don't match, continue to the next prototype
			# instruction.
			if {!$fo_match} {continue}
			
			# If there is only one operand, we are done.
			if {[llength $prototype] == 2} {
				set match 1
				append mem $code
				break
			}

			# Compare the first operands.
			set so_match 0
			set po2 [lindex $prototype 2]
			set lo2 [lindex $line 2]
			if {[string match -nocase $po2 $lo2]} {
				set so_match 1
			} elseif {$po2 == "(nn)"} {
				if {[regexp {^\(([\w]+)\)$} $lo2 dummy v]} {
					if {[regexp -nocase {^0x[0-9A-F]+$} $v]} {
						set value [format %04X [expr $v]]
						append code "[string range $value 0 1] "
						append code "[string range $value 2 3] "
						set so_match 1
					} elseif {[regexp {^[0-9]+$} $v]} {
						set value [format %04X [expr $v]]
						append code "[string range $value 0 1] "
						append code "[string range $value 2 3] "
						set so_match 1
					} else {
						foreach c $info(symbol_list) {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {[regexp -nocase $v $s]} {
								set value [format %04X $sv]
								append code "[string range $value 0 1] "
								append code "[string range $value 2 3] "
								set so_match 1
							}
						}
						if {!$so_match} {
							append code "$v "
							set so_match 1
						}
					}
				}
			} elseif {$po2 == "nn"} {
				if {[regexp {^([\w]+)$} $lo2 dummy v]} {
					if {[regexp -nocase {^0x[0-9A-F]+$} $v]} {
						set value [format %04X [expr $v]]
						append code "[string range $value 0 1] "
						append code "[string range $value 2 3] "
						set so_match 1
					} elseif {[regexp {^[0-9]+$} $v]} {
						set value [format %04X [expr $v]]
						append code "[string range $value 0 1] "
						append code "[string range $value 2 3] "
						set so_match 1
					} else {
						foreach c $info(symbol_list) {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {[regexp -nocase $v $s]} {
								set value [format %04X $sv]
								append code "[string range $value 0 1] "
								append code "[string range $value 2 3] "
								set so_match 1
							}
						}
						if {!$so_match} {
							append code "$v "
							set so_match 1
						}
					}
				}
			} elseif {$po2 == "n"} {
				if {[regexp {^([\w]+)$} $lo2 dummy v]} {
					if {[regexp -nocase {^0x[0-9A-F]+$} $v]} {
						set value [format %02X [expr $v]]
						append code "$value "
						set so_match 1
					} elseif {[regexp {^[0-9]+$} $v]} {
						set value [format %02X $v]
						append code "$value "
						set so_match 1
					} else {
						foreach c $info(symbol_list) {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {[regexp -nocase $v $s]} {
								set value [format %02X $sv]
								append code "$value "
								set so_match 1
							}
						}
					}
				}
			} 
			
			# If the second operands don't match, continue to the next prototype
			# instruction.
			if {!$so_match} {continue}
			
			# Otherwise we are done.
			set match 1
			append mem $code
			break
		}
		
		# If we matched the instruction, print out the line number, prototype
		# instruction that we matched to, and the machine code. Then continue to
		# the next line.
		if {$match} {
			LWDAQ_print -nonewline $info(text) "[format %3d $line_index]: " 
			LWDAQ_print -nonewline $info(text) \
				"[format %-16s $prototype] " $config(syntax_color)
			LWDAQ_print $info(text) $code $config(opcode_color)
			continue
		}
		
		# See if this is a symbol definition line.
		set sym_val [OSR8Asm_find_symbol $line] 
		if {[LWDAQ_is_error_result $sym_val]} {
			incr num_errors
			LWDAQ_print $info(text) "$sym_val in line $line_index\."
			continue
		} elseif {$sym_val != ""} {
			set match 1
			lappend info(symbol_list) $sym_val
			set sym [lindex $sym_val 0]
			set val [lindex $sym_val 1]
			LWDAQ_print -nonewline $info(text) "[format %3d $line_index]: " 
			LWDAQ_print -nonewline $info(text) \
				"[format %-16s $sym] " $config(syntax_color)
			LWDAQ_print $info(text) \
				"[format %-5d $val] 0x[format %04X $val]" $config(opcode_color)
			continue
		} 
		
		# See if this is a label line.
		if {[regexp {^\w+:$} $line lbl]} {
			set match 1
			append mem "$lbl "
			LWDAQ_print $info(text) $lbl 
			continue
		}
		
		# Any other characters are an error.
		if {[regexp {\w+} $line dummy]} {
			incr num_errors
			LWDAQ_print $info(text) "ERROR: Unrecognised \"$line\" at line $line_index\."
			set match 0
			continue
		}
	}
	
	# Now we resolve the label values. Each element of the memory dump is now
	# either a byte, which counts as one address, or a label with no colon,
	# which counts as two, because we are going to replace it with two bytes
	# wherever it appears in the code, or a label with a colon, which counts as
	# nothing because it's just a marker. But when we come to the marker, we add
	# it to the symbol list.
	set addr $config(base_address)
	set info(label_list) [list]
	set new_mem ""
	foreach m $mem {
		if {[regexp -nocase {^[0-9A-F]+$} $m]} {
			incr addr
			lappend new_mem $m
		} elseif {[regexp {^(\w+)$} $m dummy lbl]} {
			incr addr
			incr addr
			lappend new_mem $m
		} elseif {[regexp {^(\w+):$} $m dummy lbl]} {
				set val "[format %02X [expr $addr / 256]]\
					[format %02X [expr $addr % 256]] "
				lappend info(label_list) [list $lbl $val]	
				LWDAQ_print $info(text) "$lbl\: 0x[format %04X $addr]"
		} else {
			LWDAQ_print $info(text) "ERROR: Bad symbol \"$m\" in object code."
			incr num_errors
			lappend new_mem $m
		}
	}
	set mem $new_mem
	
	# Replace labels with their address values.
	foreach lbl $info(label_list) {
		set symbol [lindex $lbl 0]
		set value [lindex $lbl 1]
		set mem [regsub -all $symbol $mem $value]
	}
	
	# Go through the object code and write bytes to output file.
	if {$num_errors == 0} {
		LWDAQ_print $info(text) "Openikng output file $config(ofn)." purple
		LWDAQ_print $info(text) "Machine code bytes as written to output:" purple
		set f [open $config(ofn) w]
		set index 0
		foreach m $mem {
			puts $f $m
			incr index
			LWDAQ_print -nonewline $info(text) "$m "
			if {$index % 30 == 0} {LWDAQ_print $info(text)}
		}
		close $f
		if {$index % 30 != 0} {LWDAQ_print $info(text)}
		LWDAQ_print $info(text) "Wrote [llength $mem] hex bytes to output file." purple
	} else {
		LWDAQ_print $info(text) "Aborted assembly due to $num_errors errors."
	}
	
	LWDAQ_print $info(text) "Done.\n" purple
	return $mem
}

proc OSR8Asm_disassemble {{mem  ""}} {
	upvar #0 OSR8Asm_config config
	upvar #0 OSR8Asm_info info

	LWDAQ_print $info(text) "Open-Source Reconfigurable Eight-Bit\
		CPU Dis-Assembler" purple
	LWDAQ_print $info(text) "(c) 2020 Kevan Hashemi, Open Source\
		Instruments Inc." purple	
	if {$mem == ""} {
		if {[file exists $config(ofn)]} {
			set f [open $config(ofn) r]
			set mem [string trim [read $f]]
			close $f
			LWDAQ_print $info(text) "Read object code from $config(ofn)."
		} else {
			LWDAQ_print $info(text) "ERROR: Cannot find file $config(ofn)."
			return "FAIL"
		}
	}
	
	set mem [split $mem \n]
	set asm ""
	LWDAQ_print $info(text) "Output will be written to text window." 
	LWDAQ_print $info(text) "Dis-assembling [llength $mem] bytes of object code."
	LWDAQ_print $info(text) "$asm"
	LWDAQ_print $info(text) "Done.\n" purple
	return $asm
}

proc OSR8Asm_open {} {
	upvar #0 OSR8Asm_config config
	upvar #0 OSR8Asm_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return 0}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	foreach a {Assemble Disassemble Instructions} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post OSR8Asm_$b"
		pack $f.$b -side left -expand 1
		
	} 
	
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}

	foreach {a b} {ifn Infile ofn Outfile} {
		set f $w.[set a]
		frame $f
		pack $f -side top -fill x
	
		label $f.[set a]l -text "$b File:" 
		entry $f.[set a]e -textvariable OSR8Asm_config([set a]) -width 50
		button $f.[set a]p -text "Pick" -command "OSR8Asm_pick $a"
		button $f.[set a]ed -text "Edit" -command "OSR8Asm_edit $a"
		pack $f.[set a]l $f.[set a]e $f.[set a]p $f.[set a]ed -side left -expand 1
	}
	
	set info(text) [LWDAQ_text_widget $w 100 15]

	LWDAQ_print $info(text) "$info(name) Version $info(version) \n"	
	
	return "SUCCESS"
}

OSR8Asm_init
OSR8Asm_open
	
return 1

----------Begin Help----------

Each instruction is presented on a single line of assembly code. The first word
in an instruction line is the operation code, or "opcode". After that come one
or more operands separated by commas, with parenthesis used to indicate that an
operand should be used as an address. On any line, every character after a
semicolon is a comment and will be ignored by the assembler. The language is
insensitive to case, so you may use lower-case or upper-case letters as you
like. The following line specifies the eight-bit indirect load of the
accumulator from address 0x1702.
	
ld A,(0x1702) ; Load A with HI sensor byte.

To specify a jump point, or "labeel", use any string containing letter and
underscores followed immediately by a colon, and place this named marker just
before the location you wish to label. The jump point must be alone on its
declaration line. When we later mention the jump location variable, we do not
include the colon.

loop:        ; We can put a comment here too
dec A        ; Decrement the accumulator
jp nz,loop   ; Jump to loop if accumulator is not zero

Jump points are global constants that can be declared anywhere and 
referred top anywhere. So we can refer to a jump point in an instruction before
we declare it.

dec l       ; Decrement register L
jp nz,notz  ; If L is not zero, jump over the decrement of H
dec h       ; Decrement register H
notz:       ; This is where we declare the label "notz"
adc A,56    ; Add 56 decimal to the accumulator, with carry.

Empty lines, or lines with only comments, are ignored by the assembler, although
they are counted, so that warning and error messages will be able to refer to
the correct line number. To declare a constant use the following notation.

const sensor_hi 0x1702 ; Define sensor_hi to be value 1702 hexadecimal.
const step_size 34     ; Replace "step_size" with 34 decimal.
ld A,step_size         ; Load step-size constant into the accumulator
ld (sensor_hi),A       ; Load byte location sensor_hi with accumulator.

Kevan Hashemi hashemi@opensourcesintruments.com
----------End Help----------

----------Begin Data----------

	constant nop : integer := 16#00#;      -- nop
		
	constant ld_HL_SP : integer := 16#01#; -- ld hl,sp
	constant ld_SP_HL : integer := 16#02#; -- ld sp,hl
	constant ld_HL_PC : integer := 16#03#; -- ld hl,pc
	constant ld_PC_HL : integer := 16#04#; -- ld pc,hl
			
	constant ld_A_n   : integer := 16#10#; -- ld A,n
	constant ld_IX_nn : integer := 16#11#; -- ld IX,nn
	constant ld_IY_nn : integer := 16#12#; -- ld IY,nn
	constant ld_A_mm  : integer := 16#13#; -- ld A,(nn)
	constant ld_mm_A  : integer := 16#14#; -- ld (nn),A
	constant ld_A_ix  : integer := 16#15#; -- ld A,(IX)
	constant ld_A_iy  : integer := 16#16#; -- ld A,(IY)
	constant ld_ix_A  : integer := 16#17#; -- ld (IX),A
	constant ld_iy_A  : integer := 16#18#; -- ld (IY),A
	
	constant push_A  : integer := 16#20#;  -- push A
	constant push_B  : integer := 16#21#;  -- push B
	constant push_C  : integer := 16#22#;  -- push C
	constant push_D  : integer := 16#23#;  -- push D
	constant push_E  : integer := 16#24#;  -- push E
	constant push_H  : integer := 16#25#;  -- push H
	constant push_L  : integer := 16#26#;  -- push L
	constant push_F  : integer := 16#27#;  -- push F
	constant push_IX : integer := 16#28#;  -- push IX
	constant push_IY : integer := 16#29#;  -- push IY
	
	constant pop_A  : integer := 16#30#;   -- pop A
	constant pop_B  : integer := 16#31#;   -- pop B
	constant pop_C  : integer := 16#32#;   -- pop C
	constant pop_D  : integer := 16#33#;   -- pop D
	constant pop_E  : integer := 16#34#;   -- pop E
	constant pop_H  : integer := 16#35#;   -- pop H
	constant pop_L  : integer := 16#36#;   -- pop L
	constant pop_F  : integer := 16#37#;   -- pop F
	constant pop_IX : integer := 16#38#;   -- pop IX
	constant pop_IY : integer := 16#39#;   -- pop IY

	constant add_A_B : integer := 16#40#;  -- add A,B
	constant add_A_n : integer := 16#41#;  -- add A,n
	constant adc_A_B : integer := 16#42#;  -- adc A,B
	constant adc_A_n : integer := 16#43#;  -- adc A,n
	constant sub_A_B : integer := 16#44#;  -- sub A,B
	constant sub_A_n : integer := 16#45#;  -- sub A,n
	constant sbc_A_B : integer := 16#46#;  -- sbc A,B
	constant sbc_A_n : integer := 16#47#;  -- sbc A,n
	
	constant inc_A : integer := 16#50#;    -- inc A
	constant inc_B : integer := 16#51#;    -- inc B
	constant inc_C : integer := 16#52#;    -- inc C
	constant inc_D : integer := 16#53#;    -- inc D
	constant inc_E : integer := 16#54#;    -- inc E
	constant inc_H : integer := 16#55#;    -- inc H
	constant inc_L : integer := 16#56#;    -- inc L
	
	constant inc_SP : integer := 16#57#;   -- inc SP
	constant inc_IX : integer := 16#59#;   -- inc IX
	constant inc_IY : integer := 16#5A#;   -- inc IY

	constant dec_A : integer := 16#60#;    -- dec A
	constant dec_B : integer := 16#61#;    -- dec B
	constant dec_C : integer := 16#62#;    -- dec C
	constant dec_D : integer := 16#63#;    -- dec D
	constant dec_E : integer := 16#64#;    -- dec E
	constant dec_H : integer := 16#65#;    -- dec H
	constant dec_L : integer := 16#66#;    -- dec L
	
	constant dec_SP : integer := 16#68#;   -- dec SP
	constant dec_IX : integer := 16#69#;   -- dec IX
	constant dec_IY : integer := 16#6A#;   -- dec IY
	
	constant and_A_B : integer := 16#70#;  -- and A,B
	constant and_A_n : integer := 16#71#;  -- and A,n
	constant or_A_B : integer := 16#72#;   -- or A,B
	constant or_A_n : integer := 16#73#;   -- or A,n
	constant xor_A_B : integer := 16#74#;  -- xor A,B
	constant xor_A_n : integer := 16#75#;  -- xor A,n
	
	constant rla_A  : integer := 16#80#;   -- rla A
	constant rlca_A : integer := 16#81#;   -- rlca A
	constant rra_A  : integer := 16#82#;   -- rra A
	constant rrca_A : integer := 16#83#;  	-- rrca A
	constant sra_A  : integer := 16#84#;   -- sra A
	constant srl_A  : integer := 16#85#;   -- srl A
	constant sla_A  : integer := 16#86#;   -- sla A
	constant rr_A   : integer := 16#87#;   -- rr A
	constant rl_A   : integer := 16#88#;   -- rl A
	
	constant jp_nn    : integer := 16#F1#; -- jp nn
	constant jp_nz_nn : integer := 16#F2#; -- jp nz,nn
	constant jp_z_nn  : integer := 16#F3#; -- jp z,nn
	constant jp_nc_nn : integer := 16#F4#; -- jp nc,nn
	constant jp_c_nn  : integer := 16#F5#; -- jp c,nn
	constant jp_p_nn  : integer := 16#F6#; -- jp p,nn
	constant jp_m_nn  : integer := 16#F7#; -- jp m,nn
	constant call_nn  : integer := 16#F8#; -- call nn
	constant nm_int   : integer := 16#F9#; -- int
	constant ret_cll  : integer := 16#FA#; -- ret
	
----------End Data----------