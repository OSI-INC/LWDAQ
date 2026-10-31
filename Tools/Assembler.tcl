# Assembler, a LWDAQ Tool
#
# Copyright (C) 2020-2026 Kevan Hashemi, Open Source Instruments Inc.
#
# This tool translates Open-Source Reconfigurable Eight-Bit Microprocessor
# (OSR8) CPU and Reduced Instruction Set Microcontroller with Five-Bit Opcodes
# (RMC5) instruction penumonics into hexadecimal text strings, one instruction
# memory value on each line of an output file. The tool also disassembles hex
# output file. These hex files are designed for use with the Lattice Diamond
# VHDL compiler. We use the OSR8 and RMC5 with Lattice Semiconductor FPGAs, in
# particular the LCMXO2 family of devices.
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

proc Assembler_init {} {
	upvar #0 Assembler_info info
	upvar #0 Assembler_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Assembler" "4.1"
	if {[winfo exists $info(window)]} {
		raise $info(window)
		return ""
	}
	
	set config(output_format) "Hex"
	set config(ifn) "~/Desktop/Program.asm"
	set config(ofn) "~/Desktop/Program.mem"
	set config(ofn_write) "1"
	set info(ifn_ew) $info(window).iew
	set info(ofn_ew) $info(window).oew
	
	set info(t_color) "purple"
	set info(oc_color) "brown"
	set info(syntax_color) "green"
	
	set info(supported_cpus) "OSR8 RMC5"
	set config(cpu) "OSR8"
	set config(opcode_width) "0"
	set config(addr_width) "0"
	set config(data_width) "0"
	set config(output_format) "Hex"
	
	set info(OSR8_opcode_width) "8"
	set info(OSR8_addr_width) "16"
	set info(OSR8_default_addr_width) "16"
	set info(OSR8_data_width) "8"
	set info(OSR8_formats) "Hex Binary"
	set info(OSR8_default_format) "Hex"
	
	set info(RMC5_opcode_width) "5"
	set info(RMC5_addr_width) "3 4 5 6 7 8 9 10 11 12 13 14 15 16"
	set info(RMC5_default_addr_width) "7"
	set info(RMC5_data_width) "8"
	set info(RMC5_formats) "Binary"
	set info(RMC5_default_format) "Binary"
	
	set config(base_addr) "0x0000"
	set config(bytes_per_line) "30"
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	return ""
}

proc Assembler_set_cpu {cpu} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

	set config(cpu) $cpu
	
	$info(addr_menu) delete 0 100
	foreach width [set info($cpu\_addr_width)] {
		$info(addr_menu) add command -label $width \
			-command [list set Assembler_config(addr_width) $width]
	}
	set config(addr_width) $info($cpu\_default_addr_width)

	$info(format_menu) delete 0 100
	foreach f [set info($cpu\_formats)] {
		$info(format_menu) add command -label $f \
			-command [list set Assembler_config(output_format) $f]
	}
	set config(output_format) $info($cpu\_default_format)
}

proc Assembler_load {} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

	LWDAQ_print $info(text) "\nLoading instructions\
		from built-in database..." $info(t_color)
	LWDAQ_update
	
	set data [string trim [LWDAQ_tool_data $info(name)]]
	foreach cpu $info(supported_cpus) {
		set pattern "BEGIN_$cpu\(\.\*\?\)END_$cpu"
		if {![regexp -indices $pattern $data match instructions]} {
			LWDAQ_print $info(text) "ERROR: Cannot find instructions for $cpu\."
			continue
		}
		set info($cpu\_instructions) [list]
		lassign $instructions first last
		set instructions [string range $data $first $last]
		set instructions [split $instructions \n]
		lassign $match first last
		set data [string range $data [expr $last+1] end]

		LWDAQ_print -nonewline $info(text) "$cpu"
		foreach d $instructions {
			if {[regexp { +-- +([0-9A-Fa-f]{2}) +(.*)} $d dummy opcode syntax]} {
				lappend info($cpu\_instructions) [list $syntax $opcode]
				LWDAQ_print -nonewline $info(text) "."
				LWDAQ_update
			}
		}
		LWDAQ_print $info(text)
		LWDAQ_print $info(text) "Loaded [llength [set info($cpu\_instructions)]]\
			opcodes with syntax for $cpu processor."
		LWDAQ_update
	}
	
	Assembler_set_cpu [lindex $info(supported_cpus) 0]
	
	LWDAQ_print $info(text) "Done. \([clock format [clock seconds]]\)" $info(t_color)
	LWDAQ_update
}

