{
	Analysis Library.
	Copyright (C) 2007-2021, Kevan Hashemi, Brandeis University
	Copyright (C) 2021-2024, Kevan Hashemi, Open Source Instruments Inc.
	
	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the Free
	Software Foundation, either version 3 of the License, or (at your option)
	any later version.

	This program is distributed in the hope that it will be useful, but WITHOUT
	ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
	FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
	more details.

	You should have received a copy of the GNU General Public License along with
	this program.  If not, see <https://www.gnu.org/licenses/>.
}

library analysis;

{
	This is a library of routines from our analysis units. When compiled with
	our makefile, the result is a dynamically linked library (dylid on MacOS,
	dll on Windows, and so on Linux and Raspbian) that you can load and link to
	at run-time. The separate test.pas routine, aside from testing some of the
	fundamental routines, prints out a list of the sizes of various data types
	used by the library routines, in the hope that this will help you match
	data types in your own code.
}

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	utils,images,transforms,image_manip,rasnik,
	spot,bcam,shadow,wps,electronics,metrics;

{$IFDEF DARWIN}
	const exp_prefix='_';
{$ENDIF}

{$IFDEF WINDOWS}
	const exp_prefix='';
{$ENDIF}

{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	const exp_prefix='';
{$ENDIF}{$ENDIF}

{
	The following functions with prefix "dll" are designed to help us set up a connection
	between this dynamic library and a main program. 
}

function dll_inc(a:longint):longint; cdecl;
begin
	dll_inc:=a+1;
end;

function dll_print(s:PChar):longint; cdecl;
begin
	writeln('String passed to library is: "'+s+'"');
	dll_print:=length(s);
end;

function dll_sqrt(x:real):real; cdecl;
begin
	dll_sqrt:=sqrt(x);
end;

function dll_sizes:longint; cdecl;
begin
	writeln('Reporting sizes of variable types in Pascal:');
	writeln('Size of integer is ',sizeof(integer),' bytes.');
	writeln('Size of longint is ',sizeof(longint),' bytes.');
	writeln('Size of real is ',sizeof(real),' bytes.');
	writeln('Size of extended is ',sizeof(extended),' bytes.');
	writeln('Size of char is ',sizeof(char),' bytes.');
	dll_sizes:=0;
end;

{
	image_from_contents creates a new image with dimensions width and height,
	fills the intensity array with the block of data pointed to by
	intensity_ptr, and sets the analysis bounds with left, top, right, and
	bottom. The routine returns an image pointer.
}
function image_from_contents(intensity_ptr:pointer;
	width,height,left,top,right,bottom:integer;
	results,name:PChar):image_ptr_type; cdecl;

var 
	ip:image_ptr_type;

begin
	ip:=new_image(height,width);
	block_move(intensity_ptr,
		@ip^.intensity[0],
		ip^.j_size*ip^.i_size*sizeof(intensity_pixel_type));
	ip^.analysis_bounds.left:=left;
	ip^.analysis_bounds.top:=top;
	ip^.analysis_bounds.right:=right;
	ip^.analysis_bounds.bottom:=bottom;
	ip^.results:=results;
	ip^.name:=name;
	image_from_contents:=ip;
end;

{
	contents_from_image does the opposite of image_from_contents. If you pass a
	nil pointer in intensity_prt, the routine will not copy the image contents,
	but simply return the remaining parameters.
}
procedure contents_from_image(ip:image_ptr_type;
	intensity_ptr:pointer;
	var width,height,left,top,right,bottom:integer;
	var results,name:PChar); cdecl;

begin
	if intensity_ptr<>nil then
		block_move(@ip^.intensity[0],
			intensity_ptr,
			ip^.j_size*ip^.i_size*sizeof(intensity_pixel_type));
	left:=ip^.analysis_bounds.left;
	top:=ip^.analysis_bounds.top;
	right:=ip^.analysis_bounds.right;
	bottom:=ip^.analysis_bounds.bottom;
	results:=PChar(ip^.results);
	name:=PChar(ip^.name);
end;

{
	image_from_daq takes a block of data in the DAQ file format and creates a
	new image by reading the width, height and analysis bounds from the
	beginning of the file block. The image size, bounds, and name parameters
	return either as they were passed, if their values were uses, or changes to
	the values that image_from_daq decided upon. You must pass the size of the
	data block to image_from_daq so that, in case it deducesd large and invalid
	values for the image width and height, it constrains itself to copy only
	from the available image data.
}
function image_from_daq(data_ptr:pointer;data_size:integer;
	width,height,left,top,right,bottom,try_header:integer;
	results,name:PChar):PChar; cdecl;

var 
	ip:image_ptr_type=nil;
	ihp:image_header_ptr_type=nil;
	char_index,copy_size:integer;
	q:integer;
	
begin
	image_from_daq:=nil;
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
		report_error('Failed to allocate memory in image_from_daq.');
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
		results:=PChar(ip^.results);
	end 
	else ip^.results:=results;
	
	if name<>'' then begin
		if valid_image_name(name) then
			dispose_image(image_ptr_from_name(name));
		ip^.name:=name;
	end else begin
		name:=PChar(ip^.name);
	end;

	image_from_daq:=name;
end;

{
	daq_from_image does the opposite of image_from_daq. You must pass
	daq_from_image a pointer to a block of memory that is at least as large as
	ip^.width*ip^.height. 
}
procedure daq_from_image(ip:image_ptr_type;
	data_ptr:pointer); cdecl;

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

exports

{diagnostic routines}
	dll_inc name exp_prefix+'dll_inc',
	dll_print name exp_prefix+'dll_print',
	dll_sqrt name exp_prefix+'dll_sqrt',
	dll_sizes name exp_prefix+'dll_sizes',

{analysis interface routines for universal use}
	image_from_contents name exp_prefix+'image_from_contents',
	contents_from_image name exp_prefix+'contents_from_image',
	image_from_daq name exp_prefix+'image_from_daq',
	daq_from_image name exp_prefix+'daq_from_image',

{utils}
	check_for_math_error name exp_prefix+'check_for_math_error',
	math_error name exp_prefix+'math_error',
	math_overflow name exp_prefix+'math_overflow',
	error_function name exp_prefix+'error_function',
	complimentary_error_function name exp_prefix+'complimentary_error_function',
	gamma_function name exp_prefix+'gamma_function',
	chi_squares_distribution name exp_prefix+'chi_squares_distribution',
	chi_squares_probability name exp_prefix+'chi_squares_probability',
	factorial name exp_prefix+'factorial',
	full_arctan name exp_prefix+'full_arctan',
	sum_sinusoids name exp_prefix+'sum_sinusoids',
	xpy name exp_prefix+'xpy',
	xpyi name exp_prefix+'xpyi',
	random_0_to_1 name exp_prefix+'random_0_to_1',
	new_matrix name exp_prefix+'new_matrix',
	matrix_rows name exp_prefix+'matrix_rows',
	matrix_columns name exp_prefix+'matrix_columns',
	matrix_copy name exp_prefix+'matrix_copy',
	unit_matrix name exp_prefix+'unit_matrix',
	matrix_product name exp_prefix+'matrix_product',
	matrix_determinant name exp_prefix+'matrix_determinant',
	matrix_difference name exp_prefix+'matrix_difference',
	matrix_inverse name exp_prefix+'matrix_inverse',
	swap_matrix_rows name exp_prefix+'swap_matrix_rows',
	new_simplex name exp_prefix+'new_simplex',
	simplex_step name exp_prefix+'simplex_step',
	simplex_size name exp_prefix+'simplex_size',
	simplex_construct name exp_prefix+'simplex_construct',
	simplex_vertex_copy name exp_prefix+'simplex_vertex_copy',

{images}
	get_px name exp_prefix+'get_px',
	set_px name exp_prefix+'set_px',
	get_ov name exp_prefix+'get_ov',
	set_ov name exp_prefix+'set_ov',
	paint_image name exp_prefix+'paint_image',
	clear_image name exp_prefix+'clear_image',
	paint_overlay name exp_prefix+'paint_overlay',
	fill_overlay name exp_prefix+'fill_overlay',
	clear_overlay name exp_prefix+'clear_overlay',
	dispose_image name exp_prefix+'dispose_image',
	dispose_named_images name exp_prefix+'dispose_named_images',
	draw_image name exp_prefix+'draw_image',
	draw_rggb_image name exp_prefix+'draw_rggb_image',
	draw_gbrg_image name exp_prefix+'draw_gbrg_image',
	draw_image_line name exp_prefix+'draw_image_line',
	draw_overlay_line name exp_prefix+'draw_overlay_line',
	draw_overlay_pixel name exp_prefix+'draw_overlay_pixel',
	draw_overlay_rectangle name exp_prefix+'draw_overlay_rectangle',
	draw_overlay_rectangle_ellipse name exp_prefix+'draw_overlay_rectangle_ellipse',
	draw_overlay_ellipse name exp_prefix+'draw_overlay_ellipse',
	embed_image_header name exp_prefix+'embed_image_header',
	image_ptr_from_name name exp_prefix+'image_ptr_from_name',
	image_amplitude name exp_prefix+'image_amplitude',
	image_average name exp_prefix+'image_average',
	image_median name exp_prefix+'image_median',
	image_maximum name exp_prefix+'image_maximum',
	image_minimum name exp_prefix+'image_minimum',
	image_sum name exp_prefix+'image_sum',
	overlay_color name exp_prefix+'overlay_color',
	spread_overlay name exp_prefix+'spread_overlay',
	paint_overlay_bounds name exp_prefix+'paint_overlay_bounds',
	new_image name exp_prefix+'new_image',
	valid_analysis_bounds name exp_prefix+'valid_analysis_bounds',
	valid_image_analysis_point name exp_prefix+'valid_image_analysis_point',	
	valid_image_name name exp_prefix+'valid_image_name',
	valid_image_point name exp_prefix+'valid_image_point',
	valid_image_ptr name exp_prefix+'valid_image_ptr',
	write_image_list name exp_prefix+'write_image_list',

{transforms}
	i_from_c name exp_prefix+'i_from_c',
	c_from_i name exp_prefix+'c_from_i',
	p_from_i name exp_prefix+'p_from_i',
	i_from_p name exp_prefix+'i_from_p',
	c_from_i_line name exp_prefix+'c_from_i_line',
	i_from_p_line name exp_prefix+'i_from_p_line',
	i_from_c_line name exp_prefix+'i_from_c_line',
	p_from_i_line name exp_prefix+'p_from_i_line',
	i_from_c_rectangle name exp_prefix+'i_from_c_rectangle',
	c_from_i_rectangle name exp_prefix+'c_from_i_rectangle',
	i_from_c_ellipse name exp_prefix+'i_from_c_ellipse',
	c_from_i_ellipse name exp_prefix+'c_from_i_ellipse',
	display_ccd_cross name exp_prefix+'display_ccd_cross',
	display_ccd_line name exp_prefix+'display_ccd_line',
	draw_ccd_line name exp_prefix+'draw_ccd_line',
	display_ccd_pixel name exp_prefix+'display_ccd_pixel',
	display_ccd_rectangle name exp_prefix+'display_ccd_rectangle',
	display_ccd_rectangle_cross name exp_prefix+'display_ccd_rectangle_cross',
	display_ccd_rectangle_ellipse name exp_prefix+'display_ccd_rectangle_ellipse',
	display_ccd_ellipse name exp_prefix+'display_ccd_ellipse',
	display_profile_row name exp_prefix+'display_profile_row',
	display_profile_column name exp_prefix+'display_profile_column',
	display_real_graph name exp_prefix+'display_real_graph',
	draw_real_graph name exp_prefix+'draw_real_graph',

{image_manip}
	image_copy name exp_prefix+'image_copy',
	image_filter name exp_prefix+'image_filter',
	image_grad_i name exp_prefix+'image_grad_i',
	image_grad_j name exp_prefix+'image_grad_j',
	image_grad name exp_prefix+'image_grad',
	image_shrink name exp_prefix+'image_shrink',
	image_enlarge name exp_prefix+'image_enlarge',
	image_rotate name exp_prefix+'image_rotate',
	image_profile_column name exp_prefix+'image_profile_column',
	image_profile_row name exp_prefix+'image_profile_row',
	image_quadratic_sum name exp_prefix+'image_quadratic_sum',
	image_accumulate name exp_prefix+'image_accumulate',
	image_subtract name exp_prefix+'image_subtract',
	image_subtract_row_average name exp_prefix+'image_subtract_row_average',
	image_subtract_gradient name exp_prefix+'image_subtract_gradient',
	image_transfer_overlay name exp_prefix+'image_transfer_overlay',
	image_bounds_subtract name exp_prefix+'image_bounds_subtract',
	image_negate name exp_prefix+'image_negate',
	image_histogram name exp_prefix+'image_histogram',
	image_invert name exp_prefix+'image_invert',
	image_reverse_rows name exp_prefix+'image_reverse_rows',
	image_soec name exp_prefix+'image_soec',
	image_soer name exp_prefix+'image_soer',
	image_crop name exp_prefix+'image_crop',

{rasnik}
	new_rasnik name exp_prefix+'new_rasnik',
	dispose_rasnik name exp_prefix+'dispose_rasnik',
	rasnik_analyze_image name exp_prefix+'rasnik_analyze_image',
	new_rasnik_pattern name exp_prefix+'new_rasnik_pattern',
	dispose_rasnik_pattern name exp_prefix+'dispose_rasnik_pattern',
	rasnik_adjust_pattern_parity name exp_prefix+'rasnik_adjust_pattern_parity',
	rasnik_analyze_code name exp_prefix+'rasnik_analyze_code',
	rasnik_display_pattern name exp_prefix+'rasnik_display_pattern',
	rasnik_find_pattern name exp_prefix+'rasnik_find_pattern',
	rasnik_refine_pattern name exp_prefix+'rasnik_refine_pattern',
	rasnik_from_pattern name exp_prefix+'rasnik_from_pattern',
	rasnik_identify_code_squares name exp_prefix+'rasnik_identify_code_squares',
	rasnik_identify_pattern_squares name exp_prefix+'rasnik_identify_pattern_squares',
	rasnik_mask_position name exp_prefix+'rasnik_mask_position',
	rasnik_pattern_from_string name exp_prefix+'rasnik_pattern_from_string',
	rasnik_from_string name exp_prefix+'rasnik_from_string',
	rasnik_shift_reference_point name exp_prefix+'rasnik_shift_reference_point',
	rasnik_simulated_image name exp_prefix+'rasnik_simulated_image',
	string_from_rasnik_pattern name exp_prefix+'string_from_rasnik_pattern',
	string_from_rasnik name exp_prefix+'string_from_rasnik';

end.
