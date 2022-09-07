{
Routines to Locate Bright Spots in Images
Copyright (C) 2004-2021 Kevan Hashemi, Brandeis University

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
}

unit spot;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

interface

uses
	utils,images,transforms,image_manip;

const
	spot_missing_string='-1 -1 0 0 0';
	spot_missing_bounds_string='-1 -1 -1 -1';
	spot_decreasing_brightness=1;
	spot_increasing_x=2;
	spot_increasing_y=3;
	spot_decreasing_x=4;
	spot_decreasing_y=5;
	spot_decreasing_max=6;
	spot_decreasing_size=7;
	spot_increasing_xy=8;
	spot_valid_first=100;
	spot_use_centroid=1;
	spot_use_ellipse=2;
	spot_use_vertical_stripe=3;
	spot_use_vertical_shadow=4;
	spot_use_vertical_edge=5;
	spot_use_ellipse_shadow=6;
	max_num_spots=1000;
	
type
	spot_type=record
		valid:boolean;
		color_code:integer;{color code used to mark pixels in overlay}
		x:real;{location in x (um) or orientation (mrad)}
		y:real;{location in y (um) or orientation (mrad)}
		accuracy:real;{um estimate of position accuracy}
		threshold:integer;{intensity threshold for noise and background}
		background:integer;{the background level used to obtain the threshold}
		position_xy:xy_point_type;{position in image coordinates, units pixels}
		position_ij:ij_point_type;{position in ccd coordinates, units pixels}
		bounds:ij_rectangle_type;{boundries enclosing spot}
		num_pixels:integer;{number of pixels above threshold in bounds}
		sum_intensity:integer;{total intensity above background in spot}
		max_intensity:integer;{max intensity in spot}
		min_intensity:integer;{min intensity in spot}
		pixel_size_um:real;{width of pixels in um}
		ellipse:xy_ellipse_type;{ellipse for elliptical fitting}
	end;
	spot_ptr_type=^spot_type;
	spot_list_type=record
		ip:image_ptr_type;{for convenience of analysis}
		num_valid_spots:integer;{spots 1 to num_valid_spots are valid}
		num_requested_spots:integer;{spots requested for by image analysis}
		num_selected_spots:integer;{spots selected and valid}
		grand_sum_intensity:integer;{total intensity of all valid spots}
		grand_num_pixels:integer;{total number of pixels in all valid spots}
		threshold:integer;{intensity threshold for noise and background}
		background:integer;{the background level used to obtain the threshold}
		sort_code:integer;{tells us how the list was sorted}
		num_spots:integer;{their indeces are 1..num_spots}
		spots:array of spot_type;{a dynamic array that includes 1..num_spots}
	end;
	spot_list_ptr_type=^spot_list_type;

procedure spot_centroid(ip:image_ptr_type;var spot:spot_type);
procedure spot_ellipse(ip:image_ptr_type;var spot:spot_type);
procedure spot_vertical_line(ip:image_ptr_type;var spot:spot_type);
procedure spot_list_display_bounds(ip:image_ptr_type;slp:spot_list_ptr_type;
	color:integer);
procedure spot_list_display_vertical_lines(ip:image_ptr_type;slp:spot_list_ptr_type;
	color:integer);
procedure spot_list_display_crosses(ip:image_ptr_type;slp:spot_list_ptr_type;
	color:integer);
procedure spot_list_display_ellipses(ip:image_ptr_type;slp:spot_list_ptr_type;
	color:integer);
function spot_list_find(ip:image_ptr_type;
	num_spots:integer;command:string;pixel_size_um:real):spot_list_ptr_type;
procedure spot_list_merge(ip:image_ptr_type;slp:spot_list_ptr_type;command:string);
procedure spot_list_sort(slp:spot_list_ptr_type;sort_code:integer);
procedure spot_list_tidy(slp:spot_list_ptr_type);
function spot_eccentricity(s:spot_type):real;
function new_spot_list_ptr(num_spots:integer):spot_list_ptr_type;
procedure dispose_spot_list_ptr(slp:spot_list_ptr_type);
function string_from_spot(c:spot_type):string;
function string_from_spot_list(slp:spot_list_ptr_type):string;
function bounds_string_from_spot_list(slp:spot_list_ptr_type):string;
function intensity_string_from_spot_list(slp:spot_list_ptr_type):string;
procedure spot_decode_command_string(ip:image_ptr_type;
	command:string;
	var threshold,background,min_pixels,max_pixels:integer;
	var max_eccentricity:real);


implementation
	
const
	max_num_pixels=1000000; {when collecting pixels for a single spot}
	
{
	new_spot_list_ptr creates a new spot list with "num_spots"
	entries indexed 1..num_spots. When we create the spot list,
	we create space for num_spots+1 elements so we can use indices
	1..num_spots.
}
function new_spot_list_ptr(num_spots:integer):spot_list_ptr_type;

var
	slp:spot_list_ptr_type;
	spot_num:integer;
	
begin
	new_spot_list_ptr:=nil;
	if num_spots<=0 then num_spots:=1;
	new(slp);
	setlength(slp^.spots,num_spots+1);
	slp^.num_spots:=num_spots;
	if slp=nil then exit;
	inc_num_outstanding_ptrs(slp^.num_spots,'new_spot_list_ptr');
	with slp^ do begin
		num_valid_spots:=0;
		num_requested_spots:=0;
		num_selected_spots:=0;
		grand_sum_intensity:=0;
		grand_num_pixels:=0;
		for spot_num:=1 to num_spots do 
			spots[spot_num].valid:=false;
	end;
	new_spot_list_ptr:=slp;
end;

{
	dispose_spot_list_ptr disposes of a spot list.
}
procedure dispose_spot_list_ptr(slp:spot_list_ptr_type);