proc Assembler_pick {a} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

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

proc Assembler_edit {a} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

	if {[winfo exists $info($a\_ew)]} {
		raise $info($a\_ew)
	} else {
		set info($a\_ew) [LWDAQ_edit_script Open $config($a)]
	}
	return $info($a\_ew)
}

proc Assembler_instructions {} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

	LWDAQ_print $info(text) "Operation Codes and Instruction Syntax" $info(t_color)
	LWDAQ_print $info(text) "n = data constant, nn = address constant" $info(t_color)
	LWDAQ_print $info(text) "(nn) = value pointed to by address nn" $info(t_color)
	LWDAQ_print $info(text) "SP = stack pointer, PC = program counter" $info(t_color)
	LWDAQ_print $info(text) "(IX), (IY) values pointed to by IX and IY" $info(t_color)

	set instructions [set info($config(cpu)\_instructions)]
	set index 0
	foreach i $instructions {
		LWDAQ_print -nonewline $info(text) \
			"[format %-10s [lindex $i 0]] " $info(syntax_color)
		LWDAQ_print -nonewline $info(text) \
			"0x[lindex $i 1]   " $info(oc_color)
		incr index
		if {$index % 4 == 0} {LWDAQ_print $info(text)}
		LWDAQ_support
	}
	if {$index % 4 != 0} {LWDAQ_print $info(text)}
	
	LWDAQ_print $info(text) "Number of Available Instructions\
		= [llength $instructions].\n" $info(t_color)
	LWDAQ_print $info(text) "Done. \([clock format [clock seconds]]\)\n" $info(t_color)

	return ""
}

proc Assembler_define_symbol {line} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

	if {[regexp -nocase {^\s*const\s*([\w]*)\s*([\w]*)} $line dummy symbol value]} {
		if {[regexp -nocase {^0x[0-9A-F]+$} $value]} {
			set value [expr $value]
		} elseif {[regexp {^[0-9]+$} $value]} {
			set value $value
		} else {
			set message "ERROR: Bad value \"$value\" for \"$symbol\"."
			LWDAQ_print $info(text) $message
			error $message
		}
		return [list $symbol $value]
	} else {
		return ""
	}
}

proc Assembler_find_include {line} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

	if {[regexp -nocase {^\s*include\s*"(.*?)"} $line dummy fn]} {
		set fn [file join [file dirname $config(ifn)] $fn]
		set fn [file normalize $fn]
		if {[file exists $fn]} {
			return $fn		
		} else {
			set message "ERROR: Cannot find include file \"$fn\"."
			LWDAQ_print $info(text) $message
			error $message
		}
	} else {
		return ""
	}
}

