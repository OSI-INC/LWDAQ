# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2006-2021 Kevan Hashemi, Brandeis University
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
# Recorder.tcl defines the Recorder instrument.
#

#
# LWDAQ_init_Recorder creates all elements of the Recorder instrument's
# config and info arrays.
#
proc LWDAQ_init_Recorder {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Recorder info
	upvar #0 LWDAQ_config_Recorder config
	array unset config
	array unset info
	
	# The info array elements will not be displayed in the 
	# instrument window. The only info variables set in the 
	# LWDAQ_open_Instrument procedure are those which are checked
	# only when the instrument window is open.
	set info(name) "Recorder"
	set info(control) "Idle"
	set info(window) [string tolower .$info(name)]
	set info(text) $info(window).text
	set info(photo) [string tolower $info(name)\_photo]
	set info(counter) 0 
	set info(zoom) 1
	set info(daq_extended) 0
	set info(delete_old_images) 1
	set info(file_use_daq_bounds) 0
	set info(daq_image_width) 500
	set info(daq_image_height) 300
	set info(daq_buffer_width) 1000
	set info(daq_image_left) -1
	set info(daq_image_right) -1
	set info(daq_image_top) 0
	set info(daq_image_bottom) -1
	set info(daq_device_type) 3
	set info(daq_password) "no_password"
	set info(verbose_description) "{Channel Number} \
		{Number of Samples Recorded} \
		{Average Value} \
		{Standard Deviation} "
	set info(timeout) 0
	set info(transmit_file_name) "./LWDAQ.tcl"
	set info(max_sample) 65535
	set info(min_sample) 0
	set info(display_range) [expr $info(max_sample) - $info(min_sample) + 1]
	set info(display_offset) $info(min_sample)
	set info(display_mode) "SP"
	set info(core_message_length) 4
	set info(upload_command) "00D0"
	set info(reset_command) "0081"
	set info(set_num_command) "1084"
	set info(set_num_max) 14
	set info(set_num_min) 0
	set info(set_num_all) 15
	set info(channel_activity) ""
	set info(activity_threshold) "10"
	set info(errors_for_stop) 10
	set info(clock_frequency) 128
	set info(max_block_reads) 100
	set info(min_messages_per_clock) 1
	set info(messages_per_clock) 1
	set info(min_clocks) 32
	set info(empty_fraction) 0.5
	set info(min_time_fetch) 0.2
	set info(max_time_fetch) 2.0
	set info(acquire_end_ms) 0
	set info(purge_duplicates) 1
	set info(payload_options) "0 16"
	set info(firmware_version) "?"
	set info(receiver_version) "?"
	set info(fv_range) 30
	set info(aux_list_name) LWDAQ_aux_Recorder
	global $info(aux_list_name)
	set $info(aux_list_name) ""
	set info(aux_list_length) 0
	set info(set_size) "16"
	set info(clock_id) 0
	set info(aux_num_keep) 1000
	set info(show_errors) 0
	set info(show_error_extent) 20
	
	set info(buffer_image) "_recorder_buffer_image_"
	catch {lwdaq_image_destroy $info(buffer_image)}
	set info(scratch_image) "_recorder_scratch_image_"
	catch {lwdaq_image_destroy $info(scratch_image)}
		
	# All elements of the config array will be displayed in the
	# instrument window. No config array variables can be set in the
	# LWDAQ_open_Instrument procedure
	set config(image_source) "daq"
	set config(file_name) ./Images/$info(name)\*
	set config(memory_name) lwdaq_image_1
	set config(daq_ip_addr) 10.0.0.37
	set config(daq_driver_socket) 1
	set config(daq_mux_socket) 2
	set config(set_num) "*"
	set config(analysis_enable) 1
	set config(analysis_channels) "*"
	set config(intensify) none
	set config(verbose_result) 0
	set config(daq_num_clocks) 128
	set config(payload_length) 0

	return 1
}

