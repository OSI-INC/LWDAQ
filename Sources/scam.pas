{
Silhouette Camera (SCAM) Projection and Fitting Routines
Copyright (C) 2023 Kevan Hashemi, Open Source Instruments Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place - Suite 330, Boston, MA  02111-1307, USA.
}

unit scam;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

{
	This unit contains routines for use with the Silhouette Cameras (SCAMs) of
	our Contactless Position Measurement System (CPMS). An SCAM sits on the same
	design of kinematic mount as a BCAM. The SCAM coordinate system is defined
	with respect to its three mounting balls in the same way as it is for BCAMs.
	An SCAM camera's calibration constants are defined in the same way as those
	of a BCAM. We assume the camera axis is almost parallel to the z-axis of the
	mount coordinate system. We have the direction of the axis, the location of
	the pivot point, the distance to the image sensor, and the rotation of the
	image sensor about the z-axis as the eight parameters that describe an SCAM,
	all in mount coordinates. Each image sensor has a different pixel size, so
	we need the calibration constants to specify the image sensor as well. The
	z-component of the axis direction is redundant: all our routines calculate
	the z-component from the small x and y components. In place of z in the
	calibration constants is an integer code that allows us to deduce the size
	of the image sensor pixels.

	The CPMS measures position taking stereo silhouette images of one or more
	bodies, modelling each body with a line drawing, and adjusting the location
	and orientation of each body until we minimize the disagreement between the
	line drawing and the actual silhouette. For brevity, we refer to the
	location and orientation of a body as its "pose". In our SCAM routines, we
	express the pose with six numbers: six coordinates and six angles. The six
	angles specify a compound rotation consisting of sequential rotations about
	the x, y, and z axes.

	Each CPMS body has its own internal coordinate system. The location of its
	origin is the location of the body. The sequence compount rotation that
	aligns the global coordinate axes with those of the body's coordinate system
	are the orientation of the body. The pose of the body is the pose of its
	coordinate system.

	Each SCAM has its own mount coordinate system. In our SCAM routines, we
	represent each mount coordinate system by its own pose, just as we do for
	bodies. We use the same representation in our BCAM routines. Thus we use
	the same routines to transform coordinates as we use for BCAMs. We use
	pose for bodies and mounts because we want to use our simplex fitter to
	deduce body positions and to calibrate SCAMs. For the simplex fitter to work
	well, we must represent the pose with the minimum number of parameters,
	which is six. If we were to use an origin with three unit vectors we would
	have twelve parameters, making half of them redundant.

	We compose a model of a CPMS "body" with one or more "objects", where each
	object is a simple shape such as a sphere, cylinder, shaft, or cuboid. Each
	object has its own pose within the coordinate system of the body. The body
	has its pose within the global coordinate system, and the SCAM viewing the
	body has its own pose. To obtain the pose of a body in SCAM coordinates, we
	transform one or more points in each object into the SCAM coordinates. We do
	not attempt to obtain the pose of the objects in SCAM coordinates for
	several reasons. One is that some objects are radially or axially symmetric,
	so they are insensitive to one or more rotations. Another is that
	calculating the pose that corresponds to a transformation is not as fast as
	transforming points and vectors. During our fits, we want the
	transformations to run fast. We take the time to obtain the pose of SCAM
	coordinates, but we need to so only once per measurement fit, because the
	SCAM coordinates are not changing.
}

interface

uses
	math,utils,images,transforms,bcam;
	
const
{
	Classification and projection color codes.
}
	scam_sphere_color=blue_color;
	scam_cylinder_color=blue_color;
	scam_shaft_color=blue_color;
	scam_silhouette_color=orange_color;

type
{
	A sphere object is entirely specified by the location of its center and its 
	diameter. 
}
	scam_sphere_type=record 
		location:xyz_point_type; {center of sphere}
		diameter:real; {diameter of sphere}
	end;
{
	We specify a shaft with a point on the shaft axis, the direction of the
	shaft, the number of faces, and for each face a diameter and a distance
	along the axis from the specified point on the shaft. We call this point the
	"location" of the shaft. The axis vector is the "orientation" of the shaft.
}
	scam_shaft_type=record 
		location:xyz_point_type; {origin of shaft}
		direction:xyz_point_type; {direction of shaft}
		num_faces:integer; {number of faces that define the shaft}
		diameter:array of real; {diameter of face}
		distance:array of real; {distance of face from origin}
	end;