proc Assembler_assemble {{asm  ""}} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

	if {$asm == ""} {
		if {[file exists $config(ifn)]} {
			set f [open $config(ifn) r]
			set asm [split [read $f] \n]
			close $f
		} else {
			set message "ERROR: Cannot find input file \"$config(ifn)\"."
			LWDAQ_print $info(text) $message
			error $message
		}
	} else {
		set asm [split [string trim $asm] \n]
	}
	LWDAQ_print $info(text) "Assembling [llength $asm] lines of code." $info(t_color)
	
	# Include files, supporting recursive inclusion.
	set basm [list]
	foreach line $asm {
		set fn [Assembler_find_include $line]
		if {$fn != ""} {
			LWDAQ_print $info(text) "Including file \"$fn\"."
			set f [open $fn r]
			set iasm [split [read $f] \n]
			set basm [concat $basm $iasm]
			close $f
		} else {
			lappend basm $line
		}
	}
	set asm $basm
	
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
	set asm $basm
	
	# Go through lines finding instructions. Each assemby language instruction
	# must be on a separate line. We do not allow consecutive instructions on
	# the same line. Each instruction will represented in the assembled list by
	# its own element, which will consists of one or more hexadecimal bytes, and
	# perhaps a label, which we will later resolve into two hexadecimal bytes.
	# This format for representing instructions is sufficient for any processor
	# with opcode length one to eight bits and address length one to sixteen
	# bits. Our list of instructions is the one corresponding to our selected
	# processor. As we go through the code, we keep a list of symbols, which are
	# constants defined by constant declarations in the source code, and then
	# referenced in instructions. If a symbol is not resolved in an instruction
	# by an existing declaration, we assume it is an address label, and we will
	# try to resolve it later.
	set instructions [set info($config(cpu)\_instructions)]
	set assembled [list]
	set symbols [list]
	set line_index 0
	foreach line $asm {
		incr line_index
		set match 0
		set opcode ""
		foreach inst $instructions {
		
			# We extract from the instruction the two-digit hexadecimal opcode
			# string and the pneumonic string. We remove commas from the
			# pneumonic string and replace them with spaces.
			set opcode [lindex $inst 1]
			set prototype [regsub {,} [lindex $inst 0] " "]
			
			# The line and instruction prototype must have the same number of elements,
			# and their first instruction pneumonic words must match.
			if {[llength $line] != [llength $prototype]} {continue}
			if {![regexp -nocase [lindex $line 0] [lindex $prototype 0]]} {continue}

			# The pneumonics match and there are no operands, the opcode of this 
			# instruction is the output for this line.
			if {[llength $prototype] == 1} {
				set match 1
				lappend assembled [string trim $opcode]
				break
			} 
			
			# Start an instruction bytes string with the opcode.
			set code "$opcode "
			
			# Compare the first operands. These could be letters naming a register
			# or pneumonics n, nn, or (nn) for a data constant, address constant,
			# or memory access with address constant. In the case of constants, we
			# extract the constant value from the source code line. Data constants
			# we format as two hex digits, address constants as four hex digits. We
			# append these bytes to the instruction code. If we encounter what might
			# be a symbol, we look for it in our symbol list.
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
				lappend assembled [string trim $code]
				break
			}

			# Compare the second operands. We do this in exactly the same way we
			# did for the first operands.
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
			lappend assembled [string trim $code]
			break
		}
		
		# If we matched the instruction, print out the line number, prototype
		# instruction that we matched to, and the machine code. Then continue to
		# the next line.
		if {$match} {
			LWDAQ_print -nonewline $info(text) "[format %3d $line_index]: " 
			LWDAQ_print -nonewline $info(text) \
				"[format %-16s $prototype] " $info(syntax_color)
			LWDAQ_print $info(text) $code $info(oc_color)
			continue
		}
		
		# We don't have an instruction match, so maybe this is a constant declaration.
		# Use our define-symbol routine to extract the symbol string and its value.
		# We do not allow re-definition of symbols.
		set sym_val [Assembler_define_symbol $line] 
		if {$sym_val != ""} {
			set sym [lindex $sym_val 0]
			set val [lindex $sym_val 1]
			if {[lsearch -index 0 $symbol_list $sym] >= 0} {
				set message "ERROR: Symbol \"$sym\" already defined\
					at line $line_index\:\n$line\."
				LWDAQ_print $info(text) $message
				error $message
			}
			set match 1
			lappend symbol_list $sym_val
			LWDAQ_print -nonewline $info(text) "[format %3d $line_index]: " 
			LWDAQ_print -nonewline $info(text) "[format %-16s $sym] " $info(syntax_color)
			LWDAQ_print $info(text) \
				"[format %-5d $val] 0x[format %04X $val]" $info(oc_color)
			continue
		} 
		
		# The last possibility for this source code line is that it is a label
		# marker: an alphanumeric string with a colon after it, which marks a
		# location in the code for jumping to. We append labels with their colons
		# to our assembled code list, to be resolved later.
		if {[regexp {^\w+:$} $line lbl]} {
			set match 1
			lappend assembled "$lbl "
			LWDAQ_print $info(text) $lbl 
			continue
		}
		
		# We have failed to identify this line, so generate an error.
		if {[regexp {\w+} $line dummy]} {
			set message "ERROR: Unrecognised pneumoic at line $line_index\: \"$line\"."
			LWDAQ_print $info(text) $message
			error $message
		}
	}
	
	LWDAQ_print $info(text) $assembled orange
	
	# Resolve the label values. Each element of the memory dump is now one or
	# more bytes, one or more bytes with a label that needs to be substituted,
	# or a label on its own that we need to resolve. As we go through the
	# assembled code, we keep track of the instruction memory address. The way
	# we do this depends upon the processor. The OSR8 uses one to three bytes
	# per instruction in its byte-wide instruction memory, and those bytes are
	# the ones listed in our assembled instruction strings. The RMC5 has one
	# instruction memory location per instruction.
	set addr [expr $config(base_addr)]
	LWDAQ_print $info(text) "Resolving address labels,\
		base address $config(base_addr):" $info(t_color)
	set new_assembled ""
	foreach m $assembled {
		set new_m ""
		foreach element $m {
			if {[regexp -nocase {^[0-9A-F]+$} $element]} {
				if {$config(cpu) == "OSR8"} {incr addr}
				append new_m "$element "
			} elseif {[regexp {^(\w+)$} $element dummy lbl]} {
				if {$config(cpu) == "OSR8"} {
					incr addr
					incr addr
				}
				append new_m "$element "
			} elseif {[regexp {^(\w+):$} $element dummy lbl]} {
				if {[lsearch -index 0 $label_list $lbl] >= 0} {
					set message "ERROR: Label \"$lbl\"\ defined more than once."
					LWDAQ_print $info(text) $message
					error $message
				}
				set val "[format %02X [expr $addr / 256]] [format %02X [expr $addr % 256]] "
				lappend label_list [list $lbl $val]	
				LWDAQ_print $info(text) "$lbl\: 0x[format %04X $addr]"
			} else {
				set message "ERROR: Bad label \"$m\" in object code."
				LWDAQ_print $info(text) $message
				error $message
			}
		}
		if {$new_m != ""} {
			if {$config(cpu) == "RMC5"} {incr addr}
			lappend new_assembled [string trim $new_m]
		}
	}
	set assembled $new_assembled
	
	LWDAQ_print $info(text) $assembled green

	# Now that we have a list of labels and their corresponding instruction
	# memory addresses, replace all labels with their address values, which will
	# be two hex bytes.
	set new_assembled ""
	set counter 0
	foreach m $assembled {
		set new_m ""
		foreach element $m {
			if {[regexp -nocase {^[0-9A-F]+$} $element]} {
				append new_m "$element "
				continue
			}
			set found_label 0
			foreach lbl $label_list {
				set label [lindex $lbl 0]
				set value [lindex $lbl 1]
				if {$element == $label} {
					append new_m "$value "
					set found_label 1
					break
				}
			}
			if {!$found_label} {
				set message "ERROR: Undefined label \"$m\"."
				LWDAQ_print $info(text) $message
				error $message
			} else {
				incr counter
			}
		}
		lappend new_assembled [string trim $new_m]
	}
	set assembled $new_assembled

	LWDAQ_print $info(text) $assembled blue
	
	# We now have our asssembled object code, in the form of a list of instructions.
	# Each instruction is defined by one to three bytes. We are ready to write the
	# object code to the screen and to disk. The format is either hexadecimal 
	# bytes or binary strings, as selected by user.
	if {$config(ofn_write)} {
		LWDAQ_print $info(text) "Opening output file $config(ofn)." $info(t_color)
		set f [open $config(ofn) w]
	}
	if {$config(output_format) == "Hex"} {
		LWDAQ_print $info(text) "Instructions in hexadecimal format:" $info(t_color)
	} else {
		LWDAQ_print $info(text) "Instructions in binary format:" $info(t_color)
	}
	set index 0
	foreach instruction $assembled {
		if {$config(cpu) == "OSR8"} {
			foreach value $instruction {
				if {[expr 0x$value] > 255} {
					set message "ERROR: Value out of range \"0x$value\"."
					LWDAQ_print $info(text) $message
					error $message
				}
				if {$config(output_format) == "Hex"} {
					if {$config(ofn_write)} {puts $f $value}
					LWDAQ_print -nonewline $info(text) "$value "
				} else {
					set binvalue [format %08b [expr 0x$value]]
					if {$config(ofn_write)} {puts $f $binvalue}
					LWDAQ_print -nonewline $info(text) "$binvalue "
				}
				incr index
				if {$index % $config(bytes_per_line) == 0} {LWDAQ_print $info(text)}
			}
		} else {
			set opcode [format %05b [expr 0x[lindex $instruction 0]]]
			if {[llength $instruction] == 3} {
				set operand [expr (0x[lindex $instruction 1] * 256) \
					+ 0x[lindex $instruction 2]]
			} else {
				set operand 0
			}
			set operand [format %0[set config(addr_width)]b $operand]
			if {$config(ofn_write)} {puts $f "$opcode$operand"}
			LWDAQ_print -nonewline $info(text) "$opcode$operand "
			incr index
			if {$index % $config(bytes_per_line) == 0} {LWDAQ_print $info(text)}
		} 
	}
	
	# Tidy up, we are done.
	if {$index % $config(bytes_per_line) != 0} {LWDAQ_print $info(text)}
	if {$config(ofn_write)} {
		close $f
		LWDAQ_print $info(text) "Generated [llength $assembled] code bytes,\
			printed to screen, saved to \"$config(ofn)\"." $info(t_color)
	} else {
		LWDAQ_print $info(text) "Generated [llength $assembled] code bytes,\
			printed to screen, not saved to disk." $info(t_color)	
	}
	LWDAQ_print $info(text) "Done. \([clock format [clock seconds]]\)\n" $info(t_color)
	
	return $assembled
}

