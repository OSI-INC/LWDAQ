acquisifier:
name: Initialize
post_processing: {
	set config(run_result) "[clock seconds] "
	LWDAQ_print $info(text) "Results will be stored in \"$config(run_results)\"."
}
config:
end.

default:
name: BCAM_Defaults
instrument: BCAM
default_post_processing: {
	if {![LWDAQ_is_error_result $result]} {
		append config(run_result) " [lrange $result 1 2]"
	} {
		append config(run_result) " -1 -1"
	}
}
post_processing: {
	upvar #0 The_Global_Array var
	set var(message) "Defined and set global variable The_Global_Array."
	set var(time) [clock seconds]
	LWDAQ_print $info(text) $var(message)
}
config:
	image_source daq
	analysis_num_spots 2
	daq_adjust_flash 1
	daq_ip_addr 129.64.37.79
	daq_source_ip_addr *
	ambient_exposure_seconds 0
end.

default:
name: Rasnik_Defaults
instrument: Rasnik
default_post_processing: {
	if {![LWDAQ_is_error_result $result]} {
		append config(run_result) " [lrange $result 1 2]"
	} {
		append config(run_result) " -1 -1"
	}
	if {[string is integer -strict $metadata]} {
		incr metadata
		LWDAQ_print $info(text) "Metadata counter = $metadata"
	}
}
config:
	daq_ip_addr 129.64.37.79
	daq_source_ip_addr *
	intensify exact
	analysis_square_size_um 120
	daq_mux_socket 1
	daq_device_type 2
	daq_source_device_type 1
end.

default:
name: Thermometer_Defaults
instrument: Thermometer
default_post_processing: {
	if {![LWDAQ_is_error_result $result]} {
		append config(run_result) " [lrange $result 1 2]"
	} {
		append config(run_result) " -100 -100"
	}
}
config:
	image_source daq
	analysis_enable 1
	daq_ip_addr 129.64.37.79
	daq_mux_socket 1
end.

acquire:
name: Thermometer_1
instrument: Thermometer
result: None
disable: 0
config:
	daq_driver_socket 4
	daq_device_element "1 2"
	daq_device_name A2053
end.

acquire:
name: Thermometer_2
instrument: Thermometer
result: None
disable: 1
post_processing: {
	error "Testing error-handling."
}
config:
	daq_driver_socket 4
	daq_device_element "3 4"
	daq_device_name A2053
end.

acquire:
name: BCAM_1_2
instrument: BCAM
result: None
config:
	daq_flash_seconds 0.001
	daq_driver_socket 5
	daq_device_element 2
	daq_source_device_element "3 4"
	daq_source_driver_socket 8
end.

acquire:
name: Rasnik_1
instrument: Rasnik
result: None
post_processing: {
	upvar #0 The_Global_Array var
	LWDAQ_print $info(text) "The global array's time element is $var(time)"
}
config:
	daq_flash_seconds 0.01
	daq_driver_socket 6
	daq_device_element 2
	daq_source_device_element 1
	daq_source_driver_socket 7
end.

acquire:
name: BCAM_2_1
instrument: BCAM
result: None
time: 0
config:
	daq_flash_seconds 0
	daq_driver_socket 8
	daq_device_element 2
	daq_source_device_element "3 4"
	daq_source_driver_socket 5
end.

# This step writes the Rasnik image to the same folder as the run results file
# using post-processing.
acquire:
name: Rasnik_2
instrument: Rasnik
result: None
metadata: 0
post_processing: {
	set fn [file join [file dirname $config(run_results)] $name\.gif]
	LWDAQ_write_image_file $iconfig(memory_name) $fn
}
config:
	daq_flash_seconds 0.001
	daq_driver_socket 6
	daq_device_element 2
	daq_source_device_element 1
	daq_source_driver_socket 7
end.

acquire:
name: Power_Cycle
instrument: Diagnostic
result: None
config:
	daq_actions "off 500 on 100"
	daq_psc 1
end.

acquisifier:
screen_text: "This is a custom field value called screen_text."
post_processing: {
# We print the custom field value to the screen.
  LWDAQ_print $info(text) [Acquisifier_get_param $info(step) screen_text]
}
config:
end.

acquisifier:
name: Finalize
post_processing: {
	LWDAQ_print $config(run_results) $config(run_result)
	LWDAQ_print $info(text) "$config(run_result)" blue
}
config:
end.


