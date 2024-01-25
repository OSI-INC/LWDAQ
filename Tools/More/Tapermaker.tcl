# Tapermaker, a LWDAQ Tool
#
# Copyright (C) 2011-2014 Michael Collins, Open Source Instruments
# Copyright (C) 2014-2024 Kevan Hashemi, Open Source Instruments
#
# Controls the taper-making machine we use to make tapered light guides for our
# implantable stimulators.

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

#
# Initialization procedure, runs when tool is started.
#
proc Tapermaker_init {} {
	upvar #0 Tapermaker_info info
	upvar #0 Tapermaker_config config
	global LWDAQ_Info LWDAQ_Driver

	LWDAQ_tool_init "Tapermaker" "2.9"
	if {[winfo exists $info(window)]} {return ""}
	
	# Conversion constants.
	set info(steps_per_mm) "4000"
	
	# Variables.
	set config(right_distance) "-1"
	set config(left_distance) "-1"
	
	# The reset and go-home speeds.
	set config(reset_speed_mmps) "2.0"
	set config(acceleration_mmpss) "10.0"
	
	# Set the home positions of the two motors.
	set config(right_home_position_mm) "24.0"
	set config(left_home_position_mm) "42.0"
	
	# The distance moved on approach from home to the heating coil. The bottom
	# of the coil will be just above the lower fiber mounting plate. The differential
	# is a factor by which the top motor moves faster than the lower.
	set config(approach_distance_mm) "10.0"
	set config(approach_speed_mmps) "1.0"
	set config(approach_differential_mmpmm) "1.02"

	# Stretch speed (mm/s) and distance (mm) for the top and bottom portions
	# of the fiber that we are separating into two tapered portions. Also
	# A bottom portion delay between the start of the top stretch movement
	# and the bottom stretch movement.
	set config(left_stretch_delay_s) "0.0"
	set config(left_stretch_distance_mm) "10.0"
	set config(left_stretch_speed_mmps) "2.0"
	set config(right_stretch_delay_s) "2.0"
	set config(right_stretch_distance_mm) "10.0"
	set config(right_stretch_speed_mmps) "2.0"
	
	# The Terminal Instrument settings that allow communication with the
	# motor controller. We have a transmit string header consisting of 
	# an XOFF command, character 19. 
	set config(daq_ip_addr) "192.168.1.12"
	set config(daq_driver_socket) "1"
	set config(daq_mux_socket) "1"
	set config(tx_header) "19" 
	set config(tx_ascii) ""
	set config(tx_footer) "13 10"
	set config(rx_last) "0"
	set config(rx_timeout_ms) "1000"
	set config(rx_size) "1000"
	set config(xmit_cmd) "<01 H01"
	set config(analysis_enable) "5"
	set config(xmit_rx) "0"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	}
	return ""
}

#
# Tapermaker_xmit transmits a string of commands followed by a carriage return
# and line feed to the motor controller via the Terminal Instrument and an
# RS-232 Interface (A2060C). If the command string we pass is blank, we use the
# xmit_cmd string in the configuration array. We pass the string of commands in
# through the "cmd" argument. The "rxen" argument is a flag. By default, rxen is
# cleared, but if set, the xmit routine will wait for an answer from the motor
# controller in response to the command, using rx_last, rx_timeout_ms, and rx_size.
# The result string will then be analyzed and displayed using the Terminal analysis
# type given by analysis_enable.
#
proc Tapermaker_xmit {cmd {rxen "0"}} {
	upvar #0 Tapermaker_info info
	upvar #0 Tapermaker_config config
	upvar #0 LWDAQ_config_Terminal tconfig
	upvar #0 LWDAQ_info_Terminal tinfo

	set tconfig(tx_ascii) "$cmd"

	foreach a {daq_ip_addr daq_driver_socket daq_mux_socket tx_footer} {
		set tconfig($a) $config($a)
	}
	if {$rxen} {
		foreach a {rx_size rx_last rx_timeout_ms analysis_enable} {
			set tconfig($a) $config($a)
		}
	} else {
		foreach a {rx_size rx_last rx_timeout_ms analysis_enable} {
			set tconfig($a) 0
		}
	}

	LWDAQ_print $info(text) $cmd brown
	set result [LWDAQ_acquire Terminal]
	if {$rxen} {
		if {![LWDAQ_is_error_result $result]} {
			LWDAQ_print $info(text) $result
		} else {
			LWDAQ_print $info(text)
		}
	}
	
	return ""
}

