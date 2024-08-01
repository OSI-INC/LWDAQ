# DFPS Calibrator, a LWDAQ Tool
#
# Copyright (C) 2024 Kevan Hashemi, Open Source Instruments Inc.
#
# The DFPS Calibrator calibrates the Fiber View Cameras (FVCs) of a Direct Fiber
# Positioning System (DFPS). This version of the code assumes two FVCs, left and
# right as seen looking in the positive z-direction into the telescope. We 
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.

#
# DFPS_Calibrator_init initializes the tool's configuration and information arrays.
#
proc DFPS_Calibrator_init {} {
	upvar #0 DFPS_Calibrator_info info
	upvar #0 DFPS_Calibrator_config config
	
	LWDAQ_tool_init "DFPS_Calibrator" "1.1"
	if {[winfo exists $info(window)]} {return ""}

	set config(cam_left) "12.675 39.312 -2.0 0.0 0.0 2 19.0 0.0" 
	set config(cam_right) "12.675 39.312 -2.0 0.0 0.0 2 19.0 0.0" 
	set config(scaling) "1 1 1 1 1 0 1 1"

	set config(mount_left) "0 0 0 -21 0 -73 21 0 -73"
	set config(mount_right) "0 0 0 -2 1 0 -73 21 0 -73"

	set config(source_1) "0 105 -50"
	set config(source_2) "30 105 -50"
	set config(source_3) "0 75 -50"
	set config(source_4) "30 75 -50"
	set config(fit_sources) "1 3 4"
	set config(num_sources) "4"
	set config(spots_left) "100 100 200 100 100 200 200 200"
	set config(spots_right) "100 100 200 100 100 200 200 200"

	set config(fit_steps) "1000"
	set config(fit_restarts) "0"
	set config(fit_startsize) "1"
	set config(fit_endsize) "0.005"
	set config(fit_show) "1"
	set config(stop_fit) "0"
	set config(zoom) "0.5"
	set config(intensify) "exact"
	set config(num_lines) "2000"
	set config(bcam_threshold) "10 #"
	set config(bcam_sort) "8"
	set config(img_dir) "~/Desktop/DFPS"
	
	set config(cross_size) "100"
	
	set info(state) "Idle"
	
	set info(examine_window) "$info(window).examine_window"
	set info(state) "Idle"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	foreach side {left right} {
		lwdaq_image_create -name img_$side -width 700 -height 520
	}

	return ""   
}


#
# DFPS_Calibrator_show draws the left and right image overlays onto the display.
#
proc DFPS_Calibrator_show {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info
	
	foreach side {left right} {
		lwdaq_draw img_$side photo_$side \
			-intensify $config(intensify) -zoom $config(zoom)
	}

	return ""
}

#
# DFPS_Calibrator_clear clears the overlay of the left and right image displays.
#
proc DFPS_Calibrator_clear {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	foreach side {left right} {
		lwdaq_image_manipulate img_$side none -clear 1
	}
	DFPS_Calibrator_show
	return ""
}

#
# DFPS_Calibrator_get_params puts together a string containing the parameters
# the fitter can adjust to minimise the calibration disagreement. The fitter
# will adjust any parameter for which we assign a scaling value greater than 
# zero. The scaling string gives the scaling factors the fitter uses for each
# camera calibration constant. The scaling factors are used twice: once for 
# the left camera and once for the right. See the fitting routine for their
# implementation.
#
proc DFPS_Calibrator_get_params {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	set params "$config(cam_left) $config(cam_right)"
	return $params
}

