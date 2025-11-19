# Analog Signal Generator Package
# 
# (C) 2023-2025, Kevan Hashemi, Open Source Instruments Inc.
#
# Routines that interact with Analog Signal Generators (ASG). These are devices
# are LWDAQ Servers that we control using LWDAQ Messages. The Function Generator
# (A3050) and Analog Signal Generator (A3052) are power over ethernet (PoE)
# devices that we plug into a PoE switch for both power and communication. With
# its reset and configuration switches, we force the generator's IP address to
# the default LWDAQ Relay value 10.0.0.37, and from there we use the
# Configurator Tool to configure the relay for our use. 
#
# Load the ASG routines into your LWDAQ process with the "package require"
# command. The package itself calls routines from LWDAQ Driver.tcl to
# communicate with the function generator. This communication uses the LWDAQ
# messaging protocol.
#

#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA  02111-1307, USA.
#

# V1.1 [01-FEB-24] First version, in use in the SCT Checkt tool.
# V1.2 [20-MAR-24] Clip waveform DAC values to 0..255.
# V1.3 [28-MAR-24] Fix reset value of triangle wave: now zero volts.
# V1.4 [13-JUN-24] Update time constants to suite A3050B.
# V1.5 [25-JUN-24] Add sinusoidal sweep routine.
# V1.6 [01-NOV-24] New FG memory map.
# V1.7 [04-NOV-24] Implement automatic attenuation selection.
# V1.8 [19-NOV-25] Change name to Analog Signal Generator Package, ASG.

# Load this package or routines into LWDAQ with "package require EDF".
package provide ASG 1.8

# Clear the global EDF array if it already exists.
if {[info exists ASG]} {unset ASG}

# The control address through which we communicate with the data address.
set ASG(data_portal) "63"

# Data addresses for channel one.
set ASG(ch1_ram) "0x0000"
set ASG(ch1_div) "0x8000"
set ASG(ch1_len) "0x8004"
set ASG(ch1_rc)  "0x8006"
set ASG(ch1_att) "0x8007"

# Data addresses for channel two.
set ASG(ch2_ram) "0x4000"
set ASG(ch2_div) "0x8010"
set ASG(ch2_len) "0x8014"
set ASG(ch2_rc)  "0x8016"
set ASG(ch2_att) "0x8017"

# Shared characteristics of the channels.
set ASG(max_pts) "8192"
set ASG(min_pts) "4000"
set ASG(clock_hz) "40.000e6"
set ASG(div_min) "2"

# Counts and voltages.
set ASG(ch_cnt_lo) "0"
set ASG(ch_cnt_z) "128"
set ASG(ch_cnt_hi) "255"
set ASG(ch_v_lo) "-10.0"
set ASG(ch_v_hi) "+10.0"

# The low-pass filter consists of a single resistor-capacitor (RC) time constant.
# Here we list each available time constant in units of nanosectons, followed by 
# the eight-bit code we send to the channel's time constant register to establish
# the filter. We list them in order of increasing time constant.
set ASG(rc_options) "1.3e1 0x01 5.1e1 0x11 1.1e2 0x21 2.7e2 0x14 5.6e2 0x18 1.1e3 0x21 \
		2.4e3 0x22 5.9e3 0x24 1.2e4 0x28 2.6e4 0x41 5.5e4 0x42 1.4e5 0x44 \
		2.8e5 0x48 1.0e6 0x81 2.2e6 0x82 5.4e6 0x84 1.1e7 0x88"
		
# The ideal filter for sine and triangle waves has a time constant that is some
# fraction of the waveform period.
set ASG(rc_fraction) "0.01"

# The attenuator consists of a series resistor and four selectable dividing resistors.
set ASG(att_options) "1.04 0x00 0.320 0x01 0.116 0x03 0.0588 0x07 0.0360 0x0F"

#
# LWDAQ_off sets the output of the function generator at address IP, channel number
# ch_num to zero, and sets the filter value to default.
#
proc ASG_off {ip ch_num} {
	global ASG

	# Configure the function generator for zero output.
	if {[catch {

		# Open a socket to the function generator.
		set sock [LWDAQ_socket_open $ip]
		
		# Write a single zero to the waveform memory.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_ram)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format c $ASG(ch_cnt_z)]

		# Set the filter configuration register to its default value, which is the
		# code for the first time constant in our list of time constant options.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_rc)
		LWDAQ_stream_write $sock $ASG(data_portal) \
			[binary format c [lindex $ASG(rc_options) 1]]

		# Set the clock divisor to one, for which we write a zero.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_div)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format I 0]

		# Set the waveform length to zero.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_len)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format S 0]

		# Wait for the controller to be done with configuration.
		set id [LWDAQ_hardware_id $sock]
		
		# Close the socket.
		LWDAQ_socket_close $sock
	} error_message]} {
		catch {LWDAQ_socket_close $sock}
		return "ERROR: $error_message\."
	}

	return ""
}

