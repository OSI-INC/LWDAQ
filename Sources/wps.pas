{
Utilities for WPS Device Calibration and Measurement Transformation
Copyright (C) 2008-2023 Kevan Hashemi, Open Source Instruments Inc.

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

unit wps;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

interface

uses
	utils,bcam;
	
var
	wps_enable_aberration:boolean=false;

const
	wps_sensor_x=bcam_tc255_center_x;
	wps_sensor_y=bcam_tc255_center_y;
	wps_aberration_scale=1000;
	wps_y_ref=1.220;{mm, image sensor reference row position}
	wps_z_ref=-5;{mm, z-coordinate of wire position measurement plane}
	wps_z_shift=5;{mm, shift from z_ref in either direction for fitting}
	
type
{
	wps_camera_type gives the pivot point coordinates, the coordinates of the
	center of the ccd, and the rotation about x, y, and z of the ccd. All
	coordinates are in wps coordinates, which are defined with respect to the
	wps mounting balls in the same way we define bcam coordinates with respect
	to bcam mounting balls. Rotation (0, 0, 0) is when the ccd is in a z-y wps
	plane, with the image sensor x-axis parallel to the wps y-axis and the image
	sensor y-axis is parallel and opposite to the wps z-axis.
}
	wps_camera_type=record
		pivot:xyz_point_type;{wps coordinates of pivot point (mm)}
		sensor:xyz_point_type;{wps coordinates of ccd center}
		rot:xyz_point_type;{rotation of ccd about x, y, z in rad}
		id:string;{identifier}
	end;
{
	wps_wire_type describes a wire in space.
}
	wps_wire_type=record
		position:xyz_point_type;{where the center-line crosses the measurement plane}
		direction:xyz_point_type;{direction cosines of center-line direction}
		radius:real;{radius of wire}
	end;
{
	wps_edge_type describes an edge line on the ccd.
}
	wps_edge_type=record
		position:xy_point_type;{of a point in the edge line, in image coordinates, mm}
		rotation:real;{of the edge line, anticlockwise positive in image, radians}
		side:integer;{0 for wire center, +1 for left edges, -1 for right edges, as seen in image}
	end;
	
function wps_ray(p:xy_point_type;camera:wps_camera_type):xyz_line_type;
function wps_wire_plane(p:xy_point_type;r:real;camera:wps_camera_type):xyz_plane_type;
function wps_wire(p_1,p_2:xy_point_type;r_1,r_2:real;c_1,c_2:wps_camera_type):xyz_line_type;
function wps_calibrate(device_name:string;camera_num:integer;data:string):string;
function wps_coordinates_from_mount(mount:kinematic_mount_type):coordinates_type;
function wps_from_image_point(p:xy_point_type;camera:wps_camera_type):xyz_point_type;
function image_from_wps_point(p:xyz_point_type;camera:wps_camera_type):xy_point_type;
function wps_from_global_vector(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
function wps_from_global_point(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
function wps_from_global_line(b:xyz_line_type;mount:kinematic_mount_type):xyz_line_type;
function wps_from_global_plane(p:xyz_plane_type;mount:kinematic_mount_type):xyz_plane_type;
function global_from_wps_vector(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
function global_from_wps_point(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
function global_from_wps_line(b:xyz_line_type;mount:kinematic_mount_type):xyz_line_type;
function global_from_wps_plane(p:xyz_plane_type;mount:kinematic_mount_type):xyz_plane_type;
function nominal_wps_camera(code:integer):wps_camera_type;
function read_wps_camera(var f:string):wps_camera_type;
function wps_camera_from_string(s:string):wps_camera_type;
function string_from_wps_camera(camera:wps_camera_type):string;
function wps_ray_error(image:xy_point_type;edge_direction:integer;
	wire:wps_wire_type;camera:wps_camera_type):xyz_point_type;
function wps_camera_error(p:xy_point_type;r:real;
	camera:wps_camera_type;
	z_ref:real;
	wire:wps_wire_type):xyz_point_type;
function wps_error(p_1,p_2:xy_point_type;r_1,r_2:real;c_1,c_2:wps_camera_type;
	wire:xyz_line_type;
	z_ref:real):xyz_point_type;


implementation

const
	n=3;{three-dimensional space}

{
	read_wps_camera reads a camera type from a string.
}
function read_wps_camera(var f:string):wps_camera_type;

var 
	camera:wps_camera_type;

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
	read_wps_camera:=camera;
end;

{
	wps_camera_from_string converts a string into a wps_camera_type;
}
function wps_camera_from_string(s:string):wps_camera_type;
begin
	wps_camera_from_string:=read_wps_camera(s);
end;

{
	string_from_wps_camera appends a camera type to a string, using only one line.
}
function string_from_wps_camera(camera:wps_camera_type):string;
	
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
	string_from_wps_camera:=f;
end;

{
	wps_origin returns the origin of the wps coordinates for the specified mounting balls.
}
function wps_origin(mount:kinematic_mount_type):xyz_point_type;

begin
	wps_origin:=mount.cone;
end;

{
	wps_coordinates_from_mount takes the global coordinates of the wps mounting
	balls and calculates the origin and axis unit vectors of the wps coordinate
	system expressed in global coordinates. We define wps coordinates in the
	same way as bcam coordinates, so we just call the bcam routine that
	generates these coordinates, and use its result.
}
function wps_coordinates_from_mount(mount:kinematic_mount_type):coordinates_type;
	
begin
	wps_coordinates_from_mount:=bcam_coordinates_from_mount(mount);
end;

{
	wps_from_global_vector converts a direction in global coordinates into a 
	direction in wps coordinates.
}
function wps_from_global_vector(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;

var
	M:xyz_matrix_type;
	wps:coordinates_type;
	
begin
	wps:=wps_coordinates_from_mount(mount);
	M:=xyz_matrix_from_points(wps.x_axis,wps.y_axis,wps.z_axis);
	wps_from_global_vector:=xyz_transform(M,p);
end;


{
	wps_from_global_point converts a point in global coordinates into a point
	in wps coordinates.
}
function wps_from_global_point (p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;

begin
	wps_from_global_point:=wps_from_global_vector(xyz_difference(p,wps_origin(mount)),mount);
end;

{
	global_from_wps_vector converts a direction in wps coordinates into a
	direction in global coordinates.
}
function global_from_wps_vector(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;
var bc:coordinates_type;	
begin
	bc:=wps_coordinates_from_mount(mount);
	global_from_wps_vector:=
		xyz_transform(
			xyz_matrix_inverse(
				xyz_matrix_from_points(bc.x_axis,bc.y_axis,bc.z_axis)),
			p);
end;

{
	global_from_wps_point converts a point in wps coordinates into a point in
	global coordinates.
}
function global_from_wps_point(p:xyz_point_type;mount:kinematic_mount_type):xyz_point_type;

begin
	global_from_wps_point:=xyz_sum(wps_origin(mount),global_from_wps_vector(p,mount));
end;

{
	global_from_wps_line converts a bearing (point and direction) in wps coordinates into
	a bearing in global coordinates.
}
function global_from_wps_line(b:xyz_line_type;mount:kinematic_mount_type):xyz_line_type;

var
	gb:xyz_line_type;
	
begin
	gb.point:=global_from_wps_point(b.point,mount);
	gb.direction:=global_from_wps_vector(b.direction,mount);
	global_from_wps_line:=gb;
end;

{
	wps_from_global_line does the opposite of global_from_wps_line
}
function wps_from_global_line(b:xyz_line_type;mount:kinematic_mount_type):xyz_line_type;

var
	bb:xyz_line_type;
	
begin
	bb.point:=wps_from_global_point(b.point,mount);
	bb.direction:=wps_from_global_vector(b.direction,mount);
	wps_from_global_line:=bb;
end;

{
	global_from_wps_plane converts a plane in wps coordinates into a bearing in
	global coordinates.
}
function global_from_wps_plane(p:xyz_plane_type;mount:kinematic_mount_type):xyz_plane_type;

var
	gp:xyz_plane_type;
	
begin
	gp.point:=global_from_wps_point(p.point,mount);
	gp.normal:=global_from_wps_vector(p.normal,mount);
	global_from_wps_plane:=gp;
end;

{
	wps_from_global_plane does the opposite of global_from_wps_plane
}
function wps_from_global_plane(p:xyz_plane_type;mount:kinematic_mount_type):xyz_plane_type;

var
	bp:xyz_plane_type;
	
begin
	bp.point:=wps_from_global_point(p.point,mount);
	bp.normal:=wps_from_global_vector(p.normal,mount);
	wps_from_global_plane:=bp;
end;

{
	wps_from_image_point converts a point on the ccd into a point in wps coordinates. 
	The calculation takes account of the orientation of the ccd in the camera.
}
function wps_from_image_point(p:xy_point_type;camera:wps_camera_type):xyz_point_type;

var
	q:xyz_point_type;
	
begin
	q.x:=0;
	q.y:=p.y-wps_sensor_y;
	q.z:=-(p.x-wps_sensor_x);
	q:=xyz_rotate(q,camera.rot);
	q:=xyz_sum(q,camera.sensor);
	wps_from_image_point:=q;
end;

{
	image_from_wps_point converts a point in wps coordinates into a point in
	image coordinates. The wps point can lie in the image, but it does not
	have to. We make a line out of the point and the wps pivot, and 
	intersect this line with the image plane to obtain the point on the image
	plane that marks the image of the wps point. Thus we can use this routine 
	to figure out where the image of an object will lie on the image sensor.
}
function image_from_wps_point(p:xyz_point_type;camera:wps_camera_type):xy_point_type;

var
	plane:xyz_plane_type;
	ray:xyz_line_type;
	normal_point,q:xyz_point_type;
	r:xy_point_type;
	
begin
	r.x:=wps_sensor_x;
	r.y:=wps_sensor_y;
	plane.point:=wps_from_image_point(r,camera);
	with normal_point do begin x:=1; y:=0; z:=0; end;
	normal_point:=xyz_rotate(normal_point,camera.rot);
	normal_point:=xyz_sum(normal_point,camera.sensor);
	plane.normal:=xyz_difference(normal_point,plane.point);
	ray.point:=camera.pivot;
	ray.direction:=xyz_difference(p,camera.pivot);
	q:=xyz_line_plane_intersection(ray,plane);
	q:=xyz_difference(q,camera.sensor);
	q:=xyz_unrotate(q,camera.rot);
	r.x:=wps_sensor_x-q.z;
	r.y:=wps_sensor_y+q.y;
	image_from_wps_point:=r;
end;

{
	wps_ray returns the ray that passes through the camera pivot point
	and strikes the ccd at a point in the ccd. We specify a point in
	the ccd with parameter "p", which is given in image coordinates. 
	We specify the camera calibration constants with the "camera" parameter. 
	The routine gives the ray with the pivot point and a vector 
	parallel to the ray.
}
function wps_ray(p:xy_point_type;camera:wps_camera_type):xyz_line_type;

var
	ray:xyz_line_type;
	image:xyz_point_type;
	
begin
	image:=wps_from_image_point(p,camera);
	ray.point:=camera.pivot;
	ray.direction:=xyz_difference(camera.pivot,image);
	wps_ray:=ray;
end;

{
	wps_wire_plane returns the plane that contains the wire image and
	the camera pivot point. We assume that the wire itself must lie in
	this same plane. We specify a point in the ccd that lies upon the
	wire center with parameter "p", which is given in image coordinates.
	The rotation of the image, counter-clockwise on the sensor, is "r"
	in radians. We specify the camera calibration constants with the
	"camera" parameter. The routine specifies the plane with the pivot
	point and a normal vector it obtains by taking the cross product
	of the ray through "p" and another virtual point in the wire
	image. We perform the cross product so as to produce a normal vector
	that is in the positive z-direction for most wps applications.
}
function wps_wire_plane(p:xy_point_type;r:real;camera:wps_camera_type):xyz_plane_type;

var
	plane:xyz_plane_type;
	ray_1,ray_2:xyz_line_type;
	
begin
	ray_1:=wps_ray(p,camera);
	p.y:=p.y+1;
	p.x:=p.x+1*sin(r);
	ray_2:=wps_ray(p,camera);
	
	plane.point:=camera.pivot;
	plane.normal:=
		xyz_unit_vector(
			xyz_cross_product(
				ray_2.direction,ray_1.direction));
	wps_wire_plane:=plane;
end;

{
	wps_wire returns the wps measurement of a wire's center-line position in wps
	coordinates, given a point on the center-line of the image in both cameras,
	the rotation of the center line in both cameras, and the calibration
	constants of both cameras. The measurement is a line in wps coordinates,
	with a position and a direction. We obtain this line by intersecting the two
	planes defined by each image projected through its camera pivot point.
}
function wps_wire(p_1,p_2:xy_point_type;r_1,r_2:real;c_1,c_2:wps_camera_type):xyz_line_type;

begin
	wps_wire:=xyz_plane_plane_intersection(
		wps_wire_plane(p_1,r_1,c_1),wps_wire_plane(p_2,r_2,c_2));
end;

{
	nominal_wps_camera returns the nominal wps_camera_type.
}
function nominal_wps_camera(code:integer):wps_camera_type;

var
	camera:wps_camera_type;
	
begin
	with camera do begin
		case code of
			1:begin
				id:='WPS1_A_1';
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
				id:='WPS1_A_2';
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
	nominal_wps_camera:=camera;
end;


{
	wps_ray_error returns the distance between a ray defined by the position of an
	edge in an image to the actual position of the edge of the wire, or from the
	center of an image to the center of a wire. We specify left edges with
	edge_direction +1, right edges with -1, and wire centers with 0.
}
function wps_ray_error(image:xy_point_type;edge_direction:integer;
	wire:wps_wire_type;camera:wps_camera_type):xyz_point_type;

var
	ray,guide_ray,center_line,bridge:xyz_line_type;
	guide_vector:xyz_point_type;
	guide_point:xy_point_type;
	
begin
{
	Create a line along the center of the wire.
}
	center_line.point:=wire.position;
	center_line.direction:=wire.direction;
{	
	Create a line through the edge position and the pivot point.
}
	ray:=wps_ray(image,camera);
{
	Determine the shortest bridge between these two lines.
}
	bridge:=xyz_line_line_bridge(ray,center_line);
{
	If we are using the center of an image, we are done.
}
	if edge_direction=0 then begin
		wps_ray_error:=bridge.direction;
	end
{
	Displace the edge position in the direction of the center of the wire
	image and create a new ray that should be on the same side of the first
	ray as the wire center.
}
	else begin
		guide_point.x:=image.x+edge_direction;
		guide_point.y:=image.y;
		guide_ray:=wps_ray(guide_point,camera);
{
	Find the vector from the bridge point on the edge ray to the guide ray.
}
		guide_vector:=xyz_point_line_vector(bridge.point,guide_ray);
{
	If the guide_vector is in roughly the same direction as the bridge, we
	reduce the length of the bridge by one radius of the wire. Otherwise we
	extend the length of the bridge by one wire radius.
}
		if (xyz_dot_product(bridge.direction,guide_vector)>0) then 
			wps_ray_error:=
				xyz_scale(
					xyz_unit_vector(bridge.direction),
					xyz_length(bridge.direction)-wire.radius)
		else 
			wps_ray_error:=
				xyz_scale(
					xyz_unit_vector(bridge.direction),
					xyz_length(bridge.direction)+wire.radius);
	end;
end;

{
	wps_camera_error returns the error in the measurement of the position of a
	wire left edge, center-line, or right edge. We specify the actual position
	and radius of the wire with a wire_type record. We specify the image of the
	left edge, center-line, or right edge with a point and a rotation in image
	coordinates. We specify a left edge, as seen in the image, with
	edge_direction +1, right edges with -1, and a wire center-line with 0. We
	project the line on the image through the camera pivot point using the
	camera calibration constants. We intersect this plane with a reference
	z-plane, and so obtain a measurement line in the z-plane. If we are
	projecting a center-line, we intersect actual center-line with the reference
	z-plane and our error is the vector between this intersection point and our
	measurement line. If we are project a left or right edge, we add or subtract
	a wire radius vector from our center-line error vector to obtain the final
	error vector.
}
function wps_camera_error(p:xy_point_type;
	r:real;
	camera:wps_camera_type;
	z_ref:real;
	wire:wps_wire_type):xyz_point_type;

var
	m_line,center_line:xyz_line_type;
	m_plane:xyz_plane_type;
	error_vector:xyz_point_type;
	wire_point:xyz_point_type;
	z_plane:xyz_plane_type;
	
begin
{
	Construct the reference z-plane.
}
	with z_plane.point do begin x:=0;y:=0;z:=z_ref; end;
	with z_plane.normal do begin x:=0;y:=0;z:=1; end;
{	
	Create the measurement plane that contains the edge line in the image and
	the pivot point. Intersect the measurement plane the reference z-plane to
	obtain our measurement line.
}
	m_plane:=wps_wire_plane(p,r,camera);
	m_line:=xyz_plane_plane_intersection(m_plane,z_plane);
{
	Determine the intersection of the wire center-line and the reference plane.
}
	center_line.point:=wire.position;
	center_line.direction:=wire.direction;
	wire_point:=xyz_line_plane_intersection(center_line,z_plane);
{
	Determine the shortest distance between the center of the wire and our measurement
	line.
}
	error_vector:=xyz_point_line_vector(wire_point,m_line);
{
	If we are using the center of an image, we are done. The error is the vector we
	must add to the actual wire position to get to our measurement line.
}
		wps_camera_error:=error_vector;
end;

{
	wps_error returns the error in wps measurement at a specified z-plane. We
	provide the routine with image points in both cameras, the rotation of the
	wire in both cameras, the camera calibration constants, the actual wire
	position and a reference z-coordinate. We take the wps wire line and the
	actual wire line and intersect them with the z-plane. We return the vector
	in wps coordinates from the actual to the wps wire position.
	
}
function wps_error(p_1,p_2:xy_point_type; {points in wire images}
	r_1,r_2:real; {rotation of wire in image}
	c_1,c_2:wps_camera_type; {camera calibrations}
	wire:xyz_line_type; {actual wire position}
	z_ref:real {reference z-plane in mount coordinates}
	):xyz_point_type;

var
	w_1,w_2:xyz_point_type;
	z_plane:xyz_plane_type;
	
begin
	with z_plane.point do begin x:=0;y:=0;z:=z_ref; end;
	with z_plane.normal do begin x:=0;y:=0;z:=1; end;
	w_1:=xyz_line_plane_intersection(wps_wire(p_1,p_2,r_1,r_2,c_1,c_2),z_plane);
	w_2:=xyz_line_plane_intersection(wire,z_plane);
	wps_error:=xyz_difference(w_1,w_2);
end;

{	
	Wire Position Sensor Calibration. We begin with a data structure required by
	the simplex error function. The structure contains the number of calibration
	positions, N, an array of N wire positions measured by a CMM, and an array
	of N wire centerlines on the WPS camera selected for calibraion.
}
type
	wps_simplex_data=record
		wires:array of wps_wire_type;
		edges:array of wps_edge_type;
		num_points:integer;
	end;
	wps_simplex_data_ptr=^wps_simplex_data;

{
	wps_calibration_error calculates the error of a set of camera calibration
	constants when measuring the locations of a set of well-known pin positions.
	We obtain the calibration error by comparing each wire position to the line
	implied by each image. We use the camera calibration constants to generate
	the lines from the images. We involve the rotation of the wire images in the
	error calculation by generating two lines for each wire image: one from a
	point in the image towards the top of the CCD and another from a point
	towards the bottom of the CCD. The y_shift parameter tells us how much to
	move up and down the image to choose the two points. The generic pointer we
	pass to the routine we use to find a wps_calibrtion_error_data record.
}
function wps_calibration_error(v:simplex_vertex_type;ep:pointer):real;

var
	i:integer;
	sum:real;
	c:wps_camera_type;
	dp:wps_simplex_data_ptr;

begin
	dp:=wps_simplex_data_ptr(ep);
	c.pivot.x:=v[1];
	c.pivot.y:=v[2];
	c.pivot.z:=v[3];
	c.sensor.x:=v[4];
	c.sensor.y:=v[5];
	c.sensor.z:=v[6];
	c.rot.x:=v[7];
	c.rot.y:=v[8];
	c.rot.z:=v[9];
	sum:=0;
	for i:=1 to dp^.num_points do begin
		sum:=sum+sqr(xyz_length(wps_camera_error(
			dp^.edges[i].position,dp^.edges[i].rotation,
			c,wps_z_ref+wps_z_shift,dp^.wires[i])));
		sum:=sum+sqr(xyz_length(wps_camera_error(
			dp^.edges[i].position,dp^.edges[i].rotation,
			c,wps_z_ref-wps_z_shift,dp^.wires[i])));
	end;
	wps_calibration_error:=sqrt(sum/dp^.num_points/2);
end;

{
	wps_calibrate takes as input a calibration data string containing
	simultaneous WPS and CMM wire position measurements, and produces as output
	the WPS calibration constants that minimize the error between the WPS
	measurement and the CMM measured wire positions. In addition to the data
	string, we specify a camera number, for there are two cameras that we
	calibrate separately from the same data file. The input data string has the
	following format. We begin with the number of wire positions. The next three
	lines contain the coordinates of the cone, slot, and flat ball beneath the
	WPS respectively. Then we have a line for each wire position containing the
	CMM position and direction of the wire center-line. We then have one line
	for each wire position, each line containing the left and right edge
	positions and orientations from cameras one and two. Here is an example
	
	20
	117.6545 83.1886 -17.2954 
	44.6755 62.1783 -17.4321 
	44.5830 104.1654 -17.2884 
	103.9113 129.7997 50.2922 0.99991478 0.00889102 -0.00955959 
	103.9431 125.7984 50.2779 0.99991503 0.00886584 -0.00955667 
	103.9752 121.8009 50.2638 0.99991493 0.00887295 -0.00956066 
	104.0085 117.7957 50.2509 0.99991502 0.00885647 -0.00956690 
	104.7553 129.7766 46.4177 0.99991712 0.00873105 -0.00946149 
	104.7877 125.7764 46.4037 0.99991722 0.00872038 -0.00946123 
	104.8208 121.7746 46.3903 0.99991710 0.00872645 -0.00946834 
	104.8535 117.7685 46.3761 0.99991723 0.00870522 -0.00947372 
	104.9001 129.7467 42.5693 0.99991896 0.00852873 -0.00945121 
	104.9325 125.7481 42.5566 0.99991897 0.00852404 -0.00945529 
	104.9657 121.7474 42.5418 0.99991892 0.00851060 -0.00947188 
	104.9986 117.7459 42.5285 0.99991894 0.00851125 -0.00946948 
	105.7449 129.7706 48.6070 0.99870582 0.00888704 -0.05007694 
	105.7773 125.7704 48.5933 0.99870603 0.00887005 -0.05007573 
	105.8100 121.7669 48.5790 0.99870583 0.00886387 -0.05008098 
	105.8418 117.7689 48.5677 0.99870663 0.00885177 -0.05006708 
	104.3525 129.7877 46.2170 0.99785907 0.00839544 0.06485984 
	104.3849 125.7855 46.2029 0.99785944 0.00838955 0.06485491 
	104.4176 121.7886 46.1882 0.99786037 0.00837783 0.06484209 
	104.4507 117.7856 46.1745 0.99786075 0.00837207 0.06483697 
	2951.52 2.30 3251.61 1.53 1574.33 -10.06 1855.93 -10.40
	2628.52 3.65 2949.11 0.89 1195.81 -9.60 1496.22 -10.05
	2259.27 4.29 2602.12 2.89 764.15 -9.43 1086.72 -10.03	
	1830.11 3.92 2198.96 3.48 266.00 -9.19 615.70 -9.85
	2296.90 3.37 2585.66 3.13 2190.13 -10.10 2481.64 -10.44 
	1942.95 3.48 2250.45 3.64 1839.57 -9.90 2150.22 -10.36
	1537.64 5.25 1866.49 3.57 1438.10 -9.97 1771.13 -10.24
	1069.53 6.08 1425.03 3.66 973.45 -9.54 1333.81 -9.85 
	1686.43 4.49 1965.47 4.01 2845.86 -10.59 3150.64 -10.98 
	1304.51 5.03 1602.68 3.99 2527.69 -10.61 2851.96 -10.86
	868.45 6.43 1188.72 6.00 2162.36 -10.17 2509.00 -10.78
	365.94 6.63 713.81 6.46 1736.76 -9.78 2111.33 -10.76
	2613.07 -34.08 2907.86 -35.47 1884.75 -46.13 2171.53 -46.92
	2274.25 -32.98 2587.70 -34.36 1519.15 -45.14 1824.90 -46.34
	1885.62 -31.31 2221.24 -32.91 1100.95 -44.02 1429.15 -45.15
	1436.90 -29.43 1798.94 -31.25 618.94 -43.16 974.19 -44.11
	2366.01 69.79 2656.40 70.19 2107.85 56.37 2398.42 57.31
	2014.31 69.13 2323.28 69.76 1754.36 55.21 2064.15 56.05
	1612.63 68.59 1943.68 69.14 1350.65 54.26 1682.41 54.84
	1147.92 68.08 1505.81 68.70 883.10 52.90 1242.29 53.82

	The output takes the form of a single line of values, which we present here below headings
	that give the meaning of the values.
	
	------------------------------------------------------------------------------------------------
					pivot (mm)              sensor (mm)            rot (mrad)          pivot-  error
	Camera     x      y        z       x      y        z         x        y       z    ccd (mm) (um)
	------------------------------------------------------------------------------------------------
	C0562_1 -3.5814 88.8400 -4.9796 -12.6389 94.3849 -4.9598 -1558.772  -0.344 -566.827 10.620  1.6
	
	The routine uses the simplex fitting algorithm to minimize the camera
	calibration error, and while doing so, it writes its intermediate values,
	and a set of final errors for the pin positions, to the current target of
	gui_writeln.

	On a 2.3-GHz Intel Core i5 MacBook Pro, we calculated calibration constants
	using this routine for 53 WPS calibrations. The 64-bit version of the
	routine, compiled with FPC, completed in 136 s. The 32-bit version, compiled
	with GPC, completed in 335 s.
}
function wps_calibrate(device_name:string;camera_num:integer;data:string):string;

const
	pin_radius=1.0/16*25.4/2; {one sixteenth inch steel pin}
	random_scale=1;
	num_parameters=9; 
	max_num_shrinks=10;
	max_iterations=30000;
	min_iterations=6000;
	report_interval=500;
	support_interval=100;
	max_done=10;
	max_num_points=100;
	
var
	num_points:integer;

	{
		Create a random disturbance scaled by random_scale.
	}
	function disturb:real;
	begin
		disturb:=random_scale*(random_0_to_1-0.5);
	end;
	
var 
	mount:kinematic_mount_type;
	i:integer;
	simplex:simplex_type;
	camera:wps_camera_type;
	done:boolean;
	line:string;
	dp:wps_simplex_data_ptr;
	
begin
{
	Read the number of points.
}
	num_points:=read_integer(data);
	simplex:=new_simplex(num_parameters);
	new(dp);
	setlength(dp^.edges,num_points+1);
	setlength(dp^.wires,num_points+1);
	dp^.num_points:=num_points;
{
	Read the mount coordinates from coord_str. We use the mount to convert
	between global and wps coordinates.
}
	mount:=read_kinematic_mount(data);
{
	Read all the wire positions.
}
	for i:=1 to num_points do begin
		with dp^.wires[i] do begin
			radius:=pin_radius;
			position:=wps_from_global_point(read_xyz(data),mount);
			direction:=wps_from_global_vector(read_xyz(data),mount);
		end;
	end;
{
	Read all the edge positions.
}
	for i:=1 to num_points do begin
		with dp^.edges[i] do begin
			position.y:=wps_y_ref;
			if camera_num=2 then begin
				read_word(data);
				read_word(data);
				read_word(data);
				read_word(data);
			end;
			position.x:=read_real(data)/1000;
			rotation:=read_real(data)/1000;
			position.x:=(position.x+read_real(data)/1000)/2;
			rotation:=(rotation+read_real(data)/1000)/2;
			if camera_num=1 then begin
				read_word(data);
				read_word(data);
				read_word(data);
				read_word(data);
			end;
		end;
	end;
{
	Start with a nominal set of calibration constants, disturbed by a random
	amount in all parameters.
}
	camera:=nominal_wps_camera(camera_num);
	gui_writeln('nominal:   '+string_from_wps_camera(camera));
	with camera do begin
		writestr(id,device_name,'_',camera_num:1);
		with pivot do begin
			x:=x+disturb;
			y:=y+disturb;
			z:=z+disturb;
		end;
		with sensor do begin
			x:=x+disturb;
			y:=y+disturb;
			z:=z+disturb;
		end;
		with rot do begin
			x:=x+disturb/10;
			y:=y+disturb/10;
			z:=z+disturb/10;
		end;
	end;
	gui_writeln('disturbed: '+string_from_wps_camera(camera));
{
	Construct the fitting simplex, using our starting calibration as the first
	vertex.
}
	with simplex,camera do begin
		vertices[1,1]:=pivot.x;
		vertices[1,2]:=pivot.y;
		vertices[1,3]:=pivot.z;
		vertices[1,4]:=sensor.x;
		vertices[1,5]:=sensor.y;
		vertices[1,6]:=sensor.z;
		vertices[1,7]:=rot.x;
		vertices[1,8]:=rot.y;
		vertices[1,9]:=rot.z;
		construct_size:=random_scale/10;
		done_counter:=0;
		max_done_counter:=max_done;
	end;
	simplex_construct(simplex,wps_calibration_error,dp);	
{
	Run the simplex fit until we reach convergance, as determined by the
	simplex_step routine itself.
}
	done:=false;
	i:=0;
	while not done do begin
		simplex_step(simplex,wps_calibration_error,dp);
		done:=((simplex.done_counter>=simplex.max_done_counter)
				and (i>=min_iterations))
			or (i>=max_iterations);
		if (i mod report_interval = 0) or done then begin
			with simplex,camera do begin
				pivot.x:=vertices[1,1];
				pivot.y:=vertices[1,2];
				pivot.z:=vertices[1,3];
				sensor.x:=vertices[1,4];
				sensor.y:=vertices[1,5];
				sensor.z:=vertices[1,6];
				rot.x:=vertices[1,7];
				rot.y:=vertices[1,8];
				rot.z:=vertices[1,9];
			end;
			fsd:=4;
			writestr(line,i:5,' ',
				string_from_wps_camera(camera),' ',
				xyz_separation(camera.sensor,camera.pivot):1:3,' ',
				wps_calibration_error(simplex.vertices[1],dp)*1000:1:1);
			gui_writeln(line);
		end;
		if (i mod support_interval = 0) then
			gui_support('wps_calibrate');
		inc(i);
	end;
{
	Calculate and display the errors again.
}	
	fsd:=3;
	for i:=1 to num_points do begin
		writestr(line,string_from_xyz(dp^.wires[i].position),' ',
			string_from_xyz(dp^.wires[i].direction),' ',
			string_from_xyz(wps_camera_error(
				dp^.edges[i].position,dp^.edges[i].rotation,
				camera,wps_z_ref,dp^.wires[i])));
		gui_writeln(line);
	end;
{
	Construct the result line.
}
	fsd:=4;
	writestr(line,
		string_from_wps_camera(camera),
		xyz_separation(camera.sensor,camera.pivot):7:3,
		wps_calibration_error(simplex.vertices[1],dp)*1000:5:1);	
	wps_calibrate:=line;
{
	Clean up
}
	dispose(dp);
end;

end.