#
# DFPS_Calibrator_examine opens a new window that displays the CMM measurements
# of the left and right mounts, calibration constants of the left and right
# cameras, and coordinates of the calibration sources. The window allows us to
# modify the all these values by hand.
#
proc DFPS_Calibrator_examine {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	set w $info(examine_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Coordinate Measurements, DFPS Calibrator $info(version)"
	} {
		raise $w
		return ""
	}

	set f [frame $w.buttons]
	pack $f -side top -fill x
	button $f.save -text "Save Configuration" -command "LWDAQ_tool_save $info(name)"
	pack $f.save -side left -expand 1
	button $f.unsave -text "Unsave Configuration" -command "LWDAQ_tool_unsave $info(name)"
	pack $f.unsave -side left -expand 1
	
	foreach mount {Left Right} {
		set b [string tolower $mount]
		set f [frame $w.mnt$b]
		pack $f -side top -fill x
		label $f.l$b -text "$mount Mount:"
		entry $f.e$b -textvariable DFPS_Calibrator_config(mount_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}

	for {set a 1} {$a <= $config(num_sources)} {incr a} {
		set f [frame $w.src$a]
		pack $f -side top -fill x
		label $f.l$a -text "Source $a\:"
		entry $f.e$a -textvariable DFPS_Calibrator_config(source_$a) -width 70
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach mount {Left Right} {
		set b [string tolower $mount]
		set f [frame $w.spt$b]
		pack $f -side top -fill x
		label $f.l$b -text "$mount Spots:"
		entry $f.e$b -textvariable DFPS_Calibrator_config(spots_$b) -width 70
		pack $f.l$b $f.e$b -side left -expand yes
	}
	
	return ""
}

#
# DFPS_Calibrator_disagreement calculates root mean square square distance
# between the actual image positions and the modelled image positions we obtain
# when applying our mount measurements, FVC calibration constants, and the
# measured source positions.
#
proc DFPS_Calibrator_disagreement {{params ""}} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	# If user has closed the calibrator window, generate an error so that we stop any
	# fitting that might be calling this routine. 
	if {![winfo exists $info(window)]} {
		error "No DFPS window open."
	}
	
	# If no parameters specified, use those stored in configuration array.
	if {$params == ""} {
		set params [DFPS_Calibrator_get_params]
	}
	
	# Make sure messages from the BCAM routines get to the DFPS Calibrator's text
	# window. Set the number of decimal places to three.
	lwdaq_config -text_name $info(text)

	# Extract the two sets of camera calibration constants from the parameters passed
	# to us by the fitter.
	set fvc_left "FVC_L [lrange $params 0 7]"
	set fvc_right "FVC_R [lrange $params 8 15]"
	
	# Clear the overlay if showing.
	if {$config(fit_show)} {DFPS_Calibrator_clear}	
	
	# Go through the four sources. For each source, we calculate the modelled
	# image position in each camera. We look up the actual image position in
	# each camera, as we obtained when we read the two images. We square the
	# distance between the actual and modelled positions and add to our
	# disagreement.
	set sum_squares 0
	set count 0
	foreach side {left right} {
		set spots $config(spots_$side)
		for {set a 1} {$a <= $config(num_sources)} {incr a} {
			if {[lsearch $config(fit_sources) $a] >= 0} {
				set sb [lwdaq bcam_from_global_point \
					$config(source_$a) $config(mount_$side)]
				set th [lwdaq bcam_image_position $sb [set fvc_$side]]
				scan $th %f%f x_th y_th
				set x_th [format %.2f [expr $x_th * 1000.0]]
				set y_th [format %.2f [expr $y_th * 1000.0]]
				set x_a [lindex $spots 0]
				set y_a [lindex $spots 1]
				set spots [lrange $spots 2 end]
				set err [expr ($x_a-$x_th)*($x_a-$x_th) + ($y_a-$y_th)*($y_a-$y_th)]
				set sum_squares [expr $sum_squares + $err]
				incr count
				
				set y [expr 3848 - $y_th]
				set x $x_th
				set w $config(cross_size)
				lwdaq_graph "[expr $x - $w] $y [expr $x + $w] $y" img_$side \
					-entire 1 -x_min 0 -x_max 5180 -y_min 0 -y_max 3848 -color 2
				lwdaq_graph "$x [expr $y - $w] $x [expr $y + $w]" img_$side \
					-entire 1 -x_min 0 -x_max 5180 -y_min 0 -y_max 3848 -color 2
			}
		}
	}
	
	# Draw the boxes and rectangles if showing.
	if {$config(fit_show)} {DFPS_Calibrator_show}
	
	# Return the total disagreement, which is our error value.
	return [format %.3f [expr sqrt($sum_squares/$count)]]
}

#
# DFPS_Calibrator_read looks for a file called CMM.txt. We either pass it the
# directory name or the routine will open a browser for us to choose the
# directory. From the CMM.txt file the calibrator reads the global coordinates
# of the balls in the left and right FVC mounts, and the locations of the four
# calibration sources. Having read CMM.txt, the routine looks for L.gif and
# R.gif, the images returned by the left and right FVCs viewing the four
# calibration sources. In these two images, the sources must be arranged from 1
# to 4 in an x-y grid, as recognised by the BCAM Instrument.
#
proc DFPS_Calibrator_read {{img_dir ""}} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info
	upvar #0 LWDAQ_config_BCAM iconfig

	if {$info(state) != "Idle"} {return ""}
	set info(state) "Reading"
	LWDAQ_update
	
	if {$img_dir == ""} {set img_dir [LWDAQ_get_dir_name]}
	if {$img_dir == ""} {
		set info(state) "Idle"
		return ""
	} {
		set config(img_dir) $img_dir
	}
	
	LWDAQ_print $info(text) "Reading mount and source positions from CMM.txt."
	set fn [file join $img_dir CMM.txt]
	if {[file exists $fn]} {
		set f [open $fn r]
		set cmm [read $f]
		close $f
		set numbers [list]
		foreach a $cmm {if {[string is double -strict $a]} {lappend numbers $a}}
		set spheres [list]
		for {set sn 0} {$sn < 9} {incr sn} {
			lappend spheres [lrange $numbers 1 3]
			set numbers [lrange $numbers 4 end]
		}
		set config(mount_left) [join [lrange $spheres 3 5]]
		set config(mount_right) [join [lrange $spheres 6 8]]
		for {set a 1} {$a <= $config(num_sources)} {incr a} {
			set config(source_$a) [lrange $numbers 0 2]
			set numbers [lrange $numbers 3 end]
		}
	} else {
		LWDAQ_print $info(text) "Cannot find \"$fn\"."
		set info(state) "Idle"
		return ""
	}

	LWDAQ_print $info(text) "Reading and analyzing left and right FVC images."
	foreach {s side} {L left R right} {
		set ifn [file join $config(img_dir) $s\.gif]
		if {[file exists $ifn]} {
			LWDAQ_read_image_file $ifn img_$side
			set iconfig(analysis_num_spots) "$config(num_sources) $config(bcam_sort)"
			set iconfig(analysis_threshold) $config(bcam_threshold)
			LWDAQ_set_image_sensor ICX424 BCAM
			set result [LWDAQ_analysis_BCAM img_$side]
			if {![LWDAQ_is_error_result $result]} {
				set config(spots_$side) ""
				foreach {x y num pk acc th} $result {
					append config(spots_$side) "$x $y "
				}
			} else {
				LWDAQ_print $info(text) $result
				set info(state) "Idle"
				return ""
			}
		}
	}

	DFPS_Calibrator_disagreement			
	
	set info(state) "Idle"
	return ""
}