begin
	if slp=nil then exit;
	dec_num_outstanding_ptrs(slp^.num_spots,'dispose_spot_list_ptr');
	dispose(slp);
end;

{
	spot_centroid subtracts a threshold from the intensity within the spot
	bounds and determines the intensity centroid of the resulting pixels. The
	routine ignores pixels whose intensity is below threshold, but it will use
	any pixel in the bounds rectangle, even if they are not included in the
	pixels of the spot as discovered by the find_pixel routine. The centroid
	position is in image coordinates, with units microns. If the spot consists
	only of pixel (0,0) and the pixels are 10 microns, the spot position will be
	(5,5) in microns. The top left corner of pixel (0,0) is the orgin of image
	coordinates. The spot sensitivity is in microns per threshold count
	calculated at the specified threshold. The routine takes as input a
	spot_type and alters x and y to represent the centroid location. If something
	goes wrong with the calculation, we set x and y to -1.
}
procedure spot_centroid(ip:image_ptr_type;var spot:spot_type);

const
	threshold_step=1;
	
var
	i,j,sum,sum_i,sum_j,step_sum,step_sum_i,step_sum_j:longint;
	count,net_intensity:longint;
	step_position_xy:xy_point_type;
	
begin
	if not spot.valid then exit;
	if ip=nil then exit;
	count:=0;
	sum:=0;sum_i:=0;sum_j:=0;
	step_sum:=0;step_sum_i:=0;step_sum_j:=0;
	with spot,spot.bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				net_intensity:=get_px(ip,j,i)-threshold;
				if net_intensity>0 then begin
					inc(count);
					sum:=sum+net_intensity;
					sum_i:=sum_i+i*net_intensity;
					sum_j:=sum_j+j*net_intensity;
				end;
				net_intensity:=get_px(ip,j,i)-(threshold-threshold_step);
				if net_intensity>0 then begin
					step_sum:=step_sum+net_intensity;
					step_sum_i:=step_sum_i+i*net_intensity;
					step_sum_j:=step_sum_j+j*net_intensity;
				end;
			end;
		end;
		
		if (step_sum>=1) and (sum>=1) then begin
			step_position_xy.x:=(step_sum_i/step_sum)+ccd_origin_x;
			step_position_xy.y:=(step_sum_j/step_sum)+ccd_origin_y;
			position_xy.x:=(sum_i/sum)+ccd_origin_x;
			position_xy.y:=(sum_j/sum)+ccd_origin_y;
			position_ij.i:=round(sum_i/sum);
			position_ij.j:=round(sum_j/sum);
			x:=pixel_size_um*position_xy.x;
			y:=pixel_size_um*position_xy.y;
			accuracy:=xy_length(xy_scale(
				xy_difference(step_position_xy,position_xy),
				pixel_size_um/threshold_step));
		end else begin
			step_position_xy.x:=-1;
			step_position_xy.y:=-1;
			position_xy.x:=-1;
			position_xy.y:=-1;
			position_ij.i:=-1;
			position_ij.j:=-1;
			x:=-1;
			y:=-1;
			accuracy:=0;
		end;

		if math_error(accuracy)
			or math_error(position_xy.x)
			or math_error(position_xy.y) then begin
			x:=-1;
			y:=-1;
		end;
	end;
end;

{
	spot_vertical_line fits a line to the pixels in an image with overlay color
	equal to color_code. It sets spot.x to the intercept of this wire with the
	top edge of the CCD in um, and spot.y to the anti-clockwise rotation of the wire 
	in mrad.
}
procedure spot_vertical_line(ip:image_ptr_type;var spot:spot_type);

const
	max_pixels=10000;
	
var
	i,j,pixel_num:integer;
	gp:xyz_graph_type;
	slope,intercept,residual:real;

begin
	if not spot.valid then exit;
	if ip=nil then exit;
	
	setlength(gp,max_pixels);
	
	pixel_num:=0;
	gp[pixel_num].z:=ignore_remaining_data;
	with spot.bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				if (get_ov(ip,j,i)=spot.color_code) and (pixel_num<max_pixels-1) then begin
					with gp[pixel_num] do begin
						x:=j+ccd_origin_y;
						y:=i+ccd_origin_x;
						z:=get_px(ip,j,i);
					end;
					inc(pixel_num);
					gp[pixel_num].z:=ignore_remaining_data;
				end;
			end;
		end;
	end;

	weighted_straight_line_fit(gp,slope,intercept,residual);

	if math_error(slope) 
			or math_error(intercept) 
			or math_error(residual) then begin
		spot.valid:=false;
		exit;
	end;
	
	with spot do begin
		x:=intercept*pixel_size_um;
		y:=slope*mrad_per_rad;
		if pixel_num>0 then
			accuracy:=residual*pixel_size_um/sqrt(pixel_num)
		else
			accuracy:=0;
	end;
end;

{
	The spot ellipse fitting data is what the simplex error function needs
	to calculate the error of a simplex vertex, aside from the coordinates
	of the vertices themselves.
}
type
	spot_ellipse_fitting_data=record
		ip:image_ptr_type;
		th:real;
	end;
	spot_ellipse_fitting_data_ptr=^spot_ellipse_fitting_data;
		
{
	spot_ellipse_border_match returns true iff point p is on the border of the
	specified ellipse, and is also on the border of the spot defined by
	spot.threshold. the routine takes a pixel coordinate, and ellipse, and a
	pointer that leads to the image and an intensity threshold.
}
function spot_ellipse_border_match(p:ij_point_type;
	e:xy_ellipse_type;
	ep:pointer):boolean;
	
const
	image_border=2;
	
var 
	i_min,i_max,j_min,j_max,i,j:integer;
	s:real;
	q:ij_point_type;
	on_image,on_fit:boolean;
	dp:spot_ellipse_fitting_data_ptr;
	
