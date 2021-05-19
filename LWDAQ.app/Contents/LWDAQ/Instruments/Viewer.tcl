# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2004-2021 Kevan Hashemi, Brandeis University
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
# Viewer.tcl defines the Viewer instrument.
#

#
# LWDAQ_init_Viewer creates all elements of the Viewer instrument's
# config and info arrays.
#
proc LWDAQ_init_Viewer {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_info_Viewer info
	upvar #0 LWDAQ_config_Viewer config
	array unset config
	array unset info
	
	# The info array elements will not be displayed in the 
	# instrument window. The only info variables set in the 
	# LWDAQ_open_Instrument procedure are those which are checked
	# only when the instrument window is open.
	set info(name) "Viewer"
	set info(control) "Idle"
	set info(window) [string tolower .$info(name)]
	set info(text) $info(window).text
	set info(photo) [string tolower $info(name)\_photo]
	set info(x) "0"
	set info(y) "0"
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
	set info(verbose_description) " {Image Height} {Image Width} \
		{Bounds Left} {Bounds Top} {Bounds Right} {Bounds Bottom} \
		{Results String}"
	
	# All elements of the config array will be displayed in the
	# instrument window. No config array variables can be set in the
	# LWDAQ_open_Instrument procedure
	set config(image_source) "Rasnik"
	set config(analysis_source) "Camera"
	set config(file_name) ./Images/\*
	set config(memory_name) lwdaq_image_1
	set config(intensify) exact
	set config(analysis_enable) 1
	set config(verbose_result) 0
	
	return 1
}


#
# LWDAQ_daq_Viewer is a dummy procedure for the standard aquire button. 
#
proc LWDAQ_daq_Viewer {} {
	return "ERROR: The Viewer does not have its own data acquisition procedure."
} 

#
# LWDAQ_analysis_Viewer calls the analysis of another instrument to analyze
# the image in the Viewer panel.
#
proc LWDAQ_analysis_Viewer {{image_name ""} {report 0}} {
	global LWDAQ_Info
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info

	set instrument $config(analysis_source)
	if {[lsearch $LWDAQ_Info(instruments) $instrument] < 0} {
		return "ERROR: No such instrument \"$instrument\"."
	}
	if {$instrument == "Viewer"} {
		return "ERROR: The Viewer does not have its own analysis procedure."
	}
	upvar #0 LWDAQ_config_$instrument iconfig
	upvar #0 LWDAQ_info_$instrument iinfo

	if {$image_name == ""} {
		set image_name $config(memory_name)
	}
	if {[lwdaq_image_exists $image_name] == ""} {
		return "ERROR: Image \"$config(memory_name)\" does not exist."	
	}
	
	if {$info(file_use_daq_bounds)} {
		lwdaq_image_manipulate $image_name none \
			-left $info(daq_image_left) \
			-top $info(daq_image_top) \
			-right $info(daq_image_right) \
			-bottom $info(daq_image_bottom) \
			-clear 1
	}

	set iconfig(memory_name) $image_name
	set result [LWDAQ_instrument_analyze $instrument]
	if {![LWDAQ_is_error_result $result]} {
		set result [lrange $result 1 end]
	}
 	if {$report} {
		lwdaq_draw $config(memory_name) $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
		LWDAQ_print -nonewline $info(text) "$instrument: " darkgreen
		LWDAQ_print $info(text) $result	
	}	
	set info(image_results) [lwdaq_image_results $config(memory_name)]

	set info(verbose_description) $iinfo(verbose_description)

	return $result
}

#
#
#
proc LWDAQ_crop_Viewer {{image_name ""}} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	if {$image_name == ""} {
		set image_name $config(memory_name)
	}
	if {[lwdaq_image_exists $image_name] == ""} {
		return "ERROR: Image \"$config(memory_name)\" does not exist."	
	}
	lwdaq_image_manipulate $image_name crop -replace 1
	lwdaq_draw $image_name $info(photo) \
		-intensify $config(intensify) -zoom $info(zoom)
}

