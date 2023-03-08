# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2004-2019 Kevan Hashemi, Brandeis University
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

#
# Terminal.tcl defines the Terminal instrument.
#

#
# LWDAQ_init_Terminal creates all elements of the Terminal instrument's
# config and info arrays.
#
proc LWDAQ_init_Terminal {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Terminal info
	upvar #0 LWDAQ_config_Terminal config
	array unset config
	array unset info

	# The info array elements will not be displayed in the 
	# instrument window. The only info variables set in the 
	# LWDAQ_open_Instrument procedure are those which are checked
	# only when the instrument window is open.
	set info(name) "Terminal"
	set info(control) "Idle"
	set info(window) [string tolower .$info(name)]
	set info(text) $info(window).text
	set info(photo) [string tolower $info(name)\_photo]
	set info(counter) 0 
	set info(zoom) 1
	set info(delete_old_images) 1
	set info(file_use_daq_bounds) 0
	set info(daq_image_width) 400
	set info(daq_image_height) 300
	set info(daq_image_left) -1
	set info(daq_image_right) -1
	set info(daq_image_top) 0
	set info(daq_image_bottom) -1
	set info(daq_device_type) 3
	set info(daq_extended) 0
	set info(tx_string) ""
	set info(rx_terminators) "3 4"
	set info(receive_hex) "00D0"
	set info(transmit_decimal) "160"
	set info(loop_delay_ms) 30
	set info(daq_password) "no_password"
	set info(verbose_description) "{Received String}"
	set info(timeout) 0
	set info(tx_file_name) "./LWDAQ.tcl"

	# All elements of the config array will be displayed in the
	# instrument window. No config array variables can be set in the
	# LWDAQ_open_Instrument procedure
	set config(image_source) "daq"
	set config(file_name) "./Images/$info(name)\*"
	set config(memory_name) "lwdaq_image_1"
	set config(daq_ip_addr) "10.0.0.37"
	set config(daq_driver_socket) 1
	set config(daq_mux_socket) 1
	set config(analysis_enable) 0
	set config(intensify) none
	set config(verbose_result) 0
	
	# Default transmit header is "transmit off", or XOFF. Default transmit footer 
	# is "carriage return line feed", or CRLF. The receiver termination character
	# is NULL by default, which instructs the Terminal to wait for the timeout 
	# period and gather the reciver size number of bytes.
	set config(tx_wait_ms) "2"
	set config(tx_header) "19"
	set config(tx_ascii) "<01 H16"
	set config(tx_file_name) ""
	set config(tx_footer) "13 10"
	set config(rx_last) "0"
	set config(rx_timeout_ms) "1000"
	set config(rx_size) "100"
	
	return ""
}

#
# LWDAQ_analysis_Terminal scans an image received from a Terminal
# data acquisition, and turns it into a string of numbers.
#
proc LWDAQ_analysis_Terminal {{image_name ""}} {
	upvar #0 LWDAQ_config_Terminal config
	upvar #0 LWDAQ_info_Terminal info
	if {$image_name == ""} {set image_name $config(memory_name)}

	set irs [lwdaq_image_results $image_name]
	scan $irs %u%u size terminator
	if {![info exists size] || ![info exists terminator]} {
		return "ERROR: Invalid image result string, \"$irs\"."
	}
	
	set bytes [lwdaq_data_manipulate $image_name read 0 $size]
	if {$terminator != 0} {
		set i [string first [binary format c $terminator] $bytes]
		if {$i >= 0} {set bytes [string range $bytes 0 $i]}
	}

	set result ""
	switch $config(analysis_enable) {
		1 {set result $bytes}
		2 {binary scan $bytes "c*" result} 
		3 {binary scan $bytes "cu*" result} 
		4 {binary scan $bytes "H*" result} 
		5 {
			set rxl [string length $bytes]
			for {set i 0} {$i < $rxl} {incr i} {	
				set a [string index $bytes $i]
				binary scan $a cu ascii
				if {($ascii < 128) && ($ascii > 0)} {
					append result $a
				}
			}
		}
	}
	
	return $result
}