#
# Tapermaker_stop transmits a stop command to all motor controllers to be executed
# immediately.
#
proc Tapermaker_stop {} {
	upvar #0 Tapermaker_info info
	upvar #0 Tapermaker_config config
	
	LWDAQ_print $info(text) "Transmitting STOP command."
	Tapermaker_xmit "<00 *"
	LWDAQ_print $info(text) "Stop command transmitted.\n"
	return ""
}

#
# Tapermaker_off turns off the current to the motor windings.
#
proc Tapermaker_off {} {
	upvar #0 Tapermaker_info info
	upvar #0 Tapermaker_config config
	
	LWDAQ_print $info(text) "Transmitting Off command."
	Tapermaker_xmit "<00 H36"
	LWDAQ_print $info(text) "Off command transmitted.\n"
	return ""
}

#
# Tapermaker_reset sends the two stages to their home positions, in which they
# are ready to commence a tapering operation. If one of the limit switches is
# active when the home procedure begins, the accuracy of the home position
# cannot be guaranteed. In this case, the procedure should be run twice. Before
# we drive the stages to their home positions, we configure the motor
# controllers for our purposes. Prior to this configuration, however, each motor
# must be configured on its own to give it a motor identifier, which we call its
# ID. The No1 motor is driven by the No1 controller, and the No2 motor is driven
# by the No2 controller. We use "L21 1" to set a controller's ID to 1, and "L21
# 2" for 2. If we turn off the power on the controllers, they will eventually
# forget their ID number, so unplug No2 and program No1, then unplug No1 and
# program No2 with the "L21" command, then plug both in at the same time.
# 
proc Tapermaker_reset {} {
	upvar #0 Tapermaker_info info
	upvar #0 Tapermaker_config config

	LWDAQ_print $info(text) "Configuring motor controllers."	
	
	# Translate millimeters per second and millimeters per second per second 
	# into pulses per second and pulses per second per second.
	set reset_speed [expr round($config(reset_speed_mmps) * $info(steps_per_mm))]
	set acceleration [expr round($config(acceleration_mmpss) * $info(steps_per_mm))]

	# "<00" Select all controllers for universal configuration.
	Tapermaker_xmit "<00"

	# "L45 0" Activate limit switches.
	#
	# "H35" Turn on the motor windings. The windings will be powered until the 
	# user sends an H36 command, which is windings off.
	Tapermaker_xmit "L45 0 H35"

	# "<00" Select all controllers.
	# 
	# "L06 2" Upon H01 command, program will be executed entirely. 
	#
	# "L70 10" Set resolution to 10 pulses per step, which gives 2000 pulses per
	# revolution, or 4000 pulses per millimeter.
	# 
	# "L07 0" turns off the strobe outputs.
	# 
	# "L09 8000" Set jog speed to 8000 p/s or 2 mm/s. 
	Tapermaker_xmit "L70 10 L06 2 L07 0 L09 $reset_speed"

	# "L11 40000" Set acceleration and deceleration to 40000 p/s/s, or 10
	# mm/s/s. 
	# 
	# "L12 4000" Set low speed to 4000 p/s or 1 mm/s.
	# 
	# "L13 10" In step mode, one step is ten pulses. 
	Tapermaker_xmit "L11 $acceleration L12 4000 L13 10"

	# "L14 5000" Set the home speed tpo 5000. 
	# 
	# "L16 0" Disable maximum index limit.
	#
	# "L18 -0" Disable CW softare travel limit.
	# 
	# "L19 +0" Disable CCW software travel limit. 
	Tapermaker_xmit "L14 5000 L16 0 L18 -0 L19 +0"

	# "L26 3" Transmit EOT at end of each transmission, and "=" when ready for
	# new commands.
	# 
	# "L41 1" Program reset line number.
	# 
	# "L44 10" Insert 10-ms delay between each line execution.
	# 
	# "L47 0" Program repeat counter zero.
	Tapermaker_xmit "L26 3 L41 1 L44 0 L45 10 L47 0"

	# "L66 +0" Disable backlash compensation. 
	# 
	# "L67 0" Disable autoreverse.
	Tapermaker_xmit "L66 +0 L67 0"

	# "L71 115000" Max speed.
	# 
	# "L72 0" trapezoidal ramp
	# 
	# "L98 10" Delay between H-codes is 10 ms.
	Tapermaker_xmit "L71 115000 L72 0 L98 10"

	LWDAQ_print $info(text) "Done.\n"

	LWDAQ_print $info(text) "Sending reset commmands."

	# Select No1 and set it to high-speed and jog-mode. In jog-mode
	# the motor does not "jog", it just keeps turning until you stop
	# it. We set the motor turning counter-clockwise (CCW). It will 
	# will keep turning until it hits its CCW limit switch. 
	Tapermaker_xmit "<01 H4 H3 H7"

	# Now move No1 off CCW limit switch to its home position. "H02" puts the 
	# controller into step mode, in which it moves a specific number of pulses.
	# "L13 122000" specifies a movement of 122k pulses, or 30.5 mm, and "H6" orders 
	# the movement in the CW direction.
	set num_pulses [expr round($config(right_home_position_mm) * $info(steps_per_mm))]
	Tapermaker_xmit "H2 L13 $num_pulses H6"

	# Select No2 and set it to turning clockwise (CW). The motor will
	# keep turning until it hits its CW limit switch.
	Tapermaker_xmit "<02 H4 H3 H6"

	# Move No2 off CW limit switch by 190k steps, or 47.5 mm.
	set num_pulses [expr round($config(left_home_position_mm) * $info(steps_per_mm))]
	Tapermaker_xmit "H2 L13 $num_pulses H7"

	LWDAQ_print $info(text) "Establishing home position.\n"
	return ""
}

