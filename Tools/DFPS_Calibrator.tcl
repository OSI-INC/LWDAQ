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
	
	LWDAQ_tool_init "DFPS_Calibrator" "1.2"
	if {[winfo exists $info(window)]} {return ""}

	set config(cam_default) "12.675 39.312 1.0 0.0 0.0 2 19.0 0.0"
	set config(cam_left) $config(cam_default)
	set config(cam_right) $config(cam_default)
	set config(scaling) "0 0 0 1 1 0 1 1"

	set config(mount_left) "0 0 0 -21 0 -73 21 0 -73"
	set config(mount_right) "0 0 0 -2 1 0 -73 21 0 -73"
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	set config(source_1) "0 105 -50"
	set config(source_2) "30 105 -50"
	set config(source_3) "0 75 -50"
	set config(source_4) "30 75 -50"
	set config(fit_sources) "1 2 3 4"
	set config(num_sources) "4"
	set config(spots_left) "100 100 200 100 100 200 200 200"
	set config(spots_right) "100 100 200 100 100 200 200 200"
	
	set config(bcam_sensor) "ICX424"
	set config(bcam_width) "5180"
	set config(bcam_height) "3848"
	set config(bcam_threshold) "10 #"
	set config(bcam_sort) "8"

	set config(fit_steps) "1000"
	set config(fit_restarts) "2"
	set config(fit_startsize) "1"
	set config(fit_endsize) "0.005"
	set config(fit_show) "1"
	set config(fit_details) "0"
	set config(fit_report) "0"
	set config(displace_scale) "1"
	set config(stop_fit) "0"
	set config(zoom) "1.0"
	set config(intensify) "exact"
	set config(num_lines) "2000"
	set config(img_dir) "~/Desktop/DFPS"
	set config(cross_size) "100"
	
	set info(state) "Idle"
	
	set info(examine_window) "$info(window).examine_window"
	set info(state) "Idle"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	foreach side {left right} {
		set info(image_$side) dfps_calibrator_$side
		lwdaq_image_create -name $info(image_$side) -width 700 -height 520
	}

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
# of the left and right mounting balls and the calibration sources. It displays
# the spot positions for these calibration sources in the left and right FVCs.
# The window allows us to modify the all these values by hand.
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
# measured source positions. If show_fit is set, the routine clears the image
# overlays and draws blue crosses to mark the modelled positions of the 
# sources.
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
	if {$config(fit_show)} {
		foreach side {left right} {
			lwdaq_image_manipulate $info(image_$side) none -clear 1
		}
	}	
	
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
				set sb [lwdaq xyz_local_from_global_point \
					$config(source_$a) $config(coord_$side)]
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
				
				if {$config(fit_show)} {
					set y [expr $config(bcam_height) - $y_th]
					set x $x_th
					set w $config(cross_size)
					lwdaq_graph "[expr $x - $w] $y [expr $x + $w] $y" \
						$info(image_$side) -entire 1 \
						-x_min 0 -x_max $config(bcam_width) \
						-y_min 0 -y_max $config(bcam_height) -color 2
					lwdaq_graph "$x [expr $y - $w] $x [expr $y + $w]" \
						$info(image_$side) -entire 1 \
						-x_min 0 -x_max $config(bcam_width) \
						-y_min 0 -y_max $config(bcam_height) -color 2
				}
			}
		}
	}
	
	# Calculate root mean square error.
	set err [format %.3f [expr sqrt($sum_squares/$count)]]	
	
	# Draw the boxes and rectangles if showing.
	if {$config(fit_show)} {
		foreach side {left right} {
			lwdaq_draw $info(image_$side) dfps_calibrator_$side \
				-intensify $config(intensify) -zoom $config(zoom)
		}
	}
	
	# Return the total disagreement, which is our error value.
	return $err
}

#
# DFPS_Calibrator_show calls the disagreement function to show the location of 
# the modelled sources, and prints the calibration constants and disagreement
# to the text window, followed by a zero to indicated that zero fitting steps
# took place to produce these parameters and results.
#
proc DFPS_Calibrator_show {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info
	
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]
	set err [DFPS_Calibrator_disagreement]
	LWDAQ_print $info(text) "[DFPS_Calibrator_get_params] $err 0"

	return ""
}