proc Assembler_disassemble {{mem  ""}} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info

	LWDAQ_print $info(text) "Starting Dis-Assembler." $info(t_color)
	if {$mem == ""} {
		if {[file exists $config(ofn)]} {
			LWDAQ_print $info(text) "Reading object code from $config(ofn)." $info(t_color)
			set f [open $config(ofn) r]
			set mem [split [string trim [read $f]] \n]
			close $f
			LWDAQ_print $info(text) "Read [llength $mem] instruction bytes." $info(t_color)
		} else {
			set message "ERROR: Cannot find file $config(ofn)."
			LWDAQ_print $info(text) $message
			error $message
		}
	} else {
		LWDAQ_print $info(text) "Received object code from input string." $info(t_color)
		set mem [split [string trim $mem] \n]
		LWDAQ_print $info(text) "Received [llength $mem] instruction bytes." $info(t_color)
	}
	LWDAQ_print $info(text) "Output will be written to text window." $info(t_color)
	
	# Go through object file finding instructions and printing out prototype
	# instructions with operands filled in by values found in object file.
	set instructions [set info($config(cpu)\_instructions)]
	set index 0
	set asm ""
	while {$index < [llength $mem]} {
		set instruction_word [string trim [lindex $mem $index]]
		set opcode ""
		set operand ""
		set num_words "1"
		if {$config(cpu) == "OSR8"} {
			if {$config(output_format) == "Hex"} {
				set opcode [expr 0x$instruction_word]
			} else {
				scan $instruction_word %b opcode
			}
		} else {
			if {$config(output_format) == "Hex"} {
				set message "ERROR: Cannot disassemble hex format for RMC5."
				LWDAQ_print $info(text) $message
				error $message				
			}
			scan [string range $instruction_word 0 4] %b opcode
			scan [string range $instruction_word 5 end] %b operand
			set operand [format %04X $operand]
		}
		set match 0
		foreach inst $instructions {
			set prototype [regsub {,} [lindex $inst 0] " "]
			set prototype_operand "[lindex $inst 1] "
			if {[expr 0x$prototype_operand] == $opcode} {
				set match 1
				
				if {$config(cpu) == "RMC5"} {break}
				if {[llength $prototype] == 1} {break}
				
				if {[regexp -nocase {\(*nn\)*} [lindex $prototype 1]]} {
					if {$index >= [llength $mem] - 2} {
						set message "ERROR: Missing operand bytes for\
							final instruction $prototype\."
						LWDAQ_print $info(text) $message
						error $message
					}
					set n1 [lindex $mem [expr $index + 1]]
					set n2 [lindex $mem [expr $index + 2]]
					lset prototype 1 [regsub {nn} [lindex $prototype 1] \
						"0x[set n1][set n2]"]
					set operand "$n1 $n2"
					set num_words "3"
				} elseif {[regexp -nocase {^n$} [lindex $prototype 1]]} {
					if {$index >= [llength $mem] - 1} {
						set message "ERROR: Missing operand bytes for\
							final instruction $prototype\."
						LWDAQ_print $info(text) $message
						error $message
					}
					set n1 [lindex $mem [expr $index + 1]]
					lset prototype 1 [regsub {n} [lindex $prototype 1] "0x[set n1]"]
					set operand "$n1"
					set num_words "2"
				}
				
				if {[llength $prototype] == 2} {
					break
				}
				
				if {[regexp -nocase {\(*nn\)*} [lindex $prototype 2]]} {
					if {$index >= [llength $mem] - 2} {
						set message "ERROR: Missing operand bytes\
							for final instruction $prototype\."
						LWDAQ_print $info(text) $message
						error $message
					}
					set n1 [lindex $mem [expr $index + 1]]
					set n2 [lindex $mem [expr $index + 2]]
					lset prototype 2 [regsub {nn} [lindex $prototype 2] \
						"0x[set n1][set n2]"]
					set operand "$n1 $n2"
					set num_words "3"
				} elseif {[regexp -nocase {^n$} [lindex $prototype 2]]} {
					if {$index >= [llength $mem] - 1} {
						set message "ERROR: Missing operand bytes\
							for final instruction $prototype\."
						LWDAQ_print $info(text) $message
						error $message
					}
					set n1 [lindex $mem [expr $index + 1]]
					lset prototype 2 [regsub {n} [lindex $prototype 2] \
						"0x[set n1]"]
					set operand "$n1"
					set num_words "2"
				}
				
				break
			}
		}

		if {!$match} {
			set message "ERROR: Unrecognized opcode \"$opcode\"."
			LWDAQ_print $info(text) $message
			error $message
		} else {
			LWDAQ_print -nonewline $info(text) "0x[format %04X $index]: "
			LWDAQ_print -nonewline $info(text) "[format %02X $opcode] " $info(oc_color)
			LWDAQ_print -nonewline $info(text) "[format %-10s $operand] " $info(oc_color)
			LWDAQ_print $info(text) "$prototype" $info(syntax_color)	
			append asm $prototype	
		}
		
		set index [expr $index + $num_words]
	}	

	LWDAQ_print $info(text) "Done. \([clock format [clock seconds]]\)\n" $info(t_color)
	return ""
}

