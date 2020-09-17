# Configurator, a Standard and Polite LWDAQ Tool
# Copyright (C) 2020, Rebecca Rogers, Brandeis University 
# Copyright (C) 2020, Kevan Hashemi, Brandeis University 
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

#Creates a window for the tutorial and a title for the window 

proc LWDAQ_Tutorial_init {} {
	upvar #0 LWDAQ_Tutorial_info info
	upvar #0 LWDAQ_Tutorial_config config
	global LWDAQ_Info LWDAQ_Drive

	LWDAQ_tool_init "LWDAQ_Tutorial" "1.0"
	if {[winfo exists $info(window)]} {return 0}
	
	if {[file exists $info(settings_file_name)]} {
		uplevel #0 [list source $info(settings_file_name)]
	} 


	return 1   
}


#A Proc that opens the tutorial, sets a frame, creates a text widget within the window. 
#Also prints onto the window screen a basic introduction to the tutorial and 
#how it works. 

proc LWDAQ_Tutorial_open {} {
	upvar #0 LWDAQ_Tutorial_config config
	upvar #0 LWDAQ_Tutorial_info info

	set w [LWDAQ_tool_open $info(name)]
	if {$w == ""} {return 0}
	
	set f $w.controls
	frame $f
	pack $f -side top -fill x

	set $info(text) [LWDAQ_text_widget $w 100 15]
	global t 
	set t $info(text) 
	 
	

	LWDAQ_print $info(text) "Welcome to the LWDAQ Tutorial!"
	LWDAQ_print $info(text) "This tutorial is designed to teach you the basic function of LWDAQ tools."
	LWDAQ_print $info(text) "To start, please click on the Diagnostic instrument as seen at the top of this screen "
	LWDAQ_print $info(text) "Below, you will find templates to writing your own acquisifier or toolmaker script

" 
#Sets certain parameters in the instruments to -1 and then creates buttons for 
#each of the instruments. When a button is pressed it calles a proc that opens
#the instrument. 


	foreach a {"Diagnostic" "BCAM" "Camera" "Rasnik" "Thermometer" } {
		set b [string tolower $a]
		upvar #0 LWDAQ_info_Diagnostic dinfo
		upvar #0 LWDAQ_config_Diagnostic dconfig
		upvar #0 LWDAQ_info_BCAM binfo
		upvar #0 LWDAQ_config_BCAM bconfig
		upvar #0 LWDAQ_info_Camera cinfo
		upvar #0 LWDAQ_config_Camera cconfig
		upvar #0 LWDAQ_info_Thermometer tinfo
		upvar #0 LWDAQ_config_Thermometer tconfig
		upvar #0 LWDAQ_info_Rasnik rinfo
		upvar #0 LWDAQ_config_Rasnik rconfig
				

		set dconfig(daq_ip_addr) "-1"
		set dconfig(daq_driver_socket) "-1"
		set dconfig(verbose_result) "-1" 
	
		set bconfig(daq_ip_addr) -1"
		set bconfig(analysis_num_spots)  "-1"
		set bconfig(analysis_threshold) "-1" 
		set bconfig(daq_driver_socket) "-1" 
		set bconfig(daq_source_driver_socket) "-1" 
		set bconfig(daq_subtract_background) "-1" 
		
		set cconfig(daq_ip_addr) "-1" 
		set cconfig(daq_exposure_seconds) "-1" 
		set cconfig(intensify) "-1" 

		set tconfig(daq_device_name) "-1"
		set tconfig(daq_device_element) "-1" 

		set rconfig(analysis_reference_code) "-1" 
		set rconfig(analysis_square_size_um) "-1" 
		

		button $f.$b -text $a -command "Tutorial_open $a" 
		pack $f.$b -side left -expand 1

	
		
	}
	
		set f $w.custom3
		frame $f
		pack $f -side top -fill x
		
#Creates buttons at the bottom of the window for templates for acquisifier
#and toolmaker. Creates new windows for the templates and prints onto them 
#the template texts. 

		label $f.templates -text "Templates:" 
		button $f.acquisifier -text "Acquisifier" \
			-command { template_script "Acquisifier" }
		button $f.tool -text "TCL Tool" \
			-command { template_script "Toolmaker" } 
		pack $f.templates $f.acquisifier $f.tool -side left -expand 1

		proc template_script {{src ""}} { 
			global LWDAQ_Info
			upvar #0 template_script_info info 
			set fn $src 
			set win [LWDAQ_toplevel_window]
			set fr [frame $win.bf]
			pack $fr -side top -fill x
			button $fr.save -text "Save" -command "save_template $win"
			button $fr.saveas -text "Save As" -command "saveAs_template $win" 
			pack $fr.save $fr.saveas -side left -expand yes
			set text [LWDAQ_text_widget $win 100 30 1 1]
			if {$fn == "Toolmaker"} {
				LWDAQ_print $text "\# Template, a Standard and Polite LWDAQ Tool
\# Copyright \(C\) 2004-2012 Kevan Hashemi, Brandeis University
\#
\# This program is free software; you can redistribute it and/or
\# modify it under the terms of the GNU General Public License
\# as published by the Free Software Foundation; either version 2
\# of the License, or (at your option) any later version.
\#
\# This program is distributed in the hope that it will be useful,
\# but WITHOUT ANY WARRANTY; without even the implied warranty of
\# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
\# GNU General Public License for more details.
\#
\# You should have received a copy of the GNU General Public License

\# along with this program; if not, write to the Free Software
\# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


proc Template_init \{\} \{
	upvar \#0 Template_info info
	upvar \#0 Template_config config
	global LWDAQ_Info LWDAQ_Driver
	
	LWDAQ_tool_init \"Template\" \"2.1\"
	if \{\[winfo exists \$info\(window\)\]\} \{return 0\}

	set config\(example_configuration_parameter\) example_parameter_value

	set info\(example_info_parameter\) example_parameter_value
	
	if \{\[file exists \$info\(settings_file_name\)\]\} \{
		uplevel \#0 \[list source \$info\(settings_file_name\)\]
	\} 

	return 1   
\}

proc Template_open \{\} \{
	upvar \#0 Template_config config
	upvar \#0 Template_info info

	set w \[LWDAQ_tool_open \$info\(name\)\]
	if \{\$w == \"\"\} \{return 0\}
	
	set f \$w.controls
	frame \$f
	pack \$f \-side top \-fill x
	
	foreach a \{Help Configure\} \{
		set b \[string tolower \$a]
		button \$f.\$b -text \$a -command \"LWDAQ_tool_\$b \$info\(name\)\"
		pack \$f.\$b -side left -expand 1
	\}

	set info\(text\) \[LWDAQ_text_widget \$w 100 15\]

	LWDAQ_print \$info\(text\) \"\$info\(name\) Version \$info\(version\) \n\"
	
	return 1
\}

Template_init
Template_open
	
return 1" 
			}
			if {$fn == "Acquisifier"} 	{
				LWDAQ_print $text "\#Acquisifier is a program that controls and acquires from the LWDAQ hardware. 
\#By using Acquisifier, the user can access multiple LWDAQ devices sequentially and then 
\#records their results onto a text file. To use acquisifier, the user must write an acquisifier 
\#script, which is to be uploaded to the Acquisifier tool. To access their script, the user must 
\#use the \"Browse\" button on the Acquisifier tool to find their script and then \"Load\" to upload
\#the script to the Acquisifer memory. As the Acquisifier tool goes through the script the user has
\#uploaded it will print out the acquisition at each step. 

\#The Acquisifier tool does utilize some TCL language, but overall has its own syntax which 
\#is detailed in this template. This template will give a basic overview on how to write
\#an Acquisifier script by setting up a script that acquires from the two BCAMs on the test
\#stand and then save them to a file on the users desktop. 

\#The Acquisifier tool has three types of steps, which are acquire, default and acquisifier. This 
\#step that is demonstrated below is an acquisifier step. The acquisifier step allows you 
\#to change configuration parameters within the Acquisifier tool itself, such as cycle_period_seconds.
\#This tool, through the post_processing piece of code, also sets a document for the results to be
\#stored, adds a time stamp to the result string and tells the user where the results will be 
\#stored. Post_processing in Acquisifier scripts utilizes TCL language and is utilized after the 
\#main function of the step. 

acquisifier\: 
name\: Initialize 
post_processing\: \{ 
	set config\(run_result\) \"\[clock seconds\] \"
	set config\(run_results\) \"\~\/Desktop\/Acquisifier\_example.txt\"
	LWDAQ_print \$info\(text\) \"Results wil be stored in \\\"\$config\(run_results\)\\\".\" 
\}
config\: 
	cycle_period_seconds 30 
end. 

\#The default step allows the user to declare shared parameters for multiple instruments. In this 
\#example, the two BCAMs the user is acquiring from share the same driver, hence it is more efficient 
\#to declare the driver IP address in default once than having to declare it in each acquire step. 
\#The default post_processing is for the user to specify which results out of the string of results
\#on the BCAM instrument that the user wants to save to their file. Here, the user wants to save 
\#the first two results in the string which are the x and y spot positions. 

default\: 
name\: BCAM_default 
instrument\: BCAM 
default_post_processing\: \{
	if \{\!\[LWDAQ_is_error_result \$result\]\} \{
		append config\(run_result\) \"\[lrange \$result 1 2 \] \"
	\} \{
		append config\(run_result\) \"-1 -1 \"
	\}
	LWDAQ_exec_Diagnostic sleep
\}
config\: 
	daq_ip_addr \"129.64.37.79\" 
end. 

\#The third step that is utilized in the Acquisifier scripts is acquire, which tells the 
\#Acquisifier tool which instrument to acquire from. In the config section, the user can specify 
\#parameters such as daq_driver_socket. Here the user is acquiring from two BCAMs and acquiring
\#once with the BCAM on socket 8 as the source, and then the second time when BCAM on socket 5 is 
\#the source. 

acquire\: 
name\: BCAM_acquire_1
instrument\: BCAM 
config\: 
	daq_driver_socket 5
	daq_source_driver_socket 8 
end. 

acquire\: 
name\: BCAM_acquire_2
instrument\: BCAM 
config\: 
	daq_driver_socket 8
	daq_source_driver_socket 5
end. 

\#At the end of the Acquisifier script, there is another post_processing field included in the 
\#acquisifier step. This post_processing step adds the results of the BCAM acquires to the text file 
\#and prints the results onto the Acquisifier instrument. 

acquisifier\:
name\: Finalize
post_processing: \{
	LWDAQ_print \$config\(run_results\) \$config\(run_result\)
	LWDAQ_print \$info\(text\) \"\$config(run_result)\" blue
\}
config\:
end." 
			}
		} 

#Save and save as functions on the templates. Opens a working directory and 
#saves the file to the working directory (which is usually the LWDAQ file). 

		proc save_template {{win ""}} {
			global LWDAQ_Info 
			upvar #0 template_script_info info 
			set fn "Script_Template" 
			if {[file dirname $fn] == "."} {
				set fn [file join $LWDAQ_Info(working_dir) $fn]
			}
			set script [string trim [$win.text get 1.0 end]]
			set fr [open $fn w]
			puts $fr $script
			close $fr
		}
		proc saveAs_template {{win ""}} {
			global LWDAQ_Info 
			upvar #0 template_script_info info 
			set fn [LWDAQ_put_file_name [file tail [wm title $win]]]
			set script [string trim [$win.text get 1.0 end]]
			set fr [open $fn w]
			puts $fr $script
			close $fr

	}
		

#Opens instrument when button is pressed. Prints text on LWDAQ Tutorial window 
#when the button for the instrument  is pressed, explains the instrument and the parameters.
	
	proc Tutorial_open {instrument} {
			 upvar #0 Tutorial_monitor minfo
			 upvar #0 LWDAQ_Tutorial_config config
			 upvar #0 LWDAQ_Tutorial_info info
    			 upvar LWDAQ_info_$instrument iinfo
			 upvar #0 LWDAQ_info_Diagnostic dinfo
			 upvar #0 LWDAQ_config_Diagnostic dconfig
        LWDAQ_open $instrument
        LWDAQ_print $iinfo(text) "Welcome to the $instrument instrument!"
			 set instrumentname "$instrument" 
			 if {$instrumentname == "Diagnostic"} 	{
					 LWDAQ_print $info(text) "Using the LWDAQ Tutorial, you will learn to fill in some of the more basic parameters for 
LWDAQ programs. 
Let's start with the parameter labeled daq_ip_address. Here you will 
enter the IP address of the LWDAQ Driver in your set up. By entering 
this IP address, you can speak to your driver over the internet from your 
laptop/desktop. For this tutorial, we will access the driver with IP address
129.64.37.79, which is the driver used for the Brandeis HEP test stand.

The second parameter you may fill in is daq_driver_socket. The LWDAQ 
Drivers have 8 sockets, each socket consists of a connector that is
used to connect the driver to various LWDAQ devices. When you fill in 
this parameter, you will be able to send commands to the device 
connected to the socket you have chosen. For this exercise, you can
enter any socket number from 1-8.

The last parameter to fill in is the verbose_result parameter. This only
has two entries, 0 or 1. The verbose result is helpful when starting with
LWDAQ as it allows you to see what results you are obtaining when you 
enter 1. LWDAQ programs will return a string of numbers as results if you enter 0. 
Now that all the parameters have been filled in, you may click the Acquire button. 

Now, you may click \"Acquire\" for information on the result string.

 " 
				
				
				}

			 if {$instrumentname == "BCAM"} {
					 LWDAQ_print $info(text) "This instrument is used to acquire 
information from the BCAM. In the Brandeis HEP test stand, there are two BCAMs 
looking at eachother. One BCAM will flash two lasers as the other BCAM
takes a picture.
  
The IP Address is the same as for the Diagnostic, as we are 
using the same driver in the test stand. Please fill this parameter in
as 129.64.37.79. 

Next, you should fill in the parameters for the driver sockets the 
two BCAMs are connected to. The parameter daq_driver_socket is the BCAM 
that takes the picture of the flashing BCAM. It is connected to socket 5.
The flashing BCAM is under the source parameters, so fill in the parameter 
daq_source_driver_socket for the flashing BCAM. It is connected to socket 8.

The next parameter to fill in is the analysis_num_spots. This tells the BCAM 
instrument how many light sources to look for. The BCAM on the stand only 
has two laser light sources, so this parameter you must enter 2. This parameter 
searches for bright spots on the CCD that are over a certain threshold of intensity. 

The threshold for intensity is set in the analysis_threshold. This sets the 
amount of counts above 0 that the program should look for when determining sources in
the image. This parameter should be filled with a number and a symbol. For BCAM analysis, 
this parameter should be filled with 10 # where # means ave + (max-ave)*p/100 where 
ave is the background average counts, max is the maximum counts in the image
and p is the integer you have chosen which is 10 for this case. You can also enter
p *, which would be the exact threshold of intensity you want. For more, please
consult the LWDAQ manual. 

The last parameter to fill in manually is daq_subtract_background. If this parameter
is set to 1, it will take two images, one with the lasers flashing and one without. 
It will then subtract the image with no lasers from the image without so that 
there is no ambient light in the image. When the parameter is set to 0, there will
be ambient light in the photo. You may set it to 0 for general BCAM acquiring.

Now, you may click \"Acquire\" for information on the result string.  
" 
			}

	if {$instrumentname == "Camera"} {
			LWDAQ_print $info(text) "There is a camera circuit in the 
Brandeis HEP test stand that looks out into the hallway at Brandeis. 
Once you fill in the parameters, you should be able to acquire and see 
an image of the Brandeis Physics Department basement. 

The first parameter to fill in is the daq_ip_address which is the driver in the 
test stand, with the ip address 129.64.37.79

Another important parameter for the camera instrument is daq_exposure_seconds. 
This is how long the CCD is exposed to light. If you take a picture with 1 second 
exposure vs .01 second exposure, there is a big difference. Play around with the values
when starting to use the camera instrument.

Now, you may click \"Acquire\" for information on the result string.
 " 
		
			}
		if {$instrumentname == "Rasnik"} {
				LWDAQ_print $info(text) "The Rasnik mask is a program that takes a picture of a 
image that uses chessboard pattern of which only a small portion is captured by the camera. 
By looking at the pattern on the CCD, the camera can determine which part of the Rasnik 
it is viewing. 

The first parameter to fill in is the analysis_square_size_um which is the 
size of the squares in the mask. The options are generally; 85, 120, 170 and 430 um. 
In this case, it is 120.

Another parameter to fill in is the analysis_reference_code which has four options; 0,
1, 2, 3. Each of the references to a point of analysis on the CCD. 0 is for a reference point
that is in the top left corner of the top left pixel. 1 is the center of the analysis bounds. 2 
is the center of the CCD. 3 is the specified x and y parameters found in the info. The 
default for the parameter is generally 0, but 2 is also commonly used since there the smallest 
effects of the rotation on the reference point.  

Now, you may click \"Acquire\" for information on the result string. 
 " 
			}

		if {$instrumentname == "Thermometer"} {
				LWDAQ_print $info(text) "The thermometer tool is used to detect the temperature 
of a surface using RTDs which are restistance temperature devices. The tool will read out 
the temperature detected by the RTDS. The amount of RTDs vary on the device that 
is used (such as a bar head)

The parameter to fill in is the daq_device_name which is the name of the device 
you are using. On the test stand, there is a Resistive Sensor Head, which is given the 
device name A2053.

The next parameter to fill in is the device element. The device element selects the sensors as 
well as the top and bottom reference resistors. To fill in this parameter we enter B for bottom, T
for top and the sensors we want. Usually, 1 2 3 4 is entered for the four sensors. The default for 
this parameter is B T 1 2 3 4, but enter any amount of sensors to start. 

Now, you may click \"Acquire\" for information on the result string. " 
			}
		}
	
	return 1
}

LWDAQ_Tutorial_init
LWDAQ_Tutorial_open
	


# Create a global variable array that we can use in our
# monitor routine, and indeed you will need one to manage
# your Tutorial program. In the code, notice the use of the
# set command to get the value of a variable, rather than
# to set the variable. We have to do this sometimes when
# the name of the variable we want the value of is itself
# being generated by the value of other variables. See the
# foreach loop where we record the current image name for
# each existing instrument in an array variable, but we
# get the instrument names from LWDAQ's list of instrument
# names. And then there is the backslash to say "this is
# the end of the name of the variable I want you to
# substitute into this line of text."


set g $t 
set Tutorial_info(text) $g
foreach i $LWDAQ_Info(instruments) {
	      upvar #0 LWDAQ_Tutorial_config config
	      upvar #0 LWDAQ_Tutorial_info info 
        set Tutorial_info($i\_name) [set LWDAQ_config_$i\(memory_name)]
	}


# This procedure checks the memory name of each instrument. If
# one has changed, it printes a message and updates its list of
# memory names. Then it posts itself to the LWDAQ event queue.
#This calls to a proc that prints information onto the LWDAQ Tutorial 
#window when acquire is pressed on a specific instrument. 
proc Tutorial_monitor {} {
        upvar #0 LWDAQ_Tutorial_config config
        upvar #0 LWDAQ_Tutorial_info info
        upvar #0 Tutorial_info minfo
        global LWDAQ_Info
         if {![winfo exists $minfo(text)]} {return}
        foreach i $LWDAQ_Info(instruments) {
                global LWDAQ_config_$i
                set current_name [set LWDAQ_config_$i\(memory_name)]
                if {$current_name != [set minfo($i\_name)]} {
										 set instrument_choice "$i\ instrument" 
										 if {$instrument_choice == "Diagnostic instrument"} {
												Diagnostic_acquire_info
  										}
										if {$instrument_choice == "BCAM instrument"} {
												BCAM_acquire_info
  										}
										if {$instrument_choice == "Camera instrument"} {
												Camera_acquire_info
  										}
										if {$instrument_choice == "Rasnik instrument"} {
												Rasnik_acquire_info
  										}
										if {$instrument_choice == "Thermometer instrument"} {
												Thermometer_acquire_info
  										}
                        
                        set minfo($i\_name) $current_name

                }

        }
        LWDAQ_post Tutorial_monitor
}

#Information on the acquired data that prints to the LWDAQ Tutorial page 
#when acquire is pressed.  

proc Diagnostic_acquire_info {} {
	 upvar #0 LWDAQ_Tutorial_info info
	 LWDAQ_print $info(text) "You have acquired from Diagnostic. If you entered 1 for verbose_result 
then the results are labeled. If you entered 0 then you will have a string of numbers as the result. 
The text at the start of the line, or heading results if you entered 1, is the memory name. 

When looking at the result line, an important result to note is loop time. Loop time is the 
5th result in the string if you have verbose_result set to 0. Loop time is the time it takes 
for a signal to propogate from the driver to the device and back. This time is dependent on 
the cable length and  can be described by the equation 50 + 10L where L is the cable length. 
The maximum value for loop time is 3125 ns and if you receieve this as a result your device is
either non responsive or does not exist.

Other results on the Diagnostic instrument include the supply voltage and the supply current.
The driver supplies 15 Volts, 5 Volts, and -15 Volts to the device which is measured on the
Diagnostic instrument. When you turn the head power off you will notice that the voltage levels 
drop to zero as the driver is off. If you have verbose result set to 0, +15 V is the the 7th 
number in the string, +5 V is the 9th and -15 V is the 11th. These voltage levels are also seen 
on the graph given in the Diagnostic window.

The supply current for each supply Voltage is also given, which shows the current that is drawn
by the device. The current levels are given by the 8th, 10th and 12th numbers in the string
where they correspond to each voltage level, +15 V, +5 V and -15 V, respectively. 

Now, please click on the BCAM button on the LWDAQ Tutorial. 
" 
}
proc BCAM_acquire_info {} { 
	upvar #0 LWDAQ_Tutorial_info info
	LWDAQ_print $info(text) "You have acquired from the BCAM instrument. If you entered 1 for 
verbose reult, then the results are labeled. If you entered 0 then you will have a string of 
numbers as the result.  

The first two numbers in the string after the memory name is the spot position for one of 
the sources. The first number is the position in x and the second is the position in y, 
both measured in um. For reference, the position (0,0) is measured at at the top left corner of
the top left pixel. 

The third number in the string is the number of pixels above threshold in the spot, meaning the
amount of pixels that are above the intensity threshold that you have specified in the 
anaylsis_threshold. The fourth number in the string is the peak intensity in the spot, which means
the pixel with the highest count above threshold. 

The results for the second spot can be found in the 7th and 8th (the spot position), the 9th
(the numbers of pixels above threshold) and the 10th (peak intensity in the spot) numbers in the
string.

Now, please click on the Camera button on the LWDAQ Tutorial.
" 
} 
proc Camera_acquire_info {} { 
	upvar #0 LWDAQ_Tutorial_info info
	LWDAQ_print $info(text) "You have acquired from the Camera instrument. If you entered 1 for
verbose reult, then the results are labeled. If you entered 0 then you will have a string of 
numbers as the result.

The first four numbers in the string after the memory name are the analysis bounds of the image
(the left, top, right and bottom). Then the 5th number that is given is the average intensity in
counts of the pixels in the image, with the 6th number giving the standard deviation of the 
intensity in counts. The 7th and 8th numbers in the string give the maximum and minimum intensity
of the pixels in theimage in counts. The last two numbers in the string give the height and width
of the image.

Now, please click on the Rasnik button on the LWDAQ Tutorial. " 

} 
proc Rasnik_acquire_info {} {
	upvar #0 LWDAQ_Tutorial_info info
	LWDAQ_print $info(text) "You have acquired from the Rasnik instrument. If you entered 1 for
verbose reult, then the results are labeled. If you entered 0 then you will have a string of 
numbers as the result.

The first two numbers are the x and y coordinates of the point in the rasnik mask that is projected 
by the rasnik lens onto the reference point in the CCD, which is measured in um. The 3rd and
4th numbers are the magnification of the x and y directions, where the x and y cooordinates
specified here are \"pattern coordinates\" parrallel to the mask squares.

The 5th number in the string is the image roatation which measures the rotation of the pattern
coordinates with respect to the image coordinates. A positive rotation refers to an anticlockwise
rotation while a negative rotation refers to a clockwise rotation of the image with respect to
the CCD.  

The 6th number in the string is an estimate of how accurate the x and y coordinates of the
rasnik mask are. The next two numbers are the mask square size that you have specified in
analysis_square_size_um and the pixel size that is specified under info in the parameter
anaylsis_pixel_size_um. Then the 9th number is the orientation code of which there are 4 
orientations. The nomial orientation which is 1, rotation in y which is 2, rotation in x 
which is 3 and orientation in z which is 4. 

The 10th and 11th numbers are the x and y coordinates of the reference point that the rasnik 
analysis used based upon the parameter you have filled in for anylsis_reference_code. 

The 12th and 13th numbers are the image skew in x and y measured in mrad/mm. The skew in x is 
how much the horizontal lines in the pattern diverge from one another from left to right and then
the skew in y is how much the vertial line slopes change from the top to the bottom. 

The 14th and last parameter is the slant, which is measured in mrad, and describes 
the amount the vertical and horizontal edges of the mask are not perpendicular at the center
of the analysis boundaries. 

Now, please click on the Thermometer button on the LWDAQ Tutorial. 

 " 
}
proc Thermometer_acquire_info {} { 
	upvar #0 LWDAQ_Tutorial_info info
	LWDAQ_print $info(text) "You have acquired from the Thermometer instrument. 
If you entered 1 for verbose reult, then the resultsare labeled. If you entered 0 then you will
have a string of numbers as the result. 

The results in the string give you the top and bottom reference resistors (B and T specified 
in daq_device_element) and four and then reads out from 4 temperature sensors (which is  1 2 3
and 4) 
" 
}
 

# Start the process off by posting the monitor process to the
# event queue.
LWDAQ_post Tutorial_monitor


return 1