#
# LWDAQ_analysis_Recorder applies Recorder analysis to an image 
# in the lwdaq image list. By default, the routine uses the
# image $config(memory_name).
#
proc LWDAQ_analysis_Recorder {{image_name ""}} {
	upvar #0 LWDAQ_config_Recorder config
	upvar #0 LWDAQ_info_Recorder info
	upvar #0 $info(aux_list_name) aux_messages

	# By default, we use the image whose name we passed in to this routine,
	# but if no such name was passed, we use the image named in the configuration
	# array.
	if {$image_name == ""} {set image_name $config(memory_name)}
	
	# We catch all errors in analysis so that we can report them in the instrument
	# text window. We don't want these errors to stop data acquisition.
	if {[catch {
	
		# We get the number of errors, the number of clock messages, and the total
		# number of messages. We also get the message index of the first clock message.
		# We will use the first clock index later.
		scan [lwdaq_recorder $image_name \
			"-payload $config(payload_length) clocks 0"] %d%d%d%d \
			num_errors num_clocks num_messages first_index
		if {$num_errors > 0} {
			LWDAQ_print $info(text) "WARNING: Encountered $num_errors errors in data interval."
		}
		
		# We determine the display scale boundaries depending upon whether we have simple
		# plot, centered plot, or normalized plot.
		if {$info(display_mode) == "CP"} {
			set display_min [expr - $info(display_range) / 2 ]
			set display_max [expr + $info(display_range) / 2]
		} elseif {$info(display_mode) == "NP"} {
			set display_min 0
			set display_max 0
		} else {
			set display_min $info(display_offset)
			set display_max [expr $info(display_offset) + $info(display_range)]
		}
		
		# We compose a channel list from the analysis_channels string. The "*" character, 
		# if it appears anywhere in the analysis_channel list, will result in a "*" channel
		# number list. These channels are the ones we are going to plot and report on.
		set id_list ""
		foreach id $config(analysis_channels) {
			if {$id == "*"} {
				set id_list "*"
				break
			}
			if {![string is integer -strict $id]} {
				set id_list "*"
				LWDAQ_print $info(text) "WARNING: Bad channel number \"$id\"."
				break
			}
			lappend id_list $id
		}
		
		# We plot the selected channels in the image overlay. The result string
		# returned by this plot routine gives us the average and standard deviation
		# of each channel, and the number of messages present. For the clock 
		# channel, it gives the minimum and maximum timestamp values. This string is
		# the result of analysis for printing in the instrument window.
		set result [lwdaq_recorder $image_name \
			"-payload $config(payload_length) \
			plot $display_min $display_max \
			$info(display_mode) $id_list"]
			
		# We obtain a list of the channels with at least one message present
		# in the image, and the number of messages for each of these channels.
		set channels [lwdaq_recorder $image_name "-payload $config(payload_length) list"]
		if {![LWDAQ_is_error_result $channels]} {
			set ca ""
			foreach {c a} $channels {
				if {($a > $info(activity_threshold)) && ($c > 0)} {
					append ca "$c\:$a "
				}
			}
			set info(channel_activity) $ca
		} {
			error $channels
		}

		# If we don't yet know the firmware version of the receiver, we 
		# determine it now.
		if {$info(firmware_version) == "?"} {
			if {[regexp {Version ([0-9]+)} \
				[lwdaq_recorder $config(memory_name) \
					"-payload $config(payload_length) print 0 1"] match fv]} {
				set info(firmware_version) [expr $fv % $info(fv_range)]
				switch [expr $fv / $info(fv_range)] {
					0 {
						set info(receiver_version) "A3018"
					}
					1 {
						set info(receiver_version) "A3027"
					}
					2 {
						set info(receiver_version) "A3032"
					}
					3 {
						set info(receiver_version) "A3038"
					}
					default {set info(receiver_version) "?"}					
				}
			}
		}
	
		# We look for messages in the auxiliary channel.
		set new_aux_messages ""
		foreach {c a} $channels {
			if {$c % $info(set_size) == $info(set_size) - 1} {
				set messages [lwdaq_recorder $image_name \
					"-payload $config(payload_length) extract $c"]
				if {[LWDAQ_is_error_result $messages]} {error $messages}
				foreach {mt md} $messages {
					append new_aux_messages "$c $mt $md "
				}
			}
		}

		# We are going to calculate a timestamp, with resolution one clock tick, for
		# each auxiliary message. The timestamps can be used as a form of addressing
		# for slow data transmissions. To get the absolute timestamp, we get the
		# time of the first clock message in the data. This time is a sixteen-bit
		# value that has counted the number of 256-tick periods since the data receiver
		# clock was last reset, wrapping around to zero every time it overflows.
		scan [lwdaq_recorder $image_name \
			"-payload $config(payload_length) get $first_index"] %d%d%d cid bts fvn

		# We take each new auxiliary message and break it up into three parts. The
		# first part is a four-bit ID, which in the case of subcutaneous transmitters
		# would be the channel ID of the transmitter producing the auxiliary message.
		# The second part is a four-bit field address. The third is eight bits of data.
		# These sixteen bits are the contents of the auxiliary message. We add a fourth
		# number, which is the timestamp of message reception. We give the timestamp
		# modulo 2^16, which gives us sufficient precision to detect any time-based
		# address encoding of auxiliary data. These four numbers make one entry in
		# the auxiliary message list, so we append them to the existing list. If the
		# four-bit ID is zero or fifteen, this is an error, so we don't store the 
		# message.
		foreach {cn mt md} $new_aux_messages {
			set id [expr ($md / 4096)]
			if {$id == $info(set_size) - 1} {continue}
			set id [expr (($cn / $info(set_size)) * $info(set_size)) + $id]
			set fa [expr ($md / 256) % 16]
			set d [expr $md % 256]
			set ts  [expr ($mt + $bts * 256) % (65536)]
			lappend aux_messages "$id $fa $d $ts"
		}
		
		# We keep only a finite number of the most recent auxiliary messages.
		set k [expr $info(aux_num_keep) - 1]
		if {[llength $aux_messages] >= $k} {
			set aux_messages [lrange $aux_messages end-$k end]
		}
		set info(aux_list_length) [llength $aux_messages]
	} error_result]} {return "ERROR: $error_result"}

	# Handle the case where we have no messages at all.
	if {$result == ""} {
		set result "0 0 0 0"
	}
	
	return $result
}

