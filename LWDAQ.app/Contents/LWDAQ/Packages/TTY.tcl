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
package provide TTY 1.3

# Clear the global EDF array if it already exists.
if {[info exists TTY]} {unset TTY}

# Initialize the TTY global array.
set TTY(prompt) "% "
set TTY(command) ""
set TTY(state) "insert"
set TTY(commandlist) ""
set TTY(pointer) "0"
set TTY(index) "0"
set TTY(newcommand) ""
set TTY(cursor) "0"
set TTY(p) ""
set TTY(saved) [eval exec [auto_execok stty] -g]

#
# TTY_start calls the global TTY array, and uses the stty command to
# reconfigure the terminal so that any characters entered are not echoed by
# the terminal and are passed into the input channel buffer. We configure the
# standard input channel so that the I//O will flush the channel for every
# character pressed. The channel becomes readable when a string of text is
# ready to be read out of it.
#

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

#
# TTY_execute is called when the stdin channel is readable. It processes all
# characters sent through the stdin. If the characters are not new line
# characters, it will take the ascii value of every character that is entered
# into stdin.   In order to interpret more complex ascii characters, this
# procedure uses a state machine to trigger specific commands that respond to
# different ascii values. For example,for the ascii values that are denoted
# when a button is pressed, the state machine reads each character, adjusting
# its state each time in accordance with the corresponding ascii value.
# Eventually, a combination of specific ascci characters will result in a
# specific command. If the ascii characters coming through stdin are not
# significant enough to change the state, they are interpreted as normal
# characters and appended to the command variable, and printed to the screen.
# When a new line character is received, the command is executed.  Right
# before the command is executed,  the terminal is reconfigured to its
# initial state, in case the shell freezes and we need to use CTRL-C to exit.
# Once the command is executed, the terminal is set back to being "raw", the
# value of the command is returned, the state is set to insert, the command
# is added to the command list, and the command variable is cleared.
#

