# Long-Wire Data Acquisition Software (LWDAQ)
#
# Copyright (C) 2005-2021 Kevan Hashemi, Brandeis University
# Copyright (C) 2022-2024 Kevan Hashemi, Open Source Instruments Inc.
# 
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.

#
# Utils.tcl contains file input-output routines, the LWDAQ event queue,
# time and date routines, debug and diagnostic routines, and the manual
# routines. The LWDAQ Event Queue is an event scheduler that allows us
# to perform simultaneous live data acquisition from multiple instruments 
# by scheduling the acquision actions so they do not overlap with one another.
# The LWDAQ Scheduler, controlled by the schedule routines, allows us to
# schedule tasks in a manner similar to that of the Unix "cron" utility.
#

#
# LWDAQ_utils_init initializes the untils routines.
#
proc LWDAQ_utils_init {} {
	upvar #0 LWDAQ_Info info
	set info(quit) 0
	set info(queue_run) 0
	set info(queue_ms) 20
	set info(queue_events) [list]
	set info(current_event) "Stopped"
	
	set info(scheduled_tasks) [list]
	set info(scheduler_control) "Stop"
	set info(scheduler_increment) "5"
	set info(scheduler_window) "60"
	set info(scheduler_log) "none"
	set info(scheduler_format) {%d-%b-%Y %H:%M:%S}
	
	set info(reset) 0

	set info(vwait_var_names) [list]
	set info(max_vwait_names) 100
	set info(update_ms) 10
	set info(support_ms) 500
	
	set info(tcp_timeout_ms) 5000
	set info(close_delay_ms) 5
	set info(lazy_flush) 1
	set info(open_sockets) [list]
	set info(blocking_sockets) 0
	set info(daq_wait_ms) 1000
	
	set info(basic_client_port) 1090
	set info(basic_server_port) 1090
	set info(default_basic_addr) "0.0.0.0"
	
	set info(lwdaq_client_port) 90
	set info(default_lwdaq_addr) "10.0.0.37"
	set info(lwdaq_close_string) "\x04"

	set info(daq_truncate) "1"
	set info(ndf_prefix) " ndf"
	set info(ndf_header_size) 100
	set info(ndf_string_length_addr) 12
	set info(ndf_min_data_size) 100000
	set info(ndf_string_size) 10000
	set info(ndf_record_size) 4
	
	set info(lwdaq_long_string_capacity) 300000
	
	set info(debug_log) "debug_log.txt"
}

#
# LWDAQ_quit sends quit commands to all queued processes, then exits.
#
proc LWDAQ_quit {} {
	upvar #0 LWDAQ_Info info
	LWDAQ_close_all_sockets
	set LWDAQ_Info(quit) 1
	LWDAQ_update
	exit
}

#
# LWDAQ_get_lwdaq_config takes a lwdaq_config option name and returns
# its value. We can get all the values of all options with "lwdaq_config",
# but this routine extracts one particular option value for the convenience
# of the calling routine. When we specify the option, we must not include
# the dash suffix. 
#
proc LWDAQ_get_lwdaq_config {option} {
	set cg [lwdaq_config]
	set index [lsearch $cg "-$option"]
	if {$index >= 0} {
		set value [lindex $cg [expr $index + 1]]
	} {
		error "Unrecognised option \"$option\"/"
	}
	return $value
}

#
# LWDAQ_socket_open opens a connection to a TCPIP server and returns the
# socket name. The target parameter is of the form a:b where a is an IP
# address in standard x.x.x.x format or a host name, b is an IP port
# number in decimal format. The port number can be omitted, in which case
# the routine assumes a default port number. The optional parameter is 
# the message protocol name. Supported protocols are "lwdaq" and "basic". 
# The default is "lwdaq". To get the basic protocol, specify basic when 
# you open the socket. The lwdaq protocol differs from basic in that it 
# transmits an end of transmission code when we close the socket. The 
# routines that exchange messages with lwdaq servers are in the Driver.tcl
# file, and there you will see the transmit and receive routines checking 
# the socket info to determine the socket protocol. If you open a socket
# with LWDAQ_socket_open, be sure to flush it and close it with the LWDAQ
# flush and close routines also. If you use the bare flush and close
# commands provided by Tcl, the LWDAQ socket list will become garbled.
# In some situations, mixing the bare and LWDAQ commands can lead to lost
# data, or the substitution of zeros for image data.
#
proc LWDAQ_socket_open {target {protocol ""}} {
	upvar #0 LWDAQ_Info info

	# Extract the address and port from the procedure parameters.
	regexp {([^:]+)?(:([0-9]+))?} $target match addr dummy port
	if {$protocol == ""} {set protocol "lwdaq"}
	if {[lsearch "basic lwdaq" $protocol] < 0} {
		error "unrecognised protocol \"$protocol\""
	}
	if {$port == ""} {
		if {$protocol == "lwdaq"} {set port $info(lwdaq_client_port)}
		if {$protocol == "basic"} {set port $info(basic_client_port)}
	}
	if {$addr == ""} {
		if {$protocol == "lwdaq"} {set addr $info(default_lwdaq_addr)}
		if {$protocol == "basic"} {set port $info(default_basic_addr)}
	}

	# Open an asynchronous socket, and wait for it to become writeable.
	# We do this on all platforms, regardless of whether or not they
	# can tolerate blocking sockets during data transfer.
	set sock [socket -async $addr $port]
	set vwait_var_name [LWDAQ_vwait_var_name]
	upvar #0 $vwait_var_name vwait_var
	set vwait_var \
		"Waiting for connection to $addr\:$port\."
	set cmd_id [after $info(tcp_timeout_ms) [list set $vwait_var_name \
		"Timeout waiting for $sock connection to $addr\:$port\."]]
	fileevent $sock writable [list set $vwait_var_name \
		"Received connection $sock to $addr\:$port\."]
	LWDAQ_vwait $vwait_var_name
	fileevent $sock writable {}
	after cancel $cmd_id
	set vwait_var_copy $vwait_var
	unset vwait_var
	
	# If the socket did not become writeable before the timeout,
	# or if the waiting was aborted by some other routine, close
	# the socket and report an error.
	if {![string match "Received*" $vwait_var_copy]} {
		set status [fconfigure $sock -error]
		catch {close $sock}
		error "$vwait_var_copy $status"
	}
	
	# A socket error other than a timeout causes the socket to 
	# become writeable, so we now check to see if the socket
	# has become writeable as a result of an error, or whether
	# it is indeed ready to receive data.
	set status [fconfigure $sock -error]
	if {$status != ""} {
		catch {close $sock}
		error "Failed to connect to $addr\:$port, $status"
	}
	
	# If this platform and tcl version requires blocking sockets
	# to avoid crashing or freezing, set the socket to block
	# program activity during reads and writes. We configure
	# the socket as a conduit for binary data, rather than eol-
	# delimited text lines using "-translation binary".
	fconfigure $sock \
		-translation binary \
		-blocking $info(blocking_sockets) \
		-buffering full
		
	# Create socket info for lwdaq connections.
	if {$protocol == "lwdaq"} {
		set sock_info "$sock $addr $port lwdaq client"
	} 
	
	# Create socket info for basic connections.
	if {$protocol == "basic"} {
		set sock_info "$sock $addr $port basic client"
	} 
	
	# Add the socket info to the LWDAQ socket list and return its name.
	lappend info(open_sockets) $sock_info
	
	return $sock
}

#
# LWDAQ_socket_protocol determines the message protocol in use on a socket.
#
proc LWDAQ_socket_protocol {sock} {
	global LWDAQ_Info
	
	set i [lsearch $LWDAQ_Info(open_sockets) "$sock *"]
	if {$i >= 0} {
		set protocol [lindex $LWDAQ_Info(open_sockets) $i end-1]
	} {
		set protocol "basic"
	}
	
	return $protocol
}

#
# LWDAQ_socket_listen opens a server socket for listening on the specified port
# on the local machine. You specify an acceptance procedure that TCL will call
# when the server accepts a new connection.
#
proc LWDAQ_socket_listen {{accept ""} {port ""}} {
	global LWDAQ_Info
	if {$port == ""} {set port $LWDAQ_Info(basic_server_port)}
	if {$accept == ""} {set accept LWDAQ_socket_accept}
	if {[llength $accept] != 1} {
		error "cannot use \"$accept\" procedure to accept connections"
	}
	set sock [socket -server $accept $port]
	lappend LWDAQ_Info(open_sockets) "$sock 0.0.0.0 $port basic listening"
	return $sock
}

#
# LWDAQ_socket_accept is an example socket acceptance routine. It sets up the
# socket to call LWDAQ_socket_interpreter whenever a new line of data arrives
# from the socket.
#
proc LWDAQ_socket_accept {sock addr port} {
	global LWDAQ_Info
	lappend LWDAQ_Info(open_sockets) "$sock $addr $port basic server"
	fconfigure $sock -translation auto -buffering line
	fileevent $sock readable [list LWDAQ_socket_interpreter $sock]
	return ""
}

#
# LWDAQ_socket_interpreter is an example socket interpreter. It calls the LWDAQ
# socket closing routine to make sure that the open_sockets list is kept up to
# date.
#
proc LWDAQ_socket_interpreter {sock} {
	if {[eof $sock] || [catch {gets $sock line}]} {
		LWDAQ_socket_close $sock
	} {
		puts "$sock received \"$line\""
	}
	return ""
}

#
# LWDAQ_socket_close closes a socket if it exists. If the socket is listed in
# the LWDAQ open sockets list, this routine will remove the socket from the
# list. If the socket is a LWDAQ client, the routine sends an end of
# transmission character before closing the socket, and also applies a delay of
# a few milliseconds afterwards to give LWDAQ Drivers with older software time
# to get ready to accept another connection. Use this routine to close sockets
# opened by LWDAQ_socket_open. The routine always returns an empty string.
#
proc LWDAQ_socket_close {sock} {
	global LWDAQ_Info
	set sl [list]
	set i [lsearch $LWDAQ_Info(open_sockets) "$sock *"]
	if {$i >= 0} {
		set sock_info [lindex $LWDAQ_Info(open_sockets) $i]
		set LWDAQ_Info(open_sockets) [lreplace $LWDAQ_Info(open_sockets) $i $i]
	} {
		set sock_info ""
	}
	catch {
		if {[string match "*lwdaq client*" $sock_info]} {
			puts -nonewline $sock $LWDAQ_Info(lwdaq_close_string)
		}
		close $sock
		if {[string match "*lwdaq client*" $sock_info]} {
			LWDAQ_wait_ms $LWDAQ_Info(close_delay_ms)
		}
	}
	
	return ""
}

#
# LWDAQ_close_all_sockets closes all open sockets and returns an empty string.
#
proc LWDAQ_close_all_sockets {} {
	global LWDAQ_Info
	foreach sockinfo $LWDAQ_Info(open_sockets) {
		LWDAQ_socket_close [lindex $sockinfo 0]
	}
	return ""
}

#
# LWDAQ_socket_flush flushes output from a socket. Use this routine with a
# socket opened by LWDAQ_socket_open, but not with sockets opened with the bare
# Tcl socket command.
#
proc LWDAQ_socket_flush {sock} {
	if {[catch {flush $sock} error_result]} {
		error "cannot flush socket, $error_result"
	}
	return ""
}