{
	String input and output routines.
}
function scam_sphere_from_string(s:string):scam_sphere_type;
function scam_shaft_from_string(s:string):scam_shaft_type;
function read_scam_sphere(var s:string):scam_sphere_type;
function read_scam_shaft(var s:string):scam_shaft_type;
function string_from_scam_sphere(sphere:scam_sphere_type):string;
function string_from_scam_shaft(shaft:scam_shaft_type):string;

{
	Routines that project hypothetical objects onto the overlays of our SCAM
	images. We pass an image pointer to the routines, and the routine works on
	this image. We specify an object in SCAM coordinates and we give the
	calibration of the camera in SCAM coordinates too. The default routines
	project by drawing lines between projected points. 
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:scam_sphere_type;
	camera:bcam_camera_type;
	num_lines,line_width:integer);
procedure scam_project_shaft(ip:image_ptr_type;
	shaft:scam_shaft_type;
	camera:bcam_camera_type;
	num_lines,line_width:integer);

{
	Routines that analyze the image.
}
function scam_decode_rule(ip:image_ptr_type;rule:string):real;
function scam_disagreement(ip:image_ptr_type;threshold:real):real;

implementation

{
	read_scam_sphere reads the parameters of a sphere from a string and deletes
	them from the string. It returns a new sphere record.
}
function read_scam_sphere(var s:string):scam_sphere_type;
var sphere:scam_sphere_type;
begin 
	sphere.location:=read_xyz(s);
	sphere.diameter:=read_real(s);
	read_scam_sphere:=sphere;
end;

{
	scam_sphere_from_string takes a string and returns a new sphere record. Does
	not alter the original string.
}
function scam_sphere_from_string(s:string):scam_sphere_type;
begin scam_sphere_from_string:=read_scam_sphere(s); end;

{
	string_from_scam_sphere converts a shaft into a string for printing.
}
function string_from_scam_sphere(sphere:scam_sphere_type):string;
var s:string='';
begin
	with sphere do begin
		write_xyz(s,location);
		s:=s+' ';
		writestr(s,s,diameter:fsr:fsd);
	end;
	string_from_scam_sphere:=s;
end;

{
	read_scam_shaft reads the parameters of a shaft from a string and deletes
	them from the string. It returns a new shaft record. The string must contain
	the location of the shaft, which is a point on its axis, and the direction
	of the shaft, which points in the positive direction for locating faces on
	the shaft. Each face is specified by a diameter and a distance from the
	location along the shaft in the shaft direction. The distances can be
	negative or positive.	
}
function read_scam_shaft(var s:string):scam_shaft_type;
var 
	shaft:scam_shaft_type;
	i:integer;
	x:real;
	word,ss:string;
	okay:boolean;
begin 
	with shaft do begin
		location:=read_xyz(s);
		direction:=read_xyz(s);
		ss:='';
		repeat
			word:=read_word(s);
			x:=real_from_string(word,okay);
			if okay then ss:=ss+' '+word;
		until (s='') or (not okay);
		if not okay then s:=word+' '+s;
		
		num_faces:=word_count(ss) div 2;
		setlength(diameter,num_faces);
		setlength(distance,num_faces);
		for i:=0 to num_faces-1 do begin
			diameter[i]:=read_real(ss);
			distance[i]:=read_real(ss);
		end;
	end;
	read_scam_shaft:=shaft;
end;

{
	scam_shaft_from_string takes a string and returns a new shaft record. Does
	not alter the original string.
}
function scam_shaft_from_string(s:string):scam_shaft_type;
begin scam_shaft_from_string:=read_scam_shaft(s); end;

