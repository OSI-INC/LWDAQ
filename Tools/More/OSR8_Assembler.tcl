# OSR8 Assembler, a LWDAQ Tool
#
# Copyright (C) 2020-2024 Kevan Hashemi, Open Source Instruments Inc.
#
# Open-Source Reconfigurable Eight-Bit Central Porocessing Unit Assembler and
# Dis-Assembler. The OSR8 Assembler converts text Open-Source, Reconfigurable,
# Eight-Bit Central Processing Unit (OSR8 CPU) assembler source code into text
# hexadecimal machine code for use by a firmware compiler such as the Lattice
# Diamond VHDL compiler.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

proc OSR8_Assembler_init {} {
	upvar #0 OSR8_Assembler_info info
	upvar #0 OSR8_Assembler_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "OSR8_Assembler" "1.11"
	if {[winfo exists $info(window)]} {
		raise $info(window)
		return ""
	}
	
	set config(hex_output) "1"
	set config(ifn) "~/Desktop/Program.asm"
	set config(ofn) "~/Desktop/Program.mem"
	set config(ofn_write) "1"
	set info(ifn_ew) $info(window).iew
	set info(ofn_ew) $info(window).oew
	
	set config(opcode_color) "brown"
	set config(syntax_color) "green"
	
	set config(base_addr) "0x0000"
	set config(bytes_per_line) "30"
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
		
	return ""
}

proc OSR8_Assembler_pick {a} {
	upvar #0 OSR8_Assembler_config config
	upvar #0 OSR8_Assembler_info info

	set fn ""
	switch $a {
		"ifn" {set fn [LWDAQ_get_file_name]}
		"ofn" {set fn [LWDAQ_put_file_name Program.mem]}
	}
	if {$fn != ""} {
		set config($a) $fn
		return $fn
	} else {
		return ""
	}
}

proc OSR8_Assembler_edit {a} {
	upvar #0 OSR8_Assembler_config config
	upvar #0 OSR8_Assembler_info info

	if {[winfo exists $info($a\_ew)]} {
		raise $info($a\_ew)
	} else {
		set info($a\_ew) [LWDAQ_edit_script Open $config($a)]
	}
	return $info($a\_ew)
}

proc OSR8_Assembler_instructions {} {
	upvar #0 OSR8_Assembler_config config
	upvar #0 OSR8_Assembler_info info

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
	return ""
}

proc OSR8_Assembler_error {message} {
	upvar #0 OSR8_Assembler_config config
	upvar #0 OSR8_Assembler_info info

	LWDAQ_print $info(text) "ERROR: $message\."
	error $message
}

proc OSR8_Assembler_find_symbol {line} {
	upvar #0 OSR8_Assembler_config config
	upvar #0 OSR8_Assembler_info info

	if {[regexp -nocase {^\s*const\s*([\w]*)\s*([\w]*)} $line dummy symbol value]} {
		if {[regexp -nocase {^0x[0-9A-F]+$} $value]} {
			set value [expr $value]
		} elseif {[regexp {^[0-9]+$} $value]} {
			set value $value
		} else {
			OSR8_Assembler_error "Bad value \"$value\" for \"$symbol\""
		}
		return [list $symbol $value]
	} else {
		return ""
	}
}