proc TTY_execute {} {
	global TTY
	if {[catch {
		set c [read stdin 1]
		if {$c == "\n"} {
			puts stdout ""
			eval exec [auto_execok stty] $TTY(saved)
			set result [uplevel $TTY(command)]
			eval exec [auto_execok stty] raw -echo 
			if {$TTY(command) != ""} {
				lappend TTY(commandlist) $TTY(command)
			}
			set TTY(pointer) "0"	
			set TTY(command) ""
			set TTY(cursor) "0"
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
						if {$TTY(cursor) > 0} {
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
				if {$ascii == 9} {
					foreach cmd $TTY(commmandlist) {
						if {string equal $cmd $TTY(command)} {
							puts }}
					}
				if {$ascii == 3} {
					exec stty -raw echo
					exit
				} elseif {$ascii == 27} {
					set TTY(state) "escape"
				} elseif {$ascii == 127} {
					TTY_delete
				} else {
					if {$TTY(cursor)>0} {
						TTY_insert $c
						for {set i 0} {$i < $TTY(cursor)} {incr i} {
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
		eval exec [auto_execok stty] raw -echo 
		puts "ERROR: $error_result"
		lappend TTY(commandlist) $TTY(command)
		set TTY(command) ""
		puts -nonewline $TTY(prompt)
		set TTY(cursor) "0"
		set TTY(pointer) "0"
		TTY_clear
		set TTY(state) "insert"
	}

	flush stdout
}






#
# TTY_clear is used when you want to get rid of all of the text in the command
# line, while your cursor is not at the end of the text line. It does so by
# removing every character to the left of the cursor, then printing the
# previous command text to the text line, which sets the cursor back to zero.
# From here, the remove space character is able to remove every character
# from the left of the cursor, which happens to be every character in the
# command line.
#

proc TTY_clear {} {
	global TTY
	TTY_removespace
	puts -nonewline $TTY(command)
	set save $TTY(cursor)
	set TTY(cursor) "0"
	TTY_removespace
	set TTY(cursor) "$save"
}	

#
# TTY_up handles the up arrow. It allows you to  navigate through your previous
# commands that have been added to the TTY(commandlist) list. The pointer is
# set to zero any time a new line character is recieved, and as long as the
# pointer is less than the length of the command list, you clear the command
# line and print the command that is located at the point in the command list
#  determined by the pointer.
#

proc TTY_up {} {
	global TTY
	if {$TTY(commandlist) != ""} {
		if {$TTY(pointer) != [llength $TTY(commandlist)]} {
			TTY_clear
			set TTY(command) [lindex $TTY(commandlist) end-$TTY(pointer)]
			puts -nonewline $TTY(command)
			incr TTY(pointer)
		}
	}
}	

#
# TTY_down handles the down arrow. It uses the pointer to point to the more
# recent command in the command list, functions in an opposing manner to the
# TTY_up procedure.
#

proc TTY_down {} {
	global TTY
	if {$TTY(pointer) != 0} {
		TTY_clear
		incr TTY(pointer) -1
		set TTY(command) [lindex $TTY(commandlist) [expr [llength $TTY(commandlist)] - $TTY(pointer)]]
		puts -nonewline $TTY(command)
	}
}
		
#
# TTY_removespace removes whatever command line text is to the left of your cursor. The cursor
# position, subtracted from the string length of the command denotes the
# number of back spaces to do.
#

proc TTY_removespace {} {
	global TTY
	for {set i 0} {$i < [expr [string length $TTY(command)] - $TTY(cursor)]} {incr i} {
		puts -nonewline "\x08\x20\x08"
	}
}

#
# TTY_insert takes a new character, assuming the cursor has navigated to somewhere
# within the text in the command line and inserts this character into the
# text by saving the original command, removing it, rewriting it, and
# printing the new command with the inserted character to the screen
#

proc TTY_insert {c} {
	global TTY
	if {$TTY(command) != ""} {
		if {$TTY(cursor) < [string length $TTY(command)]} {
			set TTY(index) [expr [string length $TTY(command)] - $TTY(cursor)]
			append TTY(newcommand) [string range $TTY(command) 0 [expr $TTY(index) -1]]
			append TTY(newcommand) $c
			append TTY(newcommand) [string range $TTY(command) $TTY(index) end]	
			TTY_removespace
	 		set TTY(command) "$TTY(newcommand)"
		} else {
			append TTY(newcommand) $c
			append TTY(newcommand) $TTY(command)
			TTY_removespace
			set TTY(command) "$TTY(newcommand)"
		}
	} else {
			TTY_clear
		}
	puts -nonewline $TTY(command)
	set TTY(newcommand) ""
}

#
# TTY_left navigates through the command line, incrementing the cursor
# variable to keep track of the location of the cursor. The left cursor
# cannot move any more spaces to the left if it is in front of the command
# line text.
#

proc TTY_left {} {
	global TTY
	if {$TTY(cursor) < [string length $TTY(command)]} {
		puts -nonewline "\x08"
		incr TTY(cursor)
	}
	
}

#
# TTY_delete allows you to delete any character from the command line text.
# From inside a text line: By saving the value of the cursor as the "index",
# this proc clears all characters from the command line. It then copies the
# characters to the left and to the right of the delete index to a new
# command variable. Then, set the command to this newcommand. Print to the
# screen, and navigate back through the text to the new cursor position. When
# deleting from a cursor position of zero (end of the command line text), you
# may delete up to the prompt, which is done by only allowing the backspace
# procedure to occur if the command exists.
#

proc TTY_delete {} {
	global TTY 
	if {$TTY(cursor) > 0} {
		set TTY(index) [expr [string length $TTY(command)] - $TTY(cursor)]
		if {$TTY(index) > 0} {
			TTY_clear
			append TTY(newcommand) [string range $TTY(command) 0 [expr $TTY(index) -2]]
			append TTY(newcommand) [string range $TTY(command) [expr $TTY(index)] end]
			set TTY(command) "$TTY(newcommand)"
			puts -nonewline $TTY(command)
			incr TTY(cursor)) -1 
			if {$TTY(cursor) > 0} {
				for {set i 0} {$i < $TTY(cursor)} {incr i} {
					TTY_backspace
				}
			}
		}

	} elseif {$TTY(cursor) == 0} {
		if {[string length $TTY(command)] > 0} {
			puts -nonewline "\x08\x20\x08"
			if {[string length $TTY(command)] >= 3} {
				set TTY(command) [string range $TTY(command) 0 end-1]
			} elseif {[string length $TTY(command)] == 2} {
				set TTY(command) [string index $TTY(command) 0]
			} elseif {[string length $TTY(command)] == 1} {
				set TTY(command) ""
			}
		}
	}	
	
	set TTY(newcommand) ""
	
}

#
# TTY_backspace deletes the prveious character in the text command line.
#

proc TTY_backspace {} {
	puts -nonewline "\x08"
}


#
# TTY_right decrements the cursor value, by removeting the entire command
# from the screen, rewriting it, and then navigating the cursor to the new
# spot in the text(one space to the right)
#

proc TTY_right {} {
	global TTY
	TTY_clear
	puts -nonewline $TTY(command)
	incr TTY(cursor) -1 
	if {$TTY(cursor) > 0} {
		for {set i 0} {$i < $TTY(cursor)} {incr i} {
			TTY_backspace
		}
	}
}