{
	string_from_scam_shaft converts a shaft into a string for printing.
}
function string_from_scam_shaft(shaft:scam_shaft_type):string;
var s:string='';face_num:integer;
begin
	with shaft do begin
		write_xyz(s,location);
		s:=s+' ';
		write_xyz(s,direction);
		s:=s+' ';
		for face_num:=0 to num_faces-1 do
			writestr(s,s,diameter[face_num]:fsr:fsd,' ',distance[face_num]:fsr:fsd,' ');
	end;
	string_from_scam_shaft:=s;
end;

{
	scam_decode_rule takes a string like "10 &" and returns, for the specified
	image, an intensity threshold for backlight pixels in the image. The first
	parameter in the command string must be an integer specifying the threshold
	intensity. The integer may be followed by of the symbols *, %, #, $, or &.
	Each of these symbols gives a different meaning to the threshold value, in
	the same way they do for spot analysis, see the spot_decode_command_string
	for details.
}
function scam_decode_rule(ip:image_ptr_type;rule:string):real;

const
	percent_unit=100;

var
	word:string;
	background,threshold:real;
	
begin
{
	Decode the threshold string. First we read the threshold, then we look for a
	valid threshold qualifier.
}
	threshold:=read_integer(rule);
	word:=read_word(rule);
	if word='%' then begin
		background:=round(image_minimum(ip));
		threshold:=(1-threshold/percent_unit)*background
			+threshold/percent_unit*image_maximum(ip);
	end else if word='#' then begin
		background:=image_average(ip);
		threshold:=(1-threshold/percent_unit)*background
			+threshold/percent_unit*image_maximum(ip);
	end else if word='*' then begin
		background:=0;
		threshold:=threshold-background;
	end else if word='$' then begin
		background:=image_average(ip);
		threshold:=background+threshold;
	end else if word='&' then begin
		background:=image_median(ip);
		threshold:=background+threshold;
	end;
	scam_decode_rule:=threshold;
end;
	
{
	scam_project_sphere takes a sphere in SCAM coordinates and projects drawing
	of the sphere onto the image plane of a camera. The routine finds the circle
	on the surface of the sphere that is the outsline of the sphere as seen by
	the camera. It projects num_lines points around this circle into the image
	and joins them to trace the sphere silhouette perimiter. It further joins
	the points with one another to provide some fill of the silhouette. The
	routine draws in the overlay, not the actual image. 
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:scam_sphere_type;
	camera:bcam_camera_type;
	num_lines,line_width:integer);
	
const
	draw_perimeter=true;
	draw_radials=false;
	draw_chords=true;
	draw_cross_chords=true;
	min_num_lines=2;
	
var
	axis,tangent,center_line:xyz_line_type;
	theta:real;
	w:real;
	step:integer;
	pt,pc:xy_point_type;
	line:xy_line_type;
	ic:xy_point_type;
	perimeter:array of xy_point_type;
	color:integer;
	