proc Assembler_open {} {
	upvar #0 Assembler_config config
	upvar #0 Assembler_info info
	
	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	foreach a {Assemble Disassemble Instructions} {
		set b [string tolower $a]
		button $f.$b -text $a -command [list LWDAQ_post "catch Assembler_$b"]
		pack $f.$b -side left -expand 1
		
	} 
	
	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	set f $w.options
	frame $f
	pack $f -side top -fill x

	label $f.lcpu -text "Processor:"
	tk_optionMenu $f.mcpu Assembler_config(cpu) "OSR8"
	set info(cpu_menu) $f.mcpu.menu
	pack $f.lcpu $f.mcpu -side left -expand 1		
	$info(cpu_menu) delete 0 100
	foreach a $info(supported_cpus) {
		$info(cpu_menu) add command -label $a \
			-command [list Assembler_set_cpu $a]
	}

	label $f.laddr -text "Address Width:"
	tk_optionMenu $f.maddr Assembler_config(addr_width) "8" 
	set info(addr_menu) $f.maddr.menu
	pack $f.laddr $f.maddr -side left -expand 1		

	label $f.lformat -text "Output Format:"
	tk_optionMenu $f.mformat Assembler_config(output_format) "Binary"
	set info(format_menu) $f.mformat.menu
	pack $f.lformat $f.mformat -side left -expand 1

	checkbutton $f.fileout -variable Assembler_config(ofn_write) -text "Write"
	pack $f.fileout -side left -expand 1	
	
	foreach {a b} {ifn Input ofn Output} {
		set f $w.[set a]
		frame $f
		pack $f -side top -fill x
	
		label $f.[set a]l -text "$b File:" 
		entry $f.[set a]e -textvariable Assembler_config([set a]) -width 60
		button $f.[set a]p -text "Pick" -command "Assembler_pick $a"
		button $f.[set a]ed -text "Edit" -command "Assembler_edit $a"
		pack $f.[set a]l $f.[set a]e $f.[set a]p $f.[set a]ed -side left -expand 1
	}
	
	set info(text) [LWDAQ_text_widget $w 100 15]

	LWDAQ_print $info(text) "$info(name) Version $info(version)" $info(t_color)
	
	return $w
}

