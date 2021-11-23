unit shadow;
{
Routines for for Detecting One-Dimensional Shadows in Images.
Copyright (C) 2002-2021 Kevan Hashemi, Brandeis University
Copyright (C) 2021 Kevan Hashemi, Open Source Instruments Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place - Suite 330, Boston, MA  02111-1307, USA.

These routines are effective at finding wire shadows or dark images of wires
against bright backgrounds, provided that the shadows are not sharp. Sharp-edged
shadows have uniform darkness from one edge to the other, and these routines
rely upon there being a minimum of intensity near the center of the shadow or
image. We used them to good effect with dim x-ray images of muon tubes for the
ATLAS experiment. They performed well with severely out-of-focus images we
obtained from an optical Wire Position Sensor. But they do not perform well with
image from a well-focused Wire Position Sensor. We detect poor performance by
varying the min_separation parameter and watching how the measured wire position
changes. Suppose the wire shadow is 200 um wide, and we set the minimum
separation to 400 um. The shadow-finding routines will put a box 400 um wide
around the wire shadow and fit a notch profile to the shadow. The notch is 200
um wide (half the width of the box). The shadow-finding performs well if the
measured position does not move by more than a pixel as we incrase the minimum
separation from 400 um to 1000 um. This is the case for de-fucused images with
uniform background intensity, but not true for sharp images with varying
background intensity.
}

interface

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	utils,transforms,images,image_manip;

const {for shadow types}
	max_num_shadows=20;
	wire_name='wire';
	tube_left_outer_name='left_outer_edge';
	tube_right_outer_name='right_outer_edge';
	tube_left_inner_name='left_inner_edge';
	tube_right_inner_name='right_inner_edge';
	shadow_invalid_string='invalid';
	shadow_list_invalid_string='invalid';

type {for shadow list}
{
	The shadow_type describes a shadow on an image in terms of its position,
	rotation, and width. The structure of the record matches that of the 
	pattern_type we define in our transforms unit, which allows us to use
	its co-ordinate transformation routines to move between coordinates on
	the image and coordinates in the geometry of the pattern.
}
	shadow_type=record
		valid:boolean;
		padding:array [1..7] of byte;
		position:xy_point_type;
		rotation:real;
		width:xy_point_type;
		columnrow:ij_point_type;
		area:ij_rectangle_type;
		correlation,amplitude,average:real;
		shadow_name:string;
	end;
	shadow_ptr_type=^shadow_type;
{
	The shadow_list_type either describes a list of shadows we want to find
	in an image, or a list of shadows we have already found.
}
	shadow_list_type=record
		valid:boolean;{for error tracking}
		min_separation_um:real;{microns center to center}
		pixel_size_um:real;{size of pixels}
		num_shadows:integer;{number of shadows specified for the image}
		shadows:array [1..max_num_shadows] of shadow_type;
	end;
	shadow_list_ptr_type=^shadow_list_type;

function new_shadow_list_ptr:shadow_list_ptr_type;
procedure dispose_shadow_list_ptr(slp:shadow_list_ptr_type);
function shadow_list_from_string(s:string):shadow_list_ptr_type;
function string_from_shadow_list(slp:shadow_list_ptr_type):string;
function string_from_shadows(slp:shadow_list_ptr_type):string;
procedure shadow_locate_approximate(ip:image_ptr_type;
	slp:shadow_list_ptr_type);
procedure shadow_locate_accurate(ip:image_ptr_type;
	slp:shadow_list_ptr_type);

implementation

const {for rough shadow location and marking}
	area_color=green_color;
	profile_color=red_color;
	profile_derivative_color=yellow_color;
	isolation_threshold_color=blue_color;
	max_num_threshold_steps=30;

const {for ascent algorithm}
	random_start_range=0.1;{fraction of fitting area}
	nominal_rotation=0;{mrad}
	rotation_max=100;{mrad}

{
	new_shadow_list_ptr creates a new shadow list with "length"
	entries.
}
function new_shadow_list_ptr:shadow_list_ptr_type;

var
	slp:shadow_list_ptr_type;
	