begin
{
	If the number of points is fewer than two, we abort.
}
	if num_lines<min_num_lines then begin
		report_error('num_lines<min_num_lines in scam_project_sphere');
		exit;
	end;
{
	Set the color to include the line width and the overlay pixel color.
}
	color:=scam_sphere_color+(line_width-1)*byte_shift;
{
	Find a tangent to the sphere that intersects the pivot point of the camera.
	We start by constructing a line from the pivot point to the sphere center,
	which we call the center line. We obtain the angle between the tangent and
	the center line. We rotate the sphere center about an axis perpendicular to
	the center line and passing through the camera pivot point. The result is
	our tangent point, which is not the point of contact of the tangent on the
	sphere, but slightly farther along the tangent from the pivot point. The
	tangent line is the line passing through the pivot point in the direction of
	the tangent point. 
}
	center_line.point:=camera.pivot;
	center_line.direction:=xyz_difference(sphere.location,camera.pivot);
	theta:=arcsin(sphere.diameter*one_half/xyz_length(center_line.direction));
	axis.point:=camera.pivot;
	axis.direction:=xyz_perpendicular(center_line.direction);
	tangent.point:=xyz_axis_rotate(sphere.location,axis,theta);
	tangent.direction:=xyz_difference(tangent.point,camera.pivot);
{
	When we project tangents onto our image sensor, we are going to mark them in the
	overlay, for which we need the size of the pixels.
}
	case round(camera.code) of 
		bcam_icx424_code: w:=bcam_icx424_pixel_um/um_per_mm;
		bcam_tc255_code: w:=bcam_tc255_pixel_um/um_per_mm;
		bcam_generic_code: w:=bcam_generic_pixel_um/um_per_mm;
		otherwise w:=bcam_tc255_pixel_um/um_per_mm;
	end;
{
	Rotate our tangent about the center vector in steps to complete a circuit of
	the projection cone. At each step, we project the tangent point onto our
	image plane and store this image point in a perimieter array.
}
	setlength(perimeter,num_lines);
	for step:=0 to num_lines-1 do begin
		pt:=bcam_image_position(tangent.point,camera);
		perimeter[step].x:=pt.x/w-ccd_origin_x;
		perimeter[step].y:=pt.y/w-ccd_origin_y;
		tangent.point:=xyz_axis_rotate(tangent.point,center_line,2*pi/num_lines);
		tangent.direction:=xyz_difference(tangent.point,camera.pivot);
	end;
{
	Draw the perimiter by joining points with lines. If draw_radials, we draw a line
	from each perimeter point to the center. If draw_chords, we draw parallel lines
	between opposite perimeter points.
}	
	pc:=bcam_image_position(sphere.location,camera);
	ic.x:=pc.x/w-ccd_origin_x;
	ic.y:=pc.y/w-ccd_origin_y;
	for step:=0 to num_lines-1 do begin
		if draw_perimeter then begin
			line.a:=perimeter[step];		
			line.b:=perimeter[(step+1) mod num_lines];
			draw_overlay_xy_line(ip,line,color);
		end;
		
		if draw_chords and (step<=num_lines/2) then begin
			line.a:=perimeter[step];		
			line.b:=perimeter[num_lines-step-1];
			draw_overlay_xy_line(ip,line,color);
		end;	
			
		if draw_cross_chords and (step<=num_lines/2) then begin
			line.a:=perimeter[step+round(num_lines/4)];		
			line.b:=perimeter[(num_lines+round(num_lines/4)-step-1) mod num_lines];
			draw_overlay_xy_line(ip,line,color);
		end;

		if draw_radials then begin
			line.a:=perimeter[step];		
			line.b:=ic;
			draw_overlay_xy_line(ip,line,color);
		end;
	end;
end;

{
	scam_project_shaft takes a shaft in SCAM coordinates and projects a drawing
	of the shaft onto the image plane of a camera. We specify the number of
	points around each shaft face that the routine should use to traced the
	circumference at each face. The routine will further join these points from
	one face to the next, and from the shaft center line it will draw radial
	lines out to these points on the first and last faces. With enough points,
	the projection will appear solid. But we do not need a solid projection for
	SCAM fitting to work. The routine draws in the overlay, not the actual
	image.
}
procedure scam_project_shaft(ip:image_ptr_type;
	shaft:scam_shaft_type;
	camera:bcam_camera_type;
	num_lines,line_width:integer);
	
const
	draw_perimeter=true;
	draw_axials=true;
	draw_radials=false;
	min_num_lines=2;
	
var
	step,face_num:integer;
	point,center,radial:xyz_point_type;
	w:real;
	projection:xy_point_type;
	perimeter_a,perimeter_b:array of xy_point_type;
	ica:xy_point_type;
	line:xy_line_type;
	axis:xyz_line_type;
	pc:xy_point_type;
	color:integer;