Assembler_init
Assembler_open
Assembler_load
Assembler_set_cpu "OSR8"

return ""

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3035/OSR8.html#Assembler

----------End Help----------

----------Begin Data----------

BEGIN_OSR8

constant nop      : opcode_type := "0000000"; -- 00 nop
constant jp_nn    : opcode_type := "0000001"; -- 01 jp nn
constant jp_nz_nn : opcode_type := "0000010"; -- 02 jp nz,nn
constant jp_z_nn  : opcode_type := "0000011"; -- 03 jp z,nn
constant jp_nc_nn : opcode_type := "0000100"; -- 04 jp nc,nn
constant jp_c_nn  : opcode_type := "0000101"; -- 05 jp c,nn
constant jp_np_nn : opcode_type := "0000110"; -- 06 jp np,nn
constant jp_p_nn  : opcode_type := "0000111"; -- 07 jp p,nn
constant call_nn  : opcode_type := "0001000"; -- 08 call nn
constant sw_int   : opcode_type := "0001001"; -- 09 int
constant ret_cll  : opcode_type := "0001010"; -- 0A ret
constant ret_int  : opcode_type := "0001011"; -- 0B rti
constant cpu_wt   : opcode_type := "0001100"; -- 0C wait
constant clr_iflg : opcode_type := "0001101"; -- 0D clri
constant set_iflg : opcode_type := "0001110"; -- 0E seti

