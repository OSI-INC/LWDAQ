{
	A dynamic library that exports routines. Compile on all platforms with:
	
	fpc d.pas -Px86_64
	
	The result will be a shared library called  d.dll (Windows), libd.dylib (MacOS), 
	or libd.so (Linux). We load the library into Python with a commands like this:
	
import ctypes
_libd = ctypes.CDLL( './libd.dylib' )
	def inc( a ):
return _libd.increment( ctypes.c_int( a ) )

}

library d;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}
{$MACRO ON}

{$IFDEF DARWIN}
	{
		We must add an underscrore to the names of routines we export, consistent
		with the GCC linker on MacOS.
	}
	const exp_prefix='_';
{$ENDIF}

{$IFDEF WINDOWS}
	{
		We must add an underscrore to the names of routines we export, consistent
		with the GCC linker on Windows.
	}
	const exp_prefix='_';
{$ENDIF}

{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	{ 
		We do not add an underscore to the start of any exported routine names,
		for consistency with the GCC linker on Linux.
	}
	const exp_prefix='';
{$ENDIF}{$ENDIF}

function increment(a:longint):longint; cdecl;
begin
	increment:=a+1;
end;

function printstring(s:PChar):longint; cdecl;
begin
	writeln('String passed into Pascal library is: "'+s+'"');
	printstring:=length(s);
end;

function sqroot(x:real):real; cdecl;
begin
	sqroot:=sqrt(x);
end;

function reportsizes:longint; cdecl;
begin
	writeln('Reporting sizes of variable types in Pascal:');
	writeln('Size of integer is ',sizeof(integer),' bytes.');
	writeln('Size of longint is ',sizeof(longint),' bytes.');
	writeln('Size of real is ',sizeof(real),' bytes.');
	writeln('Size of extended is ',sizeof(extended),' bytes.');
	writeln('Size of char is ',sizeof(char),' bytes.');
	reportsizes:=0;
end;

exports
	increment name exp_prefix+'increment',
	printstring name exp_prefix+'printstring',
	sqroot name exp_prefix+'sqroot',
	reportsizes name exp_prefix+'reportsizes';
end.

{
	A program that calls routines in an external dynamic library. This library
	must be stored in the same directory as the program executable, and must be
	named X.dll (Windows), libX.dylib (MacOS), or libX.so (Linux), where X is the
	library name given in the compiler directive below.
}

program m;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}
{$MACRO ON}

{$define _LIB_:='d'}

{$IFDEF DARWIN}
	{
		On MacOS, we cannot compile an executable unless we provide paths to
		all the libraries that it requires. The compile-time linker
		will check that all routines external to the executable code are
		available in the libraries on disk, and embed a path to these libraries
		in the executable object. At run-time, the dynamic linker goes through all
		the undefined symbols in executable and loads libraries from disk to resolve
		them. Our compile command looks like:

		fpc m.pas -om.exe -k-lX -kLY -Px86_64
		
		The compile-time linker looks for a library libX.dylib, where X is the
		name given in our Pascal code, and it looks in directory Y, which may be
		a relative path. The command also instructs the compiler to name the
		executable m.exe. Now run with:
		
		./m.exe
	}
	{$define _EXT_:=external}
{$ENDIF}


{$IFDEF WINDOWS}
	{
		On Windows, we cannot compile an executable unless we provide paths to
		all the libraries that it requires. The compile-time linker
		will check that all routines external to the executable code are
		available in the libraries on disk, and embed a path to these libraries
		in the executable object. At run-time, the dynamic linker goes through all
		the undefined symbols in executable and loads libraries from disk to resolve
		them. Our compile command looks like:

		fpc m.pas -om.exe -k-lX -kLY -Px86_64
		
		The compile-time linker looks for a library X.dll, where X is the name
		given in our Pascal code, and it looks in directory Y, which may be a
		relative path. The command also instructs the compiler to name the
		executable m.exe. Now run with:
		
		./m.exe
	}
	{$define _EXT_:=external}
{$ENDIF}