#
# Tapermaker_taper writes the stretching program to the program memories
# of the two motor controllers. The distances and speeds used in the program
# are derived from the parameters displayed in the Tapermaker window. Once
# the program is loaded, the routine initiates the tapering process.
# 
proc Tapermaker_taper {} {
	upvar #0 Tapermaker_info info
	upvar #0 Tapermaker_config config
	
	LWDAQ_print $info(text) "Loading tapering program."
	
	# Turn on the motor windings with "H35". The windings will be powered at all times
	# until we use the OFF command.
	Tapermaker_xmit "<00 H35"

	# We have two variables to store the total upward movement of the two
	# stages during the tapering process. This allows us to return to the
	# home position from which we started using the home routine.
	set config(right_distance) 0
	set config(left_distance) 0
	
	# Select both controllers and clear all program lines. "L48 0" specifies
	# that the "H12" clear instruction should clear all ones. 
	Tapermaker_xmit "<00 L48 0 H12"

	# Program both motors to move together to bring the target region of the fiber
	# into the heating coil. We make the top motor move slightly faster than the 
	# bottom motor to make sure we maintain tension on the fiber.
	set right_approach_distance [expr round($config(approach_distance_mm) * $info(steps_per_mm))]
	set right_approach_speed [expr round($config(approach_speed_mmps) * $info(steps_per_mm))]
	Tapermaker_xmit "<01 N1 X+$right_approach_distance F$right_approach_speed"
	set config(right_distance) $right_approach_distance

	# The top stage is the one that moves slightly faster and farther.
	set left_approach_distance [expr round($right_approach_distance \
		* $config(approach_differential_mmpmm))]
	set left_approach_speed [expr round($right_approach_speed \
		* $config(approach_differential_mmpmm))]
	Tapermaker_xmit "<02 N1 X+$left_approach_distance F$left_approach_speed"
	set config(left_distance) $left_approach_distance

	# The rest of the program is different for the two motors. The top motor
	# moves the top portion of the fiber up and away, while the bottom motor
	# first pauses and then moves the bottom portion of the fiber down and away. 
	# Tapers are created at the break made by the heating coil as the two fiber 
	# ends pull apart. The taper we want to keep is the one on the bottom portion.

	# The bottom motor pauses before it moves down.
	set delay [expr round($config(right_stretch_delay_s)*1000)]
	Tapermaker_xmit "<01 N2 G04 X$delay"
	
	# The bottom motor moves down by the bottom stretch distance at the bottom
	# stretch speed.
	set stretch_distance [expr round($config(right_stretch_distance_mm) * $info(steps_per_mm))]
	set stretch_speed [expr round($config(right_stretch_speed_mmps) * $info(steps_per_mm))]
	Tapermaker_xmit "<01 N3 X-$stretch_distance F$stretch_speed"
	set config(right_distance) [expr $config(right_distance) - $stretch_distance]
	
	# The top motor pauses before it moves up.
	set delay [expr round($config(left_stretch_delay_s)*1000)]
	Tapermaker_xmit "<02 N2 G04 X$delay"
		
	# The top motor moves up by the top stretch distance at the top stretch speed.
	set stretch_distance [expr round($config(left_stretch_distance_mm) * $info(steps_per_mm))]
	set stretch_speed [expr round($config(left_stretch_speed_mmps) * $info(steps_per_mm))]
	Tapermaker_xmit "<02 N3 X+$stretch_distance F$stretch_speed"
	set config(left_distance) [expr $config(left_distance) + $stretch_distance]

	LWDAQ_print $info(text) "Program loaded.\n"
	LWDAQ_wait_ms 100
	LWDAQ_print $info(text) "Initiating tapering process."
	Tapermaker_xmit "<02 N1 H01"
	Tapermaker_xmit "<01 N1 H01"
	LWDAQ_print $info(text) "Tapering in progress.\n"
	return ""
}