begin
	new_shadow_list_ptr:=nil;
	new(slp);
	if slp=nil then exit;
	inc_num_outstanding_ptrs(sizeof(slp^),'new_shadow_list_ptr');
	slp^.valid:=false;
	slp^.num_shadows:=0;
	new_shadow_list_ptr:=slp;
end;

{
	dispose_shadow_list_ptr disposes of a shadow list.
}
procedure dispose_shadow_list_ptr(slp:shadow_list_ptr_type);

begin
	if slp=nil then exit;
	dec_num_outstanding_ptrs(sizeof(slp^),'dispose_shadow_list_ptr');
	dispose(slp);
end;

{
	shadow_list_from_string reads a shadow list, including its metadata, into a string.
}
function shadow_list_from_string(s:string):shadow_list_ptr_type;
		
var
	shadow_num:integer;
	slp:shadow_list_ptr_type;
	
begin
	shadow_list_from_string:=nil;
	slp:=new_shadow_list_ptr;
	if slp=nil then exit;
	slp^.valid:=false;
	if (s=shadow_invalid_string) then exit;
	with slp^ do begin
		valid:=true;
		min_separation_um:=read_real(s);
		pixel_size_um:=read_real(s);
		num_shadows:=read_integer(s);
		if (num_shadows>max_num_shadows) or (num_shadows<0) then valid:=false
		else for shadow_num:=1 to num_shadows do 
			with shadows[shadow_num] do begin
				shadow_name:=read_word(s);
				position.x:=0;
				position.y:=0;
				width.x:=100;
				width.y:=1;
				rotation:=0;
				columnrow.j:=0;
				columnrow.i:=0;
				valid:=false;
			end;
	end;
	shadow_list_from_string:=slp;
end;

{
	string_from_shadow_list writes shadow list metadata to a string, followed
	by the positions and orientations of the shadows. If you don't want the
	metadata, use string_from_shadows.
}
function string_from_shadow_list(slp:shadow_list_ptr_type):string;
		
var
	shadow_num:integer;
	s:string;
	
begin 
	string_from_shadow_list:=shadow_list_invalid_string;
	if slp=nil then exit;
	if not slp^.valid then exit;
	
	with slp^ do begin
		writestr(s,min_separation_um:1:1,' ',
			pixel_size_um:1:1,' ',
			num_shadows:1);
		for shadow_num:=1 to num_shadows do
			writestr(s,s,' ',shadows[shadow_num].shadow_name);
	end;
	string_from_shadow_list:=s;
end;

{
	string_from_shadows takes a shadow list and returns a string presenting its
	the positions and rotations of the shadows, but no shadow list metadata.
}
function string_from_shadows(slp:shadow_list_ptr_type):string;

var
	shadow_num:integer;
	s:string;

begin
	string_from_shadows:='';
	if slp=nil then exit;
	if not slp^.valid then exit;
	s:='';
	for shadow_num:=1 to slp^.num_shadows do
		with slp^.shadows[shadow_num] do
			writestr(s,s,position.x:1:2,' ',rotation*mrad_per_rad:1:3,' ');
	string_from_shadows:=s;
end;

{
	randomize_shadow displaces a shadow from its approximate position
	so as to provide a random starting point close to the actual position
	for our steepest ascent routine to start form.
}
procedure randomize_shadow(var shadow:shadow_type);

var 
	ir:xy_rectangle_type;
	
function delta:real;
begin delta:=(random_0_to_1-one_half)/one_half; end;

begin 
	with shadow do begin
		ir:=i_from_c_rectangle(area);
		position.x:=(ir.left+ir.right)*one_half
			+delta*random_start_range*(ir.right-ir.left)*one_half;
		position.y:=(ir.top+ir.bottom)*one_half;
		rotation:=0;
{		width.x:=(ir.right-ir.left)*one_half;}
		width.y:=(ir.bottom-ir.top)*one_half;
	end;
end; 

{
	Draw a line along the center of the wire shadow.
}
procedure shadow_line_display(ip:image_ptr_type;
	shadow:shadow_type;color:overlay_pixel_type);

var
	shadow_line:xy_line_type;
		
