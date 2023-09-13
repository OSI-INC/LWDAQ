# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2004-2021 Kevan Hashemi, Brandeis University
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
# Viewer.tcl defines the Viewer instrument.
#

#
# LWDAQ_init_Viewer creates all elements of the Viewer instrument's config and
# info arrays.
#
proc LWDAQ_init_Viewer {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Viewer info
	upvar #0 LWDAQ_config_Viewer config
	
	array unset config
	array unset info
	
	set info(name) "Viewer"
	set info(control) "Idle"
	set info(window) [string tolower .$info(name)]
	set info(text) $info(window).text
	set info(photo) [string tolower $info(name)\_photo]
	set info(select) 0
	set info(counter) 0 
	set info(zoom) 1.0
	set info(daq_extended) 0
	set info(delete_old_images) 1
	set info(file_use_daq_bounds) 0
	set info(daq_image_width) 344
	set info(daq_image_height) 244
	set info(daq_image_left) -1
	set info(daq_image_right) -1
	set info(daq_image_top) -1
	set info(daq_image_bottom) -1
	set info(daq_min_width) 4
	set info(image_results) ""
	set info(verbose_description) \
		"{Image Height} {Image Width} \
		{Bounds Left} {Bounds Top} {Bounds Right} {Bounds Bottom} \
		{Results String}"
	
	set config(image_source) "Rasnik"
	set config(analysis_source) "Camera"
	set config(file_name) ./Images/\*
	set config(memory_name) lwdaq_image_1
	set config(intensify) exact
	set config(analysis_enable) 1
	set config(verbose_result) 0
	set config(closeup_width) 40
	set config(closeup_height) 40
	
	return ""
}


#
# LWDAQ_daq_Viewer is a dummy procedure for the standard aquire button. 
#
proc LWDAQ_daq_Viewer {} {
	return "ERROR: The Viewer does not have its own data acquisition procedure."
} 

#
# LWDAQ_analysis_Viewer calls the analysis of another instrument to analyze an
# image in the Viewer panel. If report is set, the routine draws the image in
# the Viewer panel and writes the results of analysis to the text window.
#
proc LWDAQ_analysis_Viewer {{img ""} {report 0}} {
	global LWDAQ_Info
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info

	# Identify the instrument we should use to obtain our analysis routine.
	set instrument $config(analysis_source)
	if {[lsearch $LWDAQ_Info(instruments) $instrument] < 0} {
		return "ERROR: No such instrument \"$instrument\"."
	}
	if {$instrument == "Viewer"} {
		return "ERROR: The Viewer does not have its own analysis procedure."
	}
	upvar #0 LWDAQ_config_$instrument iconfig
	upvar #0 LWDAQ_info_$instrument iinfo

	# Check that the image exists. We use the local image by default.
	if {$img == ""} {set img $config(memory_name)}
	if {[lwdaq_image_exists $img] == ""} {
		return "ERROR: Image \"$img\" does not exist."	
	}
	
	# Apply the analysis bounds if the use daq bounds flag is set.
	if {$info(file_use_daq_bounds)} {
		lwdaq_image_manipulate $img none \
			-left $info(daq_image_left) \
			-top $info(daq_image_top) \
			-right $info(daq_image_right) \
			-bottom $info(daq_image_bottom) \
			-clear 1
	}

	# Set the instrument's image name to the Viewer's image name and analyze.
	# set our result string to the result of analysis.
	set saved $iconfig(memory_name)
	set iconfig(memory_name) $img
	set result [LWDAQ_analysis_$instrument]
	if {![LWDAQ_is_error_result $result]} {set result [lrange $result 1 end]}
	set iconfig(memory_name) $saved
	
	# If the report flag is set, draw the analyzed image in the Viewer panel.
 	if {$report} {
		lwdaq_draw $img $info(photo) -intensify $config(intensify) -zoom $info(zoom)
		LWDAQ_print -nonewline $info(text) "$instrument: " darkgreen
		LWDAQ_print $info(text) $result	
	}	
	set info(image_results) [lwdaq_image_results $img]
	set info(verbose_description) $iinfo(verbose_description)

	return $result
}

