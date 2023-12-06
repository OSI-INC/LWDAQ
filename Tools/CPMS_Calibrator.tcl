# CPMS Calibrator a LWDAQ Tool
# Copyright (C) 2023 Kevan Hashemi, Open Source Instruments Inc.
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
# CPMS_Calibrator_init initializes the tool's configuration and information arrays.
#
proc CPMS_Calibrator_init {} {
	upvar #0 CPMS_Calibrator_info info
	upvar #0 CPMS_Calibrator_config config
	
	LWDAQ_tool_init "CPMS_Calibrator" "4.2"
	if {[winfo exists $info(window)]} {return ""}

	set config(cam_left) "12.675 39.312 7.0 0.0 0.0 2 26.0 0.0" 
	set config(cam_right) "12.675 -39.312 7.0 0.0 0.0 2 26.0 3141.6" 
	set config(scaling) "0 0 0 1 1 0 1 1"

	set config(mount_reference) "0 0 0 -21 0 -73 21 0 -73"
	set config(coord_reference) [lwdaq bcam_coord_from_mount $config(mount_reference)]
	
	set config(mount_left) "0 0 0 -21 0 -73 21 0 -73"
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	
	set config(mount_right) "0 0 0 21 0 -73 -21 0 -73"
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	set config(body_1) "0 40 400 0 0 0 sphere 0 0 0 20"
	set config(body_2) "-20 40 600 0 0 0 shaft 0 0 0 1 0 0\
		40 0 40 10 20 10 20 40 80 40 80 60"
	set config(body_3) "0 40 500 0 0 0 sphere 0 0 0 50"
	set config(body_4) "0 40 550 0 0 0 sphere 0 0 0 40"
	set config(display_body) "1"
	set config(fit_bodies) "1 2 3 4"
	set config(num_bodies) 4

	set config(fit_steps) "1000"
	set config(fit_restarts) "0"
	set config(stop_fit) "0"
	set config(zoom) "0.5"
	set config(intensify) "exact"
	set config(num_lines) "2000"
	set config(threshold) "10 %"
	set config(line_width) "1"
	set config(img_dir) "~/Desktop/CPMS"
	
	set info(state) "Idle"
	
	set info(examine_window) "$info(window).examine_window"
	set info(state) "Idle"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	for {set a 1} {$a <= $config(num_bodies)} {incr a} {
		foreach side {left right} {
			lwdaq_image_create -name img_$side\_$a -width 700 -height 520
		}
	}

	return ""   
}

#
# CPMS_Calibrator_clear clears the overlay pixels in the cpms images, so that we see
# only the original silhouette images.
#
proc CPMS_Calibrator_clear {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	LWDAQ_print $info(text) "Coordinate Systems:"
	foreach mount {reference left right} {
		set config(coord_$mount) [lwdaq bcam_coord_from_mount $config(mount_$mount)]
		LWDAQ_print $info(text) "$mount $config(coord_$mount)" brown
	}

	for {set a 1} {$a <= $config(num_bodies)} {incr a} {
		if {[lsearch $config(fit_bodies) $a] >= 0} {set fit 1} else {set fit 0}
		if {$a == $config(display_body)} {set display 1} else {set display 0}
		lwdaq_image_manipulate img_left_$a none -clear 1
		lwdaq_image_manipulate img_right_$a none -clear 1	
		if {$display} {
			lwdaq_draw img_left_$a photo_left \
				-intensify $config(intensify) -zoom $config(zoom)
			lwdaq_draw img_right_$a photo_right \
				-intensify $config(intensify) -zoom $config(zoom)
		}
	}
}