#
# LWDAQ_refresh_Recorder refreshes the display of the data, given new
# display settings.
#
proc LWDAQ_refresh_Recorder {} {
	upvar #0 LWDAQ_config_Recorder config
	upvar #0 LWDAQ_info_Recorder info
	if {[lwdaq_image_exists $config(memory_name)] != ""} {
		LWDAQ_analysis_Recorder $config(memory_name)
		lwdaq_draw $config(memory_name) $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
	}
}

#
# LWDAQ_reset_Recorder configures a data receiver to operate with a particular set
# or with all sets, as specified by the set_num parameter. It resets the data receiver 
# address and timestamp registers, thus emptying its message buffer and resetting its clock. 
# It destroys the recorder instrument's data buffer and working image as well, and clears
# the auxiliary message list. We reset the acquired data time as well, which we use to stop
# the Recorder Instrument from over-drawing from the data receiver.
#
proc LWDAQ_reset_Recorder {} {
	upvar #0 LWDAQ_config_Recorder config
	upvar #0 LWDAQ_info_Recorder info
	global LWDAQ_Driver LWDAQ_Info

	if {[catch {
		# Clear the firmware version to unknown.
		set info(firmware_version) "?"
		set info(receiver_version) "?"
		
		# Determine the set number for configuration and write to the data receiver
		# with the help of the set_num_cmd string.
		set sn $config(set_num)
		if {[string is integer -strict $sn]} {
			if {($sn < $info(set_num_min)) || ($sn > $info(set_num_max))} {
				LWDAQ_print $info(text) "WARNING: Set number $sn out of range,\
					using $info(set_num_min)."
				set sn $info(set_num_min)
			}
		} {
			if {$config(set_num) == "*"} {
				set sn $info(set_num_all)
			} {
				LWDAQ_print $info(text) "WARNING: Set number \"$sn\" invalid,\
					must be $info(set_num_min)-$info(set_num_max) or *,\
					will use $info(set_num_min) instead."
				set sn $info(set_num_min)
			}
		}
		set set_num_cmd [string replace $info(set_num_command) 1 1 [format %1X $sn]]

		# Start the reset and configure.
		LWDAQ_print -nonewline $info(text) "Reset and configure... "
		LWDAQ_update

		# Open a socket and log in to the driver.
		set sock [LWDAQ_socket_open $config(daq_ip_addr)]
		LWDAQ_login $sock $info(daq_password)
		
		# Select the data receiver.
		LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
		
		# Configure the recorder with a set number.
		LWDAQ_transmit_command_hex $sock $set_num_cmd
		
		# Reset the data buffer.
		LWDAQ_transmit_command_hex $sock $info(reset_command)
		
		# Wait for command to execute and close socket.
		LWDAQ_wake $sock
		LWDAQ_wait_for_driver $sock
		LWDAQ_socket_close $sock

		# Destroy the buffer and memory images, clear the auxilliary message
		# list.
		lwdaq_image_destroy $info(buffer_image)
		lwdaq_image_destroy $config(memory_name)
		global $info(aux_list_name)
		set $info(aux_list_name) ""
		
		# Reset the acquired data time. We will use this end time to avoid 
		# over-drawing from the data receiver. When we ask for more data than 
		# is currently available in the data receiver, we occupy the driver 
		# until the data becomes available, which stops other clients using 
		# the driver to download their own data.
		set info(acquire_end_ms) [clock milliseconds]
		
		# We reset the number of messages per clock.
		set info(messages_per_clock) $info(min_messages_per_clock)

		# Notification to user.		
		LWDAQ_print $info(text) "Done. Acquire to get receiver and firmware version. "
	} error_result]} { 
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		incr LWDAQ_Info(num_daq_errors)
		LWDAQ_print $info(text) "\nERROR: $error_result" red
		return "ERROR: $error_result"
	}
	return 1
}