#
# LWDAQ_socket_read_partial is designed to be called by a readable file event
# during a non-blocking read operation. We pass it the total size of the data
# block we want to assemble, the name of a unique global data buffer, and the
# name of a unique global vwait status message. If the size is "line", rather
# than an integer, we read all available bytes. Otherwise we try to read as many
# bytes as we need to complete "size" bytes, knowing how many bytes we have so
# far accumulated in the data buffer. The routine first checks the status of the
# socket, because the socket may have generated a "readable" event because the
# peer closed the socket. In the event of an error, the routine sets the status
# message with an error description and returns without reading the socket.
# Otherwise, it reads and appends the data it reads to the data buffer. It
# returns and empty string to indicate no error.
#
proc LWDAQ_socket_read_partial {sock size data_name vwait_var_name} {
	global LWDAQ_Info
	upvar #0 $data_name data
	upvar #0 $vwait_var_name vwait_var

 	set status [fconfigure $sock -error]
	if {$status != ""} {set vwait_var "socket error, $status"}
	if {![string match "Reading*" $vwait_var]} {return ""}
	
	if {[string is integer $size]} {
 		set vwait_var "Reading [expr $size - [string length $data]]\
 			of $size bytes from $sock"
		set new_data [read $sock [expr $size - [string length $data]]]
	} {
 		set vwait_var "Reading characters from $sock"
		set new_data [read $sock 1]
	}
	if {[string length $new_data] > 0} {
		append data $new_data
	}
	return ""
}

#
# LWDAQ_socket_read reads $size bytes from the input buffer of $sock. If the
# blocking_sockets flag is set, LWDAQ will freeze while the read takes place.
# But if this same flag is cleared, LWDAQ will read the data as it arrives, and
# while it is waiting, it will respond to menu and window events. The routine
# collects all the necessary fragments together and returns them. Use this
# routine with sockets opened by the LWDAQ_socket_open command. If the size
# parameter is not an integer, but instead the word "line", we read characters
# from the socket until we get a newline character. In all cases, if the peer
# closes the socket, or some other interruption occurs, the routine generates a
# Tcl error and returns an informative error message. During non-blocking
# reads, this routine uses LWDAQ_socket_read_partial.
#
proc LWDAQ_socket_read {sock size} {
	global LWDAQ_Info
	
	# Check to see if the socket has any problems. If it does, we abandon the
	# read, close the socket, and report and error that includes the socket
	# status, if the socket exists.
	if {[catch {set status [fconfigure $sock -error]} error_result]} {
		error "socket error, $error_result"
	}
	if {$status != ""} {
		LWDAQ_socket_close $sock
		error "broken socket, $status"
	}

	# We flush the socket to make sure we send any data that might provoke the
	# return of our data.
	LWDAQ_socket_flush $sock

	# Non-blocking sockets are our default and preferred style of socket. As we
	# read from them, we are able to update windows, respond to mouse events,
	# and accept a command to abort the read. Our objective is to read "size"
	# bytes from the socket, but we do not want to attempt the read until at
	# least one byte of data is available in the socket. Any time there is data
	# available in the socket, we will read all the data from the socket, or as
	# much as we need to complete "size" bytes of data, whichever is less. When
	# data is available in the socket, the Tcl event loop generates a "readable"
	# file event for the socket. We associate with this event our partial-read
	# routine, which append the new data to our accumulating block of "size"
	# bytes. When we have all the bytes we want, we dissociate our partial-read
	# routine from the socket's "readable" event, and return the data. Error
	# handling takes place in the read loop, where we reset a timeout delay
	# every time we see more data arrive, and in the partial read routine, where
	# we check the status of the socket before reading. If the peer closes the
	# socket, this generates a "readable" event, but the socket status will be
	# an error message. The error messages will be recorded in a global, unique
	# vwait variable. We use the LWDAQ vwait_var_name routine to generate this
	# variable name, because all such variables are automatically displayed in
	# our System Monitor panel, which allows us to watch the progress of the
	# unblocking socket read.
	if {!$LWDAQ_Info(blocking_sockets) && [string is integer $size]} {
		fconfigure $sock -buffering full -translation binary
		set vwait_var_name [LWDAQ_vwait_var_name]
		set data_name $sock\_data
		upvar #0 $vwait_var_name vwait_var
		upvar #0 $data_name data
		set vwait_var "Reading $size bytes from $sock"
		set data ""
		fileevent $sock readable \
			[list LWDAQ_socket_read_partial $sock $size $data_name $vwait_var_name]
		set cmd_id [after $LWDAQ_Info(tcp_timeout_ms) \
			[list set $vwait_var_name \
			"Timeout reading $size bytes from $sock"]]
		while {[string length $data] < $size} {
			LWDAQ_vwait $vwait_var_name
			if {![string match "Reading*" $vwait_var]} {break}
			after cancel $cmd_id
			set cmd_id [after $LWDAQ_Info(tcp_timeout_ms) \
				[list set $vwait_var_name \
					"Timeout reading [expr $size - [string length $data]]\
 					of $size bytes from $sock"]]
		}
		fileevent $sock readable {}
		after cancel $cmd_id
		set vwait_var_copy $vwait_var
		unset vwait_var
		if {![string match "Reading*" $vwait_var_copy]} {
			LWDAQ_socket_close $sock
			error "$vwait_var_copy"
		}
	}

	# When we work with a non-blocking socket and we have a non-integer size,
	# our approach is almost identical to our binary read, except we read one
	# character at a time until we encounter a newline. We configure our
	# partial-read routine for the single-character reading by passing a
	# non-integer string for the size argument. This non-blocking line read is
	# intended for text strings no more than one or two hundred characters long,
	# so we are not concerned about the inefficiency of reading one character at
	# a time, nor of repeatedly checking to see if our string contains a newline
	# character.
	if {!$LWDAQ_Info(blocking_sockets) && ![string is integer $size]} {
		fconfigure $sock -buffering full -translation binary
		set vwait_var_name [LWDAQ_vwait_var_name]
		set data_name $sock\_data
		upvar #0 $vwait_var_name vwait_var
		upvar #0 $data_name data
		set vwait_var "Reading line from $sock"
		set data ""
		fileevent $sock readable \
			[list LWDAQ_socket_read_partial $sock $size $data_name $vwait_var_name]
		set cmd_id [after $LWDAQ_Info(tcp_timeout_ms) \
			[list set $vwait_var_name \
			"Timeout reading line from $sock"]]
		while {![regexp {\n} $data]} {
			LWDAQ_vwait $vwait_var_name
			if {![string match "Reading*" $vwait_var]} {break}
			after cancel $cmd_id
			set cmd_id [after $LWDAQ_Info(tcp_timeout_ms) \
				[list set $vwait_var_name \
					"Timeout reading line from $sock"]]
		}
		set data [string trim $data]
		fileevent $sock readable {}
		after cancel $cmd_id
		set vwait_var_copy $vwait_var
		unset vwait_var
		if {![string match "Reading*" $vwait_var_copy]} {
			LWDAQ_socket_close $sock
			error "$vwait_var_copy"
		}
	}

	# We use blocking sockets only for diagnostic purposes. A blocking socket
	# that encounters any sort of network interruption, such as unplugging the
	# peer's ethernet cable, will freeze our application until the connection
	# is restored. Here we read an integer number of binary bytes from a blocking
	# socket.
	if {$LWDAQ_Info(blocking_sockets) && [string is integer $size]} {
		fconfigure $sock -buffering full -translation binary
		set data [read $sock $size]
		if {[string length $data] != $size} {
			LWDAQ_socket_close $sock
			error "failed to read from socket"
		}	
	} 
	
	# We can also read to a newline character from a blocking socket, and for this
	# we configure the socket for line buffering and character translation. Our
	# assumption is that we will be reading a line of text. We recommend using 
	# blocking sockets only for diagnostic purposes.
	if {$LWDAQ_Info(blocking_sockets) && ![string is integer $size]} {
		fconfigure $sock -buffering line -translation auto
		set data [gets $sock]
		fconfigure $sock -buffering full -translation binary
	} 

	return $data
} 

#
# LWDAQ_socket_write sends data to a socket's output buffer. Normally, 
# we don't send out our data until the buffer is full or we are about 
# to read from the socket. We call this 'lazy flushing'. Sending many 
# instructions in one data packet is more efficient, and we get to use 
# the TCP/IP buffer as a place to construct the string of commands. 
# But if we want to see what is happening on the driver, we might want 
# to send instructions to the LWDAQ Relay immediately. In that case, we 
# set the lazy_flush flag to zero. We must make sure puts does not add 
# a newline character to the end of every binary array it sends. Use 
# this routine with sockets opened by LWDAQ_socket_open.
#
proc LWDAQ_socket_write {sock data} {
	global LWDAQ_Info
	if {[catch {
		puts -nonewline $sock $data
		if {!$LWDAQ_Info(lazy_flush)} {flush $sock}
		set status [fconfigure $sock -error]
		if {$status != ""} {error $status}
	} error_result]} {
		LWDAQ_socket_close $sock
		error "failed writing to $sock, $error_result"
	}
	return ""
}

#
# LWDAQ_socket_upload opens a socket to a server, writes a data string to the
# socket, and closes the socket. The target parameter is of the form a:b where a
# is an IP address in standard x.x.x.x format or a host name, b is an IP port
# number in decimal format. The routine treats the string as a binary object and
# transmits it without a carriage return at the end.
#
proc LWDAQ_socket_upload {target data} {
	set sock [LWDAQ_socket_open $target basic]
	LWDAQ_socket_write $sock $data
	LWDAQ_socket_close $sock
	return ""
}

#
# LWDAQ_ip_addr_match takes two IP address strings and compares them to see if
# they point to the same driver socket. If the addresses match, the routine
# returns a 1. If they don't match, it returns a 0. A * in either parameter is a
# wild card, and will match.
#
proc LWDAQ_ip_addr_match {addr_1 addr_2} {
	global LWDAQ_Info
	if {[string match $addr_1 $addr_2]} {return 1}
	if {[string match $addr_2 $addr_1]} {return 1}
	regexp {([^:]+)?(:([0-9]+))?} $addr_1 match ipa_1 d1 ipp_1
	if {$ipa_1 == ""} {set ipa_1 $LWDAQ_Info(default_client_addr)}
	if {$ipp_1 == ""} {set ipp_1 $LWDAQ_Info(lwdaq_client_port)}
	regexp {([^:]+)?(:([0-9]+))?} $addr_2 match ipa_2 d1 ipp_2
	if {$ipa_2 == ""} {set ipa_2 $LWDAQ_Info(default_client_addr)}
	if {$ipp_2 == ""} {set ipp_2 $LWDAQ_Info(lwdaq_client_port)}
	if {[string match "$ipa_1\:$ipp_1" "$ipa_2\:$ipp_2"]} {return 1}
	return 0
}


#
# LWDAQ_queue_start starts the event queue if it's not running already.
#
proc LWDAQ_queue_start {} {
	global LWDAQ_Info
	if {!$LWDAQ_Info(queue_run)} {
		set LWDAQ_Info(queue_run) 1
		after $LWDAQ_Info(queue_ms) LWDAQ_queue_step
	}
	return ""
}

