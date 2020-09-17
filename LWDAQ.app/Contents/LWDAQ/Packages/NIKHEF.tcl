# Long-Wire Data Acquisition Software (LWDAQ)
# Copyright (C) 2017 Pierre-Francois Giraud
# Copyright (C) 2004-2017 Kevan Hashemi, Brandeis University
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

package provide NIKHEF 1.0


# We need to load the HTTP routines to access the NIKHEF analysis server.
package require http

# Configure the Rasnik instrument to work with the Scalay system.
LWDAQ_set_image_sensor ICX424 Rasnik
set LWDAQ_info_Rasnik(daq_source_device_type) 6
set LWDAQ_config_Rasnik(daq_ip_addr) 10.0.0.37
set LWDAQ_config_Rasnik(daq_driver_socket) 1
set LWDAQ_config_Rasnik(daq_flash_seconds) 0.1
set LWDAQ_config_Rasnik(analysis_square_size_um) 220
set LWDAQ_config_Rasnik(intensify) none

#
# PFG 2017-12-19
# Send image data to the nikhef SOAP analysis server (assumed to run on
# localhost:8081) and return rasnik analysis result string
#
proc LWDAQ_analysis_Rasnik_Nikhef {{image_name}} {
  upvar #0 LWDAQ_config_Rasnik config
  upvar #0 LWDAQ_info_Rasnik info
  set binary_pixels [lwdaq_image_contents $image_name]
  set url "http://localhost:8081/analRaw" ;# Should be configurable?

  # Default values for nin and fin (many are not used, historical)
  set nin {21 13 0 0 0 9 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0}
  set fin {0.0074 0.0074 4.66 3.54 5.0 0.17 0.17 40.0 10.0 875.0 89.0 72.0 161.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0}

  # Set pixel size
  lset fin 0  [expr 0.001 * $info(analysis_pixel_size_um)]
  lset fin 1  [expr 0.001 * $info(analysis_pixel_size_um)]

  # Set mask pitch
  lset fin 5  [expr 0.001 * $config(analysis_square_size_um)]
  lset fin 6  [expr 0.001 * $config(analysis_square_size_um)]

  # Set image size
  set bounds [lwdaq_image_characteristics $image_name]
  set i_size [lindex $bounds 9]
  set j_size [lindex $bounds 8]
  lset nin 3 $i_size
  lset nin 4 $j_size
  lset fin 2 [expr $i_size * [lindex $fin 0] ]
  lset fin 3 [expr $j_size * [lindex $fin 1] ]

  # Set orientation flags
  if {$config(analysis_orientation_code) == 2} {
    lset nin 8 1
  } elseif {$config(analysis_orientation_code) == 3} {
    lset nin 7 1
  } elseif {$config(analysis_orientation_code) == 4} {
    lset nin 7 1
    lset nin 8 1
  }

  if {[expr $i_size * $j_size] != [string length $binary_pixels]} {
    return "ERROR invalid initial binary array size"
  }

  # Append to payload the nin and fin arrays, formatted in binary
  append binary_pixels [binary format i32 $nin]
  append binary_pixels [binary format f32 $fin]

  if {[expr $i_size * $j_size + 256] != [string length $binary_pixels]} {
    return "ERROR invalid final binary array size"
  }

  set token [::http::geturl $url -query $binary_pixels]

  set code [::http::ncode $token]
  if { $code != 200 } {
    return "ERROR invalid response from server"
  }

  return [::http::data $token]
}

