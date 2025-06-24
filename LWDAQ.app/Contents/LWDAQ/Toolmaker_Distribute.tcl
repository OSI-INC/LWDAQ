<script>
#
# A LWDAQ Toolmaker Script with a button that initiates the capture of multiple
# images from the BCAM Instrument. The routine assumes the BCAM Instrument is
# configured to obtain an image in which two light sources are visible. We
# configure the BCAM to look for two spots and to sort them in order of
# increasing x-coordinate. This sorting is effective when the two spots are
# separated horizontally in the image. The routine analyzes each image to obtain
# the x and y position of both spots. The number of images it captures is set by
# a parameter in an entry box in the Toolmaker execution window. Once it has
# captured the requested number of images, the routine calculates the average x
# and y positions and prints them to the Toolmaker execution window. The script
# illustrates the use of "upvar" commands to refer to the instrument
# configuration and information arrays within a Tcl procedure. Within the
# procedure we refer to the config and info arrays as config and info. We also
# see global declarations for the Toolmaker text window variable, "t", and a the
# number of images variable. The script illustrates how to create buttons and
# entry boxes in a Toolmaker script so that they appear in the execution window.
# We see the button posting the acquisition command to the LWDAQ event queue.
#

# Create a button and entry box in the Toolmaker execution window. These widgets
# will go in the Toolmaker execution window's widget frame, which has global
# name "f". The button itself, when pressed, does not immediatly initiate
# acquisition, but instead posts the request for the averaging acquisition to
# the LWDAQ event queue. Posting to the queue stops the button press from
# interrupting and breaking a data acquisition that is already in progress.
button $f.button -text "BCAM_Average" -command "LWDAQ_post BCAM_Average"
pack $f.button -side left
label $f.nil -text "Number:" 
entry $f.nie -textvariable BCAM_Average_num_images 
pack $f.nil $f.nie -side left
set BCAM_Average_num_images 10

# This is the averaging procedure that gets called by the button press.
proc BCAM_Average {} {

	# We must declare global variables. Here we illustrate how a routine like
	# this, which acquires from an instrument, should declare the existence
	# of the global BCAM info and config arrays: using upvar commands. These
	# arrays will then be available with shorter names in the script.
	upvar #0 LWDAQ_info_$name info
	upvar #0 LWDAQ_config_$name config
	global BCAM_Average_num_images
	global t
	
    # Check the number of images requested and save locally.
    set num_images $BCAM_Average_num_images
    if {$num_images <= 0} {
    	LWDAQ_print $t "ERROR: Cannot capture and analyze \"$num_images\" images."
    	return ""
    }

	# Initialize the position variables.
    set sum_x1 0
    set sum_y1 0
    set sum_x2 0
    set sum_y2 0
    
	# Configure the BCAM Instrument.
	set config(num_spots) "2"
	set config(sort_code) "2"
    
	# Capture and analyze the requested number of images.
    for {set i 0} {$i < $num_images} {incr i} {
    
        # Acquire an image using the BCAM Instrument
        set result [LWDAQ_acquire BCAM]

        # Parse the result to get x and y positions of the two spots. Here we
        # are using the lassign command to assign the elements of the result
        # list to the x1, y1, x2, and y2 variables. We use underscores as dummy
        # variable names to skip over the elements of the BCAM result string
        # that we don't need.
        lassign $result _ x1 y1 _ _ _ _ x2 y2 _ _ _ _

        # Accumulate the x and y positions
        set sum_x1 [expr $sum_x1 + $x1]
        set sum_y1 [expr $sum_y1 + $y1]
        set sum_x2 [expr $sum_x2 + $x2]
        set sum_y2 [expr $sum_y2 + $y2]
    }

    # Calculate the average x and y positions for each spot
    set avg_x1 [format %.2f [expr $sum_x1 / $num_images]]
    set avg_y1 [format %.2f [expr $sum_y1 / $num_images]]
    set avg_x2 [format %.2f [expr $sum_x2 / $num_images]]
    set avg_y2 [format %.2f [expr $sum_y2 / $num_images]]

    # Print the average positions in the Toolmaker text window
    LWDAQ_print $t "$avg_x1 $avg_y1 $avg_x2 $avg_y2" purple
    
    # Return an empty string.
    return ""
}
</script>