#
# LWDAQ_DAQ_to_GIF_Viewer opens a browser in which you select multiple DAQ image
# files, and converts them to GIF files, writing them into the same directory
# with suffix ".gif".
#
proc LWDAQ_DAQ_to_GIF_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	
	if {$info(control) != "Idle"} {return ""}
	set info(control) "Convert"
	set file_list [lsort -dictionary [LWDAQ_get_file_name 1]]
	set num [llength $file_list]
	set index 1
	foreach f $file_list {
		set tail [file tail $f]
		set dir [file dirname $f]
		set gif [file rootname $tail].gif 
		if {$info(delete_old_images)} {lwdaq_image_destroy $info(name)\*}
		incr info(counter)
		set config(memory_name) [LWDAQ_read_image_file $f $info(name)\_$info(counter)]
		LWDAQ_write_image_file $config(memory_name) [file join $dir $gif]
		LWDAQ_print $info(text) "$index of $num\: Created $gif."	
		incr index
		if {$info(control)=="Stop"} {break}
	}
	set info(control) "Idle"
	return ""
}

#
# LWDAQ_GIF_to_DAQ_Viewer opens a browser in which you select multiple GIF image
# files, and converts them to DAQ files, writing them into the same directory
# with suffix ".daq".
#
proc LWDAQ_GIF_to_DAQ_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	
	if {$info(control) != "Idle"} {return ""}
	set info(control) "Convert"
	set file_list [lsort -dictionary [LWDAQ_get_file_name 1]]
	set num [llength $file_list]
	set index 1
	foreach f $file_list {
		set tail [file tail $f]
		set dir [file dirname $f]
		set daq [file rootname $tail].daq 
		if {$info(delete_old_images)} {lwdaq_image_destroy $info(name)\*}
		incr info(counter)
		set config(memory_name) [LWDAQ_read_image_file $f $info(name)\_$info(counter)]
		LWDAQ_write_image_file $config(memory_name) [file join $dir $daq]
		LWDAQ_print $info(text) "$index of $num\: Created $daq."			
		incr index
		if {$info(control)=="Stop"} {break}
	}
	set info(control) "Idle"
	return ""
}

#
# LWDAQ_set_bounds_Viewer applies the Viewer's DAQ bounds to its local image and
# re-draws in the Viewer panel.
#
proc LWDAQ_set_bounds_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	
	# Check the image exists.
	set img $config(memory_name)
	if {[lwdaq_image_exists $img] == ""} {
		LWDAQ_print $info(text) "ERROR: Image \"$img\" does not exist."
		return ""
	}

	# Select new bounds.
	set left $info(daq_image_left)
	set top $info(daq_image_top)
	set right $info(daq_image_right)
	set bottom $info(daq_image_bottom)
	
	# Change the image boundaries and draw in the Viewer.
	lwdaq_image_manipulate $img none \
		-left $left -top $top -right $right -bottom $bottom -clear 1
	lwdaq_draw $img $info(photo) -intensify $config(intensify) -zoom $info(zoom)
	
	# Return empty string.
	return ""
}

#
# LWDAQ_crop_Viewer crops the Viewer's image to its analysis bounds and draws 
# it in the Viewer panel. 
#
proc LWDAQ_crop_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	
	# Check the image exists.
	set img $config(memory_name)
	if {[lwdaq_image_exists $img] == ""} {
		LWDAQ_print $info(text) "ERROR: Image \"$img\" does not exist."
		return ""
	}

	# Crop the image and draw in the Viewer.
	lwdaq_image_manipulate $img crop -replace 1
	lwdaq_draw $img $info(photo) -intensify $config(intensify) -zoom $info(zoom)
	
	# Return empty string.
	return ""
}

