{
Utilities for Silhouette Camera Image Analysis and Object Location
Copyright (C) 2023 Kevan Hashemi, Open Source Instruments Inc.

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

unit scam;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

interface

uses
	utils,bcam;
	
const
	scam_sensor_x=bcam_icx424_center_x;
	scam_sensor_y=bcam_icx424_center_y;
	
type
{
	scam_camera_type gives the pivot point coordinates, the coordinates of the
	center of the ccd, and the rotation about x, y, and z of the ccd. All
	coordinates are in scam coordinates, which are defined with respect to the
	scam mounting balls in the same way we define bcam coordinates with respect
	to bcam mounting balls. Rotation (0, 0, 0) is when the ccd is in a z-y scam
	plane, with the image sensor x-axis parallel to the scam y-axis and the image
	sensor y-axis is parallel and opposite to the scam z-axis.
}
	scam_camera_type=record
		pivot:xyz_point_type;{scam coordinates of pivot point (mm)}
		sensor:xyz_point_type;{scam coordinates of ccd center}
		rot:xyz_point_type;{rotation of ccd about x, y, z in rad}
		id:string;{identifier}
	end;
{
	scam_wire_type describes a wire in space.
}
	scam_wire_type=record
		position:xyz_point_type;{where the center-line crosses the measurement plane}
		direction:xyz_point_type;{direction cosines of center-line direction}
		radius:real;{radius of wire}
	end;
{
	scam_edge_type describes an edge line on the ccd;
}
	scam_edge_type=record
		position:xy_point_type;{of a point in the edge line, in image coordinates, mm}
		rotation:real;{of the edge line, anticlockwise positive in image, radians}
		side:integer;{0 for wire center, +1 for left edges, -1 for right edges, as seen in image}
	end;
	
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
function nominal_scam_camera(code:integer):scam_camera_type;
function read_scam_camera(var f:string):scam_camera_type;
function scam_camera_from_string(s:string):scam_camera_type;
function string_from_scam_camera(camera:scam_camera_type):string;


implementation

const
	n=3;{three-dimensional space}

{
	read_scam_camera reads a camera type from a string.
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
	end;
	read_scam_camera:=camera;
end;

{
	scam_camera_from_string converts a string into a scam_camera_type;
}
function scam_camera_from_string(s:string):scam_camera_type;
begin
	scam_camera_from_string:=read_scam_camera(s);
end;

{
	string_from_scam_camera appends a camera type to a string, using only one line.
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
				z*mrad_per_rad:8:fsdr);
	end;
	string_from_scam_camera:=f;
end;

{
	scam_origin returns the origin of the scam coordinates for the specified mounting balls.
}
function scam_origin(mount:kinematic_mount_type):xyz_point_type;

begin
	scam_origin:=mount.cone;
end;

{
	scam_coordinates_from_mount takes the global coordinates of the scam mounting
	balls and calculates the origin and axis unit vectors of the scam coordinate
	system expressed in global coordinates. We define scam coordinates in the
	same way as bcam coordinates, so we just call the bcam routine that
	generates these coordinates, and use its result.
}
function scam_coordinates_from_mount(mount:kinematic_mount_type):coordinates_type;
	
begin
	scam_coordinates_from_mount:=bcam_coordinates_from_mount(mount);
end;

{
	scam_from_global_vector converts a direction in global coordinates into a 
	direction in scam coordinates.
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
	in scam coordinates.
}
function scam_from_global_point (p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;

begin
	scam_from_global_point:=scam_from_global_vector(xyz_difference(p,scam_origin(mount)),mount);
end;

{
	global_from_scam_vector converts a direction in scam coordinates into a
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
	global_from_scam_point converts a point in scam coordinates into a point in
	global coordinates.
}
function global_from_scam_point(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;

begin
	global_from_scam_point:=xyz_sum(scam_origin(mount),global_from_scam_vector(p,mount));
end;

{
	global_from_scam_line converts a bearing (point and direction) in scam coordinates into
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
	global_from_scam_plane converts a bearing (point and direction) in scam coordinates into
	a bearing in global coordinates.
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
	scam_from_image_point converts a point on the ccd into a point in scam coordinates. 
	The calculation takes account of the orientation of the ccd in the camera.
}
function scam_from_image_point(p:xy_point_type;camera:scam_camera_type):xyz_point_type;

var
	q:xyz_point_type;
	
begin
	q.x:=0;
	q.y:=p.y-scam_sensor_y;
	q.z:=-(p.x-scam_sensor_x);
	q:=xyz_rotate(q,camera.rot);
	q:=xyz_sum(q,camera.sensor);
	scam_from_image_point:=q;
end;

{
	image_from_scam_point converts a point in scam coordinates into a point in
	image coordinates. The scam point can lie in the image, but it does not
	have to. We make a line out of the point and the scam pivot, and 
	intersect this line with the image plane to obtain the point on the image
	plane that marks the image of the scam point. Thus we can use this routine 
	to figure out where the image of an object will lie on the image sensor.
}
function image_from_scam_point(p:xyz_point_type;camera:scam_camera_type):xy_point_type;

var
	plane:xyz_plane_type;
	ray:xyz_line_type;
	normal_point,q:xyz_point_type;
	r:xy_point_type;
	
begin
	r.x:=scam_sensor_x;
	r.y:=scam_sensor_y;
	plane.point:=scam_from_image_point(r,camera);
	with normal_point do begin x:=1; y:=0; z:=0; end;
	normal_point:=xyz_rotate(normal_point,camera.rot);
	normal_point:=xyz_sum(normal_point,camera.sensor);
	plane.normal:=xyz_difference(normal_point,plane.point);
	ray.point:=camera.pivot;
	ray.direction:=xyz_difference(p,camera.pivot);
	q:=xyz_line_plane_intersection(ray,plane);
	q:=xyz_difference(q,camera.sensor);
	q:=xyz_unrotate(q,camera.rot);
	r.x:=scam_sensor_x-q.z;
	r.y:=scam_sensor_y+q.y;
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
				id:='scam1_A_1';
				pivot.x:=-4.5;
				pivot.y:=87.4;
				pivot.z:=-5;
				rot.x:=-pi/2;
				rot.y:=0;
				rot.z:=-0.541;
				sensor.x:=pivot.x-11.4*cos(rot.z);
				sensor.y:=pivot.y-11.4*sin(rot.z);
				sensor.z:=pivot.z;
			end;
			2:begin
				id:='scam1_A_2';
				pivot.x:=-4.5;
				pivot.y:=37.4;
				pivot.z:=-5;
				rot.x:=+pi/2;
				rot.y:=0;
				rot.z:=+0.541;
				sensor.x:=pivot.x-11.4*cos(rot.z);
				sensor.y:=pivot.y-11.4*sin(rot.z);
				sensor.z:=pivot.z;
			end;
			otherwise begin
				id:='DEFAULT';
				pivot:=xyz_origin;
				sensor.x:=-1;
				sensor.y:=0;
				sensor.z:=0;
				rot:=xyz_origin;
			end;
		end;
	end;
	nominal_scam_camera:=camera;
end;

end.

