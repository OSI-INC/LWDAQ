# CPMS Calibrator a LWDAQ Tool
#
# Copyright (C) 2023 Kevan Hashemi, Open Source Instruments Inc.
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
# CPMS_Calibrator_init initializes the tool's configuration and information arrays.
#
proc CPMS_Calibrator_init {} {
	upvar #0 CPMS_Calibrator_info info
	upvar #0 CPMS_Calibrator_config config
	
	LWDAQ_tool_init "CPMS_Calibrator" "2.2"
	if {[winfo exists $info(window)]} {return ""}

	set config(cam_left) "12.675 39.312 1.1 0.0 0.0 2 26.0 0.0" 
	set config(mount_left) "92.123 -18.364 -3.450 \
		83.853 -18.211 -78.940 \
		125.201 -17.747 -71.806"
	set config(coord_left) [lwdaq scam_coord_from_mount $config(mount_left)]
	set config(cam_right) "12.675 -39.312 1.1 0.0 0.0 2 26.0 3141.6" 
	set config(mount_right) "-77.819 -20.395 -2.397 \
		-74.201 -20.179 -75.451 \
		-115.549 -20.643 -68.317"
	set config(coord_right) [lwdaq scam_coord_from_mount $config(mount_right)]

	set config(bodies) [list \
		"20.231 19.192 506.194 0 0 0 sphere 0 0 0 38.068" \
		"20.017 19.275 466.169 0 0 0 sphere 0 0 0 38.068" \
		"19.861 19.319 436.169 0 0 0 sphere 0 0 0 38.073" \
		"19.693 19.371 406.173 0 0 0 sphere 0 0 0 38.072"]

	set config(scaling) "1 1 10 10 10 0 1 10"

	set config(fit_steps) "1000"
	set config(fit_restarts) "0"
	set config(num_lines) "200"
	set config(stop_fit) "0"
	set config(zoom) "0.5"
	set config(intensify) "exact"
	set config(threshold) "10 %"
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
#  CPMS_Calibrator_read_files attempts to read eight image 
#
proc CPMS_Calibrator_read_files {{img_dir ""}} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	if {$info(state) != "Idle"} {return ""}
	set info(state) "Reading"
	LWDAQ_update
	
	if {$img_dir == ""} {set img_dir [LWDAQ_get_dir_name]}
	if {$img_dir == ""} {return ""} {set config(img_dir) $img_dir}
	
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
	
	set info(state) "Idle"
}

proc CPMS_Calibrator_get_params {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set params "$config(cam_left) $config(cam_right)"
	return $params
}

proc CPMS_Calibrator_go {{params ""}} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info
	upvar #0 LWDAQ_config_BCAM iconfig
	upvar #0 LWDAQ_info_BCAM iinfo

	if {![winfo exists $info(window)]} {
		error "Cannot draw CPMS images: no CPMS window open."
	}

	if {$params == ""} {set params [CPMS_Calibrator_get_params]}
	set scam_left "SCAM_left [lrange $params 0 7]"
	set scam_right "SCAM_left [lrange $params 8 15]"
	
	set disagreement 0
	set a 1
	foreach body $config(bodies) {

		foreach side {left right} {
			lwdaq_image_manipulate img_$side\_$a none -clear 1			
			lwdaq_scam img_$side\_$a project \
				$config(coord_$side) scam_$side $body $config(num_lines)
		}
		
		set left_count [lwdaq_scam img_left_$a disagreement $config(threshold)]
		set right_count [lwdaq_scam img_right_$a disagreement $config(threshold)]
		set disagreement [expr $disagreement + $left_count + $right_count]

		lwdaq_draw img_left_$a photo_left_$a \
			-intensify $config(intensify) -zoom $config(zoom)
		lwdaq_draw img_right_$a photo_right_$a \
			-intensify $config(intensify) -zoom $config(zoom)
			
		incr a
	}
	
	return $disagreement
}

proc CPMS_Calibrator_altitude {params} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	if {$config(stop_fit)} {error "Fit aborted by user"}
	if {![winfo exists $info(window)]} {error "Tool window destroyed"}
	set count [CPMS_Calibrator_go "$params"]
	LWDAQ_update
	return $count
}

proc CPMS_Calibrator_fit {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set config(stop_fit) 0
	set info(state) "Fitting"
	
	if {[catch {
		set config(coord_left) [lwdaq scam_coord_from_mount $config(mount_left)]
		set config(coord_right) [lwdaq scam_coord_from_mount $config(mount_right)]
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

	CPMS_Calibrator_go
	set info(state) "Idle"
}

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

proc CPMS_Calibrator_open {} {
	upvar #0 CPMS_Calibrator_config config
	upvar #0 CPMS_Calibrator_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return ""}
	
	set f [frame $w.controls]
	pack $f -side top -fill x
	
	label $f.state -textvariable CPMS_Calibrator_info(state) -fg blue
	pack $f.state -side left -expand yes

	button $f.clear -text "Clear" -command {CPMS_Calibrator_clear}
	pack $f.clear -side left -expand yes
	
	button $f.go -text "Go" -command {CPMS_Calibrator_go 
		set count [CPMS_Calibrator_go]
		LWDAQ_print $CPMS_Calibrator_info(text) \
			"$CPMS_Calibrator_config(cam_left)\
			$CPMS_Calibrator_config(cam_right)\
			[format %.0f $count]"
	}
	button $f.fit -text "Fit" -command {CPMS_Calibrator_fit}
	button $f.stop -text "Stop" -command {set CPMS_Calibrator_config(stop_fit) 1}
	pack $f.go $f.fit $f.stop -side left -expand yes
	
	button $f.rdf -text "ReadFiles" -command {CPMS_Calibrator_read_files}
	pack $f.rdf -side left -expand yes

	foreach a {threshold} {
		label $f.l$a -text "$a\:"
		entry $f.e$a -textvariable CPMS_Calibrator_config($a) -width 6
		pack $f.l$a $f.e$a -side left -expand yes
	}
	
	button $f.projector -text "Adjustor" -command {CPMS_Calibrator_adjustor}
	pack $f.projector -side left -expand yes 

	foreach a {Help Configure} {
		set b [string tolower $a]
		button $f.$b -text $a -command "LWDAQ_tool_$b $info(name)"
		pack $f.$b -side left -expand 1
	}

	set f [frame $w.parameters]
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

	set f [frame $w.bodies]
	pack $f -side top -fill x

	label $f.lbody -text "bodies:"
	entry $f.ebody -textvariable CPMS_Calibrator_config(bodies) -width 160
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
CPMS_Calibrator_read_files $CPMS_Calibrator_config(img_dir)
	
return ""

----------Begin Help----------

The Contactless Position Measurement System (CPMS) Calibrator takes a series of
silhouette images of the same sphere in various positions as measured by a Coordinate
Measuring Machine (CMM) and deduces the calibration constants of a pair of Silhouette Cameras (SCAMs). 

----------End Help----------

----------Begin Data----------

----------End Data----------