#
# LWDAQ_set_dimensions_Viewer creates a new image with dimensions specified in
# the dimension control boxes. The analysis boundaries remain the same. We 
# draw the new image in the Viewer panel. If our default is to delete old Viewer
# images, we do so.
#
proc LWDAQ_set_dimensions_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	
	# Check the image exists.
	set img $config(memory_name)
	if {[lwdaq_image_exists $img] == ""} {
		LWDAQ_print $info(text) "ERROR: Image \"$img\" does not exist."
		return ""
	}

	# Make a copy with same contents but new dimensions for drawing.	
	set data [lwdaq_image_contents $img]
	set stats [lwdaq_image_characteristics $img]
	set results [lwdaq_image_results $img]
	incr info(counter)
	if {$info(delete_old_images)} {lwdaq_image_destroy $info(name)\*}
	set img [lwdaq_image_create \
		-width $info(daq_image_width) \
		-height $info(daq_image_height) \
		-left [lindex $stats 0] \
		-top [lindex $stats 1] \
		-right [lindex $stats 2] \
		-bottom [lindex $stats 3] \
		-data $data \
		-results $results \
		-name "$info(name)\_$info(counter)"]
		
	# Draw the new image.
	lwdaq_draw $img $info(photo) -intensify $config(intensify) -zoom $info(zoom)
	
	# Assign the new image to be the local image.
	set config(memory_name) $img
		
	return ""
}

#
# LWDAQ_set_results_Viewer sets the results string of the local image. 
#
proc LWDAQ_set_results_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	
	# Check the image exists.
	set img $config(memory_name)
	if {[lwdaq_image_exists $img] == ""} {
		LWDAQ_print $info(text) "ERROR: Image \"$img\" does not exist."
		return ""
	}
	
	# Set the results string and draw the updated image array. The results
	# will now be stored in the first row.
	lwdaq_image_manipulate $img none -results $info(image_results)
	lwdaq_draw $img $info(photo) -intensify $config(intensify) -zoom $info(zoom)
	
	# Issue warning if the results have been curtailed.
	set results [lwdaq_image_results $img]
	if {[string length $info(image_results)] > [string length $results]} {
		LWDAQ_print $info(text) "WARNING: Only \"$results\" fits in header."
	}
	
	# We print the new result string, so as to show if it has been curtailed.
	
	return ""
}

#
# LWDAQ_zoom_Viewer re-draws the image in the panel with the latest zoom setting.
#
proc LWDAQ_zoom_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	
	# Check the image exists.
	set img $config(memory_name)
	if {[lwdaq_image_exists $img] == ""} {
		LWDAQ_print $info(text) "ERROR: Image \"$img\" does not exist."
		return ""
	}
	
	# Draw with zoom.
	if {[winfo exists $info(window)]} {
		lwdaq_draw $img $info(photo) -intensify $config(intensify) -zoom $info(zoom)
	}
	
	return ""
}

#
# LWDAQ_xy_Viewer takes as input an x-y position relative to the top-left corner
# of the image display widget. By passing one of three commands, it sets the
# corners of the analysis boundaries. The motion command adjusts the
# bottom-right corner. The press command sets the top-left corner. The release
# command sets the image analysis bounds with the rectangle drawn. We bind 
# this routine to the image widget and remove the binding that exists in all other
# instruments to the image closeup routine. 
#
proc LWDAQ_xy_Viewer {x y cmd} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	
	# Get the image column and row.
	set zoom [expr 1.0 * $info(zoom) * [LWDAQ_get_lwdaq_config display_zoom]]
	set xi [expr round(1.0*($x - 4)/$zoom)] 
	set yi [expr round(1.0*($y - 4)/$zoom)]

	# Update corners of analysis bounds if we are moving.
	if {$cmd == "Motion"} {
		if {$info(select)} {
			if {$xi > $info(corner_x)} {
				set info(daq_image_right) $xi
				set info(daq_image_left) $info(corner_x)
			} 
			if {$xi < $info(corner_x)} {
				set info(daq_image_left) $xi
				set info(daq_image_right) $info(corner_x)
			} 
			if {$yi > $info(corner_y)} {
				set info(daq_image_bottom) $yi
				set info(daq_image_top) $info(corner_y)
			} 
			if {$yi < $info(corner_y)} {
				set info(daq_image_top) $yi
				set info(daq_image_bottom) $info(corner_y)
			} 
			LWDAQ_set_bounds_Viewer
		}
	}
	
	# Start a rectangle by dropping one corner on the image.
	if {$cmd == "Press"} {
		set info(select) 1
		set info(corner_x) $xi
		set info(corner_y) $yi
		set info(daq_image_left) $info(corner_x)
		set info(daq_image_top) $info(corner_y)
		set info(daq_image_right) [expr $info(daq_image_left) + 1]
		set info(daq_image_bottom) [expr $info(daq_image_top) + 1]
		LWDAQ_set_bounds_Viewer
	}
	
	# Complete and apply a rectangle.
	if {$cmd == "Release"} {
		set info(select) 0
		if {($info(daq_image_right)-$info(daq_image_left) < $info(daq_min_width)) \
			&& ($info(daq_image_bottom)-$info(daq_image_top) < $info(daq_min_width))} {
			set info(daq_image_right) [expr $info(daq_image_left) + $info(daq_min_width)]
			set info(daq_image_bottom) [expr $info(daq_image_top) + $info(daq_min_width)]
		}
		LWDAQ_set_bounds_Viewer
	}
	
	return ""
}