#
# DFPS_Calibrator_check projects the image of each source in the left and right
# cameras to make a bearing line in the left and right mount coordinates using
# the current camera calibration constants, transforms to global coordinates
# using the mounting ball coordinates, and finds the mid-point of the shortest
# line between these two lines. This mid-point is the FVC measurement of the
# source position. It compares this position to the measured source position and
# reports the difference between the two.
#
proc DFPS_Calibrator_check {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info
	
	LWDAQ_print $info(text) "\nGlobal Measured Position and Error\
		(xm, ym, zm, xe, ye, ze in mm):" purple
	set sources ""
	set sum_squares 0.0
	for {set i 1} {$i <= 4} {incr i} {	
		lwdaq_config -fsd 6
		foreach side {left right} {
			set x [expr 0.001 * [lindex $config(spots_$side) [expr ($i-1)*2]]]
			set y [expr 0.001 * [lindex $config(spots_$side) [expr ($i-1)*2+1]]]
			set b [lwdaq bcam_source_bearing "$x $y" "$side $config(cam_$side)"]
			set point_$side [lwdaq xyz_global_from_local_point \
				[lrange [set b] 0 2] $config(coord_$side)]
			set dir_$side [lwdaq xyz_global_from_local_vector \
				[lrange [set b] 3 5] $config(coord_$side)]
		}
		lwdaq_config -fsd 3
		
		set bridge [lwdaq xyz_line_line_bridge \
			"$point_left $dir_left" "$point_right $dir_right"]
		scan $bridge %f%f%f%f%f%f x y z dx dy dz
		
		set x_src [format %8.3f [expr $x + 0.5*$dx]]
		set y_src [format %8.3f [expr $y + 0.5*$dy]]
		set z_src [format %8.3f [expr $z + 0.5*$dz]]
		
		set a $config(source_$i)
		set x_err [format %6.3f [expr [lindex $a 0]-$x_src]]
		set y_err [format %6.3f [expr [lindex $a 1]-$y_src]]
		set z_err [format %6.3f [expr [lindex $a 2]-$z_src]]
		
		LWDAQ_print $info(text) "Source_$i\: $x_src $y_src $z_src\
			$x_err $y_err $z_err"
		
		set sum_squares [expr $sum_squares + $x_err*$x_err \
			+ $y_err*$y_err + $z_err*$z_err] 
	}

	set err [expr sqrt($sum_squares / $config(num_sources))]
	LWDAQ_print $info(text) "Root Mean Square Error (mm): [format %.3f $err]"

	return ""
}