#
# CPMS_Calibrator_examine opens a new window that displays the CMM
# measurements of the left and right mounts, as well calibration constants of
# the left and right cameras, as well as the calibration bodies. The window
# allows us to modify the mount measurements and body definitions directly.
#
proc CPMS_Calibrator_examine {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set w $info(examine_window)
	if {![winfo exists $w]} {
		toplevel $w
		wm title $w "Coordinate Measurements, CPMS Calibrator $info(version)"
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
	
	foreach mount {reference left right} {
		set f [frame $w.$mount]
		pack $f -side top -fill x
		label $f.l$mount -text "$mount\:"
		entry $f.e$mount -textvariable CPMS_Calibrator_config(mount_$mount) -width 70
		pack $f.l$mount $f.e$mount -side left -expand yes
	}

	for {set a 1} {$a <= $config(num_bodies)} {incr a} {
		set f [frame $w.$a]
		pack $f -side top -fill x
		label $f.l$a -text "Body $a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config(body_$a) -width 70
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	return ""
}

#
# CPMS_Calibrator_read looks for a file called CMM.txt in a directory. We either
# pass it the directory name or the routine will open a browser for us to choose
# the directory. From the CMM.txt file the calibrator reads the global
# coordinats of the balls in the reference mount, left SCAM mount, and right
# SCAM mount. It reads the diameter and position of all object sphere
# measurements, each of which represents a location of the sphere for which we
# have accompanying CPMS images Lx.gif and Rx.gif, where x is 1 for the first
# position, and so on. 
#
proc CPMS_Calibrator_read {{img_dir ""}} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

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
	
	set fn [file join $img_dir CMM.txt]
	if {[file exists $fn]} {
		set f [open $fn r]
		set cmm [read $f]
		close $f
		set numbers [list]
		foreach a $cmm {if {[string is double -strict $a]} {lappend numbers $a}}
		set spheres [list]
		foreach {d x y z} $numbers {lappend spheres "$x $y $z"}
		set config(mount_reference) [join [lrange $spheres 0 2]]
		set config(mount_left) [join [lrange $spheres 3 5]]
		set config(mount_right) [join [lrange $spheres 6 8]]
		set spheres [list]
		foreach {d x y z} $numbers {lappend spheres "$d $x $y $z"}
		set spheres [lrange $spheres 9 end]
		set a 0
		foreach s $spheres {
			incr a
			set config(body_$a) "[lrange $s 1 3] 0 0 0 sphere 0 0 0 [lindex $s 0]"
		}
		set config(num_bodies) $a
	} else {
		LWDAQ_print $info(text) "Cannot find \"$fn\"."
		set info(state) "Idle"
		return ""
	}

	set count 0
	for {set a 1} {$a <= $config(num_bodies)} {incr a} {
		foreach {s side} {L left R right} {
			set ifn [file join $config(img_dir) $s$a\.gif]
			if {[file exists $ifn]} {
				LWDAQ_read_image_file $ifn img_$side\_$a
				incr count
			}
		}
	}
	LWDAQ_print $info(text) "Read reference, left and right mounts.\
		Read $config(num_bodies) bodies. Read $count images."
	
	CPMS_Calibrator_clear
		
	set w $info(examine_window)
	if {[winfo exists $w]} {
		LWDAQ_print $info(text) "Updating calibration measurement window for new bodies."
		destroy $w
		CPMS_Calibrator_examine
	}
	
	if {[catch {CPMS_Calibrator_show} error_message]} {
		LWDAQ_print $info(text) "ERROR: $error_message\."
		LWDAQ_print $info(text) \
			"SUGGESTION: Check your CMM.txt file format and image names."	
	}
	
	set info(state) "Idle"
}

#
# CPMS_Calibrator_disagreement takes the eight SCAM images and obtains the
# number of pixels in which our modelled bodies and their actual silhouettes
# disagree. In doing so, the routine colors the overlay of the SCAM images to
# show the modelled bodies and their silhouettes with the disagreement pixels
# colored blue for model without silhouette and orange for silhouette without
# model and no overlay color for agreement between the two.
#
proc CPMS_Calibrator_disagreement {params} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	# If user has closed the calibrator window, generate an error so that we stop any
	# fitting that might be calling this routine. 
	if {![winfo exists $info(window)]} {
		error "Cannot draw CPMS images: no CPMS window open."
	}
	
	# Make sure messages from the SCAM routines get to the CPMS Calibrator's text
	# window. Set the number of decimal places to three.
	lwdaq_config -text_name $info(text)

	# Extract the two sets of camera calibration constants from the parameters passed
	# to us by the fitter.
	set scam_left "SCAM_left [lrange $params 0 7]"
	set scam_right "SCAM_left [lrange $params 8 15]"
	
	# Go through the list of bodies. For each body, we check to see if it is one
	# chosen for the calibration fit. If so, we calculate disagreement for the
	# left and right cameras and add to our disagreement total. If the body is
	# the one we want to display, we display it with the silhouette and model
	# colors in the overlay.
	set disagreement 0
	for {set a 1} {$a <= $config(num_bodies)} {incr a} {
		if {[lsearch $config(fit_bodies) $a] >= 0} {set fit 1} else {set fit 0}
		if {$a == $config(display_body)} {set display 1} else {set display 0}
		if {$fit || $display} {
			foreach side {left right} {
				lwdaq_image_manipulate img_$side\_$a none -clear 1	
				lwdaq_scam img_$side\_$a project \
					$config(coord_$side) [set scam_$side] \
					$config(body_$a) \
					-num_lines $config(num_lines) -line_width $config(line_width)
				set count [lindex [lwdaq_scam img_$side\_$a \
					"disagreement" $config(threshold)] 0]
				if {$fit} {
					set disagreement [expr $disagreement + $count]
				}
				if {$display} {
					lwdaq_draw img_$side\_$a photo_$side \
						-intensify $config(intensify) -zoom $config(zoom)
				}
			}
		}
	}
	
	# Return the total disagreement, which is our error value.
	return $disagreement
}