constant ld_A_n   : opcode_type := "0010000"; -- 10 ld A,n
constant ld_IX_nn : opcode_type := "0010001"; -- 11 ld IX,nn
constant ld_IY_nn : opcode_type := "0010010"; -- 12 ld IY,nn
constant ld_HL_nn : opcode_type := "0010011"; -- 13 ld HL,nn
constant ld_A_m   : opcode_type := "0010100"; -- 14 ld A,(nn)
constant ld_m_A   : opcode_type := "0010101"; -- 15 ld (nn),A
constant ld_A_ix  : opcode_type := "0010110"; -- 16 ld A,(IX)
constant ld_A_iy  : opcode_type := "0010111"; -- 17 ld A,(IY)
constant ld_ix_A  : opcode_type := "0011000"; -- 18 ld (IX),A
constant ld_iy_A  : opcode_type := "0011001"; -- 19 ld (IY),A
constant ld_HL_SP : opcode_type := "0011010"; -- 1A ld HL,SP
constant ld_SP_HL : opcode_type := "0011011"; -- 1B ld SP,HL

constant push_A   : opcode_type := "0100000"; -- 20 push A
constant push_B   : opcode_type := "0100001"; -- 21 push B
constant push_C   : opcode_type := "0100010"; -- 22 push C
constant push_D   : opcode_type := "0100011"; -- 23 push D
constant push_E   : opcode_type := "0100100"; -- 24 push E
constant push_H   : opcode_type := "0100101"; -- 25 push H
constant push_L   : opcode_type := "0100110"; -- 26 push L
constant push_F   : opcode_type := "0100111"; -- 27 push F
constant push_IX  : opcode_type := "0101000"; -- 28 push IX
constant push_IY  : opcode_type := "0101001"; -- 29 push IY

constant pop_A    : opcode_type := "0110000"; -- 30 pop A
constant pop_B    : opcode_type := "0110001"; -- 31 pop B
constant pop_C    : opcode_type := "0110010"; -- 32 pop C
constant pop_D    : opcode_type := "0110011"; -- 33 pop D
constant pop_E    : opcode_type := "0110100"; -- 34 pop E
constant pop_H    : opcode_type := "0110101"; -- 35 pop H
constant pop_L    : opcode_type := "0110110"; -- 36 pop L
constant pop_F    : opcode_type := "0110111"; -- 37 pop F
constant pop_IX   : opcode_type := "0111000"; -- 38 pop IX
constant pop_IY   : opcode_type := "0111001"; -- 39 pop IY

constant add_A_B  : opcode_type := "1000000"; -- 40 add A,B
constant add_A_n  : opcode_type := "1000001"; -- 41 add A,n
constant adc_A_B  : opcode_type := "1000010"; -- 42 adc A,B
constant adc_A_n  : opcode_type := "1000011"; -- 43 adc A,n
constant sub_A_B  : opcode_type := "1000100"; -- 44 sub A,B
constant sub_A_n  : opcode_type := "1000101"; -- 45 sub A,n
constant sbc_A_B  : opcode_type := "1000110"; -- 46 sbc A,B
constant sbc_A_n  : opcode_type := "1000111"; -- 47 sbc A,n
constant clr_aflg : opcode_type := "1001111"; -- 4F clrf

