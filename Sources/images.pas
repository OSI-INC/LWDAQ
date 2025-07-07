{
Routines for Image Handling
Copyright (C) 2004-2021 Kevan Hashemi, Brandeis University
Copyright (C) 2022-2024 Kevan Hashemi, Open Source Instruments Inc.

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
unit images;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

interface

uses
	utils;
	
const {for names}
	default_image_name='lwdaq_image_';
	scratch_image_name='lwdaq_scratch';

const {for eight-bit intensity values}
	max_intensity=255;
	min_intensity=0;
	mid_intensity=128;
	low_intensity=5;
	black_intensity=min_intensity;
	white_intensity=max_intensity;

const {overlay colors}
	red_mask=$E0;
	green_mask=$1C;
	blue_mask=$03;
	
	black_color=0; {black}
	clear_color=254; {transparent, so you see image beneath}
	white_color=255; {white}

	dark_brown_color=96;
	dark_red_color=160;
	red_color=224;
	vdark_green_color=8;
	dark_green_color=20;
	green_color=28;
	vdark_blue_color=1;
	dark_blue_color=2;
	blue_color=3;
	sky_blue_color=147;
	orange_color=236;
	yellow_color=216;
	salmon_color=242;
	magenta_color=227;
	brown_color=140;
	dark_gray_color=73;
	gray_color=146;
	light_gray_color=182;

const {for four-byte screen pixels}
	opaque_alpha=max_byte;

const {for array sizes}
	max_num_image_pixels=10000000;
	master_image_list_length=1000;

const {for intensification}
	no_intensify=0;
	mild_intensify=1;
	strong_intensify=2;
	exact_intensify=3;

const {for image files}
	image_header_len=12;

type {for image storage}
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
	
type {for drawing space}
	drawing_space_pixel_type=packed record
		red,green,blue,alpha:byte;
	end;
	color_table_type=array of drawing_space_pixel_type;

type {for image headers}
	image_header_type=packed record
		j_max,i_max,top,left,bottom,right:smallint;
		results:array[0..short_string_length] of char;
	end;
	image_header_ptr_type=^image_header_type;

var {for global use}
	drawing_space:packed array of drawing_space_pixel_type;
	image_counter:cardinal=0;
	gamma_correction:real=1;
	rggb_red_scale:real=1;
	rggb_blue_scale:real=1;
	blank_image:image_type;
	master_image_list:array [0..master_image_list_length-1] of image_type;

{
	Image creation, drawing, and examination.
}
function get_px(ip:image_ptr_type;j,i:integer):intensity_pixel_type;
procedure set_px(ip:image_ptr_type;j,i:integer;value:intensity_pixel_type);
function get_ov(ip:image_ptr_type;j,i:integer):integer;
procedure set_ov(ip:image_ptr_type;j,i:integer;value:integer);
function image_data_byte(ip:image_ptr_type;n:integer):integer;
procedure write_image_data_byte(ip:image_ptr_type;b:byte;n:integer);
procedure paint_image(ip:image_ptr_type;shade:intensity_pixel_type);
procedure clear_image(ip:image_ptr_type);
procedure paint_overlay(ip:image_ptr_type;color:integer);
procedure fill_overlay(ip:image_ptr_type);
procedure clear_overlay(ip:image_ptr_type);
procedure dispose_image(ip:image_ptr_type);
procedure dispose_named_images(key:string);
procedure draw_image(ip:image_ptr_type);
procedure draw_rggb_image(ip:image_ptr_type);
procedure draw_gbrg_image(ip:image_ptr_type);
procedure draw_image_xy_line(ip:image_ptr_type;line:xy_line_type;shade:integer);
procedure draw_image_line(ip:image_ptr_type;line:ij_line_type;shade:integer);
procedure draw_overlay_xy_line(ip:image_ptr_type;line:xy_line_type;color:integer);
procedure draw_overlay_line(ip:image_ptr_type;line:ij_line_type;color:integer);
procedure draw_overlay_pixel(ip:image_ptr_type;pixel:ij_point_type;color:integer);
procedure draw_overlay_rectangle(ip:image_ptr_type;rect:ij_rectangle_type;
	color:integer);
procedure draw_overlay_rectangle_ellipse(ip:image_ptr_type;rect:ij_rectangle_type;
	color:integer);
procedure draw_overlay_ellipse(ip:image_ptr_type;ellipse:ij_ellipse_type;color:integer);
procedure embed_image_header(ip:image_ptr_type);
function image_ptr_from_name(name:string):image_ptr_type;
function image_amplitude(ip:image_ptr_type):real;
function image_average(ip:image_ptr_type):real;
function image_median(ip:image_ptr_type):real;
function image_maximum(ip:image_ptr_type):real;
function image_minimum(ip:image_ptr_type):real;
function image_sum(ip:image_ptr_type; threshold:integer):integer;
function overlay_color(i:integer):integer;
procedure spread_overlay(ip:image_ptr_type;spread:integer);
procedure paint_overlay_bounds(ip:image_ptr_type;color:integer);
function new_image(height,width:integer):image_ptr_type;
function valid_analysis_bounds(ip:image_ptr_type):boolean;
function valid_image_analysis_point(point:ij_point_type;ip:image_ptr_type):boolean;	
function valid_image_name(name:string):boolean;
function valid_image_point(ip:image_ptr_type;p:ij_point_type):boolean;
function valid_image_ptr(ip:image_ptr_type):boolean;
procedure write_image_list(var f:string;key:string;verbose:boolean);

implementation
	
var
	image_color_table:color_table_type;
	overlay_color_table:color_table_type;
	color_index,image_index:integer;


{
	get_px returns the value of the i'th pixel in the j'th row of the intensity
	array of an image.
}
function get_px(ip:image_ptr_type;j,i:integer):intensity_pixel_type;
begin
	get_px:=ip^.intensity[j*ip^.i_size+i];
end;

{
	set_px sets the i'th pixel in the j'th row of the intensity array of an
	image to value.
}
procedure set_px(ip:image_ptr_type;j,i:integer;value:intensity_pixel_type);
begin
	ip^.intensity[j*ip^.i_size+i]:=value;
end;

{
	get_ov returns the value of the i'th pixel in the j'th row of the overlay of
	an image.
}
function get_ov(ip:image_ptr_type;j,i:integer):integer;
begin
	get_ov:=ip^.overlay[j*ip^.i_size+i];
end;

{
	set_ov sets the i'th pixel in the j'th row of the overlay of an image to
	value. We take only the lowest byte of the value we pass in, and use this
	byte for our color.
}
procedure set_ov(ip:image_ptr_type;j,i:integer;value:integer);
begin
	ip^.overlay[j*ip^.i_size+i]:=value and byte_mask;
end;

{
	image_data_byte returns the n'th byte after the first byte in the second row of an
	image. We use images for one-dimensional data as well as two-dimensional. In the
	one-dimensional case, we reserve the first row for metadata. 
}
function image_data_byte(ip:image_ptr_type;n:integer):integer;
begin
	image_data_byte:=get_px(ip,(n div ip^.i_size)+1,(n mod ip^.i_size));
end;

{
	write_image_data_byte writes to the n'th byte after the first byte in the
	second row.
}
procedure write_image_data_byte(ip:image_ptr_type;b:byte;n:integer);
begin
	set_px(ip,(n div ip^.i_size)+1,(n mod ip^.i_size),b);
end;

{
	new_image allocates space for a new image_type with the specified height and
	width. It adds this image to the master image list. The analysis boundaries
	are left = 0, top = 1, right = i_size-1, and bottom = j_size-1. We let top=1
	because routines like embed_image_header use the first row for information
	about the image, such as the dimensions and analysis bounds.
}
function new_image(height,width:integer):image_ptr_type;
 
var
	image_num:integer;
	ip:image_ptr_type;
	
begin
	new_image:=nil;
	
	image_num:=0;
	while (image_num<length(master_image_list)) 
			and (master_image_list[image_num].name<>'') do
		inc(image_num);
	if (image_num>=length(master_image_list)) then begin
		report_error('Master image list is full in new_image.');
		exit;
	end;

	if (height<=0) or (width<=0) then begin
		report_error('Found (height<=0) or (width<=0) in new_image.');
		exit;
	end;
	if (height*width)>max_num_image_pixels then begin
		report_error('Found (height*width)>max_num_image_pixels in new_image.');
		exit;
	end;

	ip:=@master_image_list[image_num];
	with ip^ do begin	
		setlength(intensity,height*width);
		setlength(overlay,height*width);
		j_size:=height;
		i_size:=width;
		with analysis_bounds do begin
			left:=0;
			right:=i_size-1;
			top:=1;
			bottom:=j_size-1;
		end;
		writestr(name,default_image_name,image_counter:1);
		inc(image_counter);
		average:=not_valid_code;
		amplitude:=not_valid_code;
		maximum:=not_valid_code;
		minimum:=not_valid_code;
		results:='';
	end;

	clear_image(ip);
	clear_overlay(ip);

	new_image:=ip;
end;

{
	valid_image_ptr returns true iff ip^ is in the master image list.
}
function valid_image_ptr(ip:image_ptr_type):boolean;

var
	image_num:integer;
	valid:boolean;

begin
	valid:=false;
	image_num:=0;
	if ip<>nil then begin
		while (image_num<length(master_image_list)) 
				and (@master_image_list[image_num]<>ip) do
			inc(image_num);
		if image_num<length(master_image_list) then
			valid:=true;
	end;
	valid_image_ptr:=valid;
end;

{
	image_ptr_from_name returns the first image with the specified name in the
	master image list.
}
function image_ptr_from_name(name:string):image_ptr_type;

var
	image_num:integer;
	ip:image_ptr_type;

begin
	image_num:=0;
	ip:=nil;	
	while (image_num<length(master_image_list)) and (ip=nil) do begin
		if master_image_list[image_num].name=name then
			ip:=@master_image_list[image_num];
		inc(image_num);
	end;
	image_ptr_from_name:=ip;
end;

{
	valid_image_name returns true iff an image with name s is in
	the image list.
}
function valid_image_name(name:string):boolean;

begin
	valid_image_name:=(image_ptr_from_name(name)<>nil);
end;

{
	dispose_image disposes of a image's pixel and overlay arrays, freeing up
	memory, and sets the image name to the empty string.
}
procedure dispose_image(ip:image_ptr_type);

var
	image_num:integer;
	
begin
	if ip=nil then exit;
	image_num:=0;
	while (image_num<length(master_image_list)) 
			and (@master_image_list[image_num]<>ip) do 
		inc(image_num);
	if image_num<length(master_image_list) then 
		with master_image_list[image_num] do begin
			name:='';
			i_size:=0;
			j_size:=0;
			setlength(intensity,0);
			setlength(overlay,0);
		end;
end;

{
	dispose_named_images disposes of any images in the image list
	whose name matches the key string. The key string can contain
	"*" for the string wild card, and "?" for the character wild
	card.
}
procedure dispose_named_images(key:string);
var image_num:integer;
begin
	for image_num:=0 to length(master_image_list)-1 do begin
		with master_image_list[image_num] do begin
			if (name<>'') and string_match(key,name) then begin
				name:='';
				i_size:=0;
				j_size:=0;
				setlength(intensity,0);
				setlength(overlay,0);
			end;
		end;
	end;
end;

{
	paint_image fills an images's intensity array with the specified 
	shade of gray.
}
procedure paint_image(ip:image_ptr_type;shade:intensity_pixel_type);
var i,j:integer;
begin
	with ip^ do 
		for j:=0 to j_size-1 do
			for i:=0 to i_size-1 do
				set_px(ip,j,i,shade);
end;

{
	clear_image fills an image's intensity array with zeros, which is
	the color black.
}
procedure clear_image(ip:image_ptr_type);
begin
	paint_image(ip,black_color);
end;

{
	paint_overlay fills an image's overlay with the specified color.
}
procedure paint_overlay(ip:image_ptr_type;color:integer);
var i,j:integer;
begin
	with ip^ do 
		for j:=0 to j_size-1 do
			for i:=0 to i_size-1 do
				set_ov(ip,j,i,color);
end;

{
	clear_overlay clears an image's overlay, making it transparant.
}
procedure clear_overlay(ip:image_ptr_type);
begin
	paint_overlay(ip,clear_color);
end;

{
	fill_overlay fills an image's overlay with opaque white.
}
procedure fill_overlay(ip:image_ptr_type);
begin
	paint_overlay(ip,white_color);
end;

{
	paint_overlay_bounds fills an image's overlay with the specified color
	within its analysis bounds.
}
procedure paint_overlay_bounds(ip:image_ptr_type;color:integer);
var i,j:integer;
begin
	with ip^ do
		with analysis_bounds do
			for j:=top to bottom do
				for i:=left to right do
					set_ov(ip,j,i,color);
end;

{
	spread_overlay takes each overlay pixel that is not transparent and spreads 
	it to a square that is spread pixels on each side, roughly centered upon 
	the original pixel. When the spread operation causes two non-transparent
	pixels to grow into one another, the lower-valued color takes precedence.
}
procedure spread_overlay(ip:image_ptr_type;spread:integer);

var 
	i,j,m,n,lo,hi:integer;
	dp:image_ptr_type;
	color:integer;

begin
	if spread<=1 then exit;
	lo:=(spread-1) div 2;
	hi:=spread div 2;
	dp:=new_image(ip^.j_size,ip^.i_size);
	for j:=lo to ip^.j_size-1-hi do
		for i:=lo to ip^.i_size-1-hi do begin
			color:=white_color;
			for m:=j-lo to j+hi do
				for n:=i-lo to i+hi do
					if get_ov(ip,m,n)<color then
						color:=get_ov(ip,m,n);
			set_ov(dp,j,i,color);
		end;
	for j:=lo to ip^.j_size-1-hi do
		for i:=lo to ip^.i_size-1-hi do
			set_ov(ip,j,i,get_ov(dp,j,i));
	dispose_image(dp);
end;

{
	overlay_color takes an integer and returns a unique color using the integer
	input. We use the routine to provide colors for indexed arrays of lines,
	graphs, or shapes on a white background. The color returned will not be
	white, nor will it be the clear color, but it can be black.
}
function overlay_color(i:integer):integer;

const
	num_predefined_colors=18;
	colors: array [0..num_predefined_colors-1] of overlay_pixel_type =
		(red_color,green_color,blue_color,
		orange_color,yellow_color,magenta_color,
		brown_color,salmon_color,sky_blue_color,
		black_color,gray_color,light_gray_color,
		dark_red_color,dark_green_color,dark_blue_color,
		dark_brown_color,vdark_green_color,vdark_blue_color);
	prime=67;

var
	c:integer;
	
begin
	if (i>=0) and (i<num_predefined_colors) then c:=colors[i]
	else c:= (i*prime) mod clear_color;
	overlay_color:=c;
end;

{
	valid_image_point returns true iff point p lies within the bounds of the
	intensity and overlay areas.
}
function valid_image_point(ip:image_ptr_type;p:ij_point_type):boolean;

begin
	valid_image_point:=
		(p.i>=0) and (p.i<ip^.i_size)
		and (p.j>=0) and (p.j<ip^.j_size);
end;

{
	valid_analysis_bounds checks for self-consistency within an image's analysis
	bounds, and also checks that the analysis bounds are contained entirely
	within the image.
}
function valid_analysis_bounds(ip:image_ptr_type):boolean;
begin
	with ip^.analysis_bounds,ip^ do begin
		if (left<0) or (left>i_size-1)
		or (right<0) or (right>i_size-1) 
		or (top<0) or (top>j_size-1)
		or (bottom<0) or (bottom>j_size-1)
		or (left>right) or (top>bottom) then 
			valid_analysis_bounds:=false
		else
			valid_analysis_bounds:=true;
	end;
end;

{
	valid_image_analysis_point returns true iff the point is in the analysis bounds.
}
function valid_image_analysis_point(point:ij_point_type;ip:image_ptr_type):boolean;	
begin 
	with point,ip^.analysis_bounds do
		valid_image_analysis_point:=
			(i>=left) and (i<=right) and (j>=top) and (j<=bottom);
end;

{
	image_maximum returns the maximum image intensity within the image analysis
	bounds.
}
function image_maximum(ip:image_ptr_type):real;
	
var
	i,j,maximum:integer;
	
begin 
	if not valid_image_ptr(ip) then begin
		image_maximum:=min_intensity;
		exit;
	end;

	maximum:=min_intensity;
	with ip^.analysis_bounds do
		for i:=left to right do
			for j:=top to bottom do 
				if get_px(ip,j,i)>maximum then
					maximum:=get_px(ip,j,i);
	image_maximum:=maximum;
end;

{
	image_minimum returns the minimum image intensity within the image analysis 
	bounds.
}
function image_minimum(ip:image_ptr_type):real;

var
	i,j,minimum:integer;
	
begin 
	if not valid_image_ptr(ip) then begin
		image_minimum:=max_intensity;
		exit;
	end;

	minimum:=max_intensity;
	with ip^.analysis_bounds do
		for i:=left to right do
			for j:=top to bottom do 
				if get_px(ip,j,i)<minimum then
					minimum:=get_px(ip,j,i);
	image_minimum:=minimum;
end;

{
	image_average samples num_points in the image and calculates the average
	image intensity from these points.
}
function image_average(ip:image_ptr_type):real;

const 
	num_points=10000;

var 
	counter,sum:integer;
	point:ij_point_type;

begin
	if not valid_image_ptr(ip) then begin
		image_average:=min_intensity;
		exit;
	end;

	sum:=0;
	for counter:=1 to num_points do begin
		point:=ij_random_point(ip^.analysis_bounds);
		sum:=sum+get_px(ip,point.j,point.i);
	end;
	image_average:=sum/num_points;
end;

{
	image_median samples num_points in the image and calculates the median
	image intensity from these points.
}
function image_median(ip:image_ptr_type):real;

const 
	num_points=10000;

var 
	hp:xy_graph_type;
	point:ij_point_type;
	num_bins,point_num,i,counter,median:integer;
	sum:real;

begin
	if not valid_image_ptr(ip) then begin
		image_median:=min_intensity;
		exit;
	end;

	num_bins:=max_intensity-min_intensity+1;
	setlength(hp,num_bins);

	for i:=min_intensity to max_intensity do begin
		with hp[i-min_intensity] do begin
			x:=i;
			y:=0;
		end;
	end;

	counter:=0;
	for point_num:=1 to num_points do begin
		point:=ij_random_point(ip^.analysis_bounds);
		i:=get_px(ip,point.j,point.i);
		if (i>=min_intensity) and (i<=max_intensity) then begin
			hp[i-min_intensity].y:=hp[i-min_intensity].y+1;
			inc(counter);
		end;
	end;
	
	sum:=0;
	median:=min_intensity;
	for i:=min_intensity to max_intensity do begin
		sum:=sum+hp[i-min_intensity].y;
		if sum<=one_half*counter then median:=i;
	end;
	
	image_median:=median;
end;

{
	image_amplitude samples num_points in the image and calculates the standard
	deviation of the intensity from these points.
}
function image_amplitude(ip:image_ptr_type):real;

const 
	num_points=10000;

var 
	counter:integer;
	mean,sum:real;
	point:ij_point_type;

begin
	if not valid_image_ptr(ip) then begin
		image_amplitude:=0;
		exit;
	end;

	mean:=image_average(ip);
	sum:=0;
	for counter:=1 to num_points do begin
		point:=ij_random_point(ip^.analysis_bounds);
		sum:=sum+sqr(get_px(ip,point.j,point.i)-mean);
	end;
	image_amplitude:=sqrt(sum/num_points);
end;

{
	image_sum returns the total intensity of an image after subtracting 
	a threshold intensity.
}
function image_sum(ip:image_ptr_type; threshold:integer):integer;

var 
	i,j,sum,p:integer;
	
begin
	if not valid_image_ptr(ip) then begin
		image_sum:=0;
		exit;
	end;

	sum:=0;
	for j:=ip^.analysis_bounds.top to ip^.analysis_bounds.bottom do begin
		for i:=ip^.analysis_bounds.left to ip^.analysis_bounds.right do begin
			p:=get_px(ip,j,i)-threshold;
			if p>0 then sum:=sum+p;
		end;
	end;
	image_sum:=sum;
end;

{
	draw_overlay_pixel colors a pixel from ij space into the image overlay,
	provided the pixel lies between the image analysis boundries in ij
	space.
}
procedure draw_overlay_pixel(ip:image_ptr_type;pixel:ij_point_type;color:integer);
	
begin
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then exit;
	if not ij_in_rectangle(pixel,ip^.analysis_bounds) then exit;
	set_ov(ip,pixel.j,pixel.i,color);
end;

{
	draw_overlay_xy_line draws a line in two-dimensional real-valued space onto
	the overlay of the specified image. The routine draws the line in the
	specified color, and clips it to the analysis bounds. The routine takes a
	line with real-valued coordinates so as to avoid rounding errors in the
	start and end of the line it draws. The "color" parameter specifies not only
	the color of the line but also its width. Byte zero is the color, byte one
	is the width minus one. We reserve bytes two and three for future use. 
}
procedure draw_overlay_xy_line(ip:image_ptr_type;line:xy_line_type;
	color:integer);
	
const
	rough_step_size=0.5;{pixels}
	
var
	num_steps,step_num,width:integer;
	i,j,a,b,ii,jj:integer;
	p,q,step:xy_point_type;
	outside:boolean;

begin
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then exit;
	
	xy_clip_line(line,outside,ip^.analysis_bounds);
	if outside then exit;
	
	with line,ip^ do begin
		p.x:=a.x;
		p.y:=a.y;
		q.x:=b.x;
		q.y:=b.y;
	end;
	
	if xy_separation(p,q)<rough_step_size then num_steps:=0
	else num_steps:=round(xy_separation(p,q)/rough_step_size);
	step:=xy_scale(xy_difference(q,p),1/(num_steps+1));

	width:=((color div byte_shift) and byte_mask)+1;
	color:=color and byte_mask;
	
	if width<=1 then begin
		for step_num:=0 to num_steps do begin
			p:=xy_sum(p,step);
				set_ov(ip,round(p.y),round(p.x),color);
		end;
	end else begin
		a:=-((width-1) div 2);
		b:=a+width-1;
		for step_num:=0 to num_steps do begin
			p:=xy_sum(p,step);
			for i:=a to b do
				for j:=a to b do begin
					ii:=round(p.x+i);
					jj:=round(p.y+j);
					with ip^.analysis_bounds do begin
						if (ii>=left) and (ii<=right) 
								and (jj>=top) and (jj<=bottom) then
							set_ov(ip,jj,ii,color);
					end;
				end;
		end;
	end;
end;

{
	draw_overlay_line draws a line in two-dimensional integer space onto the
	overlay of the specified image. The routine draws the line in the specified
	color, and clips it to the analysis bounds. It calls draw_overlay_xy_line.
	The "color" parameter specifies not only the color of the line but also its
	width. Byte zero is the color, byte one is the width minus one. We reserve
	bytes two and three for future use. 
}
procedure draw_overlay_line(ip:image_ptr_type;line:ij_line_type;
	color:integer);
	
var 
	lxy:xy_line_type;
	
begin
	lxy.a.x:=line.a.i;
	lxy.a.y:=line.a.j;
	lxy.b.x:=line.b.i;
	lxy.b.y:=line.b.j;
	draw_overlay_xy_line(ip,lxy,color);
end;

{
	draw_image_xy_line draws a line in two-dimensional real-valued space into
	the intensity array of the specified image. The shade controls the grayscale
	intensity of the line as well as its width. Byte zero is the shade, byte one
	is the width minus one. We reserve bytes two and three for future use. 
}
procedure draw_image_xy_line(ip:image_ptr_type;line:xy_line_type;shade:integer);

const
	rough_step_size=0.5;{pixels}
	
var
	num_steps,step_num,width:integer;
	i,j,a,b,ii,jj:integer;
	p,q,step:xy_point_type;
	outside:boolean;

begin
	if not valid_image_ptr(ip) then exit;
	if not valid_analysis_bounds(ip) then exit;
	
	xy_clip_line(line,outside,ip^.analysis_bounds);
	if outside then exit;
	
	with line,ip^ do begin
		p.x:=a.x;
		p.y:=a.y;
		q.x:=b.x;
		q.y:=b.y;
	end;
	
	if xy_separation(p,q)<rough_step_size then num_steps:=0
	else num_steps:=round(xy_separation(p,q)/rough_step_size);
	step:=xy_scale(xy_difference(q,p),1/(num_steps+1));

	width:=((shade div byte_shift) and byte_mask)+1;
	shade:=shade and byte_mask;
	
	if width<=1 then begin
		for step_num:=0 to num_steps do begin
			p:=xy_sum(p,step);
				set_px(ip,round(p.y),round(p.x),shade);
		end;
	end else begin
		a:=-((width-1) div 2);
		b:=a+width-1;
		for step_num:=0 to num_steps do begin
			p:=xy_sum(p,step);
			for i:=a to b do
				for j:=a to b do begin
					ii:=round(p.x+i);
					jj:=round(p.y+j);
					with ip^.analysis_bounds do begin
						if (ii>=left) and (ii<=right) 
								and (jj>=top) and (jj<=bottom) then
							set_px(ip,jj,ii,shade);
					end;
				end;
		end;
	end;
end;

{
	draw_image_line draws a line in two-dimensional integer space into the
	intensity array of the specified image. The "shade" controls not only the
	grascale intensity of the line, but also its width. Byte zero is the
	grayscale intensity, byte one is the width minus one. We reserve bytes two
	and three for future use.
}
procedure draw_image_line(ip:image_ptr_type;line:ij_line_type;shade:integer);

var 
	lxy:xy_line_type;
	
begin
	lxy.a.x:=line.a.i;
	lxy.a.y:=line.a.j;
	lxy.b.x:=line.b.i;
	lxy.b.y:=line.b.j;
	draw_image_xy_line(ip,lxy,shade);
end;

{
	draw_overlay_rectangle draws a rectangle in two-dimensional integer space 
	onto the overlay of the specified image. The routine draws the rectangle in 
	the specified color, and clips it to the overlay boundries.
}
procedure draw_overlay_rectangle(ip:image_ptr_type;rect:ij_rectangle_type;
	color:integer);
	
var
	line:ij_line_type;
	
begin
	if not valid_image_ptr(ip) then exit;
	with line,rect do begin
		a.i:=left;a.j:=top;b.i:=left;b.j:=bottom;
		draw_overlay_line(ip,line,color);
		a.i:=left;a.j:=bottom;b.i:=right;b.j:=bottom;
		draw_overlay_line(ip,line,color);
		a.i:=right;a.j:=bottom;b.i:=right;b.j:=top;
		draw_overlay_line(ip,line,color);
		a.i:=right;a.j:=top;b.i:=left;b.j:=top;
		draw_overlay_line(ip,line,color);
	end;
end;

{	
	draw_overlay_rectangle_ellipse draws an ellipse in the boundaries of a
	rectangle. This routine uses code we from Gerd Platl at the following web
	address:

	http://www.bsdg.org/SWAG/GRAPHICS/0276.PAS.html

	We provide our own PutPixel so we don't have to modify his code at all. This
	routine is efficient at drawing circles, which you obtain by passing a
	square as the boundary, with the center of the square at the center of the
	circle, and the width of the square equal to the diameter of the circle. For
	general-purpose ellipse drawing see draw_overlay_ellipse.
}
procedure draw_overlay_rectangle_ellipse(ip:image_ptr_type;rect:ij_rectangle_type;
	color:integer);

	procedure PutPixel(x,y:integer;c:integer);
	var
		p:ij_point_type;
	begin
		p.i:=x;
		p.j:=y;
		draw_overlay_pixel(ip,p,c);
	end;
	
{
	Variables used by Gerd's code.
}
var
	x,mx1,mx2,my1,my2:integer;
	aq,bq,dx,dy,r,rx,ry,mx,my,a,b:integer;

begin
{
	Set up variables used by Gerd's code.
}
	with rect do begin
		mx:=round((right+left)/2);
		my:=round((top+bottom)/2);
		a:=round((right-left)/2);
		b:=round((bottom-top)/2);
	end;
{
	Start of Gerd's code.
}
  PutPixel (mx + a, my, color);
  PutPixel (mx - a, my, color);

  mx1 := mx - a;   my1 := my;
  mx2 := mx + a;   my2 := my;

  aq := longint (a) * a;        {calc sqr}
  bq := longint (b) * b;
  dx := aq shl 1;               {dx := 2 * a * a}
  dy := bq shl 1;               {dy := 2 * b * b}
  r  := a * bq;                 {r  := a * b * b}
  rx := r shl 1;                {rx := 2 * a * b * b}
  ry := 0;                      {because y = 0}
  x := a;

  while x > 0
  do begin
    if r > 0
    then begin                  { y + 1 }
      inc (my1);   dec (my2);
      inc (ry, dx);             {ry = dx * y}
      dec (r, ry);              {r = r - dx + y}
    end;
    if r <= 0
    then begin                  { x - 1 }
      dec (x);
      inc (mx1);   dec (mx2);
      dec (rx, dy);             {rx = dy * x}
      inc (r, rx);              {r = r + dy * x}
    end;
    PutPixel (mx1, my1, color);
    PutPixel (mx1, my2, color);
    PutPixel (mx2, my1, color);
    PutPixel (mx2, my2, color);
  end;
{
	End of Gerd's code.
}
end;

{
	draw_overlay_ellipse draws the border of an ij_ellipse_type on the screen. It 
	works by going through all the pixels in the analysis bounds of the image and
	finding those that are close to the edge of the ellipse. Of these, it marks 
	the points that are inside the ellipse, but which border on at least one pixel
	that is outside the ellipse. To get the routine to run faster, consider limiting
	the image analysis bounds to a rectangle that encloses the ellipse. On our 1.3 GHz
	G4 iBook, the routine took 16 ms to draw an ellipse that filled a rectangle 240
	pixels high and 100 pixels wide. We used the same rectangle as the boundary. 
	Compare that to 400 us for the same ellipse drawn to the borders of the rectangle
	by draw_overlay_rectangle_ellipse.
}
procedure draw_overlay_ellipse(ip:image_ptr_type;
	ellipse:ij_ellipse_type;color:integer);

var
	separation:real;
	i,j:integer;
	p:ij_point_type;
	
	function on_border(p:ij_point_type):boolean;
	const
		border=2;
	var 
		i_min,i_max,j_min,j_max,i,j:integer;
		s:real;
		q:ij_point_type;
		on:boolean;
	begin
		on:=false;
		s:=ij_separation(p,ellipse.a)+ij_separation(p,ellipse.b);
		if (s<=ellipse.axis_length) and (s>=ellipse.axis_length-border) then begin
			with ip^.analysis_bounds do begin
				i_min:=left;
				i_max:=right;
				j_min:=top;
				j_max:=bottom;
				if p.i>left then i_min:=p.i-1 else on:=true;
				if p.i<right then i_max:=p.i+1 else on:=true;
				if p.j>top then j_min:=p.j-1 else on:=true;
				if p.j<bottom then j_max:=p.j+1 else on:=true;
			end;
			if not on then
				for i:=i_min to i_max do
					for j:=j_min to j_max do begin
						q.i:=i;
						q.j:=j;
						with ellipse do 
							if ij_separation(q,a)+ij_separation(q,b)>axis_length then
								on:=true;
					end;
		end;
		on_border:=on;
	end;
	
begin
{
	Determine some properties of the ellipse.
}
	separation:=ij_separation(ellipse.a,ellipse.b);
{
	Check the eccentricity of the ellipse. The length of the major axis must be
	greater than or equal to the separation of the focal points.
}
	if (separation>ellipse.axis_length) then exit;
{
	Mark the pixels on the border.
}
	with ip^.analysis_bounds do
		for i:=left to right do
			for j:=top to bottom do begin
				p.i:=i;
				p.j:=j;
				if on_border(p) then
					draw_overlay_pixel(ip,p,color);
			end;
end;

{
	embed_image_header encodes as much of the image header as possible in the
	first line of image pixels. It records j_size-1, i_size-1, top, left,
	bottom, and right as short integers with big-endian byte ordering. These six
	numbers take up twelve pixels. The remaining pixels of the first line are
	available for the null-terminated results string. If the results string is
	too long to fit in the first row, embed_image_header cuts it short with a
	null character.
}
procedure embed_image_header(ip:image_ptr_type);

const
	number_space=12;
	
var
	ihp:image_header_ptr_type;
	end_index,char_index:integer;
	
begin
	with ip^ do begin
		ihp:=pointer(@intensity[0]);
		ihp^.i_max:=big_endian_from_local_smallint(i_size-1);
		ihp^.j_max:=big_endian_from_local_smallint(j_size-1);
		ihp^.left:=big_endian_from_local_smallint(analysis_bounds.left);
		ihp^.right:=big_endian_from_local_smallint(analysis_bounds.right);
		ihp^.top:=big_endian_from_local_smallint(analysis_bounds.top);
		ihp^.bottom:=big_endian_from_local_smallint(analysis_bounds.bottom);
		if j_size-number_space-1 > length(results) then
			end_index:=length(results)
		else
			end_index:=j_size-number_space-1;
		for char_index:=1 to end_index do 
			ihp^.results[char_index-1]:=results[char_index];
		ihp^.results[end_index]:=chr(0);
	end;
end;

{
	draw_image draws the specified image in the drawing space. If there
	is not enough room in the drawing space, draw_image allocates more
	space. To determine the colors in the drawing space from the colors in
	the image pixels, draw_image composes a color look-up table. To determine
	overlay colors from the colors in the image overlay, draw_image composes
	another look-up table.
}
procedure draw_image(ip:image_ptr_type);

const
	mild_range=10;
	strong_range=4;

var
	c_index,k,shade,gamma_corrected_shade:integer;
	image_offset,shade_offset,shade_scale,im:real;
	
begin
	if not valid_image_ptr(ip) then begin
		report_error('Found not valid_image_ptr(ip) in draw_image.');
		exit;
	end;

	setlength(drawing_space,ip^.i_size*ip^.j_size);
	with ip^ do begin
		shade_scale:=1;
		shade_offset:=0;
		image_offset:=0;
		
		case intensification of
			mild_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				image_offset:=average;
				shade_offset:=mid_intensity;
				if (amplitude<>0) then 
					shade_scale:=(max_intensity/mild_range)/amplitude
				else shade_scale:=1;
			end;
			strong_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				image_offset:=average;
				shade_offset:=mid_intensity;
				if (amplitude<>0) then 
					shade_scale:=(max_intensity/strong_range)/amplitude
				else shade_scale:=1;
			end;
			exact_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				image_offset:=image_minimum(ip);
				shade_offset:=min_intensity;
				im:=image_maximum(ip);
				if (im-image_offset)<>0 then
					shade_scale:=(white_intensity-black_intensity)/
						(im-image_offset)
				else shade_scale:=1;
			end;
		end;
	end;

	for c_index:=min_intensity to max_intensity do begin
		with image_color_table[c_index] do begin
			shade:=round(shade_scale*(c_index-image_offset)+shade_offset);
			if shade>white_intensity then shade:=white_intensity;
			if shade<black_intensity then shade:=black_intensity;
			
			gamma_corrected_shade:=round(
				xpy((shade-black_intensity)/(white_intensity-black_intensity),
					1/gamma_correction)
				* (white_intensity-black_intensity));

			red:=gamma_corrected_shade;
			green:=gamma_corrected_shade;
			blue:=gamma_corrected_shade;
			alpha:=opaque_alpha;
		end;
	end;
	
	for k:=0 to ip^.j_size*ip^.i_size-1 do begin
		if ip^.overlay[k]=clear_color then 
			drawing_space[k]:=image_color_table[ip^.intensity[k]]
		else 
			drawing_space[k]:=overlay_color_table[ip^.overlay[k]];
	end;
end;

{
	draw_rggb_image draws the specified image in the drawing space, assuming
	that its pixels are arranged as sets of four in a block with color filters
	over them like this:
	
	RG
	GB
	
	The routine performs intensification of color, and scales the red and blue
	with respect to the green using the global variables rggb_blue_scale
	and rggb_red_scale.
}
procedure draw_rggb_image(ip:image_ptr_type);

const
	mild_range=10;
	strong_range=4;
	num_rgb=3;

var
	c_index,i,j,shade,gamma_corrected_shade:integer;
	image_offset,shade_offset,shade_scale,im:real;
	d_ptr:^drawing_space_pixel_type;
	
begin
	if not valid_image_ptr(ip) then begin
		report_error('Found not valid_image_ptr(ip) in draw_rggb_image.');
		exit;
	end;
	
	setlength(drawing_space,ip^.i_size*ip^.j_size);
	with ip^ do begin
		shade_scale:=1;
		shade_offset:=0;
		image_offset:=0;
		
		case intensification of
			mild_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				image_offset:=average;
				shade_offset:=mid_intensity;
				if (amplitude<>0) then 
					shade_scale:=(max_intensity/mild_range)/amplitude
				else shade_scale:=1;
			end;
			strong_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				image_offset:=average;
				shade_offset:=mid_intensity;
				if (amplitude<>0) then 
					shade_scale:=(max_intensity/strong_range)/amplitude
				else shade_scale:=1;
			end;
			exact_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				shade_offset:=min_intensity;
				image_offset:=image_minimum(ip);
				im:=image_maximum(ip);
				if (im-image_offset)>0 then
					shade_scale:=(white_intensity-black_intensity)/(im-image_offset)
				else shade_scale:=1;
			end;
		end;
	end;

	for c_index:=min_intensity to max_intensity do begin
		with image_color_table[c_index] do begin
			shade:=round(shade_scale*(c_index-image_offset)+shade_offset);			
			if shade>white_intensity then shade:=white_intensity;
			if shade<black_intensity then shade:=black_intensity;
			gamma_corrected_shade:=round(
				xpy((shade-black_intensity)/(white_intensity-black_intensity),
					1/gamma_correction)
				* (white_intensity-black_intensity));

			shade:=round(gamma_corrected_shade*rggb_red_scale);
			if shade>white_intensity then shade:=white_intensity;
			if shade<black_intensity then shade:=black_intensity;
			red:=shade;

			green:=gamma_corrected_shade;

			shade:=round(gamma_corrected_shade*rggb_blue_scale);
			if shade>white_intensity then shade:=white_intensity;
			if shade<black_intensity then shade:=black_intensity;
			blue:=shade;

			alpha:=opaque_alpha;
		end;
	end;
		
{
	Here we calculate the color of each pixel using the red, blue, and green
	color intensities available in its own sensor pixel and the eight pixels
	around it. The sensor has its pixels with color filters arranged like this:
	
	column number      0 1 2 3 4 5 6 7...
	even-numbered row  R G R G R G R G...
	odd-numbered row   G B G B G B R G...
	even-numbered row  R G R G R G R G...
	odd-numbered row   G B G B G B R G...
	even-numbered row  R G R G R G R G...
	odd-numbered row   G B G B G B R G...
	
	For example, at a green pixel in an even-numbered row, we use the blue above
	and below to determine the blue intensity, and the red left and right for
	the red intensity.
}
	d_ptr:=@drawing_space[0];
	for j:=1 to ip^.j_size-2 do begin
		inc(d_ptr);
		for i:=1 to ip^.i_size-2 do begin
			if get_ov(ip,j,i)=clear_color then begin
				if not odd(j) then begin
					if not odd(i) then begin
						{Red Pixels On Even-Numbered Rows}
						d_ptr^.red:=image_color_table[get_px(ip,j,i)].red;
						d_ptr^.green:=image_color_table[round(one_quarter*
							(get_px(ip,j,i+1)
							+get_px(ip,j,i-1)
							+get_px(ip,j+1,i)
							+get_px(ip,j-1,i)))].green;
						d_ptr^.blue:=image_color_table[round(one_quarter*
							(get_px(ip,j+1,i+1)
							+get_px(ip,j+1,i-1)
							+get_px(ip,j-1,i+1)
							+get_px(ip,j-1,i-1)))].blue;
						d_ptr^.alpha:=opaque_alpha;
					end else begin
						{Green Pixels On Even-Numbered Rows}
						d_ptr^.red:=image_color_table[round(one_half*
							(get_px(ip,j,i+1)
							+get_px(ip,j,i-1)))].red;
						d_ptr^.green:=image_color_table[get_px(ip,j,i)].green;
						d_ptr^.blue:=image_color_table[round(one_half*
							(get_px(ip,j+1,i)
							+get_px(ip,j-1,i)))].blue;
						d_ptr^.alpha:=opaque_alpha;
					end;
				end else begin
					if not odd(i) then begin
						{Green Pixels On Odd-Numbered Rows}
						d_ptr^.red:=image_color_table[round(one_half*
							(get_px(ip,j+1,i)
							+get_px(ip,j-1,i)))].red;
						d_ptr^.green:=image_color_table[get_px(ip,j,i)].green;
						d_ptr^.blue:=image_color_table[round(one_half*
							(get_px(ip,j,i+1)
							+get_px(ip,j,i-1)))].blue;
						d_ptr^.alpha:=opaque_alpha;
					end else begin
						{Blue Pixels on Odd-Numbered Rows}
						d_ptr^.red:=image_color_table[round(one_quarter*
							(get_px(ip,j+1,i+1)
							+get_px(ip,j+1,i-1)
							+get_px(ip,j-1,i+1)
							+get_px(ip,j-1,i-1)))].red;
						d_ptr^.green:=image_color_table[round(one_quarter*
							(get_px(ip,j,i+1)
							+get_px(ip,j,i-1)
							+get_px(ip,j+1,i)
							+get_px(ip,j-1,i)))].green;
						d_ptr^.blue:=image_color_table[get_px(ip,j,i)].blue;
						d_ptr^.alpha:=opaque_alpha;
					end;
				end;
			end else d_ptr^:=overlay_color_table[get_ov(ip,j,i)];
			inc(d_ptr);
		end;
		inc(d_ptr);
	end;
end;

{
	draw_gbrg_image draws the specified image in the drawing space, assuming
	that its pixels are arranged as sets of four in a block with color filters
	over them like this:
	
	GB
	RB
	
	The routine performs intensification of color, and scales the red and blue
	with respect to the green using the global variables rggb_blue_scale
	and rggb_red_scale.
}
procedure draw_gbrg_image(ip:image_ptr_type);

const
	mild_range=10;
	strong_range=4;
	num_rgb=3;

var
	c_index,i,j,shade,gamma_corrected_shade:integer;
	image_offset,shade_offset,shade_scale,im:real;
	d_ptr:^drawing_space_pixel_type;
	
begin
	if not valid_image_ptr(ip) then begin
		report_error('Found not valid_image_ptr(ip) in draw_gbrg_image.');
		exit;
	end;
	
	setlength(drawing_space,ip^.i_size*ip^.j_size);
	with ip^ do begin
		shade_scale:=1;
		shade_offset:=0;
		image_offset:=0;
		
		case intensification of
			mild_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				image_offset:=average;
				shade_offset:=mid_intensity;
				if (amplitude<>0) then 
					shade_scale:=(max_intensity/mild_range)/amplitude
				else shade_scale:=1;
			end;
			strong_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				image_offset:=average;
				shade_offset:=mid_intensity;
				if (amplitude<>0) then 
					shade_scale:=(max_intensity/strong_range)/amplitude
				else shade_scale:=1;
			end;
			exact_intensify:begin
				average:=image_average(ip);
				amplitude:=image_amplitude(ip);
				shade_offset:=min_intensity;
				image_offset:=image_minimum(ip);
				im:=image_maximum(ip);
				if (im-image_offset)>0 then
					shade_scale:=(white_intensity-black_intensity)/(im-image_offset)
				else shade_scale:=1;
			end;
		end;
	end;

	for c_index:=min_intensity to max_intensity do begin
		with image_color_table[c_index] do begin
			shade:=round(shade_scale*(c_index-image_offset)+shade_offset);			
			if shade>white_intensity then shade:=white_intensity;
			if shade<black_intensity then shade:=black_intensity;
			gamma_corrected_shade:=round(
				xpy((shade-black_intensity)/(white_intensity-black_intensity),
					1/gamma_correction)
				* (white_intensity-black_intensity));

			shade:=round(gamma_corrected_shade*rggb_red_scale);
			if shade>white_intensity then shade:=white_intensity;
			if shade<black_intensity then shade:=black_intensity;
			red:=shade;

			green:=gamma_corrected_shade;

			shade:=round(gamma_corrected_shade*rggb_blue_scale);
			if shade>white_intensity then shade:=white_intensity;
			if shade<black_intensity then shade:=black_intensity;
			blue:=shade;

			alpha:=opaque_alpha;
		end;
	end;
		
{
	Here we calculate the color of each pixel using the red, blue, and green
	color intensities available in its own sensor pixel and the eight pixels
	around it. The sensor has its pixels with color filters arranged like this:
	
	column number      0 1 2 3 4 5 6 7...
	even-numbered row  G B G B G B R G...
	odd-numbered row   R G R G R G R G...
	even-numbered row  G B G B G B R G...
	odd-numbered row   R G R G R G R G...
	even-numbered row  G B G B G B R G...
	
	For example, at a green pixel in an even-numbered row, we use the red above
	and below to determine the red intensity, and the blue left and right for
	the blue intensity.
}
	d_ptr:=@drawing_space[0];
	for j:=1 to ip^.j_size-2 do begin
		inc(d_ptr);
		for i:=1 to ip^.i_size-2 do begin
			if get_ov(ip,j,i)=clear_color then begin
				if odd(j) then begin
					if not odd(i) then begin
						{Red Pixels on Odd-Numbered Rows}
						d_ptr^.red:=image_color_table[get_px(ip,j,i)].red;
						d_ptr^.green:=image_color_table[round(one_quarter*
							(get_px(ip,j,i+1)
							+get_px(ip,j,i-1)
							+get_px(ip,j+1,i)
							+get_px(ip,j-1,i)))].green;
						d_ptr^.blue:=image_color_table[round(one_quarter*
							(get_px(ip,j+1,i+1)
							+get_px(ip,j+1,i-1)
							+get_px(ip,j-1,i+1)
							+get_px(ip,j-1,i-1)))].blue;
						d_ptr^.alpha:=opaque_alpha;
					end else begin
						{Green Pixels On Odd-Numbered Rows}
						d_ptr^.red:=image_color_table[round(one_half*
							(get_px(ip,j,i+1)
							+get_px(ip,j,i-1)))].red;
						d_ptr^.green:=image_color_table[get_px(ip,j,i)].green;
						d_ptr^.blue:=image_color_table[round(one_half*
							(get_px(ip,j+1,i)
							+get_px(ip,j-1,i)))].blue;
						d_ptr^.alpha:=opaque_alpha;
					end;
				end else begin
					if not odd(i) then begin
						{Green Pixels On Even-Numbered Rows}
						d_ptr^.red:=image_color_table[round(one_half*
							(get_px(ip,j+1,i)
							+get_px(ip,j-1,i)))].red;
						d_ptr^.green:=image_color_table[get_px(ip,j,i)].green;
						d_ptr^.blue:=image_color_table[round(one_half*
							(get_px(ip,j,i+1)
							+get_px(ip,j,i-1)))].blue;
						d_ptr^.alpha:=opaque_alpha;
					end else begin
						{Blue Pixels on Even-Numbered Rows}
						d_ptr^.red:=image_color_table[round(one_quarter*
							(get_px(ip,j+1,i+1)
							+get_px(ip,j+1,i-1)
							+get_px(ip,j-1,i+1)
							+get_px(ip,j-1,i-1)))].red;
						d_ptr^.green:=image_color_table[round(one_quarter*
							(get_px(ip,j,i+1)
							+get_px(ip,j,i-1)
							+get_px(ip,j+1,i)
							+get_px(ip,j-1,i)))].green;
						d_ptr^.blue:=image_color_table[get_px(ip,j,i)].blue;
						d_ptr^.alpha:=opaque_alpha;
					end;
				end;
			end else d_ptr^:=overlay_color_table[get_ov(ip,j,i)];
			inc(d_ptr);
		end;
		inc(d_ptr);
	end;
end;

{
	write_image_list appends a list of images with names matching the 
	key string to a string.
}
procedure write_image_list(var f:string;key:string;verbose:boolean);

var
	image_num,num_entries,list_size:cardinal;
	
begin
	image_num:=0;
	num_entries:=0;
	list_size:=0;
	if verbose then begin
		writestr(f,f,eol);
		writestr(f,f,'Master Image List (Index, Name, Dimensions)',eol);
		for image_num:=0 to length(master_image_list)-1 do
			with master_image_list[image_num] do 
				if (name<>'') and string_match(key,name) then begin
					inc(num_entries);
					f:=f+sfi(image_num)+' '+name+' '+sfi(i_size)+'x'+sfi(j_size)+eol;
					list_size:=list_size+i_size*j_size;
				end;
		if num_entries=0 then writestr(f,f,'no image list entries match "',key,'".',eol);
		writestr(f,f,'Total number of pixels ',list_size:1,eol);
		writestr(f,f,'Drawing space is ',length(drawing_space),' pixels.',eol);
	end else begin
		for image_num:=0 to length(master_image_list)-1 do
			with master_image_list[image_num] do
				if (name<>'') and string_match(key,name) then 
					writestr(f,f,name,' ');
	end;
end;

{
	initialization allocates space for drawing color tables, and fills the 
	overlay color table.
}
initialization 

setlength(image_color_table,max_byte+1);
setlength(overlay_color_table,max_byte+1);

for color_index:=0 to max_byte-1 do begin
	with overlay_color_table[color_index] do begin
		red:=round(max_byte * (color_index and red_mask) / red_mask);
		green:=round(max_byte * (color_index and green_mask) / green_mask);
		blue:=round(max_byte * (color_index and blue_mask) / blue_mask);
		alpha:=opaque_alpha;
	end;
end;

with overlay_color_table[max_byte] do begin
	red:=max_byte;
	green:=max_byte;
	blue:=max_byte;
	alpha:=opaque_alpha;
end;

for image_index:=0 to length(master_image_list)-1 do begin
	with master_image_list[image_index] do begin
		name:='';
		setlength(intensity,0);
		setlength(overlay,0)
	end;
end;
	
{
	finalization disposes of global dynamic arrays.
}
finalization 

end.