#
# CPMS_Calibrator_get_params puts together a string containing the parameters
# the fitter can adjust to minimise the calibration disagreement. The fitter
# will adjust any parameter for which we assign a scaling value greater than 
# zero. The scaling string gives the scaling factors the fitter uses for each
# camera calibration constant. The scaling factors are used twice: once for 
# the left camera and once for the right. See the fitting routine for their
# implementation.
#
proc CPMS_Calibrator_get_params {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set params "$config(cam_left) $config(cam_right)"
	return $params
}

#
# CPMS_Calibrator_show gets the current camera calibration constants and shows
# the locations of the modelled bodies in their left images. It calculates the
# disagreement, and prints the current parameters and disagreement to the text
# window. In case we have adjusted the mounts before showing, we calculate
# again the pose of the mount from both sets of balls.
#
proc CPMS_Calibrator_show {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set info(control) "Show"
	LWDAQ_update
	
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]
	set params [CPMS_Calibrator_get_params]
	set disagreement [CPMS_Calibrator_disagreement $params]
	set result "$params $disagreement"
	LWDAQ_print $info(text) $result
	
	set info(control) "Idle"
	return 
}

#
# CPMS_Calibrator_displace displaces the camera calibration constants by a random
# amount in proportion to their scaling factors.
#
proc CPMS_Calibrator_displace {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	foreach side {left right} {
		for {set i 0} {$i < [llength $config(cam_$side)]} {incr i} {
			lset config(cam_$side) $i [format %.3f \
				[expr [lindex $config(cam_$side) $i] \
					+ (rand()-0.5)*10.0*[lindex $config(scaling) $i]]]
		}
	}
	set params [CPMS_Calibrator_get_params]
	CPMS_Calibrator_disagreement $params
	return $params
} 

#
# CPMS_Calibrator_altitude is the error function for the fitter. The fitter calls
# this routine with a set of parameter values to get the disgreement, which it
# is attemptint to minimise.
#
proc CPMS_Calibrator_altitude {params} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	if {$config(stop_fit)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	set count [CPMS_Calibrator_disagreement "$params"]
	LWDAQ_support
	return $count
}