#
# ASG_configure configures a function generator for continuous generation of a
# square, triangle, or sine wave. We specify an IP address and channel number.
# We give the frequency and the low and high voltages of the waveform.
#
proc ASG_configure {ip ch_num waveform frequency v_lo v_hi} {
	global ASG
	
	# Determine if we should use an attenuator setting. 
	set attenuator [lindex $ASG(att_options) 1]
	set attenuition [lindex $ASG(att_options) 0]
	foreach {a c} $ASG(att_options) {
		if {($v_lo/$a <=  $ASG(ch_v_hi)) && ($v_lo/$a >= $ASG(ch_v_lo)) \
		&& ($v_hi/$a <=  $ASG(ch_v_hi)) && ($v_hi/$a >= $ASG(ch_v_lo))} {
			set attenuator $c
			set attenuition $a
		}
	}
	
	# Adjust the v_lo and v_hi to suite the attenuition.
	set v_lo [expr $v_lo / $attenuition]
	set v_hi [expr $v_hi / $attenuition]

	# Determine the lower and upper DAC values for our lower and upper waveform
	# voltages.
	set lsb [expr ($ASG(ch_v_hi) - $ASG(ch_v_lo)) \
		/ ($ASG(ch_cnt_hi) - $ASG(ch_cnt_lo))]
	set dac_lo [expr round(($v_lo - $ASG(ch_v_lo)) / $lsb)]
	set dac_hi [expr round(($v_hi - $ASG(ch_v_lo)) / $lsb)]

	# Begin by getting getting the number of points we need for one period with
	# the fastest sample rate, and if num_pts is too large, we increase the
	# divisor until num_pts is small enough.
	set divisor $ASG(div_min)
	set num_pts [expr round($ASG(clock_hz) / $frequency / $divisor)]
	while {$num_pts > $ASG(max_pts)} {
		incr divisor
		set num_pts [expr round($ASG(clock_hz) / $frequency / $divisor)]
	}
	
	# If num_pts is too small, we increase the number of cycles in the waveform
	# and recalculate our number of points until it is large enough.
	set num_cycles 1
	while {$num_pts < $ASG(min_pts)} {
		incr num_cycles
		set num_pts [expr round($ASG(clock_hz) * $num_cycles / $frequency / $divisor)]
	}

	# Calculate the actual frequency we are going to get.
	set actual [format %.3f [expr $ASG(clock_hz)*$num_cycles/$num_pts/$divisor]]
	
	# Generate the waveform.
	set values [list]
	set period [expr 1.0*$num_pts/$num_cycles]
	switch $waveform {
		"sine" {
			set pi 3.141592654
			for {set i 0} {$i < $num_pts} {incr i} {
				set phase [expr fmod($i,$period)/$period]
				lappend values [expr $dac_lo + \
					round(($dac_hi-$dac_lo)*0.5*(1.0+sin(2*$pi*$phase)))]
			}
		}
		"square" {
			for {set i 0} {$i < $num_pts} {incr i} {\
				set phase [expr fmod($i,$period)/$period]
				if {$phase <= 0.5} { 
					lappend values $dac_hi
				} else {
					lappend values $dac_lo
				}
			}
		}
		"triangle" {
			for {set i 0} {$i < $num_pts} {incr i} {\
				set phase [expr fmod($i,$period)/$period]
				if {$phase <= 0.5} { 
					lappend values [expr $dac_lo + \
						round(($dac_hi-$dac_lo)*$phase*2.0)]
				} else {
					lappend values [expr $dac_hi - \
						round(($dac_hi-$dac_lo)*($phase-0.5)*2.0)]
				}
			}
		}
		default {
			return "ERROR: Unkown waveform \"$waveform\"."
		}
	}
	
	# Limit the values to the range 0 to 255.
	set clipped_values [list]
	foreach value $values {
		if {$value < 0} {set value 0}
		if {$value > 255} {set value 255}
		lappend clipped_values $value
	}
	set values $clipped_values
	
	# Choose the filter.
	set rc [lindex $ASG(rc_options) 0]
	set filter [lindex $ASG(rc_options) 1]
	switch $waveform {
		"sine"     - 
		"triangle" {
			set ideal_rc [expr 1.0E9/$frequency*$ASG(rc_fraction)]
			foreach {p code} $ASG(rc_options) {
				if {$p < $ideal_rc} {
					set filter $code
					set rc $p
				}
			}
		}
	}
	
	# Configure the function generator using TCPIP messaging.
	if {[catch {
	
		# Open a socket to the function generator.
		set sock [LWDAQ_socket_open $ip]
		
		# Write the waveform values to the waveform memory.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_ram)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format c* $values]
		
		# Set the filter configuration register.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_rc)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format c [expr $filter]]
		
		# Set the attenuator configuration register.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_att)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format c [expr $attenuator]]
		
		# Set the clock divisor.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_div)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format I [expr $divisor - 1]]
		
		# Set the waveform length.
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_len)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format S [expr $num_pts - 1]]
		
		# Wait for the controller to be done with configuration.
		set id [LWDAQ_hardware_id $sock]
		
		# Close the socket.
		LWDAQ_socket_close $sock
	} error_message]} {
		catch {LWDAQ_socket_close $sock}
		return "ERROR: $error_message\."
	}
	
	# Return enough information about the waveform for us to assess accuracy.
	return "$dac_lo $dac_hi $divisor $num_pts $num_cycles\
		[format %.0f $rc] [format %.4f $attenuition]"
}

