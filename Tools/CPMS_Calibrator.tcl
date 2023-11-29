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
	
	LWDAQ_tool_init "CPMS_Calibrator" "3.2"
	if {[winfo exists $info(window)]} {return ""}

	set config(cam_left) "12.675 39.312 1.1 0.0 0.0 2 26.0 0.0" 
	set config(mount_left) "92.123 -18.364 -3.450 \
		83.853 -18.211 -78.940 \
		125.201 -17.747 -71.806"
	set config(coord_left) [lwdaq bcam_coord_from_mount $config(mount_left)]
	set config(cam_right) "12.675 -39.312 1.1 0.0 0.0 2 26.0 3141.6" 
	set config(mount_right) "-77.819 -20.395 -2.397 \
		-74.201 -20.179 -75.451 \
		-115.549 -20.643 -68.317"
	set config(coord_right) [lwdaq bcam_coord_from_mount $config(mount_right)]

	set config(bodies) [list \
		"20.231 19.192 506.194 0 0 0 sphere 0 0 0 38.068" \
		"20.017 19.275 466.169 0 0 0 sphere 0 0 0 38.068" \
		"19.861 19.319 436.169 0 0 0 sphere 0 0 0 38.073" \
		"19.693 19.371 406.173 0 0 0 sphere 0 0 0 38.072"]

	set config(scaling) "1 1 1 1 1 0 1 1"

	set config(fit_steps) "1000"
	set config(fit_restarts) "0"
	set config(stop_fit) "0"
	set config(zoom) "0.5"
	set config(intensify) "exact"
	set config(num_lines) "20"
	set config(threshold) "10 %"
	set config(line_width) "3"
	set config(img_dir) "~/Desktop/CPMS"
	
	set info(state) "Idle"

	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 

	foreach a {1 2 3 4} {
		lwdaq_image_create -name img_left_$a -width 700 -height 520
		lwdaq_image_create -name img_right_$a -width 700 -height 520
	}

	return ""   
}