#
# CPMS_Calibrator_fit gets the camera calibration constants as a starting point
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
proc CPMS_Calibrator_fit {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set config(stop_fit) 0
	set info(state) "Fitting"
	
	if {[catch {
		set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
		set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]
		set scaling "$config(scaling) $config(scaling)"
		set start_params [CPMS_Calibrator_get_params] 
		set end_params [lwdaq_simplex $start_params \
			CPMS_Calibrator_altitude \
			-report 0 -steps $config(fit_steps) -restarts $config(fit_restarts) \
			-start_size 1.0 -end_size 0.01 \
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

	CPMS_Calibrator_disagreement [CPMS_Calibrator_get_params]
	set info(state) "Idle"
}

#
# CPMS_Calibrator_check opens the CPMS Manager and uses its fitting routine to
# measure the position of all calibration bodies using the current camera
# calibration constants and mount measurements. It compares the CPMS measurement
# to the CMM measurement and reports on the difference. Before the CPMS Manager
# performs its fit, we displace its model of the calibration model so as to
# blind it to the correct body pose. The results of the check we print in the
# calibrator text window, giving the position of the body as measured by the
# CMM, and the difference between the CPMS measurement and the CMM measurement.
#
proc CPMS_Calibrator_check {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info
	upvar #0 CPMS_Manager_config mconfig
	upvar #0 CPMS_Manager_info minfo
	upvar #0 LWDAQ_config_SCAM iconfig
	
	set config(stop_fit) 0
	set info(state) "Check"

	set iconfig(analysis_threshold) $config(threshold)

	LWDAQ_run_tool "CPMS_Manager"
	foreach b {num_lines line_width cam_left cam_right mount_left mount_right} {
		set mconfig($b) $config($b)
	}
	
	for {set a 1} {$a <= $config(num_bodies)} {incr a} {
		if {$config(stop_fit)} {
			LWDAQ_print $info(text) "Check aborted by user."
			set info(state) "Idle"
			return ""
		}
		if {[lsearch $config(fit_bodies) $a] >= 0} {
			set mconfig(bodies) [list $config(body_$a)]
			lwdaq_image_manipulate img_left\_$a copy -name $minfo(img_left)
			lwdaq_image_manipulate img_right\_$a copy -name $minfo(img_right)
			CPMS_Manager_displace
			set result [lindex [CPMS_Manager_fit] 0]
			
			LWDAQ_print $info(text) "$a [lrange $config(body_$a) 0 2]\
				[format %.3f [expr [lindex $result 0]-[lindex $config(body_$a) 0]]]\
				[format %.3f [expr [lindex $result 1]-[lindex $config(body_$a) 1]]]\
				[format %.3f [expr [lindex $result 2]-[lindex $config(body_$a) 2]]]"
		}
	}
	
	set info(state) "Idle"
	return ""

}


#
# CPMS_Calibrator_open opens the CPMS Calibrator window.
#
proc CPMS_Calibrator_open {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable CPMS_Calibrator_info(state) -fg blue -width 10
	pack $f.state -side left -expand yes

	button $f.stop -text "Stop" -command {set CPMS_Calibrator_config(stop_fit) 1}
	pack $f.stop -side left -expand yes

	foreach a {Show Clear Displace Fit} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post CPMS_Calibrator_$b"
		pack $f.$b -side left -expand yes
	}

	foreach a {threshold num_lines line_width} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 4
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {Configure Help} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.cameras]
	pack $f -side top -fill x

	foreach a {cam_left cam_right} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 50
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {scaling} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 20
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.measurements]
	pack $f -side top -fill x

	foreach a {Read Examine Check} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post CPMS_Calibrator_$b"
		pack $f.$b -side left -expand yes
	}

	foreach a {num_bodies display_body} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 3
		pack $f.l$a $f.e$a -side left -expand yes
	}
		
	foreach a {fit_bodies} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 30
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