#
# Re-define the LWDAQ_analysis_Rasnik routine so that it provides the NIKHEF
# analysis when we set analysis_enable to 100+.
#
proc LWDAQ_analysis_Rasnik {{image_name ""}} {
	upvar #0 LWDAQ_config_Rasnik config
	upvar #0 LWDAQ_info_Rasnik info

	if {$image_name == ""} {set image_name $config(memory_name)}
	if {$info(analysis_show_fitting) != 0} {
		lwdaq_config -wait_ms $info(analysis_show_fitting)
		if {$info(analysis_show_fitting) == -1} {
			set info(control) "Acquire"
		}
	}
	
	switch $config(analysis_reference_code) {
		1 {
			# Specify the center of the analysis bounds.
			set ic [lwdaq_image_characteristics $image_name]
			set ref_x [expr ([lindex $ic 0] + [lindex $ic 2]) \
				/ 2.0 * $info(analysis_pixel_size_um)]
			set ref_y [expr ([lindex $ic 1] + [lindex $ic 3]) \
				/ 2.0 * $info(analysis_pixel_size_um)]
		}
		2 {
			# Specify the center of the image sensor.
			set ic [lwdaq_image_characteristics $image_name]
			set ref_x [expr [lindex $ic 9] / 2.0 * $info(analysis_pixel_size_um)]
			set ref_y [expr [lindex $ic 8] / 2.0 * $info(analysis_pixel_size_um)]
		}
		3 {
			# Specify our own point in image coordinates. The origin
			# of image coordinates is the top-left corner of the top-left
			# pixel, with x going left to right and y going top to bottom.
			set ref_x $info(analysis_reference_x_um)
			set ref_y $info(analysis_reference_y_um)
		}
		default {
			# By default we use the top-left corner of the image sensor,
			# which is the origin of image coordinates.
			set ref_x 0.0
			set ref_y 0.0
		}
	} 

	set analysis_type [expr $config(analysis_enable) % 10]
	set analysis_do_foam [expr $config(analysis_enable) / 100]

	# PFG 2017-12-19
	# Run the FOAM analysis on this image
	if {$analysis_do_foam != 0} {
	    set foamresult [LWDAQ_analysis_Rasnik_Nikhef $image_name]
	    set foamresult " : FOAM $foamresult"
	}

	if {$analysis_type == 0} {
	  if {$analysis_do_foam == 0} {
	    return ""
	  } else {
	    return "$foamresult ::"
	  }
	}

	set img $image_name	
	set shrink [expr $config(analysis_enable) % 100 / 10]
	if {$shrink >= 1} {
		set img [lwdaq_image_manipulate $img smooth -replace 0]
	}
	if {$shrink == 1} {
		lwdaq_image_manipulate $img smooth -replace 1
	}
	if {$shrink > 1} {
		lwdaq_image_manipulate $img shrink_$shrink -replace 1
		set pixel_size [expr $shrink * $info(analysis_pixel_size_um)]
		set zoom [expr $shrink * $info(zoom)]
	} {
		set pixel_size $info(analysis_pixel_size_um)
		set zoom $info(zoom)
	}
	lwdaq_config -zoom $zoom -intensify $config(intensify)
	
	if {abs($info(analysis_rotation_mrad))>1570.8} {
		return "ERROR: Analysis rotation greater than 1570.8 mrad (90 deg) limit."
	}
	
	scan [lwdaq_image_characteristics $img] "%d %d %d %d" left top right bottom
	set done 0
	set info(analysis_index_tries) 0
	while {!$done && ($analysis_type != 0)} {
		incr info(analysis_index_tries)
		set result [lwdaq_rasnik $img \
			-show_fitting $info(analysis_show_fitting) \
			-show_timing $info(analysis_show_timing) \
			-orientation_code $config(analysis_orientation_code) \
			-pixel_size_um $pixel_size \
			-reference_x_um $ref_x \
			-reference_y_um $ref_y \
			-square_size_um $config(analysis_square_size_um) \
			-rotation_mrad $info(analysis_rotation_mrad) \
			-pattern_only $info(analysis_pattern_only)]
		if {![LWDAQ_is_error_result $result]} {
			scan $result "%f %f %f %f" x y mag_x mag_y
			set error_message ""
			if {[string is integer -strict $info(analysis_max_pos_um)]} {
				if {$x > $info(analysis_max_pos_um)} {
					append error_message "x>$info(analysis_max_pos_um) "
				}
				if {$y > $info(analysis_max_pos_um)} {
					append error_message "y>$info(analysis_max_pos_um) "
				}
			}
			if {[string is double -strict $info(analysis_max_mag_ratio)]} {
				if {$mag_y == 0} {
					append error_message "mag_y=0 "
				} {
					set mag_ratio [expr $mag_x / $mag_y]
					if {$mag_ratio > $info(analysis_max_mag_ratio)} {
						append error_message "mag_x/mag_y>$info(analysis_max_mag_ratio) "
					}
					if {$mag_ratio < [expr 1 / $info(analysis_max_mag_ratio)]} {
						append error_message "mag_y/mag_x>$info(analysis_max_mag_ratio) "
					}
				}
			}
			if {$error_message != ""} {
				set result "ERROR: $error_message"
			}
		}
		if {![LWDAQ_is_error_result $result]} {
			set done 1
		} {
			if {($info(analysis_index_tries) < $info(analysis_max_tries)) \
					&& ($analysis_type >= 2)
					&& ($info(control) != "Stop")} {
				if {[winfo exists $info(window)] && ($analysis_type == 3)} {
					lwdaq_draw $img $info(photo) -intensify $config(intensify) -zoom $zoom
				}
				LWDAQ_update
				set min $info(analysis_min_width)
				if {[expr $right-$left]>$min} {
					set width [expr $min+round(rand()*($right-$left-$min))]
				} {
					set width [expr $right-$left]
				}
				if {[expr $bottom-$top]>$min} {
					set height [expr $min+round(rand()*($bottom-$top-$min))]
				} {
					set height [expr $bottom-$top]
				}
				set new_left [expr $left+round(rand()*($right-$left-$width))]
				set new_right [expr $new_left+$width]
				set new_top [expr $top+round(rand()*($bottom-$top-$height))]
				set new_bottom [expr $new_top+$height]
				lwdaq_image_manipulate $img none \
					-left $new_left -top $new_top -right $new_right -bottom $new_bottom
			} {
				set done 1
			}
		}
	}
	
	if {[LWDAQ_is_error_result $result]} {
		lwdaq_image_manipulate $img none -left $left -top $top -right $right -bottom $bottom
		if {[winfo exists $info(window)] && ($analysis_type == 3)} {
			lwdaq_draw $img $info(photo) -intensify $config(intensify) -zoom $zoom
			LWDAQ_update
		}
	}
	
	if {$img != $image_name} {
		lwdaq_image_manipulate $image_name transfer_overlay $img
		lwdaq_image_destroy $img
	}

	# PFG 2017-12-19
	# Pre-pend the FOAM results to the general result output
	if {$analysis_do_foam != 0} {
	  set result "$foamresult : LWDAQ $result ::"
	}

	return $result
}


