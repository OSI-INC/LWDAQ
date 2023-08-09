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
set TTY(commandlist) [list]
set TTY(pointer) "0"
set TTY(index) "0"
set TTY(newcommand) ""

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
		set c [read stdin 1]
		if {$c == "\n"} {
			puts stdout ""
			set result [uplevel $TTY(command)]
			lappend TTY(commandlist) $result
			set TTY(command) ""
			set TTY(pointer) "0"
			if {$result != ""} {
				puts stdout $result
			}
			puts -nonewline stdout $TTY(prompt)
			flush stdout
		} else {
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
					"A" {
					TTY_up
						}
					"B" {
						TTY_down 
					}
					"C" {
						if {$TTY(pointer) > 0} {
							TTY_right
						}
					}
					"D" {
						TTY_left
					}
						default {puts -nonewline $c}
				}
				set TTY(state) "insert"

			} elseif {$TTY(state) == "insert"} {
				if {$ascii == 3} {
					exit
				} elseif {$ascii == 27} {
					set TTY(state) "escape"
				} elseif {$ascii == 127} {
					TTY_delete
				} else {
					if {$TTY(pointer)>0} {
						TTY_insert $c
						puts -nonewline $TTY(command)
						for {set i 0} {$i < $TTY(pointer)} {incr i} {
							TTY_backspace
						}

					} else {
						puts -nonewline stdout $c
						append TTY(command) $c
					}
			}
		} else {
				error "Unknown console state \"$cstate\"."
		}
			flush stdout
		}
	} error_result]} {
		puts "ERROR: $error_result"
		set TTY(command) ""
		puts -nonewline $TTY(prompt)
		set TTY(state) "insert"
	}

	flush stdout
}





# Procedures below:

# If the command list is not empty, enact the remove space command.
# If the global variable "length" is equal to the command list,
# and the index state is "firstup", the uparrow command will print the 
# last element of the command list to the terminal, setting the 
# index state to "nextup", and decrementing the index itself to point to 
# the next previous command in the list. Regardless of index state,
# set the length variable equal to the length of the command list.
# If the index state for the next up arrow press is "nextup", the 
# index will keep decrementing until the first command in the list shown.
# Once the very first command is shown, another arrow press will set the index to point to the 
# most recent command at the end of the list.
# If the up arrow is followed by a carriage return, which appends a new command 
# to the command list, then the length variable is no longer equal to the 
# original length of the list, which then triggers the index to be reset
# to point to the new final element of the list when the next up arrow is pressed.


proc TTY_up {} {
	global TTY 
	if {$TTY(pointer) == 0} {
		set TTY(index) [llength $TTY(commandlist)]
		set TTY(command) [lindex $TTY(commandlist) $TTY(index)]
		puts -nonewline $TTY(command)
		incr TTY(pointer)
	} elseif { 0 < $TTY(pointer) < [llength $TTY(commandlist)]} {
		TTY_removespace
		set TTY(index) [expr [llength $TTY(commandlist) - $TTY(pointer)]]
		set TTY(command) [lindex $TTY(commandlist) $TTY(index)]
		puts -nonewline $TTY(command)
	}
	
}
	
	
	


# Handle the down arrow. Uses an index to point to the more recent command in
# the command list, functions in an opposing manner to the up arrow.

proc TTY_down {} {
	global TTY
	uplevel c
	if {$TTY(commandlist)!= ""} {
		TTY_removespace
	}
	if {$TTY(pointer) != 0} {
		incr TTY(pointer) -1
		set TTY(index) [expr [llength $TTY(commandlist) - $TTY(pointer)]]
		set TTY(command) [lindex $TTY(commandlist) $TTY(index)]
		puts -nonewline $TTY(command)
	}
}
		
			

# Remove the most recent command string from the standard output. Call the
# global variables command and command_list For every character of the
# command contents, which has been printed to the screen, Set the command
# to be one less character, and put a back space.
proc TTY_removespace {} {
	global TTY
	for {set i 0} {$i < [expr [string length $TTY(command)] - $TTY(pointer)]} {incr i} {
		puts -nonewline "\x08\x20\x08"
	}
}






# Insert takes a new character, assuming the cursor has navigated to somewhere
# within the text in the command line and inserts this character into the
# text by saving the original command, removing it, rewriting it, and
# printing the new command with the inserted character to the screen

proc TTY_insert {c} {
	global TTY
	if {$TTY(pointer) < [string length $TTY(command)]} {
		set TTY(index) [expr [string length $TTY(command)] - $TTY(pointer)]
		append TTY(newcommand) [string range $TTY(command) 0 [expr $TTY(index) -1]]
		append TTY(newcommand) $c
		append TTY(newcommand) [string range $TTY(command) $TTY(index) end]	
		TTY_removespace
 		set TTY(command) "$TTY(newcommand)"
	} else {
		append TTY(newcommand) $c
		append TTY(newcommand) $TTY(command)
		TTY_removespace_cmd
		set TTY(command) "$TTY(newcommand)"
	}
	set TTY(newcommand) ""
}

# Console left navigates through the command line, incrementing the leftstate
# variable to keep track of the location of the cursor. The left cursor
# cannot move any more spaces to the left if it is in front of the command
# line text.
proc TTY_left {} {
	global TTY
	if {$TTY(pointer) < [string length $TTY(command)]} {
		puts -nonewline "\x08"
		incr TTY(pointer)
	}
	
}


# Creates a backspace (moves the cursor one place to the left) in text command
# line.
proc TTY_delete {} {
	puts -nonewline "\x08\x20\x08"
}

proc TTY_backspace {} {
	puts -nonewline "\x08"
}
# Deletes the prveious character in the text command line.


# If deleting in the middle of a string:
# Set the index to point to the character being deleted. Append to a new command
#the first half of the string up to the character, and the second half of the string which is 
#after the character. Remove all of the characters from the command line, and print 
#this new command to the string. Set the left stys

#Right arrow decrements the leftstate, removes the entire command from the
#screen, rewrites it, then navigates the cursor to the new spot in the text
#(one space to the right)

proc TTY_right {} {
	global TTY
	TTY_removespace
	puts -nonewline $TTY(command)
	incr TTY(pointer) -1 
	if {$TTY(pointer) > 0} {
		for {set i 0} {$i < $TTY(pointer)} {incr i} {
			TTY_backspace
		}
	}
}



