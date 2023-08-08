# Teletypwriter Console Package 
# (c) 2023 Haley Hashemi, Open Source Instruments Inc.
# (c) 2023 Kevan Hashemi, Open Source Instruments Inc.
#
# Routines to set up a console interface using a TTY terminal.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA  02111-1307, USA.

# Version 1.1 First version.

# Load this package or routines into LWDAQ with "package require EDF".
package provide TTY 1.1

# Clear the global EDF array if it already exists.
if {[info exists TTY]} {unset TTY}

# Initialize the TTY global array.
set TTY(prompt) "% "
set TTY(command) ""
set TTY(state) "insert"

proc TTY_start {} {
	global TTY
	eval exec [auto_execok stty] raw -echo 
	fconfigure stdin -translation auto -buffering none
	fileevent stdin readable TTY_execute
	set TTY(state) "insert"
	set TTY(command) ""
	puts -nonewline stdout $TTY(prompt)
	flush stdout
}

proc TTY_stop {} {
	eval exec [auto_execok stty] -raw echo
	fconfigure stdin -translation auto -buffering line
	fileevent stdin readable ""
}

proc TTY_execute {} {
	global TTY
	if {[catch {
		if {[set c [read stdin 1]] != ""} {
			if {$c == "\n"} {
				puts stdout ""
				set result [uplevel $TTY(command)]
				set TTY(command) ""
				if {$result != ""} {
					puts stdout $result
				}
				puts -nonewline stdout $TTY(prompt)
				flush stdout
			} {
				scan $c %c ascii
				if {$TTY(state) == "escape"} {
					if {$ascii == 91} {
						set TTY(state) "arrow"
					} elseif {$ascii != 27} {			
						puts -nonewline "\x07"			
						set TTY(state) "insert"
					}
				} elseif {$TTY(state) == "arrow"} {
					switch $c {
						"A" {puts -nonewline "uarr"}
						"B" {puts -nonewline "darr"}
						"C" {puts -nonewline "rarr"}
						"D" {puts -nonewline "larr"}
						default {puts -nonewline $c}
					}
					set TTY(state) "insert"
				} else {
					if {$ascii == 27} {
						set TTY(state) "escape"
					} elseif {$ascii == 127} {
						if {[string length $TTY(command)] > 0} {
							set TTY(command) \
								[string range $TTY(command) 0 end-1]
							puts -nonewline "\x08\x20\x08"
						}
					} else {
						puts -nonewline stdout $c
						append TTY(command) $c
					}
				} 
				flush stdout
			}
		}
	} error_result]} {
		puts stdout $error_result
		puts -nonewline stdout $TTY(prompt)
		flush stdout
		set TTY(command) ""
	}
}