#
# LWDAQ_queue_step takes the first event out of the event queue deletes it,
# executes it, and posts itself to execute again after a delay of queue_ms.
#
proc LWDAQ_queue_step {} {
	global LWDAQ_Info
	
	# If we have pending events, take the first one out of the queue, remove
	# it from the pending list and execute it at the global scope. If we
	# encounter an error, report the error with the queue error procedure.
	if {[llength $LWDAQ_Info(queue_events)] > 0} {
		set LWDAQ_Info(current_event) [lindex $LWDAQ_Info(queue_events) 0]
		set LWDAQ_Info(queue_events) [lreplace $LWDAQ_Info(queue_events) 0 0]
		if {[catch {
			uplevel #0 $LWDAQ_Info(current_event)
		} error_result]} {
			LWDAQ_queue_error $LWDAQ_Info(current_event) $error_result
		}
	} 
	
	# If we have events waiting, we set the current even to the reserved
	# Wait event, which will appear in the System Monitor to show we are
	# waiting to step to the next queue event. If there are no events waiting,
	# the queue will be Idle.
	if {[llength $LWDAQ_Info(queue_events)] > 0} {
		set LWDAQ_Info(current_event) "Wait"
	} {
		set LWDAQ_Info(current_event) "Idle"
	}
	
	# Run this routine again in queue_ms, or stop and set the current event
	# to the reserved word Stop.
	if {$LWDAQ_Info(queue_run)} {
		after $LWDAQ_Info(queue_ms) LWDAQ_queue_step
	} {
		set LWDAQ_Info(current_event) "Stop"
	}

	# We always return an empty string.
	return ""
}

#
# LWDAQ_queue_stop stops the LWDAQ event manager.
#
proc LWDAQ_queue_stop {} {
	global LWDAQ_Info
	set LWDAQ_Info(queue_run) 0
	return ""
}

#
# LWDAQ_queue_clear clears the event queue of any events matching
# the globular matching string passed into the routine. By default, the
# routine clears all events from the queue.
#
proc LWDAQ_queue_clear { {pattern "*"} } {
	global LWDAQ_Info
	set newlist [list]
	foreach event $LWDAQ_Info(queue_events) {
		if {![string match $pattern $event]} {
			lappend newlist $event
		}
	}
	set LWDAQ_Info(queue_events) $newlist
	return ""
}

#
# LWDAQ_post adds the $event script to the LWDAQ Manager event list. If you set
# the optional parameter "place" to "front" or "1", the the event gets added to
# the front of the queue, in first place. If "place" is "end" or "0", the event
# is added to the end of the queue. If "place" is any other positive integer
# greater than zero, the event is inserted into the queue in the position given
# by the integer, or the end of the queue if no such position exists.
#
proc LWDAQ_post {event {place "end"}} {
	global LWDAQ_Info

	if {($place == "front") || ($place == "1")} {
		set new_event_list [list $event]
		foreach e $LWDAQ_Info(queue_events) {
			lappend new_event_list $e
		}
		set LWDAQ_Info(queue_events) $new_event_list
	} elseif {($place == "end") || ($place == "0")} {
		lappend LWDAQ_Info(queue_events) $event
	} elseif {[string is integer -strict $place]} {
		if {($place > 0) || ($place <= [llength $LWDAQ_Info(queue_events)])} {
			set new_event_list [lrange $LWDAQ_Info(queue_events) 0 [expr $place-1]]
			lappend new_event_list $event
			foreach e [lrange $LWDAQ_Info(queue_events) $place end] {
				lappend new_event_list $e
			}
			set LWDAQ_Info(queue_events) $new_event_list
		} else {
			lappend LWDAQ_Info(queue_events) $event	
		}
	} else {
		lappend LWDAQ_Info(queue_events) $event
	}
		
	return ""
}

#
# LWDAQ_queue_error displays an error for the event queue.
#
proc LWDAQ_queue_error {event error_result} {
	global errorInfo LWDAQ_Info
	if {$LWDAQ_Info(gui_enabled)} {
		set w [LWDAQ_toplevel_text_window 100 10]
		wm title $w "Event Manager Error Report, LWDAQ $LWDAQ_Info(program_patchlevel)"
		LWDAQ_print $w.text "ERROR: $error_result"
		LWDAQ_print $w.text "EVENT: \"$event\""
		if {[info exists errorInfo]} {
			LWDAQ_print $w.text "DETAILS: " blue
			LWDAQ_print $w.text $errorInfo blue
		} 
	} {
		puts stdout "ERROR: \"$error_result\""
		if {[info exists errorInfo]} {
			puts stdout $errorInfo
		} {
			puts stdout "No error information available."
		}
	}
	return ""
}

#
# LWDAQ_report_error displays an error.
#
proc LWDAQ_report_error {task message} {
	global errorInfo LWDAQ_Info
	if {$LWDAQ_Info(gui_enabled)} {
		set w [LWDAQ_toplevel_text_window 100 10]
		wm title $w "Error Report, LWDAQ $LWDAQ_Info(program_patchlevel)"
		LWDAQ_print $w.text "ERROR: $message"
		LWDAQ_print $w.text "WHILE: \"$task\""
		if {[info exists errorInfo]} {
			LWDAQ_print $w.text "DETAILS: " blue
			LWDAQ_print $w.text $errorInfo blue
		}
	} {
		puts stdout "ERROR: \"$message\""
		if {[info exists errorInfo]} {
			puts stdout $errorInfo
		}
	}
	return ""
}

#
# LWDAQ_scheduler takes a schedule of tasks and executes the tasks at their
# scheduled times. The tasks and schedules are stored in the global
# "scheduled_tasks" list. Each list entry consists of four elements. The first
# element is the name of the task. The second element is its schedule of
# execution. We define schedules in the same format as Unix "crontab files". The
# schedule string consists of five values separated by spaces. They are: minute
# (0-59), hour (0-23), day of month (1-31), month (1-12), and day of week (0-6,
# Sunday is 0). A wildcard character, "*", for a constraint means the constraint
# will be ignored. We have "0 23 * * *" schedules Daily at 11 PM, "30 22 * * *"
# schedules Daily at 22:30, "0 23 1 * *" schedules every first day of the month
# at 23:00, "0 23 * * 0" schedules every Sunday at 23:00. If the string is all
# stars, the scheduler never executes the task, so "* * * * *" means "never".
# The third element is the Tcl script that the scheduler will run when the
# specified minute arrives, or soon after it arrives. The fourth element is the
# most recent time the task was executed, in Unix seconds. If the scheduler
# misses the scheduled time by less than "scheduler_window" seconds, the
# scheduler will execute the task, otherwise it will skip the task. The
# scheduler accepts an optional parameter "next_check" that specifies the next
# second in which the scheduler should check for tasks that need to be started.
# We start the scheduler by calling it with not parameters, or with a zero
# argument. We stop it with a negative argument. If the scheduler's log name is
# not an empty string, we use it as the name of a channel or file to which we
# append notifications of tasks run by the scheduler. To add and subtract tasks
# from the scheduler's list, we use the schedule_task and unschedule_task
# routines defined below. The schedule routine starts the scheduler if it is not
# running already. The unschedule routine stops the scheduler if there are no
# tasks in the list. Thus we interact with the scheduler through these schedule
# and unschedule routines, rather than by calling the scheduler routine itself.
#
proc LWDAQ_scheduler {{next_check "0"}} {
	global LWDAQ_Info
	
	set now [clock seconds]
	
	if {$next_check < 0} {
		set LWDAQ_Info(scheduler_control) "Stop"
		return "Stop"
	} elseif {$next_check == 0} {
		if {$LWDAQ_Info(scheduler_control) == "Stop"} {
			set next_check $now
			if {$LWDAQ_Info(scheduler_log) != "none"} {
				LWDAQ_print $LWDAQ_Info(scheduler_log) "Started scheduler at\
					[clock format [clock seconds] \
					-format $LWDAQ_Info(scheduler_format)]."
			}
			set LWDAQ_Info(scheduler_control) "Run"
		} else {
			return "Run"
		}
	} elseif {$LWDAQ_Info(scheduler_control) == "Stop"} {
		if {$LWDAQ_Info(scheduler_log) != "none"} {
			LWDAQ_print $LWDAQ_Info(scheduler_log) "Stopped scheduler at\
					[clock format [clock seconds] \
					-format $LWDAQ_Info(scheduler_format)]."
		}
		return "Stop"
	} elseif {$now < $next_check} {
		LWDAQ_post [list LWDAQ_scheduler $next_check]
		return "Run"
	} else {
		set min [scan [clock format $now -format %M] %d]
		set hr [scan [clock format $now -format %H] %d]
		set dymo [scan [clock format $now -format %d] %d]
		set mo [scan [clock format $now -format %m] %d]
		set dywk [expr [clock format $now -format %u] % 7]
		global t
		set index -1
		foreach task $LWDAQ_Info(scheduled_tasks) {
			incr index
			set name [lindex $task 0]
			scan [lindex $task 1] %s%s%s%s%s schmin schhr schdymo schmo schdywk
			if {($schmin == "*") && ($schhr == "*") && ($schdymo == "*") \
				&& ($schmo == "*") && ($schdywk == "*")} {
				continue	
			}
			set cmd [lindex $task 2]
			set previous [lindex $task 3]
			if {($schmo != "*") && ($schmo != $mo)} {continue}
			if {($schdywk != "*") && ($schdywk != $dywk)} {continue}
			if {($schdymo != "*") && ($schdymo != $dymo)} {continue}
			if {($schhr != "*") && ($schhr != $hr)} {continue}
			if {$schmin == "*"} {set schmin 0}
			set hr_start [expr ([clock seconds] / 3600) * 3600] 
			set scheduled_time [expr $hr_start + (60 * $schmin)]
			if {($now - $scheduled_time >= 0) \
				&& ($now - $scheduled_time <= $LWDAQ_Info(scheduler_window)) \
				&& (($scheduled_time - $previous) > $LWDAQ_Info(scheduler_window))} {
				lset LWDAQ_Info(scheduled_tasks) $index 3 $now
				if {$LWDAQ_Info(scheduler_log) != "none"} {
					LWDAQ_print $LWDAQ_Info(scheduler_log) "Running task $name at\
						[clock format [clock seconds] \
						-format $LWDAQ_Info(scheduler_format)]."
					LWDAQ_post $cmd
				}
			}
		}
	}
	LWDAQ_post "LWDAQ_scheduler [expr $next_check + $LWDAQ_Info(scheduler_increment)]"
	
	return ""
}

#
# LWDAQ_schedule_task adds a new task to the schedule list. If the name
# conflicts with an existing task, we replace that task with the new definition.
# If the scheduler is not running, this routine starts the scheduler. The
# routine checks the format of the task schedule to make sure all five
# constraints are specified either with an integer value or a wild card. If the
# task does not conform to our required format, we return an error.
#
proc LWDAQ_schedule_task {name schedule command} {
	global LWDAQ_Info
	
	if {[llength $schedule] != [llength "* * * * *"]} {
		error "invalid schedule \"$schedule\""
	} {
		foreach s $schedule {
			if {($s != "*") && ![string is integer -strict $s]} {
				error "invalid schedule constraint \"$s\""
			}
		}
	}
	
	set index [lsearch -index 0 $LWDAQ_Info(scheduled_tasks) $name]
	if {$index < 0} {
		lappend LWDAQ_Info(scheduled_tasks) [list $name $schedule $command 0]
	} {
		lset LWDAQ_Info(scheduled_tasks) $index [list $name $schedule $command 0]
	}
	if {$LWDAQ_Info(scheduler_log) != "none"} {
		if {$index < 0} {
			LWDAQ_print $LWDAQ_Info(scheduler_log) "Added task $name with schedule\
				\"$schedule\" at [clock format [clock seconds] \
				-format $LWDAQ_Info(scheduler_format)]."
		} {
			LWDAQ_print $LWDAQ_Info(scheduler_log) "Replaced task $name with schedule\
				\"$schedule\" at [clock format [clock seconds] \
				-format $LWDAQ_Info(scheduler_format)]."
		}
	}
	if {$LWDAQ_Info(scheduler_control) == "Stop"} {
		LWDAQ_post [list LWDAQ_scheduler 0]
	}
	return ""
}

