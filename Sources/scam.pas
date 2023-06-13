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
	This unit contains routines for use with our Silhouette Cameras (SCAMs) and
	the Contactless Position Measurement System (CPMS) that uses these cameras.
	The SCAM uses the same kinematic mount as a BCAM, so SCAM coordinates are
	defined with respect to the SCAM's three mounting balls as for the BCAM. We
	assume the SCAM's axis is close to parallel to the mount coordinate z-axis.
	Our image coordinates are microns from the top-left corner of the top-left
	pixel in the image. Our mount cooridinates are in millimeters, with the
	origin at the center of the cone ball. Our global coordinates are in
	millimeters also. We use the same image sensor encoding system as the BCAM:
	in place of axis.z we include a code that indicates if the SCAM faces
	forward (+ve) or backwards (-ve), and for which the absolute value specifies
	the sensor itself. The SCAM projection routines need to know the size of the
	pixels, and for this reason the SCAM unit keeps a list of pixel sizes to go
	with the sensor codes.
}

interface

uses
	math,utils,images,transforms,bcam;
	
const
{
	Classification and projection color codes.
}
	scam_sphere_color=green_color;
	scam_cylinder_color=blue_color;
	scam_silhouette_color=orange_color;

type
{
	Object types for projection. An scam_sphere we define with a point and a
	radius. An scam_cylinder is a plane containing one of the two circular ends
	of the cylinder, a radius that gives us the perimiter of the circle, and a
	length. The length, combined with the direction of the normal vector used to
	express the plane, give us the direction and terminus of the cylinder axis,
	and therefore the far face of the cylinder as well. We have no xyz_circle,
	because we can get a circle by setting the length of a cylinder to zero. 
}
	scam_sphere_type=record center:xyz_point_type;radius:real; end;
	scam_cylinder_type=record face:xyz_plane_type;radius,length:real; end;
	scam_shaft_type=record 
		axis:xyz_line_type; {origin and direction of shaft axis}
		num_faces:integer;{number of faces that define the shaft}
		center:array of real;{face centers, distance from origin along axis}
		radius:array of real;{face radii, perpendicular to axis}
	end;

{
	Geometry routines.
}
function xyz_line_crosses_sphere(line:xyz_line_type;sphere:scam_sphere_type):boolean;
function xyz_line_crosses_cylinder(line:xyz_line_type;cylinder:scam_cylinder_type):boolean;
function scam_sphere_from_string(s:string):scam_sphere_type;
function scam_cylinder_from_string(s:string):scam_cylinder_type;
function scam_shaft_from_string(s:string):scam_shaft_type;
function read_scam_sphere(var s:string):scam_sphere_type;
function read_scam_cylinder(var s:string):scam_cylinder_type;
function read_scam_shaft(var s:string):scam_shaft_type;
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
	num_points:integer);
procedure scam_project_cylinder(ip:image_ptr_type;
	cylinder:scam_cylinder_type;
	camera:bcam_camera_type;
	num_points:integer);
procedure scam_project_shaft(ip:image_ptr_type;
	shaft:scam_shaft_type;
	camera:bcam_camera_type;
	num_points:integer);

{
	These projection routines go through every pixel in the image to see if it
	should be included in a projected silhouette. They are slow, but they are
	useful as a check of the line-drawing projection routines.
}
procedure scam_project_sphere_complete(ip:image_ptr_type;
	sphere:scam_sphere_type;
	camera:bcam_camera_type);
procedure scam_project_cylinder_complete(ip:image_ptr_type;
	cylinder:scam_cylinder_type;
	camera:bcam_camera_type);
	
{
	Routines that analyze the image.
}
function scam_decode_rule(ip:image_ptr_type;rule:string):real;
function scam_disagreement(ip:image_ptr_type;threshold:real):real;
function scam_disagreement_spread(ip:image_ptr_type;threshold,spread:real):real;

implementation

{
	read_scam_sphere reads the parameters of a sphere from a string and deletes
	them from the string. It returns a new sphere record.
}
function read_scam_sphere(var s:string):scam_sphere_type;
var sphere:scam_sphere_type;
begin 
	sphere.center:=read_xyz(s);
	sphere.radius:=read_real(s);
	read_scam_sphere:=sphere;