#
# CPMS_Calibrator_read_files attempts to read eight images with names L1..L4 and
# R1..R4. It tries to open a file CMM.txt that contains CMM measurements of a sphere
# in four positions, as well as measurements of a left and right SCAM mount.
#
proc CPMS_Calibrator_read_files {{img_dir ""}} {
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
		set config(mount_left) [join [lrange $spheres 3 5]]
		set config(mount_right) [join [lrange $spheres 6 8]]
		set spheres [list]
		foreach {d x y z} $numbers {lappend spheres "$d $x $y $z"}
		set spheres [lrange $spheres 9 end]
		set config(bodies) [list]
		foreach s $spheres {
			lappend config(bodies) "[lrange $s 1 3] 0 0 0 sphere 0 0 0 [lindex $s 0]"
		}
	} else {
		LWDAQ_print $info(text) "Cannot find \"$fn\"."
		set info(state) "Idle"
		return ""
	}

	set a 1
	set count 0
	foreach body $config(bodies) {
		foreach {letter word} {L left R right} {
			set imgf [file join $config(img_dir) $letter$a\.gif]
			if {[file exists $imgf]} {
				LWDAQ_read_image_file $imgf img_$word\_$a
				incr count
			}
		}
		incr a
	}
	LWDAQ_print $info(text) "Read left and right mounts,\
		[llength $config(bodies)] bodies,\
		$count images."
		
	CPMS_Calibrator_show
	
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

	# If user has closed the manager window, generate an error so that we stop any
	# fitting that might be calling this routine. 
	if {![winfo exists $info(window)]} {
		error "Cannot draw CPMS images: no CPMS window open."
	}
	
	# Make sure messages from the SCAM routines get to the CPMS Manager's text
	# window. Set the number of decimal places to three.
	lwdaq_config -text_name $info(text)

	# Extract the two sets of camera calibration constants from the parameters passed
	# to us by the fitter.
	set scam_left "SCAM_left [lrange $params 0 7]"
	set scam_right "SCAM_left [lrange $params 8 15]"
	
	# Go through the four pairs of images, each of which views its own body. We 
	# project the body into the image plane of each camera, measure disagreement
	# and draw the images with coloring.
	set disagreement 0
	set a 1
	foreach body $config(bodies) {
		foreach side {left right} {
			lwdaq_image_manipulate img_$side\_$a none -clear 1	
			lwdaq_scam img_$side\_$a project \
				$config(coord_$side) [set scam_$side] $body \
				-num_lines $config(num_lines) -line_width $config(line_width)
			set count [lindex [lwdaq_scam img_$side\_$a \
				"disagreement" $config(threshold)] 0]
			set disagreement [expr $disagreement + $count]
			lwdaq_draw img_$side\_$a photo_$side\_$a \
				-intensify $config(intensify) -zoom $config(zoom)
		}
		incr a
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
	LWDAQ_update
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
# CPMS_Calibrator_clear clears the overlay pixels in the cpms images, so that we see
# only the original silhouette images.
#
proc CPMS_Calibrator_clear {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	foreach a {1 2 3 4} {
		lwdaq_image_manipulate img_left_$a none -clear 1
		lwdaq_image_manipulate img_right_$a none -clear 1	
		lwdaq_draw img_left_$a photo_left_$a \
			-intensify $config(intensify) -zoom $config(zoom)
		lwdaq_draw img_right_$a photo_right_$a \
			-intensify $config(intensify) -zoom $config(zoom)
	}
}

#
# CPMS_Calibrator_open opens the CPMS Manger Tool window.
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

	foreach a {Show Clear Displace Fit Read_Files} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_post CPMS_Calibrator_$b"
		pack $f.$b -side left -expand yes
	}

	foreach a {threshold num_lines line_width} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 4
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	foreach a {Help Configure} {
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

	set f [frame $w.mounts]
	pack $f -side top -fill x

	foreach a {mount_left mount_right} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 60
		pack $f.l$a $f.e$a -side left -expand yes
	}

	set f [frame $w.bodies]
	pack $f -side top -fill x

	label $f.lbody -text "bodies:"
	entry $f.ebody -textvariable CPMS_Calibrator_config(bodies) -width 180
	pack $f.lbody $f.ebody -side left -expand yes
		
	set f [frame $w.images_a]
	pack $f -side top -fill x

	foreach a {1 2} {
		image create photo "photo_left_$a"
		label $f.left_$a -image "photo_left_$a"
		pack $f.left_$a -side left -expand yes
		image create photo "photo_right_$a"
		label $f.right_$a -image "photo_right_$a"
		pack $f.right_$a -side left -expand yes
	}
		
	set f [frame $w.images_b]
	pack $f -side top -fill x

	foreach a {3 4} {
		image create photo "photo_left_$a"
		label $f.left_$a -image "photo_left_$a"
		pack $f.left_$a -side left -expand yes
		image create photo "photo_right_$a"
		label $f.right_$a -image "photo_right_$a"
		pack $f.right_$a -side left -expand yes
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
measurements of the global coordinates and diameter of a sphere in each of four
positions in the field of view of both SCAMs, CMM measurements of the left and
right SCAM mounting balls in the same coordinate system, and left and right SCAM
images the sphere in each of the four positions. The sphere need not be the same
sphere. That is: we could use different diameter spheres in each of the four
locations. 

The CMM output file must contain the diameter, and x, y, and z coordinates of
the three balls used to define the global coordinate system, followed by the
same for the cone, slot, and flat balls of the left mount, followed by the same
for the right mount, and finally the same for each of the four calibration
spheres in sequence. The file containing these measurements must be named
CMM.txt. The file can contain any number of words that are not well-formed real
number strings, and it can contain any number of white space charcters. All
words that are not real numbers will be ignored. An example CMM.txt file is to
be found in the data section of the CPMS_Calibrator.tcl script. The images must
be named L1, R1, L2, R2,.. for the four spheres. They can be in GIF, PNG, or DAQ
format.

The calibrator works by minimizing disagreement between actual silhouettes and a
line drawing of modelled spheres. The line drawing can be sparse, as when
num_lines = 20, or filled completely, as when num_lines = 2000. We can increase
the thickness of the lines with the line_width parameter. The silhouettes will
be drawn using the intensity threshold dictated by the threshold string. When we
press Fit, the simplex fitter starts minimizing the disagreement by adjusting
the calibrations of the left and right SCAMs. This process can take one or two
minutes. The buttons in the calibrator have the following functions.

Stop: Abort fitting.

Show: Show the silhouettes and line drawings.

Clear: Clear the silhouettes and line drawings, show the raw images.

Displace: Displace the camera calibration constants from their current values.

Fit: Start the simplex fitter adjusting calibration constants to minimize
disagreement.

Read_Files: Select a directory, read image files and CMM measurements

Help: Get this help page.

Configure: Open configuration panel with Save and Unsave buttons.

To use the calibrator, press Read_Files and select your measurements. The
calibrator will display the images, silhouettes, and the modelled spheres. If
the spheres are nowhere near the silhouettes, or they are not visible, you most
likely have a mix-up in the mount coordinates. You may be saing that a slot ball
is a flat ball, for example, as is likely when you swap a blue for a black SCAM.
When you have the modelled spheres overlapping the silhouettes, press Fit. The
modelled spheres will start moving around. The status indicator on the top left
will say "Fitting". After a minute or two, the fit will converge. The status
label will return to "Idle". The camera calibration constants are now ready.

(C) Kevan Hashemi, 2023, Open Source Instruments Inc.
https://www.opensourceinstruments.com

----------End Help----------

----------Begin Data----------

+---------------------+--------------+------+-----------+---------+------+-------+----------+
| Feature Table       |              |      |           |         |      |       |          |
+---------------------+--------------+------+-----------+---------+------+-------+----------+
| Length Units        | Millimeters  |      |           |         |      |       |          |
| Coordinate Systems  | Main         |      |           |         |      |       |          |
| Data Alignments     | original     |      |           |         |      |       |          |
|                     |              |      |           |         |      |       |          |
| Name                | Control      | Nom  | Meas      | Tol     | Dev  | Test  | Out Tol  |
| Cone                | Diameter     |      | 6.345     | ±1.000  |      |       |          |
| Cone                | X            |      | 0.000     | ±1.000  |      |       |          |
| Cone                | Y            |      | 0.000     | ±1.000  |      |       |          |
| Cone                | Z            |      | 0.000     | ±1.000  |      |       |          |
| Slot                | Diameter     |      | 6.347     | ±1.000  |      |       |          |
| Slot                | X            |      | -20.975   | ±1.000  |      |       |          |
| Slot                | Y            |      | 0.000     | ±1.000  |      |       |          |
| Slot                | Z            |      | -73.000   | ±1.000  |      |       |          |
| Flat                | Diameter     |      | 6.346     | ±1.000  |      |       |          |
| Flat                | X            |      | 21.010    | ±1.000  |      |       |          |
| Flat                | Y            |      | 0.517     | ±1.000  |      |       |          |
| Flat                | Z            |      | -73.060   | ±1.000  |      |       |          |
| ConeL               | Diameter     |      | 6.339     | ±1.000  |      |       |          |
| ConeL               | X            |      | 92.134    | ±1.000  |      |       |          |
| ConeL               | Y            |      | -18.283   | ±1.000  |      |       |          |
| ConeL               | Z            |      | -3.435    | ±1.000  |      |       |          |
| SlotL               | Diameter     |      | 6.338     | ±1.000  |      |       |          |
| SlotL               | X            |      | 83.868    | ±1.000  |      |       |          |
| SlotL               | Y            |      | -18.132   | ±1.000  |      |       |          |
| SlotL               | Z            |      | -78.935   | ±1.000  |      |       |          |
| FlatL               | Diameter     |      | 6.336     | ±1.000  |      |       |          |
| FlatL               | X            |      | 125.222   | ±1.000  |      |       |          |
| FlatL               | Y            |      | -17.636   | ±1.000  |      |       |          |
| FlatL               | Z            |      | -71.795   | ±1.000  |      |       |          |
| ConeR               | Diameter     |      | 6.343     | ±1.000  |      |       |          |
| ConeR               | X            |      | -77.784   | ±1.000  |      |       |          |
| ConeR               | Y            |      | -20.454   | ±1.000  |      |       |          |
| ConeR               | Z            |      | -2.384    | ±1.000  |      |       |          |
| SlotR               | Diameter     |      | 6.339     | ±1.000  |      |       |          |
| SlotR               | X            |      | -74.756   | ±1.000  |      |       |          |
| SlotR               | Y            |      | -20.146   | ±1.000  |      |       |          |
| SlotR               | Z            |      | -78.278   | ±1.000  |      |       |          |
| FlatR               | Diameter     |      | 6.338     | ±1.000  |      |       |          |
| FlatR               | X            |      | -115.524  | ±1.000  |      |       |          |
| FlatR               | Y            |      | -20.735   | ±1.000  |      |       |          |
| FlatR               | Z            |      | -68.300   | ±1.000  |      |       |          |
| 0cm                 | Diameter     |      | 38.068    | ±1.000  |      |       |          |
| 0cm                 | X            |      | 20.231    | ±1.000  |      |       |          |
| 0cm                 | Y            |      | 19.192    | ±1.000  |      |       |          |
| 0cm                 | Z            |      | 506.194   | ±1.000  |      |       |          |
| 4cm                 | Diameter     |      | 38.066    | ±1.000  |      |       |          |
| 4cm                 | X            |      | 20.017    | ±1.000  |      |       |          |
| 4cm                 | Y            |      | 19.275    | ±1.000  |      |       |          |
| 4cm                 | Z            |      | 466.169   | ±1.000  |      |       |          |
| 7cm                 | Diameter     |      | 38.073    | ±1.000  |      |       |          |
| 7cm                 | X            |      | 19.861    | ±1.000  |      |       |          |
| 7cm                 | Y            |      | 19.319    | ±1.000  |      |       |          |
| 7cm                 | Z            |      | 436.169   | ±1.000  |      |       |          |
| 10cm                | Diameter     |      | 38.072    | ±1.000  |      |       |          |
| 10cm                | X            |      | 19.693    | ±1.000  |      |       |          |
| 10cm                | Y            |      | 19.371    | ±1.000  |      |       |          |
| 10cm                | Z            |      | 406.173   | ±1.000  |      |       |          |
+---------------------+--------------+------+-----------+---------+------+-------+----------+

----------End Data----------