CPMS_Calibrator_init
CPMS_Calibrator_open
CPMS_Calibrator_clear
	
return ""

----------Begin Help----------

The Contactless Position Measurement System (CPMS) Calibrator calculates the
calibration constants of the two Silhouette Cameras (SCAMs) mounted on a CPMS
base plate. The routine assumes we have Coordinate Measuring Machine (CMM)
measurements of a reference mount, a left SCAM mount, a right SCAM mount, and
two or more bodies in the field of view of both SCAMs. These "bodies" can be the
same or different bodies. This version of the Calibrator supports only
single-sphere bodies, but future versions might permit calibration with shafts
and pairs of spheres. The Calibrator assumes we have both left and right SCAM
images to accompany all calibration bodies. 

The CMM output file must contain the diameter, and x, y, and z coordinates of
the cone, slot, and flat balls in the mount we use to define the global
coordinate system, followed by the same for the left and right mounts. Next come
the diameter, x, y, and z coordinates of each calibration sphere. The file
containing these measurements must be named CMM.txt. In addition to the measured
diameters and coordinates, CMM.txt may contain any number of words that are not
real number strings and any number of white space charcters. All words that are
not real numbers will be ignored. An example CMM.txt file is to be found below.
The images must be named L1, R1, L2, ... RN for the N spheres. The spheres can
be GIF, PNG, or DAQ.

+---------------------+--------------+------+-----------+---------+
| Feature Table       |              |      |           |         |
+---------------------+--------------+------+-----------+---------+
| Length Units        | Millimeters  |      |           |         |
| Coordinate Systems  | Global       |      |           |         | 
| Data Alignments     | original     |      |           |         |
|                     |              |      |           |         |
| Name                | Control      | Nom  | Meas      | Tol     |
| Cone                | Diameter     |      | 6.338     | ±1.000  |
| Cone                | X            |      | 0.000     | ±1.000  |
| Cone                | Y            |      | 0.000     | ±1.000  |
| Cone                | Z            |      | 0.000     | ±1.000  |
| Slot                | Diameter     |      | 6.339     | ±1.000  |
| Slot                | X            |      | -20.975   | ±1.000  |
| Slot                | Y            |      | 0.000     | ±1.000  |
| Slot                | Z            |      | -72.999   | ±1.000  |
| Flat                | Diameter     |      | 6.335     | ±1.000  |
| Flat                | X            |      | 21.008    | ±1.000  |
| Flat                | Y            |      | 0.000     | ±1.000  |
| Flat                | Z            |      | -73.065   | ±1.000  |
| ConeL               | Diameter     |      | 6.340     | ±1.000  |
| ConeL               | X            |      | 91.877    | ±1.000  |
| ConeL               | Y            |      | -19.475   | ±1.000  |
| ConeL               | Z            |      | -3.330    | ±1.000  |
| SlotL               | Diameter     |      | 6.338     | ±1.000  |
| SlotL               | X            |      | 83.628    | ±1.000  |
| SlotL               | Y            |      | -19.455   | ±1.000  |
| SlotL               | Z            |      | -78.877   | ±1.000  |
| FlatL               | Diameter     |      | 6.341     | ±1.000  |
| FlatL               | X            |      | 124.975   | ±1.000  |
| FlatL               | Y            |      | -19.476   | ±1.000  |
| FlatL               | Z            |      | -71.682   | ±1.000  |
| ConeR               | Diameter     |      | 6.336     | ±1.000  |
| ConeR               | X            |      | -78.059   | ±1.000  |
| ConeR               | Y            |      | -19.492   | ±1.000  |
| ConeR               | Z            |      | -2.332    | ±1.000  |
| SlotR               | Diameter     |      | 6.337     | ±1.000  |
| SlotR               | X            |      | -75.026   | ±1.000  |
| SlotR               | Y            |      | -19.497   | ±1.000  |
| SlotR               | Z            |      | -78.231   | ±1.000  |
| FlatR               | Diameter     |      | 6.339     | ±1.000  |
| FlatR               | X            |      | -115.797  | ±1.000  |
| FlatR               | Y            |      | -19.534   | ±1.000  |
| FlatR               | Z            |      | -68.268   | ±1.000  |
| S1                  | Diameter     |      | 38.060    | ±1.000  |
| S1                  | X            |      | 21.098    | ±1.000  |
| S1                  | Y            |      | 24.145    | ±1.000  |
| S1                  | Z            |      | 386.482   | ±1.000  |
| S2                  | Diameter     |      | 38.054    | ±1.000  |
| S2                  | X            |      | 21.274    | ±1.000  |
| S2                  | Y            |      | 12.845    | ±1.000  |
| S2                  | Z            |      | 386.406   | ±1.000  |
+---------------------+--------------+------+-----------+---------+