end;

{
	scam_sphere_from_string takes a string and returns a new sphere record. Does
	not alter the original string.
}
function scam_sphere_from_string(s:string):scam_sphere_type;
begin scam_sphere_from_string:=read_scam_sphere(s); end;

{
	read_scam_cylinder reads the parameters of a cylinder from a string and deletes
	them from the string. It returns a new cylinder record.
}
function read_scam_cylinder(var s:string):scam_cylinder_type;
var cylinder:scam_cylinder_type;
begin 
	cylinder.face.point:=read_xyz(s);
	cylinder.face.normal:=read_xyz(s);
	cylinder.radius:=read_real(s);
	cylinder.length:=read_real(s);
	read_scam_cylinder:=cylinder;
end;

{
	scam_cylinder_from_string takes a string and returns a new cylinder record. Does
	not alter the original string.
}
function scam_cylinder_from_string(s:string):scam_cylinder_type;
begin scam_cylinder_from_string:=read_scam_cylinder(s); end;

{
	read_scam_shaft reads the parameters of a shaft from a string and deletes
	them from the string. It returns a new shaft record.
}
function read_scam_shaft(var s:string):scam_shaft_type;
var shaft:scam_shaft_type;i:integer;
begin 
	with shaft do begin
		axis.point:=read_xyz(s);
		axis.direction:=read_xyz(s);
		num_faces:=read_integer(s);
		setlength(center,num_faces);
		setlength(radius,num_faces);
		for i:=0 to num_faces-1 do begin
			center[i]:=read_real(s);
			radius[i]:=read_real(s);
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
		write_xyz(s,axis.point);
		s:=s+' ';
		write_xyz(s,axis.direction);
		s:=s+' ';
		writestr(s,s,num_faces:1,' ');
		for face_num:=0 to num_faces-1 do
			writestr(s,s,center[face_num]:fsr:fsd,' ',radius[face_num]:fsr:fsd,' ');
	end;
	string_from_scam_shaft:=s;
end;

{
	xyz_line_crosses_sphere returns true iff the line intersects or touches
	the sphere.
}
function xyz_line_crosses_sphere(line:xyz_line_type;sphere:scam_sphere_type):boolean;
var
	range:real;
begin
	xyz_line_crosses_sphere:=false;
	range:=xyz_length(xyz_point_line_vector(sphere.center,line));
	xyz_line_crosses_sphere:=(range<=sphere.radius);
end;

{
	xyz_line_crosses_cylinder returns true iff the line intersects or touches
	the cylinder. We check to see if the line crosses either flat face of the 
	cylinder, then to see if it crosses the curved surface. A line crosses a
	flat face if it intersects with the plane defining the flat surface within
	the cylinder radius of the face center. If a line crosses neither face, its
	only means of crossing the cylinder is to enter the curved surface of the
	cylinder some place and leave the curved surface at another place. The closest
	approach of the line to the cylinder axis will have length less than the 
	cylinder radius, and the closest point on the axis will lie between the 
	two cylinder faces.
}
function xyz_line_crosses_cylinder(line:xyz_line_type;cylinder:scam_cylinder_type):boolean;
var
	f:xyz_plane_type;
	n,p:xyz_point_type;
	axis,bridge:xyz_line_type;
	a:real;