begin
	with shadow_line,shadow do begin
		a.x:=0;
		a.y:=-1;
		b.x:=0;
		b.y:=+1;
	end;
	display_ccd_line(ip,c_from_i_line(i_from_p_line(shadow_line,@shadow)),color);
	with shadow_line,shadow do begin
		a.x:=+0.1;
		a.y:=-1;
		b.x:=+0.1;
		b.y:=+1;
	end;
	display_ccd_line(ip,c_from_i_line(i_from_p_line(shadow_line,@shadow)),blue_color);
	with shadow_line,shadow do begin
		a.x:=-0.1;
		a.y:=-1;
		b.x:=-0.1;
		b.y:=+1;
	end;
	display_ccd_line(ip,c_from_i_line(i_from_p_line(shadow_line,@shadow)),blue_color);
end;

{
	shadow_locate_approximate determines the column fields of all the shadows
	in the shadow list.
}
procedure shadow_locate_approximate(ip:image_ptr_type;slp:shadow_list_ptr_type);

var 
	min_separation:integer;
	threshold,threshold_step:real;
	i:integer;
	left_i,right_i:integer;
	shadow_num:integer;
	notch_index,right_edge_index,left_edge_index:integer;
	notch_list,right_edge_list,left_edge_list:shadow_list_type;
	profile,derivative:x_graph_type;
	graph:xy_graph_type;
	rms_residual,slope,intercept:real;
	profile_max,profile_min,derivative_max,derivative_min:real;
	ccd_line:ij_line_type;
	
