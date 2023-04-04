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
	utils,images,transforms,bcam;
	
const
{
	Classification and projection color codes.
}
	scam_sphere_color=green_color;
	scam_sphere_outline_color=dark_green_color;
	scam_cylinder_color=blue_color;
	scam_silhouette_color=orange_color;

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
	
{
	Routines that analyze the image.
}
function scam_classify(ip:image_ptr_type;rule:string):integer;

implementation

{
	scam_decode_rule takes a string like "10 &" and returns, for
	the specified image, an intensity threshold for backlight pixels in the
	image. The first parameter in the command string must be an integer
	specifying the threshold intensity. The integer may be followed by of the
	symbols *, %, #, $, or &. Each of these symbols gives a different meaning to
	the threshold value, in the same way they do for spot analysis, see the
	spot_decode_command_string for details.
}
function scam_decode_rule(ip:image_ptr_type;rule:string):integer;

const
	percent_unit=100;

var
	word:string;
	background,threshold:integer;
	
begin
{
	Decode the threshold string. First we read the threshold, then we look for a
	valid threshold qualifier.
}
	threshold:=read_integer(rule);
	word:=read_word(rule);
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
	perimiter.
}
procedure scam_project_sphere_outline(ip:image_ptr_type;
	sphere:xyz_sphere_type;
	camera:bcam_camera_type);

var
	i,j:integer;
	q:xy_point_type;
	w:real;
	
begin
end;

{
	scam_classify goes through an image and marks the overlay to show pixels
	that lie within a silhouette image. To classify the image as silhouette or
	background, it uses the rule string, which we interpreet with a
	scam_decode_rule. Where the overlay is clear, it will be filled with the
	silhouette color. Where the overlay is filled already with a projected
	object, it will be cleared in the region of overlap. Once the classification
	is complete, we will see the silhouette and projection colors where the
	image and simulation disagree. We will see the a clear overlay where
	projection and classification agree. As the routine proceeds through the
	image, it counts the number of pixels in which the image and projections
	disagree and returns this count as our measurement of projection error.
}
function scam_classify(ip:image_ptr_type;rule:string):integer;

var
	i,j:integer;
	t:integer;
	count:integer;

begin
	count:=0;
	t:=scam_decode_rule(ip,rule);
	with ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				if get_px(ip,j,i)<=t then begin
					if get_ov(ip,j,i)=clear_color then
						set_ov(ip,j,i,scam_silhouette_color)
					else
						set_ov(ip,j,i,clear_color);
				end;
				if get_ov(ip,j,i)<>clear_color then inc(count)
			end;
		end;
	end;
	scam_classify:=count;
end;

end.