begin
	xyz_line_crosses_cylinder:=false;
	if xyz_separation(
			xyz_line_plane_intersection(line,cylinder.face),
			cylinder.face.point) 
			<= cylinder.radius then 
		xyz_line_crosses_cylinder:=true
	else begin
		n:=xyz_unit_vector(cylinder.face.normal);
		f.point:=xyz_sum(cylinder.face.point,xyz_scale(n,cylinder.length));
		f.normal:=n;
		if xyz_separation(
				xyz_line_plane_intersection(line,f),
				f.point) <= cylinder.radius then 
			xyz_line_crosses_cylinder:=true
		else begin
			axis.point:=cylinder.face.point;
			axis.direction:=n;
			bridge:=xyz_line_line_bridge(axis,line);
			p:=xyz_difference(bridge.point,cylinder.face.point);
			a:=xyz_dot_product(p,n);
			if (a>=0) and (a<=cylinder.length) 
					and (xyz_length(bridge.direction)<=cylinder.radius) then
				xyz_line_crosses_cylinder:=true
		end;
	end;
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
	scam_project_sphere_complete takes a sphere in SCAM coordinates and projects
	it onto the image plane of a camera. The image plane's center and pixel size
	are specified by the sensor code in the camera record. The routine draws in
	the overlay, not the actual image. It represents the projection as a solid
	fill in the sphere color. The routine goes through all the pixels within the
	analysis bounds of the image and seeing if each will be in the silhouette of
	the object. Its execution time is slow, but it is "complete". We call this
	routine when we pass zero for the number of projection points to the usual
	projection routine.
}
procedure scam_project_sphere_complete(ip:image_ptr_type;
	sphere:scam_sphere_type;
	camera:bcam_camera_type);

var
	i,j:integer;
	q:xy_point_type;
	w:real;
	
begin
	case round(camera.code) of 
		bcam_icx424_code: w:=bcam_icx424_pixel_um/um_per_mm;
		bcam_tc255_code: w:=bcam_tc255_pixel_um/um_per_mm;
		bcam_generic_code: w:=bcam_generic_pixel_um/um_per_mm;
		otherwise w:=bcam_tc255_pixel_um/um_per_mm;
	end;
	with ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				q.x:=(i+ccd_origin_x)*w;
				q.y:=(j+ccd_origin_y)*w;
				if xyz_line_crosses_sphere(bcam_source_bearing(q,camera),sphere) then
					set_ov(ip,j,i,scam_sphere_color);
			end;
		end;
	end;
end;

{
	scam_project_cylinder_complete does for cylinders what scam_project_sphere
	does for spheres. We get a solid fill in the cylinder color in the overlay.
	The routine goes through all the pixels within the analysis bounds of the
	image and seeing if each will be in the silhouette of the object. Its
	execution time is slow, but it is "complete". We call this routine when we
	pass zero for the number of projection points to the usual projection
	routine.
}
procedure scam_project_cylinder_complete(ip:image_ptr_type;
	cylinder:scam_cylinder_type;
	camera:bcam_camera_type);
	
var
	i,j:integer;
	q:xy_point_type;
	w:real;
	
begin
	case round(camera.code) of 
		bcam_icx424_code: w:=bcam_icx424_pixel_um/um_per_mm;
		bcam_tc255_code: w:=bcam_tc255_pixel_um/um_per_mm;
		bcam_generic_code: w:=bcam_generic_pixel_um/um_per_mm;
		otherwise w:=bcam_tc255_pixel_um/um_per_mm;
	end;
	with ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				q.x:=(i+ccd_origin_x)*w;
				q.y:=(j+ccd_origin_y)*w;
				if xyz_line_crosses_cylinder(bcam_source_bearing(q,camera),cylinder) then
					set_ov(ip,j,i,scam_cylinder_color);
			end;
		end;
	end;
end;

{
	scam_project_sphere takes a sphere in SCAM coordinates and draws the outline
	of its projection onto the image plane of a camera, then attempts to fill
	the projection with lines drawn within the sphere. The num_points prameter
	is the number of perimeter points the routine will project. The routine
	represents the outline with a finite number of straight lines joining points
	on the projection's perimeter. If we pass zero for the number of lines, the
	routine calls scam_project_sphere_complete. The routine draws in the
	overlay, not the actual image. If we pass zero for the number of lines, the
	routine calls scam_project_sphere_complete. The routine draws in the
	overlay, not the actual image. 
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:scam_sphere_type;
	camera:bcam_camera_type;
	num_points:integer);
	
const
	draw_perimeter=true;
	draw_radials=false;
	draw_chords=true;
	draw_cross_chords=true;
	