begin 
{
	check the input data
}
	if slp=nil then exit;
	slp^.valid:=false;
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then begin
		report_error('invalid analysis bounds in shadow_locate_approximate.');
		exit;
	end;
{
	calculate the minimun distance between shadows
}
	min_separation:=round(slp^.min_separation_um/slp^.pixel_size_um);
{
	count each type of shadow expected in image.
}
	notch_list.num_shadows:=0;
	right_edge_list.num_shadows:=0;
	left_edge_list.num_shadows:=0;
	for shadow_num:=1 to slp^.num_shadows do begin
		with slp^.shadows[shadow_num] do begin
			shadow_name:=strip_spaces(shadow_name);
			if shadow_name=wire_name then begin
				inc(notch_list.num_shadows);
				inc(right_edge_list.num_shadows);
				inc(left_edge_list.num_shadows);
			end;
			if shadow_name=tube_right_inner_name then
				inc(notch_list.num_shadows);
			if shadow_name=tube_left_inner_name then
				inc(notch_list.num_shadows);
			if shadow_name=tube_right_outer_name then
				inc(right_edge_list.num_shadows);
			if shadow_name=tube_left_outer_name then 
				inc(left_edge_list.num_shadows);
			if shadow_name='' then begin
				report_error('shadow_name="" in shadow_locate_approximate.');
				exit;
			end;
		end;
	end;
{
	obtain a horizontal profile by summing each column in ip^.analysis_bounds.
}	
	profile:=image_profile_row(ip);
{
	find the minimum and maximum values of the profile.
}	
	profile_max:=min_intensity;
	profile_min:=max_intensity;
	with ip^.analysis_bounds do begin
		for i:=left to right do begin
			if profile_max<profile[i-left] then profile_max:=profile[i-left];
			if profile_min>profile[i-left] then profile_min:=profile[i-left];
		end;
	end;
{
	display profile.
}	
	if show_details then 
		display_profile_row(ip,profile,profile_color);
{
	calculate slope of profile.
}
	with ip^.analysis_bounds do begin
		setlength(graph,right-left+1);
		for i:=left to right do begin
			graph[i-left].x:=i;
			graph[i-left].y:=profile[i-left];
		end;
		straight_line_fit(graph,slope,intercept,rms_residual);
	end;
{
	calculate horizontal derivative of the intensity profile.
}
	with ip^.analysis_bounds do begin
		setlength(derivative,right-left+1);
		derivative_max:=min_intensity;
		derivative_min:=max_intensity;
		for i:=left to right do begin
			if i=left then 
				derivative[i-left]:=
					profile[i-left+1]-profile[i-left];
			if (i>left) and (i<right) then 
				derivative[i-left]:=
					(profile[i-left+1]-profile[i-left-1])*one_half;
			if i=right then 
				derivative[i-left]:=
					profile[i-left]-profile[i-left-1];
			if derivative_max<derivative[i-left] then 
				derivative_max:=derivative[i-left];
			if derivative_min>derivative[i-left] then 
				derivative_min:=derivative[i-left];
		end;
	end;
{
	display derivative.
}
	if show_details then 
		display_profile_row(ip,derivative,profile_derivative_color);
{
	find the notch-like shadows by looking at the profile.
}
	threshold:=profile_min;
	threshold_step:=(profile_max-profile_min)/max_num_threshold_steps;
	with ip^.analysis_bounds do begin
		repeat
			i:=left;
			notch_index:=0;
			while (i<=right) and (notch_index<notch_list.num_shadows) do begin
				if profile[i-left]<(threshold+(i-left)*slope) then begin
					inc(notch_index);
					left_i:=i;
					right_i:=i;
					repeat 
						inc(right_i);
					until (right_i>=right) or
						(profile[right_i-left]>(threshold+(right_i-left)*slope));	
					i:=(left_i+right_i) div 2;
					notch_list.shadows[notch_index].columnrow.i:=i;
					i:=left_i+min_separation;
				end;
				i:=i+1;
			end;
			threshold:=threshold+threshold_step;
		until (notch_index=notch_list.num_shadows) or (threshold>profile_max);
	end;
	
	if notch_index<notch_list.num_shadows then begin
		report_error('notch_index<notch_list.num_shadows in shadow_locate_approximate.');
		exit;
	end;
{
	display threshold line used to isolate notches
}
	if show_details then begin
		with ccd_line,ip^.analysis_bounds do begin
			a.i:=left;
			a.j:=bottom-round(
					(bottom-top)
					*(threshold-profile_min)
					/(profile_max-profile_min));
			b.i:=right;
			b.j:=bottom-round(
					(bottom-top)
					*(threshold+slope*(right-left)-profile_min)
					/(profile_max-profile_min));
		end;
		display_ccd_line(ip,ccd_line,isolation_threshold_color);
	end;
{
	find the right-edge-like shadows by looking at the maxima of the derivative profile.
}
	threshold:=derivative_max;
	threshold_step:=(derivative_max-derivative_min)/max_num_threshold_steps;
	with ip^.analysis_bounds do begin
		repeat
			i:=left;
			right_edge_index:=0;
			while (i<=right) and (right_edge_index<right_edge_list.num_shadows) do begin
				if derivative[i-left]>threshold then begin
					inc(right_edge_index);
					left_i:=i;
					right_i:=i;
					repeat 
						right_i:=right_i+1;
					until (right_i>=right) or
						(derivative[right_i-left]<threshold);				
					i:=(left_i+right_i) div 2;
					right_edge_list.shadows[right_edge_index].columnrow.i:=i;
					i:=left_i+min_separation;
				end;
				i:=i+1;
			end;
			threshold:=threshold-threshold_step;
		until (right_edge_index=right_edge_list.num_shadows) or (threshold<=derivative_min);
	end;
		
	if right_edge_index<right_edge_list.num_shadows then begin
		report_error('right_edge_index<right_edge_list.num_shadows in shadow_locate_approximate.');
		exit;
	end;
{
	find the left-edge-like shadows by looking at the minima of the derivative profile.
}	
	threshold:=derivative_min;
	threshold_step:=(derivative_max-derivative_min)/max_num_threshold_steps;
	with ip^.analysis_bounds do begin
		repeat
			i:=left;
			left_edge_index:=0;
			while (i<=right) and (left_edge_index<left_edge_list.num_shadows) do begin
				if derivative[i-left]<threshold then begin
					inc(left_edge_index);
					left_i:=i;
					right_i:=i;
					repeat 
						right_i:=right_i+1;
					until (right_i>=right) or
						(derivative[right_i-left]>threshold);				
					i:=(left_i+right_i) div 2;
					left_edge_list.shadows[left_edge_index].columnrow.i:=i;
					i:=left_i+min_separation;
				end;
				i:=i+1;
			end;
			threshold:=threshold+threshold_step;
		until (left_edge_index=left_edge_list.num_shadows) or (threshold>=derivative_max);
	end;
		
	if left_edge_index<left_edge_list.num_shadows then begin
		report_error('left_edge_index<left_edge_list.num_shadows in shadow_locate_approximate.');
		exit;
	end;
{
	assemble shadow_list out of notch_list, right_edge_list, and left_edge_list.
}
	notch_index:=1;
	right_edge_index:=1;
	left_edge_index:=1;
	with slp^ do begin
		for shadow_num:=1 to num_shadows do begin
			with shadows[shadow_num] do begin
				if shadow_name=wire_name then begin
					columnrow.i:=notch_list.shadows[notch_index].columnrow.i;
					inc(notch_index);
					inc(right_edge_index);
					inc(left_edge_index);
				end;
				if shadow_name=tube_right_inner_name then begin
					columnrow.i:=notch_list.shadows[notch_index].columnrow.i;
					inc(notch_index);
				end;
				if shadow_name=tube_left_inner_name then begin
					columnrow.i:=notch_list.shadows[notch_index].columnrow.i;
					inc(notch_index);
				end;
				if shadow_name=tube_right_outer_name then begin
					columnrow.i:=right_edge_list.shadows[right_edge_index].columnrow.i;
					inc(right_edge_index);
				end;
				if shadow_name=tube_left_outer_name then begin
					columnrow.i:=left_edge_list.shadows[left_edge_index].columnrow.i;
					inc(left_edge_index);
				end;
				position.x:=columnrow.i*pixel_size_um;
				rotation:=0;
			end;
		end;
	end;
{
	Done.
}
	slp^.valid:=true;