begin
	dp:=spot_ellipse_fitting_data_ptr(ep);
	on_image:=false;
	on_fit:=false;
	s:=xy_separation(i_from_c(p),e.a)+xy_separation(i_from_c(p),e.b);
	if (s<=e.axis_length) 
		and (s>=e.axis_length-image_border) 
		and (get_px(dp^.ip,p.j,p.i)>dp^.th) then begin
		with dp^.ip^.analysis_bounds do begin
			if p.i>left then i_min:=p.i-1 else i_min:=left;
			if p.i<right then i_max:=p.i+1 else i_max:=right;
			if p.j>top then j_min:=p.j-1 else j_min:=top;
			if p.j<bottom then j_max:=p.j+1 else j_max:=bottom;
		end;
		for i:=i_min to i_max do begin
			for j:=j_min to j_max do begin
				q.i:=i;
				q.j:=j;
				if (xy_separation(i_from_c(q),e.a)
					+xy_separation(i_from_c(q),e.b))
					>e.axis_length then
					on_fit:=true;
				if (get_px(dp^.ip,q.j,q.i)<=dp^.th) then
					on_image:=true;
			end;
		end;
	end;
	spot_ellipse_border_match:=on_fit and on_image;
end;

{
	The spot_ellipse_error function we provide for the simplex fitter counts the
	number of pixels in the image analysis bounds that are on the border of the
	spot in the image and also on the border of the ellipse defined by vertex
	"v". The error is the negative of the number of border-coincident pixels. We
	took the idea for border-coincidence from "Robust Ellipse Detection by
	Fitting Randomly Selected Edge Patches" by Watcharin Kaewapichai, and Pakorn
	Kaewtrakulpong. We don't use their method, but we take from it the one idea
	of matching edge pixels to determine fitness of the ellipse.
}
function spot_ellipse_error(v:simplex_vertex_type;ep:pointer):real;
var
	fitness:real;
	p:ij_point_type;
	e:xy_ellipse_type;
	i,j:integer;
	dp:spot_ellipse_fitting_data_ptr;
begin
	dp:=spot_ellipse_fitting_data_ptr(ep);
	fitness:=0;
	with e do begin
		a.x:=v[1];
		a.y:=v[2];
		b.x:=v[3];
		b.y:=v[4];
		axis_length:=v[5];
	end;
	for i:=dp^.ip^.analysis_bounds.left to dp^.ip^.analysis_bounds.right do 
		for j:=dp^.ip^.analysis_bounds.top to dp^.ip^.analysis_bounds.bottom do begin
			p.i:=i;
			p.j:=j;
			if spot_ellipse_border_match(p,e,ep) then fitness:=fitness+1;
		end;
	spot_ellipse_error:=-fitness;
end;

{
	spot_ellipse fits an ellipse to the border of a spot, and returns
	the coordinates of the center of the ellipse. It fills in the fields
	of the ellipse record in the spot.
}
procedure spot_ellipse(ip:image_ptr_type;var spot:spot_type);

const
	num_parameters=5;
	max_iterations=40;
	bounds_extra=5;
	report_progress=false;
	
var
	simplex:simplex_type;
	saved_bounds:ij_rectangle_type;
	i:integer;
	dp:spot_ellipse_fitting_data_ptr;
	
begin
	if not spot.valid then exit;
	if ip=nil then exit;
{
	Create simplex data structure and the small record we use to present the
	image pointer and intensity threshold to the simplex error function.
}
	simplex:=new_simplex(num_parameters);
	new(dp);
	dp^.ip:=ip;
	dp^.th:=spot.threshold;
{
	We generate an ellipse that fits the spot's rectangular boundaries.
}
	spot.ellipse:=xy_rectangle_ellipse(i_from_c_rectangle(spot.bounds));
{
	Set up the simplex we use with the simplex fitter. We assign the initial
	ellipse fields to the first vertex of the simplex, and construct the 
	simplex from there.
}
	with simplex,spot.ellipse do begin
		vertices[1,1]:=a.x;
		vertices[1,2]:=a.y;
		vertices[1,3]:=b.x;
		vertices[1,4]:=b.y;
		vertices[1,5]:=axis_length;
		construct_size:=10;
		done_counter:=0;
		max_done_counter:=2;
	end;
	simplex_construct(simplex,spot_ellipse_error,dp);	
{
	Reduce the image's analysis boundaries to the small boundary around the
	spot, but add bounds_extra pixels on all sides to help the fitter.
}
	saved_bounds:=ip^.analysis_bounds;
	ip^.analysis_bounds:=spot.bounds;
	with ip^.analysis_bounds do begin
		left:=left-bounds_extra;
		if left<saved_bounds.left then left:=saved_bounds.left;
		right:=right+bounds_extra;
		if right>saved_bounds.right then right:=saved_bounds.right;
		top:=top-bounds_extra;
		if top<saved_bounds.top then top:=saved_bounds.top;
		bottom:=bottom+bounds_extra;
		if bottom>saved_bounds.bottom then bottom:=saved_bounds.bottom;
	end;
{
	Apply the simplex fitter, one step at a time until it's done or we
	have exceeded the maximum number of iterations.
}
	i:=0;
	repeat
		simplex_step(simplex,spot_ellipse_error,dp);
		inc(i);
		if report_progress then with simplex,spot do begin
			writestr(debug_string,i:1,' ',vertices[1,1]:0:1,' ',vertices[1,2]:0:1,' ',
				vertices[1,3]:0:1,' ',vertices[1,4]:0:1,' ',vertices[1,5]:0:1,' ',
				spot_ellipse_error(vertices[1],dp):0:1);
			gui_writeln(debug_string);
		end;	
	until (simplex.done_counter>=simplex.max_done_counter) or (i>max_iterations);
{
	Restore the image bounds.
}
	ip^.analysis_bounds:=saved_bounds;
{
	Fill the spot ellipse with the fitted values, determine the ellipse center and 
	adjust the spot position accordingly. We estimate the fitting error by dividing
	the pixel size by the square root of the number of border pixels.
}
	with simplex,spot do begin
		ellipse.a.x:=vertices[1,1];
		ellipse.a.y:=vertices[1,2];
		ellipse.b.x:=vertices[1,3];
		ellipse.b.y:=vertices[1,4];
		ellipse.axis_length:=vertices[1,5];
		position_xy:=xy_scale(xy_sum(ellipse.a,ellipse.b),one_half);
		position_ij:=c_from_i(position_xy);
		x:=position_xy.x*pixel_size_um;
		y:=position_xy.y*pixel_size_um;
		accuracy:=pixel_size_um/sqrt(abs(spot_ellipse_error(vertices[1],dp)));
	end;	
{
	Dispose of pointers.s
}
	dispose(dp);