<script>
#
# A LWDAQ Toolmaker Script that calls the WPS instrument and obtains
# measurements for a range of exposure times (values of daq_flash_seconds). The
# exposure time, the position of the wire, and the rotation of the wire are
# printed to the script output window during execution. You can watch the WPS
# activity by opening the WPS Instrument. When the script is done, you can copy
# the results from the output window and into a spreadsheet. 
#
for {set x 0.01} {$x <= 0.3} {set x [expr $x * 1.1]} {
	set LWDAQ_config_WPS(daq_flash_seconds) $x
	LWDAQ_print $t \
	"[format {%.3f} $x] \
	 [lrange [LWDAQ_acquire WPS] 1 2]"
}
</script>

<script>
# 
# A LWDAQ Toolmaker Script that measures byte_write instruction execution time.
#
while {[winfo exists $f]} {
set sock [LWDAQ_socket_open 10.0.0.37]
set ta [clock microseconds]
for {set j 0} {$j < 100} {incr j} {
  for {set i 0} {$i < 1000} {incr i} {
    LWDAQ_byte_write $sock 0 $j
  }
  LWDAQ_wait_for_driver $sock
}
set tb [clock microseconds]
LWDAQ_socket_close $sock
LWDAQ_print $t [expr ($tb-$ta)/100000]
LWDAQ_update
}
</script>

<script>
#
# A LWDAQ Toolmaker Script that measures the instruction execution time, ram
# delete speed, and ram read and TCPIP transfer speed combined by instructing
# the relay to perform numdels ram delete instructions, each deleting delsize
# bytes in ram, and after that to read one block of readsize bytes from the
# relay ram. The script makes a button that you press to start the test. The IP
# address is hard-wired in the code.
#
global p
set p(t) $t
set p(delsize) 1000
set p(numdels) 100
set p(readsize) 1000000

button $f.do -text Do -command "do"
pack $f.do -side left
foreach a {numdels delsize readsize} {
	label $f.l$a -text $a
	entry $f.e$a -textvariable p($a)
	pack $f.l$a $f.e$a -side left
}

proc do {} {
	global p
	set sock [LWDAQ_socket_open 10.0.0.37:90]
	LWDAQ_print $p(t) "Software Version [LWDAQ_software_version $sock]"
	LWDAQ_print $p(t) "numdels = $p(numdels),\
		delsize = $p(delsize), readsize = $p(readsize)"
	LWDAQ_print $p(t) "START ram_delete"
	set ta [clock microseconds]
	for {set j 0} {$j < $p(numdels)} {incr j} {
		LWDAQ_ram_delete $sock 0 $p(delsize) 0
		if {[expr fmod($j,100)] == 0} {LWDAQ_wait_for_driver $sock}
	}
	LWDAQ_wait_for_driver $sock
	set tb [clock microseconds]
	LWDAQ_print $p(t) "DONE in [format %.2f [expr ($tb - $ta)/1000.0]] ms,\
		[format %.2f [expr 0.001*($tb-$ta)/$p(numdels)]] ms/delete,\
		[format %.2f [expr 1.0*($tb-$ta)/$p(numdels)/$p(delsize)]] us/byte"
	LWDAQ_print $p(t) "START LWDAQ_ram_read"
	LWDAQ_update
	set ta [clock microseconds]
	set data [LWDAQ_ram_read $sock 0 $p(readsize)]
	set tb [clock microseconds]
	LWDAQ_print $p(t) "DONE in [format %.2f [expr ($tb - $ta)/1000.0]] ms,\
		[format %.2f [expr $p(readsize)*1.0/($tb-$ta)*1000]] kBytes/s."
	LWDAQ_socket_close $sock
}
</script>

<script>
#
# A LWDAQ Toolmaker Script that tests the fast adc8 job on the LWDAQ driver.
# First we use the fast adc job to get some data. We must feed the signal into
# socket 1 on the driver.
#
set sock [LWDAQ_socket_open 10.0.0.37:90]
LWDAQ_set_driver_mux $sock 1 15
LWDAQ_byte_write $sock $LWDAQ_Driver(clen_addr) 0
LWDAQ_set_data_addr $sock 0
LWDAQ_set_delay_seconds $sock 0.1
LWDAQ_execute_job $sock $LWDAQ_Driver(fast_adc_job)
LWDAQ_byte_write $sock $LWDAQ_Driver(clen_addr) 1
set data [LWDAQ_ram_read $sock 0 1000]
LWDAQ_socket_close $sock

# Determine the amplitude and average value.
LWDAQ_print $t "Read [string length $data] samples."
binary scan $data c* values
set data ""
foreach v $values {
	if {$v<0} {set v [expr 256 + $v]}
	append data "$v "
}
LWDAQ_print $t [lwdaq ave_stdev $data]

# Split the binary array into a sequence of x-y values
# we can plot.
set plot_points ""
set x 0
foreach v $data {
	append plot_points "$x $v "
	incr x
}