#
# LWDAQ_DAQ_to_GIF_Viewer opens a browser in which you select
# multiple DAQ image files, and converts them to GIF files, writing
# them into the same directory with suffix ".gif".
#
proc LWDAQ_DAQ_to_GIF_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	if {$info(control) != "Idle"} {return 0}
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
	return 1
}

#
# LWDAQ_GIF_to_DAQ_Viewer opens a browser in which you select
# multiple GIF image files, and converts them to DAQ files, writing
# them into the same directory with suffix ".daq".
#
proc LWDAQ_GIF_to_DAQ_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	if {$info(control) != "Idle"} {return 0}
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
	return 1
}

#
# LWDAQ_set_bounds_Viewer applies the analyisis boundaries
# specified in the viewer's info array to the image named by config
# memory_name.
#
proc LWDAQ_set_bounds_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	if {[lwdaq_image_exists $config(memory_name)] == ""} {
		LWDAQ_print $info(text) "ERROR: Image \"$config(memory_name)\" does not exist."
		return 0
	}
	lwdaq_image_manipulate $config(memory_name) none \
		-left $info(daq_image_left) \
		-top $info(daq_image_top) \
		-right $info(daq_image_right) \
		-bottom $info(daq_image_bottom) \
		-clear 1
	lwdaq_draw $config(memory_name) $info(photo) \
		-intensify $config(intensify) -zoom $info(zoom)
	return 1
}

#
# LWDAQ_set_dimensions_Viewer takes the contents of the image
# named by config(memory_name) and creates a new image with the
# dimensions specified in the dimension control boxes. The routine
# keeps the analysis boundaries the same.
#
proc LWDAQ_set_dimensions_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	if {[lwdaq_image_exists $config(memory_name)] == ""} {
		LWDAQ_print $info(text) "ERROR: Image \"$config(memory_name)\" does not exist."
		return 0
	}
	set data [lwdaq_image_contents $config(memory_name)]
	set stats [lwdaq_image_characteristics $config(memory_name)]
	set results [lwdaq_image_results $config(memory_name)]
	incr info(counter)
	if {$info(delete_old_images)} {lwdaq_image_destroy $info(name)\*}
	set config(memory_name) [lwdaq_image_create \
		-width $info(daq_image_width) \
		-height $info(daq_image_height) \
		-left [lindex $stats 0] \
		-top [lindex $stats 1] \
		-right [lindex $stats 2] \
		-bottom [lindex $stats 3] \
		-data $data \
		-results $results \
		-name "$info(name)\_$info(counter)"]
	lwdaq_draw $config(memory_name) $info(photo) \
		-intensify $config(intensify) -zoom $info(zoom)
	return 1
}

#
# LWDAQ_set_results_Viewer sets the results string of an image.
#
proc LWDAQ_set_results_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info
	if {[lwdaq_image_exists $config(memory_name)] == ""} {
		LWDAQ_print $info(text) "ERROR: Image \"$config(memory_name)\" does not exist."
		return 0
	}
	lwdaq_image_manipulate $config(memory_name) none \
		-results $info(image_results)
	lwdaq_draw $config(memory_name) $info(photo) \
		-intensify $config(intensify) -zoom $info(zoom)
	return 1
}

#
# LWDAQ_zoom_Viewer re-draws the image in the panel with the latest zoom setting.
#
proc LWDAQ_zoom_Viewer {} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info

	if {[winfo exists $info(window)]} {
		lwdaq_draw $config(memory_name) $info(photo) \
			-intensify $config(intensify) -zoom $info(zoom)
	}
}