#
# DFPS_Calibrator_displace displaces the camera calibration constants by a random
# amount in proportion to their scaling factors.
#
proc DFPS_Calibrator_displace {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	foreach side {left right} {
		for {set i 0} {$i < [llength $config(cam_$side)]} {incr i} {
			lset config(cam_$side) $i [format %.3f \
				[expr [lindex $config(cam_$side) $i] \
					+ (rand()-0.5)*[lindex $config(scaling) $i]]]
		}
	}
	DFPS_Calibrator_disagreement
	return $params
} 

#
# DFPS_Calibrator_altitude is the error function for the fitter. The fitter calls
# this routine with a set of parameter values to get the disgreement, which it
# is attemptint to minimise.
#
proc DFPS_Calibrator_altitude {params} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	if {$config(stop_fit)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	set count [DFPS_Calibrator_disagreement "$params"]
	LWDAQ_support
	return $count
}

#
# DFPS_Calibrator_fit gets the camera calibration constants as a starting point
# and calls the simplex fitter to minimise the disagreement between the modelled
# and actual bodies by adjusting the calibration constants of both parameter.
# The size of the adjustments the fitter makes in each parameter during the fit
# will be shrinking as the fit proceeds, but relative to one another thye will
# be in proportion to the list of scaling factors we have provided. These
# factors are applied twice: once to each camera. If the scaling factors are all
# unity, all parameters are fitted with equal steps. If a scaling factor is
# zero, the parameter will not be adjusted. If a scaling factor is 10, the
# parameter will be adjusted by ten times the amount as a parameter with scaling
# factor one. At the end of the fit, we take the final fitted parameter values
# and apply them to our body models.
#
proc DFPS_Calibrator_fit {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	set config(stop_fit) 0
	set info(state) "Fitting"
	
	if {[catch {
		set scaling "$config(scaling) $config(scaling)"
		set start_params [DFPS_Calibrator_get_params] 
		set end_params [lwdaq_simplex $start_params \
			DFPS_Calibrator_altitude \
			-report 0 \
			-steps $config(fit_steps) \
			-restarts $config(fit_restarts) \
			-start_size $config(fit_startsize) \
			-end_size $config(fit_endsize) \
			-scaling $scaling]
		if {[LWDAQ_is_error_result $end_params]} {error "$end_params"}
		LWDAQ_print $info(text) $end_params black
		set config(cam_left) "[lrange $end_params 0 7]"
		set config(cam_right) "[lrange $end_params 8 15]"
	} error_message]} {
		LWDAQ_print $info(text) $error_message
		set info(state) "Idle"
		return ""
	}

	DFPS_Calibrator_disagreement
	set info(state) "Idle"
}