#
# LWDAQ_controls_Viewer creates secial controls for the Viewer instrument.
#
proc LWDAQ_controls_Viewer {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info

	set w $info(window)
	if {![winfo exists $w]} {return ""}

	set f $w.row1
	frame $f
	pack $f -side top -fill x
	
	# Crop an image to its existing bounds, set the bounds to a new
	# rectangle, and enable over-riding the bounds written in a file
	# header in favor of the bounds in our entry boxes.
	button $f.crop -text "Crop" -command LWDAQ_crop_Viewer
	pack $f.crop -side left
	button $f.setb -text "Set Bounds" -command LWDAQ_set_bounds_Viewer
	pack $f.setb -side left
	foreach l {left top right bottom} {
		label $f.l$l -text $l\: -width [string length $l]
		entry $f.e$l -textvariable LWDAQ_info_Viewer(daq_image_$l) \
			-width 4
		pack $f.l$l $f.e$l -side left -expand 1
	}
	checkbutton $f.ofb -text "file_use_daq_bounds" \
		-variable LWDAQ_info_Viewer(file_use_daq_bounds)
	pack $f.ofb -side left -expand 1
	
	set f $w.row2
	frame $f
	pack $f -side top -fill x

	# Change the dimensions of the image and re-draw with the Resize button.	
	button $f.setd -text "Resize" -command LWDAQ_set_dimensions_Viewer
	pack $f.setd -side left
	foreach l {width height} {
		label $f.l$l -text $l\: -width [string length $l]
		entry $f.e$l -textvariable LWDAQ_info_Viewer(daq_image_$l) -width 6
		pack $f.l$l $f.e$l -side left -expand 1
	}

	# These bindings allow us to change the analysis boundaries with the mouse.	
	bind $info(image_display) <Motion> {LWDAQ_xy_Viewer %x %y Motion}
	bind $info(image_display) <ButtonPress> {LWDAQ_xy_Viewer %x %y Press}
	bind $info(image_display) <ButtonRelease> {LWDAQ_xy_Viewer %x %y Release}
	
	# Delete the default double-press binding that give us pixel detail.
	bind $info(image_display) <Double-ButtonPress> ""

	# Analyze and zoom buttons that re-analyze and re-draw the image. Provide
	# buttons to convert between DAQ and GIF.
	button $f.analyze -text "Analyze" -command {LWDAQ_analysis_Viewer "" 1}
	pack $f.analyze -side left
	button $f.bzoom -text "Zoom" -command LWDAQ_zoom_Viewer 
	entry $f.ezoom -textvariable LWDAQ_info_Viewer(zoom) -width 3
	pack $f.bzoom $f.ezoom -side left -expand 1
	foreach a {"DAQ_to_GIF" "GIF_to_DAQ"} {
		set b [string tolower $a]
		button $f.$b -text $a -command \
			[list LWDAQ_post LWDAQ_$a\_Viewer front]
		pack $f.$b -side left -expand 1
	}	

	# Manipulate the results string.
	set f $w.row3
	frame $f
	pack $f -side top -fill x
	button $f.setr -text "Set Results" -command \
		LWDAQ_set_results_Viewer
	pack $f.setr -side left
	entry $f.results -textvariable LWDAQ_info_Viewer(image_results) -width 80
	pack $f.results -side left
	
	# Return an empty string to show all is well.
	return ""
}