#
# LWDAQ_unschedule_task removes the named task from the scheduler's list. If there
# are no more tasks in the list, this routine stops the scheduler.
#
proc LWDAQ_unschedule_task {name} {
	global LWDAQ_Info
	
	set index [lsearch -index 0 $LWDAQ_Info(scheduled_tasks) $name]
	if {$index >= 0} {
		set LWDAQ_Info(scheduled_tasks) \
			[lreplace $LWDAQ_Info(scheduled_tasks) $index $index]
	}
	if {[llength $LWDAQ_Info(scheduled_tasks)] == 0} {
		LWDAQ_scheduler -1
	}
	if {$LWDAQ_Info(scheduler_log) != "none"} {
		if {$index < 0} {
			LWDAQ_print $LWDAQ_Info(scheduler_log) "Unknown task \"$name\" at \
				[clock format [clock seconds] -format $LWDAQ_Info(scheduler_format)]."
		} {
			LWDAQ_print $LWDAQ_Info(scheduler_log) "Deleted task \"$name\" at \
				[clock format [clock seconds] -format $LWDAQ_Info(scheduler_format)]."
		}
	}
	return ""
}

#
# LWDAQ_ndf_create creates a new Neuroscience Data Format file, which is the
# format used by LWDAQ to store archives of continuous time-series data. The NDF
# format begins with a four-byte format identifier, which is the string " ndf"
# (note the space at the beginning of the identifier string. Next come three
# four-byte numbers in big-endian format (most significant byte first). These
# are the byte offset to meta-data space, byte offset to data space, and the
# length of meta-data string when last written. If the length is zero, routines
# that read the meta-data string should check the length for themselves. The
# header may contain additional binary information particular to the
# application. The meta-data space follows the header and contains only a
# null-terminated character string. The data space comes next, and occupies the
# remainder of the file. This routine creates a new file with an empty string
# and no data.
#
proc LWDAQ_ndf_create {file_name meta_data_size} {
	global LWDAQ_Info
	set f [open $file_name w]
	fconfigure $f -translation binary
	set header [binary format a4III \
		$LWDAQ_Info(ndf_prefix) \
		$LWDAQ_Info(ndf_header_size) \
		[expr $LWDAQ_Info(ndf_header_size) + $meta_data_size] \
		"0"]
	puts -nonewline $f $header
	set num_blank_bytes [expr $meta_data_size \
		+ $LWDAQ_Info(ndf_header_size) \
		- [string length $header]]
	set blank_bytes [binary format a$num_blank_bytes ""]
	puts -nonewline $f $blank_bytes
	close $f
	
	return ""
}

#
# LWDAQ_ndf_data_check returns the byte location of the file's data block and
# the length of the data block. If the file is not NDF, the routine returns an
# error.
#
proc LWDAQ_ndf_data_check {file_name} {
	global LWDAQ_Info

	if {![file exists $file_name]} {
		error "file $file_name does not exist"
	}
	if {[catch {
		set f [open $file_name r]
		fconfigure $f -translation binary
		set header [read $f $LWDAQ_Info(ndf_header_size)]
		seek $f 0 end
		set e [tell $f]
		close $f
	} error_message]} {
		error "file locked, $error_message"
	}
	binary scan $header a4III p m d l
	if {![info exists p]} {
		error "file \"[file tail $file_name]\" contains no header"
	}	
	if {$p != $LWDAQ_Info(ndf_prefix)} {
		error "file \"[file tail $file_name]\" is not ndf"
	}
	return "$d [expr $e - $d]"
}

#
# LWDAQ_ndf_string_check returns the byte location of the file's meta-data
# string, the maximum length of the string and the actual length of the string.
# If the file is not NDF, the routine returns an error.
#
proc LWDAQ_ndf_string_check {file_name} {
	global LWDAQ_Info

	if {![file exists $file_name]} {
		error "file $file_name does not exist"
	}
	if {[catch {
		set f [open $file_name r]
		fconfigure $f -translation binary
		set header [read $f $LWDAQ_Info(ndf_header_size)]
		close $f
	} error_message]} {
		error "file locked, $error_message"
	}
	binary scan $header a4III p m d l
	if {![info exists p]} {
		error "file \"[file tail $file_name]\" contains no header"
	}	
	if {$p != $LWDAQ_Info(ndf_prefix)} {
		error "file \"[file tail $file_name]\" is not ndf."
	}
	if {$l == 0} {
		set f [open $file_name r]
		fconfigure $f -translation binary
		seek $f $m
		set meta_data [read $f [expr $d - $m]]
		close $f
		binary scan $meta_data A* meta_data
		set l [string first "\x00" $meta_data]
		if {$l < 0} {set l [string length $meta_data]}
	}
	
	return "$m [expr $d - $m] $l"
}

#
# LWDAQ_ndf_string_write re-writes the meta-data string in an NDF-file on disk
# but leaves the data intact. The routine takes roughly 100 us to write a
# one-byte string and 1 ms to write a 10-kbyte string (on a 1.3 GHz G3 iBook).
#
proc LWDAQ_ndf_string_write {file_name meta_data} {
	global LWDAQ_Info

	scan [LWDAQ_ndf_string_check $file_name] %d%d%d location max_len actual_len
	
	set mdl [string length $meta_data]
	if {$mdl > $max_len} {
		error "trying to write $mdl bytes in space $max_len bytes"
	}

	set f [open $file_name r+]
	fconfigure $f -translation binary
	seek $f $LWDAQ_Info(ndf_string_length_addr)
	puts -nonewline $f [binary format I [string length $meta_data]]
	seek $f $location
	puts -nonewline $f $meta_data
	puts -nonewline $f "\x00"
	close $f
	
	return ""
}

#
# LWDAQ_ndf_string_read returns the meta-data string in an NDF file.
#
proc LWDAQ_ndf_string_read {file_name} {

	scan [LWDAQ_ndf_string_check $file_name] %d%d%d location max_len actual_len
	
	set f [open $file_name r]
	fconfigure $f -translation binary
	seek $f $location
	set meta_data [read $f $actual_len]
	close $f

	return $meta_data
}

#
# LWDAQ_ndf_string_append appends a meta-data string to the one that already
# exists in an NDF file. It speeds itself up by using the actual length value
# stored in the file header. It does not read the existing string from the file.
#  The routine takes roughly 100 us to append a one-byte string regardless of
# the length of the existing string, and 1 ms to append a 10-kbyte string (on a
# 1.3 GHz G3 iBook).
#
proc LWDAQ_ndf_string_append {file_name meta_data} {
	global LWDAQ_Info

	scan [LWDAQ_ndf_string_check $file_name] %d%d%d location max_len actual_len
	set mdl [string length $meta_data]
	if {[expr $mdl + $actual_len] > $max_len} {
		error "trying to append $mdl bytes to $actual_len bytes in space $max_len bytes"
	}

	set f [open $file_name r+]
	fconfigure $f -translation binary
	seek $f $LWDAQ_Info(ndf_string_length_addr)
	puts -nonewline $f [binary format I [expr $actual_len + $mdl]]
	seek $f [expr $location + $actual_len]
	puts -nonewline $f $meta_data
	puts -nonewline $f "\x00"
	close $f

	return ""
}

#
# LWDAQ_ndf_data_append appends new data to an NDF file.
#
proc LWDAQ_ndf_data_append {file_name data} {
	if {![file exists $file_name]} {
		error "file $file_name does not exist"
	}
	if {[catch {
		set f [open $file_name a]
		fconfigure $f -translation binary
		puts -nonewline $f $data
		close $f
	} error_message]} {
		error "file locked, $error_message"
	}
	
	return ""
}

#
# LWDAQ_ndf_data_read reads num_bytes of data out of an NDF file data block,
# starting at byte start_addr. The first byte in the data block is byte zero. If
# you specify * for num_bytes, the routine reads all available data bytes from
# the file. If the file does not contain the bytes requested, the routine returns
# all the bytes that can be read.
#
proc LWDAQ_ndf_data_read {file_name start_addr num_bytes} {
	scan [LWDAQ_ndf_data_check $file_name] %d%d d l
	if {$num_bytes == "*"} {set num_bytes $l}
	set f [open $file_name r]
	fconfigure $f -translation binary
	seek $f [expr $d + $start_addr]
	set data [read $f $num_bytes]
	close $f
	return $data
}

#
# LWDAQ_xml_get_list takes an xml string and extracts the list of records from
# the database that matches the specified tag. If an xml string contains one
# thousand entries delimited by <donor>...</donor>, the routine returns a TCL
# list of the contents of all the <donor> entries when we pass it the xml string
# and "donor". Each element in the list the routine returns will be the contents
# of a single record, with its start and end tags removed. You can now apply
# this same routine to each element in this list sequentially, to extract fields
# from each record.
#
proc LWDAQ_xml_get_list {xml tag} {
	set result [list]
	set index 0
	while {[regexp -start $index <$tag> $xml match]} {
		set i_start [string first "<$tag>" $xml $index]
		set i_end [string first "</$tag>" $xml $index]
		if {$i_start < 0} {break}
		if {$i_end < 0} {break}
		set field \
			[string range $xml \
				[expr $i_start + [string length "<$tag>"]] \
				[expr $i_end - 1]]
		set index [expr $i_end + [string length "</$tag>"]]
		lappend result $field
	}
	return $result
}