#
# DFPS_Calibrator_open opens the DFPS Calibrator window.
#
proc DFPS_Calibrator_open {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable DFPS_Calibrator_info(state) -fg blue -width 10
	pack $f.state -side left -expand yes

	button $f.stop -text "Stop" -command {set DFPS_Calibrator_config(stop_fit) 1}
	pack $f.stop -side left -expand yes

	foreach a {Read Examine Fit Disagreement Clear Displace } {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post DFPS_Calibrator_$b"
		pack $f.$b -side left -expand yes
	}

	foreach a {Configure Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}
	
	set f [frame $w.fvc]
	pack $f -side top -fill x
	
	foreach {a wd} {fit_sources 10 zoom 4 bcam_threshold 6 fit_steps 8} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Calibrator_config($a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	checkbutton $f.show -text "Show" -variable DFPS_Calibrator_config(fit_show)
	pack $f.show -side left -expand yes

		
	foreach {a wd} {scaling 20} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Calibrator_config($a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.cameras]
	pack $f -side top -fill x

	foreach {a wd} {cam_left 50 cam_right 50} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable DFPS_Calibrator_config($a) -width $wd
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	set f [frame $w.images]
	pack $f -side top -fill x

	foreach a {left right} {
		image create photo "photo_$a"
		label $f.$a -image "photo_$a"
		pack $f.$a -side left -expand yes
	}
	
	set info(text) [LWDAQ_text_widget $w 100 15]
	LWDAQ_print $info(text) "$info(name) Version $info(version) \n"
	lwdaq_config -text_name $info(text) -fsd 3	
	
	return $w
}

DFPS_Calibrator_init
DFPS_Calibrator_open
DFPS_Calibrator_clear
	
return ""

----------Begin Help----------

The Direct Fiber Positioning System (DFPS) Calibrator calculates the
calibration constants of the two Fiber View Cameras (FVCs) mounted on a DFPS
base plate. The routine assumes we have Coordinate Measuring Machine (CMM)
measurements of the left FVC mount, the right FVC mount, and
four point sources visible to both cameras. The program takes as input two 
images L.gif and R.gif from the left and right FVCs respectively, and CMM.txt
from the CMM.

The CMM.txt file must contain the diameter and x, y, and z coordinates of the
cone, slot, and flat balls in the two FVC mounts. After that we must find x, y,
and z coordinates of each calibration source. The file containing these
measurements must be named CMM.txt. In addition to the measured diameters and
coordinates, CMM.txt may contain any number of words that are not real number
strings and any number of white space charcters. All words that are not real
numbers will be ignored. An example CMM.txt file is to be found below.

+---------------------+--------------+------+-----------+---------+
| Feature Table       |              |      |           |         |
+---------------------+--------------+------+-----------+---------+
| Length Units        | Millimeters  |      |           |         |
| Coordinate Systems  | Global       |      |           |         | 
| Data Alignments     | original     |      |           |         |
|                     |              |      |           |         |
| Name                | Control      | Nom  | Meas      | Tol     |
| Global1             | Diameter     |      | 12.25     | ±1.000  |
| Global1             | X            |      | 0.000     | ±1.000  |
| Global1             | Y            |      | 0.000     | ±1.000  |
| Global1             | Z            |      | 0.000     | ±1.000  |
| Global2             | Diameter     |      | 12.25     | ±1.000  |
| Global2             | X            |      | 100.399   | ±1.000  |
| Global2             | Y            |      | 0.000     | ±1.000  |
| Global2             | Z            |      | 0.000     | ±1.000  |
| Global3             | Diameter     |      | 12.25     | ±1.000  |
| Global3             | X            |      | 1.008     | ±1.000  |
| Global3             | Y            |      | -0.119    | ±1.000  |
| Global3             | Z            |      | 175.239   | ±1.000  |
| Left1               | Diameter     |      | 6.350     | ±1.000  |
| Left1               | X            |      | 79.596    | ±1.000  |
| Left1               | Y            |      | 51.571    | ±1.000  |
| Left1               | Z            |      | 199.741   | ±1.000  | 
| Left2               | Diameter     |      | 6.350     | ±1.000  |
| Left2               | X            |      | 119.754   | ±1.000  |
| Left2               | Y            |      | 51.457    | ±1.000  |
| Left2               | Z            |      | 264.248   | ±1.000  |
| Left3               | Diameter     |      | 6.350     | ±1.000  |
| Left3               | X            |      | 79.246    | ±1.000  | 
| Left3               | Y            |      | 51.484    | ±1.000  |
| Left3               | Z            |      | 275.697   | ±1.000  |
| Right1              | Diameter     |      | 6.350     | ±1.000  |
| Right1              | X            |      | -104.070  | ±1.000  |
| Right1              | Y            |      | 51.174    | ±1.000  |
| Right1              | Z            |      | 199.266   | ±1.000  |
| Right2              | Diameter     |      | 6.350     | ±1.000  |
| Right2              | X            |      | -108.719  | ±1.000  |
| Right2              | Y            |      | 51.002    | ±1.000  |
| Right2              | Z            |      | 275.087   | ±1.000  |
| Right3              | Diameter     |      | 6.350     | ±1.000  |
| Right3              | X            |      | -148.270  | ±1.000  |
| Right3              | Y            |      | 50.965    | ±1.000  |
| Right3              | Z            |      | 261.039   | ±1.000  |
| S1                  | X            |      | -28.580   | ±1.000  |
| S1                  | Y            |      | 103.532   | ±1.000  |
| S1                  | Z            |      | -91.733   | ±1.000  |
| S2                  | X            |      | 1.422     | ±1.000  |
| S2                  | Y            |      | 103.656   | ±1.000  |
| S2                  | Z            |      | -92.246   | ±1.000  |
| S3                  | X            |      | -28.496   | ±1.000  |
| S3                  | Y            |      | 73.575    | ±1.000  |
| S3                  | Z            |      | -92.210   | ±1.000  |
| S4                  | X            |      | 1.415     | ±1.000  |
| S4                  | Y            |      | 73.674    | ±1.000  |
| S4                  | Z            |      | -92.317   | ±1.000  |
+---------------------+--------------+------+-----------+---------+

The calibrator works by minimizing disagreement between actual spot positions
and modelled spot positions. When we press Fit, the simplex fitter starts
minimizing this disagreement by adjusting the calibrations of the left and right
FVCs. The fit applies the "scaling" values to the eight calibration constants of
the cameras. We can fix any one of the eight parameters by setting its scaling
value to zero. We always fix the pivot.z scaling factor to zero because this
parameter has no geometric implementation. The fit uses only those calibration
sources specified in the fit_sources string.

Stop: Abort fitting.

Show: Show the silhouettes and modelled bodies.

Clear: Clear the silhouettes and modelled bodies, show the raw images.

Displace: Displace the camera calibration constants from their current values.

Fit: Start the simplex fitter adjusting calibration constants to minimize
disagreement.

Configure: Open configuration panel with Save and Unsave buttons.

Help: Get this help page.

Read: Select a directory, read image files and CMM measurements. The images must
be L.gif and R.gif.

Examine: Open a window that displays the mount and source measurements produced
by the CMM. We can modify any measurement in this window and see how our
modification affects the fit by following with the Show button.

To use the calibrator, press Read and select your measurements. The calibrator
will display the images, the measured image positions, and the modelled image
positions. If the bodies are nowhere near the silhouettes, or they are not
visible, you most likely have a mix-up in the mount coordinates. Press Fit. The
modelled sources will start moving around. The status indicator on the top left
will say "Fitting". The status label will return to "Idle" when the fit is done.
The camera calibration constants are now ready.

(C) Kevan Hashemi, 2023-2024, Open Source Instruments Inc.
https://www.opensourceinstruments.com

----------End Help----------

----------Begin Data----------


----------End Data----------