# Create graphical widgets to display the plot.
lwdaq_image_create -width 1000 -height 200 -name plot_image
image create photo plot_photo
label $f.plot -image plot_photo 
pack $f.plot -side top

# Plot the points in an image and draw the image on the screen.
lwdaq_graph $plot_points plot_image -fill 1 -y_max 255 -y_min 0
lwdaq_draw plot_image plot_photo
</script>

<script>
#
# A LWDAQ Toolmaker Script that writes a simulated BCAM image to the memory on a
# LWDAQ driver. Read it back out again multiple times and check where the
# simulated spot is in the returned image. This code looks for write and
# read-back errors.
#
button $f.a -text Acquire -command "acquire $dim $addr $base none $t"
pack $f.a -side left
button $f.s -text Stop -command "set stop 1"
pack $f.s -side left
button $f.r -text Refresh -command [list LWDAQ_post [list setup $dim $addr $base]]
pack $f.r -side left

set dim 256
set stop 0
set addr 129.64.37.44
set base 00E00000

proc setup {dim addr base} {
	set sock [LWDAQ_socket_open $addr]
	LWDAQ_set_base_addr_hex $sock $base
	LWDAQ_ram_delete $sock 0 [expr $dim * $dim] 0
	LWDAQ_ram_delete $sock [expr round(($dim+1)*$dim/2)] 1 255
	LWDAQ_wait_for_driver $sock
	LWDAQ_socket_close $sock
}

proc acquire {dim addr base last t} {
	global stop
	if {$stop} {
		set stop 0
		return
	}
	set sock [LWDAQ_socket_open $addr]
	LWDAQ_set_base_addr_hex $sock $base
	set data [LWDAQ_ram_read $sock 0 [expr $dim * $dim]]
	LWDAQ_socket_close $sock
	set image_name [lwdaq_image_create -data $data -name Camera_Test]
	upvar LWDAQ_config_BCAM config
	set config(image_source) memory
	set config(memory_name) $image_name
	set config(intensify) none
	set config(zoom) 1
	set config(daq_image_width) $dim
	set config(daq_image_height) $dim
	set result [LWDAQ_acquire BCAM]
	if {$last != $result} {
		LWDAQ_print $t $result
	}
	LWDAQ_post [list acquire $dim $addr $base $result $t]
}

setup $dim $addr $base
</script>

<script>
# 
# A LWDAQ Toolmaker Script that tests a driver's LWDAQ server for resistance to
# a message that is longer than its incoming message buffer. When the buffer
# overflows, the driver must close the socket and return to its rest state.
#

# Open the socket and create a button that will close the socket.
set sock [LWDAQ_socket_open "10.0.0.37:90"]
button $f.close \
	-text "Close Socket Now" \
	-command "LWDAQ_socket_close $sock"
pack $f.close
LWDAQ_update

# Create a long string.
set s ""
for {set i 1} {$i < 2000} {incr i} {append s "A"}
LWDAQ_print $t "Sending message with $i bytes in content."

# Transmit the string through the socket. The message ID of 0 is the version
# read identifier. After passing the redundant long string as the message
# content, we expect the server to return its software version number.
LWDAQ_transmit_message $sock 0 $s
LWDAQ_print $t [LWDAQ_receive_integer $sock]

# Close the socket: we are done.
LWDAQ_socket_close $sock
</script>

<script>
#
# A LWDAQ Toolmaker Script that writes a gray-scale image to LWDAQ server's RAM,
# reading back the same image, and displays to the Toolmaker window, as well as
# printing the download data download speed.
#
frame $f.f
pack $f.f -side top
button $f.f.a -text Acquire -command "acquire $t"
button $f.f.s -text Stop -command "set stop 1"
label $f.f.ol -text Offset:
entry $f.f.oe -textvariable offset
pack $f.f.a $f.f.s $f.f.ol $f.f.oe -side left
catch {image create photo data_photo}
label $f.il -image data_photo
pack $f.il

set width 1000
set offset 0
set stop 0

