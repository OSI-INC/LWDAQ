{
	TCL/TK Command Line Implementations of Pascal Routines 
	Copyright (C) 2004-2021 Kevan Hashemi, Brandeis University
	Copyright (C) 2022-2025 Kevan Hashemi, Open Source Instruments Inc.
	
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or (at
	your option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
}

library lwdaq;

{
	lwdaq is the interface between our Pascal libraries and TCL/TK. It provides
	init_Lwdaq, which TCL/TK calls when it loads the lwdaq dynamic library.
	init_Lwdaq installs TCL commands, each of which has a name beginning with
	lwdaq in lower-case letters. The lower-case letters distinguish these
	commands from those that we define in TCL/TK scripts, which have names that
	begin with LWDAQ.

	This is a program instead of a unit, even though we compile it into a
	dynamic library. The GPC compiler expects a main program if it is to include
	the _p_initialize routine in the compiled object. We will need this routine
	to be present in the lwdaq.o object when we link the final lwdaq.so dynamic
	library with GCC.

	For a list of routines registered with TCL by this library, scroll down to
	lwdaq_init.

	At the top of each command-line function declaration you will find a comment
	in braces that describes the function. This comment will be extracted from
	lwdaq.pas automatically by our Command Maker script, and inserted into an
	HTML document. The comments appear as they are, in the HTML manual, and so
	include their own HTML tags, and even anchors.
}

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	sysutils,process,
	utils,images,transforms,image_manip,rasnik,
	spot,bcam,scam,shadow,wps,electronics,metrics,
	tcltk;

const
	package_name = 'lwdaq';
	version_num = '10.8';

{
	The following variables we use to implement the utils gui routines for
	analysis procedures.
}
var
	gui_photo_name:string='none';
	gui_display_zoom:real=1.0;
	gui_intensify:string='exact';
	gui_text_name:string='stdout';
	gui_interp_ptr:pointer=nil;
	gui_wait_ms:integer=-1;
	lwdaq_exit_command:string='';

{
	Here we have global variables that store data for repeated use by lwdaq
	library functions. Passing parameters into and out of the library routines
	is time-consuming because it requires conversion from strings to real
	numbers and back again. If we pass a list of reference points one time, for
	example, and store it in a global list, we can later refer to this list
	without passing it again.
}
var
	nearest_neighbor_library:matrix_type;
	
type
	embed_type=record
		name:string;
		relevance:real;
		vector:x_graph_type;
	end;

var
	embed_library:array of embed_type;
	
{
	The embed library swap procedure used by lwdaq_rag to sort the embed
	library. Must be a global procedure in order for us to point the quick sort
	routine to the procedure.
}
procedure embed_swap(a,b:integer;p:pointer); 
var e:embed_type;
begin
	e.name:=embed_library[a].name;
	e.relevance:=embed_library[a].relevance;
	e.vector:=embed_library[a].vector;
	embed_library[a].name:=embed_library[b].name;
	embed_library[a].relevance:=embed_library[b].relevance;
	embed_library[a].vector:=embed_library[b].vector;
	embed_library[b].name:=e.name;
	embed_library[b].relevance:=e.relevance;
	embed_library[b].vector:=e.vector;
end;

{
	The embed library less-than function used by lwdaq_rag to sort the embed
	library. Must be a global function in order for us to point the quick sort
	routine to the procedure
	
}
function embed_lt(a,b:integer;p:pointer):boolean;
begin 
	embed_lt:=(embed_library[a].relevance < embed_library[b].relevance); 
end;

{
	lwdaq_tcl_eval evaluates a string in the Tcl interpreter and returns the
	result of execution. The routine knows how to find and communicate with the
	interpreter through use of the global gui_interp_ptr. If that pointer is set
	to nil, the routine reports an error and returns an empty string. If the
	evaluation in the interpreter leads to an error, the routine likewise
	reports an error and returns an empty string.
}
function lwdaq_tcl_eval(s:string):string;
var 
	error:integer;
	c:string;
	obj_ptr:pointer;
begin
	lwdaq_tcl_eval:='';
	if gui_interp_ptr=nil then begin
		report_error('gui_interp_ptr=nil in lwdaq_tcl_eval');
		exit;
	end;
	if Tcl_InterpDeleted(gui_interp_ptr)<>0 then begin
		report_error('interpreter deleted in lwdaq_tcl_eval');
		exit;
	end;
	error:=Tcl_Eval(gui_interp_ptr,PChar(s));
	obj_ptr:=Tcl_GetObjResult(gui_interp_ptr);
	c:=Tcl_ObjString(obj_ptr);
	if error<>Tcl_OK then report_error('executing "'+s+'" in lwdaq_tcl_eval');
	lwdaq_tcl_eval:=c;
end;

{
	lwdaq_quit executes the lwdaq_exit_command, provided the Tcl interpreter is
	still running. During an orderly exit, the interpreter will be available. The
	routine has the format of a Tcl exit handler, with a pointer parameter that
	we don't use.
}
procedure lwdaq_quit(data:pointer);
begin
	if Tcl_InterpDeleted(gui_interp_ptr)<>0 then exit;
	lwdaq_tcl_eval(lwdaq_exit_command);
end;

{
	lwdaq_gui_writeln writes a string to a text device in the TclTk interpreter
	using the LWDAQ_print command. This command accepts file names, text widget
	names, and the names of the standard output (stdout) and standard error
	(stderr) channels. The text name used by lwdaq_gui_writeln is the name
	stored in the global gui_text_name variable.
}
procedure lwdaq_gui_writeln(s:string); 
begin
	lwdaq_tcl_eval('LWDAQ_print '+gui_text_name+' "'+s+'"');
end;

{
	lwdaq_gui_draw draws the named image into the TK photo named gui_photo_name.
	The routine calls lwdaq_draw, which, like all the lwdaq TclTk commands,
	clears the global error_string. We save the initial value of error_string so
	we can restore it after the update. This restoration means we can call
	lwdaq_gui_draw anywhere in our code without deleting the existing
	error_string.
}
procedure lwdaq_gui_draw(s:string); 
var 
	c:string;
	saved_error_string:string;
begin
	if (gui_photo_name<>'none') then begin
		saved_error_string:=error_string;
		c:=' lwdaq_draw '+s+' '+gui_photo_name 
			+' -intensify '+gui_intensify
			+' -zoom '+string_from_real(gui_display_zoom,1,2);
		lwdaq_tcl_eval(c);
		lwdaq_tcl_eval('LWDAQ_update');
		error_string:=saved_error_string;
	end else
		default_gui_draw(s);
end;

{
	lwdaq_gui_wait pauses for gui_wait_ms milliseconds. If gui_wait_ms is -1,
	the routine opens a window and asks the user to press the button before
	returning.
}
procedure lwdaq_gui_wait(s:string); 
var 
	c:string;
begin
	if (gui_wait_ms>=0) then 
		c:='LWDAQ_wait_ms '+string_from_integer(gui_wait_ms,1)
	else 
		c:='LWDAQ_button_wait "'+s+'"';
	lwdaq_tcl_eval(c);
end;

{
	lwdaq_gui_support passes control to the graphical user interface to perform
	support for display updates and mouse clicks.
}
procedure lwdaq_gui_support(s:string);
begin
	lwdaq_tcl_eval('LWDAQ_support');
end;

{
	lwdaq_debug_log writes a string to a log file using the LWDAQ_debug_log
	routine.
}
procedure lwdaq_debug_log(s:string); 
begin
	lwdaq_tcl_eval('LWDAQ_debug_log "'+s+'"');
end;

{
<p>lwdaq_error_string returns the global error string into which our library routines record potentially fatal errors they encounter during execution. If we set the -append_errors flag with <a href="#lwdaq_config">lwdaq_config</a>, the string will contain all errors encountered, separated by line breaks. Otherwise, the string will contain only the most recent error. Each error line begins with the error prefix string, which is defined in <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>. If we pass the -value option, we provide a string that is to take the place of the current error string. If this string parameter is empty, the error string is cleared.</p>
}
function lwdaq_error_string(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	option:string='';
	value:string='';
	arg_index:integer;
	vp:pointer;
	
begin
	gui_interp_ptr:=interp;
	lwdaq_error_string:=Tcl_Error;

	if (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_error_string ?option value?".');
		exit;
	end;

	if argc>1 then begin
		arg_index:=1;
		while (arg_index<argc-1) do begin
			option:=Tcl_ObjString(argv[arg_index]);
			inc(arg_index);
			vp:=argv[arg_index];
			inc(arg_index);
			if (option='-value') then value:=Tcl_ObjString(vp)
			else begin 
				Tcl_SetReturnString(interp,error_prefix
					+'Bad option "'+option+'", must be one of "-value ?".'); 
				exit;
			end;
		end;
		error_string:=value;
	end;

	Tcl_SetReturnString(interp,error_string);
	lwdaq_error_string:=Tcl_OK;	
end;

{
<p>lwdaq_config sets global variables that control the operation of the lwdaq libraries. If you specify no options, lwdaq_config returns a string giving you the current values of all the options, <i>except</i> the -eol option. Each option requires a value, which will be assigned to the global variable names in the option. Here are the options and their expected value types. Boolean variables you specify with 0 for false and 1 for true.</p>

<center><table cellspacing=1 border>
<tr><th>Option</th><th>Type</th><th>Function</th></tr>
<tr><td>-stdout_available</td><td>Boolean</td><td>standard output channel is available, default 1</td></tr>
<tr><td>-stdin_available</td><td>Boolean</td><td>standard input channel is available, default 0</td></tr>
<tr><td>-track_ptrs</td><td>Boolean</td><td>track memory allocation, default 0</td></tr>
<tr><td>-text_name</td><td>String</td><td>text window, channel, or file in which to print messages, default stdout</td></tr>
<tr><td>-photo_name</td><td>String</td><td>photo in which to draw images and graphs, default none</td></tr>
<tr><td>-zoom</td><td>Real</td><td>display scaling for images drawn by <a href="#lwdaq_gui_draw">lwdaq_gui_draw</a>, default 1.0</td></tr>
<tr><td>-display_zoom</td><td>Real</td><td>display scaling for images drawn by library routines, default 1.0</td></tr>
<tr><td>-intensify</td><td>String</td><td>intensification type for images,<br>
	none, mild, strong, or exact, default exact</td></tr>
<tr><td>-wait_ms</td><td>Integer</td><td>milliseconds to pause during <a href="#lwdaq_gui_wait">lwdaq_gui_wait</a>, default -1</td></tr>
<tr><td>-gamma_correction</td><td>Real</td><td>image drawing gamma correction, default 1.0</td></tr>
<tr><td>-rggb_red_scale</td><td>Real</td><td>image drawing red brightness, default 1.0</td></tr>
<tr><td>-rggb_blue_scale</td><td>Real</td><td>image drawing blue brightness, default 1.0</td></tr>
<tr><td>-fsr</td><td>Integer</td><td>field size for real numbers returned in strings, default 1</td></tr>
<tr><td>-fsd</td><td>Integer</td><td>decimal places for real numbers returned in strings, default 6</td></tr>
<tr><td>-eol</td><td>String</td><td>end of line characters for text windows and files, default chr(10)</td></tr>
<tr><td>-append_errors</td><td>Boolean</td><td>Append errors to global error string, default 0</td></tr>
<tr><td>-log_name</td><td>String</td><td>Name of debugging log file, default "lwdaq_log.txt"</td></tr>
<tr><td>-log_errors</td><td>Boolean</td><td>Write errors to log file, default 0</td></tr>
<tr><td>-show_details</td><td>Boolean</td><td>Write execution details to text window, default 0</td></tr>
<tr><td>-exit_command</td><td>String</td><td>A Tcl command to execute on exit, default ""</td></tr>
</table><small><b>Table:</b> Options for lwdaq_config.</small></center>

<p>The lwdaq library routines can write to Tk text windows through -text_name and -photo_name. The -text_name should specify a Tk text widget (such as .text), <i>stdout</i>, or a file name. The default is <i>stdout</i>. If the -text_name does not begin with a period, indicating a text window, nor is it <i>stdout</i>, we assume it is the name of a file. File names cannot be numbers. If the file name contains a path, that path must exist. The -show_details option is used by some library routines to generate additional exectution details that will be printed to the text window specified by -text_name.</p>

<p>The library routines can draw an image in a Tk photo by calling <i>gui_draw</i> and specifying the name of the image. The photo that will receive the image is the one named by a global variable we set with the -photo_name option. The -photo_name must be an existing Tk photo (such as bcam_photo), and has default value "none", which disables the drawing. By default, <i>gui_draw</i> is set to <a href="#lwdaq_gui_draw">lwdaq_gui_draw</a>. The -intensify specifies <i>gui_intensification</i> for lwdaq_gui_draw. The -display_zoom option specifies <i>gui_display_zoom</i>, which applies an additional scaling to all images drawn by <i>lwdaq_draw</i> or by <i>gui_draw</i>. The <a href="#lwdaq_draw">lwdaq_draw</a> routine multiplies its image-specific zoom value by the global gui_display_zoom to obtain a total scaling value. The -display_zoom option is designed to accommodate different computer display resolutions, which sometimes result in lwdaq images being too large or too small. The <a href="http://www.cgsd.com/papers/gamma.html">gamma correction</a> sets the gray scale image display gamma correction used by lwdaq_draw and lwdaq_rggb_draw. By default it is 1.0, which gives us a linear relationship between the image pixel intensity and the display pixel intensity. The <i>rggb_red_scale</i> and <i>rggb_blue_scale</i> parameters determine how we increase the brightness of the red and blue component of the display pixel with respect to the green component. By default, these are also 1.0.</p>

<p>During execution, analysis routines can pause to allow us to view intermediate drarwing results by means of the -wait_ms option. If we set -wait_ms to 1000, the analysis routine will pause for one second. If we set -wait_ms to -1, Tk will open a window with a <i>Continue</i> button in it, which we click before the analysis proceeds.</p>

<p>Many routines return real numbers in strings. These real numbers will have a fixed number of decimal places equal to the global Pascal variable <i>fsd</i> and a total field size equal to the global Pascal variable <i>fsr</i>.</p>

<p>The global error_string variable is used by all the command routines in lwdaq.pas. Each command routine resets error_string and checks it when it's finished. If error_string is not empty, the routine will return an error condition and error_string will be its result. The append_errors option tells the analysis library to append new errors to error_string instead of over-writing previous errors with the new error. By default, append_errors is false. When we set log_errors to 1, each error reported by the report_error routine will, in addition, be written to a log file with the global debug_log procedure.</p>

<p>The -exit_command option allows us to specify a Tcl command that will be executed during an orderly exit from the lwdaq process. This command will be executed if the user presses the Quit button or enters an exit command in some other way, but not if the user closes the main window with a window-destroy button. Default exit command is empty.</p>
}
function lwdaq_config(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	option:string;
	arg_index:integer;
	vp:pointer;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_config:=Tcl_Error;

	if (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_config ?option value?".');
		exit;
	end;

	if argc=1 then begin
		Tcl_SetReturnString(interp,
			' -stdout_available '+string_from_boolean(stdout_available)
			+' -stdin_available '+string_from_boolean(stdin_available)
			+' -append_errors '+string_from_boolean(append_errors)
			+' -log_errors '+string_from_boolean(log_errors)
			+' -track_ptrs '+string_from_boolean(track_ptrs)
			+' -text_name '+gui_text_name
			+' -show_details '+string_from_boolean(show_details)
			+' -exit_command "'+lwdaq_exit_command+'"'
			+' -photo_name '+gui_photo_name
			+' -display_zoom '+string_from_real(gui_display_zoom,1,2)
			+' -intensify '+gui_intensify
			+' -wait_ms '+string_from_integer(gui_wait_ms,0)
			+' -gamma_correction '+string_from_real(gamma_correction,0,1)
			+' -rggb_blue_scale '+string_from_real(rggb_blue_scale,0,1)
			+' -rggb_red_scale '+string_from_real(rggb_red_scale,0,1)
			+' -fsr '+string_from_integer(fsr,0)
			+' -fsd '+string_from_integer(fsd,0));
	end else begin
		arg_index:=1;
		while (arg_index<argc-1) do begin
			option:=Tcl_ObjString(argv[arg_index]);
			inc(arg_index);
			vp:=argv[arg_index];
			inc(arg_index);
			if (option='-stdout_available') then stdout_available:=Tcl_ObjBoolean(vp)
			else if (option='-stdin_available') then stdin_available:=Tcl_ObjBoolean(vp)
			else if (option='-append_errors') then append_errors:=Tcl_ObjBoolean(vp)
			else if (option='-log_errors') then log_errors:=Tcl_ObjBoolean(vp)
			else if (option='-track_ptrs') then track_ptrs:=Tcl_ObjBoolean(vp)
			else if (option='-text_name') then gui_text_name:=Tcl_ObjString(vp)
			else if (option='-show_details') then show_details:=Tcl_ObjBoolean(vp)
			else if (option='-exit_command') then begin
				lwdaq_exit_command:=Tcl_ObjString(vp);
				Tcl_CreateExitHandler(@lwdaq_quit,nil);
			end else if (option='-photo_name') then gui_photo_name:=Tcl_ObjString(vp)
			else if (option='-display_zoom') then gui_display_zoom:=Tcl_ObjReal(vp)
			else if (option='-intensify') then gui_intensify:=Tcl_ObjString(vp)
			else if (option='-wait_ms') then gui_wait_ms:=Tcl_ObjInteger(vp)
			else if (option='-gamma_correction') then gamma_correction:=Tcl_ObjReal(vp)
			else if (option='-rggb_blue_scale') then rggb_blue_scale:=Tcl_ObjReal(vp)
			else if (option='-rggb_red_scale') then rggb_red_scale:=Tcl_ObjReal(vp)
			else if (option='-fsr') then fsr:=Tcl_ObjInteger(vp)
			else if (option='-fsd') then fsd:=Tcl_ObjInteger(vp)
			else if (option='-eol') then eol:=Tcl_ObjString(vp)
			else if (option='-log_name') then log_file_name:=Tcl_ObjString(vp)
			else begin 
				Tcl_SetReturnString(interp,error_prefix
					+'Bad option "'+option+'", must be one of '
					+'"-stdout_available ? -stdin_available ? -append_errors ?'
					+' -track_ptrs ? -text_name ? -show_details ? -photo_name ?'
					+' -wait_ms ? -gamma_correction ? -rggb_red_scale ?'
					+' -rggb_blue_scale ? -fsr ? -fsd ? -eol ? -display_zoom ?'
					+' -intensify ? -log_name ? -log_errors ? -local_terminal ?".'); 
				exit;
			end;
		end;
	end;

	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_config:=Tcl_OK;	
end;

{
<p>lwdaq_image_create creates a new image and returns a unique name for the image, by which the interpreter can identify the image to other lwdaq routines.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-name</td><td>Specify the name for the image.</td></tr>
<tr><td>-results</td><td>Set the image results string.</td></tr>
<tr><td>-width</td><td>The width of the image in pixels.</td></tr>
<tr><td>-height</td><td>The height of the image in pixels</td></tr>
<tr><td>-data</td><td>Pixel intensity values as a binary array of bytes.</td></tr>
<tr><td>-left</td><td>Left column of analysis bounds.</td></tr>
<tr><td>-right</td><td>Right column of analysis bounds.</td></tr>
<tr><td>-top</td><td>Topm row of analysis bounds.</td></tr>
<tr><td>-bottom</td><td>Bottom row of analysis bounds.</td></tr>
<tr><td>-try_header</td><td>Try image data for a lwdaq-format header, default 1.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_image_create.</small></center>

<p>The above table lists the options accepted by lwdaq_image_create, and their functions. If you use the -name option and provide the name of a pre-existing image in the lwdaq image list, lwdaq_image_create deletes the pre-existing image. If you specify "-data $value", the routine copies $value into the image's intensity array, starting at the first pixel of the first row. When you combine "-data $value" with "-try_header 1", the routine looks at the first bytes in $value to see if it contains a valid image header, specifying image width and height, as well as analysis bounds and a results string. When the routine looks for the header, it assumes that the bytes in the header specify two-byte integers in big-endian order.</p>

<p>If you have -try_header 0, or if the routine's effort to find a header fails, lwdaq_image_create will look at the values you specify for the analysis bounds with the -left, -top, -right, and -bottom options. A value of &minus;1 directs the routine to place the boundary at the edge of the image. The default values for these options are all &minus;1.</p>
}
function lwdaq_image_create(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	max_side=10000;
	min_side=10;
	
var 
	option:string;
	arg_index:integer;
	data_size:integer;
	width:integer=-1;
	height:integer=-1;
	copy_size:integer=-1;
	left:integer=-1;
	right:integer=-1;
	top:integer=-1;
	bottom:integer=-1;
	try_header:boolean=false;
	ihp:image_header_ptr_type=nil;
	data_obj:pointer=nil;
	data_ptr:pointer=nil;
	name:string='';
	results:string='';
	ip:image_ptr_type=nil;
	vp:pointer=nil;
	char_index:integer;
	q:integer;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_create:=Tcl_Error;
	
	if (argc<3) or (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_image_create option value ?option value?".');
		exit;
	end;
	
	arg_index:=1;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-name') then name:=Tcl_ObjString(vp)
		else if (option='-results') then results:=Tcl_ObjString(vp)
		else if (option='-width') then width:=Tcl_ObjInteger(vp)
		else if (option='-height') then height:=Tcl_ObjInteger(vp)
		else if (option='-data') then data_obj:=vp
		else if (option='-left') then left:=Tcl_ObjInteger(vp)
		else if (option='-right') then right:=Tcl_ObjInteger(vp)
		else if (option='-top') then top:=Tcl_ObjInteger(vp)
		else if (option='-bottom') then bottom:=Tcl_ObjInteger(vp)
		else if (option='-try_header') then try_header:=Tcl_ObjBoolean(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-name -width -height -data -left -top'
				+' -bottom -right -results -try_header".');
			exit;
		end;
	end;

	if data_obj<>nil then begin
		data_ptr:=Tcl_GetByteArrayFromObj(data_obj,data_size);
		if data_size<sizeof(image_header_type) then begin
			Tcl_SetReturnString(interp,error_prefix
			+'Data too small for image header in lwdaq_image_create.');
			exit;
		end;
		
		ihp:=pointer(data_ptr);
		if try_header then begin
			q:=local_from_big_endian_smallint(ihp^.j_max)+1;
			if (q>0) then height:=q;
			q:=local_from_big_endian_smallint(ihp^.i_max)+1;
			if (q>0) then width:=q;
		end;

		if (width<=0) and (height<=0) then begin
			width:=trunc(sqrt(data_size));
			if sqr(width)<data_size then width:=width+1;
			height:=width;
		end;

		if (width<=0) and (height>0) then begin
			width:=trunc(data_size/height);
			if width*height<data_size then width:=width+1;
		end;

		if (width>0) and (height<=0) then begin
			height:=trunc(data_size/width);
			if width*height<data_size then height:=height+1;
		end;

		if width<min_side then width:=min_side;
		if width>max_side then width:=max_side;
		if height<min_side then height:=min_side;
		if height>max_side then height:=max_side;

		if (width*height>data_size) then copy_size:=data_size
		else copy_size:=(width*height);
	end;
	
	if (data_obj=nil) and try_header then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Specified -try_header 1 without -data $value.');
		exit;
	end;
	
	ip:=new_image(height,width);
	if ip=nil then begin 
		Tcl_SetReturnString(interp,error_string);
		exit;
	end;
	
	if data_ptr<>nil then begin
		block_move(data_ptr,@ip^.intensity[0],copy_size);
	end;
	
	if try_header then begin
		q:=local_from_big_endian_smallint(ihp^.left);
		if (q>=0) then left:=q;
	end;
	if (left<0) or (left>=width) then left:=0;
	ip^.analysis_bounds.left:=left;
	
	if try_header then begin
		q:=local_from_big_endian_smallint(ihp^.right);
		if (q>left) then right:=q;
	end;
	if (right<=left) or (right>=width) then right:=width-1;
	ip^.analysis_bounds.right:=right;

	if try_header then begin
		q:=local_from_big_endian_smallint(ihp^.top);
		if (q>=0) then top:=q;
	end;
	if (top<1) or (top>=height) then top:=1;
	ip^.analysis_bounds.top:=top;
	
	if try_header then begin
		q:=local_from_big_endian_smallint(ihp^.bottom);
		if (q>top) then bottom:=q;
	end;
	if (bottom<=top) or (bottom>=height) then bottom:=height-1;
	ip^.analysis_bounds.bottom:=bottom;
	
	ip^.results:=results;
	if try_header and (ip^.results='') then begin
		char_index:=0;
		while (char_index<long_string_length) 
				and (ihp^.results[char_index]<>chr(0)) do begin
			ip^.results:=ip^.results+ihp^.results[char_index];
			inc(char_index);
		end;
	end;
	
	if name<>'' then begin
		while valid_image_name(name) do
			dispose_image(image_ptr_from_name(name));
		ip^.name:=name;
	end;
	
	if error_string='' then Tcl_SetReturnString(interp,ip^.name)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_image_create:=Tcl_OK;
end;

{
<p>lwdaq_draw transfers the contents of a lwdaq image into a Tk photo. We pass the lwdaq image name followed by the Tk photo name, and then our options in the form ?option value?. When the routine draws the image, it over-writes the first few pixels in the first image row with a header block containing the image dimensions, its analysis bounds, and its results string.</p>

<p>The -intensify option can take four values: mild, strong, exact, and none. Mild intensification displays anything darker than four standard deviations below the mean intensity as black, and anything brighter than four standard deviations above the mean intensity as white. In between black and white the display is linear with pixel brightness. Strong intensification does the same thing, but for a range of two standard deviations from the mean. Exact displays the darkest spot in the image as black and the brightest as white. In all three cases, we calculate the mean, standard deviation, minimum, and maximum intensity of the image within the <i>analysis bounds</i>, not across the entire image.</p>

<p>The -zoom option scales the image as we draw it in the Tk photo. This scaling is in addition to the scaling called for by the global <i>gui_display_zoom</i> parameter, which we set with <a href="#lwdaq_config">lwdaq_config</a>. The Tk photo will expand or contract to match the size of the zoomed image. The product of the zoom value and the global <i>gui_display_zoom</i> can take any value between 0.1 and 10. But the effective value of the scaling factor is dicated by the requirements of sub-sampling. If the scaling factor is greater than 1, we round it to the nearest integer, <i>e</i>, and draw each image pixel on the screen as a block of <i>e</i>&times;<i>e</i> pixels. If -zoom is less than 1, we round its inverse to the nearest integer, <i>c</i>. We draw only one pixel out of every <i>c</i> pixels in the Tk photo. If the scaling factor is 0.3, we draw every third pixel. If 0.4, we draw every third pixel if your computer rounds 1/0.4 to 3, or every second pixel if your computer rounds 1/0.4 to 2. With scaling factor 0.0, we draw every tenth pixel. Prior to drawing, the image overlay may contain lines that show the results of analysis or mark features in the image. These lines are likely to be only one pixel wide. If we are sub-sampling the image, all such markings will be partially erased. When drawing with a scaling factor less than 0.5, <i>lwdaq_draw</i> spreads out each pixel in the overlay so that, when subsampled, the integrity of the overlay markings is preserved. After the draw, the overlay markings remain spread, which means that subsequent drawing of the same image with a larger scaling factor will appear with thicker overlay lines.</p>

<p>With -clear set to 1, lwdaq_draw clears the overlay in the lwdaq image before drawing in the Tk photo. The overlay may contain a graph or oscilloscope display, or analysis indicator lines. If you don't want these to be displayed, set -clear to 1. Whatever was in the overlay will be erased from the overlay before drawing.</p>

<p>By default, -show_bounds is 1, and the routine draws a blue rectangle to show the the image analysis boundaries, which are used by image analysis routines like lwdaq_rasnik and lwdaq_bcam. But with -show_bounds set to 0, this blue rectangle is not drawn. If you want to be sure that you don't have a blue rectangle drawn over your gray-scale image, you should also specify -clear 1, so that lwdaq_draw will clear the image overlay of any pre-existing blue rectangles.</p>
}
function lwdaq_draw(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	min_scale=0.2;
	max_scale=20;
	
var 
	option:string;
	arg_index:integer;
	image_name:string='';
	photo_name:string='';
	intensify:string='';
	ip:image_ptr_type=nil;
	zoom:real=1;
	vp:pointer=nil;
	ph:pointer=nil;
	pib:Tk_PhotoImageBlock;
	subsampleX,subsampleY,zoomX,zoomY:integer;
	draw_width,draw_height:integer;
	clear:boolean=false;
	rggb:boolean=false;
	gbrg:boolean=false;
	show_bounds:boolean=true;
	scale:real;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_draw:=Tcl_Error;

	if (argc<3)	or (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_draw image photo ?option value?".');
		exit;
	end;
		
	image_name:=Tcl_ObjString(argv[1]);
	photo_name:=Tcl_ObjString(argv[2]);
	arg_index:=3;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-intensify') then intensify:=Tcl_ObjString(vp)
		else if (option='-zoom') then zoom:=Tcl_ObjReal(vp)
		else if (option='-clear') then clear:=Tcl_ObjBoolean(vp)
		else if (option='-show_bounds') then show_bounds:=Tcl_ObjBoolean(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-intensify -zoom -clear -show_bounds".');
			exit;
		end;
	end;
	
	ip:=image_ptr_from_name(image_name);
	if ip=nil then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist.');
		exit;
	end;
	embed_image_header(ip);

	if intensify='exact' then ip^.intensification:=exact_intensify
	else if intensify='mild' then ip^.intensification:=mild_intensify
	else if intensify='strong' then ip^.intensification:=strong_intensify
	else if intensify='exact_rggb' then begin 
		ip^.intensification:=exact_intensify;
		rggb:=true;
	end else if intensify='mild_rggb' then begin
		ip^.intensification:=mild_intensify;
		rggb:=true;
	end else if intensify='strong_rggb' then begin
		ip^.intensification:=strong_intensify;
		rggb:=true;
	end else if intensify='rggb' then begin
		ip^.intensification:=no_intensify;
		rggb:=true;
	end else if intensify='exact_gbrg' then begin 
		ip^.intensification:=exact_intensify;
		gbrg:=true;
	end else if intensify='mild_gbrg' then begin
		ip^.intensification:=mild_intensify;
		gbrg:=true;
	end else if intensify='strong_gbrg' then begin
		ip^.intensification:=strong_intensify;
		gbrg:=true;
	end else if intensify='gbrg' then begin
		ip^.intensification:=no_intensify;
		gbrg:=true;
	end else ip^.intensification:=no_intensify;
	
	ph:=Tk_FindPhoto(interp,PChar(photo_name));
	if ph=nil then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Photo "'+photo_name+'" does not exist.');
		exit;
	end;
	
	scale:=zoom*gui_display_zoom;
	if scale<min_scale then scale:=min_scale;
	if scale>max_scale then scale:=max_scale;

	if clear then clear_overlay(ip);
	if show_bounds then
		draw_overlay_rectangle(ip,ip^.analysis_bounds,blue_color);
	if (scale>0) and (scale<>1) then spread_overlay(ip,round(1/scale));
	if rggb then draw_rggb_image(ip)
	else if gbrg then draw_gbrg_image(ip)
	else draw_image(ip);
	with pib do begin
		pixelptr:=@drawing_space[0];
		width:=ip^.i_size;
		height:=ip^.j_size;
		pitch:=width*sizeof(drawing_space_pixel_type);
		pixelSize:=sizeof(drawing_space_pixel_type);
		offset[red]:=0;
		offset[green]:=offset[red]+sizeof(byte);
		offset[blue]:=offset[green]+sizeof(byte);
		offset[alpha]:=offset[blue]+sizeof(byte);
	end;
	if scale>=1 then begin
		subsampleX:=1;
		subsampleY:=1;
		zoomX:=round(scale);
		zoomY:=round(scale);
		draw_width:=pib.width*zoomX;
		draw_height:=pib.height*zoomY;
	end else begin
		subsampleX:=round(1/scale);
		subsampleY:=round(1/scale);
		zoomX:=1;
		zoomY:=1;
		draw_width:=round(pib.width/subsampleX);
		draw_height:=round(pib.height/subsampleY);
	end;

	Tk_PhotoSetSize(interp,ph,draw_width,draw_height);
	Tk_PhotoBlank(ph);
	Tk_PhotoPutZoomedBlock(interp,ph,@pib,0,0,
		draw_width,draw_height,
		zoomX,zoomY,subsampleX,subsampleY,1);
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_draw:=Tcl_OK;
end;

{
<p>lwdaq_draw_raw renders a block of raw image data in a Tk photo. The -pix_fmt option follows the naming conventions of <i>ffmpeg</i>. We currently recognise formats "gray" for eight-bit gray-scale, and "rgb24" for three-byte color. The -width and -height options specify the dimensions of the image. The -zoom option scales the image as we draw it in the Tk photo. See <a href="#lwdaq_draw">lwdaq_draw</a> for description of these last three options.</p>
}
function lwdaq_draw_raw(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	min_scale=0.2;
	max_scale=20;
	
var 
	option:string;
	arg_index:integer;
	data_obj:pointer=nil;
	data_ptr:pointer=nil;
	data_size:integer=0;
	photo_name:string='';
	width:integer=0;
	height:integer=0;
	pix_fmt:string='rgb24';
	zoom:real=1;
	vp:pointer=nil;
	ph:pointer=nil;
	pib:Tk_PhotoImageBlock;
	subsampleX,subsampleY,zoomX,zoomY:integer;
	draw_width,draw_height:integer;
	scale:real;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_draw_raw:=Tcl_Error;

	if (argc<3)	or (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_image_draw image photo ?option value?".');
		exit;
	end;
		
	data_obj:=argv[1];
	photo_name:=Tcl_ObjString(argv[2]);
	arg_index:=3;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-pix_fmt') then pix_fmt:=Tcl_ObjString(vp)
		else if (option='-zoom') then zoom:=Tcl_ObjReal(vp)
		else if (option='-width') then width:=Tcl_ObjInteger(vp)
		else if (option='-height') then height:=Tcl_ObjInteger(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-pix_fmt -zoom -width -height".');
			exit;
		end;
	end;
	
	data_ptr:=Tcl_GetByteArrayFromObj(data_obj,data_size);
	
	if (width<=0) and (height<=0) then begin
		width:=trunc(sqrt(data_size));
		height:=width;
	end;

	if (width<=0) and (height>0) then begin
		width:=trunc(data_size/height);
	end;

	if (width>0) and (height<=0) then begin
		height:=trunc(data_size/width);
	end;

	ph:=Tk_FindPhoto(interp,PChar(photo_name));
	if ph=nil then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Photo "'+photo_name+'" does not exist.');
		exit;
	end;
	
	if (pix_fmt = 'gray') then begin
		pib.pixelptr:=data_ptr;
		pib.width:=width;
		pib.height:=height;
		pib.pitch:=width*1;
		pib.pixelSize:=1;
		pib.offset[red]:=0;
		pib.offset[green]:=0;
		pib.offset[blue]:=0;
		pib.offset[alpha]:=0;
	end else begin
		pib.pixelptr:=data_ptr;
		pib.width:=width;
		pib.height:=height;
		pib.pitch:=width*3;
		pib.pixelSize:=3;
		pib.offset[red]:=0;
		pib.offset[green]:=1;
		pib.offset[blue]:=2;
		pib.offset[alpha]:=0;
	end;
	
	scale:=zoom*gui_display_zoom;
	if scale<min_scale then scale:=min_scale;
	if scale>max_scale then scale:=max_scale;
	if scale>=1 then begin
		subsampleX:=1;
		subsampleY:=1;
		zoomX:=round(scale);
		zoomY:=round(scale);
		draw_width:=pib.width*zoomX;
		draw_height:=pib.height*zoomY;
	end else begin
		subsampleX:=round(1/scale);
		subsampleY:=round(1/scale);
		zoomX:=1;
		zoomY:=1;
		draw_width:=round(pib.width/subsampleX);
		draw_height:=round(pib.height/subsampleY);
	end;

	Tk_PhotoSetSize(interp,ph,draw_width,draw_height);
	Tk_PhotoBlank(ph);
	Tk_PhotoPutZoomedBlock(interp,ph,@pib,0,0,
		draw_width,draw_height,
		zoomX,zoomY,subsampleX,subsampleY,1);
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_draw_raw:=Tcl_OK;
end;

{
<p>lwdaq_image_contents returns a byte array containing the intensity array from the named image. In the first line of the image the routine records the image dimensions, analysis boundry, and results string. The image dimensions and boundaries are given as two-bytes integers, and we use big-endian byte ordering, so the high-order byte is first. The rest of the image data is returned exactly as it is in the image. If the image consists of single-byte pixels, these are returned with no modification or padding. Likewise, if the image consists of two-byte words, or four-byte messages, these are returned as a block of bytes with no modification. If you specify -truncate 1, the routine removes all trailing zero-bytes from the data. When we create a new image to accomodate the same data later, we clear the image intensity array before we copy in the new data, so the image is re-constructed faithfully. This truncation is effective at reducing the size of data files from instruments that don't fill the intensity array with real data, but instead use the intensity array as a place to store one-dimensional data, and use the overlay as a white-board upon which to render the data (like the Voltmeter). If you specify -data_only 1, the routine chops off the leading row of data, leaving only the data from the first pixel of the first row onwards, which is the block of data operated upon by our lwdaq_data_manipulate routines. If you specify -record_size larger than 1, the routine makes sure that the size of the block it returns is divisible by the record size.</p>
}
function lwdaq_image_contents(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	option:string;
	arg_index:integer;
	image_name:string='';
	ip:image_ptr_type;
	vp:pointer;	
	i,j:integer;
	truncate:boolean=false;
	data_only:boolean=false;
	copy_size:integer=0;
	record_size:integer=1;
	cp:pointer;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_contents:=Tcl_Error;
	
	if (argc<2) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, must be "'
				+'lwdaq_image_contents image".');
		 exit;
	end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_image_contents.');
		exit;
	end;
	
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-truncate') then truncate:=Tcl_ObjBoolean(vp)
		else if (option='-data_only') then data_only:=Tcl_ObjBoolean(vp)
		else if (option='-record_size') then record_size:=Tcl_ObjInteger(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'" in '
				+'lwdaq_image_contents, must be one of '
				+'"-truncate -data_only -record_size".');
			exit;
		end;
	end;

	embed_image_header(ip);
	
	copy_size:=ip^.j_size*ip^.i_size*sizeof(intensity_pixel_type);
	if truncate then begin
		with ip^ do begin
			j:=j_size-1;
			i:=i_size-1;
			while (j>0) and (get_px(ip,j,i)=0) do begin
				if i=0 then begin
					dec(j);
					i:=i_size-1;
				end else begin
					dec(i);
				end;
				dec(copy_size);
			end;
		end;
	end;
	
	if data_only then begin
		copy_size:=copy_size-ip^.i_size;
		cp:=@ip^.intensity[ip^.i_size];
	end else begin
		cp:=@ip^.intensity[0];
	end;
	
	if copy_size<0 then copy_size:=0;
	
	if record_size>1 then
		if (copy_size mod record_size) > 0 then
			copy_size:=copy_size+record_size-(copy_size mod record_size);
	
	if error_string='' then Tcl_SetReturnByteArray(interp,cp,copy_size)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_image_contents:=Tcl_OK;
end;

{
<p>lwdaq_image_destroy disposes of an image. You can specify multiple images, or image name patterns with * and ? wild cards. You can enter multiple image names on the command line, too.</p>
}
function lwdaq_image_destroy(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	arg_index:integer;
	image_name:string='';

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_destroy:=Tcl_Error;
	
	if (argc<2) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_image_destroy image".');
		exit;
	end;
	
	for arg_index:=1 to argc-1 do begin
		image_name:=Tcl_ObjString(argv[arg_index]);
		dispose_named_images(image_name);
	end;
	
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_image_destroy:=Tcl_OK;
end;

{
<p>lwdaq_photo_contents returns a byte array containing gray-scale intensity array corresponding to a tk photo. The routine uses the red intensity as the gray-scale intensity, which will work in a purely gray-scale image, and assumes that the red intensity is an 8-bit number.</p> 

<p>The routine embeds the image dimensions in the first four pixels of the image by over-writing them with j_size-1 and i_size-1 each as two-byte integers in big-endian format. If the image is one that has been previously stored or drawn by lwdaq routines, the first twelve pixels of the first line will already contain the image dimensions, plus the analysis boundaries, all encoded as two-byte big-endian integers. Because the routine already knows for sure what the image dimensions are, it over-writes dimensions in the first row. But it does not over-write the analysis boundaries. These may be correct or incorrect. You can pass this routine's result to lwdaq_image_create, and have the image-creating routine check the first twelve bytes for valid analysis bounds, or ignore these bounds and use newly-specified bounds.</p> 

<p>To assemble the 8-bit gray-scale image, the routine uses the lwdaq scratch image. If the routine were to allocate and dispose of an image, the printing activity of the disposal when -track_ptrs is set to 1 would alter the TCL return string.</p>
}
function lwdaq_photo_contents(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	photo_name:string='';
	ip:image_ptr_type;
	ph:pointer=nil;
	ihp:image_header_ptr_type=nil;
	pib:Tk_PhotoImageBlock;
	i:integer=0;
	j:integer=0;
	copy_size:integer;
	pp:^intensity_pixel_type;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_photo_contents:=Tcl_Error;

	if (argc<2) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, must be "'
				+'lwdaq_photo_contents photo".');
		exit;
	end;
		
	photo_name:=Tcl_ObjString(argv[1]);
	ph:=Tk_FindPhoto(interp,PChar(photo_name));
	if ph=nil then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Photo "'+photo_name+'" does not exist in '
			+'lwdaq_photo_contents.');
		exit;
	end;
	Tk_PhotoGetImage(ph,@pib);
	with pib do begin
		dispose_named_images(scratch_image_name);
		ip:=new_image(height,width);
		ip^.name:=scratch_image_name;

		pp:=pointer(pixelptr);
		for j:=0 to height-1 do begin
			for i:=0 to width-1 do begin
				set_px(ip,j,i,pp^);
				pp:=pointer(qword(pp)+pixelSize);
			end;
		end;
	end;

	ihp:=pointer(@ip^.intensity[0]);
	ihp^.i_max:=big_endian_from_local_smallint(ip^.i_size-1);
	ihp^.j_max:=big_endian_from_local_smallint(ip^.j_size-1);
	copy_size:=ip^.i_size*ip^.j_size*sizeof(intensity_pixel_type);

	if error_string='' then begin
		Tcl_SetReturnByteArray(interp,@ip^.intensity[0],copy_size);
	end else Tcl_SetReturnString(interp,error_string);
	lwdaq_photo_contents:=Tcl_OK;
end;

{
<p>lwdaq_image_characteristics returns a string of numbers, each of which is some characteristic of the image. We list the characteristics in the table below. The first row of the table gives the first number in the return string. The last row gives the last number.</p>

<center><table border>
<tr><th>Index</th><th>Characteristic</th><th>Description</th></tr>
<tr><td>0</td><td>left</td><td>the left column of the analysis bounds</td></tr>
<tr><td>1</td><td>top</td><td>the top row of the analysis bounds</td></tr>
<tr><td>2</td><td>right</td><td>the right column of the analysis bounds</td></tr>
<tr><td>3</td><td>bottom</td><td>the bottom row of the analysis bounds</td></tr>
<tr><td>4</td><td>ave</td><td>the average intensity in the analysis bounds</td></tr>
<tr><td>5</td><td>stdev</td><td>the standard deviation of intensity in the analysis bounds</td></tr>
<tr><td>6</td><td>max</td><td>the maximum intensity in the analysis bounds</td></tr>
<tr><td>7</td><td>min</td><td>the minimum intensity in the analysis bounds</td></tr>
<tr><td>8</td><td>height</td><td>the number of rows in the image</td></tr>
<tr><td>9</td><td>width</td><td>the number of colums in the image</td></tr>
</table><small><b>Table:</b> Options for lwdaq_characteristics.</small></center>

<p>The lwdaq_image_characteristics routine does not use the global fsr and fsd parameters to format its output. Instead, it always provides one and only one decimal place for its real-valued characteristics.</p>

<pre>set img [LWDAQ_read_image_file Images/Rasnik_skewed.gif]
lwdaq_image_characteristics $img
24 15 680 504 148.5 56.4 255.0 63.0 520 700</pre>

<p>In the example above, we read in a sample image and obtain its characteristics. The analysis boundaries are set at column 24 on the left, row 15 on the top, column 680 on the right, and row 504 on the bottom. The average intensity in the image is 148.5. The standard deviation of intensity is 56.4. The maximum intensity is 255.0, which is the maximum value possible with eight-bit gray-scale images. The minimum intensity is 63.0. The number of rows in the image is 520 and the number of columns is 700.</p>
}
function lwdaq_image_characteristics(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	image_name:string='';
	result:string='';
	ip:image_ptr_type;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_characteristics:=Tcl_Error;
	
	if (argc<2) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, must be "'
				+'lwdaq_image_characteristics image".');
			exit;
	end;
		
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_image_characteristics.');
		exit;
	end;
	
	with ip^.analysis_bounds do
		writestr(result,left:1,' ',top:1,' ',right:1,' ',bottom:1,' ',
			image_average(ip):1:1,' ',image_amplitude(ip):1:1,' ',
			image_maximum(ip):1:1,' ',image_minimum(ip):1:1,' ',
			ip^.j_size:1,' ',ip^.i_size:1);

	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_image_characteristics:=Tcl_OK;
end;

{
<p>lwdaq_image_histogram returns a histogram of image intensity within the analysis bounds of an image. The histogram takes the form of an x-y graph in a space-delimited string, with the x-coordinate representing intensity, and the y-coordinate representing frequency. Suppose we apply the histogram routine to a 20&times;20 image and we assume that the pixel intensities range from 0 to 3. The string "0 100 1 210 2 40 3 50" confirms that there are 400 pixels in the image, 100 with intensity 0, 210 with intensity 1, and so on.</p>
}
function lwdaq_image_histogram(data,interp:pointer;argc:integer;
	var argv:Tcl_ArgList):integer;

var 
	image_name:string='';
	result:string='';
	hg:xy_graph_type;
	ip:image_ptr_type;
	i:integer;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_histogram:=Tcl_Error;
	
	if (argc<2) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_image_histogram image".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_image_histogram.');
		exit;
	end;
	
	hg:=image_histogram(ip);
	for i:=0 to length(hg)-1 do
		writestr(result,result,hg[i].x:1:0,' ',hg[i].y:1:0,' ');
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_image_histogram:=Tcl_OK;
end;


{
<p>lwdaq_image_profile returns a list of the average intensity in the analysis boundaries along the row or column directions.  The profile takes the form of series of numbers in a space-delimited decimal string. The first number of a row profile is the average intensity of pixels in the leftmost column of the analysis boundaries. The last number is the average intensity of the right-most column. The first number of a column profile is the average intensity of the topmost row in the analysis boundaries. The last number is the average intensity of the bottom row. To obtain the row profile, use option -row 1, which is the default. To obtain the column profile, use -row 0.</p>
}
function lwdaq_image_profile(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	option:string;
	arg_index:integer;
	image_name:string='';
	result:string='';
	pp:x_graph_type;
	ip:image_ptr_type;
	vp:pointer;	
	i:integer;
	row:boolean=true;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_profile:=Tcl_Error;
	
	if (argc<2) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_image_profile image".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_image_profile.');
		exit;
	end;
	
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-row') then row:=Tcl_ObjBoolean(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-row" in lwdaq_image_profile.');
			exit;
		end;
	end;

	if row then pp:=image_profile_row(ip)
	else pp:=image_profile_column(ip);
	for i:=0 to length(pp)-1 do writestr(result,result,pp[i]:fsr:fsd,' ');

	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_image_profile:=Tcl_OK;
end;

{
<p>lwdaq_image_exists returns a list of images in the lwdaq image list that match the image_name pattern we pass to the routine. If we pass "*", it will return a list of all existing images. If there are no matching images, lwdaq_image_exists returns an empty string.</p>
}
function lwdaq_image_exists(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	option:string;
	result:string='';
	arg_index:integer;
	image_name:string='*';
	vp:pointer;	
	verbose:boolean=false;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_exists:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_image_exists image ?option value?".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);

	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-verbose') then verbose:=Tcl_ObjBoolean(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-verbose" in '
				+'lwdaq_image_exists.');
			exit;
		end;
	end;

	write_image_list(result,image_name,verbose);
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_image_exists:=Tcl_OK;
end;

{
<p>lwdaq_image_results returns an image's results string. When read from disk, and image  result string cannot exceed the length of the first row in bytes minus the image header bytes.</p>
}
function lwdaq_image_results(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	image_name:string='';
	ip:image_ptr_type;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_results:=Tcl_Error;
	
	if (argc<2) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_image_results image".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_image_results.');
		exit;
	end;
	
	if error_string='' then Tcl_SetReturnString(interp,ip^.results)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_image_results:=Tcl_OK;
end;

{
<p>lwdaq_image_manipulate returns the name of a new image derived from one or more images passed to lwdaq_image_manipulate. If we set the -replace option to 1, the routine replaces the original image with the new image. The command takes the name of an image in the LWDAQ image list, and the name of a manipulation to be performed upon this image. The currently-supported manipulations are as follows.</p>

<center><table border cellspacing=2>
<tr><th>Manipulation</th><th>Function</th></tr>
<tr><td>none</td><td>No manipulation of pixels, the new image is the old image.</td></tr>
<tr><td>accumulate</td><td>Add second image to first, subtract average intensity of second..</td></tr>
<tr><td>bounds_subtract</td><td>Subtract a second image from the first within the analysis bounds.</td></tr>
<tr><td>combine</td><td>Replaces a portion of the image.</td></tr>
<tr><td>copy</td><td>Copy the image into a new image.</td></tr>
<tr><td>crop</td><td>Crop the image to its analysis boundaries.</td></tr>
<tr><td>enlarge_<i>n</i></td><td>Enlarge the image by an integer factor <i>n</i>, where values 2, 3, and 4 are supported.</td></tr>
<tr><td>grad_i</td><td>Magnitude of the horizontal intensity derivative.</td></tr>
<tr><td>grad_i_s</td><td>Horizontal intensity derivative, signed.</td></tr>
<tr><td>grad_j</td><td>Magnitude of the vertical intensity derivative.</td></tr>
<tr><td>grad_j_s</td><td>Vertical intensity derivative, signed.</td></tr>
<tr><td>grad</td><td>Magnitude of the intensity gradient.</td></tr>
<tr><td>invert</td><td>Turn image upside-down by reversing order of pixels. Top-left becomes bottom-right.</td></tr>
<tr><td>negate</td><td>Negate the image. Each pixel will have value max_intensity &minus; original_intensity.</td></tr>
<tr><td>rasnik</td><td>Create an artificial rasnik pattern in the image.</td></tr>
<tr><td>reverse_rows</td><td>Reverse the order of the rows. The top row becomes the bottom row.</td></tr>
<tr><td>rows_to_columns</td><td>Top row becomes left column, left column becomes top row.</td></tr>
<tr><td>rotate</td><td>Rotate the image about a point by an angle in radians.</td></tr>
<tr><td>shrink_<i>n</i></td><td>Shrink the image by an integer factor <i>n</i>, where values 2, 3, and 4 are supported.</td></tr>
<tr><td>soec</td><td>Swap odd and even columns.</td></tr>
<tr><td>soer</td><td>Swap odd and even rows.</td></tr>
<tr><td>smooth</td><td>Smooth with 3&times;3 box filter and add contrast.</td></tr>
<tr><td>subtract</td><td>Subtract a second image from the first image.</td></tr>
<tr><td>subtract_row</td><td>Subtract the row average intensity from all pixels in each row.</td></tr>
<tr><td>subtract_gradient</td><td>Subtract the average gradient intensity from all pixels.</td></tr>
<tr><td>transfer_overlay</td><td>Transfer the overlay of a second image into the overlay of the first image.</td></tr>
</table><b>Table:</b> Manipulation Codes and their Functions. All codes create a new image, except for <i>none</i>. With -replace 1 the old image will be replaced by the new image. With -replace 0, the new image will be distinct, with a distinct name.</center>

<p>The <i>none</i> manipulation does nothing. It does not return a new image. Instead, the <i>none</i> manipulation allows us to manipulate an existing image's analysis boundaries, result string, and overlay pixels.</p>

<p>The <i>accumulate</i> option allows us to combine the contrast of two images. It adds the intensity of the two images together, subtracts the average intensity of each image, and adds the mid-intensity value, which is 128 in eight-bit images. If we have ten dim x-ray images of the same device, we can add them together with the accumulate instruction so as to obtain an image with better contrast.</p>

<p>The <i>bounds_subtract</i> manipulation is like <i>subtract</i>, but applies the subtraction only within the analysis bounds of the first image. Elsewhere, the difference image is equal to the first image.</p>

<p>The <i>copy</i> manipulation makes a copy of an image. By default, the name of the copy will be the name of the original, which is inconvenient. So we should use the -name option with <i>copy</i> to specify a name for the copy. As always, when we specify a name, all existing images with that name will be deleted to make way for the new image, thus assuring us that the new image is the only one with its name. With the -replace option we disturb the behavior of the <i>copy</i> manipulationg by deleting the original image and replacing it with the copy.</p>

<p>The <i>invert</i>, <i>reverse_rows</i>, and <i>rows_to_columns</i> operations can be combined to obtain arbitrary square rotations of an image, as well as mirroring. If we want to rotate an image by 90&deg; clockwise, we use <i>reverse_rows</i> followed by <i>rows_to_columns</i>. If we want to make the top-left corner the bottom-right corner while keeping the bottom-left corner in place, which is a rotation and a reflection, we use <i>invert</i> and then <i>rows_to_columns</i>.</p>

<p>The <i>combine</i> manipulation allows you to write over the data in an image, starting with the <i>offset</i>'th pixel. You specify <i>offset</i> after the data. The manipulation copies the entire contents of an <i>m</i>-byte binary block into the image, starting at pixel <i>offset</i>, and ending at pixel <i>offset+m-1</i>. If the copy goes past the end of the image array, the manipulation aborts without doing anything, and returns an error.</p>

<p>The <i>crop</i> manipulation extracts the pixels inside the analysis boundaries of the original image, and creates a new image containing only these pixels. The dimensions of the new image will be those of the original analysis boundaries, but with one extra row at the top to accommodate an image header when we save to disk. The new analysis boundaries will include the entire image except for row zero.</p>

<p>The <i>grad</i> manipulations either return an absolute intensity gradient or a signed intensity gradient. We calculate the horizontal gradient at pixel (i,j) by subtracting the intensity of pixel (i-1,j) from that of pixel (i+1,j). The vertical gradient is (i,j+1) minus (i,j-1). When we return the magnitude of the gradient, the intensity of the gradient image is simply the absolute value of the gradient. When we return the signed gradient, we offset the gradient image intensity by mid_intensity, which is 128 for eight-bit gray scale images. Thus an intensity of 128 means zero gradient, and an intensity of 138 means +10. When the gradient exceeds 127 or -128, we clip its value to 255 and 0 respectively. For more details, see the image_filter and subsequent routine in <a href="../../Software/Sources/image_manip.pas">image_manip.pas</a>.</p>

<p>The <i>rasnik</i> manipulation draws a rasnik pattern in the image. We specify the rasnik pattern with a string of seven numbers: origin.x, origin.y, pattern_x_width, pattern_y_width, rotation, sharpness, and noise amplitude. The origin is the image coordinates of the top-left corner of one of the squares in the chessboard. Units are pixels, not mircons. The x and y width of the squares are in the near-horizontal and near-vertical direction respectively. Units are pixels again. The rotation is counter-clockwise in milliradians of the pattern with respect to the sensor. With sharpness 1, the pattern has sinusoidal intensity variation from black to white. With sharpness less than 1, the amplitude of the sinusoidal variation decreases in proportion. With sharpness greater than one, the sinusoidal amplitude increases in proportion, but is clipped to black and white intensity, so that we obtain a sharply-defined chessboard. With sharpness 0.01 we obtain an image with alternating circles of intensity one count above and below the middle intensity, set in a field of middle intensity, as shown <a href="../../Devices/Rasnik/Sharpness_001.jpg">here</a>. When we differentiate such an image in the horizontal direction, we get <a href="../../Devices/Rasnik/Sharpness_001_grad_i.gif">this</a>, which defeats our frequency-based rasnik analysis. We can add noise to our simulated image with the noise amplitude parameter. If we set this to 1.0, we add a random number between 0.0 and 1.0 to each pixel.</p>

<pre>lwdaq_image_manipulate image_name rasnik "0 0 20 30 2 10" -replace 1</pre>

<p>In the above example, the the existing image would be replaced by a new image containing a rasnik pattern with origin at the top-left corner of the top-left pixel in the image, each square 20 pixels wide and 30 pixels high, rotated by 2 mrad anti-clockwise, with sharp edges.</p>

<p>The <i>rotate</i> manipulation rotates the entire image about a point. Do not use this routine to rotate an image in the traditional sense or right, left, or invert rotations. The routine is designed to perform non-square rotations, and will always lose some of the image that falls off the sides when we rotate. Use combinations of reverse_rows, rows_to_columns, and invert to produce traditional rotations. We specify the rotation in radians. We specify the point in <i>image coordinates</i>, where point (0,0) is the top-left corner of the top-left pixel, the <i>x</i>-axis runs left to right, the <i>y</i>-axis runs top to bottom, and the units of length are pixels. The point (0.5,0.5) is the center of the top-left pixel. The point (199.5,99.5) is the center of the pixel in the 200'th column and 100'th row. When we rotate a rectangular image, some parts will leave the rectangular image area. These are lost by the rotation manipulation. Opposite to these losses are regions where there is no intensity information to fill in the image area. These regions we fill in with pixels intensity equal to the average intensity of the original image within its analysis bounds. The rotation is applied to the entire image, not just the analysis area.</p>

<p>The <i>smooth</i> manipulation applies a 3&times;3 average filter to the image within the analysis boundaries. The value of pixel (i, j) in the new image will be proportional to the sum of the pixels (i-1..i+1, j-1..j+1) in the original image. One of the potential benifits of smoothing is to attenuate stochastic noise. We would like the smoothing to attenuate quantization noise in very dim images. But if we add the nine pixels in the 3&times;3 block together and dividing by nine to obtain their average, we find that our average itself suffers from quantization noise. For example, suppose eight pixels have value 100 and the ninth is 101. The average should be 100.1, but this will be rounded to 100. The smooth routine calculates the average value of the nine pixels and stores them in an array of real values. Once the array is complete, the routine tranforms the minimum to maximum range in the real-valued array into the pixel value range in the final image. If the smoothed values ranged from 98 to 102 and the final image pixels can be 0 to 255, the smooth routine transforms 98 to 0 and 102 to 255. Thus we obtain the best possible contrast in the final image, and we do the best we can to remove quantization noise.</p>

<p>The <i>subtract</i> manipulation requires you to name a second image, which will be subtracted from the first to create a third image. The two images must have the same dimensions. All pixels in the second images will be subtracted from the first image. The third image, being the difference, will be the same dimensions as the first two.</p>

<p>The <i>subtract_row</i> manipulation does not require a second image. It operates only upon the image within the analysis boundaries. Pixels outside the analysis boundaries are unchanged. Within the analysis boundaries, we subtract the average intensity of each row from the pixels in the row. The row average we obtain from the pixels in the row that lie within the analysis boundaries. In addition, we offset the intensity of the pixels in the analysis boundaries so that the intensity of the top-left pixel in the analysis bounds remains unchanged.</p>

<p>The <i>subtract_gradient</i> manipulation does not require a second image. We determine the gradient of intensity within the analysis boundaries. We measure the slope of the vertical and horizontal intensity profiles and use these to obtain the two-dimensional gradient. We subtract the intensity due to the gradient from each pixel in the analysis boundaries, but not from those outside the analysis boundaries. We thus remove both the horizontal and vertical intensity slopes from the image. We offset the intensity within the analysis boundaries so that the intensity of the top-left pixel in the analysis bounds remains unchanged.</p>

<p>The <i>transfer_overlay</i> manipulation copies the overlay of a second image into the overlay of the first. This manipulation is the only one operating upon the image ovelays. Each image has an overlay area whose colors we draw on top of the image when we display the image on the screen. Thus we can use the overlay to mark features in the image without corrupting the image itself. The overlay transfer scales the original overlay so that it fits into the rectangle of the new image. We can shrink a large image by a factor of four, analyze the quarter-sized image, record the results of analysis in the overlay, and transfer the overlay back into the original full-sized image. The transfer will make sure that the markings are aligned correctly with the features in the original image.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-name value</td><td>The name of the new image will be value.</td></tr>
<tr><td>-results value</td><td>Set the new image results string to value.</td></tr>
<tr><td>-replace value</td><td>If value is 1, delete the original image and replace with new image, default.</td></tr>
<tr><td>-clear value</td><td>If value is 1, clear overlay of final image, default 0.</td></tr>
<tr><td>-fill value</td><td>If value is 1, fill overlay of final image with white, default 0.</td></tr>
<tr><td>-paint value</td><td>Paint the overlay within the analysis bounds with eight-bit color value, default 0.</td></tr>
<tr><td>-bottom value</td><td>Set the bottom of the analysis bounds to value.</td></tr>
<tr><td>-top value</td><td>Set the top of the analysis bounds to value.</td></tr>
<tr><td>-left value</td><td>Set the left of the analysis bounds to value.</td></tr>
<tr><td>-right value</td><td>Set the rigth of the analysis bounds to value.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_manipulate.</small></center>

<p>With -name you specify the name of the new image created by the manipulation, or the existing image if there is no new image created by the manipulation. Any pre-existing images with this name will be destroyed before the name change occurs.</p>

<p>With -replace 0, the manipulation creates a new image and returns its name. With -replace 1, the manipulation over-writes data in the old image and returns the old image name.</p>

<p>The -paint option instructs lwdaq_image_manipulate to paint the entire area within the analysis bounds with the color given by <i>value</i>. This value should be a number between 0 and 255. The value 0 is for transparant. Other than the 0-value, the number will be treated like an eight-bit RGB code, with the top three bits for red, the middle three for green, and the bottom three for blue. Thus $E0 (hex E0) is red, $1C is green, and $03 is blue. Note that paint does not convert value into one of LWDAQ's standard graph-plotting colors, as defined in the overlay_color routine of images.pas, and used in <a href="#lwdaq_graph">lwdaq_graph</a>.</p>

<p>In addition to the pixel manipulations, we also have options to change other secondary properties of the image. The table above shows the available manipulation options, each of which is followed by a value in the command line, in the format ?option value?.</p>

<p>When you specify the analysis bounds, a value of &minus;1 is the code for "do nothing". The boundary will remain as it was. This use of the &minus;1 code contasts with that of lwdaq_image_create, where &minus;1 directs lwdaq_image_create to move the boundary to the edge of the image.</p>
}
function lwdaq_image_manipulate(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	option:string;
	arg_index:integer;
	center:xy_point_type;
	rotation:real=0;
	image_name:string='';
	second_image_name:string='';
	name:string='';
	manipulation:string='none';
	results:string=null_code;
	left:integer=-1;
	right:integer=-1;
	top:integer=-1;
	bottom:integer=-1;
	paint:integer=-1;
	replace:boolean=false;
	clear:boolean=false;
	fill:boolean=false;
	ip,nip,ip_2:image_ptr_type;
	vp:pointer;	

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_image_manipulate:=Tcl_Error;
{
	This routine needs at least three arguments: the routine name, the image name, and
	the manipulation name.
}
	if (argc<3) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be '
			+'"lwdaq_image_manipulate image_name manipulation ?option value?".');
		exit;
	end;
{
	Get the image name and manipulation name.
}
	arg_index:=1;
	image_name:=Tcl_ObjString(argv[arg_index]);
	inc(arg_index);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_image_manipulate.');
		exit;
	end;
	manipulation:=Tcl_ObjString(argv[arg_index]);
	inc(arg_index);
{
	Perform the specified manipulation.
}
	if manipulation='copy' then nip:=image_copy(ip)
	else if manipulation='grad_i' then nip:=image_grad_i(ip)
	else if manipulation='grad_i_s' then nip:=image_filter(ip,-1,0,1,0,1,0,1)
	else if manipulation='grad_j' then nip:=image_grad_j(ip)
	else if manipulation='grad_j_s' then nip:=image_filter(ip,0,1,0,-1,0,1,1)
	else if manipulation='grad' then nip:=image_grad(ip)
	else if manipulation='smooth' then nip:=image_filter(ip,1,1,1,1,1,1,0)
	else if manipulation='shrink_2' then nip:=image_shrink(ip,2)
	else if manipulation='enlarge_2' then nip:=image_enlarge(ip,2)
	else if manipulation='shrink_3' then nip:=image_shrink(ip,3)
	else if manipulation='enlarge_3' then nip:=image_enlarge(ip,3)
	else if manipulation='shrink_4' then nip:=image_shrink(ip,4)
	else if manipulation='enlarge_4' then nip:=image_enlarge(ip,4)
	else if manipulation='rotate' then begin
		if argc<arg_index+3 then begin
			Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be '
			+'"lwdaq_image_manipulate image_name '+manipulation
			+' center_x_pixels center_y_pixels rotation_mrad".');
			exit;
		end;
		rotation:=Tcl_ObjReal(argv[arg_index]);
		inc(arg_index);
		center.x:=Tcl_ObjReal(argv[arg_index]);
		inc(arg_index);
		center.y:=Tcl_ObjReal(argv[arg_index]);
		inc(arg_index);
		nip:=image_rotate(ip,rotation,center);
	end else if manipulation='negate' then nip:=image_negate(ip)
	else if manipulation='invert' then nip:=image_invert(ip)
	else if manipulation='crop' then nip:=image_crop(ip)
	else if manipulation='reverse_rows' then nip:=image_reverse_rows(ip)
	else if manipulation='rows_to_columns' then nip:=image_rows_to_columns(ip)
	else if manipulation='soec' then nip:=image_soec(ip)
	else if manipulation='soer' then nip:=image_soer(ip)
	else if manipulation='subtract_row' then nip:=image_subtract_row_average(ip)
	else if manipulation='subtract_gradient' then nip:=image_subtract_gradient(ip)
	else if (manipulation='subtract') or (manipulation='bounds_subtract') 
			or (manipulation='transfer_overlay') or (manipulation='accumulate') then begin
		if argc<arg_index+1 then begin
			Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be '
			+'"lwdaq_image_manipulate image_name '+manipulation
			+' second_image ?option value?".');
			exit;
		end;
		second_image_name:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		ip_2:=image_ptr_from_name(second_image_name);
		if not valid_image_ptr(ip_2) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Image "'+second_image_name+'" does not exist in '
				+'lwdaq_image_manipulate.');
			exit;
		end;
		if manipulation='subtract' then nip:=image_subtract(ip,ip_2)
		else if manipulation='accumulate' then nip:=image_accumulate(ip,ip_2)
		else if manipulation='bounds_subtract' then nip:=image_bounds_subtract(ip,ip_2)
		else begin
			image_transfer_overlay(ip,ip_2);
			nip:=ip;
		end;
	end else if manipulation='none' then begin 
		nip:=ip;
	end else if manipulation='rasnik' then begin
		nip:=ip;
		if argc<arg_index+1 then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, must be '
				+'"lwdaq_image_manipulate image_name rasnik commands ?option value?".');
			exit;
		end;
		rasnik_simulated_image(nip,Tcl_ObjString(argv[arg_index]));
		inc(arg_index);
	end else begin
		Tcl_SetReturnString(interp,error_prefix
			+'Bad manipulation "'+manipulation
			+'", must be one of "none accumulate copy crop enlarge_2 enlarge_3 enlarge_4 '
			+'grad grad_i grad_i_s grad_j grad_j_s negate '
			+'invert reverse_rows rows_to_columns '
			+'shrink_2 shrink_3 shrink_4 smooth subtract subtract_bounds subtract_row '
			+'subtract_gradient transfer_overlay soec soer" in '
			+'lwdaq_image_manipulate.');
		exit;
	end;
{
	Scan the command arguments for option specifiers and record their values.
	If we encounter an invalid argument beginning with a hyphen, we report
	an error.
}
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-name') then name:=Tcl_ObjString(vp)
		else if (option='-results') then results:=Tcl_ObjString(vp)
		else if (option='-replace') then replace:=Tcl_ObjBoolean(vp)
		else if (option='-bottom') then bottom:=Tcl_ObjInteger(vp)
		else if (option='-top') then top:=Tcl_ObjInteger(vp)
		else if (option='-left') then left:=Tcl_ObjInteger(vp)
		else if (option='-right') then right:=Tcl_ObjInteger(vp)
		else if (option='-clear') then clear:=Tcl_ObjBoolean(vp)
		else if (option='-fill') then fill:=Tcl_ObjBoolean(vp)
		else if (option='-paint') then paint:=Tcl_ObjInteger(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-name -results -replace -bottom -top -left -right '
				+'-clear -paint in '
				+'lwdaq_image_manipulate.');
			exit;
		end;
	end;
{
	Perform the option modifications to the new image.
}
	if replace and (nip<>ip) then begin
		nip^.name:=ip^.name;
		dispose_image(ip);
	end;
	if results<>null_code then begin
		nip^.results:=leftstr(results,nip^.i_size-image_header_len);
	end;
	if left<>-1 then begin
		if (left>0) and (left<nip^.i_size) then
			nip^.analysis_bounds.left:=left
		else
			nip^.analysis_bounds.left:=0;
	end;
	if right<>-1 then begin
		if (right>left) and (right<nip^.i_size) then
			nip^.analysis_bounds.right:=right
		else 
			nip^.analysis_bounds.right:=nip^.i_size-1;
	end;
	if top<>-1 then begin
		if (top>1) and (top<nip^.j_size) then
			nip^.analysis_bounds.top:=top
		else
			nip^.analysis_bounds.top:=1;
	end;
	if bottom<>-1 then begin
		if (bottom>top) and (bottom<nip^.j_size) then
			nip^.analysis_bounds.bottom:=bottom
		else
			nip^.analysis_bounds.bottom:=nip^.j_size-1;
	end;
	if name<>'' then begin
		while valid_image_name(name) do
			dispose_image(image_ptr_from_name(name));
		nip^.name:=name;
	end;
	if clear then clear_overlay(nip);
	if fill then fill_overlay(nip);
	if paint>=0 then paint_overlay_bounds(nip,paint);
{
	If we encountered no errors, return the name of the new image.
	Otherwise return the error message and dispose of any new image
	we may have created.
}
	if error_string='' then Tcl_SetReturnString(interp,nip^.name)
	else begin
		Tcl_SetReturnString(interp,error_string);
		if nip<>ip then dispose_image(nip);
	end;
	lwdaq_image_manipulate:=Tcl_OK;
end;

{
<p>lwdaq_data_manipulate operates upon the data in an image, and we intend it for use with instruments that store one-dimensional arrays of data in an image's intensity array. Our convention, when using the intensity array in this way, is to start storing data in the first column of the second row. This leaves the first row free for header information when we store the image to disk. We refer to the block of memory starting with the first byte of the second row, and ending with the last byte of the last row, as the <i>data space</i>. We specify bytes in the data space with their <i>byte address</i>, which is zero at the first byte in the data space. The routine returns a byte array in the case of the <i>read</i> manipulation, or an empty string otherwise. In the event of an error, it returns an error description. The <i>write</i>, <i>shift</i>, and <i>clear</i> manipulations affect the data in the image.</p>

<center><table border cellspacing=2>
<tr><th>Manipulation</th><th>Function</th></tr>
<tr><td>write</td><td>Writes a block of data into the data space.</td></tr>
<tr><td>read</td><td>Reads a block of data from the data space.</td></tr>
<tr><td>shift</td><td>Shifts data towards start of data space.</td></tr>
<tr><td>clear</td><td>Clears the data.</td></tr>
<tr><td>none</td><td>No action.</td></tr></table><small><b>Table:</b> Options for lwdaq_data_manipulate.</small></center>

<p>The <i>write</i> function requires two parameters: the data you wish to write to the data space and the byte address at which you want the first byte of your data to be written. The following command writes the contents of <i>data</i> to the data space of the image named <i>image_name</i> starting at the first byte in the data space (which is the first pixel in the second row).</p>

<pre>lwdaq_data_manipulate image_name write 0 $data</pre>

<p>The <i>read</i> function requires two parameters: the number of bytes you wish to read from the data space and the byte address at which you want to start reading. The following command reads 10000 bytes starting at byte address 100, and returns them as a byte array. If the image has 100 pixels per row, the first byte the routine reads will be the first pixel in the third row of the image.</p>

<pre>lwdaq_data_manipulate image_name read 100 10000</pre>

<p>The following commands read 200 bytes from the image, starting with the 50'th byte, and transforms them into a list of signed integers, on the assumption that the 200 bytes represent 100 consecutive, two-byte signed binary values with the most significant byte first (big-endian byte ordering).</p>

<pre>lwdaq_data_manipulate image_name read 50 200</pre>

<p>The <i>shift</i> function requires one parameter: the number of bytes to the left by which you want the data to be shifted. Shifting to the left is in the direction of the start of the data space. If you specify a negative shift, the routine shifts the data to the right, in the direction of the end of the data space.</p>

<p>The <i>clear</i> function takes no parameters. It clears all the byte in the data space to zero.</p>
}
function lwdaq_data_manipulate(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	arg_index:integer;
	image_name:string='';
	manipulation:string='none';
	ip,nip:image_ptr_type;
	data_obj:pointer=nil;
	data_ptr:pointer=nil;
	data_size:integer=0;
	intensity_size:integer=0;
	byte_address:integer=-1;
	shift:integer=0;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_data_manipulate:=Tcl_Error;
{
	This routine needs at least three arguments: the routine name, the image name, and
	the manipulation name.
}
	if (argc<3) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be '
			+'"lwdaq_data_manipulate image_name manipulation ?parameters?".');
		exit;
	end;
{
	Get the image name and manipulation name.
}
	arg_index:=1;
	image_name:=Tcl_ObjString(argv[arg_index]);
	inc(arg_index);
	ip:=image_ptr_from_name(image_name);
	intensity_size:=ip^.j_size*ip^.i_size*sizeof(intensity_pixel_type);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_data_manipulate.');
		exit;
	end;
	manipulation:=Tcl_ObjString(argv[arg_index]);
	inc(arg_index);
{
	Perform the specified manipulation.
}
	if manipulation='write' then begin
		if argc<arg_index+2 then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Specify byte_address and data in '
				+'lwdaq_data_manipulate.');
			exit;
		end;
		byte_address:=Tcl_ObjInteger(argv[arg_index]);
		inc(arg_index);
		if byte_address<0 then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Start address less than zero in '
				+'lwdaq_data_manipulate.');
			exit;
		end;
		data_obj:=argv[arg_index];
		inc(arg_index);
		data_ptr:=Tcl_GetByteArrayFromObj(data_obj,data_size);
		if byte_address+data_size>intensity_size-ip^.i_size then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Data extends past end of image "'
				+image_name+'" in '
				+'lwdaq_data_manipulate.');
			exit;
		end;
		block_move(data_ptr,
			pointer(qword(@ip^.intensity[ip^.i_size])+byte_address),
			data_size);
		Tcl_SetReturnString(interp,'');
	end else if manipulation='read' then begin
		if argc<arg_index+2 then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Specify data size and byte address in '
				+'lwdaq_data_manipulate.');
			exit;
		end;
		byte_address:=Tcl_ObjInteger(argv[arg_index]);
		inc(arg_index);
		if byte_address<0 then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Start address less than zero in '
				+'lwdaq_data_manipulate.');
			exit;
		end;
		data_size:=Tcl_ObjInteger(argv[arg_index]);
		inc(arg_index);
		if data_size=0 then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Requested data size zero in '
				+'lwdaq_data_manipulate.');
			exit;
		end;
		if byte_address+data_size>intensity_size-ip^.i_size then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Requested data extends past end of image "'
				+image_name+'" in lwdaq_data_manipulate.');
			exit;
		end;
		Tcl_SetReturnByteArray(interp,
			pointer(qword(@ip^.intensity[ip^.i_size])+byte_address),
			data_size);
	end else if manipulation='shift' then begin
		if argc<arg_index+1 then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Specify shift in bytes, positive left in '
				+'lwdaq_data_manipulate.');
			exit;
		end;
		shift:=Tcl_ObjInteger(argv[arg_index]);
		nip:=new_image(ip^.j_size,ip^.i_size);
		if nip=nil then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Failed to allocate memory for new image in '
				+'lwdaq_data_manipulate.');
			exit;
		end;
		if shift>0 then begin
			block_move(pointer(qword(@ip^.intensity[ip^.i_size])+shift),
				@nip^.intensity[nip^.i_size],
				intensity_size-ip^.i_size-shift);
		end else begin
			block_move(@ip^.intensity[ip^.i_size],
				pointer(qword(@nip^.intensity[nip^.i_size])+shift),
				intensity_size-ip^.i_size-shift);
		end;
		block_move(@nip^.intensity[nip^.i_size],@ip^.intensity[ip^.i_size],intensity_size-ip^.i_size);
		dispose_image(nip);
		Tcl_SetReturnString(interp,'');
	end else if manipulation='clear' then begin
		with ip^ do block_clear(@intensity[ip^.i_size],intensity_size-ip^.i_size);
		Tcl_SetReturnString(interp,'');
	end else if manipulation='none' then begin 
		{no action}
	end else begin
		Tcl_SetReturnString(interp,error_prefix
			+'Bad manipulation "'+manipulation
			+'", must be one of "read write shift clear none" in '
			+'lwdaq_data_manipulate.');
		exit;
	end;
{
	If we have an error, return error string and report okay to interpreter.
}
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_data_manipulate:=Tcl_OK;
end;

{
<p>lwdaq_bcam finds spots in images. It is used by the <a href="https://www.bndhep.net/Electronics/LWDAQ/Manual.html#BCAM">BCAM Instrument</a> to analyze BCAM images. The routine clears the image overlay for its own use. By default, lwdaq_bcam returns six numbers for each of the spots it finds. In the example below, we read a sample image and apply BCAM analysis, asking for the location of two spots.</p>

<pre>set img [LWDAQ_read_image_file Images/BCAM_tape.gif]
lwdaq_bcam $img -num_spots 2 -threshold "10 #"
2681.66 964.12 2313 72 0.556 62 959.30 883.76 2306 72 0.499 62</pre>

<p>The first two numbers for each spot are the x and y position in microns of the spot, or the x position in microns and the anticlockwise rotation in milliradians. Position (0,0) is the top-left corner of the top-left pixel in the image. Rotation zero is vertical. The third value is an integer giving the number of pixels in the spot. The fourth value is an integer giving the intensity of the brightest pixel in the spot. The fifth number is the derivative of spot position with analysis threshold. The sixth number is an integer giving the threshold intensity used to distinguish between pixels that are bright enough to be in a spot and those that are not. This threshold intensity may have been specified directly by an absolute threshold string, or it may have been deduced from the image itself with the use of a threshold symbol.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-num_spots</td><td>The number of spots the analysis should find.</td></tr>
<tr><td>-threshold</td><td>String specifying threshold intensity and spot size.</td></tr>
<tr><td>-color</td><td>Color for spot outlining in overlay, default red.</td></tr>
<tr><td>-pixel_size_um</td><td>Tells the analysis the pixel size (assumed square)</td></tr>
<tr><td>-show_timinig</td><td>If 1, print timing report to gui text window.</td></tr>
<tr><td>-show_pixels</td><td>If 1, mark pixels above threshold.</td></tr>
<tr><td>-analysis_type</td><td>Selects analysis type, default weighted centroid.</td></tr>
<tr><td>-sort_code</td><td>Specifies how the spots are to be sorted in the output string.</td></tr>
<tr><td>-return_threshold</td><td>If 1, return threshold string results only, default 0.</td></tr>
<tr><td>-return_bounds</td><td>If 1, return spot bounds only, default 0.</td></tr>
<tr><td>-return_intensity</td><td>If 1, return spot intensity only, default 0.</td></tr>
<tr><td>-add_x_um</td><td>Add this value in microns to the spot x-position, default 0.</td></tr>
<tr><td>-add_y_um</td><td>Add this value in microns to the spot y-position, default 0</td></tr>
<tr><td>-reference_um</td><td>Reference line y-position for line fits, default 0</td></tr>
</table><small><b>Table:</b> Options for lwdaq_bcam.</small></center>

<p>The routine makes a list of spots in the image. The threshold string, included with the -threshold option, tells lwdaq_bcam how to distinguish background pixels from spot pixels. The threshold string must specify a threshold intensity, or a means of calculating a threshold intensity. All the spot-locating routines called by lwdaq_bcam use the <i>net intensity</i> of pixels, which is the image intensity minus the threshold intensity, with negative values clipped to zero.</p>

<p>The threshold string must begin with an integer, <i>t</i>. After <i>t</i> comes an optional <i>threshold symbol</i>. If there is no threshold symbol, the routine assumes the "*" symbol. The "*" symbol tells the routine to use intensity <i>t</i> as the threshold. The string "20 *" means any pixel with intensity 20 or greater is a spot or part of some larger spot. The "%" symbol means that the threshold is some fraction of the way from the minimum image intensity to the maximum intensity, where the minimum and maximum are obtained from within the image analysis boundaries. The value of <i>t</i> is treated as a percentage. The string "10 %" in an image with minimum intensity 40 and maximum intensity 140 results in a threshold of 50. The "#" symbol is similar to the "%" symbol, except the average intensity takes the place of the minimum. The string "10 #" in an image with average intensity 50 and maximum intensity 140 results in a threshold of 59. The "$" symbol means the threshold is <i>t</i> counts above the average intensity. The string "5 $" in an image with average intensity 50 results in a threshold of 55. The "&" symbol uses the median intensity to obtain the threshold. The string "5 &" in an image with median intensity 62 results in a threshold of 67. The "@" symbol uses the minimum intensity to obtain the threshold. String "20 @" in an image with minimum intensity 42 produces a threshold of 62. In each of these calculations, the BCAM analysis also defines a "background" intensity, which it uses only when we want it to calculate and report to us the total brightness of a spot. The background is the average (# and $), minimum (% and @), median (&), or simply zero (*).</p>

<p>Following the threshold value and threshold symbol there are two further, optional criteria we can use to restrict the routine's choice of spots. The first parameter must be an integer, <i>n</i>, which specifies the number of pixels above threshold in a spot. If <i>n</i> is followed by the symbol ">", spots must contain at least <i>n</i> pixels or else they are rejected. The symbol "<" means spots must contain at most <i>n</i> pixels. If the symbol is omitted, we assume <i>n</i> is a minimum.</p>

<p>The next parameter in the threshold  must be a real number, <i>e</i>, which specifies the maximum eccentricity of the spot, which is the maximum ratio of width to height, or height to width. Spots that have greater eccentricity will be rejected by the routine. The second parameter cannot be included without the first, but if you use 0 for the first, the routine ignores the first parameter and moves on to the second.</p>

<p>The lwdaq_bcam routine identifies all distinct sets of contiguous pixels above threshold, eliminates those that do not meet the test criteria, determines the position and total net intensity of each remaining set, sorts them in order of decreasing total net intensity, and eliminates all but the first -num_spots sets. The <i>total net intensity</i> is the sum of the net intensities of all the pixels in the set. By default, the routine returns the position of each spot in microns with respect to the top-left corner of the image. To convert from pixels to microns, the routine uses -pixel_size_um, and assumes the pixels are square.</p>

<p>There are several ways that lwdaq_bcam can analyze an image. We can manipulate the image before analysis, or we can operate on the original image. Regardless of what image the analysis works on, it still drawss the results of analysis in the overlay of the original image so that we will see the results when we display the image. We can find the weighted centroid of the pixels in the spot, fit an ellipse to the perimeter of the spot, or fit a straight line to the pixels in the spot. We specify a combination of manipulation and calculation with the analysis_type parameter, which correspond to the <i>spot_use</i> constants in <a href="https://www.bndhep.net/Software/Sources/spot.pas">spot.pas</a>.</p>

<center><table border=1>
<tr><th>Value</th><th>Manipulation</th><th>Calculation</th><th>Description</th></tr>
<tr><td>1</td><td>none</td><td>weighted centroid</td><td>Centroid of intensity for point source images</td></tr>
<tr><td>2</td><td>none</td><td>edge of elliptical spot</td><td>Perimiter fit for retroreflecting targets</td></tr>
<tr><td>3</td><td>none</td><td>vertical stripe</td><td>Weighted fit to a vertical stripe</td></tr>
<tr><td>4</td><td>negate</td><td>vertical shadow</td><td>Weighted fit to a vertical shadow</td></tr>
<tr><td>5</td><td>grad_i</td><td>vertical edge</td><td>Weighted fit to edge pixels.</td></tr>
<tr><td>6</td><td>negate</td><td>edge of elliptical shadow</td><td>Weighted fit to edge pixels.</td></tr>
</table><small><b>Table:</b> Analysis Types, Image Manipulations and Calculations</small></center>

<p>With analysis_type=1, which is the default, the position of the spot is the weighted centroid of its net intensity. With analysis_type=2, the routine fits an ellipse to the edge of the spot. The position is the center of the ellipse. With analysis_type=3 the routine fits a straight line to the net intensity of a bright stripe. The analysis returnsthe <i>x</i>-coordinate of the intersection of this straight line with a reference line. We specify the <i>y</i>-coordinate of a horizontal reference line with <i>reference_um</i>. In place of a <i>y</i>-coordinate of the line, the routine returns its anti-clockwise rotation in milliradians. With analysis_type=4, the routine negates the image, turning a dark shadow into a bright stripe, and then applies vertical stripe analysis to the negated image. With analysis_type=5, the routine obtains the absolute horizontal gradient of intensity and applies vertical stripe analyis to the gradient image. With analysis_type=6, the routine negates the image, finds bright spots, and fits an ellipse to their edges. With analysis=7, the routine negates the image, finds the bright spots in the negated image, and calculates their centroids.</p>

<p>With return_threshold=1, the routine does no spot-finding, but instead returns a string of five values obtained by interpreting the threshold string and examining the image. These five values are four integers and one real. The integers are threshold intensity, background intensity, minimum numbser of pixels in a valid spot, maximum number of pixels in a valid spot, and maximum eccentricity of a valid spot. With return_bounds=1 and return_threshold=0, the routine returns as its result string the boundaries around the spots. It chooses the same boundaries it draws in the image overlay. Each spot boundary is given as four integers: left, top, right, and bottom. The left and right integers are column numbers. The top and bottom integers are row numbers. Each spot gets four numbers, and these make up the result string, separated by spaces. With return_intensity=1, return_bounds=0, and return_threshold=0, the routine returns only the total intensity above background of the spot for each spot. Note that this total intensity above background is not the same as the net intensity of the spot, which is the intensity above threshold. The centroid analysis uses the intensity above threshold, not the total intensity above background.</p>

<p>The sort_code has the following meanings, and dictates the order in which the spots are returned in the result string.</p>

<pre>spot_decreasing_brightness=1;
spot_increasing_x=2;
spot_increasing_y=3;
spot_decreasing_x=4;
spot_decreasing_y=5;
spot_decreasing_max=6;
spot_decreasing_size=7;
spot_increasing_xy=8;</pre>

<p>Thus with spot_decreasing_x as the value for sort_code, the routine sorts the num_spots brightest spots in order of decreasing <i>x</i> position, which means spots on the right of the image will appear first in the result string. With spot_decreasing_brightness, which is the default, the spot with the highest total net intensity comes first. But with spot_decreasing_max, the spot with the highest maximum intensity comes first. With spot_decreasing_size, the spot with the largest number of pixels comes first.</p>

<p>With show_pixels=0, which is the default value, the routine draws red boxes around the spots. These boxes are of the same size as the spots, or a little bigger if the spots are small. If num_spots=1 and the number of pixels in the spot is greater than min_pixels_for_cross, the routine draws a cross centered on the spot instead of a box around it. When show_pxels=1, the routine marks all the pixels in each spot, so you can see the pixels that are above threshold and contiguous.</p>

<p>The color we use to mark the image with the results of analysis is given in the <i>-color</i> option. You specify the color with an integer. Color codes 0 to 15 specity a set of distinct colors, shown <a href="https://www.bndhep.net/Electronics/LWDAQ/HTML/Plot_Colors.jpg">here</a>.</p>
}
function lwdaq_bcam(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	min_pixels_for_cross=100;
		
var 
	ip,scratch_image,analysis_image:image_ptr_type;
	image_name:string='';
	result:string='';
	option:string;
	arg_index,spot_num:integer;
	vp:pointer;	
	show_timing:boolean=false;
	show_pixels:boolean=false;
	return_bounds:boolean=false;
	return_intensity:boolean=false;
	return_threshold:boolean=false;
	reference_um:real=0;
	pixel_size_um:real=10;
	max_e:real=10;
	add_x_um:real=0;
	add_y_um:real=0;
	color:integer=0;
	min_p:integer=0;
	max_p:integer=0;
	threshold:integer=0;
	background:integer=0;
	num_spots:integer=1;
	analysis_type:integer=1;
	sort_code:integer=1;
	slp:spot_list_ptr_type;
	threshold_string:string='50';
	saved_bounds:ij_rectangle_type;
	ref_line:ij_line_type;
	pp:x_graph_type;
	i,j:integer;

begin
{
	Prepare return values in case of sudden exit.
}
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_bcam:=Tcl_Error;
{
	Check for any obvious errors in command line.
}
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_bcam image ?option value?".');
		exit;
	end;
{
	Connect to the image.
}
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_bcam.');
		exit;
	end;
{
	Decode the options.
}
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-show_timing') then show_timing:=Tcl_ObjBoolean(vp)
		else if (option='-pixel_size_um') then pixel_size_um:=Tcl_ObjReal(vp)
		else if (option='-threshold') then threshold_string:=Tcl_ObjString(vp)
		else if (option='-num_spots') then num_spots:=Tcl_ObjInteger(vp)
		else if (option='-analysis_type') then analysis_type:=Tcl_ObjInteger(vp)
		else if (option='-sort_code') then sort_code:=Tcl_ObjInteger(vp)
		else if (option='-return_bounds') then return_bounds:=Tcl_ObjBoolean(vp)
		else if (option='-return_intensity') then return_intensity:=Tcl_ObjBoolean(vp)
		else if (option='-return_threshold') then return_threshold:=Tcl_ObjBoolean(vp)
		else if (option='-show_pixels') then show_pixels:=Tcl_ObjBoolean(vp)
		else if (option='-add_x_um') then add_x_um:=Tcl_ObjReal(vp)
		else if (option='-add_y_um') then add_y_um:=Tcl_ObjReal(vp)
		else if (option='-reference_um') then reference_um:=Tcl_ObjReal(vp)
		else if (option='-color') then color:=Tcl_ObjInteger(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'-threshold -pixel_size_um -show_timing -num_spots -color'
				+'-analysis_type -sort_code -show_pixels -reference_um'
				+'-return_bounds -return_intensity -return_threshold'
				+'-add_x_um -add_y_um" in '
				+'lwdaq_bcam.');
			exit;
		end;
	end;
{
	Clear the image overlay. We need it clear so we can draw spots on it.
}
	start_timer('begin','lwdaq_bcam');
	clear_overlay(ip);
{
	Perform any pre-filtering required by the analysis. We end up with either a
	new image called analysis_image, or we just let analysis_image be equal to
	the image passed into the routine.
}
	case analysis_type of
		spot_use_vertical_shadow,
		spot_use_ellipse_shadow,
		spot_use_centroid_shadow:begin
			mark_time('negating image','lwdaq_bcam');
			analysis_image:=image_negate(ip);		
		end;
		spot_use_vertical_edge:begin
			mark_time('smoothing and differentiating image','lwdaq_bcam');
			scratch_image:=image_filter(ip,1,1,1,1,1,1,0);
			analysis_image:=image_grad_i(scratch_image);
			dispose_image(scratch_image);
		end;
		otherwise begin
			analysis_image:=ip;
		end;
	end;
{
	If all we want is to obtain the threshold intensity in the analysis image,
	we calculate it and return it immediately.	
}
	if return_threshold then begin
		spot_decode_threshold_string(analysis_image,
			threshold_string,threshold,background,min_p,max_p,max_e);
		writestr(result,threshold:1,' ',background:1,' ',min_p:1,' ',max_p:1,' ',max_e:1:2);
		if error_string='' then Tcl_SetReturnString(interp,result)
		else Tcl_SetReturnString(interp,error_string);
		lwdaq_bcam:=Tcl_OK;
		exit;	
	end;
{
	Find all the spots above threshold.
}
	slp:=spot_list_find(analysis_image,num_spots,threshold_string,pixel_size_um);
	if slp=nil then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Failed to allocate memory for spot list in '
			+'lwdaq_bcam.');
		exit;
	end;
{
	In some cases, we want to merge spots that are part of the same feature, which
	is possible provided we know the size and direction of the feature. 
}
	if analysis_type=spot_use_vertical_edge then begin
		mark_time('merging edge clusters','lwdaq_bcam');
		spot_list_merge(analysis_image,slp,'vertical');
	end;
{
	Sort the spots according to our sort code, which could be left to right or
	top to bottom, or brightest to dimmest, and a few other possibilities as
	specified by the sort_code.
}
	mark_time('sorting spots','lwdaq_bcam');
	for spot_num:=1 to slp^.num_selected_spots do
		spot_centroid(analysis_image,slp^.spots[spot_num]);
	spot_list_sort(slp,sort_code);
{
	Now that we have the spots, we might re-analyze them to obtain some
	measurement of their position other than the centroid that we obtained while
	finding the spots. 
}
	case analysis_type of 
		spot_use_ellipse,spot_use_ellipse_shadow: begin
			mark_time('fitting ellipses','lwdaq_bcam');
			for spot_num:=1 to slp^.num_selected_spots do
				spot_ellipse(analysis_image,slp^.spots[spot_num]);
		end;
		spot_use_vertical_stripe,
		spot_use_vertical_shadow,
		spot_use_vertical_edge: begin
			mark_time('fitting lines','lwdaq_bcam');
			for spot_num:=1 to slp^.num_selected_spots do
				spot_vertical_line(analysis_image,slp^.spots[spot_num]);
		end;
	end;
{
	Display the spots. We might put them all in boxes, draw an ellipse, or 
	draw a line. And display profiles and reference lines as required.
}
	mark_time('drawing results of analysis','lwdaq_bcam');
	if show_pixels then begin
		if analysis_image<>ip then begin
			for j:=ip^.analysis_bounds.top to ip^.analysis_bounds.bottom do
				for i:=ip^.analysis_bounds.left to ip^.analysis_bounds.right do 
					set_ov(ip,j,i,get_ov(analysis_image,j,i));
		end;
	end else begin
		clear_overlay(ip);	
	end;
	case analysis_type of 
		spot_use_ellipse,spot_use_ellipse_shadow:
			spot_list_display_ellipses(ip,slp,overlay_color(color));
		spot_use_vertical_stripe,
		spot_use_vertical_shadow: begin
			pp:=image_profile_row(ip);
			display_profile_row(ip,pp,green_color);
			spot_list_display_vertical_lines(ip,slp,overlay_color(color));
		end;
		spot_use_vertical_edge: begin
			if not show_pixels then begin
				saved_bounds:=ip^.analysis_bounds;
				pp:=image_profile_row(analysis_image);
				ip^.analysis_bounds:=analysis_image^.analysis_bounds;
				display_profile_row(ip,pp,yellow_color);
				ip^.analysis_bounds:=saved_bounds;
				pp:=image_profile_row(ip);
				display_profile_row(ip,pp,green_color);
			end;
						
			ref_line.a.i:=ip^.analysis_bounds.left;
			ref_line.a.j:=round(reference_um/pixel_size_um);
			ref_line.b.i:=ip^.analysis_bounds.right;
			ref_line.b.j:=round(reference_um/pixel_size_um);
			display_ccd_line(ip,ref_line,blue_color);	

			spot_list_display_vertical_lines(ip,slp,overlay_color(color));
		end;
		otherwise begin
			if num_spots>1 then 
				spot_list_display_bounds(ip,slp,overlay_color(color));
			if num_spots=1 then 
				if slp^.spots[1].num_pixels>=min_pixels_for_cross then
					spot_list_display_crosses(ip,slp,overlay_color(color))
				else
					spot_list_display_bounds(ip,slp,overlay_color(color));
		end;
	end;
{
	Adjust the coordinates of the spot to account for different ways of reading
	out the same image sensor. For example, if we read out the ICX424 by binning
	blocks of four pixels into one, which is the ICX424Q readout, we have to
	displace the coordinate to make them consistent with the coordinates we
	would obtain with the single-pixel readout. This displacement is a result of
	pipelines in the LWDAQ Driver, not due to any geometry on the image sensor.
}	
	mark_time('adjusting coordinates','lwdaq_bcam');
	if (add_x_um<>0) or (add_y_um<>0) then begin
		case analysis_type of 
			spot_use_vertical_stripe,
			spot_use_vertical_shadow,
			spot_use_vertical_edge: begin
				for spot_num:=1 to slp^.num_selected_spots do begin
					with slp^.spots[spot_num] do begin
						x:=x+add_x_um;
						y:=y+add_y_um;
						x:=x+reference_um*y/mrad_per_rad;
					end;
				end;
			end;
			otherwise begin
				for spot_num:=1 to slp^.num_selected_spots do begin
					with slp^.spots[spot_num] do begin
						x:=x+add_x_um;
						y:=y+add_y_um;
					end;
				end;
			end;
		end;
	end;
	
	if return_bounds then
		result:=bounds_string_from_spot_list(slp)
	else if return_intensity then
		result:=intensity_string_from_spot_list(slp)
	else 
		result:=string_from_spot_list(slp);
	dispose_spot_list_ptr(slp);
	if analysis_image<>ip then dispose_image(analysis_image);
	if num_spots=0 then result:='';
	if show_timing then report_time_marks;

	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_bcam:=Tcl_OK;
end;

{
<p>lwdaq_dosimeter finds hits in images. It is called by the Dosimeter Instrument. The routine clears the image overlay for its own use.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-num_hits</td><td>The number of hits the analysis should find, default 0.</td></tr>
<tr><td>-threshold</td><td>String specifying threshold intensity and hit size limits.</td></tr>
<tr><td>-color</td><td>Color for hit outlining in overlay, default green.</td></tr>
<tr><td>-show_timinig</td><td>If 1, print timing report to gui text window, default 0.</td></tr>
<tr><td>-show_pixels</td><td>If 1, mark pixels above threshold, default 0.</td></tr>
<tr><td>-subtract_gradient</td><td>If 1, subtract the image gradient before finding hits, default 0.</td></tr>
<tr><td>-include_ij</td><td>If 1, include column and row of hit centers, default 0.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_dosimeter.</small></center>

<p>The lwdaq_dosimeter routine measures the vertical slope of intensity in the image, which is a measure of the sensor dark current, and then finds all the bright pixels in the image, which we call <i>hits</i>, as directed by a threshold string. The -threshold string tells lwdaq_dosimeter how to distinguish background pixels from bright pixels. A bright pixel is one with intensity above the threshold intensity. The brightness of a bright pixel is its intensity minus the background intensity. The threshold string uses the same syntax as the <a href="#lwdaq_bcam">lwdaq_bcam</a> routine. It allows us to define the background, threshold, limits on the number of pixels a hit may contain, and a limit for its eccentricity.</p>

<p>The lwdaq_dosimeter routine identifies all sets of contiguous pixels above threshold in the analysis bounds. It eliminates those that have too few or too many pixels, and those that are too eccentric. It adds up the total intensity above backround of the accepted hits, and the total number of pixels in the accepted hits. Now the routine composes its output string. First comes the vertical slope of intensity, which we call the <i>intensity-slope</i>, in units of ADC counts per row, or cnt/row. Next comes the total intensity of all accepted hits divided by the total number of pixels in the analysis bounds, which we call the <i>charge density</i>, in units of counts per pixel, or cnt/px. The next value is the standard deviation of intensity in the analysis bounds, in counts. The fourth number is the threshold intensity used to isolate bright pixels, also in counts. The fifth number is the total number of bright pixels in all accepted hits, also in counts. Following these five numbers is an optional list of hits. If <i>num_hits</i> &ge; 0, it spectifies the number of hits to be listed. If <i>num_hits</i> &lt; 0, all valid hits will be listed. By default, each hit is listed by its brightness above background. Non-existent hits are indicated with brightness &minus;1. If <i>include_ij</i> is set, the brightness of each hit is followed by the image column and row of the pixel containing its intensity centroid.</p>

<p>With subgract_gradient=0, the dosimeter analysis operates entirely upon the original image. But with subgract_gradient=1, the analysis obtains the intensity-slope with the original image, but then subtracts the average intensity gradient from the analysis bounds and continues with bright-pixel collection in the gradient-subtracted image.</p>

<p>The color we use to outline bright pixels is given in the <i>-color</i> option. You specify the color with an integer. Color codes 0 to 15 specity a set of distinct colors, shown <a href="https://www.bndhep.net/Electronics/LWDAQ/HTML/Plot_Colors.jpg">here</a>.</p>

<p>See the <a href="https://www.bndhep.net/Electronics/LWDAQ/Manual.html#Dosimeter">Dosimeter Instrument</a> Manual for more information about the option values.</p>
}
function lwdaq_dosimeter(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	wip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	field:string='';
	option:string='';
	arg_index,hit_num:integer;
	vp:pointer;	
	show_timing:boolean=false;
	show_pixels:boolean=false;
	subtract_gradient:boolean=false;
	include_ij:boolean=false;
	pixel_size_um:real=1;
	color:integer=0;
	num_hits:integer=0;
	slp:spot_list_ptr_type;
	threshold_string:string='50';
	slope:real=0;
	intercept:real=0;
	residual:real=0;
	density:real=0;
	stdev:real=0;
	gpx:x_graph_type;
	gpxy:xy_graph_type;
	j:integer;
		
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_dosimeter:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_dosimeter image ?option value?".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_dosimeter.');
		exit;
	end;
	
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-show_timing') then show_timing:=Tcl_ObjBoolean(vp)
		else if (option='-threshold') then threshold_string:=Tcl_ObjString(vp)
		else if (option='-num_hits') then num_hits:=Tcl_ObjInteger(vp)
		else if (option='-show_pixels') then show_pixels:=Tcl_ObjBoolean(vp)
		else if (option='-include_ij') then include_ij:=Tcl_ObjBoolean(vp)
		else if (option='-subtract_gradient') then subtract_gradient:=Tcl_ObjBoolean(vp)
		else if (option='-color') then color:=Tcl_ObjInteger(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'-threshold -show_timing -num_hits -color'
				+'-show_pixels -subtract_gradient" in '
				+'lwdaq_dosimeter.');
			exit;
		end;
	end;
		
	start_timer('finding intensity-slope','lwdaq_dosimeter');
	gpx:=image_profile_column(ip);
	setlength(gpxy,length(gpx));
	for j:=0 to length(gpx)-1 do begin
		gpxy[j].x:=j;
		gpxy[j].y:=gpx[j];
	end;
	straight_line_fit(gpxy,slope,intercept,residual);
	
	if subtract_gradient then begin
		mark_time('subtracting gradient','lwdaq_dosimeter');
		wip:=image_subtract_gradient(ip);
	end else begin
		wip:=ip;
	end;
		
	mark_time('finding hits','lwdaq_dosimeter');
	clear_overlay(wip);
	slp:=spot_list_find(wip,num_hits,threshold_string,pixel_size_um);
	if slp=nil then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Failed to allocate memory for spot list in '
			+'lwdaq_dosimeter.');
		exit;
	end;
	
	mark_time('displaying positions','lwdaq_dosimeter');
	if not show_pixels then clear_overlay(wip);
	spot_list_display_bounds(wip,slp,overlay_color(color));

	mark_time('calculating stdev and density','lwdaq_dosimeter');
	stdev:=image_amplitude(wip);
	with wip^.analysis_bounds do
		density:=slp^.grand_sum_intensity/(right-left)/(bottom-top);
	writestr(result,slope:1:4,' ',density:1:4,' ',stdev:1:1,' ',
		slp^.threshold:1,' ',slp^.num_valid_spots,' ');
	
	mark_time('listing hits','lwdaq_dosimeter');
	if num_hits<0 then num_hits:=slp^.num_valid_spots;
	for hit_num:=1 to num_hits do begin
		if hit_num<=slp^.num_valid_spots then begin
			writestr(field,slp^.spots[hit_num].sum_intensity:1,' ');
			if include_ij then begin
				spot_centroid(wip,slp^.spots[hit_num]);
				writestr(field,field,
					slp^.spots[hit_num].position_ij.i:1,' ',
					slp^.spots[hit_num].position_ij.j:1,' ');
			end;
		end else begin
			field:=('-1 ');
			if include_ij then begin
				writestr(field,field,'0 0 ');
			end;
		end;
		insert(field,result,length(result)+1);
	end;
	Tcl_SetReturnString(interp,result);
		
	if subtract_gradient then begin
		mark_time('transferring overlay','lwdaq_dosimeter');
		image_transfer_overlay(ip,wip);
		dispose_image(wip);
	end;
	dispose_spot_list_ptr(slp);

	mark_time('done','lwdaq_dosimeter');
	if show_timing then report_time_marks;
		
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_dosimeter:=Tcl_OK;
end;

{
<p>lwdaq_rasnik analyzes rasnik images. Specify the image with -image_name as usual. The routine clears the image overlay for its own use. The routine takes the following options, each of which you specify by giving the option name followed by its value, ?option value?. See the <a href="https://www.opensourceinstruments.com/Software/LWDAQ/Manual.html#Rasnik">Rasnik Instrument</a> for a description of the options.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-reference_x_um</td><td>x-coordinate of reference point.</td></tr>
<tr><td>-reference_y_um</td><td>y-coordinate of reference point.</td></tr>
<tr><td>-orientation_code</td><td>Selects the analysis orientation code.</td></tr>
<tr><td>-square_size_um</td><td>Tells the analysis the mask square size (assumed square).</td></tr>
<tr><td>-pixel_size_um</td><td>Tells the analysis the pixel size (assumed square)</td></tr>
<tr><td>-show_timinig</td><td>If 1, print timing report to gui text window.</td></tr>
<tr><td>-show_fitting</td><td>If <> 0, show fitting stages with delay <i>value</i> ms.</td></tr>
<tr><td>-rotation_mrad</td><td>If <> 0, pre-rotate image before analysis by &minus;<i>value</i>.</td></tr>
<tr><td>-pattern_only</td><td>If 1, return pattern description not rasnik measurement.</td></tr>
<tr><td>-disable_skew</td><td>If 1, forces skew and slant values to zero, default 0.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_rasnik.</small></center>

<p>See the <a href="https://www.bndhep.net/Electronics/LWDAQ/Manual.html#Rasnik">Rasnik Instrument</a> Manual for more information about the option values, in particular the reference and orientation code meanings.</p>

<p>The <i>rotation_mrad</i> option allows us to specify a large nominal rotation of the mask, positive is counter-clockwise. The rasnik routine will rotate the image so as to remove the large rotation, apply analysis, then un-rotate the image. The rotation takes place about the center of the analysis bounds.</p>

<p>With the -pattern_only option set, the routine returns a description of the chessboard pattern it finds in the image. The result string contains seven numbers: origin.x, origin.y, pattern_x_width, pattern_y_width, rotation, error, and extent. The origin values are the image coordinates of the top-left corner of one of the squares in the chessboard. Units are pixels, not mircons. The next two numbers are the  width of the squares in the near-horizontal direction and their width in the near-vertical direction. Units are again pixels. The rotation is counter-clockwise in milliradians. The error is an estimate of the fitting accuracy in pixel widths. The extent is the number of squares from the image center over which the pattern extends. If we know that our image is neither slanted nor skewed, but has instead been severely corrupted by poor focus and dirt, we can force the skew and slant to zero with -disable_skew. Now, when we apply the rasnik analysis a hundred times to the same poor image, we have a higher chance of finding the correct pattern by accident.</p> 
}
function lwdaq_rasnik(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	sip:image_ptr_type=nil;
	tip:image_ptr_type=nil;
	iip:image_ptr_type=nil;
	jip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	pp:rasnik_pattern_ptr_type=nil;
	option:string;
	arg_index:integer;
	vp:pointer;	
	show_fitting:boolean=false;
	show_timing:boolean=false;
	pattern_only:boolean=false;
	square_size_um:real=120;
	pixel_size_um:real=10;
	orientation_code:integer=0;
	rp:rasnik_ptr_type;
	reference_x_um:real=0;
	reference_y_um:real=0;
	reference_point_um:xy_point_type;
	rotation_mrad:real=0;
	w:real=0;
	h:real=0;
	a:real=0;
	r:real=0;
	center:xy_point_type;
	reference:xy_point_type;
	radius:xy_point_type;
		
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_rasnik:=Tcl_Error;		

	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'v image ?option value?".');
		exit;
	end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_rasnik.');
		exit;
	end;
	
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-show_fitting') then show_fitting:=Tcl_ObjBoolean(vp)
		else if (option='-show_timing') then show_timing:=Tcl_ObjBoolean(vp)
		else if (option='-pattern_only') then pattern_only:=Tcl_ObjBoolean(vp)
		else if (option='-orientation_code') then orientation_code:=Tcl_ObjInteger(vp)
		else if (option='-square_size_um') then square_size_um:=Tcl_ObjReal(vp)
		else if (option='-pixel_size_um') then pixel_size_um:=Tcl_ObjReal(vp)
		else if (option='-reference_x_um') then reference_x_um:=Tcl_ObjReal(vp)
		else if (option='-reference_y_um') then reference_y_um:=Tcl_ObjReal(vp)
		else if (option='-rotation_mrad') then rotation_mrad:=Tcl_ObjReal(vp)
		else if (option='-disable_skew') then rasnik_disable_skew:=Tcl_ObjBoolean(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-orientation_code -square_size_um '
				+'-pixel_size_um -reference_x_um -reference_y_um '
				+'-show_fitting -disable_skew" in '
				+'lwdaq_rasnik.');
			exit;
		end;
	end;
	
	with reference_point_um do begin
		x:=reference_x_um;
		y:=reference_y_um;
	end;
	
	start_timer('beginning rasnik analysis','lwdaq_rasnik');
	center:=xy_origin;
	if (rotation_mrad<>0) then begin
		mark_time('rotating original image','lwdaq_rasnik');
		with ip^.analysis_bounds do begin
			center.x:=(left+right)/2;
			center.y:=(top+bottom)/2;
		end;
		r:=rotation_mrad/mrad_per_rad;
		reference.x:=reference_x_um/pixel_size_um;
		reference.y:=reference_y_um/pixel_size_um;
		radius:=xy_difference(reference,center);
		radius:=xy_rotate(radius,r);
		reference:=xy_sum(center,radius);
		reference_point_um.x:=reference.x*pixel_size_um;
		reference_point_um.y:=reference.y*pixel_size_um;
		sip:=ip;
		ip:=image_rotate(ip,-r,center);
		with ip^.analysis_bounds do begin
			w:=(right-left);
			h:=(bottom-top);
			if (abs(cos(r/2)) < small_real) then
				a := 0
			else if (abs(cos(r)) < small_real) then 
				a := abs(w-h)/2.0
			else begin
				if w>h then a := (w-h*abs(sin(r/2))/cos(r/2))
				else a := (h - w*abs(sin(r/2))/cos(r/2));
				a := a * abs(sin(r)) / cos(r) / (2*(1+abs(sin(r))/cos(r)));
			end;
			left:=left+round(a);
			top:=top+round(a);
			right:=right-round(a);
			bottom:=bottom-round(a);
		end;
	end;
	
	mark_time('generating image derivatives','lwdaq_rasnik');
	iip:=image_grad_i(ip);
	jip:=image_grad_j(ip);
	mark_time('clearing overlay','lwdaq_rasnik');
	clear_overlay(ip);
	mark_time('starting rasnik_find_pattern','lwdaq_rasnik');
	pp:=rasnik_find_pattern(iip,jip,show_fitting);
	if show_fitting then begin
		rasnik_display_pattern(ip,pp,false);
		gui_draw(ip^.name);
		gui_wait('Approximate pattern from slices.');
	end;
	mark_time('starting rasnik_refine_pattern','lwdaq_rasnik');
	rasnik_refine_pattern(pp,iip,jip,show_fitting);
	mark_time('starting rasnik_adjust_pattern_parity','lwdaq_rasnik');
	rasnik_adjust_pattern_parity(ip,pp);
	if pattern_only then begin
		mark_time('starting rasnik_display_pattern','lwdaq_rasnik');
		rasnik_display_pattern(ip,pp,show_fitting);
		if (rotation_mrad<>0) then begin
			pp^.rotation:=pp^.rotation+r;
		end;
		result:=string_from_rasnik_pattern(pp);
	end else begin
		mark_time('starting rasnik_identify_pattern_squares','lwdaq_rasnik');
		rasnik_identify_pattern_squares(ip,pp);
		mark_time('starting rasnik_identify_code_squares','lwdaq_rasnik');
		rasnik_identify_code_squares(ip,pp);
		mark_time('starting rasnik_analyze_code','lwdaq_rasnik');
		rasnik_analyze_code(pp,orientation_code);
		mark_time('starting rasnik_from_pattern','lwdaq_rasnik');
		rp:=rasnik_from_pattern(ip,pp,reference_point_um,square_size_um,pixel_size_um);	
		mark_time('starting rasnik_display_pattern','lwdaq_rasnik');
		rasnik_display_pattern(ip,pp,show_fitting);
		if (rotation_mrad<>0) then begin
			rp^.rotation:=rp^.rotation+r;
			rp^.reference_point_um.x:=reference_x_um;
			rp^.reference_point_um.y:=reference_y_um;
		end;
		writestr(result,string_from_rasnik(rp));
		mark_time('starting to dispose pointers','lwdaq_rasnik');
		dispose_rasnik(rp);
	end;

	dispose_rasnik_pattern(pp);
	dispose_image(iip);
	dispose_image(jip);
	
	if (rotation_mrad<>0) then begin
		mark_time('un-rotating image','lwdaq_rasnik');
		display_ccd_rectangle(ip,ip^.analysis_bounds,orange_color);
		tip:=image_rotate(ip,r,center);
		dispose_image(ip);
		image_transfer_overlay(sip,tip);
		dispose_image(tip);
		ip:=sip;
	end;

	mark_time('done','lwdaq_rasnik');
	if show_timing then report_time_marks;
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_rasnik:=Tcl_OK;
end;

{
<p>lwdaq_rasnik_shift takes in a rasnik result string and shifts it to a new reference point. The routine gets the old reference point from the results string, and re-calculates the rasnik measurement using the x and y coordinates you specify with -reference_x_um and -reference_y_um.</p>
}
function lwdaq_rasnik_shift(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ref:xy_point_type;
	old_result:string='';
	result:string='';
	option:string;
	arg_index:integer;
	vp:pointer;	
	rasnik:rasnik_type;
	reference_x_um:real=0;
	reference_y_um:real=0;
	source_name:string='';
		
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_rasnik_shift:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_rasnik_shift old_result ?option value?".');
		exit;
	end;
	
	old_result:=Tcl_ObjString(argv[1]);
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-reference_x_um') then reference_x_um:=Tcl_ObjReal(vp)
		else if (option='-reference_y_um') then reference_y_um:=Tcl_ObjReal(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-reference_x_um -reference_y_um" in '
				+'lwdaq_rasnik_shift.');
			exit;
		end;
	end;
	
	source_name:=read_word(old_result);
	rasnik:=rasnik_from_string(old_result);
	ref.x:=reference_x_um;
	ref.y:=reference_y_um;
	rasnik:=rasnik_shift_reference_point(rasnik,ref);
	result:=source_name+' '+string_from_rasnik(@rasnik);
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_rasnik_shift:=Tcl_OK;
end;

{
<p>lwdaq_shadow finds vertical or horizontal line shadows in images. We call these <i>wire shadows</i> because we firsst obtained them from wires in x-ray images. The image itself must be blurred enough that the minimum intensity of the shadow lies near its center. We use a simplex fitter to maximize the correlation between the image and a prototype shape. You will find this analysis described in the  <a href="http://www.opensourceinstruments.com/WPS/WPS1/index.html#Fitting% 20Analysis">Fitting Analysis</a> section of the WPS1 Manual.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-approximate</td><td>Stop approximate shadow positions, default zero.</td></tr>
<tr><td>-pixel_size_um</td><td>Width and height of image pixels in microns.</td></tr>
<tr><td>-reference_um</td><td>Location of reference line in microns from top of image, default zero.</td></tr>
<tr><td>-show_timinig</td><td>Print timing report to gui text window, default zero.</td></tr>
<tr><td>-num_shadows</td><td>Number of shadows you want the routine to find.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_shadow.</small></center>

<p>With -pre_smooth set to 1, the routine smooths the original image with a box filter before it applies the gradient and threshold. We use -pre_smooth when noise is obscuring the larger edge features in a wire image.</p>

<p>The shadow positions are given with respect to a horizontal reference line drawing <i>reference_um</i> microns down from the top edge of the top image row.</p>
}
function lwdaq_shadow(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	spots_per_wire=2;
		
var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	shadow_string:string='';
	option:string;
	arg_index:integer;
	shadow_num:integer;
	num_shadows:integer=1;
	vp:pointer;	
	show_timing:boolean=false;
	approximate:boolean=false;
	pixel_size_um:real=10.0;
	reference_um:real=0;
	min_separation_um:real=500.0;
	i:integer=1;
	slp:shadow_list_ptr_type;
	ref_line:ij_line_type;
		
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_shadow:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_shadow image ?option value?".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_shadow.');
		exit;
	end;
	
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-show_timing') then show_timing:=Tcl_ObjBoolean(vp)
		else if (option='-pixel_size_um') then pixel_size_um:=Tcl_ObjReal(vp)
		else if (option='-reference_um') then reference_um:=Tcl_ObjReal(vp)
		else if (option='-min_separation_um') then min_separation_um:=Tcl_ObjReal(vp)
		else if (option='-num_shadows') then num_shadows:=Tcl_ObjInteger(vp)
		else if (option='-approximate') then approximate:=Tcl_ObjBoolean(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'-approximate -pixel_size_um -show_timing -num_shadows '
				+'-reference_um -min_separation" in '
				+'lwdaq_shadow.');
			exit;
		end;
	end;
	
	if image_name='' then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Specify an image name with -image_name in '
			+'lwdaq_shadow.');
		exit;
	end;
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_shadow.');
		exit;
	end;
{
	Set up shadow list and find approximate locations.
}
	start_timer('finding approximate positions','lwdaq_shadow');
	writestr(shadow_string,
		min_separation_um,' ',
		pixel_size_um:1:3,' ',
		num_shadows:1);
	for i:=1 to num_shadows do shadow_string:=shadow_string+' wire';
	slp:=shadow_list_from_string(shadow_string);
	shadow_locate_approximate(ip,slp);
{
	Find precise positions of shadows.
}
	if not approximate then begin
		mark_time('fitting accurate positions','lwdaq_shadow');
		shadow_locate_accurate(ip,slp);
	end;
{
	Display graphical results of analysis.
}
	mark_time('displaying lines','lwdaq_shadow');
	ref_line.a.i:=ip^.analysis_bounds.left;
	ref_line.a.j:=round(reference_um/pixel_size_um);
	ref_line.b.i:=ip^.analysis_bounds.right;
	ref_line.b.j:=round(reference_um/pixel_size_um);
	display_ccd_line(ip,ref_line,blue_color);	
{
	Shift x-position of shadows so that each is given as the intersection of the
	line and reference_um microns down from the top row in the image.
}
	for shadow_num:=1 to num_shadows do 
		with slp^.shadows[shadow_num] do
			position.x:=position.x+reference_um*rotation/mrad_per_rad;
{
	Dispose of the shadow list and return the numerical results.
}
	mark_time('done','lwdaq_shadow');
	result:=string_from_shadows(slp);
	dispose_shadow_list_ptr(slp);
	if num_shadows=0 then result:='';
	if show_timing then report_time_marks;
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_shadow:=Tcl_OK;
end;

{
<p>lwdaq_wps analyzes wps images. It clears the overlay for its own use. We describe the analysis in our <a href="http://www.opensourceinstruments.com/WPS/WPS1/">WPS1 Manual</a>.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-pixel_size_um</td><td>Width and height of image pixels in microns.</td></tr>
<tr><td>-reference_um</td><td>Location of reference line in microns below top edge of top row.</td></tr>
<tr><td>-show_timinig</td><td>If 1, print timing report to gui text window, default zero.</td></tr>
<tr><td>-show_edges</td><td>If 1, show edge pixesls in image, defalut zero</td></tr>
<tr><td>-num_wires</td><td>The number of wires you want the routine to find.</td></tr>
<tr><td>-pre_smooth</td><td>Smooth the image before you take the derivative.</td></tr>
<tr><td>-merge</td><td>Merge aligned edge clusters.</td></tr>
<tr><td>-threshold</td><td>Criteria for finding spots, including threshold specification.</td></tr>
pixels.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_wps.</small></center>

<p>The -threshold string is used in the same way as in <a href="#lwdaq_bcam">lwdaq_bcam</a>. It can contain an intensity threshold or it can define a means to calculate the threshold. The string can also specify the minimum number of pixels a spot must contain, and its maximum eccentricity. Spots that do not meet these criteria will be marked as invalid. In this case, note that the threshold intensity will be applied to the horizontal gradient of the wire image, not the image itself.</p>

<p>With -pre_smooth set to 1, the routine smooths the original image with a box filter before it applies the gradient and threshold. We use -pre_smooth when noise is obscuring the larger edge features in a wire image.</p>

<p>With -merge set to 1, the routine checks for edge pixel clusters that are closely aligned, and merges these together. We use -merge when image contrast is so poor that the edge pixels along one side of a wire image can break into two or more separate clusters.</p>

<p>The wire positions are given with respect to a horizontal reference line drawing <i>reference_um</i> microns down from the top edge of the top image row. With <i>show_edges</i> equal to zero (the default value), the routine plots the image's horizontal intensity profile in green and the derivative profile in yellow. But when you set <i>show_edges</i> to 1, the routine no longer plots these two graphs, but instead displays the spots it finds in the derivative image, overlayed upon the original image. The edges of a wire will be covered with colored pixels. White pixels are ones that were part of spots that did not satisfy the -threshold critera.</p>
}
function lwdaq_wps(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	spots_per_wire=2;
		
var 
	ip:image_ptr_type=nil;
	iip:image_ptr_type=nil;
	sip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	option:string;
	arg_index:integer;
	reference_um:real=0;
	spot_num,num_spots:integer;
	vp:pointer;	
	show_timing:boolean=false;
	show_edges:boolean=false;
	pre_smooth:boolean=false;
	merge:boolean=false;
	pixel_size_um:real=10;
	num_wires:integer=1;
	i:integer=1;
	j:integer=1;
	slp:spot_list_ptr_type;
	pp:x_graph_type;
	saved_bounds:ij_rectangle_type;
	ref_line:ij_line_type;
	threshold:string='50';
		
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_wps:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_wps image ?option value?".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_wps.');
		exit;
	end;
	
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-show_timing') then show_timing:=Tcl_ObjBoolean(vp)
		else if (option='-show_edges') then show_edges:=Tcl_ObjBoolean(vp)
		else if (option='-pixel_size_um') then pixel_size_um:=Tcl_ObjReal(vp)
		else if (option='-reference_um') then reference_um:=Tcl_ObjReal(vp)
		else if (option='-num_wires') then num_wires:=Tcl_ObjInteger(vp)
		else if (option='-pre_smooth') then pre_smooth:=Tcl_ObjBoolean(vp)
		else if (option='-merge') then merge:=Tcl_ObjBoolean(vp)
		else if (option='-threshold') then threshold:=Tcl_ObjString(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'-pixel_size_um -show_timing -num_wires -reference_um '
				+'-threshold -show_edges -pre_smooth" in '
				+'lwdaq_wps.');
			exit;
		end;
	end;
	
	if image_name='' then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Specify an image name with -image_name in '
			+'lwdaq_wps.');
		exit;
	end;
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_wps.');
		exit;
	end;	
{
	Generate the derivative image and find spots above threshold in this new
	image.
}
	start_timer('generating derivative image','lwdaq_wps');
	if pre_smooth then begin
		sip:=image_filter(ip,1,1,1,1,1,1,0);
		iip:=image_grad_i(sip);
		dispose_image(sip);
	end else begin
		iip:=image_grad_i(ip);
	end;
	mark_time('finding spots','lwdaq_wps');
	num_spots:=spots_per_wire*num_wires;
	slp:=spot_list_find(iip,num_spots,threshold,pixel_size_um);
	if slp=nil then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Failed to allocate memory for spot list in '
			+'lwdaq_wps.');
		exit;
	end;
{
	Merge similar spots if requested.
}
	if merge then begin
		mark_time('merging edge clusters','lwdaq_wps');
		spot_list_merge(iip,slp,'vertical');
	end;
{
	Sort the spots from left to right.
}
	mark_time('sorting spots','lwdaq_wps');
	for spot_num:=1 to slp^.num_selected_spots do begin
		spot_centroid(iip,slp^.spots[spot_num]);
	end;
	spot_list_sort(slp,spot_increasing_x);
{
	Fit lines to the spots.
}
	mark_time('calculating vertical lines','lwdaq_wps');
	for spot_num:=1 to num_spots do
		if slp<>nil then spot_vertical_line(iip,slp^.spots[spot_num]);
{
	Display graphical results of analysis.
}
	if show_edges then begin
		mark_time('displaying edges','lwdaq_wps');
		for j:=ip^.analysis_bounds.top to ip^.analysis_bounds.bottom do
			for i:=ip^.analysis_bounds.left to ip^.analysis_bounds.right do 
				set_ov(ip,j,i,get_ov(iip,j,i));
	end else begin
		mark_time('displaying derivative profile','lwdaq_wps');
		saved_bounds:=ip^.analysis_bounds;
		pp:=image_profile_row(iip);
		ip^.analysis_bounds:=iip^.analysis_bounds;
		display_profile_row(ip,pp,yellow_color);
		ip^.analysis_bounds:=saved_bounds;
		mark_time('displaying intensity profile','lwdaq_wps');
		pp:=image_profile_row(ip);
		display_profile_row(ip,pp,green_color);
	end;
	mark_time('displaying lines','lwdaq_wps');
	spot_list_display_vertical_lines(ip,slp,red_color);
	ref_line.a.i:=ip^.analysis_bounds.left;
	ref_line.a.j:=round(reference_um/pixel_size_um);
	ref_line.b.i:=ip^.analysis_bounds.right;
	ref_line.b.j:=round(reference_um/pixel_size_um);
	display_ccd_line(ip,ref_line,blue_color);	
{
	Shift x-position of lines so that each line position is given
	as the intersection of the line and a horizontal line reference_um
	microns down from the top row in the image.
}
	for spot_num:=1 to num_spots do 
		with slp^.spots[spot_num] do
			if valid then
				x:=x+reference_um*y/mrad_per_rad;
{
	Dispose of the spot list and return the numerical results.
}
	mark_time('done','lwdaq_wps');
	result:=string_from_spot_list(slp);
	dispose_spot_list_ptr(slp);
	dispose_image(iip);
	if num_spots=0 then result:='';
	if show_timing then report_time_marks;
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_wps:=Tcl_OK;
end;

{
<p>lwdaq_scam applies Silhouette Camera (SCAM) routines to SCAM images. The SCAM routines are defined in <a href="https://www.bndhep.net/Software/Sources/scam.pas">scam.pas</a>. We pass lwdaq_scam an instruction, and one or more arguments required by the instruction.</p>

<center><table border cellspacing=2>
<tr><th>Instruction</th><th>Function</th></tr>
<tr><td>project</td><td>Project a modelled object into an image overlay.</td></tr>
<tr><td>disagreement</td><td>Measure disagreement between actual and modelled silhouette.</td></tr>
</table><small><b>Table:</b> Instructions for the lwdaq_scam command.</small></center>

<p>The <i>project</i> instruction takes three arguments: a <i>camera</i> calibration in the SCAM's mount coordinates, an <i>object</i> definition in the SCAM's mount coordinates, and a number of projection lines to use to fill the overlay in the silhouette image. The object must be one of those in the library provided by scam.pas. When we want to project more complex bodies, we build them out of multiple objects.</p>

<p>The <i>camera</i> string contains nine elements. The first is the name of the camera. The following eight are the camera calibration constants, as described in the <a href="https://www.bndhep.net/Devices/BCAM/User_Manual.html">BCAM User Manual</a>. They are the xyz camera pivot position millimeters, the angle subtended by the camera axis with the x and y axis in milliradians, a numerical code to say if the axis is forward or backwards and to identify the image sensor, the distance from the pivot point to the center of the image sensor, and the rotation of the image sensor about the camera axis.</p>

<p>Prior to projecting any object, we must transform its location into mount coordinates. If the object is anything other than a sphere, it will have an orientation as well, and this we must transform this orientation into mount coordinates as well. The orientation of an object is three rotations about the x, y, and z axes that bring the object from its zero orienation to its modelled orientation.The modelled object itself we specify with its own string. Each object begins with a name, such as "sphere" or "shaft". Every object has a location, which is the translation of its zero point to obtain its modelled position. All objects other than the sphere have an orientation, which is the xyz rotation we apply to the object in its zero orientation to obtain its modelled oriention. The location and orientation together define the "pose" of the modelled object.</p>

<center><table border cellspacing=2>
<tr>
	<th>Object</th>
	<th>Zero Point</th>
	<th>Zero Orientation</th>
</tr>
<tr>
	<td>sphere</td>
	<td>center of sphere</td>
	<td>no orientation</td>
</tr>
<tr>
	<td>shaft</td>
	<td>a point on the shaft axis</td>
	<td>shaft axis is parallel to x-axis</td>
</tr>
<tr>
	<td>cuboid</td>
	<td>center of left face</td>
	<td>x-axis perpendicular to left face, y-axis parallel to top edge</td>
</tr>
</table><small><b>Table:</b> Object Types Supported by the lwdaq_scam Command.</small></center>

<p>Following the location, and possibly the orientation, of the object are one or more values giving its dimensions. A <i>sphere</i> consists of a location and a diameter. A <i>shaft</i> consists of a location and orientation in the coordinate system of the body, followed by a pair of numbers for each face of the shaft. Each pair is a diameter and distance. The distance is measured along the shaft axis from the zero point, with negative values being in the direction opposite to the axis vector. A <i>cuboid</i> consists of a location, an orientation, a width, a height, and a depth. The width, height, and depth are parallel to the x, y, and z axes respectively when the cuboid is in its zero orientation.</p>

<p>The <i>disagreement</i> instruction counts the number of pixels in the analysis boundaries for which the image and the overlay disagree about the location and extent of the silhouette. To determine which pixels are silhouette and which are background, the routine uses an intensity threshold. Pixels with intensity equal to or below the threshold are considered part of the silhouette. All others are background. To specify the threshold, we pass lwdaq_scam a "threshold string" immediately after the image name. The threshold string takes the same form as it does in the <a href="#lwdaq_bcam">lwdaq_bcam</a> routine, as illustrated in the <a href="https://www.bndhep.net/Electronics/LWDAQ/Manual.html#BCAM">BCAM Instrument</a> manual. A background pixel that is marked blue from a previous SCAM body projection will remain blue. A background pixel that is not marked will remain unmarked. A silhouette pixel that is marked blue will be unmarked. A silhouette pixel that is unmarked will be marked orange. In this way, a prefect match between a solid projection and a silhouette will be entirely unmarked, while imprefections are marked either orange for silhouette without projection or blue for projection without silhouette. The marked pixels are the disagreement pixels.</p>

<p>The <i>disagreement</i> instruction's result string begins with an integer giving the number of disagreement pixels in the image. If the analysis encountered an error, this value will be "-1". Following the count are the minimum and maximum intensities in the image, also integers, and the threshold intensity used to detect the silhouette. The threshold we return as a real number so that we can support thresholds half-way between two integer values.</p>

<pre>set img [LWDAQ_read_image_file Images/SCAM_sphere.gif]
lwdaq_scam $img disagreement "10 %"
72832 49 123 56.4</pre>

<p>In the above example, we read the sample SCAM_sphere.gif image and apply the scam disagreement routine with a threshold string "10 %". This threshold string specifies an intensity that is 10% of the way from the minimum intensity to the maximum intensity.</p>
}
function lwdaq_scam(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	command:string='';
	option:string='';
	body:string='';
	threshold_string:string='10 %';
	camera:bcam_camera_type;
	sphere:scam_sphere_type;
	shaft:scam_shaft_type;
	disagreement:integer=0;
	threshold:real=0;
	num_lines:integer=0;
	line_width:integer=0;
	body_pose:xyz_pose_type;
	scam_pose:xyz_pose_type;
	arg_index:integer;
	vp:pointer;	
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_scam:=Tcl_Error;
	scam_pose:=xyz_pose_from_string('0 0 0 0 0 0');
	camera:=bcam_camera_from_string('scam 0 0 0 0 0 2 25 0');
	body:='sphere 0 0 1000 0 0 0 50';
	num_lines:=1000;
	line_width:=1;
	
	if (argc<3) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_wps image command ?arguments?".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_scam.');
		exit;
	end;
	
	command:=Tcl_ObjString(argv[2]);
	if (command='project') then begin
		if argc>3 then scam_pose:=xyz_pose_from_string(Tcl_ObjString(argv[3]));
		if argc>4 then camera:=bcam_camera_from_string(Tcl_ObjString(argv[4]));
		if argc>5 then body:=Tcl_ObjString(argv[5]);
		arg_index:=6;
	end else if (command='disagreement') then begin
		if argc>3 then threshold_string:=Tcl_ObjString(argv[3]);
		arg_index:=4;
	end else begin
		Tcl_SetReturnString(interp,error_prefix
			+'Invalid command "'+command+'", must be one of '
			+'"project disagreement" in '
			+'lwdaq_scam.');
		exit;
	end;
	
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-num_lines') then num_lines:=Tcl_ObjInteger(vp)
		else if (option='-line_width') then line_width:=Tcl_ObjInteger(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-num_lines -line_width" in lwdaq_scam.');
			exit;
		end;
	end;
	
	if command='project' then begin
		body_pose:=read_xyz_pose(body);
		while body<>'' do begin
			option:=read_word(body);
			if option='sphere' then begin
				sphere:=read_scam_sphere(body);
				sphere.location:=xyz_global_from_local_point(sphere.location,body_pose);
				sphere.location:=xyz_local_from_global_point(sphere.location,scam_pose);
				scam_project_sphere(ip,sphere,camera,num_lines,line_width);
			end else if option='shaft' then begin
				shaft:=read_scam_shaft(body);
				shaft.location:=xyz_global_from_local_point(shaft.location,body_pose);
				shaft.location:=xyz_local_from_global_point(shaft.location,scam_pose);
				shaft.direction:=xyz_global_from_local_vector(shaft.direction,body_pose);
				shaft.direction:=xyz_local_from_global_vector(shaft.direction,scam_pose);
				scam_project_shaft(ip,shaft,camera,num_lines,line_width);
			end else begin
				Tcl_SetReturnString(interp,error_prefix
					+'Invalid shape "'+option+'", must be one of '
					+'"sphere shaft" in '
					+'lwdaq_scam.');
				exit;
			end;
		end;
	end;
	
	if command='disagreement' then begin
		threshold:=scam_decode_threshold_string(ip,threshold_string);
		disagreement:=scam_disagreement(ip,threshold);
		writestr(result,disagreement:1,' ',image_minimum(ip):1:0,' ',
			image_maximum(ip):1:0,' ',threshold:1:1);
	end;
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_scam:=Tcl_OK;
end;

{
<p>lwdaq_bcam_calib takes as input an apparatus measurement and a device calibration, and returns a parameter calculation. The routine calls parameter_calculation in the <a href="https://www.bndhep.net/Software/Sources/bcam.pas">bcam.pas</a>. This routine supports bcam cameras and bcam sources for all types of bcam and both j_plates and k_plates.</p>
}
function lwdaq_bcam_calib(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	option:string;
	arg_index:integer;
	vp:pointer;	
	calib_str:string='';
	app_str:string='';
	param_str:string='';
	ct:string='';
	verbose:boolean=false;
	check:boolean=false;
	app:apparatus_measurement_type;
	calib:device_calibration_type;
		
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_bcam_calib:=Tcl_Error;
	
	if (argc<3) or (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be ' 
			+'"lwdaq_bcam_calib device_calibration apparatus_measurement'
			+' ?option value?".');
		exit;
	end;
	
	arg_index:=3;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-verbose') then verbose:=Tcl_ObjBoolean(vp)
		else if (option='-check') then check:=Tcl_ObjBoolean(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-verbose -check" in '
				+'lwdaq_bcam_calib.');
			exit;
		end;
	end;
	
	calib_str:=Tcl_ObjString(argv[1]);
	calib:=device_calibration_from_string(calib_str);
	app_str:=Tcl_ObjString(argv[2]);
	app:=apparatus_measurement_from_string(app_str);
	
	if app.calibration_type<>calib.calibration_type then begin
		report_error('Apparatus measurement type "'
			+app.calibration_type
			+'" does not match device calibration type "'
			+calib.calibration_type+'" in '
			+'lwdaq_bcam_calib');
	end;

	ct:=calib.calibration_type;
	
	if (ct='black_polar_fc') 
			or (ct='black_polar_rc') 
			or (ct='blue_polar_fc') 
			or (ct='blue_polar_rc') 
			or (ct='black_n_c') 
			or (ct='blue_n_c') 
			or (ct='black_h_fc') 
			or (ct='black_h_rc') 
			or (ct='blue_h_fc') 
			or (ct='blue_h_rc')
			or (ct='black_d_fc') 
			or (ct='black_d_rc') 
			or (ct='blue_d_fc') 
			or (ct='blue_d_rc')
			or (ct='black_azimuthal_c') 
			or (ct='blue_azimuthal_c') then begin
		param_str:=bcam_camera_calib(calib,app,verbose,check);
	end;
	
	if (ct='black_polar_fs') 
			or (ct='blue_polar_fs') 
			or (ct='black_polar_rs') 
			or (ct='blue_polar_rs')
			or (ct='black_n_s') 
			or (ct='blue_n_s') 
			or (ct='black_h_fs') 
			or (ct='blue_h_fs') 
			or (ct='black_h_rs') 
			or (ct='blue_h_rs')
			or (ct='black_d_fs') 
			or (ct='blue_d_fs') 
			or (ct='black_d_rs') 
			or (ct='blue_d_rs')
			or (ct='black_fiber_rs') 
			or (ct='blue_fiber_rs')
			or (ct='black_azimuthal_s') 
			or (ct='blue_azimuthal_s') then begin
		param_str:=bcam_sources_calib(calib,app,verbose,check);
	end;
	
	if (ct='j_plate')
			or (ct='k_plate') then begin
		param_str:=bcam_jk_calib(calib,app,verbose,check);
	end;
	
	if error_string='' then Tcl_SetReturnString(interp,param_str)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_bcam_calib:=Tcl_OK;
end;

{
<p>lwdaq_diagnostic analyzes sixteen-bit adc samples from the driver supplies. It assumes that five numbers specifying the relay software version, the driver assembly number, the driver hardware version, the controller firmware version, and the data transfer speed are all saved in the input image's results string. The routine leaves these numbers in the results string after it is done.</p>
}
function lwdaq_diagnostic(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	option:string;
	arg_index:integer;
	vp:pointer;	
	v_min:real=0;
	v_max:real=0;
	t_min:real=0;
	t_max:real=0;
	ac_couple:boolean=false;
	 
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_diagnostic:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_diagnostic image ?option value?".');
		exit;
	 end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_diagnostic.');
		exit;
	end;
	
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-v_min') then v_min:=Tcl_ObjReal(vp)			
		else if (option='-v_max') then v_max:=Tcl_ObjReal(vp)			
		else if (option='-t_max') then t_max:=Tcl_ObjReal(vp)			
		else if (option='-t_min') then t_min:=Tcl_ObjReal(vp)			
		else if (option='-ac_couple') then ac_couple:=Tcl_ObjBoolean(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-v_max -v_min -t_max -t_min -ac_couple" in '
				+'lwdaq_diagnostic.');
			exit;
		end;
	end;
	
	result:=lwdaq_A2037_monitor(ip,t_min,t_max,v_min,v_max,ac_couple);
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_diagnostic:=Tcl_OK;
end;

{
<p>lwdaq_voltmeter analyzes image data for the Voltmeter instrument. We pass the routine an image name and it returns either a string of characteristics of the voltages recorded in the image, or the voltages themselves. It plots the voltages in the image overlay, according to plot ranges passed to the routine. The display looks like an oscilloscope, and provides a software trigger.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-v_min</td><td>The minimum voltage for the display.</td></tr>
<tr><td>-v_max</td><td>The maximum voltage for the display.</td></tr>
<tr><td>-t_min</td><td>The minimum time for the display.</td></tr>
<tr><td>-t_max</td><td>The maximum time for the display.</td></tr>
<tr><td>-ac_couple</td><td>Whether to subtract the average value from display.</td></tr>
<tr><td>-positive_trigger</td><td>Trigger on positive-going transition.</td></tr>
<tr><td>-v_trigger</td><td>The trigger voltage for display and extraction.</td></tr>
<tr><td>-auto_calib</td><td>Use the device's reference voltages.</td></tr>
<tr><td>-values</td><td>Return the voltage values rather than characteristics.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_voltmeter.</small></center>

<p>The lwdaq_voltmeter routine calls lwdaq_A2057_voltmeter to analyze the samples in the image. The image results string must contain some information about the samples that will allow the analysis to parse the voltages into reference samples and signal samples. The results string will contain 5 numbers. The first two are the bottom and top reference voltages available on the LWDAQ device. In the case of the A2057 these are 0 V and 5 V, but they could be some other value on another device. The third number is the gain applied to the signal. The fourth number is the data acquisition redundancy factor, which is the number of samples recorded divided by the width of the image. Because we will use a software trigger, we want to give the routine a chance to find a trigger and still have enough samples to plot one per image column. Suppose the image contains 200 columns, then we might record 600 samples so that any trigger occuring in the first 400 samples will leave us with 200 samples after the trigger to plot on the screen. In this case, our redundancy factor is 3. The fifth number is the number of channels from which we have recorded.</p>

<p>The result string "0.0 5.0 10 3 2" indicates 0 V and 5 V references, a gain of 10, a redundancy factor of 3 and two channels. The channels will be plotted with the usual LWDAQ <a href="https://www.bndhep.net/Electronics/LWDAQ/HTML/Plot_Colors.jpg">colors</a>, with the first channel being color zero.</p>

<p>The analysis assumes the samples are recorded as sixteen-bit numbers taking up two bytes, with the most significant byte first (big-endian short integer). The first byte of the recorded signal should be the first pixel in the second row of the image, which is pixel (0,1). If <i>n</i> is the image width and <i>r</i> is the redundancy factory, the first <i>n</i> samples (therefore 2<i>n</i> bytes) are samples of the bottom reference voltage. After that come <i>nr</i> samples from each channel recorded (therefore 2<i>nr</i> bytes from each channel). Last of all are <i>n</i> samples from the top reference.</p>

<p>The analysis uses the bottom and top reference values to calibrate the recorded signals, which are otherwise poorly defined in their correspondance between integer values and voltages. We turn on the calibration with the auto_calib option.</p>

<p>The recorded signal from the last channel to be analysed can be returned as a string. Each point consists of a time and a voltage. We instruct the analysis to return the points rather than characteristics with the values option. The following line of code extracts the signal of the last channel. Time zero will be the trigger instant if a trigger was detected, and the first sample otherwise. Thus the returned string contains more data than is plotted by the voltmeter analysis in the image overlay. It contains all the samples recorded.</p>

<pre>set trace [lwdaq_voltmeter image_name -values 1 -auto_calib 1]</pre>

<p>When the values option is not set, as is the case by default, the analysis returns four numbers for each channel recorded. The first number is the average value of the signal. The second is its standard deviation. You can obtain the root mean square of the signal by adding the square of the average and the standard deviation, and taking the square root. The third number is an estimate of the fundamental frequency of the recorded signal, if such a frequency exists, in Hertz, as obtained from a discrete fourier transform. To obtain the discrete fourier transform, we use a subset of the data containing an exact power of two number of samples. We pass this exact power of two number of samples to our fast fourier transform routine. The fourth number is the amplitude of this fundamental frequency.</p>
}
function lwdaq_voltmeter(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	option:string;
	arg_index:integer;
	vp:pointer;	
	v_min:real=0;
	v_max:real=0;
	v_trigger:real=0;
	t_min:real=0;
	t_max:real=0;
	ac_couple:boolean=false;
	auto_calib:boolean=false;
	positive_trigger:boolean=false;
	values:boolean=false;
	 
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_voltmeter:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_voltmeter image ?option value?".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_voltmeter.');
		exit;
	end;
	
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-v_min') then v_min:=Tcl_ObjReal(vp)			
		else if (option='-v_max') then v_max:=Tcl_ObjReal(vp)			
		else if (option='-v_trigger') then v_trigger:=Tcl_ObjReal(vp)			
		else if (option='-t_max') then t_max:=Tcl_ObjReal(vp)			
		else if (option='-t_min') then t_min:=Tcl_ObjReal(vp)			
		else if (option='-ac_couple') then ac_couple:=Tcl_ObjBoolean(vp)			
		else if (option='-positive_trigger') then positive_trigger:=Tcl_ObjBoolean(vp)			
		else if (option='-auto_calib') then auto_calib:=Tcl_ObjBoolean(vp)			
		else if (option='-values') then values:=Tcl_ObjBoolean(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'-v_max -v_min -t_max -t_min -ac_couple -auto_calib -values" in '
				+'lwdaq_voltmeter.');
			exit;
		end;
	end;
	result:=lwdaq_A2057_voltmeter(ip,t_min,t_max,v_min,v_max,v_trigger,
		ac_couple,positive_trigger,auto_calib);
		
	if error_string='' then begin
		if values then begin
			result:=string_from_xy_graph(electronics_trace);
			Tcl_SetReturnString(interp,result);
		end else begin
			Tcl_SetReturnString(interp,result);
		end;
	end else 
		Tcl_SetReturnString(interp,error_string);
	lwdaq_voltmeter:=Tcl_OK;
end;

{
<p>lwdaq_rfpm analyzes images from an RFPM instrument.</p>
}
function lwdaq_rfpm(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	option:string;
	arg_index:integer;
	vp:pointer;	
	v_min:real=0;
	v_max:real=0;
	rms:boolean=false;
	 
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_rfpm:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_rfpm image ?option value?".');
		exit;
	end;
	
	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_rfpm.');
		exit;
	end;
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-v_min') then v_min:=Tcl_ObjReal(vp)			
		else if (option='-v_max') then v_max:=Tcl_ObjReal(vp)			
		else if (option='-rms') then rms:=Tcl_ObjBoolean(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-v_max -v_min -rms" in '
				+'lwdaq_rfpm.');
			exit;
		end;
	end;
	result:=lwdaq_A3008_rfpm(ip,v_min,v_max,rms);
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_rfpm:=Tcl_OK;
end;

{
<p>lwdaq_inclinometer analyzes an image returned by the Inclinometer instrument. It returns the amplitude of harmonics in signals recorde in an image.</p>
}
function lwdaq_inclinometer(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	option:string;
	arg_index:integer;
	vp:pointer;	
	v_min:real=0;
	v_max:real=0;
	v_trigger:real=0;
	harmonic:real=1;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_inclinometer:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_inclinometer image ?option value?".');
		exit;
	end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_inclinometer.');
		exit;
	end;
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-v_min') then v_min:=Tcl_ObjReal(vp)			
		else if (option='-v_max') then v_max:=Tcl_ObjReal(vp)	
		else if (option='-harmonic') then harmonic:=Tcl_ObjReal(vp)	
		else if (option='-v_trigger') then v_trigger:=Tcl_ObjReal(vp)	
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-v_trigger -v_max -v_min -harmonic" in '
				+'lwdaq_inclinometer.');
			exit;
		end;
	end;
	result:=lwdaq_A2065_inclinometer(ip,v_trigger,v_min,v_max,harmonic);
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_inclinometer:=Tcl_OK;
end;

{
<p>lwdaq_receiver steps through the data bytes of an image, looking for valid four-byte messages, such as those transmitted by a Subcutaneous Transmitter (<a href="http://www.opensourceinstruments.com/Electronics/A3028/M3028.html">A3028</a>) and received by an Octal Data Receiver (<a href="http://www.opensourceinstruments.com/Electronics/A3018/M3027.html">A3027</a>). The lwdaq_receiver command takes two arguments. The first is the name of the image that contains the message data. The second is a command string. The command string in turn contains an instruction and some parameters. The function of lwdaq_receiver we describe in detail, with examples, in the <a href="http://www.opensourceinstruments.com/Electronics/A3018/Receiver.html">Receiver Instrument</a> manual. The lwdaq_receiver command calls another routine <i>lwdaq_sct_receiver</i>, which is defined in <a href="https://www.bndhep.net/Software/Sources/electronics.pas">electronics.pas</a>. The paragraphs below are the comments from the head of this lwdaq_sct_receiver function, and describe how to compose the command string we pass through lwdaq_receiver to lwdaq_sct_receiver. (Note: lwdaq_sct_receiver was formerly called lwdaq_sct_recorder. The new name should be used in all code.)</p>

<p>lwdaq_sct_receiver analyzes receiver messages. These messages have a four-byte core, and may be accompanied by one or more bytes of payload data. The routine assumes that the first byte of the second image row is the first byte of a message. Each message takes the following form: an eight-bit signal identifier, a sixteen-bit sample value, an eight-bit time stamp, and zero or more bytes of payload. The routine will return the sixteen-bit sample values, or various characteristics of the data block, depending upon the options passed in through the command string.</p>

<p>The routine does not return the payload directly, but instead uses the global electronics_trace to store indices that allow another routine to extract payload values from the image data. The electronics trace is filled with message indices when we execute the "extract" or "reconstruct" instructions.</p>

<p>The only command that alters the image data is "purge", which eliminates duplicate messages. All other commands leave the image data untouched. Some commands alter the image result string.</p>

<p>In some cases, following aborted data acquisition, it is possible for the data block to be aligned incorrectly, so that the first byte of the block is not the first byte of a message, but instead the second, third, or fourth byte of an incomplete message. The routine does not handle such exceptions. If we want to deal with such corruption, we must shift the image data one byte to the left and try again until we meet with success.</p>

<p>The command string passed into this routine begins with options and values, followed by an instruction and parameters. We present the options and instructions in the comments below. Each option must be accompanied by an option value.</p>

<p>The "-size n" option tells the routine how many messages are in the image. The default value is 0, in which case the routine scans through the entire image looking until it encounters a null message or the end of the image. A null message is any one for which the first four bytes are zero. Such messages arise in corrupted recordings, but are also used to fill in the remainder of the image after the last valid message. If n > 0, the routine reads n messages even if there are null messages in the block it reads.</p>

<p>The "-payload n" option indicates that the four-byte core of each message is followed by n bytes of payload data. The default value of n is zero. The only instruction that returns the payload data directly is the "print" instruction. Otherwise, payload data is accessible through a list of indices passed back by the "extract" and "reconstruct" instructions.</p>

<p>The "-glitch x" option enables a glitch filter where applicable, as described below, the value x being the maximum absolute change in sample value that  will be left intact without an attempt to over-write and remove with previous sample values. But default x is zero and the filter is disabled.</p>

<p>The "-divergent b" option enables tolerance of a sample clock that diverges significantly from that of the data receiver. This option affects the reconstruction instruction only. We use zero and one to indicate false and true.</p>

<p>	The "-activity n" option sets the minimum number of samples a signal channel must contain for either plotting or listing.</p>

<p>Because of limitations in their logic, some data receivers may be unable to eliminate duplicate messages from their data stream. The same signal message received on two or more antennas may appear two or more times in the data. This routine eliminates these duplicates when it copies the messages from the image block into a separate message array. We will see the duplicates with the "print" and "get" instructions, which operate on the original image data. But all other instructions operate upon the message array, from which duplicates have been removed.</p>

<p>The "get" instruction performs no analysis of messages, but instead returns only the id, value, and timestamp of a list of messages. We specify each message with its index. The first message it message zero. A message index greater than the maximum number of messages the image can hold, or less than zero, will return zero values for all parameters.</p>

<p>The "purge" instruction re-writes the image data, eliminating duplicate messages and returning the number of messages in the purged data. This  instruction is for diagnostic purposes only: we do not eliminate messages from the raw data before writing to disk.</p>

<p>The "plot" instruction tells the routine to plot all messages received from the channel numbers we specify, or all channels if we specify a "*" character. No elimination of messages nor reconstruction is performed prior to plotting, but if we use the -glitch option to enable a glitch filter, this filter will be applied to the signals before plotting and summarizing. The two parameters after the plot instruction specify the minimum and maximum values of the signal in the interval. The next parameter is either AC or DC, to specify the display coupling. After these three, we add the identifiers of the signals we want to plot. To specify all signals except the clock signal, use a "*". The routine returns a summary result of the form "id_num num_message ave stdev" for each selected channel. For the clock channel signal, which is channel number zero, the routine gives the start and end clock samples. The final two numbers in the summary result are the invalid_id code followed by the number of messages the routine did not plot.</p>

<p>The "print" instruction returns the error_report string followed by the content of all messages, or a subrange of messages. In the event of analysis failure, "print" will assume messages are aligned with the first data byte in the image, and print out the contents of all messages, regardless of errors found. When analysis fails because there are too many messages in the image, the result string returned by print is likely to be cut off at the end. The "print" instruction tries to read first_message and last_message out of the command string. If they are present, the routine uses these as the first and last message numbers it writes to its return string. Otherwise it returns all messages.</p>

<p>The "extract" instruction tells the routine to return a string containing all messages from a specified signal, but rejecting duplicates. A duplicate is any message with the same value as the previous message, and a timestamp that is at most one later than the previous message. The routine takes two parameters. The first is the identifier of the signal we want to extract. The second is the sampling period in clock ticks. The routine returns each message on a separate line. On each line is the time of the message in ticks from the beginning of the image time interval, followed by the sample value. The command writes the following numbers into ip^.results: the number of clock messages in the image and the number of samples it extracted.</p>

<p>The "reconstruct" instruction tells the routine to reconstruct a particular signal with the assumption that the transmission is periodic with temporal scattering of transmission to avoid systematic collisions between transmitters. Where messages are missing from the data, the routine adds substitute messages. It removes duplicate messages and messages that occur at invalid moments in time. The result of reconstruction is a sequence of messages with none missing and none extra. The instruction string for the "reconstruct" instruction begins with the word "reconstruct" and is followed by several paramters. The first parameter is the identifier of the signal we want to reconstruct. The second parameter is its nominal sampling period in clock ticks. The third parameter is "standing_value", the signal's most recent correct sample value. If the -glitch option has been used to set a non-zero glitch threshold, the routine applies this filter after reconstruction is complete. If the -divergent option has been enabled, the reconstruction permits greater disagreement between the transmitter and receiver clocks. By default, standing_value, glitch_threshold, and divent_clocks are all zero. The result string contains the reconstructed message stream with one message per line. Each message is represented by the time it occured, in ticks after the first clock in the image time interval, and the message data value. The "reconstruct" command writes the following numbers into ip^.results: the number of clock messages in the image, the number of messages in the reconstructed messages stream, the number of bad messages, and the number of substituted messages.</p>

<p>The "clocks" instruction returns a the number of errors in the sequence of clock messages, the number of clock messages, the total number of messages from all signals, and the byte location of clock messages specified by a list of integers. The command "clocks 0 100" might return "0 128 640 0 500" when passed a 2560-byte block of messages containing 128 valid clocks and 512 messages from non-clock signals. The last two numbers are the byte location of the 1st clock message and the byte location of the 101st clock message. A negative index specifies a clock message with respect to the end of the message block. Thus "-1" specifies the last clock message.</p>

<p>The "list" instruction returns a list of signal identifiers and the number of samples in the signal. Signals with no samples are omitted from the list. The list takes the form of channel identifier followed by number of samples separated by spaces.</p>

<p>The "auxiliary" instruction extracts and returns all auxiliary messages in a string. An auxiliary message is one in which the lower four bits are equal to fifteen. The instruction returns one message per line. For each message it writes the eight-bit channel number, the sixteen-bit timestamp, and the sixteen-bit contents.</p>

<p>The "system" instruction extracts and returns all system messages in a string, excluding the clock messages. An system message is one in which the lower four bits are equal to zero. The instruction returns one message per line. For each message it writes the eight-bit channel number, the sixteen-bit timestamp, and the sixteen-bit contents.</p>
}
function lwdaq_receiver(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	show_timing=false;
	
var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	command:string='';

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_receiver:=Tcl_Error;
	
	if argc<>3 then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_receiver image command".');
		exit;
	end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_receiver.');
		exit;
	end;
	command:=Tcl_ObjString(argv[2]);
	
	start_timer('starting '''+command+'''','lwdaq_receiver');
	result:=lwdaq_sct_receiver(ip,command);
	mark_time('done with '''+command+'''','lwdaq_receiver');
	if show_timing then report_time_marks;
		
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_receiver:=Tcl_OK;
end;

{
<p>lwdaq_alt extracts power measurements from data recorded by an Animal Location Tracker (ALT, <a href="http://www.opensourceinstruments.com/Electronics/A3038/M3038.html">A3038</a>) so as to measure the location of telemetry devices such as our Subcutaneous Transmitters (<a href="http://www.opensourceinstruments.com/SCT">SCT</a>), Implantable Inertial Sensors (<a href="http://www.opensourceinstruments.com/IIS">IIS</a>), and Implantable Stimulator-Transponders (<a href="http://www.opensourceinstruments.com/IST">IST</a>). The routine assumes that the global electronics_trace is a valid xy_graph created by lwdaq_receiver, giving a list of x-y values in which x is an integer time and y is an integer index. The message corresponding to time <i>x</i> is the <i>y</i>'th message in the Receiver Instrument image to which we applied the lwdaq_receiver routine. The electronics_trace will be valid provided that the most recent call to the lwdaq electronics library was the <a href="https://www.bndhep.net/Electronics/LWDAQ/Commands.html#lwdaq_receiver">lwdaq_receiver</a> with either the "extract" or "reconstruct" instructions.</p>

<p>The routine takes two parameters and has several options. The first parameter is the name of the image that contains the tracker data. The indices in electronics_trace must refer to the data space of this image. An index of <i>n</i> points to the <i>n</i>'th message in the data, with the first message being number zero. Each message starts with four bytes and is followed by one or more <i>payload bytes</i>. The payload bytes contain one or more power measurements.</p>

<p>The second parameter is a list of locations of detector coils, given as a sequence of numbers <i>x</i>, <i>y</i>, <i>z</i> separated by spaces. When calculating the location of a transmitter, lwdaq_alt will center each detector on these coordinates. All coordinates are assumed to be greater than or equal to zero, so that (-1,-1,-1) will be recognised as an invalid location. When we pass "-1 -1 -1" as the coordinate of a coil, lwdaq_alt does not include the coil in its position calculation. We use position "-1 -1 -1" for auxiliary antenna coils in animal location trackers. The A3038C, for example, provides fifteen tracker coils and a sixteenth auxiliary antenna input that may be used for reception of telemetry signals and for measuring background power. We use any position (-1,y,z) for coils we want to ignore. We might have sixteen detector antennas divided into two sets of eight for monitoring the location of animals in two habitats. When we calculate position in the first habitat, we ignore the coils arranged in the second habitat. We set the coordinates of the coils we want to ignore to "-1 y z", where <i>y</i> and <i>z</i> can be anything. In a two-dimensional tracker platform such as the A3038C, the value of the <i>z</i>-coordinate will be shared by all coils. Regardless of the arrangent of antennas, all <i>z</i>-coordinates must be greater than zero. We must make it impossible for the measured position of the transmitter to come out as "0.0 0.0 0.0" because we use this origin position to indicate "no position measurement obtained in this interval". For the A3038C we set the <i>z</i>-coordinage to 2.0, the approximate distance from the center of its detector coils to a transmitter sitting on the platform.</p>

<p>The lwdaq_alt routine supports the following options:</p>

<center><table border>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-payload</td><td>Payload length in bytes, default 16.</td></tr>
<tr><td>-scale</td><td>Number of eight-bit counts corresponding to 10 dB power increase, default 30.</td></tr>
<tr><td>-extent</td><td>Radius for coil inclusion about coil with maximum power.</td></tr>
<tr><td>-percentile</td><td>Fraction of power measurements below chosen value, default 50.</td></tr>
<tr><td>-background</td><td>String of background power levels to be subtracted from coil powers, default all 0.</td></tr>
<tr><td>-slices</td><td>Number of sub-intervals for which we calculate power and position, default 1.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_alt.</small></center>

<p>The output contains <i>x</i>, <i>y</i>, and <i>z</i> in whatever units we used to specify the coil centers, followed by a string of detector power values. If <i>slices</i> &gt; 1, we will have <i>slices</i> lines in our output string, each giving the position and powers values for a fraction of the interval represented by the data image. The purpose of the <i>slices</i> option is to permit us to play through a recording with eight-second intervals and yet obtain tracker measurements with a sample period that is some integer fraction of the interval period. The unit of activity is coil center units per slice interval. If we break the interval into eight slices and specify coil positions in centimeters, the activity will be centimeters per eighth of a second.</p>

<p>The -background option allows us to specify background power levels for all detector coils, in anticipation of a need to calibrate detectors. By default, these background powers are all zero. If we pass an empty string for the background powers, lwdaq_alt will use zeros. The -extent value sets a maximum distance from the location of the transmitter to a coil used to calculate the transmitter location. The -payload value is the number of bytes added to the core four-byte message in order to accommodate the power values. A fifteen-coil tracker has payload sixteen and returns sixteen power values. The first fifteen are the powers from the coils, in the order defined by the tracker's geometry map. The sixteenth value is either zero or the power we obtain from an auxiliary detector module.</p>
}
function lwdaq_alt(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	core_message_length=4;
	error_value=-1;
	power_hi=255;
	power_lo=0;

var 
{
	Input and output vehicles.
}
	ip:image_ptr_type=nil;
	image_name:string='';
	field,result:string;
	option:string='';
	arg_index:integer;
	vp:pointer;
{
	Default option values.
}
	payload:integer=16; {value for any ALT with fifteen coils}
	extent:real=1e10; {infinity}
	percentile:real=50; {median power value will be used}
	scale:real=30; {eight-bit counts per decade of weight}
	num_slices:integer=1; {default one}
{
	Result variables.
}
	location,max_location:xyz_point_type;
	detector_powers:x_graph_type;
{
	Variables for position calculations.
}
	num_samples,num_detectors,sample_num,detector_num:integer;
	slice_num,slice_size:integer;
	max_power,min_power,scaled_power:real;
	sum_power:real=-1;
	sum_x:real=-1;
	sum_y:real=-1;
	sum_z:real=-1;
	detector_coordinates:xyz_graph_type;
	detector_samples:x_graph_type;
	detector_background:x_graph_type;

	{
		A function to extract the sn'th sample made by the dn'th detector
		coil. We use the index stored in the electronics trace to find the
		message and its payload in the image data. If the index is -1, we 
		set the power measurement to zero.
	}
	function power_measurement(sn,dn:integer):integer;
	var n,i:integer;
	begin
		i:=round(electronics_trace[sn].y);
		if i>=0 then begin
			n:=i*(payload+core_message_length)
				+core_message_length
				+dn;
			power_measurement:=
				get_px(ip,(n div ip^.i_size)+1,(n mod ip^.i_size));
		end else 
			power_measurement:=0;
	end;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_alt:=Tcl_Error;
	setlength(detector_background,0);

	if (argc<3) or (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_alt image xycoordinates ?option value?".');
		exit;
	end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in lwdaq_alt.');
		exit;
	end;
	
	num_samples:=length(electronics_trace);
	if num_samples=0 then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Number of samples is zero in lwdaq_alt.');
		exit;
	end;

	{
		We must have the detector coordinates, or else we cannot use power values to
		determine location. From the detector coordinates, we deduce the number of
		detectors.
	}
	field:=Tcl_ObjString(argv[2]);
	detector_coordinates:=read_xyz_graph(field);
	num_detectors:=length(detector_coordinates);
	if num_detectors=0 then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Number of detectors is zero in lwdaq_alt.');
		exit;
	end;
	
	{
		Handle options.
	}
	arg_index:=3;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-payload') then payload:=Tcl_ObjInteger(vp)			
		else if (option='-scale') then scale:=Tcl_ObjReal(vp)			
		else if (option='-extent') then extent:=Tcl_ObjReal(vp)			
		else if (option='-slices') then num_slices:=Tcl_ObjInteger(vp)			
		else if (option='-background') then begin
			field:=Tcl_ObjString(vp);
			detector_background:=read_x_graph(field);
		end else if (option='-percentile') then percentile:=Tcl_ObjReal(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"image -payload -extent -scale -background -percentile -slices'
				+'-previous -filter" in lwdaq_alt.');
			exit;
		end;
	end;

	{
		The payload must be large enough for the number of detectors.
	}	
	if num_detectors>payload then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Payload length less than number of detector coordinates in lwdaq_alt.');
		exit;
	end;
	
	{
		If no detector background power values were specified, we set the background
		powers to zero, and no calibration of the power measurements will take place.
	}
	if (length(detector_background)=0) then begin
		setlength(detector_background,num_detectors);
		for detector_num:=0 to num_detectors-1 do
			detector_background[detector_num]:=0;
	end;

	{
		We are going to calculate the location of the transmitter in each of
		one or more slices, so prepare result arrays.
	}
	slice_size:=num_samples div num_slices;
	if slice_size < 1 then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Fewer than one message per slice in lwdaq_alt.');
		exit;
	end;

	{
		Create arrays for detector powers and samples.
	}
	setlength(detector_powers,num_detectors);
	setlength(detector_samples,slice_size);

	{
		Calculate location in each slice using a new percentile power value
		calculated for each slice. Write the result string as we go.
	}
	result:='';
	for slice_num:=0 to num_slices-1 do begin
		{
			Calculate the median power value for each detector coil in this
			time slice. Obtain the maximum, and minimum coil powers in case
			we need them. Record the location of the coil with the maximum power.
		}
		min_power:=power_hi;
		max_power:=power_lo;
		max_location:=detector_coordinates[0];
		for detector_num:=0 to num_detectors-1 do begin
			for sample_num:=0 to slice_size-1 do
				detector_samples[sample_num]:=
					power_measurement((slice_num*slice_size)+sample_num,detector_num);
			detector_powers[detector_num]:=
				percentile_x_graph(detector_samples,percentile)
				-detector_background[detector_num];
			if (detector_coordinates[detector_num].x <> -1)
				and (detector_powers[detector_num]>max_power) then begin
				max_power:=detector_powers[detector_num];
				max_location:=detector_coordinates[detector_num];
			end;
			if (detector_coordinates[detector_num].x <> -1)
				and (detector_powers[detector_num]<min_power) then 
				min_power:=detector_powers[detector_num];
		end;
		
		{
			The detector coil power measurements we obtain from the tracker are
			logarithmic. We want to perform a weighted centroid on the power
			itself, or the square root of the power, not on the logarithm of the
			power. We take the anti-log of the power measurement. But we need to
			know what increment in power measurement corresponcs to a factor of
			ten increase in received power or received square root of power.
			This scaling factor is what we have in our "scale" parameter. We use
			the scale to obtain the "power weight". We don't need to obtain an
			absolute power value from the detector coils: so long as we know the
			relative magnitude of the power received in each coil we can obtain
			the centroid. We assume that a power value of zero corresponds to
			unit weight. We reject any coils that are farther than the extent
			from the coil with maximum power.
		}
		sum_x:=0;
		sum_y:=0;
		sum_z:=0;
		sum_power:=0;
		for detector_num:=0 to num_detectors-1 do begin
			if (detector_coordinates[detector_num].x <> -1)
				and (xyz_separation(
					detector_coordinates[detector_num],max_location)
					< extent) then begin
				scaled_power:=xpy(10,
					(detector_powers[detector_num]-min_power+scale)/scale);
				sum_x:=sum_x
					+scaled_power*detector_coordinates[detector_num].x;
				sum_y:=sum_y
					+scaled_power*detector_coordinates[detector_num].y;
				sum_z:=sum_z
					+scaled_power*detector_coordinates[detector_num].z;
				sum_power:=sum_power
					+scaled_power;
			end;
		end;
		if sum_power>0 then begin
			location.x:=sum_x/sum_power;
			location.y:=sum_y/sum_power;
			location.z:=sum_z/sum_power;
		end else begin
			location.x:=error_value;
			location.y:=error_value;
			location.z:=error_value;
		end;
		
		field:='';
		writestr(field,location.x:1:1,' ',location.y:1:1,' ',location.z:1:1,' ');
		for detector_num:=0 to num_detectors-1 do
			writestr(field,field,detector_powers[detector_num]:1:1,' ');
		insert(field,result,length(result)+1);			
		if slice_num<num_slices-1 then
			insert(eol,result,length(result)+1);
	end;
	
	{
		Return the result string or, if we have one, an error string.
	}
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_alt:=Tcl_OK;
end;

{
<p>lwdaq_tcb extracts the top antenna and top power from data recorded by a Telemetry Control Box (TCB, <a href="http://www.opensourceinstruments.com/Electronics/A3038/M3038.html">A3042</a>). The top antenna is a number specifying one of the antennas connected to the TCB. Each of these antennas is capable of receiving telemetry messages from devices such as our Subcutaneous Transmitters (<a href="http://www.opensourceinstruments.com/SCT">SCT</a>), Implantable Inertial Sensors (<a href="http://www.opensourceinstruments.com/IIS">IIS</a>), or Implantable Stimulator-Transponders (<a href="http://www.opensourceinstruments.com/IST">IST</a>). For each message it receives, the TCB adds a payload of two bytes to the core four-byte telemetry message. The first payload byte is the maximum power with which this message was received by any of the TCB's antennas. The second payload byte is a number identifying this antenna. We call this antenna the <i>top</i> antenna and its received power is the <i>top</i> power. The TCB-A16 antenna inputs are numbered 1-16 on the connectors on the back of the box. The top antenna number provided by the TCB-A16 gives us the antenna input to which the top antenna is connected.</p>

<p>If we know where our antennas are located in our recording system, the top antenna number gives us an approximate measurement of the transmitter's location. Most likely, the transmitter is nearer to the top antenna than to any other. If the transmitter is half-way between two antennas, we may see the top antenna number varying from one received message to the next. The lwdaq_tcb routine returns the median antenna number and the median power. Our assumption is that these two median values correspond to one another. We convert the antenna number into a three-dimensional position with a string of three-dimensional points, each point representing the location of an antenna in an arbitrary three-dimensional coordinate system with arbitrary units. The lwdaq_tcb routine picks the point corresponding to the top antenna and returns its three coordinates <i>x</i>, <i>y</i>, and <i>z</i>. We must choose the coordinate system for the antennas such that all <i>z</i>-coordinates are positive and non-zero. By this means, we allow our analysis of animal movement, which we apply to a history of animal position, to use coordinate "0.0 0.0 0.0" as a marker for "no measurement in this interval".</p>

<p>The routine takes two parameters and has a single option. The first parameter is the name of the image that contains the tracker data. The indices in electronics_trace must refer to the data space of this image. An index of <i>n</i> points to the <i>n</i>'th message in the data, with the first message being number zero. Each message starts with four bytes and is followed by one or more <i>payload bytes</i>. The payload bytes contain one or more power measurements. The routine assumes that the global electronics_trace is a valid xy_graph created by lwdaq_receiver, giving a list of x-y values in which x is an integer time and y is an integer index. The message corresponding to time <i>x</i> is the <i>y</i>'th message in the Receiver Instrument image to which we applied the lwdaq_receiver routine. The electronics_trace will be valid provided that the most recent call to the lwdaq electronics library was the <a href="https://www.bndhep.net/Electronics/LWDAQ/Commands.html#lwdaq_receiver">lwdaq_receiver</a> with either the "extract" or "reconstruct" instructions. The second parameter is a list of locations of antennas, given as a sequence of numbers <i>x</i>, <i>y</i>, <i>z</i> separated by spaces. The "slices" option tells the routine how many top antenna measurements to make within the playback interval covered by the data image.</p>

<center><table border>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-slices</td><td>Number of sub-intervals for which we calculate power and position, default 1.</td></tr>
</table><small><b>Table:</b> Options for lwdaq_tcb.</small></center>

<p>The lwdaq_tcb output is compatible with that of <a href="#lwdaq_alt">lwdaq_alt</a>. The first three values returned are <i>x</i>, <i>y</i>, and <i>z</i> of the top antenna. Next comes one power value for each antenna. These are all zero except for that of the top antenna, for which the power is the value recorded by the TCB. If <i>slices</i> &gt; 1, we will have <i>slices</i> lines in our output string, each giving the position and power for a fraction of the interval represented by the data image.</p>
}
function lwdaq_tcb(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	core_message_length=4;
	error_value=-1;
	power_hi=255;
	power_lo=0;
	payload=2;
	percentile=50;

var 
{
	Input and output vehicles.
}
	ip:image_ptr_type=nil;
	image_name:string='';
	field,result:string;
	option:string='';
	arg_index:integer;
	vp:pointer;
{
	Default option values.
}
	num_slices:integer=1; {default one}
{
	Result variables.
}
	location:xyz_point_type;
{
	Variables for position calculations.
}
	num_samples,sample_num:integer;
	num_antennas,antenna_num:integer;
	slice_num,slice_size:integer;
	antenna_coordinates:xyz_graph_type;
	top_powers,top_antennas:x_graph_type;
	top_antenna:integer;
	top_power:real;
	
	{
		A function to extract the bn'th payload byte of the sn'th sample. We use
		the index stored in the electronics trace to find the message and its
		payload in the image. If the index is -1, we set the power
		measurement to zero.
	}
	function payload_byte(sn,bn:integer):integer;
	var i:integer;
	begin
		i:=round(electronics_trace[sn].y);
		if i>=0 then begin
			payload_byte:=image_data_byte(ip,
				i*(payload+core_message_length)+core_message_length+bn);
		end else 
			payload_byte:=0;
	end;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_tcb:=Tcl_Error;

	if (argc<3) or (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_tcb image xycoordinates ?option value?".');
		exit;
	end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in lwdaq_tcb.');
		exit;
	end;
	
	num_samples:=length(electronics_trace);
	if num_samples=0 then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Number of samples is zero in lwdaq_tcb.');
		exit;
	end;

	{
		We must have the antenna coordinates, or else we cannot use power values to
		determine location. From the antenna coordinates, we deduce the number of
		antennas.
	}
	field:=Tcl_ObjString(argv[2]);
	antenna_coordinates:=read_xyz_graph(field);
	num_antennas:=length(antenna_coordinates);
	if num_antennas=0 then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Number of antennas is zero in lwdaq_tcb.');
		exit;
	end;
	
	{
		Handle options.
	}
	arg_index:=3;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-slices') then num_slices:=Tcl_ObjInteger(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-slices" in lwdaq_tcb.');
			exit;
		end;
	end;

	{
		We are going to calculate the location of the transmitter in each of
		one or more slices, so prepare result arrays.
	}
	slice_size:=num_samples div num_slices;
	if slice_size < 1 then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Fewer than one message per slice in lwdaq_tcb.');
		exit;
	end;

	{
		Create arrays for antenna powers and samples.
	}
	setlength(top_powers,slice_size);
	setlength(top_antennas,slice_size);

	{
		Obtain the median top antenna number and top power value. Use the top antenna
		number to extract the top antenna location and construct an array of power
		measurements that are all zeros except for that of the top antenna. We do 
		this for each slice, returning a separate line for each slice in our result
		string.
	}
	result:='';
	for slice_num:=0 to num_slices-1 do begin
		for sample_num:=0 to slice_size-1 do begin
			top_powers[sample_num]:=payload_byte(sample_num,0);
			top_antennas[sample_num]:=payload_byte(sample_num,1);
		end;
		
		top_power:=percentile_x_graph(top_powers,percentile);
		top_antenna:=round(percentile_x_graph(top_antennas,percentile));
		if (top_antenna>=1) and (top_antenna<=num_antennas) then
			location:=antenna_coordinates[top_antenna-1]
		else
			location:=antenna_coordinates[0];
		
		field:='';
		writestr(field,location.x:1:1,' ',location.y:1:1,' ',location.z:1:1,' ');
		for antenna_num:=1 to num_antennas do
			if antenna_num=top_antenna then
				writestr(field,field,top_power:1:1,' ')
			else
				writestr(field,field,'0.0 ');
		insert(field,result,length(result)+1);			
		if slice_num<num_slices-1 then
			insert(eol,result,length(result)+1);
	end;
	
	{
		Return the result string or, if we have one, an error string.
	}
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_tcb:=Tcl_OK;
end;

{
	lwdaq_simplex_error takes a simplex vertex type and a pointer to a string
	containing a Tcl command name and executes this command with the numerical
	values specified in the vertex type. The routine is used exclusively by
	lwdaq_simplex.
}
function lwdaq_simplex_error(v:simplex_vertex_type;ep:pointer):real;
type
	error_string_ptr=^string;
var 
	j:integer;
	obj_ptr:pointer;
	error:integer;
	command:string;
	result:string;
begin
	command:=error_string_ptr(ep)^+' [list ';
	for j:=1 to length(v) do
		writestr(command,command,v[j]:fsr:fsd,' ');
	writestr(command,command,']');
	error:=Tcl_Eval(gui_interp_ptr,PChar(command));
	obj_ptr:=Tcl_GetObjResult(gui_interp_ptr);
	result:=Tcl_ObjString(obj_ptr);
	if error>0 then begin
		report_error(result+' in lwdaq_simplex');
		lwdaq_simplex_error:=0;
	end else begin
		lwdaq_simplex_error:=read_real(result);
	end;
end;

{
<p>lwdaq_simplex finds a point in an <i>n</i>-dimensional space at which an error function is a minium. The routine takes a minimum of two parameters: the initial position and an error procedure name. The initial position must be a list of <i>n</i> real numbers. The error procedure must be defined in the Tcl interpreter, take a single list as its input, and return a real-valued error measurement. The single list argument, when passed into the error funtion by lwdaq_simplex, will contain <i>n</i> space-delimited real numbers. The error routine must extract and assign the numbers from this list. We call the Tcl error routine with the help of the lwdaq_simplex_error interface function. This helper function prints <i>n</i> real numbers to a string and makes sure they are passed as a single list argument into the Tcl error function. The simplex fitter starts at the initial position and moves through the n-dimensional space until it reaches a maximum number of steps specified with the "-max_steps <i>m</i>" option. When it stops, it returns the point of convergeance as <i>n</i> real numbers, the final error value, and the number of steps it took.</p>

<center><table border cellspacing=2>
<tr>
	<th>Option</th>
	<th>Function</th>
</tr>
<tr>
	<td>-report <i>m</i></td>
	<td>Print progress line every <i>m</i> iterations, default 0 no reporting.</td>
</tr>
<tr>
	<td>-steps <i>m</i></td>
	<td>Abort after <i>m</i> steps, default 0 is no maximum.</td>
</tr>
<tr>
	<td>-scaling <i>s</i></td>
	<td>Scaling factors, default <i>s</i> is a string of <i>n</i> ones.</td>
</tr>
<tr>
	<td>-start_size <i>d</i></td>
	<td>Simplex construction size, default <i>d</i> = 1.0.</td>
</tr>
<tr>
	<td>-end_size <i>d</i></td>
	<td>Simplex size at convergeance, default <i>d</i> = 0.01.</td>
</tr>
<tr>
	<td>-restarts <i>m</i></td>
	<td>Number of restarts before starting to shrink, default <i>m</i> = 0.</td>
</tr>
</table><small><b>Table:</b> Options For lwdaq_simplex.</small></center>

<p>By default, the simplex routine assumes that the sensitivity of the error to each of the n coordinates is similar, so that it sets up its simplex triangle with equal length in all n dimensions. If the sensitivity of the error function is dramatically different for different coordinates, we can specify the sensitivity through the "-scaling <i>s</i>" option. If the error is ten times less sensitive to one coordinate than the others, we give it a scaling factor of ten and the other coordinates a scaling factor of one. If we do not specify the scaling factors, the routine assumes a value of unity for all coordinates.</p>

<p>When the fit takes a long time, or when we are trying to figure out why it won't converge, it's nice to have the fit print out the coordinates and the error value every <i>m</i>'th iteration, which we achieve with "-report <i>m</i>". The report calls gui_writeln, which in turn prints in a Tk text widget called gui_text_name. We set gui_text_name with <a href="#lwdaq_config">lwdaq_config</a>.</p>

<p>We avoid freezing LWDAQ during a long fit by calling LWDAQ_support in the error procedure. To permit the user to abort the fit, have the error procedure check a global abort flag. When the error procedure sees the abort, it can return a Tcl error to the lwdaq_simplex routine, and lwdaq_simplex will abort.</p>
}
function lwdaq_simplex(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	max_n=1000;
	
var 
	error_proc:string='';
	simplex:simplex_type;
	i,n,interation_num:integer;
	result:string;
	setup:string='';
	report:integer=0;
	scaling:string='';
	restarts:integer=0;
	start_size:real=1.0;
	steps:integer=0;
	end_size:real=0.01;
	option:string='';
	arg_index:integer;
	vp:pointer;	
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_simplex:=Tcl_Error;
	
	if argc<3 then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_simplex start_point error_proc".');
		exit;
	end;

	setup:=Tcl_ObjString(argv[1]);
	n:=word_count(setup);
	if (n<1) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'No coordinates in lwdaq_simplex.');
		exit;
	end;
	if (n>max_n) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'More than max_n coordinates in lwdaq_simplex.');
		exit;
	end;

	error_proc:=Tcl_ObjString(argv[2]);
	
	arg_index:=3;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-report') then report:=Tcl_ObjInteger(vp)			
		else if (option='-steps') then steps:=Tcl_ObjInteger(vp)			
		else if (option='-scaling') then scaling:=Tcl_ObjString(vp)			
		else if (option='-restarts') then restarts:=Tcl_ObjInteger(vp)			
		else if (option='-start_size') then start_size:=Tcl_ObjReal(vp)			
		else if (option='-end_size') then end_size:=Tcl_ObjReal(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-report -steps -scaling -start_size -end_size -restarts"'
				+' in lwdaq_simplex.');
			exit;
		end;
	end;
	
	simplex:=new_simplex(n);
	for i:=1 to n do simplex.vertices[1,i]:=read_real(setup);
	simplex.max_restarts:=restarts;
	simplex.start_size:=start_size;
	simplex.end_size:=end_size;
	if scaling<>'' then begin
		if word_count(scaling)<>n then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Number of scaling factors not equal to number of parameters'
				+' in lwdaq_simplex.');
			exit;
		end;
		for i:=1 to n do
			simplex.scaling[i]:=read_real(scaling);
	end;
	simplex_construct(simplex,lwdaq_simplex_error,@error_proc);
	
	interation_num:=0;
	repeat
		if (report>0) and (interation_num mod report = 0) then begin
			result:='';
			for i:=1 to n do
				writestr(result,result,simplex.vertices[1,i]:fsr:fsd,' ');
			writestr(result,result,simplex.errors[1]:fsr:fsd,' ',interation_num:1);
			gui_writeln(result);
		end;
		simplex_step(simplex,lwdaq_simplex_error,@error_proc);
		inc(interation_num);
	until simplex.done 
		or ((interation_num>=steps) and (steps>0))
		or (error_string<>'');
		
	result:='';
	for i:=1 to n do
		writestr(result,result,simplex.vertices[1,i]:fsr:fsd,' ');
	writestr(result,result,simplex.errors[1]:fsr:fsd,' ',interation_num:1);

	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_simplex:=Tcl_OK;
end;

{
<p>lwdaq_gauge analyzes sixteen-bit adc values by calling lwdaq_A2053_gauge. The routine assumes that two numbers specifying the sample period and the number of channels sampled are saved in the input image's results string. The routine leaves these numbers in the results string after it is done. For each gauge channel in the image, the routine returns a result, according to the result specifiers. With -ave 1, the result for each channel includes the average gauge value. With -stdev 1, the result includes the standard deviation of the gauge value. With both set to zero, the result is an empty string. The default values for ave and stdev are 1 and 0 respectively.</p>
}
function lwdaq_gauge(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	option:string;
	arg_index:integer;
	vp:pointer;	
	y_min:real=0;
	y_max:real=0;
	t_min:real=0;
	t_max:real=0;
	ref_bottom:real=0;
	ref_top:real=100;
	ac_couple:boolean=false;
	stdev:boolean=false;
	ave:boolean=true;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_gauge:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_gauge image ?option value?".');
		exit;
	end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_gauge.');
		exit;
	end;
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-y_min') then y_min:=Tcl_ObjReal(vp)			
		else if (option='-y_max') then y_max:=Tcl_ObjReal(vp)			
		else if (option='-t_max') then t_max:=Tcl_ObjReal(vp)			
		else if (option='-t_min') then t_min:=Tcl_ObjReal(vp)			
		else if (option='-ref_bottom') then ref_bottom:=Tcl_ObjReal(vp)			
		else if (option='-ref_top') then ref_top:=Tcl_ObjReal(vp)			
		else if (option='-ac_couple') then ac_couple:=Tcl_ObjBoolean(vp)			
		else if (option='-stdev') then stdev:=Tcl_ObjBoolean(vp)			
		else if (option='-ave') then ave:=Tcl_ObjBoolean(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"image -y_max -y_min -t_max -t_min -ac_couple -stdev -ave" in '
				+'lwdaq_gauge.');
			exit;
		end;
	end;
	result:=lwdaq_A2053_gauge(ip,t_min,t_max,y_min,y_max,
		ac_couple,ref_bottom,ref_top,
		ave,stdev);
		
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_gauge:=Tcl_OK;
end;

{
<p>lwdaq_flowmeter analyzes sixteen-bit adc values by calling lwdaq_A2053_flowmeter. It assumes that two numbers specifying the sample period and the number of channels sampled are saved in the input image's results string. The routine leaves these numbers in the results string after it is done.</p>
}
function lwdaq_flowmeter(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	image_name:string='';
	result:string='';
	option:string;
	arg_index:integer;
	vp:pointer;	
	c_min:real=0;
	c_max:real=0;
	t_min:real=0;
	t_max:real=0;
	ref_bottom:real=15.38;
	ref_top:real=25.69;
	 
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_flowmeter:=Tcl_Error;
	
	if (argc<2) or (odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_flowmeter image ?option value?".');
		exit;
	end;

	image_name:=Tcl_ObjString(argv[1]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_flowmeter.');
		exit;
	end;
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-c_min') then c_min:=Tcl_ObjReal(vp)			
		else if (option='-c_max') then c_max:=Tcl_ObjReal(vp)			
		else if (option='-t_max') then t_max:=Tcl_ObjReal(vp)			
		else if (option='-t_min') then t_min:=Tcl_ObjReal(vp)			
		else if (option='-ref_bottom') then ref_bottom:=Tcl_ObjReal(vp)			
		else if (option='-ref_top') then ref_top:=Tcl_ObjReal(vp)			
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-c_max -c_min -t_max -t_min" in '
				+'lwdaq_flowmeter.');
			exit;
		end;
	end;
	result:=lwdaq_A2053_flowmeter(ip,t_min,t_max,c_min,c_max,ref_bottom,ref_top);
	
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);
	lwdaq_flowmeter:=Tcl_OK;
end;

{
<p>lwdaq_graph takes a string of numbers and plots them in the image overlay, displaying them by means of lines between the consecutive points. The string of numbers may contain x-y value pairs, or x values only or y values only. The default is x-y values. With <i>y_only</i> = 1 it assumes y values only and assigns x-value 0 to the first y-value, 1 to the next, and so on. With <i>x_only</i> = 1 it assumes x values only and assigns y-value 0 to the first x-value, &minus;1 to the next, and so on. The negative-going y-values are consistent with the negative-going vertical image coordinates, so that <i>x_only</i> is useful for plotting image properties on top of an image, such as vertical intensity profile. Thus the following code plots the vertical and horizontal intensity profiles in an image overlay</p>

<pre>set profile [lwdaq_image_profile imagname -row 1]
lwdaq_graph $profile imagname -y_only 1 -color 3
set profile [lwdaq_image_profile imagname -row 0]
lwdaq_graph $profile imagname -x_only 1 -color 4</pre>

<p>The graph will fill the analysis boundaries of the image unless you set <i>entire</i> = 1, in which case the graph will fill the entire image. The routine returns the number of points it plotted.</p>

<p>You can specify the values of x and y that correspond to the edges of the plotting area with <i>x_min</i>, <i>x_max</i>, <i>y_min</i>, and <i>y_max</i>. By default, however, the routine will stretch of compress the plot to fit exactly in the available space.</p>

<center><table border>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-x_min</td><td>x at left edge, if 0 with x_max = 0, use minimum value of x, default 0</td></tr>
<tr><td>-x_max</td><td>x at right edge, if 0 with x_min = 0, use maximum value of x, default 0</td></tr>
<tr><td>-y_min</td><td>y at bottom edge, if 0 with y_max = 0, use minimum value of y, default 0</td></tr>
<tr><td>-y_max</td><td>y at top edge, if 0 with y_min = 0, use maximum value of y, default 0</td></tr>
<tr><td>-ac_couple</td><td>1 add average y-value to y_min and y_max, default 0</td></tr>
<tr><td>-glitch</td><td>&gt;0, apply glitch filter before plotting, default 0 disabled.</td></tr>
<tr><td>-color</td><td>integer code for the color, default 0</td></tr>
<tr><td>-clear</td><td>1, clear image overlay before plotting, default 0</td></tr>
<tr><td>-fill</td><td>1, fill image overlay before plotting, default 0</td></tr>
<tr><td>-width</td><td>width of plot line, default 1</td></tr>
<tr><td>-x_div</td><td>&gt; 0, plot vertical divisions spaced by this amount, default 0 disabled</td></tr>
<tr><td>-y_div</td><td>&gt; 0, plot horizontal divisions spaced by this amount, default 0 disabled</td></tr>
<tr><td>-y_only</td><td>1, data is y-values only, default 0.</td></tr>
<tr><td>-x_only</td><td>1, data is x-values only, default 0.</td></tr>
<tr><td>-entire</td><td>1 use entire image for plot, 0 use analysis bounds, default 0.</td></tr>
<tr><td>-in_image</td><td>1 draw as a shade of gray in the image rather than overlay, default 0.</td></tr></table><small><b>Table:</b> Options for lwdaq_graph.</small></center>

<p>By default, the graph will be drawn in the overlay, so it can use colors and be accompanied by grid lines that do not interfere with the underlying image data. The overlay can be transparent or white, depending upon whether we have cleared or filled the overlay respectively before calling <i>lwdaq_graph</i>. But if <i>in_image</i> is 1, the color will be treated as a shade of gray and the graph will be drawn in the image itself. By this means, we can create images for two-dimensional analysis out of graphs. When <i>in_image</i> is set, the <i>x_div</i> and <i>y_div</i> options are ignored.</p>

<p>The color codes for a graph in the overlay give 255 unique colors. You can try them out to see which ones you like. The colors 0 to 15 specify a set of distinct colors, as shown <a href="https://www.bndhep.net/Electronics/LWDAQ/HTML/Plot_Colors.jpg">here</a>. The remaining colors are eight-bit RGB codes. If you don't specify a color, the plot will be red. The line will be one pixel wide unless we specify a larger  width with the -width option, which takes an integert value one or greater.</p>

<p>Some data contains occasional error samples, which we call <i>glitches</i>. The <i>lwdaq_graph</i> "-glitch <i>g</i>" option allows you to specify a threshold for glitch filtering. The <i>lwdaq_graph</i> routine calls the <i>glitch_filter_y</i> from <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a> to eliminate glitches from the sequence of <i>y</i>-coordinates. We provide the same glitch filter at the command line with the <a href="#glitch_filter_y">glitch_filter_y</a>.</p>
}
function lwdaq_graph(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	ip:image_ptr_type=nil;
	gxy:xy_graph_type;
	gx:x_graph_type;
	image_name:string='';
	result:string='';
	option:string;
	arg_index:integer;
	vp:pointer;	
	x_min:real=0;
	x_max:real=0;
	y_min:real=0;
	y_max:real=0;
	x_div:real=0;
	y_div:real=0;
	width:integer=1;
	num_points:integer=0;
	point_num:integer=0;
	color:integer=0;
	shade:integer=0;
	clear:boolean=false;
	entire:boolean=false;
	fill:boolean=false;
	ac_couple:boolean=false;
	y_only:boolean=false;
	x_only:boolean=false;
	in_image:boolean=false;
	glitch:real=0;
	average:real;
	saved_bounds:ij_rectangle_type;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_graph:=Tcl_Error;
	
	if (argc<3) or (not odd(argc)) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_graph data image ?option value?".');
		exit;
	end;

	arg_index:=3;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-x_min') then x_min:=Tcl_ObjReal(vp)			
		else if (option='-x_max') then x_max:=Tcl_ObjReal(vp)			
		else if (option='-y_max') then y_max:=Tcl_ObjReal(vp)			
		else if (option='-y_min') then y_min:=Tcl_ObjReal(vp)			
		else if (option='-color') then color:=Tcl_ObjInteger(vp)			
		else if (option='-width') then width:=Tcl_ObjInteger(vp)			
		else if (option='-clear') then clear:=Tcl_ObjBoolean(vp)			
		else if (option='-entire') then entire:=Tcl_ObjBoolean(vp)			
		else if (option='-fill') then fill:=Tcl_ObjBoolean(vp)			
		else if (option='-x_div') then x_div:=Tcl_ObjReal(vp)			
		else if (option='-y_div') then y_div:=Tcl_ObjReal(vp)
		else if (option='-y_only') then y_only:=Tcl_ObjBoolean(vp)
		else if (option='-x_only') then x_only:=Tcl_ObjBoolean(vp)
		else if (option='-ac_couple') then ac_couple:=Tcl_ObjBoolean(vp)
		else if (option='-glitch') then glitch:=Tcl_ObjReal(vp)
		else if (option='-in_image') then in_image:=Tcl_ObjBoolean(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-x_max -x_min -y_max -y_min -clear -color -x_div -y_div '
				+'"-fill -width -entire -y_only -glitch" in '
				+'lwdaq_graph.');
			exit;
		end;
	end;
	
	image_name:=Tcl_ObjString(argv[2]);
	ip:=image_ptr_from_name(image_name);
	if not valid_image_ptr(ip) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Image "'+image_name+'" does not exist in '
			+'lwdaq_graph.');
		exit;
	end;
	if clear then clear_overlay(ip);
	if fill then fill_overlay(ip);
	saved_bounds:=ip^.analysis_bounds;
	if entire then begin
		with ip^.analysis_bounds do begin
			left:=0;
			top:=0;
			right:=ip^.i_size-1;
			bottom:=ip^.j_size-1;
		end;
	end;

	result:=Tcl_ObjString(argv[1]);
	if y_only then begin
		gx:=read_x_graph(result);
		setlength(gxy,length(gx));
		for point_num:=0 to length(gx)-1 do begin
			gxy[point_num].x:=point_num;
			gxy[point_num].y:=gx[point_num];
		end;
	end;
	if x_only then begin 
		gx:=read_x_graph(result);
		setlength(gxy,length(gx));
		for point_num:=0 to length(gx)-1 do begin
			gxy[point_num].y:=-point_num;
			gxy[point_num].x:=gx[point_num];
		end;
	end;
	if (not y_only) and (not x_only) then 
		gxy:=read_xy_graph(result);

	if glitch>0 then glitch_filter_y(gxy,glitch);

	color:=byte_shift*(width-1)+overlay_color(color);
	shade:=byte_shift*(width-1)+color;	
	
	if ac_couple then begin
		average:=average_y_xy_graph(gxy);
		if not in_image then
			display_real_graph(ip,gxy,color,
				x_min,x_max,y_min+average,y_max+average,x_div,y_div)
		else
			draw_real_graph(ip,gxy,shade,
				x_min,x_max,y_min+average,y_max+average);
	end else 
		if not in_image then
			display_real_graph(ip,gxy,color,
				x_min,x_max,y_min,y_max,x_div,y_div)
		else
			draw_real_graph(ip,gxy,shade,
				x_min,x_max,y_min,y_max);

	if entire then ip^.analysis_bounds:=saved_bounds;

	writestr(result,num_points:1);
	if error_string='' then Tcl_SetReturnString(interp,result)
	else Tcl_SetReturnString(interp,error_string);

	lwdaq_graph:=Tcl_OK;
end;

{
<p>lwdaq_filter applies a recursive filter to a sampled signal. The samples are passed to lwdaq_filter as a string of space-delimited real numbers. By default, lwdaq_filter assumes every number in the string is a sample. With the -tv_format option set to 1, lwdaq_filter assumes every other number in the string is a uniformly-spaced sample, in the form "t v ", where "t" is time and "v" is the sample. In this case, lwdaq_filter reads the v-values only.</p>

<p>The routine returns its answer as a string of space-delimited real numbers. By default, lwdaq_filter returns a signal with as many samples as it received, separated by spaces, and formatted withe the global fsr (field size real) and fsd (field size decimal) values. With -tv_format set to 1, lwdaq_filter copies the t-values from the input string, so as to create an output string with the same t-values, but processed v-values.</p>

<center><table border cellspacing=2>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-tv_format</td><td>if 0, data points "v", otherwise "t v", default 0</td></tr>
<tr><td>-ave_start</td><td>if 1, over-write first sample with average, default 0</td></tr>
</table><small><b>Table:</b> Options for lwdaq_filter.</small></center>

<p>We define the digital signal processing we with lwdaq_filter to perform by means of two strings. The first string gives the coefficients a[0]..a[n] by which the input values x[k]..x[k-n] are multiplied before adding to y[k]. The second string gives the coefficients b[1]..b[n] by which the previous outputs y[k-1]..y[k-n] are multiplied before adding to y[k].</p>
}
function lwdaq_filter(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	vt_signal:xy_graph_type;
	signal:x_graph_type;
	filtered:x_graph_type;
	a_list:string='';
	b_list:string='';
	option:string='';
	arg_index,point_num:integer;
	vp:pointer;	
	result:string;
	tv_format:boolean=false;
	ave_start:boolean=false;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_filter:=Tcl_Error;
{
	Check the argument list.
}
	if (argc<4) or odd(argc) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_filter data a_list b_list ?option value?".');
		exit;
	end;
{
	Determine the options.
}
	arg_index:=4;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-tv_format') then tv_format:=Tcl_ObjBoolean(vp)		
		else if (option='-ave_start') then ave_start:=Tcl_ObjBoolean(vp)	
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-tv_format -ave_start" in '
				+'lwdaq_filter.');
			exit;
		end;
	end;
{
	Read the data into a graph and get the command string.
}
	arg_index:=1;
	result:=Tcl_ObjString(argv[arg_index]);
	if tv_format then begin
		vt_signal:=read_xy_graph(result);
		setlength(signal,length(vt_signal));
		for point_num:=0 to length(signal)-1 do
			signal[point_num]:=vt_signal[point_num].y;
	end else begin
		signal:=read_x_graph(result);
	end;
	if ave_start then
		signal[0]:=average_x_graph(signal);
	inc(arg_index);
	a_list:=Tcl_ObjString(argv[arg_index]);
	inc(arg_index);
	b_list:=Tcl_ObjString(argv[arg_index]);
	inc(arg_index);
{
	Call the dsp routine on the signal.
}
	filtered:=recursive_filter(signal,a_list,b_list);	
{
	Prepare the output data.
}
	if filtered<>nil then begin
		if tv_format then begin
			for point_num:=0 to length(filtered)-1 do
				vt_signal[point_num].y:=filtered[point_num];
			result:=string_from_xy_graph(vt_signal);
		end else
			result:=string_from_x_graph(filtered);
		Tcl_SetReturnString(interp,result);
	end;
{
	Dispose of pointers and check for errors.
}
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_filter:=Tcl_OK;
end;

{
<p>lwdaq_fft applies a fast fourier tranfsorm to a waveform and returns the complete <a href="https://grokipedia.com/page/Discrete_Fourier_transform">discrete fourier transform</a> (DFT). In general, the DFT transforms a set of <i>N</i> complex-valued samples and returns a set of <i>N</i> complex-valued frequency components. We assume the samples, are uniformly-spaced with respect to some one-dimensional quantity such as time or distance. The <i>sample period</i> is the separation of the samples in this one-dimensional quantity. We denote the sample period with <i>T</i> and the one-dimensional quantity we denote as <i>t</i>. We denote the sample at <i>t</i> = <i>nT</i> with <i>x<sub>n</sub></i>, where <i>n</i> is an integer such that 0&le;<i>n</i>&le;<i>N</i>&minus;1. We denote the transform components <i>X<sub>k</sub></i>, where <i>k</i> is an integer such that 0&le;<i>k</i>&le;<i>N</i>&minus;1. Each transform component represents a complex sinusoidal function in <i>t</i>. The <i>k</i>'th sinusoid, <i>S<sub>k</sub></i>, has frequency <i>k</i>/<i>NT</i>. Its magnitude and phase are given by <i>X<sub>k</sub></i>.</p>

<big>
<p>
<i>S<sub>k</sub></i> = 
<i>X<sub>k</sub></i> e<sup>2&pi;<i>kt</i>/<i>NT</i></sup>
</p>
</big>

<p>In the text-book definition of the <a href="https://grokipedia.com/page/Discrete_Fourier_transform">discrete fourier transform</a>, <i>X<sub>k</sub></i> is <i>N</i> times larger, and we must divide by <i>N</i> to obtain the sinusoidal amplitude. But we pre-scaled our components by 1/<i>N</i> so we return the sinusoidal comonents directly. If we express <i>X<sub>k</sub></i> as a magnitude, <i>A<sub>k</sub></i>, and a phase &Phi;<sub>k</sub>, we get the following expression for the sinusoid.</p>

<big>
<p>
<i>S<sub>k</sub></i> = 
<i>A<sub>k</sub></i> e<sup>2&pi;<i>kt</i>/<i>NT</i>+&Phi;<sub>k</sub></sup>
</p>

<p>
<i>S<sub>k</sub></i> = 
<i>A<sub>k</sub></i>cos(2&pi;<i>kt</i>/<i>NT</i>+&Phi;<sub>k</sub>)
+<i>i</i><i>A<sub>k</sub></i>sin(2&pi;<i>kt</i>/<i>NT</i>+&Phi;<sub>k</sub>)
</p>
</big>

<p>When our inputs <i>x<sub>n</sub></i> are real-valued, we find that the the <i>k</i>'th component of the transform is the complex conjugate of component <i>N</i>&minus;<i>k</i>. A feature of all discrete transform is <i>X<sub>k</sub></i> = <i>X<sub>k&minus;N</sub></i>. Thus <i>X<sub>N&minus;k</sub></i> = <i>X<sub>&minus;k</sub></i>, the component with frequency &minus;<i>k</i>/<i>NT</i>. We observe that cos(<i>v</i>) = cos(&minus;<i>v</i>) and sin(<i>v</i>) = &minus;sin(&minus;<i>v</i>), so the &minus;<i>k</i>'th component is the complex conjugate of the <i>k</i>'th component. This means that the <i>N</i>&minus;<i>k</i>'th component is equal to the <i>k</i>'th component.</p>

<big>
<p>
<i>S<sub>k</sub></i> + <i>S<sub>&minus;k</sub></i> = 
2<i>A<sub>k</sub></i>cos(2&pi;<i>kt</i>/<i>NT</i>+&Phi;<sub>k</sub>)
</p>
</big>

<p>The 0'th and <i>N</i>/2'th components we cannot sum together using the above trick. But these components always have phase 0 or &pi; when the inputs are real-valued. We can represent them with two real-valued numbers, where the magnitude of the number is the magnitude of the component and the sign is the phase 0 or &pi;.</p>

<p>The <i>lwdaq_fft</i> routine will accept <i>N</i> complex-valued samples in the form <i>x<sub>n</sub></i> = <i>u</i>+<i>iv</i> and return <i>N</i> complex-valued components in the form <i>X<sub>k</sub></i> = <i>U</i>+<i>iV</i>. We specify complex-valued input with option "-complex 1". The default option, however, is "-complex 0", which specifies real-valued input and returns <i>N</i>/2 real-valued components. We obtain the <i>N</i>/2 components by adding each <i>X<sub>k</sub></i> to its complex conjugate <i>X<sub>N&minus;k</sub></i>. We express these real-valued frequency components with two numbers each, 2<i>A<sub>k</sub></i> and &Phi;<sub>k</sub>. These represent a cosine with amplitude 2<i>A<sub>k</sub></i>, angular frequency 2&pi;<i>k</i>/<i>NT</i> (rad/s), and phase shift &Phi;<sub>k</sub> (rad).</p>

<p>The 0'th component of the real-valued transform is an exception. It contains two numbers, but neither of them is a phase. One is the magnitude of the 0'th component, which is the DC component, and the <i>N</i>/2'th component, which is the Nyquist-frequency component.</p>

<p>The <i>lwdaq_fft</i> routine insists upon <i>N</i> being a power of two so that the fast fourier transform algorithm can divide the problem in half repeatedly until it arrives at transforms of length 1. For the fast fourier transform algorithm itself, see the <i>fft</i> routine in <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>. For its real-valued wrapper see <i>fft_real</i>.</p>

<pre>lwdaq_config -fsr 1 -fsd 2
lwdaq_fft "1 1 1 1 1 1 1 0"
0.88 0.13 0.25 -2.36 0.25 -1.57 0.25 -0.79</pre>

<p>In the example, we supply the routine with eight real-valued samples and obtain a transform of eight numbers. The first number tells us the magnitude and phase of the 0-frequency component. This number is equal to the average value of the samples, and is often called the "DC-component". The second number gives us the Nyquist-frequency component, which is the component with period two sample intervals. Here, the Nyquist-frequency component is the 4-frequency component with period N/4 (N=8). We multiply a cosine by this mangnitude and we obtain the 4-frequency component of the transform. Its phase can be either +&pi; or &minus;&pi;, and so is represented by the signe of the component magnitude.</p>

<p>The remaining components in the tranform, 1 through 3, are each represented by two numbers, a magnitude, <i>a</i>, and a phase <i>&Phi;</i>. We obtain the value of component <i>k</i> at time <i>t</i> with <i>a</i>cos(2&pi;<i>kt</i>/<i>NT</i>+&Phi;). If we use sample number, <i>n</i>, instead of time, the component is <i>a</i>cos(2&pi;<i>kn</i>/<i>N</i>+&Phi;).</p>

<pre>lwdaq_fft "1 0 1 0 1 0 1 0 1 0 1 0 1 0 0 0" -complex 1
0.88 0.00 -0.09 -0.09 -0.00 -0.13 0.09 -0.09 0.13 0.00 0.09 0.09 0.00 0.13 -0.09 0.09</pre>

<p>We submit the same data to the complex version of the transform by accompanying each sample with a zero phase, so as to indicate a real value with a complex number. The result is a transform that is equivalent to our first, abbreviated transform. You can see the <i>N</i>/4 component as "0.13 0.00" and the 0 component as "0.88 00". There are two <i>N</i>/1 frequency components "-0.09 -0.09" and "-0.09 0.09". Their magnitude is 0.127 and their phases are &minus;3&pi;/4 and &minus;&pi;/4. When we add these magnitudes together we obtain the <i>N</i>/1 component of the real-valued transform, which is 0.25 as shown above. The phase of the <i>N</i>/1 component is &minus;3&pi;/4 = &minus;2.36 radians, which is also what we see in the real-valued transform above.</p>

<p>Here is another example. In this case, the <i>N</i>/4 component is zero, as is the 0 component.</p>

<pre>lwdaq_fft "1 1 1 1 -1 -1 -1 -1"
0.00 0.00 1.31 -1.18 0.00 0.00 0.54 -0.39 
lwdaq_fft "1 0 1 0 1 0 1 0 -1 0 -1 0 -1 0 -1 0" -complex 1
0.00 0.00 0.25 -0.60 0.00 0.00 0.25 -0.10 0.00 0.00 0.25 0.10 0.00 0.00 0.25 0.60 </pre>

<p>If the samples were taken over 1 s, the eight components represent frequencies 0, 1, 2, and 3 Hz. So we see the square wave of frequency 1 Hz has harmonics at 1 Hz and 3 Hz. The fourier series expansion of a square wave has harmonics of amplitude 4/<i>n</i>&pi; for the <i>n</i>'th harmonic. The first harmonic in the fourier series would have amplitude 1.27. Our 1-Hz component has amplitude 1.31. The discrete fourier transform is an exact representation of the original data, but it does not provide all the harmonics of the fourier series. Therefore, the existing harmonics are not exactly of the same amplitude as those in the fourier series.</p>

<p>The phases of the components in our example are also correct. The first harmonic is offset by &minus;1.18 radians, which means it is a cosine delayed by 1.18/2&pi; = 0.188 of a period, or 1.5 samples. We see that a cosine delayed by 1.5 samles will reach its maximum between samples 1 and 2, which matches our input data. In the example below, we change the phase of the input by &pi; and we see the phase of the fundamental harmonic changes by &pi;.</p>

<pre>lwdaq_fft "1 1 1 1 0 0 0 0"
0.50 0.00 0.65 -1.18 0.00 0.00 0.27 -0.39 
lwdaq_fft "0 0 0 0 1 1 1 1"
0.50 0.00 0.65 1.96 0.00 0.00 0.27 2.75 </pre>

<p>We can use <i>lwdaq_fft</i> to perform the inverse transform, but we must invoke the "-inverse 1" option or else the inverse does not come out quite right.</p>

<pre>set dft [lwdaq_fft "1 0 1 0 1 0 1 0 -1 0 -1 0 -1 0 -1 0" -complex 1]
0.00 0.00 0.25 -0.60 0.00 0.00 0.25 -0.10 0.00 0.00 0.25 0.10 0.00 0.00 0.25 0.60 
lwdaq_fft $dft -complex 1
0.12 0.00 -0.12 0.00 -0.12 0.00 -0.12 0.00 -0.12 0.00 0.12 -0.00 0.12 -0.00 0.12 -0.00 
lwdaq_fft $dft -complex 1 -inverse 1
1.00 0.00 0.99 -0.00 1.00 -0.00 0.99 -0.00 -1.00 0.00 -0.99 0.00 -1.00 0.00 -0.99 0.00 </pre>

<p>The "-inverse 1" option reverses the order of the input components, which is a trick for getting the forward transform to act like an inverse transform, and then multiplies the resulting sample-values by <i>N</i> to account for the fact that our <i>lwdaq_fft</i> routine scales its frequency components by 1/<i>N</i> to make them correspond to sinusoidal amplitudes. The reversal of the input components and the scaling takes place in <i>fft_inverse</i> of <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>.</p>

<p>We can also invert our compact magnitude-phase transforms, which we derive from real-valued inputs with the "-complex 0" option (the default).</p> 

<pre>set dft [lwdaq_fft "1 1 1 1 -1 -1 -1 -1"]
0.00 0.00 1.31 -1.18 0.00 0.00 0.54 -0.39 
lwdaq_fft $dft -inverse 1
1.00 1.00 1.01 1.00 -1.00 -1.00 -1.01 -1.00 </pre>

<p>Note the rounding errors we see because we are using only two decimal places in our examples. For the real-valued inverse transform code, see <i>fft_real_inverse</i> in <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>.</p>

<p>The fft, like all discrete fourier transforms, assumes that the <i>N</i> samples are the entire period of a repeating waveform. The <i>N</i> components of the transform, when inverted, give us an exact reproduction of the original <i>N</i> samples. As you are looking at the signal represented by the N samples, be aware that any difference between the 0'th sample and the (<i>N</i>-1)'th sample amounts to a discontinuity at the end of the repeating waveform. A ramp from 0 to 1000 during the <i>N</i> samples gives rise to a sudden drop of 1000. This sudden drop appears as power in all frequency components.</p>

<p>One way to remove end steps is to apply a <a href="https://grokipedia.com/page/Window_function">window function</a> to the data before you take the fourier transform. We provide a linear window function with the "-window <i>w</i>" option, where we apply the window function to the first <i>w</i> samples and the final <i>w</i> samples. This window function is the same one we provide separately in our <a href="#window_function">window function</a> routine. We recommend you calculate <i>w</i> as a fraction of <i>N</i> when you call <i>lwdaq_fft</i>. We suggest starting <i>w</i> = <i>N</i>/10. We implement the window function only for real-valued samples passed to the forward transform. If you try to apply the window function during the inverse transform or when passing complex samples to the forward transform, <i>lwdaq_fft</i> returns an error. That's not to say that there is no point in applying a window function in these other circumstances, but our linear window function does not have any obvious utility or meaning when so applied.</p>

<p>Some data contains occasional error samples, called <i>glitches</i>. At some point in our data analysis, we must eliminate these glitches. The <i>lwdaq_fft</i> "-glitch <i>g</i>" option allows you to specify a threshold for glitch filtering. The <i>lwdaq_fft</i> routine calls the one-dimensional <i>glitch_filter</i> from <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>. We provide this routine at the command line with the <a href="#glitch_filter">glitch_filter</a> library command. The "-glitch" option is compatible only with real-valued data passed to the forward transform. A threshold value of 0 disables the filter.</p>
}
function lwdaq_fft(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var 
	gp:xy_graph_type;
	ft:xy_graph_type;
	gpx:x_graph_type;
	option:string='';
	arg_index:integer;
	vp:pointer;	
	result:string='';
	complex:boolean=false;
	inverse:boolean=false;
	window:integer=0;
	glitch:real=0;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_fft:=Tcl_Error;
{
	Check the argument list.
}
	if (argc<2) or odd(argc) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_fft data ?option value?".');
		exit;
	end;
{
	Determine the options.
}
	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-complex') then complex:=Tcl_ObjBoolean(vp)	
		else if (option='-inverse') then inverse:=Tcl_ObjBoolean(vp)
		else if (option='-window') then window:=Tcl_ObjInteger(vp)
		else if (option='-glitch') then glitch:=Tcl_ObjReal(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-complex -inverse -window -glitch" in '
				+'lwdaq_fft.');
			exit;
		end;
	end;
{
	Check for incompatible options.
}
	if ((window<>0) or (glitch<>0)) and (inverse or complex) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'"-window" and "-glitch" cannot be used with '
			+'-complex" or "-inverse" in lwdaq_fft.');
		exit;
	end;
{
	The forward transform.
}
	if not inverse then begin
		result:=Tcl_ObjString(argv[1]);
		if complex then begin
			gp:=read_xy_graph(result);
			ft:=fft(gp);
		end else begin
			gpx:=read_x_graph(result);
			if glitch>0 then glitch_filter(gpx,glitch);
			if window>0 then window_function(gpx,window);
			ft:=fft_real(gpx);
		end;
		result:=string_from_xy_graph(ft);
	end;
{
	The reverse transform.
}
	if inverse then begin
		result:=Tcl_ObjString(argv[1]);
		ft:=read_xy_graph(result);
		if complex then begin
			gp:=fft_inverse(ft);
			result:=string_from_xy_graph(gp);
		end else begin
			gpx:=fft_real_inverse(ft);
			result:=string_from_x_graph(gpx);
		end;
	end;
{
	Return result or error as required.
}
	Tcl_SetReturnString(interp,result);
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_fft:=Tcl_OK;
end;

{
<p>lwdaq_metrics takes a sequence of real numbers as input and returns a list of real-valued properties of the input sequence. The input sequence represent samples of a signal, such as an EEG recording, and the metrics represent properties of the signal, such as average value, standard deviation, maximum, minimum, coastline length, intermittency of high-frequency power, spikiness, asymmetry, and so on. The lwdaq_metrics routine is an interface with the <a href="https://www.bndhep.net/Software/Sources/metrics.pas">metrics.pas</a> library of metric-calculating routines. To select one of these routines, and control its output, we pass a command string into lwdaq_metrics following the data string.</p>
}
function lwdaq_metrics(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var
	metrics:string='';
	command:string='';
	select:string='';
	result:string='';
	gp:x_graph_type;

begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_metrics:=Tcl_Error;

	if (argc<>3) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, should be "'
			+'lwdaq_metrics data command".');
		exit;
	end;

	result:=Tcl_ObjString(argv[1]);
	gp:=read_x_graph(result);
	command:=Tcl_ObjString(argv[2]);

	metrics:='invalid command';
	select:=read_word(command);
	if select='A' then metrics:=metric_calculation_A(gp,command)
	else if select='B' then metrics:=metric_calculation_B(gp,command)
	else if select='C' then metrics:=metric_calculation_C(gp,command)
	else if select='D' then metrics:=metric_calculation_D(gp,command)
	else if select='E' then metrics:=metric_calculation_E(gp,command)
	else report_error('invalid selection "'+select+'" in lwdaq_metrics');

	Tcl_SetReturnString(interp,metrics);
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_metrics:=Tcl_OK;
end;

{
<p>lwdaq_rag provides routines to support retrieval-assisted generation (RAG). It creates and maintains a library of embedding vectors in memory. It allows us to compare a new vector to every vector in the library and obtain a list of the most relevant library entries, a process we call <i>retrieval</i>. Each embed in the library has a name, a relevance, and an n-dimensional vector. The name is a string of characters that identify a document chunk, although lwdaq_rag at no point handles anything but embedding vectors, nor does it read embedding vectors from disk or write them to disk. The vector itself, as delivered to the library, can have integer or real-valued components, but all components will be saved as real numbers. All vectors in the library must have the same length so that the dot product of a test vector with each vector will be proportional to the cosine of the angle between each vector and the test vector.  The relevance stored with each embed is the dot product we obtained from the most recent comparison. The lwdaq_rag guarantees that all vectors have unit length by calcualting the length of each vector it receives, and dividing all its coordinates by the length.</p>

<p>The lwdaq_rag command is used by the RAG Manager tool to load a library of embedding vectors into memory, and subsequently to compare a question vector to all library entries. Embedding vectors provided by services such as OpenAI's text-embedding-3-small have real-valued components and are normalized to unit length. The RAG Manager calls lwdaq_rag to manage its embed library. To obtain 0.1% precision in relevance measurement, while at the same time reducing the size of the embeds on disk, the RAG Manager scales the vectors by &times;100k and rounds the coordinates to integers before storing to disk. These integer-coordinate vectors all have length 100k. We pass them directly into the embed directory, and the embed library automatically normalizes them to unit length.</p>

<p>The lwdaq_rag command operates on a persitent embedding library. This library can be replaced, but unless replaced, it persists so long as the LWDAQ instance that created it persists. We create a new library with the <i>create</i> operation. Here is an example library creation command, one that creates a library of 925 embeds, each with 1536-dimensional vectors.</p>

<pre>lwdaq_rag create -lib_len 925 -vec_len 1536</pre>

<p>Here we specify the number of entries in the library with the -lib_len option and the number of dimensions to each vector with -vec_len. These two options are both mandatory if we want to be sure the library fits our embedding vectors, but lwdaq_rag initializes both parameters from the existing library, so it will not raise an error if we fail to specify one or both.</p> 
<center><table border>
<tr><th>Option</th><th>Function</th></tr>
<tr><td>-lib_len</td><td>Number of embeds in the library, default 1.</td></tr>
<tr><td>-vec_len</td><td>Number of coordinates in embedding vectors, default 1.</td></tr>
<tr><td>-retrieve_len</td><td>Number of chunks returned by comparison, default 10.</td></tr>
<tr><td>-name</td><td>A name for a new vector, default "Empty".</td></tr>
<tr><td>-vector</td><td>A list of integers specifying a vector, devault "0".</td></tr>
<tr><td>-scale</td><td>The scaling factor used to make integer coordinates, default "1".</td></tr>
</table><small><b>Table:</b> Options for lwdaq_rag.</small></center>

<p>We add vectors to the library one at a time with the <i>add</i> operation. When we add a new vector, the library must already exist, and be set up for vectors of the same length. We do not specify vector length when we add, we just specify a name and provide the vector itself. In the following example, we create a library with the <i>create</i> operation, add three embeds with <i>add</i> and use the <i>dump</i> operation to show the library contents.</p>

<pre>lwdaq_rag create -lib_len 5 -vec_len 4
lwdaq_rag add -name v0 -vector "1 2 3 4"
lwdaq_rag add -name v1 -vector "2 3 4 1"
lwdaq_rag add -name v2 -vector "3 4 1 2"
lwdaq_rag dump
v0 1 2 3 4 
v1 2 3 4 1 
v2 3 4 1 2 
EMPTY 0 0 0 0 
EMPTY 0 0 0 0</pre>

<p>The three embeds that have not been filled are named "EMPTY" and their components are all zero. Any comparison made with empty vectors will produces a zero relevance. Creation of a library is fast, but adding vectors is slow, because we are passing the vectors as strings, and these must be converted to integers before storage. If we create a library larger than our immediate needs, we can add more vectors without having to re-load all the existing vectors. The lwdaq_rag command has no operation for extending a library.</p>

<p>We compare a test vector to our library and obtain a list of the most relevant vectors with the <i>retrieve</i> operation. We pass the vector into the lwdaq_rag routine with the -vector option just as we do for the <i>add</i> operatin. The text vector must has integer coordinates if it is to be compared effectively, because lwdaq_rag will round all its coordinates to the nearest integer before proceeding with calculating the dot product of the test vector with every vector in the library and storing the dot product in each embed's relevance parameter. Here is an example comparison following the code above.</p>

<pre>lwdaq_rag retrieve -retrieve_len 2 -vector "4 3 2 1"
v2 28 v1 26</pre>

<p>The comparison returns -retrieve_len embeds in order of descending relevance. The first embed returned is the one of greatest relevance. The relevant embeds are returned as a space-delimited string. Each embed name is followed by its relevance.</p>

<p>Each entry in the embed list consists of its name, its relevance, and a pointer to the embed vector. When we sort the embed list, we don't have to move the vectors around in memory. We just swap the pointers around in the embed list. Thus the sort time is independent of the vector size. We use our quick_sort routine to sort the embed list in order of decreasing relevance, so we expect the sort time to increase as <i>N</i>log<sub>2</sub><i>N</i>, where <i>N</i> is the length of the library. Here are creation, vector addition, and retrieval times for increasing library lengths.</p>

<center><table border>
<tr><th>lib_len</th><th>Create (ms)</th><th>Add (ms)</th><th>Load (s)</th><th>Retrieval (ms)</th></tr>
<tr><td>100</td><td>0</td><td>5.1</td><td>0.5</td><td>4.6</td></tr>
<tr><td>200</td><td>0</td><td>4.6</td><td>0.9</td><td>5.4</td></tr>
<tr><td>500</td><td>1</td><td>5.3</td><td>2.6</td><td>6.0</td></tr>
<tr><td>1000</td><td>1</td><td>4.7</td><td>4.6</td><td>8.0</td></tr>
<tr><td>2000</td><td>3</td><td>4.8</td><td>9.6</td><td>12.4</td></tr>
<tr><td>5000</td><td>9</td><td>4.8</td><td>24.3</td><td>26.0</td></tr>
<tr><td>10000</td><td>13</td><td>5.2</td><td>51.8</td><td>49.6</td></tr>
</table><small><b>Table:</b> Execution Time of lwdaq_rag Operations for 1536-Dimensional Vectors.</small></center>

<p>The "load" time is the total time taken to load the entire library with random integer-valued vectors generated in Tcl and passed into lwdaq_rag as strings. We choose 1536-dimensional vectors because this is the size of contemporary large language model (LLM) embedding vectors. Each vector takes 1536 integer locations in memory, each of which is 8 bytes on a 64-bit machine, so each embed is 12 KByte and a ten-thousand embed library will take up 123 MByte of RAM. Once loaded into memory, however, identifying relevant is fast compared to the several seconds it takes to obtain an answer from an LLM completion endpoint.</p>

}
function lwdaq_rag(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

const
	empty_name='EMPTY';
	
var
	option:string='';
	arg_index:integer;
	vp:pointer;	
	operation:string='';
	name:string=empty_name;
	vector:string='0';
	vec_len:integer=1536;
	lib_len:integer=10;
	retrieve_len:integer=10;
	scale,r:real;
	result:string='';
	i:integer=-1;
	j:integer=-1;
	limit:integer=1;
	vg:x_graph_type;
	s:string;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq_rag:=Tcl_Error;
	lib_len:=length(embed_library);
	vec_len:=length(embed_library[0].vector);

	if (argc<2) or odd(argc) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be "'
			+'lwdaq_rag operation ?option value?".');
		exit;
	end;

	arg_index:=2;
	while (arg_index<argc-1) do begin
		option:=Tcl_ObjString(argv[arg_index]);
		inc(arg_index);
		vp:=argv[arg_index];
		inc(arg_index);
		if (option='-lib_len') then lib_len:=Tcl_ObjInteger(vp)	
		else if (option='-retrieve_len') then retrieve_len:=Tcl_ObjInteger(vp)	
		else if (option='-vec_len') then vec_len:=Tcl_ObjInteger(vp)
		else if (option='-name') then name:=Tcl_ObjString(vp)	
		else if (option='-vector') then vector:=Tcl_ObjString(vp)
		else begin
			Tcl_SetReturnString(interp,error_prefix
				+'Bad option "'+option+'", must be one of '
				+'"-lib_len -retrieve_len -vec_len -name -vector" in '
				+'lwdaq_rag.');
			exit;
		end;
	end;

	operation:=Tcl_ObjString(argv[1]);
	if (operation='create') then begin
		setlength(embed_library,lib_len);
		for i:=0 to lib_len-1 do 
			with embed_library[i] do begin
				name:=empty_name;
				relevance:=0;
				setlength(embed_library[i].vector,vec_len);
			end;
	end else if (operation='add') then begin
		vg:=read_x_graph(vector);
		if length(vg)<>vec_len then begin
			writestr(result,'Mismatched vector length, expected ',vec_len:1,
				' received ',length(vg));
			Tcl_SetReturnString(interp,error_prefix+result+' in lwdaq_rag add.');
			exit;
		end;
		j:=0;
		while (j<length(embed_library)) and (embed_library[j].name<>empty_name) do 
			inc(j);
		if j>=length(embed_library) then begin
			writestr(result,'Embed library full with ',length(embed_library):1,' embeds');
			Tcl_SetReturnString(interp,error_prefix+result+' in lwdaq_rag add.');
			exit;
		end;
		scale:=0;
		for i:=0 to vec_len-1 do scale:=scale+sqr(vg[i]);
		scale:=sqrt(scale);
		for i:=0 to vec_len-1 do embed_library[j].vector[i]:=vg[i]/scale;
		embed_library[j].name:=name;
	end else if (operation='retrieve') then begin
		vg:=read_x_graph(vector);
		if length(vg)<>vec_len then begin
			writestr(result,'Mismatched vector length, expected ',
				vec_len:1,' received ',length(vg));
			Tcl_SetReturnString(interp,error_prefix+result+' in lwdaq_rag retrieve.');
			exit;
		end;
		scale:=0;
		for i:=0 to vec_len-1 do scale:=scale+sqr(vg[i]);
		scale:=sqrt(scale);
		for i:=0 to vec_len-1 do vg[i]:=vg[i]/scale;
		for j:=0 to lib_len-1 do 
			with embed_library[j] do begin 
				r:=0;
				for i:=0 to vec_len-1 do r:=r+vector[i]*vg[i];
				relevance:=r;
			end;
		quick_sort(0,lib_len-1,embed_swap,embed_lt,@embed_library);
		result:='';
		if retrieve_len>lib_len then limit:=lib_len else limit:=retrieve_len;
		for j:=0 to limit-1 do
			with embed_library[j] do begin
				writestr(s,name,' ',relevance:1:4,' ');
				insert(s,result,length(result)+1);
				if length(result)>long_string_length then begin
					report_error(
						'length(result)>long_string_length in lwdaq_rag retrieve');
					exit;
				end;
			end;
	end else if (operation='config') then begin
		writestr(result,'-lib_len ',lib_len:1,'-vec_len ',vec_len:1);
	end else if (operation='dump') then begin
		result:='';
		for j:=0 to length(embed_library)-1 do 
			with embed_library[j] do begin
				s:=name+' ';
				for i:=0 to length(vector)-1 do
					writestr(s,s,vector[i]:1:6,' ');
				if j<length(embed_library)-1 then s:=s+eol;
				insert(s,result,length(result)+1);
			end;
	end else begin
		Tcl_SetReturnString(interp,error_prefix
			+'Bad operation "'+operation+'", must be one of '
			+'"create add retrieve config dump" in lwdaq_rag.');
		exit;
	end;


	Tcl_SetReturnString(interp,result);
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq_rag:=Tcl_OK;
end;

{
<p>The <i>lwdaq</i> command acts as an entry point into our analysis libraries, making various math functions available at the TCL command line. You specify the routine we wish to call, and pass arguments to the routine in strings or byte arrays or both. Most routines return results as text strings in which real numbers are encoded in characters with a fixed number of decimal places, as defined by the global constants <i>fsr</i> and <i>fsd</i>. You can set both of these with <i>lwdaq_config</i>. Beware that these routines can round small values to zero.</p>
}
function lwdaq(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;

var
	option:string='';
	result:string='';
	data_string:string='';
	s:string='';
	slope,intercept,rms_residual,position,interpolation:real;
	threshold:real;
	amplitude,offset,average:real;
	a,b:sinusoid_type;
	gp,gp2:xy_graph_type;
	gpx,frequencies,signal,gpx2:x_graph_type;
	M,N:matrix_type;
	num_rows,num_elements,num_columns:integer;
	num_glitches:integer=0;
	i,extent,color,red,blue,green:integer;
	x_axis,y_axis,z_axis:xyz_point_type;
	
begin
	error_string:='';
	gui_interp_ptr:=interp;
	lwdaq:=Tcl_Error;
		
	if (argc<2) then begin
		Tcl_SetReturnString(interp,error_prefix
			+'Wrong number of arguments, must be: "lwdaq option ?args?".');
		exit;
	end;

	option:=Tcl_ObjString(argv[1]);
	if option='bcam_from_global_point' then begin
{
<p><b>Obsolete Routine</b> Transforms a point in global coordinates to a point in bcam coordinates. The bcam coordinates are those defined by a kinematic mount holding a bcam. The routine takes as input a <i>point</i> string containing the global xyz-position of point and a <i>mount</i> string containing the global xyz-positions of the centers of the cone, slot, and flat balls of the mount. Note that the routine does not accept the pose of the mount coordinate system, but instead the positions of the kinematic mounting balls.</p>

<p>This routine deduces the pose of the mount coordinate system itself, which is computationally intensive and unecessary. Instead of deducing the mount coordinate pose every time we transform between global and mount coordinates, call <a href="#bcam_coord_from_mount">bcam_coord_from_mount</a> once to obtain the pose of the mount coordinates, and then pass this pose into <a href="#xyz_local_from_global_point">xyz_local_from_global_point</a>.</p>

<p>In the following example, we transform the global point (0,1,0) into BCAM coordinates when our cone, slot and flat balls have coordinates (0,1,0), (-1,1,-1), and (1,1,-1).</p>

<pre>lwdaq bcam_from_global_point "0 1 0" "0 1 0 -1 1 -1 1 1 -1"
0.000000 0.000000 0.000000</pre>

<p>For a description of the BCAM coordinate system, and how it is defined with respect to a BCAM's kinematic mounting balls, consult the BCAM <a href="https://www.bndhep.net/Devices/BCAM/User_Manual.html">User Manual</a>. We usually use millimeters to specify coordinates, because we use millimeters in our BCAM camera and source calibration constants. But the routine will work with any units of length, so long as we use the same units for both the point and the mount strings.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' point mount".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_local_from_global_point(
					xyz_from_string(Tcl_ObjString(argv[2])),
					bcam_coord_from_mount(
						kinematic_mount_from_string(Tcl_ObjString(argv[3]))))));
	end 
	else if option='global_from_bcam_point' then begin
{
<p><b>Obsolete Routine</b> Transforms a point in bcam coordinates to a point in global coordinates. The bcam coordinates are those defined by a kinematic mount holding a bcam. The routine takes as input a <i>point</i> string containing the bcam xyz-position of point and a <i>mount</i> string containing the global xyz-positions of the centers of the cone, slot, and flat balls of the mount. Note that the routine does not accept the pose of the mount coordinate system, but instead the positions of the kinematic mounting balls.</p>

<pre>lwdaq global_from_bcam_point "0 1 0" "0 1 0 -1 1 -1 1 1 -1"
0.000000 2.000000 0.000000</pre>

<p>This routine deduces the pose of the mount coordinate system itself, which is
computationally intensive and unecessary. Instead of deducing the mount
coordinate pose every time we transform between global and mount coordinates,
call <a href="#bcam_coord_from_mount">bcam_coord_from_mount</a> once to obtain
the pose of the mount coordinates, and then pass this pose into <a
href=#xyz_global_from_local_point">xyz_global_from_local_point</a>.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' point mount".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_global_from_local_point(
					xyz_from_string(Tcl_ObjString(argv[2])),
					bcam_coord_from_mount(
						kinematic_mount_from_string(Tcl_ObjString(argv[3]))))));
	end 
	else if option='bcam_from_global_vector' then begin
{
<p><b>Obsolete Routine</b> Transforms a vector in global coordinates to a vector
in bcam coordinates. The bcam coordinates are those defined by a kinematic mount
holding a bcam. The routine takes as input a <i>vector</i> string containing the
bcam xyz-components of vector and a <i>mount</i> string containing the global
xyz-positions of the centers of the cone, slot, and flat balls of the mount. Note
that the routine does not accept the pose of the mount coordinate system, but
instead the positions of the kinematic mounting balls.</p>

<pre>lwdaq bcam_from_global_vector "0 1 0" "0 1 0 -1 1 -1 1 1 -1"
0.000000 1.000000 0.000000</pre>

<p>This routine deduces the pose of the mount coordinate system itself, which is
computationally intensive and unecessary. Instead of deducing the mount
coordinate pose every time we transform between global and mount coordinates,
call <a href="#bcam_coord_from_mount">bcam_coord_from_mount</a> once to obtain
the pose of the mount coordinates, and then pass this pose into <a
href=#xyz_local_from_global_vector">xyz_local_from_global_vector</a>.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector mount".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_local_from_global_vector(
					xyz_from_string(Tcl_ObjString(argv[2])),
					bcam_coord_from_mount(
						kinematic_mount_from_string(Tcl_ObjString(argv[3]))))));
	end 
	else if option='global_from_bcam_vector' then begin
{
<p><b>Obsolete Routine</b> Transforms a vector in bcam coordinates to a vector
in global coordinates. The bcam coordinates are those defined by a kinematic mount
holding a bcam. The routine takes as input a <i>vector</i> string containing the
global xyz-components of vector and a <i>mount</i> string containing the global
xyz-positions of the centers of the cone, slot, and flat balls of the mount. Note
that the routine does not accept the pose of the mount coordinate system, but
instead the positions of the kinematic mounting balls.</p>

<pre>lwdaq global_from_bcam_vector "0 1 0" "0 1 0 -1 1 -1 1 1 -1"
0.000000 1.000000 0.000000</pre>

<p>This routine deduces the pose of the mount coordinate system itself, which is
computationally intensive and unecessary. Instead of deducing the mount
coordinate pose every time we transform between global and mount coordinates,
call <a href="#bcam_coord_from_mount">bcam_coord_from_mount</a> once to obtain
the pose of the mount coordinates, and then pass this pose into <a
href=#xyz_global_from_local_vector">xyz_global_from_local_vector</a>.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector mount".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_global_from_local_vector(
					xyz_from_string(Tcl_ObjString(argv[2])),
					bcam_coord_from_mount(
						kinematic_mount_from_string(Tcl_ObjString(argv[3]))))));
	end 
	else if option='bcam_source_bearing' then begin
{
<p>Calculates the line in BCAM coordinates upon which a light source must lie
for its image to be centered at <i>spot_center</i>. The line is returned as a
string containing six numbers. The first three numbers are the coordinates of
the BCAM pivot point in BCAM coordinates in millimeters. The last three numbers
are a unit vector in the direction of the line. The BCAM itself we describe with
its calibration constants in the <i>camera</i> string. The <i>camera</i> string
contains nine elements. The first is the name of the camera, which might be its
serial number. The following eight are the camera calibration constants, as
described in the <a
href="https://www.bndhep.net/Devices/BCAM/User_Manual.html">BCAM User
Manual</a>.</p>

<pre>lwdaq bcam_source_bearing "1.72 1.22" "P0001 1 0 0 0 0 1 75 0"
1.000000 0.000000 0.000000 0.000000 0.000000 1.000000</pre>

<p>The first element in the <i>camera</i> string is the name of the camera, even
though this calculation does not use the camera name. In the example above,
P0001 is the camera name, the pivot point is at (1,0,0) in BCAM coordinates, the
camera axis is parallel to the BCAM <i>z</i>-axis,  the pivot point is 75 mm
from the lens, and the CCD rotation is zero. We transform point (1.72, 1.22)  on
the CCD (dimensions are millimeters) into a bearing that passes through the
pivot point (1,0,0) in the direction (0,0,1). The point (1.72,1.22) is our
aribitrarily-chosen center of the CCD in all currently-available BCAMs (it is
close to the center of the TC255P image sensor, but not exactly at the center).
The BCAM camera axis is the line passing through the CCD center and the pivot
point.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' spot_center camera".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz_line(
				bcam_source_bearing(
					xy_from_string(Tcl_ObjString(argv[2])),
					bcam_camera_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='bcam_source_position' then begin
{
<p>Calculates the BCAM coordinates of a light source whose image is centered at
<i>spot_center</i>, and which itself lies in the plane <i>z</i> = <i>bcam_z</i>
in BCAM coordinates. The routine is similar to <a
href="#bcam_source_bearing">bcam_source_bearing</a>, but we specify the BCAM
<i>z</i>-coordinate of the source as well, in millimeters. The routine
determines the position of the source by calling <a
href="#bcam_source_breagin">bcam_source_bearing</a> and intersecting the source
bearing with the <i>z</i>=<i>range</i> plane. The <i>camera</i> string contains
the camera calibration constants, just as for <a
href="#bcam_source_bearing">bcam_source_bearing</a>.</p>

<pre>lwdaq bcam_source_position "1.72 1.22" 1000 "P0001 1 0 0 0 0 1 75 0"
1.000000 0.000000 1000.000000</pre>

<p>Here we see the source is at (1, 0, 1000) in BCAM coordinates, where all
three coordinates are in millimeters. You specify the BCAM itself with its
calibration constants using the <i>camera</i> string, just as for <a
href="#bcam_source_bearing">bcam_source_bearing</a>.</p>
}
		if (argc<>5) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' spot_center bcam_z camera".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				bcam_source_position(
					xy_from_string(Tcl_ObjString(argv[2])),
					Tcl_ObjReal(argv[3]),
					bcam_camera_from_string(Tcl_ObjString(argv[4])))));
	end 
	else if option='bcam_image_position' then begin
{
<p>Calculates the image coordinates of the image generated by a light source at
location <i>source_position</i> in BCAM coordinates. We specify the BCAM itself
with the <i>camera</i> string. The routine determines the image position by
drawing a line from the source through the pivot point and instersecting this
line with the plane of the image sensor. The orientation and location of the
image sensor is given by the camera calibration constants. The image coordinate
origin is the top-left corner of the image sensor as seen on the screen. The
units of image coordinates are microns, with x going left-right and y going
top-bottom.</p>

<pre>lwdaq bcam_image_position "0 0 750" "P0001 0 0 0 0 0 1 75 0"
1.720 1.220</pre>

<p>Here we see the image is at (1.72,1.22) in image coordinates, which is the
center of a TC255P image sensor. You specify the BCAM itself with its
calibration constants using the <i>camera</i> string, just as for <a
href="#bcam_source_bearing">bcam_source_bearing</a>.</p>

<pre>lwdaq bcam_image_position "1 0 750" "P0001 0 0 0 0 0 1 75 0"
1.620 1.220</pre>

<p>Here we see movement of 1 mm at a range ten times the pivot-ccd distance causing a 100-um move on the image.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' source_position camera".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xy(
				bcam_image_position(
					xyz_from_string(Tcl_ObjString(argv[2])),
					bcam_camera_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='bcam_coord_from_mount' then begin	
{
<p>Convert the ball positions of a BCAM-style kinematic mount into the pose of
the mount's coordinate system. These three balls mate with a cone, slot, and
flat depression under a metrology device such as a Boston CCD Angle Monitor
(BCAM), Silhouette Camera (SCAM), Wire Position Sensor (WPS), or Fiber View
Camera (FVC). We pass the routine the global xyz-position of the three balls in
the order cone, slot, flat. The routine returns the location and orientation of
the mount coordinate system. We describe how the three balls define the mount
coordinate system in the <a
href="https://www.bndhep.net/Devices/BCAM/User_Manual.html">BCAM User Manual</a>.
See <i>bcam_coordinates_from_mount</i> in <a
href="https://www.bndhep.net/Software/Sources/bcam.pas">bcam.pas</a> for the
exact calculation. The mount coordinate system is defined in such a way that it
is always in the same location and orientation with respect to the sensor
chassis, regardless of small variations in the ball arrangements between one
kinematic mount and the next.</p>

<pre>lwdaq bcam_coord_from_mount "0 1 0 -21 1 -72 21 1 -72"
0.000 1.000 0.000 -0.000 0.004 0.000</pre>

<p>The "pose" of the mount coordinate system consists of its location and
orientation. The location is the xyz-position of the mount coordinate origin in
global coordinates. The rotation is three angles by which we rotate a global
vector about the global x, y, and then z axis to obtain the components of the
vector in mount coordinates. If we apply this rotation to the global coordinate
axes, we obtain the axes of the mount coordinate system. The units of angle are
radians.</p>

<p>Note that our <i>bcam_from_global</i> and <i>global_from_bcam</i> routines
perform this conversion from ball positions to mount coordinate system
themselves. We pass these routine the ball positions, not the pose of the mount
coordinate system. The more generic <i>xyz_local_from_global</i> and
<i>xyz_local_from_global</i> routines do, however, expect the pose of the local
coordinate system. We may use these generic routines for any style of kinematic
mount or body positioning, provided that we know the pose of the local
coordinate system in the global coordinate system.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' mount".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz_pose(
				bcam_coord_from_mount(
					kinematic_mount_from_string(Tcl_ObjString(argv[2])))));
	end
	else if option='xyz_local_from_global_vector' then begin
{
<p>Transforms a vector in global coordinates to a vector in local coordinates.
The routine takes two strings as parameters. The first is the xyz components of
the vector in global coordinates. The second is the pose of the local coordinate
system in the global coordinate system. By "pose" we mean the location and
orientation of the local coordinates, where the locaion is the xyz-position of
its origin in global coordinates and the orientation is the xyz-rotation we
apply to the global coordinate axes to obtain the local coordinate axes. An
"xyz-rotation" consists of three rotations by three angles about the x, y, and z
axes in that order. The units of angle are radians. In the example below, the
local coordinate system is at (10,0,0) and we obtain its axes by rotating the
global axes by 90&deg; about the x-axis.</p>

<pre>lwdaq xyz_local_from_global_vector "0 0 1" "10 0 0 1.570796327 0 0"
0.000000 1.000000 -0.000000</pre>

<p>When working with devices that sit on a BCAM-style kinematic mount, we obtain
the pose of the sensor's mount coordinate system by passing the global
coordinates of their three mounting balls to <a
href="#bcam_coord_from_mount">bcam_coord_from_mount</a>.</p>

<pre>lwdaq xyz_local_from_global_vector "5 0 0" "10 0 0 0 0.1 0"
4.975021 0.000000 0.499167</pre>

<p>In the example above, we have the local origin at x=10 in global coordinates,
but this has no effect upon the resulting vector. The local axes are rotated by
100 mrad about the global y-axis. Our vector is distance 5 in the global
x-direction.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector local".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_local_from_global_vector(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_pose_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_global_from_local_vector' then begin
{
<p>Transforms a vector in local coordinates to a vector in global coordinates.
It is the inverse of <a
href="#xyz_local_from_global_vector">xyz_local_from_global_vector</a>. We pass
the local coordinates of a point in the <i>point</i> string. In the <i>local</i>
string we pass the pose the local coordinate system as seen in the global
coordinate system.</p>

<pre>lwdaq xyz_global_from_local_vector "0 -1 0" "10 0 0 1.570796327 0 0"
0.000000 0.000000 1.000000</pre>

<p>The "pose" consists of the xyz-position and xyz-rotation of the local
coordinates in global coordinates. The units of angle are radians. The routine
returns the local components of the vector.</p>

<pre>lwdaq xyz_global_from_local_vector "4.975021 0.000000 0.499167" "10 0 0 0 0.1 0"
5.000000 0.000000 -0.000000</pre>

<p>In the example above, we have the local origin at x=10 in global coordinates,
but this has no effect upon the resulting vector. The local axes are rotated by
100 mrad about the global y-axis. Our vector is distance 5 in the global
x-direction.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector local".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_global_from_local_vector(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_pose_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_local_from_global_point' then begin
{
<p>Transforms a point in global coordinates to a point in local coordinates. It
is the inverse of <a href="#xyz_global_from_local_point">xyz_global_from_local_point</a>.
We pass the local coordinates of a point in the <i>point</i> string. We pass a
description of the local coordinate system in the <i>local</i> string. The
coordinate description consists of six numbers. The first three are the location
in global coordinates of the local origin. The next three are the rotations about
the global x, y, and z axes that transform the global axis unit vectors into the
local axis unit vectors. The units of angle are radians. The routine returns the
local coordinates of the point.</p>

<pre>lwdaq xyz_local_from_global_point "0 1 0" "10 0 0 1.570796327 0 0"
-10.000000 -0.000000 -1.000000</pre>

<p>We use <a href="#bcam_coord_from_mount">bcam_coord_from_mount</a> to obtain the pose of the mount coordinate systems of BCAM-style kinematic mounts.</p>

<pre>lwdaq xyz_local_from_global_point "0 0 0" "10 0 0 0 0.1 0"
-9.950042 0.000000 -0.998334</pre>

<p>In the example above, we have the local origin at x=10 in global coordinates. The local axes are rotated by 100 mrad about the global y-axis.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' point local".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_local_from_global_point(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_pose_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_global_from_local_point' then begin
{
<p>Transforms a point in global coordinates to a point in local coordinates. It
is the inverse of <a href="#xyz_local_from_global_point">xyz_local_from_global_point</a>.
We pass it the local coordinates of a point in the <i>point</i> string. We pass
it the pose of the local coordinate system in the <i>local</i> string. The
routine returns the global coordinates of the point.</p>

<pre>lwdaq xyz_global_from_local_point "-10 0 1" "10 0 0 1.570796327 0 0"
0.000000 1.000000 -0.000000</pre>

<p>We use <a href="#bcam_coord_from_mount">bcam_coord_from_mount</a> to obtain the pose of the mount coordinate systems for BCAM-style kinematic mounts.</p>

<pre>lwdaq xyz_global_from_local_point "-9.950042 0.000000 -0.998334" "10 0 0 0 0.1 0"
-0.000000 0.000000 0.000000</pre>

<p>In the example above, we have the local origin at x=10 in global coordinates. The
local axes are rotated by 100 mrad about the global y-axis. Our local point is the one
that corresponds to the origin of global coordinates.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' point local".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_global_from_local_point(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_pose_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='wps_wire_plane' then begin
{
<p>Calculates the plane that must contain the center-line of a wire given the position and rotation of a wire image in a WPS camera. The units for wire position are millimeters, and for rotation are milliradians. We use the camera's calibration constants to determine the plane. We specify the plane in WPS coordinates, which are defined in the same way as BCAM coordinates, using the positions of the WPS (or BCAM) mounting balls. For a description of the BCAM coordinate system, consult the BCAM <a href="https://www.bndhep.net/Devices/BCAM/User_Manual.html">User Manual</a>.</p>

<pre>lwdaq wps_wire_plane "1.720 1.220" "0.000" "Q0131_1 0 0 0 -10 0 0 0 0 0"
0.000000 0.000000 0.000000 0.000000 0.000000 1.000000</pre>

<p>The image position in our example is 1.720 mm from the right and 1.220 mm from the top. This is at the nominal center point of a TC255 image sensor. The wire is rotated by 0 mrad anti-clockwise in the image. The first element in the <i>camera</i> string is the name of the camera, even though this calculation does not use the camera name. In the example above, Q0131_1 is the camera name. It is camera number one on the WPS with serial number Q0131. In this example, the camera pivot point is at (0,0,0) in WPS coordinates, which puts it at the center of the cone ball supporting the WPS. That's clearly impossible, but we're just using simple numbers to illustrate the routine. The center of the image sensor (the CCD) is at (-10,0,0). The x-axis runs directly through the pivot point and the center of the sensor. The rotation of the sensor is (0,0,0), which means the x-axis is perpendicular to the sensor surface. Here is another example.</p>

<pre>lwdaq wps_wire_plane "1 1.220" "10.000" "Q0131_1 0 0 0 -10 0 0 0 0 0"
0.000000 0.000000 0.000000 0.071811 0.009974 0.997368</pre>

<p>The routine calculates the plane that contains the center of the image and the pivot point. It specifies the plane as the pivot point, which is a point in the plane, and a normal to the plane. The first three numbers in the result are the coordinates of the pivot point. The last three numbers are the normal to the plane. The normal is a unit vector.</p>
}
		if (argc<>5) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' wire_center wire_rotation camera".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz_plane(
				wps_wire_plane(
					xy_from_string(Tcl_ObjString(argv[2])),
					Tcl_ObjReal(argv[3])/mrad_per_rad,
					wps_camera_from_string(Tcl_ObjString(argv[4])))));
	end 
	else if option='wps_calibrate' then begin
{
<p>Calculates calibration constants for a single WPS camera using a data file that contains simultaneous CMM and WPS measurements. We pass the routine a device name and a camera number, followed by a calibration data string containing simultaneous WPS and CMM wire position measurements, and produces as output the WPS calibration constants that minimize the error between the WPS measurement and the CMM measured wire positions. In addition to the data string, we specify a camera number, for there are two cameras that we calibrate separately from the same data file. The input data string has the following format. We begin with the number of wire positions. The next three lines contain the global coordinates of the cone, slot, and flat ball beneath the WPS respectively, in millimeters. Then we have a line for each wire position containing a point on the wire center in millimeters and the direction of center-line as direction cosines, measured by the CMM in global coordinates. Then we have one line for each wire position, each line containing the left and right edge positions and orientations from cameras one and two. Edge positions are the intersection of the edge line with the top of the image sensor, measured in microns from the left edge of the leftmost column of pixels. Rotation is anti-clockwise positive in milliradians. Here is an example string we might pass for the third parameter <i>data</i>.</p>

<pre>20
117.6545 83.1886 -17.2954 
44.6755 62.1783 -17.4321 
44.5830 104.1654 -17.2884 
103.9113 129.7997 50.2922 0.99991478 0.00889102 -0.00955959 
103.9431 125.7984 50.2779 0.99991503 0.00886584 -0.00955667 
103.9752 121.8009 50.2638 0.99991493 0.00887295 -0.00956066 
104.0085 117.7957 50.2509 0.99991502 0.00885647 -0.00956690 
104.7553 129.7766 46.4177 0.99991712 0.00873105 -0.00946149 
104.7877 125.7764 46.4037 0.99991722 0.00872038 -0.00946123 
104.8208 121.7746 46.3903 0.99991710 0.00872645 -0.00946834 
104.8535 117.7685 46.3761 0.99991723 0.00870522 -0.00947372 
104.9001 129.7467 42.5693 0.99991896 0.00852873 -0.00945121 
104.9325 125.7481 42.5566 0.99991897 0.00852404 -0.00945529 
104.9657 121.7474 42.5418 0.99991892 0.00851060 -0.00947188 
104.9986 117.7459 42.5285 0.99991894 0.00851125 -0.00946948 
105.7449 129.7706 48.6070 0.99870582 0.00888704 -0.05007694 
105.7773 125.7704 48.5933 0.99870603 0.00887005 -0.05007573 
105.8100 121.7669 48.5790 0.99870583 0.00886387 -0.05008098 
105.8418 117.7689 48.5677 0.99870663 0.00885177 -0.05006708 
104.3525 129.7877 46.2170 0.99785907 0.00839544 0.06485984 
104.3849 125.7855 46.2029 0.99785944 0.00838955 0.06485491 
104.4176 121.7886 46.1882 0.99786037 0.00837783 0.06484209 
104.4507 117.7856 46.1745 0.99786075 0.00837207 0.06483697 
2951.52 2.30 3251.61 1.53 1574.33 -10.06 1855.93 -10.40
2628.52 3.65 2949.11 0.89 1195.81 -9.60 1496.22 -10.05
2259.27 4.29 2602.12 2.89 764.15 -9.43 1086.72 -10.03	
1830.11 3.92 2198.96 3.48 266.00 -9.19 615.70 -9.85
2296.90 3.37 2585.66 3.13 2190.13 -10.10 2481.64 -10.44 
1942.95 3.48 2250.45 3.64 1839.57 -9.90 2150.22 -10.36
1537.64 5.25 1866.49 3.57 1438.10 -9.97 1771.13 -10.24
1069.53 6.08 1425.03 3.66 973.45 -9.54 1333.81 -9.85 
1686.43 4.49 1965.47 4.01 2845.86 -10.59 3150.64 -10.98 
1304.51 5.03 1602.68 3.99 2527.69 -10.61 2851.96 -10.86
868.45 6.43 1188.72 6.00 2162.36 -10.17 2509.00 -10.78
365.94 6.63 713.81 6.46 1736.76 -9.78 2111.33 -10.76
2613.07 -34.08 2907.86 -35.47 1884.75 -46.13 2171.53 -46.92
2274.25 -32.98 2587.70 -34.36 1519.15 -45.14 1824.90 -46.34
1885.62 -31.31 2221.24 -32.91 1100.95 -44.02 1429.15 -45.15
1436.90 -29.43 1798.94 -31.25 618.94 -43.16 974.19 -44.11
2366.01 69.79 2656.40 70.19 2107.85 56.37 2398.42 57.31
2014.31 69.13 2323.28 69.76 1754.36 55.21 2064.15 56.05
1612.63 68.59 1943.68 69.14 1350.65 54.26 1682.41 54.84
1147.92 68.08 1505.81 68.70 883.10 52.90 1242.29 53.82</pre>

<p>The output takes the form of a single line of values, which we present here below headings that give the meaning of the values.</p>
	
<pre>------------------------------------------------------------------------------------------------
				pivot (mm)              sensor (mm)            rot (mrad)          pivot-  error
Camera     x      y        z       x      y        z         x        y       z    ccd (mm) (um)
------------------------------------------------------------------------------------------------
C0562_1 -3.5814 88.8400 -4.9796 -12.6389 94.3849 -4.9598 -1558.772  -0.344 -566.827 10.620  1.6</pre>
	
<p>The routine uses the simplex fitting algorithm to minimize the camera calibration error, and while doing so, it writes its intermediate values, and a set of final errors for the pin positions, to the current target of gui_writeln.</p>
}
		if (argc<>5) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' device_name camera_num data".');
			exit;
		end;
		data_string:=Tcl_ObjString(argv[4]);
		Tcl_SetReturnString(interp,
			wps_calibrate(
				Tcl_ObjString(argv[2]),
				Tcl_ObjInteger(argv[3]),
				data_string));
	end 
	else if option='xyz_length' then begin
{
<p>Return the length of an xyz vectors.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_real(
				xyz_length(
					xyz_from_string(Tcl_ObjString(argv[2]))),
				fsr,fsd));
	end 
	else if option='xyz_sum' then begin
{
<p>Add two xyz vectors together as in a + b.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector_a vector_b".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_sum(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_difference' then begin
{
<p>Subtract a second xyz vector from a first xyx vector, as in a - b.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector_a vector_b".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_difference(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_axis_rotate' then begin
{
<p>Rotate an xyz point about an axis line by an angle in radians.</p>
}
		if (argc<>5) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' point axis rotation".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_axis_rotate(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_line_from_string(Tcl_ObjString(argv[3])),
					Tcl_ObjReal(argv[4]))));
	end 
	else if option='xyz_rotate' then begin
{
<p>Rotate an xyz vector about the x, y, and z axes in that order by three angles rx, ry, and rz in radians.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector rotation".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_rotate(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_unrotate' then begin
{
<p>Rotate an xyz vector about the z, y, z axes in that order by three angles rz, ry, and rx in radians. We specify the angles with three values in the order rx, ry, and rz, opposite to the order in which the angles will be applied to their respective axes, hence the name "unrotate".</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector_a vector_b".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_unrotate(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_rotation_from_axes' then begin
{
<p>Search for a compound, three-dimensional rotation that produces the specified orthogonal, right-handed coordinate system vectors from the existing x, y, and z unit vectors. The rotation takes the form of three angles by which we rotate about x, y, and z. We pass the routine three vectors parallel to the new coordinate system. The routine returns the three rotations.</p>
}
		if (argc<>5) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' x_axis y_axis z_axis".');
			exit;
		end;
		x_axis:=xyz_from_string(Tcl_ObjString(argv[2]));
		y_axis:=xyz_from_string(Tcl_ObjString(argv[3]));
		z_axis:=xyz_from_string(Tcl_ObjString(argv[4]));	
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_rotation_from_matrix(
					xyz_matrix_from_points(x_axis,y_axis,z_axis))));
	end 
	else if option='xyz_dot_product' then begin
{
<p>The dot product of a first xyz vector with a second xyz vector, as in a.b.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector_a vector_b".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_real(
				xyz_dot_product(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_from_string(Tcl_ObjString(argv[3]))),
				fsr,fsd));
	end 
	else if option='xyz_unit_vector' then begin
{
<p>Take a vector and divide it by its length to obtain a unit vector.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_unit_vector(
					xyz_from_string(Tcl_ObjString(argv[2])))));
	end 
	else if option='xyz_cross_product' then begin
{
<p>The cross product of a first xyz vector with a second xyz vector, as in a X b.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' vector_a vector_b".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_cross_product(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_plane_plane_intersection' then begin
{
<p>Determines the line along which two planes intersect. We specify each plane with a point in the plane and a normal to the plane, making six numbers for each plane.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' plane_1 plane_2".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz_line(
				xyz_plane_plane_intersection(
					xyz_plane_from_string(Tcl_ObjString(argv[2])),
					xyz_plane_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_line_plane_intersection' then begin
{
<p>Determines the point at which a line and a plane intersect. We specify the line with a point and a direction. We specify the plane with a point and a normal vector.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' line plane".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_line_plane_intersection(
					xyz_line_from_string(Tcl_ObjString(argv[2])),
					xyz_plane_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_point_line_vector' then begin
{
<p>Determines the shortest vector from a point to a line. We specify the point with three coordinates. We specify the line with a point and a direction vector. The direction vector does not have to be a unit vector. The routine returns the three components of the shortest vector.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' point line".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz(
				xyz_point_line_vector(
					xyz_from_string(Tcl_ObjString(argv[2])),
					xyz_line_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='xyz_line_line_bridge' then begin
{
<p>Determines the shortest vector from a one line to another. We specify each line with a point and a direction vector. The direction vector does not have to be a unit vector. We express the link as a point and a vector. We give the point in the first line that is closest to the second, and the vector that connects this point to the point in the second line that is closest to the first. The original two lines must be skewed. Parallel lines will return the origin for a point, and a zero vector.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' line line".');
			exit;
		end;
		Tcl_SetReturnString(interp,
			string_from_xyz_line(
				xyz_line_line_bridge(
					xyz_line_from_string(Tcl_ObjString(argv[2])),
					xyz_line_from_string(Tcl_ObjString(argv[3])))));
	end 
	else if option='straight_line_fit' then begin
{
<p>Fits a straight line to <i>data</i>, where <i>data</i> contains a string of numbers, alternating between <i>x</i> and <i>y</i> coordinates. The routine returns a string of three numbers: slope, intercept, and rms residual. The rms residual is the standard deviation of the difference between the straight line and the data, in the <i>y</i>-direction. The data "0 3 1 5 2 7 5 13" would represent a straight line with slope 2, intercept 3, and rms residual 0. The result would be "2.000000 3.000000 0.000000".</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' data".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		gp:=read_xy_graph(result);
		straight_line_fit(gp,slope ,intercept,rms_residual);
		writestr(result,slope:fsr:fsd,' ',intercept:fsr:fsd,' ',rms_residual:fsr:fsd);
		Tcl_SetReturnString(interp,result);
	end 
	else if option='ave_stdev' then begin
{
<p>Calculates the average, standard deviation, maximum, minimum, and mean absolute deviation of of <i>data</i>, where <i>data</i> contains a string of numbers. The routine returns values separated by spaces, and formatted to <a href="#lwdaq_config">fsd</a> decimal places.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' data".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		gpx:=read_x_graph(result);
		writestr(result,average_x_graph(gpx):fsr:fsd,' ',
			stdev_x_graph(gpx):fsr:fsd,' ',
			max_x_graph(gpx):fsr:fsd,' ',
			min_x_graph(gpx):fsr:fsd,' ',
			mad_x_graph(gpx):fsr:fsd);
		Tcl_SetReturnString(interp,result);
	end 
	else if option='linear_interpolate' then begin
{
<p>Interpolates between the two-dimensional points of <i>x_y_data</i> to obtain an estimate of <i>y</i> at <i>x</i>=<i>x_position</i>. If we pass "2.5" for the x position, and "0 0 10 10" for the x-y data, the routine will return "2.500000".</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' x_position x_y_data".');
			exit;
		end;
		position:=Tcl_ObjReal(argv[2]);
		result:=Tcl_ObjString(argv[3]);
		gp:=read_xy_graph(result);
		linear_interpolate(gp,position,interpolation);
		writestr(result,interpolation:fsr:fsd);
		Tcl_SetReturnString(interp,result);
	end 
	else if option='nearest_neighbor' then begin
{
<p>Finds the closest point to <i>p</i> in a library of points. The point and the members of the library are all points in an <i>n</i>-dimensional space. When we call this routine, we can specify the library with the after the point by passing another string containing the library of <i>m</i> points. If we don't pass the library, the routine uses the library most recently passed. The routine stores the library in a global array so that it can use it again. We pass the point <i>p</i> as a string of <i>n</i> real numbers. The library we pass as a string of <i>m</i>&times;<i>n</i> real numbers separated by spaces. The value returned by the routine is an integer that specifies the library point that is closest to the <i>p</i>. The first library point we specify with integer 1 (one) and the last with integer <i>m</i>.</p>
}
		if (argc<>3) and (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' point ?library?".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		num_columns:=word_count(result);
		M:=new_matrix(1,num_columns);
		read_matrix(result,M);
		if argc=4 then begin
			result:=Tcl_ObjString(argv[3]);
			num_elements:=word_count(result);
			if (num_elements mod num_columns) <> 0 then begin
				Tcl_SetReturnString(interp,error_prefix
					+'Library mismatch, num_elements mod num_columns <> 0.');
				exit;
			end;
			if (num_elements = 0) then begin
				Tcl_SetReturnString(interp,error_prefix
					+'Library error, num_elements = 0.');
				exit;
			end;
			nearest_neighbor_library:=new_matrix(num_elements div num_columns,num_columns);
			read_matrix(result,nearest_neighbor_library);
		end;
		if length(nearest_neighbor_library)=0 then begin
			Tcl_SetReturnString(interp,error_prefix
				+'No library defined.');
			exit;
		end;
		writestr(result,nearest_neighbor(M,nearest_neighbor_library):1);
		Tcl_SetReturnString(interp,result);
	end 
	else if option='sum_sinusoids' then begin
{
<p>Adds two sinusoidal waves of the same frequency together. You specify the two waves with their amplitude and phase. The phase must be in radians. The amplitude is dimensionless. The result contains the amplitude and phase of the sum of the two waves. If we pass the numbers "1 0 1 0.1" to the routine, it will return "1.997500 0.050000".</p>
}
		if (argc<>6) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' a.amplitude a.phase b.amplitude b.phase".');
			exit;
		end;
		a.amplitude:=Tcl_ObjReal(argv[2]);
		a.phase:=Tcl_ObjReal(argv[3]);
		b.amplitude:=Tcl_ObjReal(argv[4]);
		b.phase:=Tcl_ObjReal(argv[5]);
		a:=sum_sinusoids(a,b);
		writestr(result,a.amplitude:fsr:fsd,' ',a.phase:fsr:fsd,' ');
		Tcl_SetReturnString(interp,result);
	end 
	else if option='frequency_components' then begin
{
<p>Calculates components of the <a href="https://grokipedia.com/page/Discrete_Fourier_transform">discrete fourier transform</a> of a real-valued waveform by repeated calls to <i>frequency_component</i> in <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>. We specify the <i>M</i> components we want to calculate with a string of <i>M</i> frequencies, each of which is a multiple of the fundamental frequency of the waveform, 1/<i>NT</i>. The frequencies provided by a full discrete fourier transform of <i>N</i> real samples are <i>k</i>/<i>NT</i> for <i>k</i> such that 0&le;<i>k</i>&le;<i>N</i>&minus;1. If we want to obtain all <i>N</i>/2 components, we can use our <a href="#lwdaq_fft">lwdaq_fft</a> routine instead. The <i>frequency_components</i> routine is designed to provide a small number of components for real-valued input data.</p>

<pre>lwdaq_config -fsr 1 -fsd 2
lwdaq frequency_components "0 1 2 3 4 5" "0 0 0 0 1 1 1 1"
0.50 0.00 0.65 3.50 0.00 -1.91 0.27 0.83 0.00 0.00 0.27 0.30 </pre>

<p>Here we ask for components with frequencies "0 1 2 3 4 5" and we specify data "0 0 0 0 1 1 1 1". The routine returns a string containg the amplitude, <i>a</i>, and phase, &phi;, of each specified component, separated by spaces.</p>

<p>Because the <i>frequency_component</i> routine accepts only real-valued inputs, we are certain that component <i>k</i> for <i>K</i>&gt;0 will be the complex conjugate of component <i>N</i>&minus;<i>k</i>, which means the two components add together to form one component of double the magnitude but with the same phase as component <i>k</i>. Thus <i>frequency_component</i> doubles the magnitude of the <i>k</i>'th component for <i>k</i> equal to 1, 2,..<i>N</i>/2&minus;1 and leaves the phase unchanged.</p>

<p>The phase, &phi;, is in units of <i>T</i>, and refers to the phase of a sinusoid, so that the frequency component is</p>

<p><i>a</i>sin(2&pi;(<i>t</i>&minus;&phi;)<i>f</i>/<i>N</i>)</p>

<p>where <i>f</i> is the frequency we specified and <i>t</i> is the quantity that separates the samples. The quantity <i>t</i> might be time or distance.</p>

<p>The frequency need not be an integer, but if it is an integer, then this frequency will be one of those defined for the discrete fourier transform. There are times when choosing an exact frequency outside that finite set of periods is useful. For example, if we have 512 samples taken over 1 s, the discrete fourier transform contains components with frequencies 1 Hz, 2 Hz,.. 255 Hz. If we want to look for a signal at 33.3 Hz, we will find that the discrete fourier transform spreads 33.3 Hz into 33 Hz and 34 Hz, but neither component has the correct amplitude. By specifying a frequency of 33.3 Hz, we will obtain a more accurate estimate of a 33.3 Hz signal. Most of the time, however, the value of the transform outside the frequencies defined in the discrete transform is unreliable.</p>

<p>To improve its accuracy, the routine subtracts the average value of the waveform from each sample before it calculates the frequency components. To further improve the accuracy of the transform, we can apply a <a href="https://grokipedia.com/page/Window_function">window function</a> to <i>waveform</i> before it we call <i>frequency_component</i>. The window function smooths off the first and final few samples so that they converge upon the waveform's average value. We provide a linear window function with <a href="#window_function">window_function</a>.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' frequencies waveform".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		frequencies:=read_x_graph(result);
		result:=Tcl_ObjString(argv[3]);
		signal:=read_x_graph(result);
		average:=average_x_graph(signal);
		for i:=0 to length(signal)-1 do signal[i]:=signal[i]-average;
		result:='';
		for i:=0 to length(frequencies)-1 do begin
			if frequencies[i]=0 then begin
				amplitude:=average;
				offset:=0;
			end else begin
				frequency_component(frequencies[i],signal,amplitude,offset);
			end;
			writestr(s,amplitude:fsr:fsd,' ',offset:fsr:fsd,' ');
			insert(s,result,length(result)+1);
			if length(result)>long_string_length then begin
				Tcl_SetReturnString(interp,error_prefix
					+'Return string overflow in '					
					+'lwdaq '+option+'.');
				exit;
			end;
		end;
		Tcl_SetReturnString(interp,result);
	end 
	else if option='window_function' then begin
{
<p>Applies a linear <a href="https://grokipedia.com/page/Window_function">window function</a> to a series of samples. The window function affects the first and last <i>extent</i> samples in <i>data</i>. The window function calculates the average value of the data, and then scales the deviation of the first and last <i>extent</i> samples so that the first sample and the last sample are now equal to the average, while the deviation of the other affected samples increases linearly up to the edge of the affected sample range. The function returns a new data string with the same number of samples, but the first and last samples are guaranteed to be the same. The window function is useful for preparing data for fourier transforms.</p>

<pre>lwdaq_config -fsd 2 -fsr 1
lwdaq window_function 5 "0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1"
0.50 0.40 0.30 0.20 0.10 0.00 0.00 0.00 0.00 0.00 1.00 1.00 1.00 1.00 1.00 0.90 0.80 0.70 0.60 0.50 </pre>

<p>Here we see a step function being windowed so that the ends are at the average value. Note that we set the <i>fsd</i> (field size decimal) and <i>fsr</i> (field size real) configuration parameters so that we can get the output data all on one line.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' extent data".');
			exit;
		end;
		extent:=Tcl_ObjInteger(argv[2]);
		result:=Tcl_ObjString(argv[3]);
		gpx:=read_x_graph(result);
		window_function(gpx,extent);
		result:=string_from_x_graph(gpx);
		Tcl_SetReturnString(interp,result);
	end 
	else if option='glitch_filter' then begin
{
<p>Applies a glitch filter to a sequence of real-valued samples. The glitch filter takes a real-valued threshold as its first parameter, followed by a list of real-valued samples. The routine calls <i>glitch_filter</i> from <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>. A "glitch" is a corruption of one or more adjacent points in a signal. Our implementation of the glitch filter is designed to eliminate glitches that arise from missing samples being replaced by corrupt or interference samples in telemetry systems. When the absolute change in value from sample n-1 to sample n exceeds the threshold, we look to see if there is another threshold-exceeding change from sample n to n+1 in the opposite direction. If so, we replace sample n with sample n-1. Otherwise, we check to see if sample n+1 has exactly the same value as sample n, and if so, we replace sample n with sample n-1. Thus a jump up or down by more than the threshold, followed by any number of identical samples, will be treated as a glitch and eliminated entirely, replaced by the sample before the jump. A threshold of 0 disables the filter. As an example, we could have:</p>

<pre>lwdaq_config -fsd 0 -fsr 1
lwdaq glitch_filter 3.0 "0 1 20 1 0 3 1 2 3 2 2 0 8 6 7 0 0"
0 1 1 1 0 3 1 2 3 2 2 0 8 6 7 7 7</pre>

<p>Here we see a glitch in the third sample being removed, and later we have another glitch: a jump downwards of 7 when our threshold is 3, followed by two zeros. The repetition of the exact same value is a signature of glitches in unreliable signals. When several samples go missing, and the first is a corrupted sample, the reconstruction routine we apply to the raw telemetry signal will fill in the missing samples with the value of the corrupted sample. If we specify a negative threshold, the routine still uses its absolute value, but in addition it will append to the end of the output string the number of glitches removed.</p>

<pre>lwdaq glitch_filter -3.0 "0 0 0 0 10 0 1 2 0 0 0 0 0"
0 0 0 0 0 0 1 2 0 0 0 0 0 1</pre>

<p>The last number in the string is the number removed.</p>
}
		if (argc<4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' threshold data".');
			exit;
		end;
		threshold:=Tcl_ObjReal(argv[2]);
		result:=Tcl_ObjString(argv[3]);
		gpx:=read_x_graph(result);
		if abs(threshold)>0 then 
			num_glitches:=glitch_filter(gpx,abs(threshold))
		else
			num_glitches:=0;
		result:=string_from_x_graph(gpx);
		if threshold<0 then begin
			writestr(s,num_glitches:1);
			insert(s,result,length(result)+1);
		end;
		Tcl_SetReturnString(interp,result);
	end 
	else if option='glitch_filter_y' then begin
{
<p>Applies a glitch filter to the y-values of a sequence of x-y points. The routine calls <i>glitch_filter_y</i> from <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>. The result is equivalent to taking the y-values, passing them through the one-dimensional <a href="#glitch_filter">glitch_filter</a> and re-combining the result with their x-values. We replace the glitch point in the data sequence with a point whose y-coordinate is the same as the previous point's y-coordinate. A threshold of 0 disables the filter. A negative threshold causes the number of glitches to be appended to the signal values.</p>

<pre>lwdaq_config -fsd 0 -fsr 1
lwdaq glitch_filter_y -4.0 "1 0 2 0 3 10 4 0 5 0 6 0 7 5 8 5 9 0 10 0 11 0 12 0 13 0"
1 0 2 0 3 0 4 0 5 0 6 0 7 0 8 0 9 0 10 0 11 0 12 0 13 0 3</pre>

<p>In the example above, the final number in the output is the number of glitches removed.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' threshold data".');
			exit;
		end;
		threshold:=Tcl_ObjReal(argv[2]);
		result:=Tcl_ObjString(argv[3]);
		gp:=read_xy_graph(result);
		if abs(threshold)>0 then
			num_glitches:=glitch_filter_y(gp,abs(threshold))
		else
			num_glitches:=0;
		result:=string_from_xy_graph(gp);
		if threshold<0 then begin
			writestr(s,num_glitches:1);
			insert(s,result,length(result)+1);
		end;
		Tcl_SetReturnString(interp,result);
	end 
	else if option='glitch_filter_xy' then begin
{
<p>Applies a glitch filter to the a sequence of x-y points. The routine calls <i>glitch_filter_xy</i> from <a href="https://www.bndhep.net/Software/Sources/utils.pas">utils.pas</a>. The distance between consecutive points is their two-dimensional separation. The routine works in the same way as the one-dimensional <a href="#glitch_filter">glitch_filter</a> except it uses the separation of consecutive two-dimentional points rather than the absolute change in the value of a one-dimensional coordinate. A single-point glitch is a jump of length greater than the threshold followed by another jump of length greater than the threshold in a direction that is at least ninety degrees rotated with respect to the original jump. A threshold of 0 disables the filter.</p>

<pre>lwdaq_config -fsd 0 -fsr 1
lwdaq glitch_filter_xy 10 "0 0 1 0 0 2 3 2 50 2 2 2 1 4 3 3"
0 0 1 0 0 2 3 2 3 2 2 2 1 4 3 3</pre>

<p>A negative threshold causes the number of glitches to be appended to the end of the return string.</p>

<pre>lwdaq glitch_filter_xy -10 "0 0 1 0 0 2 3 2 50 2 2 2 1 4 3 3"
0 0 1 0 0 2 3 2 3 2 2 2 1 4 3 3 1</pre>

<p>The last number in the example above is not a sample, it is the number of glitches removed.</p>
}
		if (argc<>4) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' threshold data".');
			exit;
		end;
		threshold:=Tcl_ObjReal(argv[2]);
		result:=Tcl_ObjString(argv[3]);
		gp:=read_xy_graph(result);
		if abs(threshold)>0 then
			num_glitches:=glitch_filter_xy(gp,abs(threshold))
		else
			num_glitches:=0;
		result:=string_from_xy_graph(gp);
		if threshold<0 then begin
			writestr(s,num_glitches:1);
			insert(s,result,length(result)+1);
		end;
		Tcl_SetReturnString(interp,result);
	end 
	else if option='spikes_x' then begin
{
<p>Returns a list of spikes found by path-finding in a one-dimensional graph array. The values in the array represent the vertical position of a sequence of points in a two-dimensional map, while the horizontal position we construct by arranging the points in sequence with uniform spacing. The height of a map square is one mean absolute step size of the array values. The width of the map squares is the horizontal separation of consecutive points. The routine takes three parameters: data, threshold, and extent. The data is a list of real numbers. The threshold is the minimum size for spikes, in units of mean absolute steps. The extent is the maximum width for spikes. The result of the routine is a list of spikes, each of which is the index of a spike location and the size of the spike in units of mean absolute steps.</p>

<pre>lwdaq_config -fsd 2
lwdaq spikes_x "0 0 0 0 2 9 1 0 0 7 0 7 0 9 0 0 0 0" 2 4
5.00 2.46 9.00 2.21 11.00 2.21 13.00 2.72</pre>

<p>Above we specify a threshold of two mean absolute steps and an extent of four samples. The one-dimensional coastline of the data is 64 and there are 18 data points, so the mean absolute step size is 3.6. Sample five have value 9. We can step around sample five to sample six, missing out the spike on sample five. So our first spike has location five (5.00). To calculate the size of the first spike, we must convert the height of the spike into units of mean absolute steps, and we use the trailing edge of the spike to measure height, not the leading edge. So we have 9 as the highest point in the spike and 1 as the end of the spike to give us a height of 8 in original units, or 2.2 mean absolute steps. The horizontal distance from the peak to the trailing edge is 1 sample period, so the spike size is sqrt(sqr(2.2)+sqr(1)) = 2.46. The same logic is used to calculate the locations and heights of the remaining three spikes.</p>

}
		if (argc<>5) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' data threshold extent".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		gpx:=read_x_graph(result);
		threshold:=Tcl_ObjReal(argv[3]);
		extent:=Tcl_ObjInteger(argv[4]);
		gp:=spikes_x_graph(gpx,threshold,extent);
		result:=string_from_xy_graph(gp);
		Tcl_SetReturnString(interp,result);
	end
	else if option='coastline_x' then begin
{
<p>Returns the cumulative absolute difference in consecutive values of a sequence of real numbers. If we pass the routine "0 1 2 3 2 1 6" it returns value 10.0.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' data".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		gpx:=read_x_graph(result);
		writestr(result,coastline_x_graph(gpx):fsr:fsd);
		Tcl_SetReturnString(interp,result);
	end
	else if option='coastline_x_progress' then begin
{
<p>Returns a sequence of real numbers in which the n'th value is the coastline_x of the first n numbers passed into the routine. If we pass the routine "0 1 2 3 2 1 6" it returns "0 1 2 3 4 5 10". Thus the coastline_x of the entire sequence is the final number in the output sequence.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' data".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		gpx:=read_x_graph(result);
		gpx2:=coastline_x_graph_progress(gpx);
		result:=string_from_x_graph(gpx2);
		Tcl_SetReturnString(interp,result);
	end
	else if option='coastline_xy' then begin
{
<p>Returns the cumulative separation of consecutive values of a sequence of two-dimensional points. The routine accepts a sequence of two-dimensional points as pairs of real numbers. If we pass the routine "0 0 0 1 0 0 4 0" it returns value 6.0.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' data".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		gp:=read_xy_graph(result);
		writestr(result,coastline_xy_graph(gp):fsr:fsd);
		Tcl_SetReturnString(interp,result);
	end
	else if option='coastline_xy_progress' then begin
{
<p>Takes a two-dimensional graph as input and returns a two-dimensional graph in which the y-coordinate of the n'th point represents the coastline_xy of the first n points in the input graph and the x-coordinate of the n'th point is the same as the x-coordinate of the n'th input point. Thus the coastline_xy of the entire input graph is the final y-value of the output sequence.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' data".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		gp:=read_xy_graph(result);
		gp2:=coastline_xy_graph_progress(gp);
		result:=string_from_xy_graph(gp2);
		Tcl_SetReturnString(interp,result);
	end
	else if option='matrix_inverse' then begin
{
<p>Calculates the inverse of a square matrix. We pass the original matrix as a string of real numbers in <i>matrix</i>. The first number should be the top-left element in the matrix, the second number should be the element immediately to the right of the top-left element, and so on, proceeding from left to right, and then downwards to the bottom-right element. The command deduces the dimensions of the matrix from the number of elements, which must be an integer square. For more information about the matrix inverter, see matrix_inverse in utils.pas. The "lwdaq matrix_inverse" routine is inefficient in its use of the matrix_inverse function. The routine spends most of its time translating between TCL strings and Pascal floating point numbers. A 10x10 matrix inversion with random elements takes 1800 &mu;s on our 1 GHz iBook, of which only 100 &mu;s is spent calculating the inverse. The routine returns the inverse as a string of real numbers, in the same format as the original <i>matrix</i>.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' matrix".');
			exit;
		end;
		result:=Tcl_ObjString(argv[2]);
		num_elements:=word_count(result);
		num_rows:=trunc(sqrt(num_elements));
		if sqrt(num_elements)-num_rows>small_real then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Non-square matrix.');
			exit;
		end;
		M:=new_matrix(num_rows,num_rows);
		N:=new_matrix(num_rows,num_rows);
		read_matrix(result,M);
		N:=matrix_inverse(M);
		result:='';
		write_matrix(result,N);
		Tcl_SetReturnString(interp,result);
	end
	else if option='tkcolor' then begin
{
<p>Returns the Tk color that matches an internal lwdaq color value. The TK color is returned as a string of the form #RRGGBB, where R, G, and B are each hexadecimal digits specifying the intensity of red, blue, and green.</p>
}
		if (argc<>3) then begin
			Tcl_SetReturnString(interp,error_prefix
				+'Wrong number of arguments, should be '
				+'"lwdaq '+option+' color_value".');
			exit;
		end;
		color:=Tcl_ObjInteger(argv[2]);
		color:=overlay_color(color);
		red:=round(max_byte * (color and red_mask) / red_mask);
		green:=round(max_byte * (color and green_mask) / green_mask);
		blue:=round(max_byte * (color and blue_mask) / blue_mask);
		writestr(result,'#',
			string_from_decimal(red,16,2),
			string_from_decimal(green,16,2),
			string_from_decimal(blue,16,2));
		Tcl_SetReturnString(interp,result);
	end 
{
	A bad option returns a list in double-quotes containing all the valid option
	names. This list is used by the LWDAQ_command_reference routine to generate
	the library routine reference manual.
}
	else begin
		Tcl_SetReturnString(interp,'Bad option "'+option+'", must be one of "'
		+' bcam_from_global_point global_from_bcam_point bcam_from_global_vector'
		+' global_from_bcam_vector bcam_source_bearing bcam_source_position'
		+' bcam_image_position bcam_coord_from_mount'
		+' xyz_local_from_global_point xyz_global_from_local_point'
		+' xyz_local_from_global_vector xyz_global_from_local_vector '
		+' wps_wire_plane wps_calibrate'
		+' xyz_sum xyz_difference xyz_rotate xyz_unrotate xyz_unit_vector'
		+' xyz_cross_product xyz_dot_product xyz_rotation_from_axes'
		+' xyz_plane_plane_intersection xyz_line_plane_intersection'
		+' xyz_line_line_bridge xyz_point_line_vector xyz_axis_rotate'
		+' xyz_length'
		+' linear_interpolate nearest_neighbor straight_line_fit ave_stdev'
		+' sum_sinusoids frequency_components window_function'
		+' glitch_filter spikes_x glitch_filter_y glitch_filter_xy'
		+' coastline_x coastline_x_progress coastline_xy coastline_xy_progress'
		+' matrix_inverse'
		+' tkcolor'
		+'".');
		exit;
	end;
	
	if error_string<>'' then Tcl_SetReturnString(interp,error_string);
	lwdaq:=Tcl_OK;
end;

{
	lwdaq_init initializes our global variables to suit the TclTk interpreter,
	and installs our lwdaq commands. It is called by TclTk when we load our
	dynamic library.
}
function lwdaq_init(interp:pointer):integer; cdecl;
begin
	gui_interp_ptr:=interp;
	gui_writeln:=lwdaq_gui_writeln;
	gui_draw:=lwdaq_gui_draw;
	gui_wait:=lwdaq_gui_wait;
	gui_support:=lwdaq_gui_support;
	debug_log:=lwdaq_debug_log;
	setlength(nearest_neighbor_library,1,1);
	setlength(embed_library,1);
	setlength(embed_library[0].vector,1);
	
	tcl_createobjcommand(interp,'lwdaq_config',lwdaq_config,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_create',lwdaq_image_create,0,nil);
	tcl_createobjcommand(interp,'lwdaq_draw',lwdaq_draw,0,nil);
	tcl_createobjcommand(interp,'lwdaq_draw_raw',lwdaq_draw_raw,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_contents',lwdaq_image_contents,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_destroy',lwdaq_image_destroy,0,nil);
	tcl_createobjcommand(interp,'lwdaq_photo_contents',lwdaq_photo_contents,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_characteristics',lwdaq_image_characteristics,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_histogram',lwdaq_image_histogram,0,nil);
	tcl_createobjcommand(interp,'lwdaq',lwdaq,0,nil);
	tcl_createobjcommand(interp,'lwdaq_config',lwdaq_config,0,nil);
	tcl_createobjcommand(interp,'lwdaq_error_string',lwdaq_error_string,0,nil);
	tcl_createobjcommand(interp,'lwdaq_graph',lwdaq_graph,0,nil);
	tcl_createobjcommand(interp,'lwdaq_filter',lwdaq_filter,0,nil);
	tcl_createobjcommand(interp,'lwdaq_fft',lwdaq_fft,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_profile',lwdaq_image_profile,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_exists',lwdaq_image_exists,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_results',lwdaq_image_results,0,nil);
	tcl_createobjcommand(interp,'lwdaq_image_manipulate',lwdaq_image_manipulate,0,nil);
	tcl_createobjcommand(interp,'lwdaq_data_manipulate',lwdaq_data_manipulate,0,nil);
	tcl_createobjcommand(interp,'lwdaq_rasnik',lwdaq_rasnik,0,nil);
	tcl_createobjcommand(interp,'lwdaq_rasnik_shift',lwdaq_rasnik_shift,0,nil);
	tcl_createobjcommand(interp,'lwdaq_wps',lwdaq_wps,0,nil);
	tcl_createobjcommand(interp,'lwdaq_shadow',lwdaq_shadow,0,nil);
	tcl_createobjcommand(interp,'lwdaq_bcam',lwdaq_bcam,0,nil);
	tcl_createobjcommand(interp,'lwdaq_scam',lwdaq_scam,0,nil);
	tcl_createobjcommand(interp,'lwdaq_dosimeter',lwdaq_dosimeter,0,nil);
	tcl_createobjcommand(interp,'lwdaq_diagnostic',lwdaq_diagnostic,0,nil);
	tcl_createobjcommand(interp,'lwdaq_gauge',lwdaq_gauge,0,nil);
	tcl_createobjcommand(interp,'lwdaq_flowmeter',lwdaq_flowmeter,0,nil);
	tcl_createobjcommand(interp,'lwdaq_voltmeter',lwdaq_voltmeter,0,nil);
	tcl_createobjcommand(interp,'lwdaq_rfpm',lwdaq_rfpm,0,nil);
	tcl_createobjcommand(interp,'lwdaq_inclinometer',lwdaq_inclinometer,0,nil);
	tcl_createobjcommand(interp,'lwdaq_receiver',lwdaq_receiver,0,nil);
	tcl_createobjcommand(interp,'lwdaq_alt',lwdaq_alt,0,nil);
	tcl_createobjcommand(interp,'lwdaq_tcb',lwdaq_tcb,0,nil);
	tcl_createobjcommand(interp,'lwdaq_metrics',lwdaq_metrics,0,nil);
	tcl_createobjcommand(interp,'lwdaq_bcam_calib',lwdaq_bcam_calib,0,nil);
	tcl_createobjcommand(interp,'lwdaq_simplex',lwdaq_simplex,0,nil);
	tcl_createobjcommand(interp,'lwdaq_rag',lwdaq_rag,0,nil);
	
	lwdaq_init:=tcl_pkgprovide(interp,package_name,version_num);
end;

{
	lwdaq_unload calls all finalization routines in the lwdaq library and then
	returns OK.
}
function lwdaq_unload(interp:pointer;flags:integer):integer; cdecl;
begin
	lwdaq_unload:=Tcl_OK;
	halt;
end;

{
	lwdaq_safeinit installs only the lwdaq_config routine and then tries to provide
	this routine to Tcl.
}
function lwdaq_safeinit(interp:pointer):integer; cdecl;
begin
	gui_interp_ptr:=interp;
	gui_writeln:=lwdaq_gui_writeln;
	gui_draw:=lwdaq_gui_draw;
	gui_wait:=lwdaq_gui_wait;
	gui_support:=lwdaq_gui_support;
	debug_log:=lwdaq_debug_log;
	
	tcl_createobjcommand(interp,'lwdaq_config',lwdaq_config,0,nil);

	lwdaq_safeinit:=tcl_pkgprovide(interp,package_name,version_num);
end;

{
	lwdaq_safeunload does not call the lwdaq finalization routines, in case they
	are unsafe. So it just returns OK.
}
function lwdaq_safeunload(interp:pointer;flags:integer):integer; cdecl;
begin
	lwdaq_safeunload:=Tcl_OK;
end;

{
	We declare all routines we export.
}
exports
	lwdaq_init name tcl_ld_prefix+'Lwdaq_Init',
	lwdaq_unload name tcl_ld_prefix+'Lwdaq_Unload',
	lwdaq_safeinit name tcl_ld_prefix+'Lwdaq_Safeinit',
	lwdaq_safeunload name tcl_ld_prefix+'Lwdaq_Safeunload';
end.
