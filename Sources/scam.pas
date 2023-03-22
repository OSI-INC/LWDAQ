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
		
{
	Routines that project hypothetical objects in SCAM coordinates onto SCAM
	image sensors to produce simulated views of the hypothetical objects. We
	pass an image pointer to the routines, and the routine works on this image.
	We specify an object in SCAM coordinates and we give the calibration of the
	SCAM itself, which is also in SCAM coordinates.
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:xyz_sphere_type;
	camera:bcam_camera_type);
procedure scam_project_cylinder(ip:image_ptr_type;
	cylinder:xyz_cylinder_type;
	camera:bcam_camera_type);


implementation

const
	
{
	Colors for various shapes.
}
	sphere_color=green_color;
	cylinder_color=blue_color;
	
{
	scam_project_sphere takes a sphere in SCAM coordinates and projects it onto the
	image sensor of a camera. The image sensor's center and pixel size are specified by
	the sensor code in the camera_type. The pixels of the image sensor we obtain from the image, 
	which defines its own width and height. The routine draws in the overlay, not the
	actual image. I draws only within the analysis boundaries.
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:xyz_sphere_type;
	camera:bcam_camera_type);
var
	i,j:integer;
	q:xy_point_type;
	r:xyz_point_type;
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
					set_ov(ip,j,i,sphere_color);
			end;
		end;
	end;
end;

{
	scam_project_cylinder does for cylinders what scam_project_sphere does for spheres.
}
procedure scam_project_cylinder(ip:image_ptr_type;
	cylinder:xyz_cylinder_type;
	camera:bcam_camera_type);
var
	i,j:integer;
	q:xy_point_type;
	r:xyz_point_type;
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
					set_ov(ip,j,i,cylinder_color);
			end;
		end;
	end;
end;

end.