constant inc_A    : opcode_type := "1010000"; -- 50 inc A
constant inc_B    : opcode_type := "1010001"; -- 51 inc B
constant inc_C    : opcode_type := "1010010"; -- 52 inc C
constant inc_D    : opcode_type := "1010011"; -- 53 inc D
constant inc_IX   : opcode_type := "1011001"; -- 59 inc IX
constant inc_IY   : opcode_type := "1011010"; -- 5A inc IY

constant dec_A    : opcode_type := "1100000"; -- 60 dec A
constant dec_B    : opcode_type := "1100001"; -- 61 dec B
constant dec_C    : opcode_type := "1100010"; -- 62 dec C
constant dec_D    : opcode_type := "1100011"; -- 63 dec D
constant dly_A    : opcode_type := "1100111"; -- 67 dly A
constant dec_IX   : opcode_type := "1101001"; -- 69 dec IX
constant dec_IY   : opcode_type := "1101010"; -- 6A dec IY

constant and_A_B  : opcode_type := "1110000"; -- 70 and A,B
constant and_A_n  : opcode_type := "1110001"; -- 71 and A,n
constant or_A_B   : opcode_type := "1110010"; -- 72 or A,B
constant or_A_n   : opcode_type := "1110011"; -- 73 or A,n
constant xor_A_B  : opcode_type := "1110100"; -- 74 xor A,B
constant xor_A_n  : opcode_type := "1110101"; -- 75 xor A,n

constant rl_A     : opcode_type := "1111000"; -- 78 rl A
constant rlc_A    : opcode_type := "1111001"; -- 79 rlc A
constant rr_A     : opcode_type := "1111010"; -- 7A rr A
constant rrc_A    : opcode_type := "1111011"; -- 7B rrc A
constant sla_A    : opcode_type := "1111100"; -- 7C sla A
constant sra_A    : opcode_type := "1111101"; -- 7D sra A
constant srl_A    : opcode_type := "1111110"; -- 7E srl A

END_OSR8

BEGIN_RMC5

constant nop      : opcode_type := "00000"; -- 00 nop
constant jp_nn    : opcode_type := "00001"; -- 01 jp nn
constant jp_nz_nn : opcode_type := "00010"; -- 02 jp nz,nn
constant jp_z_nn  : opcode_type := "00011"; -- 03 jp z,nn
constant jp_nc_nn : opcode_type := "00100"; -- 04 jp nc,nn
constant jp_c_nn  : opcode_type := "00101"; -- 05 jp c,nn
constant call_nn  : opcode_type := "00110"; -- 06 call nn
constant ret_cll  : opcode_type := "00111"; -- 07 ret

constant ret_int  : opcode_type := "01000"; -- 08 rti
constant push_A   : opcode_type := "01001"; -- 09 push A
constant pop_A    : opcode_type := "01010"; -- 0A pop A
constant push_F   : opcode_type := "01011"; -- 0B push F
constant pop_F    : opcode_type := "01100"; -- 0C pop F
constant ld_m_A   : opcode_type := "01101"; -- 0D ld (nn),A
constant ld_A_m   : opcode_type := "01110"; -- 0E ld A,(nn)

constant add_A_m  : opcode_type := "10000"; -- 10 add A,(nn)
constant adc_A_m  : opcode_type := "10001"; -- 11 adc A,(nn)
constant sub_A_m  : opcode_type := "10010"; -- 12 sub A,(nn)
constant sbc_A_m  : opcode_type := "10011"; -- 13 sbc A,(nn)

constant and_A_m  : opcode_type := "10100"; -- 14 and A,(nn)
constant or_A_m   : opcode_type := "10101"; -- 15 or A,(nn)
constant xor_A_m  : opcode_type := "10110"; -- 16 xor A,(nn)

constant rl_A     : opcode_type := "11000"; -- 18 rl A
constant rr_A     : opcode_type := "11001"; -- 19 rr A
constant clr_aflg : opcode_type := "11010"; -- 1A clrf
constant clr_iflg : opcode_type := "11011"; -- 1B clri
constant set_iflg : opcode_type := "11100"; -- 1C seti

END_RMC5

----------End Data----------