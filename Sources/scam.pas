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
	scam_sphere_outline_color=green_color;
	scam_cylinder_color=blue_color;
	scam_cylinder_outline_color=blue_color;
	scam_silhouette_color=orange_color;
{
	Projection of outlines.
}
	scam_num_tangents=100;

{
	Routines that project hypothetical objects onto the overlays of our SCAM
	images. We pass an image pointer to the routines, and the routine works on
	this image. We specify an object in SCAM coordinates and we give the
	calibration of the camera in SCAM coordinates too.
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:xyz_sphere_type;
	camera:bcam_camera_type);
procedure scam_project_cylinder(ip:image_ptr_type;
	cylinder:xyz_cylinder_type;
	camera:bcam_camera_type);
procedure scam_project_sphere_outline(ip:image_ptr_type;
	sphere:xyz_sphere_type;
	camera:bcam_camera_type);
procedure scam_project_cylinder_outline(ip:image_ptr_type;
	cylinder:xyz_cylinder_type;
	camera:bcam_camera_type);
	
{
	Routines that analyze the image.
}
function scam_decode_rule(ip:image_ptr_type;rule:string):real;
function scam_disagreement(ip:image_ptr_type;threshold,spread:real):real;

implementation

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
	scam_project_sphere takes a sphere in SCAM coordinates and projects it onto
	the image plane of a camera. The image plane's center and pixel size are
	specified by the sensor code in the camera record. The routine draws in the
	overlay, not the actual image. It represents the projection as a solid fill
	in the sphere color.
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:xyz_sphere_type;
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
	scam_project_cylinder does for cylinders what scam_project_sphere does for
	spheres. We get a solid fill in the cylinder color in the overlay.
}
procedure scam_project_cylinder(ip:image_ptr_type;
	cylinder:xyz_cylinder_type;
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
	scam_project_sphere_outline takes a sphere in SCAM coordinates and draws the
	outline of its projection onto the image plane of a camera. The routine
	draws in the overlay, not the actual image. It represents the outline with a
	finite number of straight lines joining points on the projection's
	perimeter.
}
procedure scam_project_sphere_outline(ip:image_ptr_type;
	sphere:xyz_sphere_type;
	camera:bcam_camera_type);
	
const
	draw_radials=true;
	
var
	unit_x:xyz_point_type;
	axis,tangent,center_line:xyz_line_type;
	theta:real;
	w:real;
	step:integer;
	pt,pc:xy_point_type;
	line:ij_line_type;
	ic:ij_point_type;
	
begin
{
	Find a tangent to the sphere that intersects the pivot point of the camera.
	We start by constructing a line from the pivot point to the sphere center.
	We obtain the angle between the tangent and the center line. We rotate the
	sphere center about an axis perpendicular to the center line and passing
	through the camera pivot point. The result is our tangent point, which is
	not the point of contact of the tangent on the sphere, but slightly farter
	along the tangent from the pivot point. The tangent line is the line passing
	through the pivot point in the direction of the tangent point. 
}
	center_line.point:=camera.pivot;
	center_line.direction:=xyz_difference(sphere.center,camera.pivot);
	theta:=arcsin(sphere.radius/xyz_length(center_line.direction));
	with unit_x do begin x:=1; y:=0; z:=0; end;
	axis.point:=camera.pivot;
	axis.direction:=xyz_cross_product(center_line.direction,unit_x);
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
	image plane and draw a line to the center of the circle.
}
	pc:=bcam_image_position(sphere.center,camera);
	ic.i:=round(pc.x/w-ccd_origin_x);
	ic.j:=round(pc.y/w-ccd_origin_y);
	for step:=0 to scam_num_tangents do begin
		pt:=bcam_image_position(tangent.point,camera);
		line.a.i:=round(pt.x/w-ccd_origin_x);
		line.a.j:=round(pt.y/w-ccd_origin_y);
		if step>0 then
			draw_overlay_line(ip,line,scam_sphere_outline_color);
		if draw_radials then begin
			line.b:=ic;
			draw_overlay_line(ip,line,scam_sphere_outline_color);
		end;
		line.b:=line.a;
		tangent.point:=xyz_axis_rotate(tangent.point,center_line,2*pi/scam_num_tangents);
		tangent.direction:=xyz_difference(tangent.point,camera.pivot);
	end;