end;

{
	spot_eccentricity returns the elliptic eccentricity of a spot, which is its
	maximum width divided by its minimum width.
}
function spot_eccentricity(s:spot_type):real;

var
	e:real;
	
begin
	if not s.valid then begin
		spot_eccentricity:=0;
		exit;
	end;
	
	with s do begin
		with bounds do begin 
			e:=(right-left)/(bottom-top);
			if e<1 then e:=1/e;
			e:=e*((right-left)*(bottom-top)*pi/4)/num_pixels;
		end;
	end;
	spot_eccentricity:=e;
end;

{
	string_from_spot returns a string expressing the
	most prominent elements of a spot record.
}
function string_from_spot(c:spot_type):string;

var  
	s:string;

begin
	if c.valid then
		with c,c.bounds do
			writestr(s,x:4:2,' ',y:4:2,' ',
				num_pixels:1,' ',max_intensity:1,' ',
				accuracy:5:3,' ',threshold:1)
	else 
		writestr(s,spot_missing_string,' ',c.threshold:1);
	string_from_spot:=s;
end;

{
	string_from_spot_list returns a string made by concatinating the
	string_from_spots for all the spots in the list.
}
function string_from_spot_list(slp:spot_list_ptr_type):string;

var
	spot_num:integer;
	s:string;
	
begin
	string_from_spot_list:='';
	if slp=nil then exit;
	s:='';
	for spot_num:=1 to slp^.num_requested_spots do begin 
		writestr(s,s,string_from_spot(slp^.spots[spot_num]));
		if spot_num<slp^.num_requested_spots then writestr(s,s,' ');
	end;
	string_from_spot_list:=s;
end;

{
	bounds_string_from_spot_list returns a string made by the bounds of
	all spots in a list. The bounds are given as left, right, top, bottom of 
	each rectangle.
}
function bounds_string_from_spot_list(slp:spot_list_ptr_type):string;

var
	spot_num:integer;
	s:string;
	
begin
	bounds_string_from_spot_list:='';
	if slp=nil then exit;
	s:='';
	for spot_num:=1 to slp^.num_requested_spots do begin
		if slp^.spots[spot_num].valid then
			with slp^.spots[spot_num].bounds do
				writestr(s,s,left:1,' ',top:1,' ',right:1,' ',bottom:1)
		else
			writestr(s,s,spot_missing_bounds_string);
		if spot_num<slp^.num_spots then writestr(s,s,' ');
	end;
	bounds_string_from_spot_list:=s;
end;

{
	intensity_string_from_spot_list returns a string containing the total intensity
	of each spot in a list, which is the sum of the pixel intensities above background.
	The sum intensity in the spot record is the sum of the net intensities of the spot
	pixels, which is their intensities above threshold. So we add to the sum intensity
	the product of the number of pixels and the difference between the threshold and
	the background.
}
function intensity_string_from_spot_list(slp:spot_list_ptr_type):string;

var
	spot_num:integer;
	s:string;
	
begin
	intensity_string_from_spot_list:='';
	if slp=nil then exit;
	s:='';
	for spot_num:=1 to slp^.num_requested_spots do begin
		if slp^.spots[spot_num].valid then
			with slp^.spots[spot_num] do
				writestr(s,s,sum_intensity:1)
		else
			writestr(s,s,-1);
		if spot_num<slp^.num_spots then writestr(s,s,' ');
	end;
	intensity_string_from_spot_list:=s;
end;

{
	spot_list_sort sorts a spot list in order of decreasing intensity,
	increasing x-coordinate, increasing y-coordinate, increasing x-y coordinate,
	decreasing x-coordinate or decreasing y-coordinate, depending upon
	sort_code. The routine operates upon the first num_selected_spots entries in
	the spot list, ignoring the rest of the spots, and operates upon spots
	whether they are valid or not. The increasing x-y coordinate option will
	sort an x-y grid of spots from top-left to bottom-right in the image. For
	other distributions of spots, its sorting will be less obvious. The default
	sort, which we can specify with spot_valid_first, brings all valid spots to
	the beginning of the list, for use when we have operated upon the list,
	merging spots or eliminating spots. We begin with the ordering function we
	will use to drive the sort. Returns true if element a should be placed after
	element b.
}
function sls_after(a,b:integer;ptr:pointer):boolean;
const grid_threshold=0.3;
var after:boolean;x_diff,y_diff:real;slp:spot_list_ptr_type;
begin
	slp:=spot_list_ptr_type(ptr);
	with slp^ do begin
		case sort_code of
			spot_decreasing_brightness: 
				after:= spots[a].sum_intensity < spots[b].sum_intensity;
			spot_increasing_x: after:= spots[a].x > spots[b].x;
			spot_increasing_y: after:= spots[a].y > spots[b].y;
			spot_decreasing_x: after:= spots[a].x < spots[b].x;
			spot_decreasing_y: after:= spots[a].y < spots[b].y;
			spot_decreasing_max: 
				after:=spots[a].max_intensity < spots[b].max_intensity;
			spot_decreasing_size: after:= spots[a].num_pixels < spots[b].num_pixels;
			spot_increasing_xy: begin
				x_diff := spots[a].x - spots[b].x;
				y_diff := spots[a].y - spots[b].y;
				if (y_diff > 0) and (abs(y_diff) > abs(x_diff*grid_threshold)) then after:=true
				else if (x_diff > 0) and (abs(y_diff) < abs(x_diff*grid_threshold)) then after:=true
				else if (y_diff < 0) and (abs(y_diff) > abs(x_diff*grid_threshold)) then after:=false
				else if (x_diff < 0) and (abs(y_diff) < abs(x_diff*grid_threshold)) then after:=false
				else after:=false;
			end;
			otherwise begin
				after:= spots[b].valid and (not spots[a].valid);
			end;
		end;
		if (not spots[a].valid) and (spots[b].valid) then after:=true;
	end;
	sls_after:=after;