end; 

{
	notch returns a straight-edged notch function
	extending notch_extent on either side of the
	y-axis.
}
function notch(point:xy_point_type):real;

begin 
	if abs(point.x)>200 then notch:=1 else notch:=abs(point.x)/200;
end;

{
	right_edge returns a right-edge function.
}
function right_edge(point:xy_point_type):real;

begin 
	if (point.x>0) then right_edge:=+1 else right_edge:=-1;
end;

{
	left_edge returns a left edge pattern.
}
function left_edge(point:xy_point_type):real;

begin 
	if (point.x>0) then left_edge:=-1 else left_edge:=+1;
end;

{
	The following data structure contains the information needed by the simplex
	error function we use to find a shadow in an image. These are two pointers,
	one to an image and one to a shadow.
}
type
	simplex_data=record
		ip:image_ptr_type;
		sp:shadow_ptr_type;
	end;
	simplex_data_ptr=^simplex_data;
			
{
	The error function we provide for the simplex fitter obtains a real
	number proportional to the average product of pattern and pixel values
	within a region of the image. To reduce aliasing and edge effects,
	we subtract the average intensity in the region from the image intensity
	before multiplication. We return the negative of the correlation as the
	error, which will be minimized by the simplex fitter, thus maximizing
	the correlation.
}
function simplex_error(v:simplex_vertex_type;ep:pointer):real;

const
	rotation_scale=2000;
		
var
	p:ij_point_type;
	pp:xy_point_type;
	counter,i,j:integer;
	sum,wire:real;
	dp:simplex_data_ptr;

begin
	dp:=simplex_data_ptr(ep);
	with dp^.sp^ do begin
		position.x:=v[1];
		rotation:=v[2]/rotation_scale;
		counter:=0;
		sum:=0;
		for j:=dp^.sp^.area.top to dp^.sp^.area.bottom do begin
			for i:=dp^.sp^.area.left to dp^.sp^.area.right do begin
				p.i:=i;
				p.j:=j;
				pp:=p_from_i(i_from_c(p),dp^.sp);
				wire:=abs(pp.x);
				sum:=sum+wire*(get_px(dp^.ip,p.j,p.i)-dp^.sp^.average);
				inc(counter);
			end;
		end;
		if counter=0 then correlation:=0
		else correlation:=sum/(counter*amplitude);	
		simplex_error:=-correlation;
	end;