var
	axis,tangent,center_line:xyz_line_type;
	theta:real;
	w:real;
	step:integer;
	pt,pc:xy_point_type;
	line:xy_line_type;
	ic:xy_point_type;
	perimeter:array of xy_point_type;
	
begin
{
	If the number of points is zero, we call the complete projection routine.
}
	if num_points=0 then scam_project_sphere_complete(ip,sphere,camera);
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
	center_line.direction:=xyz_difference(sphere.center,camera.pivot);
	theta:=arcsin(sphere.radius/xyz_length(center_line.direction));
	axis.point:=camera.pivot;
	axis.direction:=xyz_perpendicular(center_line.direction);
	tangent.point:=xyz_axis_rotate(sphere.center,axis,theta);
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
	setlength(perimeter,num_points);
	for step:=0 to num_points-1 do begin
		pt:=bcam_image_position(tangent.point,camera);
		perimeter[step].x:=pt.x/w-ccd_origin_x;
		perimeter[step].y:=pt.y/w-ccd_origin_y;
		tangent.point:=xyz_axis_rotate(tangent.point,center_line,2*pi/num_points);
		tangent.direction:=xyz_difference(tangent.point,camera.pivot);
	end;
{
	Draw the perimiter by joining points with lines. If draw_radials, we draw a line
	from each perimeter point to the center. If draw_chords, we draw parallel lines
	between opposite perimeter points.
}	
	pc:=bcam_image_position(sphere.center,camera);
	ic.x:=pc.x/w-ccd_origin_x;
	ic.y:=pc.y/w-ccd_origin_y;
	for step:=0 to num_points-1 do begin
		if draw_perimeter then begin
			line.a:=perimeter[step];		
			line.b:=perimeter[(step+1) mod num_points];
			draw_overlay_xy_line(ip,line,scam_sphere_color);
		end;
		
		if draw_chords and (step<=num_points/2) then begin
			line.a:=perimeter[step];		
			line.b:=perimeter[num_points-step-1];
			draw_overlay_xy_line(ip,line,scam_sphere_color);
		end;	
			
		if draw_cross_chords and (step<=num_points/2) then begin
			line.a:=perimeter[step+round(num_points/4)];		
			line.b:=perimeter[(num_points+round(num_points/4)-step-1) mod num_points];
			draw_overlay_xy_line(ip,line,scam_sphere_color);
		end;

		if draw_radials then begin
			line.a:=perimeter[step];		
			line.b:=ic;
			draw_overlay_xy_line(ip,line,scam_sphere_color);
		end;
	end;
end;

{
	scam_project_cylinder takes a cylinder in SCAM coordinates and draws the
	outline of its projection onto the image plane of a camera, then attempts to
	fill in the outline with lines. The num_points parameter tells the routine
	how many points around the perimiter of the cylinder faces it should project
	into the image plane. The routine operates in such a way that if the length
	of the cylinder is zero, the routine draws a single ellipse. If we pass zero
	for num_points, the routine calls scam_project_cylinder_complete.
}
procedure scam_project_cylinder(ip:image_ptr_type;
	cylinder:scam_cylinder_type;
	camera:bcam_camera_type;
	num_points:integer);
	
const
	draw_perimeter=true;
	draw_axials=true;
	draw_chords=true;
	draw_cross_chords=true;
	draw_radials=false;
	
var
	step:integer;
	point_a,point_b,center_a,center_b,radial:xyz_point_type;
	w:real;
	projection:xy_point_type;
	perimeter_a,perimeter_b:array of xy_point_type;
	ica,icb:xy_point_type;
	line:xy_line_type;
	axis:xyz_line_type;
	pc:xy_point_type;