#
# LWDAQ_daq_Terminal reads a string of characters or a block of data
# froma  data device.
#
proc LWDAQ_daq_Terminal {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Terminal info
	upvar #0 LWDAQ_config_Terminal config

	# Check that the image will be large enough to hold the received
	# data. Sometimes it's nice to make the image dimensions small and
	# use zoom to look closely at the bytes displayed by intensity. In
	# such cases, we can overflow the image if we are not careful.
	set data_size [expr $info(daq_image_width) * ($info(daq_image_height) - 1)]
	if {$config(rx_size) >= $data_size} {
		set info(daq_image_width) [expr round(sqrt($config(rx_size))) + 1]
		set info(daq_image_height) [expr $info(daq_image_width) + 2]
	}

	# Check the rx_last, tx_header, and tx_footer strings. These should all be
	# lists of one or more decimal numbers.
	foreach a {rx_last tx_header tx_footer} {
		set $a ""
		foreach b $config($a) {
			if {[string is integer -strict $b]} {
				lappend $a $b
			} {
				LWDAQ_print $info(text) "WARNING: Invalid decimal code \"$b\"."
			}
		}
	}

	# Compose the transmit string.
	set info(tx_string) ""
	foreach a $tx_header {append info(tx_string) [binary format c $a]}
	append info(tx_string) $config(tx_ascii)
	if {$config(tx_file_name) != ""} {
		if {[file exists $config(tx_file_name)]} {
			set f [open $config(tx_file_name) r]
			append info(tx_string) [read $f]
			close $f
		} {
			LWDAQ_print $info(text) "WARNING: file $config(tx_file_name) does not exist."	
		}
	}
	foreach a $tx_footer {append info(tx_string) [binary format c $a]}

	# The data acquisition commands are contained within an error trap.
	if {[catch {
		# Open a socket to the driver and select the target device.
		set sock [LWDAQ_socket_open $config(daq_ip_addr)]
		LWDAQ_login $sock $info(daq_password)
		LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)

		# We set up the driver to receive characters as much as we can, so as
		# to reduce the number of things it must do between transmitting its
		# final character and starting to listen for the first answering character.
		if {$config(rx_size) > 0} {

			# Fill the RAM with rx_last in anticipation of a timeout, 
			# and then clear the most recent byte register by writing 
			# a zero to RAM.
			LWDAQ_ram_delete $sock 0 $config(rx_size) $config(rx_last)
			LWDAQ_byte_write $sock $LWDAQ_Driver(ram_portal_addr) 0

			# Set up recording of bytes in driver memory.
			LWDAQ_set_device_type $sock $info(daq_device_type)
			LWDAQ_set_data_addr $sock 0
		}

		# Transmit the string.
		set txl [string length $info(tx_string)]
		for {set i 0} {$i < $txl} {incr i} {
			# We translate the i'th character in the transmit string into
			# an ascii code, and then create a sixteen-bit command word in
			# which the upper byte is the character and the lower byte is
			# the transmission command for a terminal instrument.
			set char [string index $info(tx_string) $i]		
			binary scan $char c ascii
			set cmd [expr (256 * $ascii) + $info(transmit_decimal)]
			
			# We write the command to the outgoing socket butter, but we
			# do not transmit it just yet. We will flush the socket later.
			LWDAQ_transmit_command $sock $cmd

			# Flush the socket so that the character is transmitted.
			LWDAQ_socket_flush $sock
			
			# If the serial instrumcnt at the other end is particularly slow,
			# we may have to wait additional time to allow it to transmit one
			# byte before we tell it to transmit the next.
			LWDAQ_wait_ms $config(tx_wait_ms)
		}

		# If there are bytes to be received, set up repeated execution of the read job. 
		if {$config(rx_size) > 0} {
			# Instruct the device to transfer bytes as they become available.
			LWDAQ_transmit_command_hex $sock $info(receive_hex)

			LWDAQ_set_repeat_counter $sock [expr $config(rx_size) - 1]

			# Start recording.
			LWDAQ_start_job $sock $LWDAQ_Driver(read_job)
	
			# Send all pending commands to the driver.
			LWDAQ_socket_flush $sock
			
			# Set up a timeout.
			set info(timeout) 0
			if {$config(rx_timeout_ms) > 0} {
				set cmd_id [after $config(rx_timeout_ms) {set LWDAQ_info_Terminal(timeout) 1}]
			}
	
			# Wait for a reception termination condition.
			while {1} {
			
				# If we have a non-null termination character specified, check the most
				# recent byte to see if it is the termination character or one of the
				# standard alternate termination characters: EOT or ETX. If we see a 
				# terminator, reset the controller and break out of the wait loop.
				if {$config(rx_last) != 0} {
					set mrb [LWDAQ_most_recent_byte $sock]
					if {($mrb == $config(rx_last)) \
						|| ([lsearch $mrb $info(rx_terminators)] >= 0)} {
						LWDAQ_controller_reset $sock
						break
					}
				}
				
				# If the timout flag has been set, break out of the wait loop. If we 
				# specified a non-null termination character, issue a warning that no
				# termination character arrived.
				if {$info(timeout) == 1} {
					if {$config(rx_last) != 0} {
						LWDAQ_print $info(text) \
							"WARNING: Timeout waiting for receive terminator."
					}
					LWDAQ_controller_reset $sock
					break
				}
				
				# If we have received the specified number of characters, break out
				# of the loop. If we have not yet received the termination character,
				# issue a warning.
				if {[LWDAQ_job_done $sock]} {
					if {$config(rx_last) != "0"} {
						LWDAQ_print $info(text) "WARNING:\
							Read $config(rx_size) bytes, but no receive terminator."
					}
					break
				}
				
				# If the user presses Stop, abandon the acquisition.
				if {$info(control) == "Stop"} {
					LWDAQ_print $info(text) "WARNING: Acquisition interrupted."
					LWDAQ_controller_reset $sock
					break
				}
				
				# We insert a delay here so we don't generate unnecessary traffic.
				LWDAQ_wait_ms $info(loop_delay_ms)
			}
			
			# Cancel the timeout.
			catch {after cancel $cmd_id}
			
			# Download a block of data rx_size bytes long.
			set data [LWDAQ_ram_read $sock 0 $config(rx_size)]
		} {
			# Even if there are no bytes to receive, we configure the terminal device to
			# receive data. In some devices, this return to reception causes an XON to be 
			# transmitted.
			LWDAQ_transmit_command_hex $sock $info(receive_hex)
			
			# Wait for the driver to be done.
			LWDAQ_wait_for_driver $sock
			
			# Set data to empty string.
			set data ""
		}
		
		# Close the socket.
		LWDAQ_socket_close $sock
	} error_result]} { 
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		return "ERROR: $error_result"
	}

	set config(memory_name) [lwdaq_image_create \
		-width $info(daq_image_width) \
		-height $info(daq_image_height) \
		-left $info(daq_image_left) \
		-right $info(daq_image_right) \
		-top $info(daq_image_top) \
		-bottom $info(daq_image_bottom) \
		-results "$config(rx_size) $config(rx_last)" \
		-name "$info(name)\_$info(counter)"]
	lwdaq_data_manipulate $config(memory_name) write 0 $data
	
	return $config(memory_name) 
} 