#
# LWDAQ_write_image_file writes an image to disk in the LWDAQ image format. If
# the file name has tail ".gif" or ".png" (case insensitive), the routine saves
# the file in GIF or PNG format respectively. If the file name ends with ".ndf",
# the routine treats the image as a container for one-dimensional data, skipping
# the first row (row zero) and starting from the first pixel of the second row
# (pixel zero of row one). Otherwise, the routine saves the image in the DAQ
# format. In a GIF, PNG and DAQ files, the LWDAQ image header, with dimensions,
# analysis bounds, and results string, will be embedded in the first line of the
# image. In an NDF file, this header information is lost. The results string is
# saved in the meta-data string. When we save to GIF and PNG we use the Tk
# built-in routines that export photos to GIF and PNG files. We draw the image
# in a Tk photo using lwdaq_draw. We make sure we draw the pixels one-to-one by
# looking up the prevailiing display_zoom value and passing its inverse to
# lwdaq_draw as an additional zoom value. We use the Tk photo's write function
# to create the GIF or PNG file. Another thing we must do when saving the GIF
# or PNG files is make sure lwdaq_draw does not draw the analysis bounds on the
# image, nor anything from the overlay.
#
proc LWDAQ_write_image_file {image_name outfile_name} {
	global LWDAQ_Info
	set file_type [string tolower [file extension $outfile_name]]
	switch -exact -- $file_type {
		".gif" {
			set p [image create photo]
			lwdaq_draw $image_name $p -show_bounds 0 -clear 1 \
				-zoom [expr 1.0/[LWDAQ_get_lwdaq_config display_zoom]]
			$p write $outfile_name -format GIF
			image delete $p
		} 
		".png" {
			set p [image create photo]
			lwdaq_draw $image_name $p -show_bounds 0 -clear 1 \
				-zoom [expr 1.0/[LWDAQ_get_lwdaq_config display_zoom]]
			$p write $outfile_name -format PNG
			image delete $p
		} 
		".ndf" {
			LWDAQ_ndf_create $outfile_name $LWDAQ_Info(ndf_string_size)
			LWDAQ_ndf_string_write $outfile_name [lwdaq_image_results $image_name]
			set data [lwdaq_image_contents $image_name \
				-truncate 0 -data_only 1 -record_size $LWDAQ_Info(ndf_record_size)]
			LWDAQ_ndf_data_append $outfile_name $data		
		}
		default {
			set outfile [open $outfile_name w]
			fconfigure $outfile -translation binary
			puts -nonewline $outfile \
				[lwdaq_image_contents $image_name \
				-truncate $LWDAQ_Info(daq_truncate)]
			close $outfile
		}
	}
	return ""
}

#
# LWDAQ_read_image_file reads an image file from disk into the lwdaq image list
# and returns its list name. If the file name ends with ".gif" (case
# insensitive), the routine reads the file as a GIF image. The gray-scale values
# in the first line of the image should, for best results, contain a DAQ image
# header. The DAQ header contains the image dimensions, the analysis bounds, and
# a result string. Two- dimensional image data begins only on the second line of
# the image. If the file name ends with ".ndf", the routine reads the file as an
# NDF (Neuroscience Data Format) file. It creates a new image that is
# approximately square, and large enough to contain the NDF data. It sets the
# image result string equal to the NDF meta-data string. It copies the NDF data
# into the image data area, which begins with the first pixel of the second row
# in the new image. If the file name ends with any other extension, the routine
# reads the image in as a DAQ file. You can specify a name for the image if you
# like, otherwise the routine will assign its own name.
#
proc LWDAQ_read_image_file {infile_name {image_name ""}} {
	global LWDAQ_Info
	set file_type [string tolower [file extension $infile_name]]
	switch -exact -- $file_type {
		".gif" {
			if {!$LWDAQ_Info(gui_enabled)} {
				error "gif format supported only with gui enabled"
			}
			set p [image create photo]
			$p read $infile_name -format GIF
			set data [lwdaq_photo_contents $p]
			image delete $p
			set image_name [lwdaq_image_create \
				-try_header 1 -data $data -name $image_name]	
		} 
		".ndf" {
			scan [LWDAQ_ndf_data_check $infile_name] %d%d a l
			if {$l < $LWDAQ_Info(ndf_min_data_size)} {
				set l $LWDAQ_Info(ndf_min_data_size)
			}
			set width [expr round(sqrt($l)) + 1]	
			set image_name [lwdaq_image_create \
				-try_header 0 -name $image_name \
				-width $width -height $width \
				-results [LWDAQ_ndf_string_read $infile_name] ]
			lwdaq_data_manipulate $image_name write 0 \
				[LWDAQ_ndf_data_read $infile_name 0 *]
		}
		".png" {
			if {!$LWDAQ_Info(gui_enabled)} {
				error "png format supported only with gui enabled"
			}
			set p [image create photo]
			$p read $infile_name -format PNG
			set data [lwdaq_photo_contents $p]
			image delete $p
			set image_name [lwdaq_image_create \
				-try_header 1 -data $data -name $image_name]	
		}
		".jpg" {
			error "cannot open jpg"
		}
		default {
			set infile [open $infile_name r]
			fconfigure $infile -translation binary
			set data [read $infile]
			close $infile
			set image_name [lwdaq_image_create \
				-try_header 1 -data $data -name $image_name]	
		}
	}
	return $image_name
}

#
# LWDAQ_image_pixels returns a string containing the intensities of all pixels
# in a rectangular area in the image. By default, the routine uses the analysis
# boundaries, but we can also specify our own left, top, right, and bottom
# boundaries in that order. The pixels form an array by use of spaces and line
# breaks. There is a line break at the end of each row of pixels and a space
# between each column. You can paste the output from this routine directly into
# a spreadsheet and obtain a two-dimensional intensity array.
#
proc LWDAQ_image_pixels {image_name {left -1} {top -1} {right -1} {bottom -1}} {
	
	set binary_pixels [lwdaq_image_contents $image_name]
	binary scan $binary_pixels c* string_pixels
	set bounds [lwdaq_image_characteristics $image_name] 
	if {$left < 0} {set left [lindex $bounds 0]}
	if {$top < 0} {set top [lindex $bounds 1]}
	if {$right <0} {set right [lindex $bounds 2]}
	if {$bottom < 0} {set bottom [lindex $bounds 3]}
	set i_size [lindex $bounds 9]
	set j_size [lindex $bounds 8]
	set i 0
	set j 0
	set array_pixels ""
	foreach p $string_pixels {
		if {($i >= $left) && ($i <= $right) && ($j >= $top) && ($j <= $bottom)} {
			if {$p < 0} {set p [expr 256 + $p]}
			append array_pixels "$p "
			if {$i == $right} {append array_pixels "\n"}
		}
		incr i
		if {$i == $i_size} {
			set i 0
			incr j
		}
		if {$j > $bottom} {break}
	}
	return $array_pixels
}

#
# LWDAQ_get_file_name opens a file browser window and allows the user to select
# one or more files in the file system. The user can select multiple files when
# multiple is one (1). By default, multiple is zero (0). The routine starts in
# the LWDAQ working directory, and when the user selects a file, it sets the
# working directory to the directory containing the file. If the user selects no
# file, or presses the cancel button in the pop-up window, the routine does
# nothing. We can specify an initial directory for the file search. By default
# the search begins in the LWDAQ working directory.
#
proc LWDAQ_get_file_name { {multiple 0} {initialdir ""} } {
	global LWDAQ_Info

	if {$initialdir == ""} {set initialdir $LWDAQ_Info(working_dir)}
	if {![file exists $initialdir]} {
		set initialdir $LWDAQ_Info(program_dir)
	}
	
	set fl [tk_getOpenFile \
		-initialdir $initialdir \
		-multiple $multiple]
	if {$fl == ""} {return ""}

	if {$multiple} {
		set LWDAQ_Info(working_dir) [file dirname [lindex $fl 0]]
	} {
		set LWDAQ_Info(working_dir) [file dirname $fl]
	}
	
	return $fl
}

#
# LWDAQ_get_dir_name opens a file browser and allows you to select a directory.
# We can specify an initial directory for the file search. By default the search
# begins in the LWDAQ working directory.
#
proc LWDAQ_get_dir_name { {initialdir ""} } {
	global LWDAQ_Info

	if {$initialdir == ""} {set initialdir $LWDAQ_Info(working_dir)}
	if {![file exists $initialdir]} {
		set initialdir $LWDAQ_Info(program_dir)
	}

	set dirname [tk_chooseDirectory \
		-initialdir $initialdir \
		-mustexist 0]
	if {$dirname == ""} {return ""}
	
	set LWDAQ_Info(working_dir) $dirname

	return $dirname
}

#
# LWDAQ_put_file_name opens a file browser window and allows the user to specify
# an output file. The browser allows the user to select an existing directory in
# the file system, and to type in a name for the file within that directory. If
# the "name" parameter is set when this procedure is called, the value of "name"
# will be the default file name in the browser window. The routine returns the 
# name of the file that was written to. An empty string indicates that no file
# was written.
#
proc LWDAQ_put_file_name {{name ""}} {
	global LWDAQ_Info
	if {[file dirname $name] == "."} {
		if {![file exists $LWDAQ_Info(working_dir)]} {
			set LWDAQ_Info(working_dir) $LWDAQ_Info(program_dir)
		}
		set initialdir $LWDAQ_Info(working_dir)
	} {
		set initialdir [file dirname $name]
	}
	set f [tk_getSaveFile \
		-initialdir $initialdir \
		-initialfile [file tail $name]]
	if {$f != ""} {set LWDAQ_Info(working_dir) [file dirname $f]}
	return $f
}

#
# LWDAQ_find_files takes a directory and a glob matching pattern to produce a
# list of all matching files in the directory and its sub-directories. The match
# is case-insensitive, but the complete file name, including its extension, must
# match the patter. Thus AFileName.txt will not be matched with FileName.txt,
# although it will match with *Name.txt and ?FileName.*. The routine assembles
# its match list by calling itself recursively. The fact that the routine must
# support recursive calls dictates that the final list is not sorted. If we were
# to sort the list, we would be sorting in every recursive call to the routine,
# which makes the routine inefficient. Follow your call to this routine with a
# list sort to obtain an ordered list.
#
proc LWDAQ_find_files {directory pattern} {
	set ffl [list]
	set dfl [glob -nocomplain [file join $directory *]]
	foreach fn $dfl {
		if {[file isdirectory $fn]} {
			foreach fn [LWDAQ_find_files $fn $pattern] {
				lappend ffl $fn
			}
		} else {
			if {[string match -nocase $pattern [file tail $fn]]} {
				lappend ffl $fn
			}
		}
		LWDAQ_support
	}
	return $ffl
}

#
# LWDAQ_sort_files takes a list of file names and sorts them by the file name
# without directory name, which in Tcl we call the file tail. 
#
proc LWDAQ_sort_files {fnl} {
	proc LWDAQ_sort_files_command {a b} {
		return [string compare [file tail $a] [file tail $b]]
	}
	return [lsort -increasing -command LWDAQ_sort_files_command $fnl]
}

#
# LWDAQ_split takes a list of parameters delimited by white space, colons,
# commas, equal-signs, semi-colons, and null characters. It returns a list
# containing no empty elements.
#
proc LWDAQ_split {s} {
	set a [string map {; \  , \  \0 \  = \ } $s]
	set a [split $a]
	set b [list]
	foreach e $a {if {![string is space $e] && !($e == "\0")} {lappend b $e}}
	return $b
}

#
# LWDAQ_decimal_to_binary takes a decimal integer, $decimal, and returns the
# least significant $length digits of its binary representation as a string of
# ones and zeros. By default, $length is 32, which is also the maximum value of
# $length supported by the routine. We include comment in the code to explain
# our use of binary format and binary scan. It turns out that we have to use
# both these routines to achieve our end. First we format the integer as a
# binary object, then we scan this binary object for its bits.
#
proc LWDAQ_decimal_to_binary {decimal {length 32}} {
	# Convert $i into a four-byte binary object in memory.
	set binary_object [binary format I $decimal]
	# Scan the bits of $binary_object to create a binary string.
	binary scan $binary_object B32 binary_string
	# Extract the lower $n bits of the string.
	if {$length>32} {set length 32}
	set result [string range $binary_string [expr 32 - $length] 31]
	# Return this string.
	return $result
}

