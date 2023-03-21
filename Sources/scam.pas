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

interface

uses
	utils,images,transforms,bcam;
		
type
{
	scam_camera_type gives the pivot point coordinates, the coordinates of the
	center of the ccd, and the rotation about x, y, and z of the ccd. All
	coordinates are in SCAM coordinates, which are defined with respect to the
	scam mounting balls in the same way we define bcam coordinates with respect
	to bcam mounting balls. Rotation (0, 0, 0) is when the ccd is in an x-y scam
	plane, with the image sensor x-axis parallel to the SCAM x-axis and the image
	sensor y-axis is parallel and opposite to the SCAM y-axis.
}
	scam_camera_type=record
		pivot:xyz_point_type;{scam coordinates of pivot point in mm}
		sensor:xyz_point_type;{scam coordinates of sensor reference point in mm}
		rot:xyz_point_type;{rotation of ccd about x, y, z in rad}
		reference_point:xy_point_type;{from sensor top-left corner in mm}
		pixel_size:real;{width and height of a sensor pixel in mm}
		id:string;{identifier}
	end;
	
{
	Coordinate transformations. The SCAM coordinates are the mount coordinates
	of the SCAM mount. We define with respect to its kinematic cone, slot flat
	in the same way we do for BCAMs. See bcam_coordinates_from_mount for
	details. Image coordinates are in millimeters from the top-left corner of
	the image sensor. Global coordinates are those in which we express the
	position of the SCAM mounting balls and of the objects the SCAMs see in
	front of a backlight to generate silhouette images.
}	
function scam_ray(p:xy_point_type;camera:scam_camera_type):xyz_line_type;
function scam_coordinates_from_mount(mount:kinematic_mount_type):coordinates_type;
function scam_from_image_point(p:xy_point_type;camera:scam_camera_type):xyz_point_type;
function image_from_scam_point(p:xyz_point_type;camera:scam_camera_type):xy_point_type;
function scam_from_global_vector(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
function scam_from_global_point(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
function scam_from_global_line(b:xyz_line_type;mount:kinematic_mount_type):xyz_line_type;
function scam_from_global_plane(p:xyz_plane_type;mount:kinematic_mount_type):xyz_plane_type;
function global_from_scam_vector(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
function global_from_scam_point(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
function global_from_scam_line(b:xyz_line_type;mount:kinematic_mount_type):xyz_line_type;
function global_from_scam_plane(p:xyz_plane_type;mount:kinematic_mount_type):xyz_plane_type;

{
	Routines to read and write camera parameters from and to strings.
}
function nominal_scam_camera(code:integer):scam_camera_type;
function read_scam_camera(var f:string):scam_camera_type;
function scam_camera_from_string(s:string):scam_camera_type;
function string_from_scam_camera(camera:scam_camera_type):string;

{
	Routines that project hypothetical objects in SCAM coordinates onto SCAM
	image sensors to produce simulated views of the hypothetical objects. We
	pass an image pointer to the routines, and the routine works on this image.
	We specify an object in SCAM coordinates and we give the calibration of the
	SCAM itself, which is also in SCAM coordinates.
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:xyz_sphere_type;
	camera:scam_camera_type);
procedure scam_project_cylinder(ip:image_ptr_type;
	cylinder:xyz_cylinder_type;
	camera:scam_camera_type);


implementation

const
{
	The reference point in the image is the point that we use as the center of
	the sensor when we express the geometry of a camera in mount coordinates. We
	give the default value here, in millimeters. These values are for the ICX424.
}
	reference_x_default=2.590; 
	reference_y_default=1.924;
	pixel_size_default=0.0074;
{
	Colors for various shapes.
}
	sphere_color=green_color;
	cylinder_color=blue_color;
	
{
	read_scam_camera reads a camera type from a string. It assumes that the pivot and
	sensor coordinates are in millimeters, and leaves them in millimeters. It assumes
	the rotation is in milliradians, but converts them to radians. It assumes the
	reference point and pixel size are in microns, and leaves them in microns.
}
function read_scam_camera(var f:string):scam_camera_type;

var 
	camera:scam_camera_type;

begin
	with camera do begin
		id:=read_word(f);
		pivot:=read_xyz(f);
		sensor:=read_xyz(f);
		rot:=read_xyz(f);
		with rot do begin
			x:=x/mrad_per_rad;
			y:=y/mrad_per_rad;
			z:=z/mrad_per_rad;
		end;
		reference_point:=read_xy(f);
		pixel_size:=read_real(f);
	end;
	read_scam_camera:=camera;
end;

{
	scam_camera_from_string converts a string into a scam_camera_type.
}
function scam_camera_from_string(s:string):scam_camera_type;
begin
	scam_camera_from_string:=read_scam_camera(s);
end;

{
	string_from_scam_camera appends a camera type to a string, using only one line. It
	converts rotation in radians into milliradians. 
}
function string_from_scam_camera(camera:scam_camera_type):string;
	
const 
	fsr=1;fsd=4;fsdr=3;fss=4;

var 
	f:string='';

begin
	with camera do begin
		writestr(f,f,id,' ');
		with pivot do 
			writestr(f,f,x:fsr:fsd,' ',y:fsr:fsd,' ',z:fsr:fsd,' ');
		with sensor do 
			writestr(f,f,x:fsr:fsd,' ',y:fsr:fsd,' ',z:fsr:fsd,' ');
		with rot do 
			writestr(f,f,x*mrad_per_rad:9:fsdr,' ',
				y*mrad_per_rad:7:fsdr,' ',
				z*mrad_per_rad:8:fsdr,' ');
		with reference_point do
			writestr(f,f,x:fsr:fsdr,' ',y:fsr:fsdr,' ');
		writestr(f,f,pixel_size:fsr:fsdr);
	end;
	string_from_scam_camera:=f;
end;

{
	scam_origin returns the origin of the SCAM coordinates for the specified mounting balls.
}
function scam_origin(mount:kinematic_mount_type):xyz_point_type;

begin
	scam_origin:=mount.cone;
end;

{
	scam_coordinates_from_mount takes the global coordinates of the SCAM mounting
	balls and calculates the origin and axis unit vectors of the SCAM coordinate
	system expressed in global coordinates. We define SCAM coordinates in the
	same way as bcam coordinates, so we just call the bcam routine that
	generates these coordinates, and use its result.
}
function scam_coordinates_from_mount(mount:kinematic_mount_type):coordinates_type;
	
begin
	scam_coordinates_from_mount:=bcam_coordinates_from_mount(mount);
end;

{
	scam_from_global_vector converts a direction in global coordinates into a 
	direction in SCAM coordinates.
}
function scam_from_global_vector(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;

var
	M:xyz_matrix_type;
	scam:coordinates_type;
	
begin
	scam:=scam_coordinates_from_mount(mount);
	M:=xyz_matrix_from_points(scam.x_axis,scam.y_axis,scam.z_axis);
	scam_from_global_vector:=xyz_transform(M,p);
end;


{
	scam_from_global_point converts a point in global coordinates into a point
	in SCAM coordinates.
}
function scam_from_global_point (p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;

begin
	scam_from_global_point:=scam_from_global_vector(xyz_difference(p,scam_origin(mount)),mount);
end;

{
	global_from_scam_vector converts a direction in SCAM coordinates into a
	direction in global coordinates.
}
function global_from_scam_vector(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
var bc:coordinates_type;	
begin
	bc:=scam_coordinates_from_mount(mount);
	global_from_scam_vector:=
		xyz_transform(
			xyz_matrix_inverse(
				xyz_matrix_from_points(bc.x_axis,bc.y_axis,bc.z_axis)),
			p);
end;

{
	global_from_scam_point converts a point in SCAM coordinates into a point in
	global coordinates.
}
function global_from_scam_point(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;

begin
	global_from_scam_point:=xyz_sum(scam_origin(mount),global_from_scam_vector(p,mount));
end;

{
	global_from_scam_line converts a bearing (point and direction) in SCAM coordinates into
	a bearing in global coordinates.
}
function global_from_scam_line(b:xyz_line_type;mount:kinematic_mount_type):xyz_line_type;

var
	gb:xyz_line_type;
	
begin
	gb.point:=global_from_scam_point(b.point,mount);
	gb.direction:=global_from_scam_vector(b.direction,mount);
	global_from_scam_line:=gb;
end;

{
	scam_from_global_line does the opposite of global_from_scam_line
}
function scam_from_global_line(b:xyz_line_type;mount:kinematic_mount_type):xyz_line_type;

var
	bb:xyz_line_type;
	
begin
	bb.point:=scam_from_global_point(b.point,mount);
	bb.direction:=scam_from_global_vector(b.direction,mount);
	scam_from_global_line:=bb;
end;

{
	global_from_scam_plane converts a plane in SCAM coordinates into a plane
	global coordinates.
}
function global_from_scam_plane(p:xyz_plane_type;mount:kinematic_mount_type):xyz_plane_type;

var
	gp:xyz_plane_type;
	
begin
	gp.point:=global_from_scam_point(p.point,mount);
	gp.normal:=global_from_scam_vector(p.normal,mount);
	global_from_scam_plane:=gp;
end;

{
	scam_from_global_plane does the opposite of global_from_scam_plane
}
function scam_from_global_plane(p:xyz_plane_type;mount:kinematic_mount_type):xyz_plane_type;

var
	bp:xyz_plane_type;
	
begin
	bp.point:=scam_from_global_point(p.point,mount);
	bp.normal:=scam_from_global_vector(p.normal,mount);
	scam_from_global_plane:=bp;
end;

{
	scam_from_image_point converts a point on the ccd into a point in SCAM coordinates. 
	The calculation takes account of the orientation of the ccd in the camera.
}
function scam_from_image_point(p:xy_point_type;camera:scam_camera_type):xyz_point_type;

var
	q:xyz_point_type;
	
begin
	q.z:=0;
	q.x:=p.x-camera.reference_point.x;
	q.y:=-(p.y-camera.reference_point.y);
	q:=xyz_rotate(q,camera.rot);
	q:=xyz_sum(q,camera.sensor);
	scam_from_image_point:=q;
end;

{
	image_from_scam_point converts a point in SCAM coordinates into a point in
	image coordinates. The SCAM point can lie in the image, but it does not
	have to. We make a line out of the point and the SCAM pivot, and 
	intersect this line with the image plane to obtain the point on the image
	plane that marks the image of the SCAM point. Thus we can use this routine 
	to figure out where the image of an object will lie on the image sensor.
}
function image_from_scam_point(p:xyz_point_type;camera:scam_camera_type):xy_point_type;

var
	plane:xyz_plane_type;
	ray:xyz_line_type;
	normal_point,q:xyz_point_type;
	r:xy_point_type;
	
begin
	r.x:=camera.reference_point.x;
	r.y:=camera.reference_point.y;
	plane.point:=scam_from_image_point(r,camera);
	with normal_point do begin x:=0; y:=0; z:=1; end;
	normal_point:=xyz_rotate(normal_point,camera.rot);
	normal_point:=xyz_sum(normal_point,camera.sensor);
	plane.normal:=xyz_difference(normal_point,plane.point);
	ray.point:=camera.pivot;
	ray.direction:=xyz_difference(p,camera.pivot);
	q:=xyz_line_plane_intersection(ray,plane);
	q:=xyz_difference(q,camera.sensor);
	q:=xyz_unrotate(q,camera.rot);
	r.x:=camera.reference_point.x+q.x;
	r.y:=camera.reference_point.y-q.y;
	image_from_scam_point:=r;
end;

{
	scam_ray returns the ray that passes through the camera pivot point and
	strikes the ccd at a point in the ccd. We specify a point in the ccd with
	parameter "p", which is given in image coordinates. We specify the camera
	calibration constants with the "camera" parameter. The routine gives the ray
	with the pivot point and a vector parallel to the ray.
}
function scam_ray(p:xy_point_type;camera:scam_camera_type):xyz_line_type;

var
	ray:xyz_line_type;
	image:xyz_point_type;
	
begin
	image:=scam_from_image_point(p,camera);
	ray.point:=camera.pivot;
	ray.direction:=xyz_difference(camera.pivot,image);
	scam_ray:=ray;
end;

{
	nominal_scam_camera returns the nominal scam_camera_type.
}
function nominal_scam_camera(code:integer):scam_camera_type;

var
	camera:scam_camera_type;
	
begin
	with camera do begin
		case code of
			1:begin
				id:='scam1';
				pivot.x:=0;
				pivot.y:=0;
				pivot.z:=0;
				rot.x:=0;
				rot.y:=0;
				rot.z:=0;
				sensor.x:=pivot.x;
				sensor.y:=pivot.y;
				sensor.z:=pivot.z-25;
				reference_point.x:=reference_x_default; 
				reference_point.y:=reference_y_default;
				pixel_size:=pixel_size_default;
			end;
			otherwise begin
				id:='scam0';
				pivot:=xyz_origin;
				rot:=xyz_origin;
				sensor.x:=0;
				sensor.y:=0;
				sensor.z:=-1;
				reference_point:=xy_origin; 
				pixel_size:=0.01;
			end;
		end;
	end;
	nominal_scam_camera:=camera;
end;

{
	scam_project_sphere takes a sphere in SCAM coordinates and projects it onto the
	image sensor of a camera. The image sensor's center and pixel size are specified by
	the camera parameters. The pixels of the image sensor we obtain from the image, 
	which defines its own width and height. The routine draws in the overlay, not the
	actual image. I draws only within the analysis boundaries.
}
procedure scam_project_sphere(ip:image_ptr_type;
	sphere:xyz_sphere_type;
	camera:scam_camera_type);
var
	i,j:integer;
	q:xy_point_type;
	r:xyz_point_type;
begin
	with ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				q.x:=(i+ccd_origin_x)*camera.pixel_size;
				q.y:=(j+ccd_origin_y)*camera.pixel_size;
				if xyz_line_crosses_sphere(scam_ray(q,camera),sphere) then
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
	camera:scam_camera_type);
var
	i,j:integer;
	q:xy_point_type;
	r:xyz_point_type;
begin
	with ip^.analysis_bounds do begin
		for j:=top to bottom do begin
			for i:=left to right do begin
				q.x:=(i+ccd_origin_x)*camera.pixel_size;
				q.y:=(j+ccd_origin_y)*camera.pixel_size;
				if xyz_line_crosses_cylinder(scam_ray(q,camera),cylinder) then
					set_ov(ip,j,i,cylinder_color);
			end;
		end;
	end;
end;

end.