{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	{ 
		On Linux, we don't need to link to external libraries at compile time.
		The linker trusts that the required routines will be available at
		run-time. At compile time all we need is:
		
		fpc m.pas -om.exe -Px86_64
		
		At run-time, all symbols undefined in the executable must be resolved.
		If the symbols are defined in memory already by the operating system,
		they are resolved immediately. Otherwise, the dynamic linker must load a
		library from disk. Our external routines will not be defined by the
		operating system, nor loaded as part of any other library, so we must
		specify in our Pascal code, after each "external" directive, the name of
		the library in which the routine is defined. If we say "d" for the
		library name, FPC embeds the name "libd.so" in the executable file as
		the name of the library that must be loaded. The dynamic linker looks
		for libd.so in the Linux library paths. In our case, libd.so is a local
		library we have compiled ourselves, so we must use the LD_LIBRARY_PATH
		environment variable to tell the dynamic linker where to find it.
		
		LD_LIBRARY_PATH="./"
		export LD_LIBRARY_PATH
		
		Now run with:
		
		./m.exe
	}
	{$define _EXT_:=weakexternal}
{$ENDIF}{$ENDIF}


function increment(a:longint):longint; cdecl; _EXT_ _LIB_ name 'increment';
function printstring(s:PChar):longint; cdecl; _EXT_ _LIB_ name 'printstring';
function sqroot(x:real):real; cdecl; _EXT_ _LIB_ name 'sqroot';
function reportsizes:longint; cdecl; _EXT_ _LIB_ name 'reportsizes';

var 
	i:longint=42;
	x:real=21.0;

begin
	writeln('Hello world from m.pas.');
	reportsizes;
	writeln('Passed string of length ',printstring('hello sailor'),' to library.');
	writeln('Increment of ',i:1,' is ',increment(i):1);
	writeln('The square root of ',x:1:3,' is ',sqroot(x):1:3);
end.

{
	A program that loads our analysis units.
}
program p;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	utils,images,transforms,image_manip,rasnik,
	spot,bcam,shadow,wps,electronics,metrics;

procedure console_write(s:string);
begin writeln(s); end;

function console_read(s:string):string;
begin write(s);readln(s);console_read:=s; end;

var
	x:real;
	i:integer;
	
begin
	gui_writeln:=console_write;
	gui_readln:=console_read;
	gui_writeln('Hello from program p, which loads all analysis units.');
	
	for i:=0 to 15 do begin
		x:=i*2.0*pi/16;
		write(i:1,' ',x:fsr:fsd,' ');
		writeln(full_arctan(sin(x),cos(x)):fsr:fsd);
	end;
end.

{
	Here we link dynamically to libanalysis.dylib and call some routines.
}
program m;
 
{$linklib analysis}
{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}


type 
	ij_rectangle_type=record top,left,bottom,right:integer; end;
	overlay_pixel_type=byte;
	intensity_pixel_type=byte;
	image_type=record
		i_size,j_size,intensification:integer;
		intensity:packed array of intensity_pixel_type;
		overlay:packed array of overlay_pixel_type;
		analysis_bounds:ij_rectangle_type;
		average,amplitude,maximum,minimum:real;
		name,results:string;
	end;
	image_ptr_type=^image_type;

	xy_point_type=record x,y:real; end;
	rasnik_type=packed record
		valid:boolean;{no problems encountered during analysis}
		padding:array [1..7] of byte;{force mask_point to eight-byte boundary}
		mask_point:xy_point_type;{point in mask, um}
		magnification_x,magnification_y:real;{magnification along pattern coords}
		skew_x,skew_y:real;{skew in x and y directions in rad/m}
		slant:real;{radians non-perpendicularity in image}
		rotation:real;{radians anticlockwize in image}
		error:real;{um rms in mask}
		mask_orientation:integer;{orientation chosen by analysis}
		reference_point_um:xy_point_type;{point in image, um from top-left corner}
		square_size_um:real;{width of mask squares}
		pixel_size_um:real;{width of a sensor pixel in um}
	end;
	rasnik_ptr_type=^rasnik_type;

function new_image(height,width:integer):image_ptr_type;
	cdecl; external name 'new_image';

procedure rasnik_simulated_image(ip:image_ptr_type;command:string);
	cdecl; external name 'rasnik_simulated_image';
	
function image_amplitude(ip:image_ptr_type):real;
	cdecl; external name 'image_amplitude';

var
	rpp:rasnik_ptr_type;
	ip:pointer;
	s:string;
	a:real;
	
begin
	ip:=new_image(200,200);
	writeln('Well hello there, we made an image.');
	rasnik_simulated_image(ip,'5 0 20 25 20 10');
	writeln('And then we created a simulated rasnik image');
	a:=image_amplitude(ip);
	writeln('Image amplitude is: ',a:1:2);
end.

{

	Code by Fred Sv of FPC forum.
}
program m;

uses 
	dynlibs, SysUtils;

const
	use_local_path = true;
	dll_name = 'd.dll';
	
type
	TMyMethod=function :integer; cdecl;

var
	MyLib: TLibHandle = dynlibs.NilHandle;
	MyMethod: TMyMethod;
	name: shortstring;

begin

	if use_local_path then
		name := dll_name
	else
		name := ExtractFilePath(ParamStr(0)) + '\' + dll_name;

	writeln('Looking for library named "'+name+'"');	
	MyLib := LoadLibrary(name);
	
	if MyLib = 0 then begin
		writeln('Failed to load the dynamic library.');
		exit;
	end;
	MyMethod := TMyMethod(GetProcedureAddress(MyLib, 'answer'));
	if MyMethod <> nil then begin
		writeln('Found library routine, calling it now.');
		writeln('Answer: ',MyMethod);
		FreeLibrary(MyLib);
		MyLib:= DynLibs.NilHandle;
	end else begin
		writeln('Failed to find library routine.');
	end;
end.

{
	bcam_pair_calib_simplex is like bcam_pair_calib except it uses a simplex fitter
	rather than a direct calculation to find the calibration constants. The fit 
	takes place in eleven dimensions to accommodate the seven calibration constants
	and two x-y offsets of the source blocks at two ranges.
}
function bcam_pair_calib_simplex(calib_data:bcam_camera_pair_calib_input_type):bcam_camera_type;

const
	show_details=false;
	num_parameters=11;{7 BCAM calibration paramters and 4 source block displacements}
	max_iterations=20000;
	check_period=1000;
	pivot_z_scale=0.1;
	axis_xy_scale=1000;
	rotation_scale=1000;
	pivot_xy_scale=1.0;
	ccd_to_pivot_scale=1.0;
	simplex_construct_size=0.1;
	
var
	calibration:bcam_camera_type;
	sp:simplex_type;
	offset_x:real=0;
	offset_y:real=0;
	calculation_num:integer;
	
	function bcam_error(v:simplex_vertex_type):real;
	var 
		sum:real;
		mount_num,range_num,source_num:integer;
		bcam_point,apparatus_point:xyz_point_type;
		vertex_calib:bcam_camera_type;
	begin
		with vertex_calib do begin
			pivot.x:=v[1]/pivot_xy_scale;
			pivot.y:=v[2]/pivot_xy_scale;
			pivot.z:=v[3]/pivot_z_scale;
			axis.x:=v[4]/axis_xy_scale;
			axis.y:=v[5]/axis_xy_scale;
			axis.z:=calibration.axis.z;
			code:=calibration.code;
			ccd_to_pivot:=v[6]/ccd_to_pivot_scale;
			ccd_rotation:=v[7]/rotation_scale;
			id:=calibration.id;
		end;
		sum:=0;
		for mount_num:=1 to num_mounts_per_pair do begin
			for range_num:= 1 to num_ranges_per_mount do begin
				for source_num:=1 to num_sources_per_range do begin
					bcam_point:=
						global_from_calib_datum(
							calib_data.measurements[mount_num,range_num,source_num],
							vertex_calib,
							calib_data.mounts[mount_num]);
					if range_num=1 then begin
						apparatus_point.x:=
							calib_data.source_locations[source_num].x+v[8];
						apparatus_point.y:=
							calib_data.source_locations[source_num].y+v[9];
					end else begin
						apparatus_point.x:=
							calib_data.source_locations[source_num].x+v[10];
						apparatus_point.y:=
							calib_data.source_locations[source_num].y+v[11];
					end;
					apparatus_point.z:=
						bcam_point.z;
					sum:=sum+sqr(xyz_separation(bcam_point,apparatus_point));
				end;
			end;
		end;
		bcam_error:=sqrt(sum/num_mounts_per_pair/num_ranges_per_mount/num_sources_per_range);
	end;
	
begin
{
	Set the bcam calibration to some initial values.
}
		calibration:=nominal_bcam_camera(calib_data.device_type);
		calibration.id:=calib_data.id;
{
	Construct the simplex fitting structure.
}
	sp:=new_simplex(num_parameters);
	with sp do begin
		with calibration do begin
			vertices[1,1]:=pivot.x*pivot_xy_scale;
			vertices[1,2]:=pivot.y*pivot_xy_scale;
			vertices[1,3]:=pivot.z*pivot_z_scale;
			vertices[1,4]:=axis.x*axis_xy_scale;
			vertices[1,5]:=axis.y*axis_xy_scale;
			vertices[1,6]:=ccd_to_pivot*ccd_to_pivot_scale;
			vertices[1,7]:=ccd_rotation*rotation_scale;
			construct_size:=simplex_construct_size;
			max_done_counter:=2;
		end;
	end;
	simplex_construct(sp,bcam_error);
	
	if show_details then begin
		gui_writeln('Simplex fitting progress:');
	end;
	
	calculation_num:=0;
	repeat
		if calculation_num mod check_period = 0 then begin
			gui_support('');
			if show_details then begin
				with calibration do begin
					pivot.x:=sp.vertices[1,1]/pivot_xy_scale;
					pivot.y:=sp.vertices[1,2]/pivot_xy_scale;
					pivot.z:=sp.vertices[1,3]/pivot_z_scale;
					axis.x:=sp.vertices[1,4]/axis_xy_scale;
					axis.y:=sp.vertices[1,5]/axis_xy_scale;
					ccd_to_pivot:=sp.vertices[1,6]/ccd_to_pivot_scale;
					ccd_rotation:=sp.vertices[1,7]/rotation_scale;
				end;
				gui_writeln(stringof(calculation_num:1)+' '
					+string_from_bcam_camera(calibration)
					+' '+stringof(sp.vertices[1,8]:1:3)
					+' '+stringof(sp.vertices[1,9]:1:3)
					+' '+stringof(sp.vertices[1,10]:1:3)
					+' '+stringof(sp.vertices[1,11]:1:3)
					+' '+stringof(bcam_error(sp.vertices[1]):1:3));
			end;
		end;
		simplex_step(sp,bcam_error);
		inc(calculation_num);
	until (sp.done_counter>=sp.max_done_counter) 
		or (calculation_num>max_iterations)
		or (error_string<>'');
		
	with calibration do begin
		pivot.x:=sp.vertices[1,1]/pivot_xy_scale;
		pivot.y:=sp.vertices[1,2]/pivot_xy_scale;
		pivot.z:=sp.vertices[1,3]/pivot_z_scale;
		axis.x:=sp.vertices[1,4]/axis_xy_scale;
		axis.y:=sp.vertices[1,5]/axis_xy_scale;
		ccd_to_pivot:=sp.vertices[1,6]/ccd_to_pivot_scale;
		ccd_rotation:=sp.vertices[1,7]/rotation_scale;
	end;
	if show_details then
		gui_writeln(stringof(calculation_num:1)+' '
			+string_from_bcam_camera(calibration)
			+' '+stringof(sp.vertices[1,8]:1:3)
			+' '+stringof(sp.vertices[1,9]:1:3)
			+' '+stringof(sp.vertices[1,10]:1:3)
			+' '+stringof(sp.vertices[1,11]:1:3)
			+' '+stringof(bcam_error(sp.vertices[1]):1:3));

	dispose_simplex(sp);
	bcam_pair_calib_simplex:=calibration;
end;

{
	image_from_daq takes a block of data in the DAQ file format and
	creates a new image by reading the width, height and analysis bounds
	from the beginning of the file block. The image size, bounds, and name
	parameters return either as they were passed, if their values were
	uses, or changes to the values that image_from_daq decided upon. You
	must pass the size of the data block to image_from_daq so that, in
	case it deducesd large and invalid values for the image width and
	height, it constrains itself to copy only from the available image
	data.
}
function image_from_daq(data_ptr:pointer;data_size:integer;
	var width,height,left,top,right,bottom,try_header:integer;
	var results,name:CString):image_ptr_type;

var 
	ip:image_ptr_type=nil;
	ihp:image_header_ptr_type=nil;
	char_index,copy_size:integer;
	q:integer;
	s:short_string;

begin
	if data_ptr=nil then exit;
	if data_size<=0 then exit;
	
	ihp:=pointer(data_ptr);

	if (try_header<>0) then begin
		q:=local_from_big_endian_smallint(ihp^.j_max)+1;
		if (q>0) then height:=q;
		q:=local_from_big_endian_smallint(ihp^.i_max)+1;
		if (q>0) then width:=q;
	end;
	if (width<=0) or (height<=0) then begin
		width:=trunc(sqrt(data_size));
		if (sqr(width)<data_size) then width:=width+1;
		height:=width;
	end;

	if (width*height>data_size) then copy_size:=data_size
	else copy_size:=(width*height);

	ip:=new_image(height,width);
	if ip=nil then begin
		report_error('Failed to allocate memory for new image in '+CurrentRoutineName+'.');
		exit;
	end;

	block_move(data_ptr,@ip^.intensity,copy_size);

	if (try_header<>0) then begin
		q:=local_from_big_endian_smallint(ihp^.left);
		if (q>=0) then left:=q;
	end;
	if (left<0) or (left>=width) then left:=0;
	ip^.analysis_bounds.left:=left;
	
	if (try_header<>0) then begin
		q:=local_from_big_endian_smallint(ihp^.right);
		if (q>left) then right:=q;
	end;
	if (right<=left) or (right>=width) then right:=width-1;
	ip^.analysis_bounds.right:=right;

	if (try_header<>0) then begin
		q:=local_from_big_endian_smallint(ihp^.top);
		if (q>=0) then top:=q;
	end;
	if (top<1) or (top>=height) then top:=1;
	ip^.analysis_bounds.top:=top;
	
	if (try_header<>0) then begin
		q:=local_from_big_endian_smallint(ihp^.bottom);
		if (q>top) then bottom:=q;
	end;
	if (bottom<=top) or (bottom>=height) then bottom:=height-1;
	ip^.analysis_bounds.bottom:=bottom;
	
	if (try_header<>0) then begin
		ip^.results:='';
		char_index:=0;
		while (char_index<short_string_length) 
				and (ihp^.results[char_index]<>chr(0)) do begin
			ip^.results:=ip^.results+ihp^.results[char_index];
			inc(char_index);
		end;
		results:=ip^.results;
	end 
	else ip^.results:=short_string_from_c_string(results);
	
	s:=short_string_from_c_string(name);
	if s<>'' then begin
		if valid_image_name(s) then
			dispose_image(image_ptr_from_name(s));
		ip^.name:=s;
	end;

	image_from_daq:=ip;
end;

{
	daq_from_image does the opposite of image_from_daq. You must pass
	daq_from_image a pointer to a block of memory that is at least
	as large as ip^.width*ip^.height.
}
procedure daq_from_image(ip:image_ptr_type;data_ptr:pointer);

var
	ihp:image_header_ptr_type;
	char_index:integer;
	
begin
	if data_ptr=nil then exit;
	with ip^ do begin
		ihp:=pointer(@intensity);
		ihp^.i_max:=big_endian_from_local_smallint(i_size-1);
		ihp^.j_max:=big_endian_from_local_smallint(j_size-1);
		ihp^.left:=big_endian_from_local_smallint(analysis_bounds.left);
		ihp^.right:=big_endian_from_local_smallint(analysis_bounds.right);
		ihp^.top:=big_endian_from_local_smallint(analysis_bounds.top);
		ihp^.bottom:=big_endian_from_local_smallint(analysis_bounds.bottom);
		for char_index:=1 to length(results) do 
			ihp^.results[char_index-1]:=results[char_index];
		ihp^.results[length(results)]:=chr(0);
	end;
	block_move(data_ptr,@ip^.intensity,ip^.j_size*ip^.i_size);
end;

{
	read_daq_file reads an image in daq format out of a file and 
	returns a pointer to the image in memory. It calls image_from_daq to 
	convert the file contents into an image.
}
function read_daq_file(name:CString):image_ptr_type;

var
	b:byte_array_ptr;
	width,height,left,top,right,bottom:integer=0;
	try_header:integer=1;
	image_results,image_name:CString='';
	
begin
	b:=read_file(short_string_from_c_string(name));
	if b=nil then exit;
	read_daq_file:=image_from_daq(@b^[0],b^.size,
		width,height,left,top,right,bottom,
		try_header,
		image_results,image_name);
	dispose_byte_array(b);
end;

{
	write_daq_file writes an image to disk in daq format. It 
	calls daq_from_image to create the daq data block.
}
procedure write_daq_file(name:CString;ip:image_ptr_type);

var
	b:byte_array_ptr;
	
begin
	b:=new_byte_array(sizeof(ip^.intensity));
	if b=nil then begin
		report_error('Error allocating for byte array in '+CurrentRoutineName+'.');
		exit;
	end;
	daq_from_image(ip,@b^[0]);
	write_file(short_string_from_c_string(name),b);
	dispose_byte_array(b);
end;