#
# LWDAQ_set_bit takes a string of ones and zeros, called binary_string, and sets
# bit number $bit_num to $value. By default, $value is 1, in keeping with the
# electrical engineer's meaning of the word "set".
#
proc LWDAQ_set_bit {binary_string bit_num {value 1}} {
	return [string replace $binary_string end-$bit_num end-$bit_num $value]
}

#
# LWDAQ_time_stamp returns a year, month, date, hour, seconds time-stamp string
# for record keeping, or converts a [clock seconds] result into a time-stamp.
#
proc LWDAQ_time_stamp { {s ""} } {
	if {$s == ""} {set s [clock seconds]}
	return [clock format $s -format "%Y%m%d%H%M%S"]
}

#
# LWDAQ_is_error_result returns 1 if and only if the first string begins with
# "ERROR: " (case sensitive).
#
proc LWDAQ_is_error_result {s} {
	return [string match "ERROR: *" $s]
}

#
# LWDAQ_vwait_var_name will return a unique name for a global vwait variable.
# All LWDAQ routines that call TCL's vwait routine use a global timeout variable
# assigned by this routine, so that its partner routine LWDAQ_stop_vwaits can go
# through all existing timeout variables and set them, which aborts the vwaits.
#
proc LWDAQ_vwait_var_name {} {
	global LWDAQ_Info

	set i 1
	global LWDAQ_vwait_$i
	while {[info exists LWDAQ_vwait_$i]} {
		incr i
		global LWDAQ_vwait_$i
	}
	
	return LWDAQ_vwait_$i
}

#
# LWDAQ_vwait calls vwait, but also keeps a list of the current vwait variable
# stack, which the System Monitor uses to keep track of LWDAQ vwaits.
#
proc LWDAQ_vwait {var_name} {
	global LWDAQ_Info $var_name
	
	if {$LWDAQ_Info(reset)} {
		# If a LWDAQ reset is in progress, we abort.
		return "Reset"
	} 

	# If there is no reset, we add the variable name to 
	# global vwait variable list and wait until it is 
	# set by some other process.
	lappend LWDAQ_Info(vwait_var_names) $var_name
	
	# Wait until the variable is set by some command or event.
	vwait $var_name
	
	# Delete the variable from the list, provided it is still
	# in there.
	set index [lsearch $LWDAQ_Info(vwait_var_names) $var_name]
	if {$index >= 0} {
		set LWDAQ_Info(vwait_var_names) \
			[lreplace $LWDAQ_Info(vwait_var_names) $index $index]
	}
	
	# If the variable has been set, return its value.
	# Otherwise return an empty string.
	if {[info exists $var_name]} {
		return [set $var_name]
	} {
		return ""
	}
}

#
# LWDAQ_stop_vwaits sets all vwait variables generated by the above routine,
# which aborts all the current LWDAQ vwaits. Because TCL vwaits are nested,
# LWDAQ_stop_vwaits will cause any depth of nesting to terminate, even it the
# nesting is in deadlock.
#
proc LWDAQ_stop_vwaits {} {
	global LWDAQ_Info

	foreach var $LWDAQ_Info(vwait_var_names) {
		global $var
		if {[info exists $var]} {
			set $var "Aborted waiting for $var."
		}
	}

	return ""
}

#
# LWDAQ_wait_ms waits for the specified time. By default, the routine assigns a
# unique global name of its own. But it allows you to specify the name of the
# variable that will be used to control the delay. In this way, you can abort
# the waiting period by setting the variable from a button or some other event
# command. When the waiting is done, we unset the waiting variable. When the
# waiting is aborted, we cancel the waiting command so that the waiting variable
# will not be set later. We return the value to which the vwait variable was
# set.
#
proc LWDAQ_wait_ms {time_ms {vwait_var_name ""}} {
	if {![string is integer -strict $time_ms]} {
		error "Invalid millisecond time \"$time_ms\"."
	}
	if {$vwait_var_name == ""} {
		set vwait_var_name [LWDAQ_vwait_var_name]
	}
	upvar #0 $vwait_var_name vwait_var
	set vwait_var "Waiting for $time_ms ms."
	set cmd [after $time_ms \
		[list set $vwait_var_name "Waited for $time_ms ms."]]
		
	LWDAQ_vwait $vwait_var_name
	
	set vwait_var_copy $vwait_var
	unset vwait_var
	after cancel $cmd
	
	return $vwait_var_copy
}

#
# LWDAQ_wait_seconds waits for the specified time.
#
proc LWDAQ_wait_seconds {t {vwait_var_name ""}} {
	LWDAQ_wait_ms [expr round( 1000 * $t )] $vwait_var_name
	return ""
}

#
# LWDAQ_watch waits for a global variable to aquire a particular value, at which
# point it executes a command. We give the name of the global variable and the
# awaited value. When the condition is met, the procedure executes the command,
# otherwise it posts itself to the event queue. The command is a script.
#
proc LWDAQ_watch {watch_var watch_val command} {
	upvar #0 $watch_var wv
	if {[info exists wv] && ($wv == $watch_val)} {
		uplevel #0 $command
	} {
		LWDAQ_post [list LWDAQ_watch $watch_var $watch_val $command]
	}
	return ""
}

#
# LWDAQ_update passes control to the TclTk event handler for update_ms. During
# this time, the event handler can perform window updates, respond to mouse
# clicks, and service TCPIP sockets.
#
proc LWDAQ_update {} {
	global LWDAQ_Info
	LWDAQ_wait_ms $LWDAQ_Info(update_ms)
	return ""
}

#
# LWDAQ_support allows you to move windows while running a computation. You simply
# include a call to this routine in your repeating loop. Every support_ms, the 
# routine will call LWDAQ_update to handle system activity.
#
proc LWDAQ_support {} {
	global LWDAQ_Info
	set c [clock milliseconds]
	if {![info exists LWDAQ_Info(support_time)]} {set LWDAQ_Info(support_time) $c}
	if {$LWDAQ_Info(support_time) <= $c} {
		LWDAQ_update
		set LWDAQ_Info(support_time) [expr [clock milliseconds] + $LWDAQ_Info(support_ms)]
	}
	return ""
}

#
# LWDAQ_global_var_name will return a unique name for a global variable.
#
proc LWDAQ_global_var_name {} {
	set count 0
	set var "lwdaq_global_[incr count]"
	global $var
	while {[info exists $var]} {
		set var "lwdaq_global_[incr count]"
		global $var
	}
	return $var
}