end;
{
	The swap routine that rearranges list entries.
}
procedure sls_swap(a,b:integer;ptr:pointer);
var temp_spot:spot_type;slp:spot_list_ptr_type;
begin
	slp:=spot_list_ptr_type(ptr);
	with slp^ do begin
		temp_spot:=spots[a];
		spots[a]:=spots[b];
		spots[b]:=temp_spot;
	end;
end;
{
	Call the quick-sort routine using the swap and after functions.
}
procedure spot_list_sort(slp:spot_list_ptr_type;sort_code:integer);
begin
	if slp=nil then exit;
	slp^.sort_code:=sort_code;
	quick_sort(1,slp^.num_selected_spots,sls_swap,sls_after,pointer(slp));
end;

{
	spot_list_tidy brings all valid spots to the front of the list, counts them and
	sets num_valid_spots, sorts the valid spots in order of decreasing brightness,
	and then sets num_selected_spots to match num_valid_spots and num_requested_spots.
}
procedure spot_list_tidy(slp:spot_list_ptr_type);
var
	spot_num:integer;
begin
	if slp=nil then exit;
	slp^.num_selected_spots:=slp^.num_spots;
	spot_list_sort(slp,spot_valid_first);
	spot_num:=1;
	while (spot_num<=slp^.num_spots) and slp^.spots[spot_num].valid do 
		inc(spot_num);
	slp^.num_valid_spots:=spot_num-1;
	slp^.num_selected_spots:=slp^.num_valid_spots;
	spot_list_sort(slp,spot_decreasing_brightness);
	if slp^.num_valid_spots>slp^.num_requested_spots then
		slp^.num_selected_spots:=slp^.num_requested_spots
	else
		slp^.num_selected_spots:=slp^.num_valid_spots;
end;

{
	find_pixels takes as input a spot list pointer and the coordinates of
	a pixel in an image. It finds all pixels above in the spot that contains
	the specified pixel, sets their overlay color to the color code of the 
	last valid spot in the spot list, and adjusts the bounds of this same spot
	to accommodate all pixels in the spot.
}
procedure find_pixels(slp:spot_list_ptr_type;j,i:integer);

function valid_pixel(j,i:integer):boolean;
begin
	valid_pixel:=false;
	with slp^ do begin
		with ip^,ip^.analysis_bounds,spots[num_valid_spots] do begin
			if (i<=right) and (i>=left) and (j>=top) and (j<=bottom) then begin
				if (get_px(ip,j,i)>threshold) and (get_ov(ip,j,i)=clear_color) then begin
					valid_pixel:=true;
				end;
			end;
		end;
	end;	
end;

const
	top_center=1;
	top_right=2;
	right_center=3;
	bottom_right=4;
	bottom_center=5;
	bottom_left=6;
	left_center=7;
	top_left=8;
	origin_pixel=9;

var 
	no_more_pixels:boolean;
	jj,ii:integer;
	counter:integer;

begin
	ii:=1;
	jj:=1;
	if slp=nil then exit;
	with slp^ do begin
		with ip^,ip^.analysis_bounds,spots[num_valid_spots] do begin
			set_ov(ip,j,i,origin_pixel);
			no_more_pixels:=false;
			counter:=0;
			repeat
				inc(counter);
				if counter>max_num_pixels then exit;
				if valid_pixel(j-1,i) then begin 
					set_ov(ip,j-1,i,top_center);
					j:=j-1;
				end else if valid_pixel(j-1,i+1) then begin
					set_ov(ip,j-1,i+1,top_right);
					j:=j-1;
					i:=i+1;
				end else if valid_pixel(j,i+1) then begin
					set_ov(ip,j,i+1,right_center);
					i:=i+1;
				end else if valid_pixel(j+1,i+1) then begin
					set_ov(ip,j+1,i+1,bottom_right);
					j:=j+1;
					i:=i+1;
				end else if valid_pixel(j+1,i) then begin
					set_ov(ip,j+1,i,bottom_center);
					j:=j+1;
				end else if valid_pixel(j+1,i-1) then begin
					set_ov(ip,j+1,i-1,bottom_left);
					j:=j+1;
					i:=i-1;
				end else if valid_pixel(j,i-1) then begin
					set_ov(ip,j,i-1,left_center);
					i:=i-1;
				end else if valid_pixel(j-1,i-1) then begin
					set_ov(ip,j-1,i-1,top_left);
					j:=j-1;
					i:=i-1;
				end else begin
					case get_ov(ip,j,i) of
						top_center:begin jj:=j+1; ii:=i; end;
						top_right:begin jj:=j+1; ii:=i-1; end;
						right_center:begin jj:=j; ii:=i-1; end;
						bottom_right:begin jj:=j-1; ii:=i-1; end;
						bottom_center:begin jj:=j-1; ii:=i; end;
						bottom_left:begin jj:=j-1; ii:=i+1; end;
						left_center:begin jj:=j; ii:=i+1; end;
						top_left:begin jj:=j+1; ii:=i+1; end;
						origin_pixel:begin
							no_more_pixels:=true;
							jj:=j; 
							ii:=i;
						end;
					end;
					set_ov(ip,j,i,color_code);
					inc(num_pixels);
					sum_intensity:=sum_intensity+get_px(ip,j,i)-background;
					if get_px(ip,j,i)>max_intensity then 
						max_intensity:=get_px(ip,j,i);
					if get_px(ip,j,i)<min_intensity then 
						min_intensity:=get_px(ip,j,i);
					if j>bounds.bottom then bounds.bottom:=j;
					if j<bounds.top then bounds.top:=j;
					if i>bounds.right then bounds.right:=i;
					if i<bounds.left then bounds.left:=i;
					j:=jj;
					i:=ii;
				end;
			until no_more_pixels;
		end;
	end;