The calibrator works by minimizing disagreement between actual silhouettes and
drawings of modelled spheres. The drawing should be filled, as when num_lines is
2000, or else the fit may not converge correctly. The line width should be only
one pixel, as with line_width is 1, or else the fill will make the modelled
object appear too large. The silhouettes will be drawn using the intensity
threshold dictated by the threshold string. When we press Fit, the simplex
fitter starts minimizing the disagreement by adjusting the calibrations of the
left and right SCAMs. The fit applies the "scaling" values to the eight
calibration constants of the cameras. We can fix any one of the eight parameters
by setting its scaling value to zero. We always fix the pivot.z of SCAMs because
this parameter has no geometric implementation. The fit uses only those
calibration bodies specified in the fit_bodies string. If we want all bodies to
be used, we list all the body numbers from 1 to N for N bodies. If we want to
use only two of them, we list their indeces. During the fit, we select one of
the bodies to view by giving its index in the display_body entry. We can change
both fit_bodies and display_bodies during the fit, and the fit will adapt as it
proceeds.

Stop: Abort fitting.

Show: Show the silhouettes and modelled bodies.

Clear: Clear the silhouettes and modelled bodies, show the raw images.

Displace: Displace the camera calibration constants from their current values.

Fit: Start the simplex fitter adjusting calibration constants to minimize
disagreement.

Configure: Open configuration panel with Save and Unsave buttons.

Help: Get this help page.

Read: Select a directory, read image files and CMM measurements. The images must
be L1.gif, R1.gif, ... RN.gif, where N is the number of calibration spheres. The
CMM measurements must be in a file called CMM.txt. The only real-valued words in
the file must be diameter, x, y, z coordinates in millimeters of the three
global coordinate system definition balls, the cone, slot, flat balls of the
left and right SCAM mounts, and the calibration spheres. The text table below is
an example of one produced by our CMM that satisfies the calibrator's
requirements.

Examine: Open a window that displays the mount and body measurements produce by
the CMM. We can modify any measurement in this window and see how our
modification affects the fit by following with the Show button.

Check: Opens the CPMS Manager Tool and uses its fitting routine to check the
performance of the current camera calibration constants when applied to all
bodies listed in fit_bodies. Leaves the CPMS Manager open at the end, with
mounts and cameras updated.

To use the calibrator, press Read and select your measurements. The calibrator
will display the images, silhouettes, and the modelled bodies. If the bodies are
nowhere near the silhouettes, or they are not visible, you most likely have a
mix-up in the mount coordinates. Check that you have the slot and cone balls
named correctly for your black and blue SCAMs. If some bodies are in view of
both cameras, but others are not, use fit_bodies to select two or more bodies
that are in view of both cameras. Press Fit. Choose a body to display with
display_body. The modelled body will start moving around. The status indicator
on the top left will say "Fitting". After a minute or two, the fit will
converge. The status label will return to "Idle". The camera calibration
constants are now ready.

(C) Kevan Hashemi, 2023, Open Source Instruments Inc.
https://www.opensourceinstruments.com

----------End Help----------

----------Begin Data----------