end;

{
	simplex_find_shadow applies the simplex fitter to the correlation between
	an artificial shadow shape and a region of an image.
}
procedure simplex_find_shadow(ip:image_ptr_type;var shadow:shadow_type);

const
	num_parameters=2;
	max_iterations=1000;
	rotation_scale=2000;
	initial_step=20;
		
var
	simplex:simplex_type;
	dp:simplex_data_ptr;
	i:integer;
	
begin 
	if not valid_image_ptr(ip) then exit;
{
	Creat simplex structure and error function data structure.
}
	simplex:=new_simplex(num_parameters);
	new(dp);
	dp^.ip:=ip;
	dp^.sp:=@shadow;
{
	Set up the simplex we use with the simplex fitter.
}
	with simplex,shadow do begin
		vertices[1,1]:=position.x;
		vertices[1,2]:=rotation_scale*rotation;
		construct_size:=initial_step;
		done_counter:=0;
		max_done_counter:=num_parameters;
	end;
	simplex_construct(simplex,simplex_error,dp);	
{
	Apply the simplex fitter, one step at a time until it's done or we
	have exceeded the maximum number of iterations.
}
	i:=0;
	repeat
		inc(i);
		simplex_step(simplex,simplex_error,dp);
	until (simplex.done_counter>=simplex.max_done_counter) or (i>max_iterations);
{
	Extract the fitted value from the simplex array.
}
	with simplex,shadow do begin
		position.x:=vertices[1,1];
		rotation:=vertices[1,2]/rotation_scale;
	end;
{
	Clean up.
}
	dispose(dp);
end;

{
	shadow_locate_accurate uses a steepest ascent algorithm to maximize
	the correlation between shadow in an image and patterns specified
	by the shadow_list. The shadow list must contain the approximate
	location of the features, as it does after shadow_locate_approximate.
}
procedure shadow_locate_accurate(ip:image_ptr_type;
	slp:shadow_list_ptr_type);

const
	line_construction_offset=100;
	
var 
	shadow_num:integer;
	area_half_width:integer;
	shadow_line,reference_line:xy_line_type;
	saved_bounds:ij_rectangle_type;

begin
{
	check the input parameters
}
	if slp=nil then exit;
	slp^.valid:=false;
	if not valid_image_ptr(ip) then exit;
{
	determine the width of the rectangle in which correlation is calculated
}
	area_half_width:=round(one_half*slp^.min_separation_um/slp^.pixel_size_um);
{
	refine the measurement of each shadow location in turn
}		
	for shadow_num:=1 to slp^.num_shadows do begin
		with slp^.shadows[shadow_num] do begin
			with area do begin
				left:=columnrow.i-area_half_width;
				if left<ip^.analysis_bounds.left then 
					left:=ip^.analysis_bounds.left;
				right:=columnrow.i+area_half_width;
				if right>ip^.analysis_bounds.right then
					right:=ip^.analysis_bounds.right;
				top:=ip^.analysis_bounds.top;
				bottom:=ip^.analysis_bounds.bottom;
			end;
			if show_details then display_ccd_rectangle(ip,area,area_color);
		
			randomize_shadow(slp^.shadows[shadow_num]);

			saved_bounds:=ip^.analysis_bounds;
			ip^.analysis_bounds:=area;
			average:=image_average(ip);
			amplitude:=image_amplitude(ip);
			ip^.analysis_bounds:=saved_bounds;

			simplex_find_shadow(ip,slp^.shadows[shadow_num]);
		
			shadow_line_display(ip,slp^.shadows[shadow_num],orange_color);

			with shadow_line do begin
				a:=position;
				b.x:=position.x+rotation*1.0;
				b.y:=position.x+1;
			end;

			with reference_line do begin
			  a.x:=0;
			  a.y:=0;
			  b.x:=1;
			  b.y:=0;
			end;
			position:=xy_line_line_intersection(shadow_line,reference_line);
			position:=xy_scale(position,slp^.pixel_size_um);
		end;
	end;

	slp^.valid:=true;
end; 

end.