#
# ASG_sweep_sine sets up a sinusoidal sweep that lasts for t_len seconds,
# starting at f_lo, ending at f_hi, with the sinusoid spanning voltage v_lo to
# v_hi, on channel ch_num. The log flag determines if the frequency will be
# increased in a logarithmic or linear manner during the sweep.
#
proc ASG_sweep_sine {ip ch_num f_lo f_hi v_lo v_hi t_len log} {
	global ASG

	# Determine if we should use an attenuator setting. 
	set attenuator [lindex $ASG(att_options) 1]
	set attenuition [lindex $ASG(att_options) 0]
	foreach {a c} $ASG(att_options) {
		if {($v_lo/$a <=  $ASG(ch_v_hi)) && ($v_lo/$a >= $ASG(ch_v_lo)) \
		&& ($v_hi/$a <=  $ASG(ch_v_hi)) && ($v_hi/$a >= $ASG(ch_v_lo))} {
			set attenuator $c
			set attenuition $a
		}
	}
	
	# Adjust the v_lo and v_hi to suite the attenuition.
	set v_lo [expr $v_lo / $attenuition]
	set v_hi [expr $v_hi / $attenuition]

	# Determine the lower and upper DAC values for our lower and upper waveform
	# voltages.
	set lsb [expr ($ASG(ch_v_hi) - $ASG(ch_v_lo)) \
		/ ($ASG(ch_cnt_hi) - $ASG(ch_cnt_lo))]
	set dac_lo [expr round(($v_lo - $ASG(ch_v_lo)) / $lsb)]
	set dac_hi [expr round(($v_hi - $ASG(ch_v_lo)) / $lsb)]

	# Our sweep will use the maximum number of locations in memory so as to give
	# the finest definition.
	set num_pts $ASG(max_pts)
	set divisor [expr round(($ASG(clock_hz) * $t_len) / $num_pts) - "1"]
	
	# Generate the waveform.
	set values [list]
	set period [expr 1.0*$num_pts]
	set pi 3.141592654
	for {set i 0} {$i < $num_pts} {incr i} {
		set phase [expr fmod($i,$period)/$period]
		if {$log} {
			lappend values [expr $dac_lo + \
				round(($dac_hi - $dac_lo) * 0.5 * \
					(1.0+sin(2*$pi*($f_lo*$t_len* \
						((pow(($f_hi/$f_lo), ($phase)) - 1) \
							/(log($f_hi/$f_lo)))))))]
		} else {
			lappend values [expr $dac_lo + \
				round(($dac_hi - $dac_lo) * 0.5 * \
					(1.0+sin(2*$pi*$t_len*(($f_lo+ \
						(($f_hi-$f_lo)/2)*$phase)*$phase))))]
		}
	}

	# Choose the filter.
	set rc [lindex $ASG(rc_options) 0]
	set filter [lindex $ASG(rc_options) 1]
	set ideal_rc [expr 1.0E9/($f_hi)*$ASG(rc_fraction)]
	foreach {p code} $ASG(rc_options) {
		if {$p < $ideal_rc} {
			set filter $code
			set rc $p
		}
	}
	
	# Limit the values to the range 0 to 255.
	set clipped_values [list]
	foreach value $values {
		if {$value < 0} {set value 0}
		if {$value > 255} {set value 255}
		lappend clipped_values $value
	}
	set values $clipped_values
	
	# Configure the function generator using TCPIP messaging.
	if {[catch {

		# Open a socket to the function generator.
		set sock [LWDAQ_socket_open $ip]
		
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_ram)
		LWDAQ_stream_write $sock $ASG(data_portal) [binary format c* $values]

		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_rc)
		LWDAQ_stream_write $sock $ASG(data_portal) \
			[binary format c [expr $filter]]
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_att)
		LWDAQ_stream_write $sock $ASG(data_portal) \
			[binary format c [expr $attenuator]]
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_div)
		LWDAQ_stream_write $sock $ASG(data_portal) \
			[binary format I [expr $divisor - 1]]
		LWDAQ_set_data_addr $sock $ASG(ch$ch_num\_len)
		LWDAQ_stream_write $sock $ASG(data_portal) \
			[binary format S [expr $num_pts - 1]]

		set id [LWDAQ_hardware_id $sock]
		LWDAQ_socket_close $sock
	} error_message]} {
		catch {LWDAQ_socket_close $sock}
		return "ERROR: $error_message\."
	}
	
	# Return enough information about the waveform for us to assess accuracy.
	return "$dac_lo $dac_hi $divisor $num_pts 1\
		[format %.0f $rc] [format %.4f $attenuition]"
}