proc OSR8_Assembler_assemble {{asm  ""}} {
	upvar #0 OSR8_Assembler_config config
	upvar #0 OSR8_Assembler_info info

	if {$asm == ""} {
		if {[file exists $config(ifn)]} {
			set f [open $config(ifn) r]
			set asm [split [read $f] \n]
			close $f
		} else {
			OSR8_Assembler_error "Cannot find input file \"$config(ifn)\"."
		}
	} else {
		set asm [split [string trim $asm] \n]
	}
	LWDAQ_print $info(text) "Assembling [llength $asm] lines of code." purple
	
	
	# Refresh error, warning, symbol, and label lists.
	set symbol_list [list]
	set label_list [list]

	# Eliminate comments, replace commas with spaces, reduce multiple spaces 
	# with single spaces, and trim all lines.
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
			} elseif {[regexp -nocase {^\(*(IX|IY|SP)\)*$} $lo1]} {
				set fo_match 0
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
						foreach c $symbol_list {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {$v == $s} {
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
						foreach c $symbol_list {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {$v == $s} {
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
						set value [format %02X $v]
						append code "$value "
						set fo_match 1
					} elseif {[regexp {^[0-9]+$} $v]} {
						set value [format %02X [expr $v]]
						append code "$value "
						set fo_match 1
					} else {
						foreach c $symbol_list {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {$v == $s} {
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
			} elseif {[regexp -nocase {^\(*(IX|IY|SP)\)*$} $lo2]} {
				set so_match 0
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
						foreach c $symbol_list {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {$v == $s} {
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
						foreach c $symbol_list {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {$v == $s} {
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
						foreach c $symbol_list {
							set s [lindex $c 0]
							set sv [lindex $c 1]
							if {$v == $s} {
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
		set sym_val [OSR8_Assembler_find_symbol $line] 
		if {$sym_val != ""} {
			set sym [lindex $sym_val 0]
			set val [lindex $sym_val 1]
			if {[lsearch -index 0 $symbol_list $sym] >= 0} {
				OSR8_Assembler_error "Symbol \"$sym\" already defined\
					at line $line_index\:\n$line"
			}
			set match 1
			lappend symbol_list $sym_val
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
			OSR8_Assembler_error "Unrecognised pneumoic\
				at line $line_index\: \"$line\""
		}
	}
	
	# Now we resolve the label values. Each element of the memory dump is now
	# either a byte, which counts as one address, or a label with no colon,
	# which counts as two, because we are going to replace it with two bytes
	# wherever it appears in the code, or a label with a colon, which counts as
	# nothing because it's just a marker. But when we come to the marker, we add
	# it to the symbol list.
	set addr [expr $config(base_addr)]
	LWDAQ_print $info(text) "Resolving address labels,\
		base address $config(base_addr):" purple
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
			if {[lsearch -index 0 $label_list $lbl] >= 0} {
				OSR8_Assembler_error "Label \"$lbl\"\ defined more than once."
			}
			set val "[format %02X [expr $addr / 256]] [format %02X [expr $addr % 256]] "
			lappend label_list [list $lbl $val]	
			LWDAQ_print $info(text) "$lbl\: 0x[format %04X $addr]"
		} else {
			OSR8_Assembler_error "Bad label \"$m\" in object code."
		}
	}
	set mem $new_mem
	
	# Replace labels with their address values.
	set new_mem ""
	set counter 0
	foreach m $mem {
		if {[regexp -nocase {^[0-9A-F]+$} $m]} {
			append new_mem "$m "
			continue
		}
		set found_label 0
		foreach lbl $label_list {
			set label [lindex $lbl 0]
			set value [lindex $lbl 1]
			if {$m == $label} {
				append new_mem "$value "
				set found_label 1
				break
			}
		}
		if {!$found_label} {
			OSR8_Assembler_error "Undefined label \"$m\"."
		} else {
			incr counter
		}
	}
	set mem $new_mem
	
	# Go through the object code and write bytes to object file if enabled,
	# and always to the text window. The format is either hex bytes or decimal
	# bytes, as selected by user.
	if {$config(ofn_write)} {
		LWDAQ_print $info(text) "Opening output file $config(ofn)." purple
		set f [open $config(ofn) w]
	}
	if {$config(hex_output)} {
		LWDAQ_print $info(text) "Code bytes in hex format:" purple
	} else {
		LWDAQ_print $info(text) "Code bytes in decimal format:" purple
		set newmem [list]
		foreach m $mem {lappend newmem [expr 0x$m]}
		set mem $newmem
	}
	set index 0
	foreach m $mem {
		if {$config(ofn_write)} {puts $f $m}
		incr index
		LWDAQ_print -nonewline $info(text) "$m "
		if {$index % $config(bytes_per_line) == 0} {LWDAQ_print $info(text)}
	}
	if {$index % $config(bytes_per_line) != 0} {LWDAQ_print $info(text)}
	if {$config(ofn_write)} {
		close $f
		LWDAQ_print $info(text) "Generated [llength $mem] code bytes,\
			printed to screen, saved to \"$config(ofn)\"." purple
	} else {
		LWDAQ_print $info(text) "Generated [llength $mem] code bytes,\
			printed to screen, not saved to disk." purple	
	}
	LWDAQ_print $info(text) "Done. \([clock format [clock seconds]]\)" purple
	
	return $mem
}

proc OSR8_Assembler_disassemble {{mem  ""}} {
	upvar #0 OSR8_Assembler_config config
	upvar #0 OSR8_Assembler_info info

	LWDAQ_print $info(text) "Starting OSR8 Dis-Assembler." purple
	if {$mem == ""} {
		if {[file exists $config(ofn)]} {
			LWDAQ_print $info(text) "Reading object code from $config(ofn)." purple
			set f [open $config(ofn) r]
			set mem [split [string trim [read $f]] \n]
			close $f
			LWDAQ_print $info(text) "Read [llength $mem] instruction bytes." purple
		} else {
			OSR8_Assembler_error "Cannot find file $config(ofn)"
		}
	} else {
		LWDAQ_print $info(text) "Received object code from input string." purple
		set mem [split [string trim $mem] \n]
		LWDAQ_print $info(text) "Received [llength $mem] instruction bytes." purple
	}
	LWDAQ_print $info(text) "Output will be written to text window." purple
	
	# Go through object file finding instructions and printing out prototype
	# instructions with operands filled in by values found in object file.
	set index 0
	set asm ""
	while {$index < [llength $mem]} {
		set bytes [string trim [lindex $mem $index]]
		set match 0
		foreach inst $info(instructions) {
			set prototype [regsub {,} [lindex $inst 0] " "]
			set code "[lindex $inst 1] "
			if {[expr 0x$code] == [expr 0x$bytes]} {
				set match 1
				
				if {[llength $prototype] == 1} {
					break
				}
				
				if {[regexp -nocase {\(*nn\)*} [lindex $prototype 1]]} {
					if {$index >= [llength $mem] - 2} {
						OSR8_Assembler_error "Missing operand bytes for\
							final instruction $prototype"
					}
					set n1 [lindex $mem [expr $index + 1]]
					set n2 [lindex $mem [expr $index + 2]]
					lset prototype 1 [regsub {nn} [lindex $prototype 1] \
						"0x[set n1][set n2]"]
					append bytes " $n1 $n2"
				} elseif {[regexp -nocase {^n$} [lindex $prototype 1]]} {
					if {$index >= [llength $mem] - 1} {
						OSR8_Assembler_error "Missing operand bytes for\
							final instruction $prototype"
					}
					set n1 [lindex $mem [expr $index + 1]]
					lset prototype 1 [regsub {n} [lindex $prototype 1] \
						"0x[set n1]"]
					append bytes " $n1"
				}
				
				if {[llength $prototype] == 2} {
					break
				}
				
				if {[regexp -nocase {\(*nn\)*} [lindex $prototype 2]]} {
					if {$index >= [llength $mem] - 2} {
						OSR8_Assembler_error "Missing operand bytes\
							for final instruction $prototype"
					}
					set n1 [lindex $mem [expr $index + 1]]
					set n2 [lindex $mem [expr $index + 2]]
					lset prototype 2 [regsub {nn} [lindex $prototype 2] \
						"0x[set n1][set n2]"]
					append bytes " $n1 $n2"
				} elseif {[regexp -nocase {^n$} [lindex $prototype 2]]} {
					if {$index >= [llength $mem] - 1} {
						OSR8_Assembler_error "Missing operand bytes\
							for final instruction $prototype"
						break
					}
					set n1 [lindex $mem [expr $index + 1]]
					lset prototype 2 [regsub {n} [lindex $prototype 2] \
						"0x[set n1]"]
					append bytes " $n1"
				}
				
				break
			}
		}

		if {!$match} {
			OSR8_Assembler_error "Unrecognized opcode \"$byte\""
		} else {
			LWDAQ_print -nonewline $info(text) "0x[format %04X $index]: "
			LWDAQ_print -nonewline $info(text) \
				"[format %-10s $bytes] " $config(opcode_color)
			LWDAQ_print $info(text) $prototype $config(syntax_color)	
			append asm $prototype	
		}
		
		set index [expr $index + [llength $bytes]]
	}	

	return ""
}

proc OSR8_Assembler_open {} {
	upvar #0 OSR8_Assembler_config config
	upvar #0 OSR8_Assembler_info info
	
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	foreach a {Assemble Disassemble Instructions} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_post "catch OSR8_Assembler_$b"]
		pack $f.$b -side left -expand 1
		
	} 
	
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	checkbutton $f.hex -variable OSR8_Assembler_config(hex_output) -text "Hex Output"
	pack $f.hex -side left -expand 1
	checkbutton $f.fileout -variable OSR8_Assembler_config(ofn_write) -text "Write File"
	pack $f.fileout -side left -expand 1

	foreach {a b} {ifn Input ofn Output} {
		set f $w.[set a]
		frame $f
		pack $f -side top -fill x
	
		label $f.[set a]l -text "$b File:" 
		entry $f.[set a]e -textvariable OSR8_Assembler_config([set a]) -width 60
		button $f.[set a]p -text "Pick" -command "OSR8_Assembler_pick $a"
		button $f.[set a]ed -text "Edit" -command "OSR8_Assembler_edit $a"
		pack $f.[set a]l $f.[set a]e $f.[set a]p $f.[set a]ed -side left -expand 1
	}
	
	set info(text) [LWDAQ_text_widget $w 100 15]

	LWDAQ_print $info(text) "$info(name) Version $info(version)" purple
	LWDAQ_print $info(text) "(c) 2020 Kevan Hashemi, Open Source\
		Instruments Inc.\n" purple	
	
	return $w
}

OSR8_Assembler_init
OSR8_Assembler_open
	
return ""

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3035/OSR8.html#Assembler

----------End Help----------

----------Begin Data----------

	constant nop      : integer := 16#00#; -- nop
	constant jp_nn    : integer := 16#01#; -- jp nn
	constant jp_nz_nn : integer := 16#02#; -- jp nz,nn
	constant jp_z_nn  : integer := 16#03#; -- jp z,nn
	constant jp_nc_nn : integer := 16#04#; -- jp nc,nn
	constant jp_c_nn  : integer := 16#05#; -- jp c,nn
	constant jp_np_nn : integer := 16#06#; -- jp np,nn
	constant jp_p_nn  : integer := 16#07#; -- jp p,nn
	constant call_nn  : integer := 16#08#; -- call nn
	constant sw_int   : integer := 16#09#; -- int
	constant ret_cll  : integer := 16#0A#; -- ret
	constant ret_int  : integer := 16#0B#; -- rti
	constant cpu_wt   : integer := 16#0C#; -- wait
	constant clr_iflg : integer := 16#0D#; -- clri
	constant set_iflg : integer := 16#0E#; -- seti
	
	constant ld_A_n   : integer := 16#10#; -- ld A,n
	constant ld_IX_nn : integer := 16#11#; -- ld IX,nn
	constant ld_IY_nn : integer := 16#12#; -- ld IY,nn
	constant ld_HL_nn : integer := 16#13#; -- ld HL,nn
	constant ld_A_mm  : integer := 16#14#; -- ld A,(nn)
	constant ld_mm_A  : integer := 16#15#; -- ld (nn),A
	constant ld_A_ix  : integer := 16#16#; -- ld A,(IX)
	constant ld_A_iy  : integer := 16#17#; -- ld A,(IY)
	constant ld_ix_A  : integer := 16#18#; -- ld (IX),A
	constant ld_iy_A  : integer := 16#19#; -- ld (IY),A
	constant ld_HL_SP : integer := 16#1A#; -- ld HL,SP
	constant ld_SP_HL : integer := 16#1B#; -- ld SP,HL
	constant ld_HL_PC : integer := 16#1C#; -- ld HL,PC
	constant ld_PC_HL : integer := 16#1D#; -- ld PC,HL
			
	constant push_A   : integer := 16#20#; -- push A
	constant push_B   : integer := 16#21#; -- push B
	constant push_C   : integer := 16#22#; -- push C
	constant push_D   : integer := 16#23#; -- push D
	constant push_E   : integer := 16#24#; -- push E
	constant push_H   : integer := 16#25#; -- push H
	constant push_L   : integer := 16#26#; -- push L
	constant push_F   : integer := 16#27#; -- push F
	constant push_IX  : integer := 16#28#; -- push IX
	constant push_IY  : integer := 16#29#; -- push IY
	
	constant pop_A    : integer := 16#30#; -- pop A
	constant pop_B    : integer := 16#31#; -- pop B
	constant pop_C    : integer := 16#32#; -- pop C
	constant pop_D    : integer := 16#33#; -- pop D
	constant pop_E    : integer := 16#34#; -- pop E
	constant pop_H    : integer := 16#35#; -- pop H
	constant pop_L    : integer := 16#36#; -- pop L
	constant pop_F    : integer := 16#37#; -- pop F
	constant pop_IX   : integer := 16#38#; -- pop IX
	constant pop_IY   : integer := 16#39#; -- pop IY

	constant add_A_B  : integer := 16#40#; -- add A,B
	constant add_A_n  : integer := 16#41#; -- add A,n
	constant adc_A_B  : integer := 16#42#; -- adc A,B
	constant adc_A_n  : integer := 16#43#; -- adc A,n
	constant sub_A_B  : integer := 16#44#; -- sub A,B
	constant sub_A_n  : integer := 16#45#; -- sub A,n
	constant sbc_A_B  : integer := 16#46#; -- sbc A,B
	constant sbc_A_n  : integer := 16#47#; -- sbc A,n
	constant clr_aflg : integer := 16#4F#; -- clrf
	
	constant inc_A    : integer := 16#50#; -- inc A
	constant inc_B    : integer := 16#51#; -- inc B
	constant inc_C    : integer := 16#52#; -- inc C
	constant inc_D    : integer := 16#53#; -- inc D
	constant inc_E    : integer := 16#54#; -- inc E
	constant inc_H    : integer := 16#55#; -- inc H
	constant inc_L    : integer := 16#56#; -- inc L
	constant inc_SP   : integer := 16#57#; -- inc SP
	constant inc_IX   : integer := 16#59#; -- inc IX
	constant inc_IY   : integer := 16#5A#; -- inc IY

	constant dec_A    : integer := 16#60#; -- dec A
	constant dec_B    : integer := 16#61#; -- dec B
	constant dec_C    : integer := 16#62#; -- dec C
	constant dec_D    : integer := 16#63#; -- dec D
	constant dec_E    : integer := 16#64#; -- dec E
	constant dec_H    : integer := 16#65#; -- dec H
	constant dec_L    : integer := 16#66#; -- dec L
	constant dly_A    : integer := 16#67#; -- dly A
	constant dec_SP   : integer := 16#68#; -- dec SP
	constant dec_IX   : integer := 16#69#; -- dec IX
	constant dec_IY   : integer := 16#6A#; -- dec IY
	
	constant and_A_B  : integer := 16#70#; -- and A,B
	constant and_A_n  : integer := 16#71#; -- and A,n
	constant or_A_B   : integer := 16#72#; -- or A,B
	constant or_A_n   : integer := 16#73#; -- or A,n
	constant xor_A_B  : integer := 16#74#; -- xor A,B
	constant xor_A_n  : integer := 16#75#; -- xor A,n
	
	constant rl_A     : integer := 16#78#; -- rl A
	constant rlc_A    : integer := 16#79#; -- rlc A
	constant rr_A     : integer := 16#7A#; -- rr A
	constant rrc_A    : integer := 16#7B#; -- rrc A
	constant sla_A    : integer := 16#7C#; -- sla A
	constant sra_A    : integer := 16#7D#; -- sra A
	constant srl_A    : integer := 16#7E#; -- srl A
	
----------End Data----------