#
# DFPS_Calibrator_read either reads a specified CMM measurement file or browses
# for one. The calibrator reads the global coordinates of the balls in the left
# and right FVC mounts, and the locations of the four calibration sources.
# Having read the CMM file the routine looks for L.gif and R.gif in the same
# directory. These should be the images returned by the left and right FVCs of
# the four calibration sources. In these two images, the sources must be
# arranged from 1 to 4 in an x-y grid, as recognised by the BCAM Instrument.
#
proc DFPS_Calibrator_read {{fn ""}} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo

	if {$info(state) != "Idle"} {return ""}
	set info(state) "Reading"
	LWDAQ_update
	
	if {$fn == ""} {set fn [LWDAQ_get_file_name]}
	if {$fn == ""} {
		set info(state) "Idle"
		return ""
	} {
		set config(img_dir) [file dirname $fn]
	}
	
	LWDAQ_print $info(text) "\nReading measurements from disk." purple
	
	LWDAQ_print $info(text) "Reading CMM measurements from [file tail $fn]."
	set f [open $fn r]
	set cmm [read $f]
	close $f
	set numbers [list]
	foreach a $cmm {if {[string is double -strict $a]} {lappend numbers $a}}
	set spheres [list]
	foreach {d x y z} $numbers {
		lappend spheres "$x $y $z"
	}
	set config(mount_left) [join [lrange $spheres 3 5]]
	set config(mount_right) [join [lrange $spheres 6 8]]
	set spheres [lrange $spheres 9 end]
	for {set a 1} {$a <= $config(num_sources)} {incr a} {
		set config(source_$a) [lindex $spheres [expr $a-1]]
	}

	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	foreach {s side} {L left R right} {
		LWDAQ_print $info(text) "Reading and analyzing image $a\.gif from $side camera."
		set ifn [file join $config(img_dir) $s\.gif]
		if {[file exists $ifn]} {
			LWDAQ_read_image_file $ifn $info(image_$side)
			set iconfig(analysis_num_spots) "$config(num_sources) $config(bcam_sort)"
			set iconfig(analysis_threshold) $config(bcam_threshold)
			LWDAQ_set_image_sensor $config(bcam_sensor) BCAM
			set config(bcam_width) [expr $iinfo(daq_image_width) \
				* $iinfo(analysis_pixel_size_um)]
			set config(bcam_height) [expr $iinfo(daq_image_height) \
				* $iinfo(analysis_pixel_size_um)]
			set result [LWDAQ_analysis_BCAM $info(image_$side)]
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

	set err [DFPS_Calibrator_disagreement]
	LWDAQ_print $info(text) "Current spot position fit error is $err um rms."

	set info(state) "Idle"
	return ""
}

#
# DFPS_Calibrator_displace displaces the camera calibration constants by a
# random amount in proportion to their scaling factors. The routine does not
# print anything to the text window, but if show_fit is set, it does update the
# modelled source positions in the image. We want to be able to use this routine
# repeatedly to move the modelled sources around before starting a new fit,
# while reserving the text window for the fitted end values.
#
proc DFPS_Calibrator_displace {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	foreach side {left right} {
		for {set i 0} {$i < [llength $config(cam_$side)]} {incr i} {
			lset config(cam_$side) $i [format %.3f \
				[expr [lindex $config(cam_$side) $i] \
					+ ((rand()-0.5) \
						*$config(displace_scale) \
						*[lindex $config(scaling) $i])]]
		}
	}
	DFPS_Calibrator_disagreement
	return ""
} 

#
# DFPS_Calibrator_defaults restores the cameras to their default, nominal
# calibration constants.
#
proc DFPS_Calibrator_defaults {} {
	upvar #0 DFPS_Calibrator_config config
	upvar #0 DFPS_Calibrator_info info

	foreach side {left right} {
		set config(cam_$side) $config(cam_default)
	}
	DFPS_Calibrator_disagreement
	return ""
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
	set altitude [DFPS_Calibrator_disagreement "$params"]
	LWDAQ_support
	return $altitude
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
		set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
		set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]
		lwdaq_config -show_details $config(fit_details)
		set end_params [lwdaq_simplex $start_params \
			DFPS_Calibrator_altitude \
			-report $config(fit_report) \
			-steps $config(fit_steps) \
			-restarts $config(fit_restarts) \
			-start_size $config(fit_startsize) \
			-end_size $config(fit_endsize) \
			-scaling $scaling]
		lwdaq_config -show_details 0
		if {[LWDAQ_is_error_result $end_params]} {error "$end_params"}
		set config(cam_left) "[lrange $end_params 0 7]"
		set config(cam_right) "[lrange $end_params 8 15]"
		LWDAQ_print $info(text) "$end_params"
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

	foreach a {Read Show Check Displace Defaults Examine Fit} {
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
		image create photo "dfps_calibrator_$a"
		label $f.$a -image "dfps_calibrator_$a"
		pack $f.$a -side left -expand yes
	}
	
	# Create the text window and direct the lwdaq library routines to print to this
	# window.
	set info(text) [LWDAQ_text_widget $w 120 15]
	lwdaq_config -text_name $info(text) -fsd 3	
	
	# Draw two blank images into the display.
	foreach side {left right} {
		lwdaq_draw $info(image_$side) dfps_calibrator_$side \
			-intensify $config(intensify) -zoom $config(zoom)
	}
	
	return $w
}

DFPS_Calibrator_init
DFPS_Calibrator_open
	
return ""

----------Begin Help----------

The Direct Fiber Positioning System (DFPS) Calibrator calculates the calibration
constants of the two Fiber View Cameras (FVCs) mounted on a DFPS base plate. The
routine assumes we have Coordinate Measuring Machine (CMM) measurements of the
left FVC mount, the right FVC mount, and four point sources visible to both
cameras. The program takes as input two images L.gif and R.gif from the left and
right FVCs respectively, and CMM.txt from the CMM.

The CMM.txt file must contain the diameter and x, y, and z coordinates of the
cone, slot, and flat balls in the two FVC mounts. After that we must find
diameter, x, y, and z coordinates of each calibration source ferrule. The file
containing these measurements must be named CMM.txt. In addition to the measured
diameters and coordinates, CMM.txt may contain any number of words that are not
real number strings and any number of white space charcters. All words that are
not real numbers will be ignored. An example CMM.txt file is to be found below.