# 
# LWDAQ_process_exists checks if an operating system process exists. We pass the
# routine an id number and the routine returns 0 for false (does not exist) and
# 1 for true (exists). If the id is zero, we always return false. 
#
proc LWDAQ_process_exists {id} {
	global LWDAQ_Info

	if {$id == "0"} {return 0}

	if {$LWDAQ_Info(os) == "Windows"} {
		catch {eval exec [auto_execok tasklist] /fi \"pid eq $id\" /nh} message
		set process_list [split $message \n]
		foreach p $process_list {
			if {[lindex $p 1] == $id} {return 1}
		}
		return 0
	} else {
		catch {eval exec [auto_execok ps] $id} message
		set process_list [split $message \n]
		foreach p $process_list {
			if {[lindex $p 0] == $id} {
				if {[lindex $p 2] != "Z"} {
					return 1
				} {
					return 0
				}
			}
		}
		return 0
	}
}

#
# LWDAQ_process_stop attempts to stop an operating system process using its id
# number. If the process id is zero, the routine does nothing. Otherwise it calls
# the local operating system's kill command to stop the process. It returns the
# message given by the kill process.
#
proc LWDAQ_process_stop {id} {
	global LWDAQ_Info

	if {$id == "0"} {return ""}
	
	if {$LWDAQ_Info(os) == "Windows"} {
		catch {eval exec [auto_execok taskkill] /PID $id /F} message
	} else {
		catch {eval exec [auto_execok kill] $id} message
	}
	return $message
}

#
# LWDAQ_url_download downloads the source file of a url so we can parse it and extract
# text fields.
#
proc LWDAQ_url_download {url} {
	package require http
	set token [::http::geturl $url]
	set data [::http::data $token]
	::http::cleanup $token          
	return $data
}

#
# LWDAQ_url_open starts a browser window and directs the browser to open the url
# and either display or save its contents to disk, as if we cut and pasted the
# url into the default browser's address field. An html link will be displayed.
# A zip archive will be saved to disk. 
#
proc LWDAQ_url_open {url} {
	upvar #0 LWDAQ_Info info

	# Use the auto_execok command to obtain the name of the command
	# that will open the default browser on this operating system.
	switch $info(os) {
		"Windows" {set command [auto_execok "start"]}
		"MacOS" {set command [auto_execok "open"]}
		default {set command [auto_execok "xdg-open"]}
	}
	
	# If the auto_execok command returned an empty string, we have failed
	# to find the browser.
	if {[string length $command] == 0} {
		return "ERROR: Could not find browser."
	}
	
	# Now we try to open the page. We uset the {*} operator on the list
	# that is the browser command so as to expand a single multi-word 
	# list entry into individual command arguments. 
	if {[catch {exec {*}$command $url &} error]} {
		return "ERROR: $error trying to open url."
	}
	
	# If all is well, return an empty string.
	return ""
}

#
# LWDAQ_random returns a number between min and max. If both min and max are
# integers, then the number returned is also and integer. If either min or max
# is real, then the number returned is real. The random calculation we take from
# Practical Programming in TCL and TK by Brent Welch et al. 
#
proc LWDAQ_random {{min 0.0} {max 1.0}} {
	global LWDAQ_random_seed
	if {![info exists LWDAQ_random_seed]} {
		set LWDAQ_random_seed [clock format [clock seconds] -format "1%M%S"]
	}
	set LWDAQ_random_seed [expr ($LWDAQ_random_seed*9301 + 49297) % 233280]
	set random [expr $LWDAQ_random_seed/double(233280)]
	set random [expr $min + ($max - $min)*$random]
	if {[string is integer $min] && [string is integer $max]} {
		set random [expr round($random)]
	}
	return $random
}

#
# LWDAQ_random_wait_ms waits for a random number of milliseconds between min and
# max. During the wait, it passes control to the TCL/TK event loop so that idle
# tasks can be executed.
#
proc LWDAQ_random_wait_ms {{min 0} {max 1000}} {
	set time [LWDAQ_random [expr round($min)] [expr round($max)]]
	LWDAQ_wait_ms $time
	return $time
}

#
# LWDAQ_debug_log opens a file named by the debug_log value, in the
# program directory, and appends a string to the end of it, then
# closes the file.
#
proc LWDAQ_debug_log {s} {
	global LWDAQ_Info
	set f [open [file join $LWDAQ_Info(program_dir) $LWDAQ_Info(debug_log)] a]
	puts $f $s
	close $f
	return $s
}

#
# LWDAQ_proc_list returns a list of all procedures declared in the specified
# file that match the proc_name string. The proc_name can contain wild cards *
# and ?. Each procedure must be declared on a new line that begins with "proc "
# followed by the procedure name.
#
proc LWDAQ_proc_list {{proc_name "LWDAQ_*"} {file_name ""} } {
	if {$file_name == ""} {
		set file_name [LWDAQ_get_file_name]
		if {$file_name == ""} {return}
	}
	set f [open $file_name r]
	set names ""
	while {[gets $f line] >= 0} {
		if {[string match "proc $proc_name *" $line]} {
			set a [string last "\{" $line]
			set a [string replace $line $a end]
			set a [lindex $a 1]
			lappend names $a 
		}
	}
	close $f
	return $names
}

#
# LWDAQ_proc_description returns a list of procedure descriptions, such as this
# one, as exctracted from the TCL/TK script that defines the procedure. If there
# are procedures in the script that match the proc_name parameter, but do not
# have their own descriptions, the routine returns an empty element in its list.
# The script must indicate the description by quoting the procedure name after
# "# " on a new line. If you pass keep_breaks=1, the procedure will retain the
# original line breaks, which can be useful for printing directly to the TCL
# console.
#
proc LWDAQ_proc_description {{proc_name "LWDAQ_*"} {file_name ""} {keep_breaks 0} } {
	if {$file_name == ""} {
		set file_name [LWDAQ_get_file_name]
		if {$file_name == ""} {return}
	}
	set proc_list [LWDAQ_proc_list $proc_name $file_name]
	set description ""
	foreach p $proc_list {
		set f [open $file_name r]
		set d "No description available."
		while {[gets $f line] >= 0} {
			if {[string match "# $p *" $line]} {
				set d $line
				while {[gets $f line] >= 0} {
					if {[string match "# *" $line]} {
						if {$keep_breaks == 1} {append d "\n"} {append d " "}
						append d "$line"
					} {
						break
					}
				}
				set d [string map {"# " ""} $d]
			}
		}
		lappend description [string trim $d]
		close $f
	}
	if {[llength $description] > 1} {
		return $description
	} {
		return [lindex $description 0]
	}
}

#
# LWDAQ_proc_declaration returns a list of procedure declarations that match
# proc_name from the script file specified by file_name. The script must
# indicate a procedure declaration by quoting the procedure name after "proc "
# on a new line. The routine is tolerant of long lists of procedure arguments
# that are wrapped with backslashes onto the next line.
#
proc LWDAQ_proc_declaration {{proc_name "LWDAQ_*"} {file_name ""} } {
	if {$file_name == ""} {
		set file_name [LWDAQ_get_file_name]
		if {$file_name == ""} {return}
	}
	
	set proc_list [LWDAQ_proc_list $proc_name $file_name]

	set f [open $file_name r]
	set contents [read $f]
	close $f
	set contents [regsub -all {\\\n} $contents " "]
	set contents [regsub -all {[\t ][\t ]+} $contents " "]
	set lines [split $contents "\n"]

	set declaration ""
	foreach p $proc_list {
		set d ""
		foreach line $lines {
			if {[string match "proc $proc_name *" $line]} {
				set d [string last "\{" $line]
				set d [string replace $line $d end]
				break
			}
		}
		lappend declaration [string trim $d]
	}
	if {[llength $declaration] > 1} {
		return $declaration
	} {
		return [lindex $declaration 0]
	}
}

#
# LWDAQ_proc_definition returns a list of procedure definitions that
# match proc_name from the script file specified by file_name. The script
# must indicate the start of a procedure definition by quoting the 
# procedure name after "proc " on a new line. It must indicate the end
# of the procedure definition with a line consisting only of a single
# right-brace "}".
#
proc LWDAQ_proc_definition {{proc_name "LWDAQ_*"} {file_name ""} } {
	if {$file_name == ""} {
		set file_name [LWDAQ_get_file_name]
		if {$file_name == ""} {return}
	}
	set proc_list [LWDAQ_proc_list $proc_name $file_name]
	set definition ""
	foreach p $proc_list {
		set f [open $file_name r]
		set d ""
		while {[gets $f line] >= 0} {
			if {[string match "proc $proc_name *" $line]} {
				set d $line
				while {[gets $f line] >= 0} {
					append d "\n$line"
					if {$line == "\}"} {break}
				}
			}
		}
		lappend definition [string trim $d]
		close $f
	}
	if {[llength $definition] > 1} {
		return $definition
	} {
		return [lindex $definition 0]
	}
}

#
# LWDAQ_script_description returns the introductory paragraph of a 
# TCL/TK script. It extracts the script name from the file_name
# parameter. The script name is the tail of the file_name. The script
# must indicate the introductory paragraph by quoting the script name
# after "# " on a new line. If you pass keep_breaks=1, the procedure
# will retain the original line breaks, which can be useful for printing
# directly to the TCL console.
#
proc LWDAQ_script_description {{file_name ""} {keep_breaks 0} } {
	if {$file_name == ""} {
		set file_name [LWDAQ_get_file_name]
		if {$file_name == ""} {return}
	}
	set script_name [file tail $file_name]
	set f [open $file_name r]
	set description ""
	while {[gets $f line] >= 0} {
		if {[string match "# $script_name *" $line]} {
			append description $line
			while {[gets $f line] >= 0} {
				if {[string match "# *" $line]} {
					if {$keep_breaks == 1} {
						append description "\n"
					} {
						append description " "
					}
					append description "$line"
				} {
					break
				}
			}
		}
	}
	close $f
	set description [string map {"# " ""} $description]
	return [string trim $description]
}

#
# LWDAQ_list_commands lists LWDAQ commands in the console and returns an empty
# string.
#
proc LWDAQ_list_commands { {pattern *} } {
	set clist [info commands lwdaq_$pattern]
	set sclist [lsort -dictionary $clist]
	foreach command $sclist {puts $command}
	set clist [info commands LWDAQ_$pattern]
	set sclist [lsort -dictionary $clist]
	foreach command $sclist {puts $command}
	return ""
}

#
# help prints help on LWDAQ routines to the console. If we pass a pattern with
# wildcards into help, the routine selects only routines that match the pattern.
# If the option is "definition", the routine returns the actual script that
# defines the procedure in addition to the comments at the top. 
#
proc help { {pattern ""} {option "none"}} {
	global LWDAQ_Info
	
	if {$pattern == ""} {
		puts "Try LWDAQ_list_commands to get a list of LWDAQ commands."
		puts "Try \"help\" or \"man\" followed by a procedure name containing wild cards."
		puts "Try the LWDAQ Manual (web address is in the About dialog box)."
		puts "Try typing a routine name to get a list of parameters it requires."
		return
	}

	foreach f $LWDAQ_Info(scripts)  {
		set names [LWDAQ_proc_list $pattern $f]
		if {[llength $names] > 0} {
			puts ""
			puts "From [file tail $f]: "
			puts ""
			foreach n $names {
				puts [LWDAQ_proc_declaration $n $f]
				puts
				puts [LWDAQ_proc_description $n $f 1]
				puts ""
				if {$option == "definition"} {
					puts [LWDAQ_proc_definition $n $f]
					puts ""
				}
			}
		}
	}
	
	return ""
}

#
# man calls help.
#
proc man { {pattern ""} {option "none"} } {
	help $pattern $option
}

#
# LWDAQ_html_contents creates a table of contents for an HTML document.
# Each h2 and h3 level heading must have a unique name in the document, because
# this routine uses the heading text as the identifier for each heading line.
# The table of contents will be placed underneath an h2 heading with text
# "Contents". Any pre-existing table of contents between this h2 heading and the
# next h2 heading will be removed from the document. The routine takes three
# optional parameters. The first two are cell_spacing and num_columns for the 
# h3 heading tables beneath each h2 heading. The third parameter is the name of the
# HTML file to be processed.
#
proc LWDAQ_html_contents { {cell_spacing 4} {num_columns 4} {file_name ""} } {

	# procedure that tabulates headings.
	proc LWDAQ_html_contents_tabulate {names outfile cell_spacing num_columns} {
		if {[llength $names] > 0} {
			puts $outfile "<table cellspacing=$cell_spacing>"
			set index 0
			foreach n $names {
				if {$index==0} {puts -nonewline $outfile "<tr><td></td>"}
				puts -nonewline $outfile "<td><a href=\"\#$n\">$n</a></td>"
				if {$index==[expr $num_columns -1]} {puts -nonewline $outfile "</tr>\n"}
				incr index
				if {$index==$num_columns} {set index 0}
			}
			if {$index != 0} {puts $outfile "</tr>"}
			puts $outfile "</table>"
			return 1
		} {
			return 0
		}
	}
	
	# Find the input file.
	if {$file_name == ""} {
		set file_name [LWDAQ_get_file_name]
		if {$file_name == ""} {return ""}
	}
	set ft [file tail $file_name]
	set nfn [file join [file dirname $file_name] "new_$ft"]
	
	# Open the input file for reading, and temporary file for writing.
	set f [open $file_name r]
	set nf [open $nfn w]
	
	# Make a list of headings and instert heading identifiers in text of
	# temporary file.
	set headings [list]
	while {[gets $f line] > -1} {
		set h2 [regexp {[^<]*<h2([^>]*)>([^<]*)} $line a b c d e]
		if {$h2} {
			lappend headings h2
			lappend headings $c
			puts $nf "<h2 id=\"$c\">$c</h2>"
		} {
			set h3 [regexp {[^<]*<h3([^>]*)>([^<]*)} $line a b c d e]
			if {$h3} {
				lappend headings h3
				lappend headings $c
				puts $nf "<h3 id=\"$c\">$c</h3>"
			} {
				puts $nf $line
			}
		}
	}
	lappend headings "h2"
	lappend headings "End"
	
	# Close both files.
	close $f
	close $nf
	
	# Open the input file for writing, and the temporary file for reading.
	set f [open $file_name w]
	set nf [open $nfn r]
	
	# Copy $nf to $f until and including contents heading
	while {[gets $nf line] > -1} {
		puts $f $line
		if {[regexp {[^<]*<h2([^>]*)>([^<]*)Contents} $line a b c d e]} {
			puts $f ""
			break
		}	
	}
	
	# Create table of contents after contents heading
	set h3list [list]
	foreach {h t} $headings {
		if {$h == "h2"} {
			if {[llength $h3list] > 0} {
				LWDAQ_html_contents_tabulate $h3list $f $cell_spacing $num_columns
				set h3list [list]
			}
			if {($t != "End") && ($t != "Contents")} {
				puts $f "<a href=\"\#$t\">$t</a><br>"
			}
		}
		if {$h == "h3"} {
			lappend h3list $t
		}
	}
	
	# Add a line break before the next heading.
	puts $f ""
	
	# Skip over old contents until next heading.
	while {[gets $nf line] > -1} {
		if {[regexp {[^<]*<h2([^>]*)>([^<]*)} $line a b c d e]} {
			puts $f $line
			break
		}	
	}
	
	# Copy the rest of the file.
	while {[gets $nf line] > -1} {
		puts $f $line
	}
	
	# Close the files.
	close $f
	close $nf
	
	# Delete the temporary file.
	file delete $nfn
	
	return ""
}	

#
# LWDAQ_html_split takes a long file with h2-level chapters and splits it into
# chapter files. It puts the chapter files in a new directory. If the original
# file is called A.html, the directory is A, and the chapters are named A_1.html
# to A_n.html, where n is the number of chapters. There will be another file
# called index.html, which is the table of contents. Each chapter provides a
# link to the table of contents, to the previous chapter, and to the next
# chapter. Each preserves the header and stylsheets used in the original file.
# All local html links get displaced downwards by one level in order to account
# for the chapters being buried in a new directory. Internal links in the
# document are broken, so you will have to go in and fix them by hand. Any
# h2-level heading called "Contents" will be removed from the list of chapter,
# because we assume it's a table of contents generated by the routine
# LWDAQ_html_contents.
#
proc LWDAQ_html_split {{file_name ""}} {
	# Find the input file.
	if {$file_name == ""} {
		set file_name [LWDAQ_get_file_name]
	}
	if {$file_name == ""} {
		return ""
	}

	# Read input file.
	set f [open $file_name r]
	set master [read $f]
	close $f

	# Displace links down one into directory structure.
	regsub -all {href="} $master {href="../} master
	regsub -all {src="} $master {src="../} master
	
	# Split the master according to h2-level html headings.
	set chapters [list]
	while {1} {
		set n [string first "<h2" $master 3]
		if {$n < 0} {break}
		lappend chapters [string range $master 0 [expr $n - 1]]
		set master [string replace $master 0 [expr $n - 1] ""]
	}
	regsub -all {</body>} $master {} master
	regsub -all {</html>} $master {} master
	lappend chapters $master
	
	# Remove the table of contents, if there is one.
	for {set i 0} {$i < [llength $chapters]} {incr i} {
		if {[regexp {<h2[^>]*>[^<]*Contents} [lindex $chapters $i] a]} {
			set chapters [lreplace $chapters $i $i]
		}
	}
	
	# Extract the header: it's chapter zero now.
	set header [lindex $chapters 0]
	
	# Compose names for the new files.
	set fr [file rootname $file_name]
	set root [file tail $fr]

	# Make a list of chapter names. Give the zero-chapter the name
	# Contents, because that's what it's going to be. Set the zero
	# chapter to be a list of links to the remaining chapters.
	set contents ""
	for {set i 1} {$i < [llength $chapters]} {incr i} {
		if {[regexp {[^<]*<h2([^>]*)>([^<]*)} [lindex $chapters $i] a b c d e]} {
			lappend names $c
			append contents "<a href=\"$root\_$i\.html\">Chapter $i\: $c</a><br>\n"
		} {
			error "no h2 heading in chapter $i"
		}
	}
	lset chapters 0 $contents
	
	# Add links to previous chapters to each chapter except the first.
	for {set i 2} {$i < [llength $chapters]} {incr i} {
		lset chapters $i "<a href=\"$root\_[expr $i - 1]\.html\">Previous Chapter</a><br> \
			\n[lindex $chapters $i]"
	}
	
	# Add links to next chapters to each chapter except the last. We add
	# a link at the top and bottom of the chapter.
	for {set i 1} {$i < [expr [llength $chapters] - 1]} {incr i} {
		lset chapters $i "\
			<a href=\"$root\_[expr $i + 1]\.html\">Next Chapter</a><br>\n \
			[lindex $chapters $i]<br>\n \
			<a href=\"$root\_[expr $i + 1]\.html\">Next Chapter</a><br>\n"
	}
	
	# Add links to the table of contents to each chapter.
	for {set i 1} {$i < [llength $chapters]} {incr i} {
		lset chapters $i "<a href=\"index.html\">Contents</a><br>\n \
			[lindex $chapters $i]"
	}
	
	# Add the header and footer to all chapters.
	for {set i 0} {$i < [llength $chapters]} {incr i} {
		lset chapters $i "$header\n[lindex $chapters $i]\n</body>\n</html>"
	}
	
	# Make directory for chapters.
	file mkdir $fr

	# Save the contents as index.html.	
	set f [open [file join $fr index.html] w]
	puts $f [lindex $chapters 0]
	close $f

	# Save the chapters as $fr/root_$i.html
	for {set i 1} {$i < [llength $chapters]} {incr i} {
		set f [open [file join $fr "$root\_$i\.html"] w]
		puts $f [lindex $chapters $i]
		close $f
	}

	return ""
}

#
# LWDAQ_html_tables extracts all the tables from an HTML document and writes
# them to a new HTML document with Tables_ added to the beginning of the
# original document's file root. The routine takes one optional parameter: the
# name of the HTML document.
#
proc LWDAQ_html_tables { {file_name ""} } {
	# Find the input file.
	if {$file_name == ""} {
		set file_name [LWDAQ_get_file_name]
	}
	set ft [file tail $file_name]
	set nfn [file join [file dirname $file_name] "Tables_$ft"]
	
	# Open the input file for reading, and new file for writing.
	set f [open $file_name r]
	set nf [open $nfn w]
	
	# Copy header from $f to $nf adding "Tables From" to title.
	while {[gets $f line] > -1} {
		if {[regexp {[^<]*<title>([^<]*)} $line a b]} {
			puts $nf "<title>Tables From $b</title>"
		} {
			puts $nf $line
		}
		if {[regexp {[^<]*<body>[^<]*} $line]} {
			puts $nf ""
			break
		}	
			
	}
	
	# Skip past the contents
	while {[gets $f line] > -1} {
		if {[regexp {[^<]*<h2([^>]*)>([^<]*)Contents} $line a]} {
			break
		}	
	}
	while {[gets $f line] > -1} {
		if {[regexp {[^<]*<h2([^>]*)>} $line a]} {
			break
		}	
	}
	
	# Copy all tables
	set in_table 0
	while {[gets $f line] > -1} {
		if {[regexp {[^<]*<table([^>]*)>} $line a]} {set in_table 1}
		if {$in_table} {
			puts $nf $line
		}
		if {[regexp {[^<]*</table} $line a]} {
			set in_table 0
			puts $nf "<br>"
		}
	}
	
	
	puts $nf "</body></html>"
	
	# Close the files.
	close $f
	close $nf
	return ""
}

#
# LWDAQ_command_reference generates the LWDAQ software command reference manual
# automatically, using the files ./Sources/lwdaq.pas for Pascal library routine
# entries and the template file ./LWDAQ.app/Contents/LWDAQ/CRT.html, as well as
# our LWDAQ command listing and help extraction routines. By default, the
# routine creates the command reference in the current LWDAQ working directory,
# and names it Commands.html.
#
proc LWDAQ_command_reference { {file_name ""} } {
	global LWDAQ_Info
	
	if {$file_name == ""} {
		set file_name [file join $LWDAQ_Info(working_dir) "Commands.html"]
	}
	set ref_file [open $file_name w]
	set template_file [open [file join $LWDAQ_Info(scripts_dir) CRT.html] r]
	
	while {[gets $template_file line] >= 0} {
		set line [string map "LWDAQ_Version_Here $LWDAQ_Info(program_patchlevel)" $line]
	
		if {$line == "Script_Descriptions"} {
			foreach f $LWDAQ_Info(scripts) {
				set description [LWDAQ_script_description $f]
				if {$description == ""} {continue}
				set s [file tail $f]
				puts $ref_file ""
				puts $ref_file "<h3>$s</h3>"
				puts $ref_file ""
				puts $ref_file "<p>$description</p>"
			}
			continue
		}
		
		if {$line == "Script_Commands"} {
			puts $ref_file ""
			puts $ref_file "<h2>Script Commands</h2>"
			puts $ref_file ""
			set script_list [list]
			foreach f $LWDAQ_Info(scripts) {
				puts $f
				LWDAQ_update
				foreach sc [LWDAQ_proc_list LWDAQ_* $f] {
					lappend script_list "$sc $f"
				}
			}
			set script_list [lsort -dictionary -index 0 $script_list]
			foreach {s} $script_list {
				set sc [lindex $s 0]
				set f [lindex $s 1]
				puts $ref_file ""
				puts $ref_file "<h3>$sc</h3>"
				puts $ref_file ""
				puts $ref_file "<small><pre>[LWDAQ_proc_declaration $sc $f]</pre></small>"
				puts $ref_file "<p>[LWDAQ_proc_description $sc $f]</p>"
				puts $ref_file ""
			}
			continue
		}
	
		if {$line == "Library_Commands"} {
			set fn [file join $LWDAQ_Info(sources_dir) lwdaq.pas]
			puts $fn
			LWDAQ_update
			set f [open $fn r]
			set code [read $f]
			close $f
			
			puts $ref_file ""
			puts $ref_file "<h2>Library Commands</h2>"
			puts $ref_file ""
			set lwdaq_names [lsort -dictionary [info commands lwdaq_*]]
			foreach n $lwdaq_names {
				puts $ref_file ""
				puts $ref_file "<h3>$n</h3>"
				puts $ref_file ""
				if {[catch {$n} error_message]} {
					regexp {"([^"]+)"} $error_message match syntax
					puts $ref_file "<small><pre>$syntax</pre></small>"
				} {
					puts $ref_file "<small><pre>$n ?option value?</pre></small>"
				}
				set r "\{(\[^\\\}\]+)\}\[\\r\\t\\n \]*function $n\[ \\\(\]+"
				regexp $r $code match comment
				puts $ref_file "$comment"
			}
			continue
		}
		
		if {$line == "Library_Routines"} {
			set fn [file join $LWDAQ_Info(sources_dir) lwdaq.pas] 
			puts $fn
			LWDAQ_update
			set f [open $fn r]
			set code [read $f]
			close $f

			puts $ref_file ""
			puts $ref_file "<h2>Library Routines</h2>"
			puts $ref_file ""

			set r "\{(\[^\\\}\]+)\}\[\\r\\t\\n \]*function lwdaq\[^_\]"
			if {[regexp $r $code match comment]} {
				puts $ref_file "$comment"
			}

			catch {lwdaq *} error_message
			regexp {"\*"[^"]*"([^"]+)"} $error_message match names
			set lwdaq_routine_names [lsort -dictionary $names]
			foreach n $lwdaq_routine_names {
				puts $ref_file ""
				puts $ref_file "<h3>$n</h3>"
				puts $ref_file ""
				catch {lwdaq $n} error_message
				regexp {"([^"]+)"} $error_message match syntax
				puts $ref_file "<small><pre>$syntax</pre></small>"
				set r "option='$n'\[^\{\}\]+\{(\[^\}\]+)\}"
				if {[regexp $r $code match comment]} {
					puts $ref_file "$comment"
				}
			}
			continue
		}
		
		puts $ref_file $line
	}

	close $template_file
	close $ref_file
	
	LWDAQ_html_contents 3 3 $file_name
	
	return ""
}

#
# LWDAQ_tool_reference generates an HTML manual page for the routines defined in
# a LWDAQ tool script. We name the tool script and the routine does the rest.
# The routine creates the tool reference in the LWDAQ directory, and names it
# Tool.html. If we don't specify a a file, the routine will open a file browser.
# The routine writes an h3-level title, a declaration showing the parameters
# that we must pass into the procedure, and the description of the procedure
# extracted from the comments above. 
#
proc LWDAQ_tool_reference {{script ""}} {
	global LWDAQ_Info
	
	if {$script == ""} {set script [LWDAQ_get_file_name]}
	if {$script == ""} {return ""}
	set f [open [file join $LWDAQ_Info(program_dir) "Tool.html"] w]
	set script_list [LWDAQ_proc_list * $script]
	set script_list [lsort -dictionary -index 0 $script_list]
	foreach {s} $script_list {
		puts $f "<h3 id=\"$s\">$s</h3>"
		puts $f "<small><pre>[LWDAQ_proc_declaration $s $script]</pre></small>"
		puts $f "<p>[LWDAQ_proc_description $s $script]</p>"
		puts $f ""
	}
	close $f
	return ""
}