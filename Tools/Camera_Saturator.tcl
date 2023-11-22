# Camera_Saturator, a Standard and Polite LWDAQ Tool
# Copyright (C) 2004-2021, Kevan Hashemi, Brandeis University
# Copyright (C) 2021-2023, Kevan Hashemi, Open Source Instruments Inc.
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

#
# Version 8: Brought up to date with LWDAQ 7.2. 
#
# Version 9: Expand plot.
#
# Version 10: Change name from Saturator to Saturator. The tool now acquires 
# images from a named instrument, increasing daq_flash_seconds from a minimum to
# a maximum in a proscribed number of steps. It prints to its text window the minimum,
# average, and maximum intensity in the image. It no longer plots the result, but leaves
# it to the user to cut and paste into a plot.

#
# Camera_Saturator_init initializes the tool's configuration and informational arrays.
#
proc Camera_Saturator_init {} {
	upvar #0 Camera_Saturator_info info
	upvar #0 Camera_Saturator_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init "Camera_Saturator" "1"
	if {[winfo exists $info(window)]} {return ""}

	set config(flash_min) "0"
	set config(flash_max) "1.0"
	set config(flash_steps) "20"
	set config(instrument) "SCAM"
	set config(intensify) "exact"
	set config(zoom) "1.0"
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	set info(control) "Idle"

	return ""	
}

#
# Camera_Saturator_saturate captures images using the named instrument, starting with the
# minimum exposure time and increasing to the maximum exposure time in steps.
#
proc Camera_Saturator_saturate {} {
	upvar #0 Camera_Saturator_info info
	upvar #0 Camera_Saturator_config config
	upvar #0 LWDAQ_config_$config(instrument) iconfig
	upvar #0 LWDAQ_info_$config(instrument) iinfo

	# Check the state of the saturator.
	if {$info(control) != "Idle"} {
		return ""
	}
	set info(control) "Saturate"
	set w $info(window)
	
	if {[info exists iconfig(daq_adjust_flash)] \
			&& $iconfig(daq_adjust_flash)} {
		LWDAQ_print $info(text) "WARNING: Turning off $config(instrument)\
			instrument's automatic flash adjustmenet."
		set iconfig(daq_adjust_flash) 0
	}
	if {[info exists iconfig(daq_subtract_background)] \
			&& $iconfig(daq_subtract_background)} {
		LWDAQ_print $info(text) "WARNING: Turning off $config(instrument)\
			instrument's automatic background subtraction."
		set iconfig(daq_subtract_background) 0
	}
	
	# Prepare to perform the saturation.
	set saved_flash $iconfig(daq_flash_seconds)
	LWDAQ_print $info(text) "Saturating $config(instrument) camera from\
		$config(flash_min) s to $config(flash_max) s\
		in $config(flash_steps) steps." brown

	# Increase exposure time in steps. Draw image in tool window. Print
	# results to text window.
	set iconfig(daq_flash_seconds) $config(flash_min)
	set step [expr 1.0*($config(flash_max) - $config(flash_min))/$config(flash_steps)]
	while {$iconfig(daq_flash_seconds) <= $config(flash_max)} {
		set daq_result [LWDAQ_acquire $config(instrument)]
		if {![LWDAQ_is_error_result $daq_result]} {
			lwdaq_image_manipulate $iconfig(memory_name) none -clear 1
			lwdaq_draw $iconfig(memory_name) $info(photo) \
				-intensify $config(intensify) \
				-zoom $config(zoom)
			set characteristics [lwdaq_image_characteristics $iconfig(memory_name)]
			set max [lindex $characteristics 6]
			LWDAQ_print $info(text) "[format %.6f $iconfig(daq_flash_seconds)]\
				[format %.0f [lindex $characteristics 7]]\
				[lindex $characteristics 4]\
				[format %.0f [lindex $characteristics 6]]"
		} else {
			LWDAQ_print $info(text) $daq_result
			set info(control) "Abort"
		}		
		LWDAQ_update	
		if {$info(control) == "Abort"} {
			LWDAQ_print $info(text) "Saturation aborted by user."
			break
		}
		set iconfig(daq_flash_seconds) [format %.6f \
			[expr $iconfig(daq_flash_seconds) + $step]]
	}
	
	# Clean up now we are done.
	set iconfig(daq_flash_seconds) $saved_flash
	set info(control) "Idle"
	return ""
}