+---------------------+--------------+------+-----------+---------+------+-------+----------+
| Feature Table       |              |      |           |         |      |       |          |
+---------------------+--------------+------+-----------+---------+------+-------+----------+
| Length Units        | Millimeters  |      |           |         |      |       |          |
| Coordinate Systems  | csys         |      |           |         |      |       |          |
| Data Alignments     | original     |      |           |         |      |       |          |
|                     |              |      |           |         |      |       |          |
| Name                | Control      | Nom  | Meas      | Tol     | Dev  | Test  | Out Tol  |
| g1                  | Diameter     |      | 12.702    | ±1.000  |      |       |          |
| g1                  | X            |      | 0.000     | ±1.000  |      |       |          |
| g1                  | Y            |      | 0.000     | ±1.000  |      |       |          |
| g1                  | Z            |      | 0.000     | ±1.000  |      |       |          |
| g2                  | Diameter     |      | 12.700    | ±1.000  |      |       |          |
| g2                  | X            |      | 100.390   | ±1.000  |      |       |          |
| g2                  | Y            |      | 0.000     | ±1.000  |      |       |          |
| g2                  | Z            |      | 0.000     | ±1.000  |      |       |          |
| g3                  | Diameter     |      | 12.698    | ±1.000  |      |       |          |
| g3                  | X            |      | 1.023     | ±1.000  |      |       |          |
| g3                  | Y            |      | -0.155    | ±1.000  |      |       |          |
| g3                  | Z            |      | 175.224   | ±1.000  |      |       |          |
| l1                  | Diameter     |      | 6.349     | ±1.000  |      |       |          |
| l1                  | X            |      | 79.614    | ±1.000  |      |       |          |
| l1                  | Y            |      | 51.505    | ±1.000  |      |       |          |
| l1                  | Z            |      | 199.754   | ±1.000  |      |       |          |
| l2                  | Diameter     |      | 6.347     | ±1.000  |      |       |          |
| l2                  | X            |      | 119.777   | ±1.000  |      |       |          |
| l2                  | Y            |      | 51.355    | ±1.000  |      |       |          |
| l2                  | Z            |      | 264.265   | ±1.000  |      |       |          |
| l3                  | Diameter     |      | 6.350     | ±1.000  |      |       |          |
| l3                  | X            |      | 79.277    | ±1.000  |      |       |          |
| l3                  | Y            |      | 51.400    | ±1.000  |      |       |          |
| l3                  | Z            |      | 275.713   | ±1.000  |      |       |          |
| r1                  | Diameter     |      | 6.352     | ±1.000  |      |       |          |
| r1                  | X            |      | -104.039  | ±1.000  |      |       |          |
| r1                  | Y            |      | 51.210    | ±1.000  |      |       |          |
| r1                  | Z            |      | 199.297   | ±1.000  |      |       |          |
| r2                  | Diameter     |      | 6.352     | ±1.000  |      |       |          |
| r2                  | X            |      | -108.680  | ±1.000  |      |       |          |
| r2                  | Y            |      | 51.004    | ±1.000  |      |       |          |
| r2                  | Z            |      | 275.110   | ±1.000  |      |       |          |
| r3                  | Diameter     |      | 6.354     | ±1.000  |      |       |          |
| r3                  | X            |      | -148.231  | ±1.000  |      |       |          |
| r3                  | Y            |      | 50.989    | ±1.000  |      |       |          |
| r3                  | Z            |      | 261.059   | ±1.000  |      |       |          |
| u1                  | Diameter     |      | 2.498     | ±1.000  |      |       |          |
| u1                  | X            |      | -28.554   | ±1.000  |      |       |          |
| u1                  | Y            |      | 103.614   | ±1.000  |      |       |          |
| u1                  | Z            |      | -91.666   | ±1.000  |      |       |          |
| u2                  | Diameter     |      | 2.399     | ±1.000  |      |       |          |
| u2                  | X            |      | 1.447     | ±1.000  |      |       |          |
| u2                  | Y            |      | 103.722   | ±1.000  |      |       |          |
| u2                  | Z            |      | -92.199   | ±1.000  |      |       |          |
| u3                  | Diameter     |      | 2.401     | ±1.000  |      |       |          |
| u3                  | X            |      | -28.490   | ±1.000  |      |       |          |
| u3                  | Y            |      | 73.650    | ±1.000  |      |       |          |
| u3                  | Z            |      | -92.161   | ±1.000  |      |       |          |
| u4                  | Diameter     |      | 2.372     | ±1.000  |      |       |          |
| u4                  | X            |      | 1.433     | ±1.000  |      |       |          |
| u4                  | Y            |      | 73.749    | ±1.000  |      |       |          |
| u4                  | Z            |      | -92.267   | ±1.000  |      |       |          |
+---------------------+--------------+------+-----------+---------+------+-------+----------+

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