#
# LWDAQ_xy_Viewer takes as input an x-y position relative to the top-left corner of
# the image display widget, and sets the info(x) and info(y) parameters with the columen
# and row of the image pixel displayed at that display widget position.
#
proc LWDAQ_xy_Viewer {x y cmd} {
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info

	set info(x) [expr round(1.0*($x - 4)/$info(zoom))] 
	set info(y) [expr round(1.0*($y - 4)/$info(zoom))]

	if {$cmd == "Motion"} {
		if {$info(select)} {
			if {$info(x) > $info(corner_x)} {
				set info(daq_image_right) $info(x)
				set info(daq_image_left) $info(corner_x)
			} 
			if {$info(x) < $info(corner_x)} {
				set info(daq_image_left) $info(x)
				set info(daq_image_right) $info(corner_x)
			} 
			if {$info(y) > $info(corner_y)} {
				set info(daq_image_bottom) $info(y)
				set info(daq_image_top) $info(corner_y)
			} 
			if {$info(y) < $info(corner_y)} {
				set info(daq_image_top) $info(y)
				set info(daq_image_bottom) $info(corner_y)
			} 
			LWDAQ_set_bounds_Viewer
		}
	}
	
	if {$cmd == "Press"} {
		set info(select) 1
		set info(corner_x) $info(x)
		set info(corner_y) $info(y)
		set info(daq_image_left) $info(corner_x)
		set info(daq_image_top) $info(corner_y)
		set info(daq_image_right) [expr $info(daq_image_left) + 1]
		set info(daq_image_bottom) [expr $info(daq_image_top) + 1]
		LWDAQ_set_bounds_Viewer
	}
	
	if {$cmd == "Release"} {
		set info(select) 0
		if {($info(daq_image_right)-$info(daq_image_left) < $info(daq_min_width)) \
			&& ($info(daq_image_bottom)-$info(daq_image_top) < $info(daq_min_width))} {
			set info(daq_image_right) [expr $info(daq_image_left) + $info(daq_min_width)]
			set info(daq_image_bottom) [expr $info(daq_image_top) + $info(daq_min_width)]
		}
		LWDAQ_set_bounds_Viewer
	}
}

#
# LWDAQ_controls_Viewer creates secial controls for the 
# Viewer instrument.
#
proc LWDAQ_controls_Viewer {} {
	global LWDAQ_Info LWDAQ_Driver
	upvar #0 LWDAQ_config_Viewer config
	upvar #0 LWDAQ_info_Viewer info

	set w $info(window)
	if {![winfo exists $w]} {return 0}

	set f $w.row1
	frame $f
	pack $f -side top -fill x
	
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
	
	checkbutton $f.fudb -text "Use These Bounds" -variable LWDAQ_info_Viewer(file_use_daq_bounds)
	pack $f.fudb -side left -expand 1
	
	set f $w.row2
	frame $f
	pack $f -side top -fill x
	
	button $f.setd -text "Set Size" -command \
		LWDAQ_set_dimensions_Viewer
	pack $f.setd -side left
	foreach l {width height} {
		label $f.l$l -text $l\: -width [string length $l]
		entry $f.e$l -textvariable LWDAQ_info_Viewer(daq_image_$l) \
			-width 4
		pack $f.l$l $f.e$l -side left -expand 1
	}
	
	foreach a {x y} {
		label $f.cursorl$a -text "[string toupper $a]:"
		label $f.cursor$a -textvariable LWDAQ_info_Viewer($a) -width 4 -fg black
		pack $f.cursorl$a $f.cursor$a -side left -expand 1
	}
	bind $info(image_display) <Motion> {LWDAQ_xy_Viewer %x %y Motion}
	bind $info(image_display) <ButtonPress> {LWDAQ_xy_Viewer %x %y Press}
	bind $info(image_display) <ButtonRelease> {LWDAQ_xy_Viewer %x %y Release}

	button $f.analyze -text "Analyze" -command {LWDAQ_analysis_Viewer "" 1}
	pack $f.analyze -side left

	button $f.bzoom -text "Zoom" -command LWDAQ_zoom_Viewer 
	entry $f.ezoom -textvariable LWDAQ_info_Viewer(zoom) -width 3
	pack $f.bzoom $f.ezoom -side left -expand 1

	set f $w.row3
	frame $f
	pack $f -side top -fill x

	button $f.setr -text "Set Results" -command \
		LWDAQ_set_results_Viewer
	pack $f.setr -side left
	entry $f.results -textvariable LWDAQ_info_Viewer(image_results) -width 40
	pack $f.results -side left
	foreach a {"DAQ_to_GIF" "GIF_to_DAQ"} {
		set b [string tolower $a]
		button $f.$b -text $a -command \
			[list LWDAQ_post LWDAQ_$a\_Viewer front]
		pack $f.$b -side left -expand 1
	}	
}