begin
{
	If the number of points is fewer than two, we abort.
}
	if num_lines<min_num_lines then begin
		report_error('num_lines<min_num_lines in scam_project_shaft');
		exit;
	end;
{
	Set the color to include the line width and the overlay pixel color.
}
	color:=scam_sphere_color+(line_width-1)*byte_shift;
{
	If the number of points is zero, or the number of faces is zero, exit.
}
	if num_lines=0 then exit;
	if shaft.num_faces<=0 then exit;
{
	Set the axis line point at the shaft location, and set its direction to
	be a unit vector parallel to the shaft direction.
}
	axis.point:=shaft.location;
	axis.direction:=xyz_unit_vector(shaft.direction);
{
	When we project tangents onto our image sensor, we are going to mark them in
	the overlay, for which we need the size of the pixels.
}
	case round(camera.code) of 
		bcam_icx424_code: w:=bcam_icx424_pixel_um/um_per_mm;
		bcam_tc255_code: w:=bcam_tc255_pixel_um/um_per_mm;
		bcam_generic_code: w:=bcam_generic_pixel_um/um_per_mm;
		otherwise w:=bcam_tc255_pixel_um/um_per_mm;
	end;
{
	Progress through the faces, drawing each perimeter, then joining perimeter
	points to the perimeter points of the previous face, if it exists. See
	comments in the cylinder projection routine for details of the calculation.
	When we draw the first and last faces, we always draw the radial lines,
	provided that the face diameter is greater than zero. Otherwise, we draw the
	radials only if the draw_radials flag is set.
}
	for face_num:=0 to shaft.num_faces-1 do begin
		setlength(perimeter_a,num_lines);
		if face_num=0 then perimeter_b:=perimeter_a;
		with shaft do begin
			radial:=xyz_scale(xyz_perpendicular(axis.direction),
				diameter[face_num]*one_half);
			center:=xyz_sum(axis.point,
				xyz_scale(axis.direction,distance[face_num]));
			point:=xyz_sum(center,radial);
			
			for step:=0 to num_lines-1 do begin
				projection:=bcam_image_position(point,camera);
				perimeter_a[step].x:=projection.x/w-ccd_origin_x;
				perimeter_a[step].y:=projection.y/w-ccd_origin_y;
				point:=xyz_axis_rotate(point,axis,2*pi/num_lines);
			end;
			
			pc:=bcam_image_position(center,camera);
			ica.x:=pc.x/w-ccd_origin_x;
			ica.y:=pc.y/w-ccd_origin_y;
			
			for step:=0 to num_lines-1 do begin
				if draw_perimeter then begin
					line.a:=perimeter_a[step];		
					line.b:=perimeter_a[(step+1) mod num_lines];
					draw_overlay_xy_line(ip,line,color);
				end;
				
				if ((face_num=0) and (diameter[face_num]>0))
					or ((face_num=num_faces-1) and (diameter[face_num]>0))
					or draw_radials then begin
					line.a:=perimeter_a[step];		
					line.b:=ica;
					draw_overlay_xy_line(ip,line,color);
				end;
				
				if (face_num>0) and draw_axials then begin
					line.a:=perimeter_a[step];
					line.b:=perimeter_b[step];
					draw_overlay_xy_line(ip,line,color);
				end;
			end;
		end;
		perimeter_b:=perimeter_a;
	end;
end;

{
	scam_disagreement measures the disagreement between a silhouette and a
	collection of projected objets. So far as the routine is concerned, a pixel
	is part of a projection if and only if its overlay is not clear. A pixel is
	part of a silhouette if and only if its intensity is less than the specified
	threshold. When a pixel is occupied by silhouette and projection, we clear
	its overlay, to show there is no disagreement. If it is occupied by neither
	silhouette nor projection, we leave its overlay clear, to show there is no
	disagreement. If it is silhouette but not projection, we mark its overlay
	with the silhouette color to show disagreement. If it is projection but not
	silhouette, we leave its overlay marked with the projection color to show
	disagreement. The overlay will be clear except where the silhouette and
	projection disagree. The routine returns the number of disagreeing pixels
	as its measure of disagreement.
}
function scam_disagreement(ip:image_ptr_type;threshold:real):real;

var
	i,j:integer;
	t,b,d:real;
	p:boolean;
	
begin
	d:=0;
	t:=threshold;
	with ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				p:=(get_ov(ip,j,i)<>clear_color);
				b:=get_px(ip,j,i);
				if b<=t then begin
					if not p then begin
						d:=d+1.0;
						set_ov(ip,j,i,scam_silhouette_color);
					end else begin
						set_ov(ip,j,i,clear_color);
					end;
				end else begin
					if p then d:=d+1.0;
				end;
			end;
		end;
	end;
	scam_disagreement:=d;
end;

end.