+---------------------+--------------+------+-----------+---------+
| Feature Table       |              |      |           |         |
+---------------------+--------------+------+-----------+---------+
| Length Units        | Millimeters  |      |           |         |
| Coordinate Systems  | Global       |      |           |         | 
| Data Alignments     | original     |      |           |         |
|                     |              |      |           |         |
| Name                | Control      | Nom  | Meas      | Tol     |
| Cone                | Diameter     |      | 6.338     | ±1.000  |
| Cone                | X            |      | 0.000     | ±1.000  |
| Cone                | Y            |      | 0.000     | ±1.000  |
| Cone                | Z            |      | 0.000     | ±1.000  |
| Slot                | Diameter     |      | 6.339     | ±1.000  |
| Slot                | X            |      | -20.975   | ±1.000  |
| Slot                | Y            |      | 0.000     | ±1.000  |
| Slot                | Z            |      | -72.999   | ±1.000  |
| Flat                | Diameter     |      | 6.335     | ±1.000  |
| Flat                | X            |      | 21.008    | ±1.000  |
| Flat                | Y            |      | 0.000     | ±1.000  |
| Flat                | Z            |      | -73.065   | ±1.000  |
| ConeL               | Diameter     |      | 6.340     | ±1.000  |
| ConeL               | X            |      | 91.877    | ±1.000  |
| ConeL               | Y            |      | -19.475   | ±1.000  |
| ConeL               | Z            |      | -3.330    | ±1.000  |
| SlotL               | Diameter     |      | 6.338     | ±1.000  |
| SlotL               | X            |      | 83.628    | ±1.000  |
| SlotL               | Y            |      | -19.455   | ±1.000  |
| SlotL               | Z            |      | -78.877   | ±1.000  |
| FlatL               | Diameter     |      | 6.341     | ±1.000  |
| FlatL               | X            |      | 124.975   | ±1.000  |
| FlatL               | Y            |      | -19.476   | ±1.000  |
| FlatL               | Z            |      | -71.682   | ±1.000  |
| ConeR               | Diameter     |      | 6.336     | ±1.000  |
| ConeR               | X            |      | -78.059   | ±1.000  |
| ConeR               | Y            |      | -19.492   | ±1.000  |
| ConeR               | Z            |      | -2.332    | ±1.000  |
| SlotR               | Diameter     |      | 6.337     | ±1.000  |
| SlotR               | X            |      | -75.026   | ±1.000  |
| SlotR               | Y            |      | -19.497   | ±1.000  |
| SlotR               | Z            |      | -78.231   | ±1.000  |
| FlatR               | Diameter     |      | 6.339     | ±1.000  |
| FlatR               | X            |      | -115.797  | ±1.000  |
| FlatR               | Y            |      | -19.534   | ±1.000  |
| FlatR               | Z            |      | -68.268   | ±1.000  |
| S1                  | Diameter     |      | 38.060    | ±1.000  |
| S1                  | X            |      | 21.098    | ±1.000  |
| S1                  | Y            |      | 24.145    | ±1.000  |
| S1                  | Z            |      | 386.482   | ±1.000  |
| S2                  | Diameter     |      | 38.054    | ±1.000  |
| S2                  | X            |      | 21.274    | ±1.000  |
| S2                  | Y            |      | 12.845    | ±1.000  |
| S2                  | Z            |      | 386.406   | ±1.000  |
| S3                  | Diameter     |      | 38.056    | ±1.000  |
| S3                  | X            |      | 26.487    | ±1.000  |
| S3                  | Y            |      | -2.695    | ±1.000  |
| S3                  | Z            |      | 640.772   | ±1.000  |
| S4                  | Diameter     |      | 38.062    | ±1.000  |
| S4                  | X            |      | 26.679    | ±1.000  |
| S4                  | Y            |      | 39.634    | ±1.000  |
| S4                  | Z            |      | 641.064   | ±1.000  |
+---------------------+--------------+------+-----------+---------+


----------End Data----------