#
# LWDAQ_controls_Recorder creates secial controls 
# for the Recorder instrument.
#
proc LWDAQ_controls_Recorder {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_config_Recorder config
	upvar #0 LWDAQ_info_Recorder info

	set w $info(window)
	if {![winfo exists $w]} {return 0}

	set g $w.scale
	frame $g
	pack $g -side top -fill x

	foreach {label_name element_name} { \
			"Offset:" {display_offset} \
			"Range:" {display_range} } {
		label $g.l$element_name -text $label_name 
		entry $g.e$element_name -textvariable LWDAQ_info_Recorder($element_name) \
			-relief sunken -bd 1 -width 6
		pack $g.l$element_name $g.e$element_name -side left -expand 1
		bind $g.e$element_name <Return> LWDAQ_refresh_Recorder
	}

	foreach a "SP CP NP" {
		set b [string tolower $a]
		radiobutton $g.$b -variable LWDAQ_info_Recorder(display_mode) \
			-text $a -value $a
		pack $g.$b -side left -expand 0
	}
	
	button $g.reset -text "Reset and Configure" -command "LWDAQ_post LWDAQ_reset_Recorder"
	pack $g.reset -side left -expand 1

	label $g.lrv -text "Receiver:" 
	label $g.erv -textvariable LWDAQ_info_Recorder(receiver_version) -width 5
	pack $g.lrv $g.erv -side left -expand 1
	
	label $g.lfv -text "Firmware:" 
	label $g.efv -textvariable LWDAQ_info_Recorder(firmware_version) -width 3
	pack $g.lfv $g.efv -side left -expand 1

	set g $w.channels
	frame $g -border 2
	pack $g -side top -fill x

	label $g.l -text "Activity (id:qty) "
	pack $g.l -side left
	label $g.c -textvariable LWDAQ_info_Recorder(channel_activity) \
		-relief sunken -anchor w -width 90
	pack $g.c -side left -expand yes
}