proc acquire {t} {
	global stop offset width
	if {$stop || ![winfo exists $t]} {
		set stop 0
		return
	}
	
	set addr 10.0.0.37:90
	set sock [LWDAQ_socket_open $addr]

	LWDAQ_print $t "Creating gray-scale image $width x $width\
		at offset $offset..."
	LWDAQ_update
	for {set j 0} {$j < $width} {incr j} {
		LWDAQ_ram_delete $sock [expr $j*$width + $offset] \
			$width [expr round(256.0*$j/$width-0.5)]
	}
	LWDAQ_wait_for_driver $sock

	LWDAQ_print $t "Downloading image..."
	LWDAQ_update
	set ta [clock microseconds]
	set data [LWDAQ_ram_read $sock $offset [expr $width*$width]]
	set tb [clock microseconds]
	LWDAQ_print $t "Downloaded at\
		[format %.2f [expr $width*$width*1.0/($tb-$ta)*1000]] kBytes/s."

	LWDAQ_socket_close $sock

	LWDAQ_print $t "Displaying image..."
	LWDAQ_update
	lwdaq_image_create -name data_image \
		-width $width -height $width -data $data
	lwdaq_draw data_image data_photo -zoom 0.25 -intensify none
	
	LWDAQ_post [list acquire $t]
}
</script>

<script>
#
# A LWDAQ Toolmaker Script that tests a LWDAQ Driver's RAM by writing bytes to
# random locations and reading them back. To write to each location, we set the
# data address, write a byte to the RAM portal, set the data address again
# (because it will have been incremented by the write to the portal) and read
# back the byte. We compare the byte we wrote to the one we read back. 
#
button $f.a -text Acquire -command "acquire $t"
pack $f.a -side top
button $f.s -text Stop -command "set stop 1"
pack $f.s -side top
set stop 0

proc acquire {t} {
	global stop
	if {$stop || ![winfo exists $t]} {
		set stop 0
		return
	}
	
	set ip_addr 10.0.0.37:90
	set max_addr 8000000
	set num 1000
	
	LWDAQ_print $t "Testing $num locations..."
	LWDAQ_update
	set count 0
	set sock [LWDAQ_socket_open $ip_addr]
	for {set j 0} {$j < $num} {incr j} {
		set addr [expr round(rand()*$max_addr)]
		set value [expr round(rand()*255)]
		LWDAQ_set_data_addr $sock $addr
		LWDAQ_byte_write $sock 63 $value
		LWDAQ_set_data_addr $sock $addr
		set read_value [LWDAQ_byte_read $sock 63]
		if {$read_value<0} {set read_value [expr 256+$read_value]}
		if {$value == $read_value} {
			incr count
		} {
			LWDAQ_print $t "ERROR: Wrote $value, read $read_value, at address $addr."
			LWDAQ_update
		}
		if {$stop} {break}
	}
	LWDAQ_socket_close $sock

	LWDAQ_print $t "SCORE: $count out of $num"
	LWDAQ_post [list acquire $t]
}
</script>

<script>
#
# A LWDAQ Toolmaker Script that demonstrates the LWDAQ command-line simplex
# fitter. We define an altitude function and call the fitter with a starting
# point. The fitter returns with the coordinates of the point in the fitting
# space at which the altitude function is a minimum.
#
proc altitude {u v w x y z} {
  set uu 10
  set vv 20
  set ww 30
  set xx 40
  set yy 50
  set zz 60
  LWDAQ_support
  return [expr ($x-$xx)*($x-$xx) + ($y-$yy)*($y-$yy) \
    + ($z-$zz)*($z-$zz) \
    + ($u-$uu)*($u-$uu) + ($v-$vv)*($v-$vv) + ($w-$ww)*($w-$ww)]
}

set minimum [lwdaq_simplex "0 0 0 0 0 0" altitude]
LWDAQ_print $t $minimum
</script>

<script>
#
# A LWDAQ Toolmaker Script that sets up an instrument so that when we click on
# an image pixel with the mouse, its column and row is printed to the instrument
# text window. In instruments where the analysis_pixel_size_um parameter is
# defined, we calculate the image coordinates of the mouse click as well.
#
set instrument BCAM

bind .[string tolower $instrument].ic.i.image <Button-1> \
	[list image_point $instrument %x %y]

proc image_point {instrument x y} {
  upvar LWDAQ_config_$instrument config
  upvar LWDAQ_info_$instrument info
  set x_offset 3
  set y_offset 3

  LWDAQ_print -nonewline $info(text) "$instrument\
    [expr ($x-$x_offset) / $info(zoom)]\
    [expr ($y-$y_offset) / $info(zoom)]"
  if {[info exists info(analysis_pixel_size_um)]} {
    LWDAQ_print $info(text) "\
    [expr $info(analysis_pixel_size_um) * ($x-$x_offset) / $info(zoom)]\
    [expr $info(analysis_pixel_size_um) * ($y-$y_offset) / $info(zoom)]"
  } else {
    LWDAQ_print $info(text) ""
  }
}
</script>