end;

{
	spot_decode_command_string takes a string like "10 & 3 > 1.4" and
	determines, for the specified image, an intensity threshold for selecting
	bright pixels in the image, minimum and maximum values for the number of
	pixels in a spot, and a maximu, value for eccentricity.

	The first parameter in the command string must be an integer specifying the
	threshold intensity. The integer may be followed by of the symbols *, %, #,
	$, or &. Each of these symbols give a different meaning to the threshold
	value. If there is no symbol, we default to the function of the * symbol, in
	which the threshold integer is the threshoild intensity with no
	modification. But the % symbol means that the threshold is a percentage of
	the way from the minimum to maximum intensities within the analysis
	boundaries of the image. Thus, if the minimum intensity is 40, the maximum
	is 140, and the command string begins with "20 %" the threshold intensity
	will be 60. The # symbol's behavior is similar, but the average intensity
	takes the place of the miniumum. The $ symbol says that the threshold is the
	average intensity plus the threshold integer. If the average is 50 and the
	command starts with "10 $", the threshold will be 60. The "&" symbol says
	the threshold is the median intensity plus the threshold integer.

	Following the threshold definition is a minimum or maximum number of pixels
	the spot must contain to be added to the spot list. If the integer is
	followed by a ">" character, it specifies a minimum number of pixels. If
	followed by a "<" the integer is a maximum number. The default is ">". The
	third integer gives the maximum eccentricity of the spot.
}
procedure spot_decode_command_string(ip:image_ptr_type;
	command:string;
	var threshold,background,min_pixels,max_pixels:integer;
	var max_eccentricity:real);

const
	percent_unit=100;
	large_number=10000000;

var
	word:string;
	

begin
{
	Decode the command string. First we read the threshold, then we look for a
	valid threshold qualifier.
}
	threshold:=read_integer(command);
	word:=read_word(command);
	if word='%' then begin
		background:=round(image_minimum(ip));
		threshold:=
			round((1-threshold/percent_unit)*background
			+threshold/percent_unit*image_maximum(ip));
	end else if word='#' then begin
		background:=round(image_average(ip));
		threshold:=
			round((1-threshold/percent_unit)*background
			+threshold/percent_unit*image_maximum(ip));
	end else if word='*' then begin
		background:=0;
		threshold:=threshold-background;
	end else if word='$' then begin
		background:=round(image_average(ip));
		threshold:=background+threshold;
	end else if word='&' then begin
		background:=round(image_median(ip));
		threshold:=background+threshold;
	end else command:=word+' '+command;
{
	Determine minimum and maximum number of pixels in valid spot.
}
	min_pixels:=read_integer(command);
	if min_pixels<1 then min_pixels:=1;
	word:=read_word(command);
	if word='<' then begin
		max_pixels:=min_pixels;
		min_pixels:=1;
	end else if word='>' then 
		max_pixels:=large_number
	else begin
		max_pixels:=large_number;
		command:=word+' '+command;
	end;
{
	Determine maximum eccentricity of a valid spot.
}
	max_eccentricity:=read_real(command);
	if max_eccentricity<1 then max_eccentricity:=0;
end;


{
	spot_list_find finds multiple spots in an image and records them in a
	spot_list_type, which the calling process must dispose of itself. The
	routine uses the image overlay to mark the spots its finds. It clears the
	overlay at the start of execution. A spot is any connected set of pixels
	with intensity above the threshold specified in the command string.

	We decode the command string with the spot_decode_command_string procedure,
	see comments above. The purpose of the command string is to define a
	background intensity, a threshold intensity, limits for the number of pixels
	in the spot, and a limit for the eccentricity of the spot. In the image
	overlay, the color black (0) is reserved for pixels below threshold. The
	color white (255) is reserved for pixels above threshold that are not part
	of a valid spot. The spots in the spot list each have their own boundaries,
	each boundary being the minimum ij_rectangle_type that encloses the spot, as
	assigned by the find_pixels routine. The routine starts by finding as many
	valid spots as it can. Once it finds max_num_spots of them, it stops. If
	there are more spots in the image, these will not be found.

	If a spot contains too many or too few pixels, or if it is is too eccentric,
	spot_list_find changes the color of its pixels to white and does not add the
	spot to the spot list. The routine calculates the brightness of each spot by
	adding the intensity minus background of all the pixels it contains. The
	routine sorts all qualifying spots in order of descending brightness and
	eliminates all but the num_spots brightest spots. If num_spots is negative,
	the routine will use all valid spots, and not others. The routine leaves its
	markings in the overlay afterwards, which is how we can use the overlay to
	see which pixels it has used.
	
	At the end of spot_list_find, the fields x, y, position_xy, and position_ij
	remain at their default values. Use a routine like spot_centroid,
	spot_vertical_line, or spot_ellipse to obtain values for these fields.
}
function spot_list_find(ip:image_ptr_type;
	num_spots:integer;
	command:string;
	pixel_size_um:real):spot_list_ptr_type;
	