#
# LWDAQ_daq_Recorder reads data from a data device. It fetches the data
# in blocks, and opens and closes a socket to the driver for each block.
# Although opening and closing sockets introduces a delay into the data
# acquisition, it allows another LWDAQ process to use the same LWDAQ
# driver in parallel, as may be required when we have two data receivers
# running on the same LWDAQ Driver, or a single data receiver and two
# animal location trackers, or a spectrometer. There is no way to obtain
# from a data receiver the number of messages available for download in
# its memory. The LWDAQ_daq_Recorder routine estimates the number of 
# messages available using aquire_end_ms, which it updates after every
# block download to be equal to or greater than the millisecond absolute
# time of the last clock message in the block. By subtracting the end
# time from the current time, the routine obtains an estimate of the 
# length of time spanned by the messages available in the data receiver.
# The routine also maintains an estimate of the number of messages per
# clock message in the recording. It multiplies this ratio by the available
# time and the clock frequency to get its estimate of the number of 
# messages avaialable in the data receiver. 
#
proc LWDAQ_daq_Recorder {} {
	global LWDAQ_Driver LWDAQ_Info
	upvar #0 LWDAQ_info_Recorder info
	upvar #0 LWDAQ_config_Recorder config

	# If they don't exist, create the buffer and scratch images.
	if {[lwdaq_image_exists $info(buffer_image)] == ""} {
		lwdaq_image_create \
			-width $info(daq_buffer_width) \
			-height $info(daq_buffer_width) \
			-name $info(buffer_image)
	}
	if {[lwdaq_image_exists $info(scratch_image)] == ""} {
		lwdaq_image_create \
			-width $info(daq_buffer_width) \
			-height $info(daq_buffer_width) \
			-name $info(scratch_image)
	}
		
	# Save the value of daq_num_clocks in case the user changes it 
	# during acquisition. Calculate the message length.
	set daq_num_clocks $config(daq_num_clocks)
	if {![string is integer -strict $daq_num_clocks]} {
		return "ERROR: Invalid number of clocks \"$daq_num_clocks\"."
	}
	set message_length [expr $info(core_message_length) + $config(payload_length)]
	
	# Check the buffer contents. If we have just reset the data receiver, this 
	# buffer will be empty, and no error will be caused by having the wrong
	# payload length.
	scan [lwdaq_recorder $info(buffer_image) \
		"-payload $config(payload_length) clocks 0 $daq_num_clocks"] %d%d%d%d%d \
		num_errors num_clocks num_messages start_index end_index
		
	if {[catch {
		# Set the block counter, which counts how many times we download a 
		# block of messages from the recorder.
		set block_counter 0
		
		# We download data until we have more than daq_num_clocks clock messages.
		# If the buffer already contains enough messages, we are already done without
		# any further download.
		while {$num_clocks <= $daq_num_clocks} {

			# Open a socket to driver and log in.
			set sock [LWDAQ_socket_open $config(daq_ip_addr)]
			LWDAQ_login $sock $info(daq_password)
	
			# Select the data receiver for communication within the LWDAQ.
			LWDAQ_set_device_type $sock $info(daq_device_type)
			LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
			
			# Configure the data receiver for data download.
			LWDAQ_transmit_command_hex $sock $info(upload_command)

			# Estimate the number of seconds of data available in the data receiver.
			# If we think there are few or no seconds of data, we download a minimum
			# duration. This minimum download, combined with the acquire lag we 
			# introduce when we update our acquire time, allows us to overcome a 
			# systematic error in our acquire time estimate, in which we think we have
			# advanced farther in the data receiver buffer than is actually the case.
			set time_fetch [expr 0.001 * ([clock milliseconds] - $info(acquire_end_ms))]
			if {$time_fetch < $info(min_time_fetch)} {
				set time_fetch $info(min_time_fetch)
			}
			if {$time_fetch > $info(max_time_fetch)} {
				set time_fetch $info(max_time_fetch)
			}
			
			# Calculate the length of the block of data we are going to attempt
			# to download from the data receiver.			
			set block_length [expr $message_length \
				* round( $time_fetch * $info(clock_frequency) ) \
				* $info(messages_per_clock)]
				
			# We are going to measure how long it takes to transfer the block 
			# of data from the receiver to the driver. We must first wait for
			# the driver to acknowledge that it has accepted our socket request,
			# or else our transfer time will include the time it takes for the
			# driver to finish jobs with other clients and start working on our
			# connection.
			LWDAQ_wait_for_driver $sock
			set block_start_ms [clock milliseconds]

			# Transfer bytes from receiver to the driver.
			LWDAQ_set_data_addr $sock 0
			LWDAQ_set_repeat_counter $sock [expr $block_length - 1]			
			LWDAQ_execute_job $sock $LWDAQ_Driver(read_job)
			
			# Wait for the driver to complete the transfer. If we have asked
			# for too much data, we will get a TCPIP timeout. The socket will
			# be closed either by the driver or by the LWDAQ process, whichever
			# has the shortest timeout. Once a timeout has occurred, the socket
			# will almost certainly be closed, but we make sure it is closed 
			# so we can open a new one to the same driver. Between closing one 
			# socket and opening another, the driver could serve any number of
			# other clients, so there will be no way to recover the data in its 
			# memory. We must open another socket, reset the data receiver, close 
			# the socket, and break out of data acquisition. This error occurs
			# most easily when we disconnect the source of messages from the
			# data receiver, such as when we unplug a single antenna that is
			# receiving from a dozen channels.
			if {[catch {LWDAQ_wait_for_driver $sock} read_error]} {
				if {[info exists sock]} {LWDAQ_socket_close $sock}
				LWDAQ_print $info(text) "WARNING: Timeout awaiting transfer\
					from receiver to driver. Resetting receiver."
				LWDAQ_update
				set sock [LWDAQ_socket_open $config(daq_ip_addr)]
				LWDAQ_login $sock $info(daq_password)
				LWDAQ_set_driver_mux $sock $config(daq_driver_socket) $config(daq_mux_socket)
				LWDAQ_transmit_command_hex $sock $info(reset_command)
				LWDAQ_wait_for_driver $sock
				LWDAQ_socket_close $sock
				set start_index 0
				set end_index [expr $num_messages - 1]
				set info(messages_per_clock) $info(min_messages_per_clock)
				break
			}
			
			# Calculate the block transfer time. If the data was waiting in the 
			# receiver, it will transfer at roughly 1.4 MBytes/s to the driver 
			# memory, for both the old and new drivers. If the driver has to wait
			# for the data to arrive from transmitters and the receiver clock, 
			# the transfer takes much longer. 
			set block_ms [expr [clock milliseconds] - $block_start_ms]
			if {$block_ms < 1} {set block_ms 1}
			
			# Download data from the driver into a local byte array.
			set data [LWDAQ_ram_read $sock 0 $block_length]
						
			# Put the data in the scratch image. 
			lwdaq_data_manipulate $info(scratch_image) clear
			lwdaq_data_manipulate $info(scratch_image) write 0 $data
			
			# Check the block for errors and count the number of clocks and messages
			# it containes.
			scan [lwdaq_recorder $info(scratch_image) \
				"-payload $config(payload_length) clocks"] %d%d%d \
				num_errors num_new_clocks num_new_messages

			# We use the show_errors and show_error_extent parameters to control
			# the display of raw message blocks that contain errors.
			if {($num_errors > 0) && $info(show_errors)} {
				set result [lwdaq_recorder $info(scratch_image) \
					"-payload $config(payload_length) print 0 1"]
				if {[regexp {index=([0-9]+)} $result match index]} {
					set result [lwdaq_recorder $info(scratch_image) \
						"-payload $config(payload_length) print \
						[expr $index-$info(show_error_extent)] \
						[expr $index+$info(show_error_extent)]"]
					LWDAQ_print $info(text) $result purple
				} {
					LWDAQ_print $info(text) $result purple
				}
			}
				
			# If we see errors in the new data, we check to see if this is because we are
			# using the wrong payload length. If so, we throw away the data we just downloaded,
			# reset the data receiver, close the socket, and abandon this acquisition. If not,
			# we throw away the data, reset the receiver, close the socket, and keep trying.
			# We throw away the data and reset the receiver because all algorithms for trying 
			# to recover from data errors without resetting the receiver are vulnerable to rare 
			# error sources that cause disastrous loss of data. By resetting the data receiver, 
			# we make sure that it is in a known state for our next download. But we lose
			# continuity of clock messages within the data buffer.
			if {$num_errors > 0} {
				foreach pl $info(payload_options) {
					scan [lwdaq_recorder $info(scratch_image) \
						"-payload $pl clocks"] %d%d%d ne nc nm
					if {$ne == 0} {break}
				}
				
				if {$ne == 0} {
					LWDAQ_print $info(text) \
						"WARNING: Suspect payload length $config(payload_length) is wrong.\
							Resetting data receiver and trying again."
				} {
					LWDAQ_print $info(text) \
						"WARNING: Received corrupted data.\
							Resetting data receiver and trying again."
				}

				LWDAQ_transmit_command_hex $sock $info(reset_command)
				LWDAQ_wait_for_driver $sock
				LWDAQ_socket_close $sock
				continue
			}
			
			# If purge_duplicates is set, we remove duplicate messages from the 
			# block before we do any processing.
			if {$info(purge_duplicates)} {
				set num_unique_messages \
					[lwdaq_recorder $info(scratch_image) \
						"-payload $config(payload_length) purge"]
				set data [lwdaq_data_manipulate $info(scratch_image) read \
					0 [expr $num_unique_messages * $message_length]]
				set num_new_messages $num_unique_messages
			}

			# Adjust the number of messages per clock we expect in our next
			# download, making sure we count the duplicate messages that may
			# have existed before we purged the data.
			set saved_messages_per_clock $info(messages_per_clock)
			if {$num_new_clocks > 1} {
				set info(messages_per_clock) [expr \
					round( 1.0 * $block_length / $message_length / $num_new_clocks )]
			}
			if {$info(messages_per_clock) < $info(min_messages_per_clock)} {
				set info(messages_per_clock) $info(min_messages_per_clock)
			}
			if {$info(messages_per_clock) > 2 * $saved_messages_per_clock} {
				set info(messages_per_clock) [expr 2 * $saved_messages_per_clock]
			}
			
			# Adjust the acquire time using the number of new clock messages and the block
			# transfer time. If the block transfer time was comparable to the interval time,
			# we can assume the data receiver buffer is empty, which means the acquire time is
			# equal to the current time. Otherwise, we add to the acquire time the time
			# spanned by the messages in the block we downloaded, which we calculate from the
			# number of clocks it contains and the clock frequency. If the clock on the data
			# receiver is faster than the clock in our computer, we will download one second
			# of data and think it spans more than one second. Our acquire time will be wrong:
			# we think we have downloaded all the messages in the data receiver up to the
			# acquire time, but we have failed to do so. As hours go by, we lag farther and
			# farther behind the data in the data receiver until its buffer overflows. The
			# acquire_lag is the number of clocks we subtract from the numer we have just
			# acquired, so that our estimate of the time spanned by the data we download will
			# always be lower than the actual time it spans. Occasionally we will reach the
			# end of the buffer on the data receiver because it occurs earlier than our
			# acquire time suggests. At that point, we will reset the acquire time to the
			# current time because we detect the empty buffer with the block transfer time.
			set clock_ms [clock milliseconds]
			set acquired_ms [expr round( \
				1000.0 * ($num_new_clocks + 1) / $info(clock_frequency) )]
			if {$block_ms > 1000.0 * $info(empty_fraction) * $time_fetch} {
				set info(acquire_end_ms) $clock_ms
				set lag_ms 0
				# Un-comment to report when we detect an empty receiver buffer.
				# LWDAQ_print $info(text) "Empty buffer detected." purple

			} {
				set info(acquire_end_ms) [expr $info(acquire_end_ms) + $acquired_ms]
				if {$info(acquire_end_ms) > $clock_ms} {
					set info(acquire_end_ms) $clock_ms
				}
				set lag_ms [expr $clock_ms - $info(acquire_end_ms)]
			}	
			# Un-comment to report various time parameters used to adapt to interruptions
			# in data acquisition.
			# LWDAQ_print $info(text) "$time_fetch $acquired_ms $lag_ms $block_ms" orange

			# Check that we can fit the existing data in the buffer image. If not,
			# discard the data instead of adding it to the buffer, stop this 
			# data acquisition, and return the entire buffer as a source
			# of data.
			if {($num_new_messages + $num_messages) * $message_length > \
					[expr $info(daq_buffer_width) * ($info(daq_buffer_width) - 1)]} {
				LWDAQ_print $info(text) "ERROR: Buffer overflow, abandoning this acquisition."
				LWDAQ_socket_close $sock
				set start_index 0
				set end_index [expr $num_messages - 1]
				break
			}
			
			# Append the new messages to buffer image. If we purged the data, the purged
			# data has already been copied back into the data array.
			lwdaq_data_manipulate $info(buffer_image) write \
				[expr $num_messages * $message_length] $data

			# Check the new buffer contents.
			scan [lwdaq_recorder $info(buffer_image) \
				"-payload $config(payload_length) clocks 0 $daq_num_clocks"] %d%d%d%d%d \
				num_errors num_clocks num_messages start_index end_index
			
			# If we have too many errors in the message buffer, we reset the data receiver,
			# wait for the driver to respond, close the socket, and break out of the 
			# acquisition loop, returning the entire message buffer as data.
			if {$num_errors > $info(errors_for_stop)} {
				LWDAQ_print $info(text) \
					"ERROR: Severely corrupted data.\
						resetting data receiver and\
						abandoning this acquisition."
				LWDAQ_transmit_command_hex $sock $info(reset_command)
				LWDAQ_wake $sock
				LWDAQ_wait_for_driver $sock
				LWDAQ_socket_close $sock
				set start_index 0
				set end_index [expr $num_messages - 1]
				set info(messages_per_clock) $info(min_messages_per_clock)
				break
			}

			# Check the block counter to see if we have made too many attempts
			# to get our data. 
			incr block_counter
			if {$block_counter > $info(max_block_reads)} {
				LWDAQ_print $info(text) \
					"ERROR: Failed to accumulate clock messages,\
						resetting data receiver and\
						abandoning this acquisition."
				LWDAQ_transmit_command_hex $sock $info(reset_command)
				LWDAQ_wake $sock
				LWDAQ_wait_for_driver $sock
				LWDAQ_socket_close $sock
				set start_index 0
				set end_index [expr $num_messages - 1]
				set info(messages_per_clock) $info(min_messages_per_clock)
				break
			}
			
			# Disable data upload from data receiver and close socket.
			LWDAQ_wake $sock
			LWDAQ_wait_for_driver $sock
			LWDAQ_socket_close $sock
		}
	} error_result]} { 
		# To get here, we have encountered a TCPIP communication error other than
		# a timeout waiting for the data receiver to supply data. We don't attempt
		# to reset the data receiver, but we reset the block size.
		if {[info exists sock]} {LWDAQ_socket_close $sock}
		set info(messages_per_clock) $info(min_messages_per_clock)
		return "ERROR: $error_result"
	}
	
	# Create the new data image, storing extra data in the
	# Recorder's buffer image.
	set config(memory_name) [lwdaq_image_create \
		-width $info(daq_image_width) \
		-height $info(daq_image_height) \
		-left $info(daq_image_left) \
		-right $info(daq_image_right) \
		-top $info(daq_image_top) \
		-bottom $info(daq_image_bottom) \
		-name "$info(name)\_$info(counter)"]
	
	# Extract data from the buffer.
	if {($start_index <= $end_index) && ($start_index >= 0) && ($end_index > 0)} {
		set start_addr [expr $message_length * $start_index]
		set end_addr [expr $message_length * $end_index]
		set data [lwdaq_data_manipulate $info(buffer_image) read \
			 $start_addr [expr $end_addr - $start_addr] ]
		lwdaq_data_manipulate $info(buffer_image) shift $end_addr
	} {
		set data ""
		lwdaq_data_manipulate $info(buffer_image) clear
	}
	
	# Write data into the new data image, but check that the data will fit.
	set max_length [expr $info(daq_image_width) * ($info(daq_image_height) - 1)]
	if {[string length $data] > $max_length} {
		LWDAQ_print $info(text) "WARNING: Discarding\
			[expr [string length $data] - $max_length]\
			bytes to fit data image."
		set data [string range $data 0 [expr $max_length - 1]]
	}
	lwdaq_data_manipulate $config(memory_name) write 0 $data
	
	return $config(memory_name) 
} 