#
# Tapermaker_homr takes the stages back to the home positions after a taper
# process.
#
proc Tapermaker_home {} {
	upvar #0 Tapermaker_info info
	upvar #0 Tapermaker_config config
	
	LWDAQ_print $info(text) "Sending home commands."
	
	# Put the bottom motor into step mode and move it back to the home position. We
	# have to check that the distance moved is greater than zero, or else the command
	# will be misinterpreted by the motor controller.
	if {$config(right_distance) > 0} {
		Tapermaker_xmit "<01 H2 L13 $config(right_distance) H7"
	} {
		LWDAQ_print $info(text) "Bottom stage (No1) already in home position." brown
	}
	
	# Put the top motor into step mode and move it back to the home position.
	if {$config(left_distance) > 0} {
		Tapermaker_xmit "<02 H2 L13 $config(left_distance) H7"
	} {
		LWDAQ_print $info(text) "Top stage (No2) already in home position." brown	
	}
	
	LWDAQ_print $info(text) "Moving to home position.\n"
	return ""
}

#
# Tapermaker_open opens the tool window and configurat the graphical user interface.
#
proc Tapermaker_open {} {
	upvar #0 Tapermaker_config config
	upvar #0 Tapermaker_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}	

	set f [frame $w.top]
	pack $f -side top -fill x

	button $f.reset -text "Reset" -fg brown \
		-command [list LWDAQ_post Tapermaker_reset]
	button $f.taper -text "Taper" -fg green \
		-command [list LWDAQ_post Tapermaker_taper]
	button $f.home -text "Home" -fg orange \
		-command [list LWDAQ_post Tapermaker_home]
	button $f.stop -text "Stop" -fg red \
		-command [list LWDAQ_post Tapermaker_stop front]
	button $f.off -text "Off" -fg black \
		-command [list LWDAQ_post Tapermaker_off]
    button $f.configure -text "Configure" \
    	-command "LWDAQ_tool_configure $info(name)"
    button $f.help -text "Help" \
    	-command "LWDAQ_tool_help $info(name)"
    	
    pack $f.reset $f.home $f.taper $f.stop $f.off \
    	$f.configure $f.help -side left -expand 1
	
	set ff [frame $w.middle]
	pack $ff -side top -fill x
	
	set f [frame $ff.left]
	pack $f -side left -fill y

	foreach a {right_home_position_mm \
		left_home_position_mm \
		approach_distance_mm \
		approach_speed_mmps \
		approach_differential_mmpmm \
		right_stretch_delay_s \
		right_stretch_distance_mm \
		right_stretch_speed_mmps} {
		
		set word_list [split $a _] 
		set name ""
		foreach word [lrange $word_list 0 end-1] {
			append name [string toupper $word 0 0]
			append name " "
		}
		set abbr [lindex $word_list end]
		switch $abbr {
			"mmps" {set unit "mm/s"}
			"mmpmm" {set unit "mm/mm"}
			default {set unit $abbr}
		}
		label $f.l$a -text $name -justify left
		entry $f.e$a -textvariable Tapermaker_config($a) -width 10 -justify right
		label $f.u$a -text $unit -justify left
		grid $f.l$a $f.e$a $f.u$a -sticky w
	}
	
	set f [frame $ff.right]
	pack $f -side right -fill y

	foreach a {left_stretch_delay_s \
		left_stretch_distance_mm \
		left_stretch_speed_mmps \
		reset_speed_mmps \
		acceleration_mmpss} {
		
		set word_list [split $a _] 
		set name ""
		foreach word [lrange $word_list 0 end-1] {
			append name [string toupper $word 0 0]
			append name " "
		}
		set abbr [lindex $word_list end]
		switch $abbr {
			"mmps" {set unit "mm/s"}
			"mmpmm" {set unit "mm/mm"}
			"mmpss" {set unit "mm/s/s"}
			default {set unit $abbr}
		}
		label $f.l$a -text $name -justify left
		entry $f.e$a -textvariable Tapermaker_config($a) -width 10 -justify right
		label $f.u$a -text $unit -justify left
		grid $f.l$a $f.e$a $f.u$a -sticky w
	}
	
	foreach a {daq_ip_addr daq_driver_socket} {
		label $f.l$a -text $a -justify left
		entry $f.e$a -textvariable Tapermaker_config($a) -width 15 -justify right
		grid $f.l$a $f.e$a - -sticky w
	}	
	
	# Create a general-purpose G-code command interface.
	set f [frame $w.xmit]
	pack $f -side top -fill x
	button $f.xmit -text "Transmit" -command {
		Tapermaker_xmit $Tapermaker_config(xmit_cmd) $Tapermaker_config(xmit_rx)
	}
	entry $f.cmd -textvariable Tapermaker_config(xmit_cmd) -width 70 -justify right
	checkbutton $f.rx -text "Rx" -variable Tapermaker_config(xmit_rx) 
	pack $f.xmit $f.cmd $f.rx -side left
	
	# Creates text widget and prints tool name
	set info(text) [LWDAQ_text_widget $w 85 10]
	
	# Print help.
	LWDAQ_print $info(text) "$info(name) Version $info(version)\n" purple

	return $w
}

Tapermaker_init
Tapermaker_open

return ""

----------Begin Help----------

http://www.opensourceinstruments.com/Electronics/A3036/M3036.html#Fiber%20Tapering

----------End Help----------

----------Begin Data----------


----------End Data----------