var 
	min_pixels,max_pixels,threshold,background:integer;
	i,j,ii,jj:integer;
	spot_num:integer;
	slp:spot_list_ptr_type;
	max_eccentricity:real;
	
begin
{
	Set spot_list_find to nil in case we abort.
}
	spot_list_find:=nil;
	if ip=nil then exit;
	if num_spots>max_num_spots then begin
		report_error('num_spots>max_num_spots in spot_list_find.');
		exit;
	end;
{
	Decode the command string to obtain the threshold for spot detection, the background
	for spot intensity, the minimum and maximum number of pixels a spot can contain and
	be counted, and the maximum eccentricity.
}
	spot_decode_command_string(ip,command,
		threshold,background,
		min_pixels,max_pixels,
		max_eccentricity);
{
	It's okay to pass empty strings to the decode procedure, but if we passed a
	non-numeric, non-empty string, these routines will have recorded and error,
	and we should now quit with this error before we run into trouble.
}
	if error_string<>'' then exit;
{
	Assign a new spot list to hold our maximum number of 
	spots.
}
	slp:=new_spot_list_ptr(max_num_spots);
	if slp=nil then begin
		report_error('Failed to allocate for slp in spot_list_find.');
		exit;
	end;
	slp^.ip:=ip;
	slp^.threshold:=threshold;
	slp^.background:=background;
	for spot_num:=1 to max_num_spots do begin
		slp^.spots[spot_num].threshold:=threshold;
		slp^.spots[spot_num].background:=background;
	end;
{
	Clear the image overlay so we can use it to mark pixels as belonging to
	the spots.
}	
	clear_overlay(ip);
{
	Proceed through the entire image, calling find_pixels each time we find a pixel
	unmarked in the overlay whose intensity is above the threshold. Each time we call
	find_pixels we assume the routine gathers all the light spot's pixels together.
}
	with ip^,ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				if (get_px(ip,j,i)>threshold) 
						and (get_ov(ip,j,i)=clear_color)
						and (slp^.num_valid_spots<slp^.num_spots) then begin
					with slp^ do begin
						inc(num_valid_spots);
						spots[num_valid_spots].pixel_size_um:=pixel_size_um;
						with spots[num_valid_spots] do begin
							color_code:=overlay_color_from_integer(num_valid_spots);
							bounds.left:=ip^.analysis_bounds.right;
							bounds.right:=ip^.analysis_bounds.left;
							bounds.top:=ip^.analysis_bounds.bottom;
							bounds.bottom:=ip^.analysis_bounds.top;
							num_pixels:=0;
							sum_intensity:=0;
							max_intensity:=black_intensity;
							min_intensity:=white_intensity;
						end;
						find_pixels(slp,j,i);
						with spots[num_valid_spots] do begin
							valid:=true;
							if (num_pixels<min_pixels) or (num_pixels>max_pixels) then 
								valid:=false;
							if (max_eccentricity<>0) then
								if (spot_eccentricity(spots[num_valid_spots])>max_eccentricity) then 
									valid:=false;
							if (not valid) and (num_pixels>0) then begin
								for jj:=bounds.top to bounds.bottom do
									for ii:=bounds.left to bounds.right do
										if get_ov(ip,jj,ii)=color_code then
											set_ov(ip,jj,ii,white_color);
							end;
						end;
						if spots[num_valid_spots].valid then begin
							grand_sum_intensity:=grand_sum_intensity+spots[num_valid_spots].sum_intensity;
							grand_num_pixels:=grand_num_pixels+spots[num_valid_spots].num_pixels;
						end else 
							dec(num_valid_spots);
					end;
				end;
			end;
		end;
	end;
{
	Sort the spots in order of decreasing intensity. We specify that all valid
	spots are selected for this sort. 
}
	slp^.num_selected_spots:=slp^.num_valid_spots;
	spot_list_sort(slp,spot_decreasing_brightness);
{
	Record the number of spots requested in the spot list. If num_spots is negative, this 
	means the user has requested all valid spots. Otherwise, num_spots gives the number 
	of spots requested directly.
}
	if num_spots<0 then 
		slp^.num_requested_spots:=slp^.num_valid_spots
	else
		slp^.num_requested_spots:=num_spots;
{
	Record the number of spots selected for display, which will be
	the number requested if there are enough valid spots, or the
	number of valid spots if there are fewer than requested.
}
	if slp^.num_requested_spots<slp^.num_valid_spots then
		slp^.num_selected_spots:=slp^.num_requested_spots
	else
		slp^.num_selected_spots:=slp^.num_valid_spots;
{
	Return the list. The list may have fewer than num_spots valid entries.
	The routine that uses the spot list must check the valid flag on each 
	spot before using it.
}
	spot_list_find:=slp;
end;

{
	spot_list_merge combines separate spots that may be part of the same
	feature. For example, suppose we are looking at a near-vertical stripe in an
	image. When the stripe is bright enough, it forms one connected set of
	pixels, and therefore one spot. But when the stripe is dim, it may fragment
	into separate spots. We call spot_list_merge with the "vertical" command,
	and we merge these separates spots into one spot whose pixels are not
	connected, but which represent the same image feature.

	The merge routine compares all valid spots to all other valid spots, looking
	for possible merges.

	When the routine merges two spots, it changes the color of all the pixels in
	the overlay corresponding to the second spot so that they are the same as
	the overlay color of the first spot. The routine expands the bounds
	rectangle to include all the pixels.

	NOTE: At the moment, only vertical merging is supported.
}
procedure spot_list_merge(ip:image_ptr_type;slp:spot_list_ptr_type;command:string);

var
	a,b,i,j:integer;
	la,lb:xy_line_type;
	