#
# Camera_Saturator_abort sets the control to Abort if not Idle.
#
proc Camera_Saturator_abort {} {
	upvar #0 Camera_Saturator_info info
	if {$info(control) != "Idle"} {
		set info(control) "Abort"
	}
	return ""
}

#
# Camera_Saturator_clear clears the image.
#
proc Camera_Saturator_clear {} {
	upvar #0 Camera_Saturator_info info
	if {$info(control) != "Idle"} {return ""}
	lwdaq_draw $info(graph_image_name) $info(graph)
	return ""
}

#
# Camera_Saturator_open creates the tool window.
#
proc Camera_Saturator_open {} {
	upvar #0 Camera_Saturator_config config
	upvar #0 Camera_Saturator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
		
	set f $w.controls
	frame $f
	pack $f -side top -fill x
	
	label $f.state -textvariable Camera_Saturator_info(control) -width 10 -fg blue
	pack $f.state -side left -expand 1

	foreach a {Saturate Abort Clear} {
		set b [string tolower $a]
		button $f.$b -text $a -command Camera_Saturator_$b
		pack $f.$b -side left -expand 1
	}

	foreach a {Configure Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}

	set f $w.image
	frame $f 
	pack $f -side top -fill x
	
	set info(photo) [image create photo]
	label $f.image -image $info(photo) 
	pack $f.image -side top

	set f $w.config
	frame $f
	pack $f -side top -fill x
	
	tk_optionMenu $f.instrument Camera_Saturator_config(instrument) \
		BCAM Rasnik SCAM WPS
	pack $f.instrument -side left -expand 1
	
	foreach a {flash_min flash_max flash_steps intensify zoom} {
		label $f.l$a -text $a -fg green
		entry $f.e$a -textvariable Camera_Saturator_config($a) -width 8
		pack $f.l$a $f.e$a -side left -expand 1
	}

	set info(text) [LWDAQ_text_widget $w 80 15]

	return $w
}

Camera_Saturator_init
Camera_Saturator_open

return ""

----------Begin Help----------

Camera Saturator, A LWDAQ Tool
------------------------------

The Camera Saturator will show you the saturation intensity of a camera, the linearity
of the laser-camera combination with flash time, and the intensity of the laser
image at zero exposure time, which can be significant when the camera is less
than a couple of meters from the laser. The tool takes a series of images from a
camera, such as those in BCAM, Camera, Rasnik, SCAM, or WPS instruments, so as
to show how the minimum, average, and maximum intensity in the image varies with
the time for which we flash the instrument's light sources.

Before you press Saturate, set up your selected instrument so that it captures
images of your light sources. Write the name of this instrument in the
instrument entry box of the Camera Saturator window. Specify a minimum and maximum
flash time for the saturation experiment. Specify a number of steps. The maximum
flash time should be sufficient to saturate the image, so you will see the
saturation developing in the last few exposure times of the saturation
experiment.

When you press Saturate, the Camera Saturator starts obtaining image, analyzing them,
and writing their intensity characteristics to its text window. Here is an example
output.

Saturating SCAM camera from 0 s to 1.0 s in 20 steps.
0.000000 48 49.3 55
0.050000 48 54.6 86
0.100000 49 59.7 123
0.150000 50 64.9 158
0.200000 50 70.3 189
0.250000 51 75.4 199
0.300000 51 80.6 200
0.350000 52 85.7 201
0.400000 53 90.6 203
0.450000 53 95.5 204
0.500000 53 101.4 205
0.550000 54 105.4 205
0.600000 55 111.0 206
0.650000 55 116.3 207
0.700000 56 120.6 207
0.750000 56 126.2 206
0.800000 56 130.7 208
0.850000 58 135.4 208
0.900000 58 140.3 209
0.950000 58 144.1 214
1.000000 59 148.0 219

For each image it captures, the Camera Saturator gives us the value
daq_flash_seconds it used to obtain the image, in seconds. We give the flash
times to six decimal places so we can see microseconds. The next three numbers
are the minimum, average, and maximum intensities. The minimum and maximum are
integers, but the average is a real value we give to one decimal place.

The Camera Saturator also shows you the images it obtains, so you can, in
theory, watch them get brighter. Press Abort to stop the experiment. The images
will not include the results of instrument analysis. The Camera Saturator shows
you the image with nothing in the overlay. By default the Camera Saturator uses
exact intensification, but you can change intensification to any of "none",
"strong", "weak", or "exact". The size of the image display is controlled by
"zoom".

Kevan Hashemi hashemi@opensourceinstruments.com

----------End Help----------