begin
{
	If the number of points is zero, we call the complete projection routine.
}
	if num_points=0 then scam_project_cylinder_complete(ip,cylinder,camera);
{
	Find a point on the circumference of the first end of the cylinder.
}
	cylinder.face.normal:=xyz_unit_vector(cylinder.face.normal);
	radial:=xyz_scale(
		xyz_perpendicular(cylinder.face.normal),
		cylinder.radius);
	point_a:=xyz_sum(cylinder.face.point,radial);
	center_a:=cylinder.face.point;
	axis.point:=cylinder.face.point;
	axis.direction:=xyz_scale(cylinder.face.normal,cylinder.length);
{
	Find the matching point and center on the opposite end of the cylinder.
	These two points are joined by a line parallel to the cylinder axis, of
	length equal to the cylinder length, which could be zero or negative.
}
	point_b:=xyz_sum(point_a,axis.direction);
	center_b:=xyz_sum(center_a,axis.direction);
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
	Rotate our cicumference points about the cylinder axis. Project them both
	into the image plane and store in two arrays, one for the a-face, one for
	the b-face. Our objective is to produce num_points pairs of points along the
	perimeter of the two faces of the cylinder.
}
	setlength(perimeter_a,num_points);
	setlength(perimeter_b,num_points);
	for step:=0 to num_points-1 do begin
		projection:=bcam_image_position(point_a,camera);
		perimeter_a[step].x:=projection.x/w-ccd_origin_x;
		perimeter_a[step].y:=projection.y/w-ccd_origin_y;
		
		projection:=bcam_image_position(point_b,camera);
		perimeter_b[step].x:=projection.x/w-ccd_origin_x;
		perimeter_b[step].y:=projection.y/w-ccd_origin_y;
		
		point_a:=xyz_axis_rotate(point_a,axis,2*pi/num_points);
		point_b:=xyz_axis_rotate(point_b,axis,2*pi/num_points);
	end;
{
	Draw lines between the circumference points on the image plane, and also
	radials and chords in the faces themselves, as directed by flags.
}
	pc:=bcam_image_position(center_a,camera);
	ica.x:=pc.x/w-ccd_origin_x;
	ica.y:=pc.y/w-ccd_origin_y;
	pc:=bcam_image_position(center_b,camera);
	icb.x:=pc.x/w-ccd_origin_x;
	icb.y:=pc.y/w-ccd_origin_y;
	for step:=0 to num_points-1 do begin
	
		if draw_perimeter then begin
			line.a:=perimeter_a[step];		
			line.b:=perimeter_a[(step+1) mod num_points];
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
			line.a:=perimeter_b[step];		
			line.b:=perimeter_b[(step+1) mod num_points];
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
		end;
				
		if draw_axials then begin
			line.a:=perimeter_a[step];
			line.b:=perimeter_b[step];
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
		end;
	
		if draw_chords and (step<=num_points/2) then begin
			line.a:=perimeter_a[step];		
			line.b:=perimeter_a[num_points-step-1];
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
			line.a:=perimeter_b[step];		
			line.b:=perimeter_b[num_points-step-1];
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
		end;
		
		if draw_radials then begin
			line.a:=perimeter_a[step];		
			line.b:=ica;
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
			line.a:=perimeter_b[step];		
			line.b:=icb;
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
		end;

		if draw_cross_chords and (step<=num_points/2) then begin
			line.a:=perimeter_a[step+round(num_points/4)];		
			line.b:=perimeter_a[(num_points+round(num_points/4)-step-1) mod num_points];
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
			line.a:=perimeter_b[step+round(num_points/4)];		
			line.b:=perimeter_b[(num_points+round(num_points/4)-step-1) mod num_points];
			draw_overlay_xy_line(ip,line,scam_cylinder_color);
		end;
	end;
end;

{
	scam_project_shaft takes a shaft in SCAM coordinates and draws the outline
	of its projection onto the image plane of a camera, then attempts to fill in
	the outline with lines. The num_points parameter tells the routine how many
	points around the perimiter of each shaft face it should project.
}
procedure scam_project_shaft(ip:image_ptr_type;
	shaft:scam_shaft_type;
	camera:bcam_camera_type;
	num_points:integer);
	
const
	draw_perimeter=true;
	draw_axials=true;
	draw_radials=false;
	
var
	step,face_num:integer;
	point_a,point_b,center_a,center_b,radial:xyz_point_type;
	w:real;
	projection:xy_point_type;
	perimeter_a,perimeter_b:array of xy_point_type;
	ica,icb:xy_point_type;
	line:xy_line_type;
	axis:xyz_line_type;
	pc:xy_point_type;