begin
	if slp=nil then exit;
	if ip=nil then exit;
	
	if command<>'vertical' then begin
		report_error('Only vertical merging is supported in spot_list_merge');
		exit;
	end;
	
	with slp^ do begin
		for a:=1 to num_valid_spots do
			if spots[a].valid then
				spot_vertical_line(ip,spots[a]);
	
		for a:=1 to num_valid_spots-1 do begin
			if spots[a].valid then begin
				with spots[a] do begin
					la.a.x:=x/pixel_size_um+bounds.top*y/mrad_per_rad;
					la.a.y:=bounds.top;
					la.b.x:=x/pixel_size_um+bounds.bottom*y/mrad_per_rad;
					la.b.y:=bounds.bottom;
				end;	
				for b:=a+1 to num_valid_spots do begin
					if spots[b].valid then begin
						with spots[b] do begin
							lb.a.x:=x/pixel_size_um+bounds.top*y/mrad_per_rad;
							lb.a.y:=bounds.top;
							lb.b.x:=x/pixel_size_um+bounds.bottom*y/mrad_per_rad;
							lb.b.y:=bounds.bottom;
						end;
						if ij_line_crosses_rectangle(
								c_from_i_line(la),spots[b].bounds) 
							and ij_line_crosses_rectangle(
								c_from_i_line(lb),spots[a].bounds) then begin
							with spots[b].bounds do begin
								for j:=top to bottom do begin
									for i:=left to right do begin
										if get_ov(ip,j,i)=spots[b].color_code then begin
											set_ov(ip,j,i,spots[a].color_code);
										end;
									end;
								end;
							end;
							spots[a].bounds:=
								ij_combine_rectangles(spots[a].bounds,spots[b].bounds);
							spots[a].num_pixels:=
								spots[a].num_pixels+spots[b].num_pixels;
							spots[a].sum_intensity:=
								spots[a].sum_intensity+spots[b].sum_intensity;
							if spots[a].max_intensity<spots[b].max_intensity then
								spots[a].max_intensity:=spots[b].max_intensity;
							if spots[a].min_intensity>spots[b].min_intensity then
								spots[a].min_intensity:=spots[b].min_intensity;
							spots[b].valid:=false;
						end;
					end;
				end;
			end;
		end;
	end;
	spot_list_tidy(slp);
end;

{
	spot_list_display_bounds displays the bounds of a list of spots. If the bounds
	are too small to see, we increase them. If they reach the edge of the analysis
	boundaries, we display them one pixel inbounds so they will be visible.
}
procedure spot_list_display_bounds(ip:image_ptr_type;slp:spot_list_ptr_type;
	color:integer);

const
	extent=5;
	min_width=2*extent;
	
var
	spot_num,i,j:integer;
	r:ij_rectangle_type;
	
begin
	if slp=nil then exit;
	for spot_num:=1 to slp^.num_selected_spots do begin
		r:=slp^.spots[spot_num].bounds;
		if r.right>=ip^.analysis_bounds.right then r.right:=ip^.analysis_bounds.right-1;
		if r.left<=ip^.analysis_bounds.left then r.left:=ip^.analysis_bounds.left+1;
		if r.top<=ip^.analysis_bounds.top then r.top:=ip^.analysis_bounds.top+1;
		if r.bottom>=ip^.analysis_bounds.bottom then r.bottom:=ip^.analysis_bounds.bottom-1;
		if abs(r.right-r.left)<min_width then begin
			i:=round(one_half*(r.right+r.left));
			r.right:=i+extent;
			r.left:=i-extent;
		end;
		if abs(r.bottom-r.top)<min_width then begin
			j:=round(one_half*(r.bottom+r.top));
			r.bottom:=j+extent;
			r.top:=j-extent;
		end;
		display_ccd_rectangle(ip,r,color);
	end;
end;

{
	spot_list_display_crosses displays crosses on a list of spots.
}
procedure spot_list_display_crosses(ip:image_ptr_type;slp:spot_list_ptr_type;
	color:integer);

var
	spot_num:integer;
	
begin
	if slp=nil then exit;
	for spot_num:=1 to slp^.num_selected_spots do begin
		display_ccd_cross(ip,slp^.spots[spot_num].position_ij,color);
	end;
end;

{
	spot_list_display_vertical_lines displays vertical lines.
}
procedure spot_list_display_vertical_lines(ip:image_ptr_type;slp:spot_list_ptr_type;
	color:integer);

var
	spot_num:integer;
	i_line:xy_line_type;
	
begin
	if slp=nil then exit;
	for spot_num:=1 to slp^.num_selected_spots do begin
		with slp^.spots[spot_num] do begin
			i_line.a.x:=x/pixel_size_um+bounds.top*y/mrad_per_rad;
			i_line.a.y:=bounds.top;
			i_line.b.x:=x/pixel_size_um+bounds.bottom*y/mrad_per_rad;
			i_line.b.y:=bounds.bottom;
			display_ccd_line(ip,c_from_i_line(i_line),color);
		end;
	end;
end;

{
	spot_list_display_ellipses displays ellipses in the bounds of a list of
	spots.
}
procedure spot_list_display_ellipses(ip:image_ptr_type;slp:spot_list_ptr_type;
	color:integer);

var
	spot_num:integer;
	saved_bounds:ij_rectangle_type;
	
begin
	if slp=nil then exit;
	saved_bounds:=ip^.analysis_bounds;
	for spot_num:=1 to slp^.num_selected_spots do begin
		with slp^.spots[spot_num] do begin
			ip^.analysis_bounds:=bounds;
			display_ccd_ellipse(ip,c_from_i_ellipse(ellipse),color);
		end;
	end;
	ip^.analysis_bounds:=saved_bounds;
end;	

{
	initialization does nothing.
}
initialization 

{
	finalization does nothing.
}
finalization 

end.