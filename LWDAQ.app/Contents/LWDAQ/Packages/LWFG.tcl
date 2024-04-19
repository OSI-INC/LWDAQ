# Long-Wire Function Generator Package
# 
# (C) 2023-2024, Kevan Hashemi, Open Source Instruments Inc.
#
# Routines that interact with Long-Wire Data Acquisition Function Generators
# (LWFGs). These are devices are TCPIP servers that we control using LWDAQ
# Messages. The A3050, for example, is a power over ethernet (PoE) device that
# we plug into a PoE switch for both power and communication. With its reset and
# configuration switches, we force its IP address to the default LWDAQ Relay
# value 10.0.0.37, and from there we use the Configurator Tool to configure the
# relay for our use. 
#
# Load within LWDAQ with the package require command. The routines the package
# uses are to be found in the LWDAQ Driver.tcl file, from which the code that
# performs the communication with the function generator may be copied.
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
#

# Version 1.1 [01-FEB-24] First version, in use in the SCT Checkt tool.
# Version 1.2 [20-MAR-24] Clip waveform DAC values to 0..255.
# Version 1.3 [28-MAR-24] Fix reset value of triangle wave: now zero volts.

# Load this package or routines into LWDAQ with "package require EDF".
package provide LWFG 1.4

# Clear the global EDF array if it already exists.
if {[info exists LWFG]} {unset LWFG}

set LWFG(data_portal) "63"
set LWFG(ch1_ram) "0x0000"
set LWFG(ch1_rc) "0x8000"
set LWFG(ch1_div) "0x8002"
set LWFG(ch1_len) "0x800A"

set LWFG(ch2_ram) "0x4000"
set LWFG(ch2_rc) "0x8001"
set LWFG(ch2_div) "0x8006"
set LWFG(ch2_len) "0x800C"

set LWFG(max_pts) "8192"
set LWFG(min_pts) "4000"
set LWFG(clock_hz) "40.000e6"
set LWFG(div_min) "2"

set LWFG(ch_cnt_lo) "0"
set LWFG(ch_cnt_z) "128"
set LWFG(ch_cnt_hi) "255"
set LWFG(ch_v_lo) "-10.0"
set LWFG(ch_v_hi) "+10.0"

set LWFG(rc_options) "1.3e1 0x01 5.1e1 0x11 1.1e2 0x21 2.7e2 0x14 5.6e2 0x18 1.1e3 0x21 \
		2.4e3 0x22 5.9e3 0x24 1.2e4 0x28 2.6e4 0x41 5.5e4 0x42 1.4e5 0x44 \
		2.8e5 0x48 1.0e6 0x81 2.2e6 0x82 5.4e6 0x84 1.1e7 0x88"
set LWFG(rc_fraction) "0.01"
set LWFG(rc_default) "0x01"
	
#
# LWDAQ_off sets the output of the function generator at address IP, channel number
# ch_num to zero, and sets the filter value to default.
#
proc LWFG_off {ip ch_num} {
	global LWFG

	# Configure the function generator for zero output.
	if {[catch {

		# Open a socket to the function generator.
		set sock [LWDAQ_socket_open $ip]
		
		# Write a single zero to the waveform memory.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_ram)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c $LWFG(ch_cnt_z)]
		
		# Set the filter configuration register to its default value.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_rc)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c $LWFG(rc_default)]
		
		# Set the clock divisor to one, for which we write a zero.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_div)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format I 0]
		
		# Set the waveform length to zero.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_len)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format S 0]
		
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
# LWFG_configure configures a function generator for continuous generation of a square,
# triangle, or sine wave. We specify an IP address and channel number. We give the 
# frequency and the low and high voltages of the waveform.
#
proc LWFG_configure {ip ch_num waveform frequency v_lo v_hi} {
	global LWFG

	# Determine the lower and upper DAC values for our lower and upper waveform
	# voltages.
	set lsb [expr ($LWFG(ch_v_hi) - $LWFG(ch_v_lo)) \
		/ ($LWFG(ch_cnt_hi) - $LWFG(ch_cnt_lo))]
	set dac_lo [expr round(($v_lo - $LWFG(ch_v_lo)) / $lsb)]
	set dac_hi [expr round(($v_hi - $LWFG(ch_v_lo)) / $lsb)]

	# We begin by getting getting the number of points we need for one period
	# with the fastest sample rate, and if num_pts is too large, we increase
	# the divisor until num_pts is small enough.
	set divisor $LWFG(div_min)
	set num_pts [expr round($LWFG(clock_hz) / $frequency / $divisor)]
	while {$num_pts > $LWFG(max_pts)} {
		incr divisor
		set num_pts [expr round($LWFG(clock_hz) / $frequency / $divisor)]
	}
	
	# If num_pts is too small, we increase the number of cycles in the waveform
	# and recalculate our number of points until it is large enough.
	set num_cycles 1
	while {$num_pts < $LWFG(min_pts)} {
		incr num_cycles
		set num_pts [expr round($LWFG(clock_hz) * $num_cycles / $frequency / $divisor)]
	}

	# Calculate the actual frequency we are going to get.
	set actual [format %.3f [expr $LWFG(clock_hz)*$num_cycles/$num_pts/$divisor]]
	
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
	set rc [lindex $LWFG(rc_options) 0]
	set filter [lindex $LWFG(rc_options) 1]
	switch $waveform {
		"sine"     - 
		"triangle" {
			set ideal_rc [expr 1.0E9/$frequency*$LWFG(rc_fraction)]
			foreach {p code} $LWFG(rc_options) {
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
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_ram)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c* $values]
		
		# Set the filter configuration register.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_rc)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format c [expr $filter]]
		
		# Set the clock divisor.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_div)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format I [expr $divisor - 1]]
		
		# Set the waveform length.
		LWDAQ_set_data_addr $sock $LWFG(ch$ch_num\_len)
		LWDAQ_stream_write $sock $LWFG(data_portal) [binary format S [expr $num_pts - 1]]
		
		# Wait for the controller to be done with configuration.
		set id [LWDAQ_hardware_id $sock]
		
		# Close the socket.
		LWDAQ_socket_close $sock
	} error_message]} {
		catch {LWDAQ_socket_close $sock}
		return "ERROR: $error_message\."
	}
	
	# Return enough information about the waveform for us to assess accuracy.
	return "$dac_lo $dac_hi $divisor $num_pts $num_cycles [format %.0f $rc]"
}