begin
debug_log('entering');
{
	If the number of points is zero, or the number of faces is zero, exit.
}
	if num_points=0 then exit;
	if shaft.num_faces<=0 then exit;
{
	Make sure the shaft axis direction is a unit vector.
}
	shaft.axis.direction:=xyz_unit_vector(shaft.axis.direction);
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
	Progress through the faces, drawing each perimeter, then joining perimeter points
	to the perimeter points of the previous face, if it exists. See comments in the
	cylinder projection routine for details of the calculation.
}
	for face_num:=0 to shaft.num_faces-1 do begin
		setlength(perimeter_a,num_points);
		with shaft do begin
			radial:=xyz_scale(xyz_perpendicular(axis.direction),radius[face_num]);
			center_a:=xyz_sum(
				axis.point,
				xyz_scale(axis.direction,center[face_num]));
			point_a:=xyz_sum(center_a,radial);
			
			for step:=0 to num_points-1 do begin
				projection:=bcam_image_position(point_a,camera);
				perimeter_a[step].x:=projection.x/w-ccd_origin_x;
				perimeter_a[step].y:=projection.y/w-ccd_origin_y;
				point_a:=xyz_axis_rotate(point_a,axis,2*pi/num_points);
			end;
			
			pc:=bcam_image_position(center_a,camera);
			ica.x:=pc.x/w-ccd_origin_x;
			ica.y:=pc.y/w-ccd_origin_y;

			for step:=0 to num_points-1 do begin
				if draw_perimeter then begin
					line.a:=perimeter_a[step];		
					line.b:=perimeter_a[(step+1) mod num_points];
					draw_overlay_xy_line(ip,line,scam_cylinder_color);
				end;
				
				if draw_radials then begin
					line.a:=perimeter_a[step];		
					line.b:=ica;
					draw_overlay_xy_line(ip,line,scam_cylinder_color);
				end;
				
				if (face_num>0) and draw_axials then begin
					line.a:=perimeter_a[step];
					line.b:=perimeter_b[step];
					draw_overlay_xy_line(ip,line,scam_cylinder_color);
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

{
	scam_disagreement_spread measures the disagreement between a silhouette and a
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
	projection disagree.
	
	The routine returns a measures of the disagreement between the image and
	projections. To obtain the disagreement we use the intensity threshold, "t",
	the pixel intensity "b", the minimum intensity in the image, "m", and the
	specified spread. We let e = (t-m)*spread. If the projected object occupies
	the pixel, we use the following three rules. If b < t-e, we add 0.0 to the
	disagreement. If b > t+e we add 1.0. In between we add (b-t+e)/2e. When the
	projected object does not occupy the pixel, we use the following three
	rules. If b > t+e we add 0.0. If b < t-e we add one. In between we add
	(t+e-b)/2e. We add the disagreement of all pixels together to obtain the
	total disagreement. With spread=0, the disagreement is the number of pixels
	that are silhouette or projection but not both, using a binary threshold. 
}
function scam_disagreement_spread(ip:image_ptr_type;threshold,spread:real):real;

var
	i,j:integer;
	t,b,e,d,m:real;
	p:boolean;
	
begin
	d:=0;
	m:=image_minimum(ip);
	t:=threshold;
	e:=(t-m)*spread;
	with ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				p:=(get_ov(ip,j,i)<>clear_color);
				b:=get_px(ip,j,i);
				if p then begin
					if b>t+e then d:=d+1.0
					else if (b>t-e) then d:=d+(b-t+e)/(2.0*e);
				end else begin
					if b<t-e then d:=d+1.0
					else if (b<t+e) then d:=d+(t-b+e)/(2.0*e);
				end;
				if (b<=t) then begin
					if not p then set_ov(ip,j,i,scam_silhouette_color)
					else set_ov(ip,j,i,clear_color);
				end;
			end;
		end;
	end;
	scam_disagreement_spread:=d;
end;


end.