<script>
#
# A Template LWDAQ Toolmaker Script that repeats a LWDAQ messaging job over and
# over to permit us to test the behavior of various LWDAQ Relays. Insert your
# own test procedure in the "go" routine. We use a global "p" array to handle
# starting and stopping the procedure.
#
global p
set p(t) $t
set p(location) 19
set p(control) Idle
button $f.go -text Go -command "go"
button $f.stop -text Stop -command "stop"
label $f.control -textvariable p(control)
pack $f.go $f.stop $f.control -side left

# The go procedure executes in a while loop until we press the stop button. In
# our example, we open a socket and repeatedly read back the firmware version
# number until it's time to stop, then we close the socket. We include the
# LWDAQ_support routine so that we can receive and respond to mouse and keyboard
# events. One such event will cause the control variable to be set to Stop.
proc go {} {
  global p
  set p(control) "Run"
  set sock [LWDAQ_socket_open 10.0.0.37]
  while {$p(control)!="Stop"} {
    set fv [LWDAQ_firmware_version $sock]
    LWDAQ_support
  }
  LWDAQ_socket_close $sock
  set p(control) "Idle"
}

# The stop procedure, which will be executed when we press the stop button. Note
# that we must have LWDAQ_support or some equivalent Tcl update command in the
# go loop for our mouse click on the stop button to be effective.
proc stop {} {
  global p
  set p(control) "Stop"
}
</script>

<script>
#
# A LWDAQ Toolmaker Script that send a sequence of LWDAQ commands to a device
# repeatedly after pressing Transmit. Stop with stop button. List the commands
# in hex format.
#
set p(commands) "0001 0000 AA02"
set p(text) $t
set p(ip_addr) "10.0.0.37"
set p(driver_socket) 8
set p(mux_socket) 1
set p(stop) 0
button $f.transmit -text Transmit -command Transmit
entry $f.commands -textvariable p(commands) -width 60
button $f.stop -text Stop -command {set p(stop) 1}
pack $f.transmit $f.commands $f.stop -side left -expand yes
proc Transmit {} {
  global p
  set sock [LWDAQ_socket_open $p(ip_addr)]
  LWDAQ_set_driver_mux $sock $p(driver_socket) $p(mux_socket)
  while {!$p(stop)} {
    foreach c $p(commands) {
      LWDAQ_transmit_command_hex $sock $c
    }
    LWDAQ_wait_for_driver $sock
  }
  LWDAQ_socket_close $sock
  set p(stop) 0
}
</script>

<script>
#
# A LWDAQ Toolmaker Script that uses every instrument analysis procedure to
# analyze every image in the Images directory. We use this script to check our
# error handling. If LWDAQ crashes during the execution, we know we have a bug
# in the analysis library.
#
global LWDAQ_Info
set fl [glob [file join $LWDAQ_Info(program_dir) Images *]]
foreach i $LWDAQ_Info(instruments) {
	LWDAQ_update
	LWDAQ_print $t $i purple
	LWDAQ_print ~/analysis_log.txt $i
	foreach fn $fl {
		set image_name [LWDAQ_read_image_file $fn]
		set result "[file tail $fn] [LWDAQ_analysis_$i $image_name]"
		LWDAQ_print $t $result
		LWDAQ_print ~/analysis_log.txt $result
		lwdaq_image_destroy $image_name
	}
}
</script>

<script>
#
# A LWDAQ Toolmaker Script that illustrates the use of our database package,
# searching through our Devices.xml file for devices with part number A3038 and
# customer name "Natalia", then listing them.
#
package require DB
set devices [DB_read]
set devices [DB_get_list $devices device]
set count 0
foreach d $devices {
	set sn [DB_get_list $d sn]
	set pn [DB_get_list $d pn]
	set c [DB_get_list $d c]
	if {[regexp {A3038} $pn] && [regexp {Natalia} $c]} {
		LWDAQ_print $t "$sn $pn \"[lindex $c 0]\""
		incr count
	}
}
LWDAQ_print $t "Found $count matching devices."
</script>

<script>
#
# A LWDAQ Toolmaker Script that aligns a circular survey targets with the field
# of view of a BCAM. The script opens a canvas widget in the Toolmaker execution
# window. It draws the BCAM image photo in the canvas widget and a red circle on
# top of that. Whenever the BCAM instrument updates its bcam_photo, the same
# canvas widget re-draws the photo in the canvas widget.
#
canvas $f.survey -width 400 -height 400 -bd 2 -relief solid
pack $f.survey
$f.survey create image 200 200 -image bcam_photo
$f.survey create oval 130 130 250 250 -outline red
</script>