end;

{
	scam_project_cylinder_outline takes a cylinder in SCAM coordinates and draws
	the outline of its projection onto the image plane of a camera. The routine
	operates in such a way that if the length of the cylinder is zero, the routine
	draws a single ellipse.
}
procedure scam_project_cylinder_outline(ip:image_ptr_type;
	cylinder:xyz_cylinder_type;
	camera:bcam_camera_type);
	
var
	step:integer;
	unit_x,point_a,point_b:xyz_point_type;
	radial,axis:xyz_line_type;
	w:real;
	projection:xy_point_type;
	line_a,line_b,line_c:ij_line_type;

begin
{
	Find a point on the circumference of the first end of the cylinder.
}
	radial.point:=cylinder.face.point;
	cylinder.face.normal:=xyz_unit_vector(cylinder.face.normal);
	axis.point:=cylinder.face.point;
	axis.direction:=cylinder.face.normal;
	with unit_x do begin x:=1; y:=0; z:=0; end;
	radial.direction:=
		xyz_scale(xyz_cross_product(axis.direction,unit_x),cylinder.radius);
	point_a:=xyz_sum(radial.point,radial.direction);
{
	Find the matching point on the opposite end of the cylinder. These two
	points are joined by a line parallel to the cylinder axis, of length equal
	to the cylinder length, which could be zero or negative.
}
	point_b:=xyz_sum(point_a,xyz_scale(cylinder.face.normal,cylinder.length));
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
	Rotate our cicumference point about the cylinder axis. Construct for each
	cylinder point its opposite point on the second face. Project both points
	onto the image plane and draw a line from one to the other in the overlay.
}
	for step:=0 to scam_num_tangents do begin
		projection:=bcam_image_position(point_a,camera);
		line_a.b.i:=round(projection.x/w-ccd_origin_x);
		line_a.b.j:=round(projection.y/w-ccd_origin_y);
		if step=0 then line_a.a:=line_a.b;
		draw_overlay_line(ip,line_a,scam_cylinder_outline_color);

		projection:=bcam_image_position(point_b,camera);
		line_b.b.i:=round(projection.x/w-ccd_origin_x);
		line_b.b.j:=round(projection.y/w-ccd_origin_y);
		if step=0 then line_b.a:=line_b.b;
		draw_overlay_line(ip,line_b,scam_cylinder_outline_color);

		line_c.a:=line_a.b;
		line_c.b:=line_b.b;
		draw_overlay_line(ip,line_c,scam_cylinder_outline_color);		

		line_a.a:=line_a.b;
		line_b.a:=line_b.b;

		point_a:=xyz_axis_rotate(point_a,axis,2*pi/scam_num_tangents);
		point_b:=xyz_axis_rotate(point_b,axis,2*pi/scam_num_tangents);
	end;
end;

{
	scam_disagreement measures the disagreement between a silhouette and a
	collection of projected objets. So far as the routine is concerned, a pixel
	is part of a projection if and only if its overlay is some color other than
	clear. A pixel is part of a silhouette if and only if its intensity is less
	than the specified threshold. When a pixel is occupied by silhouette and
	projection, we clear its overlay, to show there is no disagreement. If it is
	occupied by neither silhouette nor projection, we leave its overlay clear,
	to show there is no disagreement. If it is silhouette but not projection, we
	mark its overlay with the silhouette color to show disagreement. If it is
	projection but not silhouette, we leave its overlay marked with the
	projection color to show disagreement. We will see clear overlay where
	projection and classification agree, and colored overlay otherwise.
	
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
function scam_disagreement(ip:image_ptr_type;threshold,spread:real):real;

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
	scam_disagreement:=d;
end;


end.

