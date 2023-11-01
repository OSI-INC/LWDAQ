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
	The SCAM uses the same kinematic mount as a BCAM. The SCAM coordinate system
	is defined with respect to the SCAM's three mounting balls in the same way
	as for BCAMs. In our SCAM calibration constants, we assume that the SCAM
	axis is close to the SCAM z-axis. Our image coordinates are microns from the
	top-left corner of the top-left pixel in the image. Our mount coordinates
	are in millimeters, with the origin at the center of the cone ball. Our
	global coordinates are in millimeters also. We use the same image sensor
	encoding system as the BCAM: in place of axis.z we include a code that
	indicates if the SCAM faces forward (+ve) or backwards (-ve), and for which
	the absolute value specifies the sensor itself. The SCAM projection routines
	need to know the size of the pixels, and for this reason the SCAM unit keeps
	a list of pixel sizes to go with the sensor codes.
	
	The CPMS measures position by modelling the bodies in its view, projecting
	line drawings of the modelled bodies into the image sensor planes of both
	SCAMs, and comparing the projected line drawings to the actual silhouette
	images obtained by the SCAM image sensors. We compose a model of a "body"
	with one or more "objects", where each object is a simple shape such as a
	sphere, cylinder, shaft, or cuboid. The body itself has its own coordinate
	system. The location and orientation of this coordinate system with respect
	to the CPMS global coordinate system is the body's "pose". Each object
	within the body has a pose in the coordinate system of the body. When we
	project a drawing of an object, we obtain the object's global pose by adding
	its pose within the body to the pose of the body within the global
	coordinate system. We then transform the global pose of the object into the
	coordinate system of each SCAM. Once we have the pose of the object in SCAM
	coordinates, we can call one of the projection routines in this library. The
	routines for adding and transforming poses are provided by the utils, bcam,
	and scam units.
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
	An SCAM coordinate system is defined by a translation of the origin in
	global coordinates and a compound rotation about the global coordinate axes.
	The compound rotation is three rotations in order x, y, z, which we call an
	"xyz rotation". When we apply the rotation to the global axis vectors, we
	obtain the SCAM axis vectors. Together, the translation and the rotation
	define the SCAM coordinate system with the minimal number of free variables.
	We can think of the SCAM coordinate system as being one with a particular
	location and orientation in global coordinates, which is to say: a
	right-handed coordinate system with a particular pose. As a result, our SCAM
	coordinate type is simply and xyz_pose_type, containing two fields: a
	location and an orientation.
}
	scam_coord_type=xyz_pose_type;
{
	A sphere object is entirely specified by the location of its center and its 
	diameter. 
}
	scam_sphere_type=record 
		pose:xyz_pose_type; {center of sphere}
		diameter:real; {diameter of sphere}
	end;
{
	We specify a shaft with a point on the shaft axis, the direction of the
	shaft, the number of faces, and for each face a diameter and a distance
	along the axis from the specified point on the shaft. We call this point the
	"location" of the shaft. The axis vector is the "orientation" of the shaft.
}
	scam_shaft_type=record 
		pose:xyz_pose_type; {origin of shaft}
		num_faces:integer; {number of faces that define the shaft}
		diameter:array of real; {diameter of face}
		distance:array of real; {distance of face from origin}
	end;

{
	String input and output routines.
}
function scam_coord_from_string(s:string):scam_coord_type;
function scam_sphere_from_string(s:string):scam_sphere_type;
function scam_shaft_from_string(s:string):scam_shaft_type;
function read_scam_coord(var s:string):scam_coord_type;
function read_scam_sphere(var s:string):scam_sphere_type;
function read_scam_shaft(var s:string):scam_shaft_type;
function string_from_scam_coord(scam:scam_coord_type):string;
function string_from_scam_sphere(sphere:scam_sphere_type):string;
function string_from_scam_shaft(shaft:scam_shaft_type):string;

{
	Coordinate handling routines.
}
function scam_coord_from_mount(mount:kinematic_mount_type):scam_coord_type;
function scam_from_global_vector(p:xyz_point_type;c:scam_coord_type):xyz_point_type;
function scam_from_global_point(p:xyz_point_type;c:scam_coord_type):xyz_point_type;
function scam_from_global_pose(p:xyz_pose_type;c:scam_coord_type):xyz_pose_type;
function global_from_scam_vector(p:xyz_point_type;c:scam_coord_type):xyz_point_type;
function global_from_scam_point(p:xyz_point_type;c:scam_coord_type):xyz_point_type;
function global_from_scam_pose(p:xyz_pose_type;c:scam_coord_type):xyz_pose_type;

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
procedure scam_project_shaft(ip:image_ptr_type;
	shaft:scam_shaft_type;
	camera:bcam_camera_type;
	num_points:integer);

{
	Routines that analyze the image.
}
function scam_decode_rule(ip:image_ptr_type;rule:string):real;
function scam_disagreement(ip:image_ptr_type;threshold:real):real;

implementation

{
	read_scam_coord reads the parameters of an scam coordinate system from a
	string and deletes them from the string. It returns an scam coordinate
	record.
}
function read_scam_coord(var s:string):scam_coord_type;
var scam:scam_coord_type;
begin
	scam.location:=read_xyz(s);
	scam.orientation:=read_xyz(s);
	read_scam_coord:=scam;
end;	

{
	scam_coord_from_string converts a string into an scam coordinate type and returns
	the coordinate record.
}
function scam_coord_from_string(s:string):scam_coord_type;
begin scam_coord_from_string:=read_scam_coord(s); end;	

{
	string_from_scam_coord converts a coordinate type into a string for printing.
}
function string_from_scam_coord(scam:scam_coord_type):string;
var s:string='';
begin
	with scam do begin
		write_xyz(s,location);
		s:=s+' ';
		write_xyz(s,orientation);
	end;
	string_from_scam_coord:=s;
end;


{
	read_scam_sphere reads the parameters of a sphere from a string and deletes
	them from the string. It returns a new sphere record.
}
function read_scam_sphere(var s:string):scam_sphere_type;
var sphere:scam_sphere_type;
begin 
	sphere.pose.location:=read_xyz(s);
	sphere.pose.orientation:=xyz_origin;
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
		write_xyz(s,pose.location);
		s:=s+' ';
		writestr(s,s,diameter:fsr:fsd);
	end;
	string_from_scam_sphere:=s;
end;

{
	read_scam_shaft reads the parameters of a shaft from a string and deletes
	them from the string. It returns a new shaft record. The string must contain
	with the xyz origin of the shaft axis, the xyz direction of the shaft axis,
	and one or more faces. Each face is specified by a diameter and a distance
	from the origin along the shaft.	
}
function read_scam_shaft(var s:string):scam_shaft_type;
var shaft:scam_shaft_type;i:integer;
begin 
	with shaft do begin
		pose.location:=read_xyz(s);
		pose.orientation:=read_xyz(s);
		num_faces:=word_count(s) div 2;
		setlength(diameter,num_faces);
		setlength(distance,num_faces);
		for i:=0 to num_faces-1 do begin
			diameter[i]:=read_real(s);
			distance[i]:=read_real(s);
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
		write_xyz(s,pose.location);
		s:=s+' ';
		write_xyz(s,pose.orientation);
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
	scam_coordinates_from_mount takes the global coordinates of the cone, slot,
	and flat balls of an SCAM mount and returns the SCAM coordinate system
	defined by the mount. The location is the vector in global coordinates
	from the global coordinate origin to the SCAM mount origin, which will be
	the center of the cone ball. The rotation is an xyz rotation that rotates
	the global axis unit vectors into the SCAM coordinate axis vectors. To
	obtain the location and SCAM coordinate axes vectors we call the BCAM
	coordinate routine. To obtain the compount rotation from the three
	coordinate axes vectors we call another routine that uses a simplex fitter
	to find the x, y, and z rotations that match the coordinate axes vectors.
	This routine takes roughly one millisecond to run, so the idea is we save
	the scam coordinates and pass them in to coordinate transformation routines
	so that we don't have to find the angles more than once.
}
function scam_coord_from_mount(mount:kinematic_mount_type):scam_coord_type;

var
	bcam:bcam_coord_type;
	scam:scam_coord_type;
	
begin
	bcam:=bcam_coord_from_mount(mount);
	scam.location:=bcam.origin;
	scam.orientation:=xyz_rotation_from_axes(bcam.x_axis,bcam.y_axis,bcam.z_axis);
	scam_coord_from_mount:=scam;
end;

{
	bcam_from_scam_coord takes an scam_coord_type and transforms it into 
	a bcam_coord_type. We rotate the bcam global coordinate axes to obtain
	the coordinate axes of the bcam coordinate system that is equivalent
	to our rotation-based scam coordinate system.
}
function bcam_from_scam_coord(scam:scam_coord_type):bcam_coord_type;

var
	bcam:bcam_coord_type;

begin
	bcam.origin:=scam.location;
	bcam.x_axis:=xyz_rotate(global_bcam_coord.x_axis,scam.orientation);
	bcam.y_axis:=xyz_rotate(global_bcam_coord.y_axis,scam.orientation);
	bcam.z_axis:=xyz_rotate(global_bcam_coord.z_axis,scam.orientation);
	bcam_from_scam_coord:=bcam;
end;

{
	scam_from_global_vector transforms a direction in global coordinates to a
	direction in scam coordinates. We pass into the routine an scam coordinate
	type, which provides the xyz rotation we must apply to the vector.
}
function scam_from_global_vector(p:xyz_point_type;c:scam_coord_type):xyz_point_type;
begin
	scam_from_global_vector:=xyz_unrotate(p,c.orientation);
end;

{
	global_from_scam_vector transforms a direction in scam coordinates into a 
	direction in global coordinates. We pass into the routine an scam coordinate
	type, which provides the xyz rotation we must apply in reverse to the vector.
}
function global_from_scam_vector(p:xyz_point_type;c:scam_coord_type):xyz_point_type;
begin
	global_from_scam_vector:=xyz_rotate(p,c.orientation);
end;

{
	scam_from_global_point transforms a point in global coordinates to a point
	in scam coordinates.
}
function scam_from_global_point(p:xyz_point_type;c:scam_coord_type):xyz_point_type;
begin
	scam_from_global_point:=scam_from_global_vector(xyz_difference(p,c.location),c);
end;

{
	global_from_scam_point transforms a point in scam coordinates into a point
	in global coordinates.
}
function global_from_scam_point(p:xyz_point_type;c:scam_coord_type):xyz_point_type;
begin
	global_from_scam_point:=xyz_sum(c.location,global_from_scam_vector(p,c));
end;

{
	scam_from_global_pose transforms a pose in global coordinates to a pose
	in scam coordinates.
}
function scam_from_global_pose(p:xyz_pose_type;c:scam_coord_type):xyz_pose_type;

var 
	pose:xyz_pose_type;
	
begin
	pose.location:=scam_from_global_point(p.location,c);
	pose.orientation:=
		xyz_rotate(
			xyz_difference(
				p.orientation,c.orientation),c.orientation);
	scam_from_global_pose:=pose;
end;

{
	global_from_scam_pose transforms a pose in scam coordinates to a pose
	in global coordinates.
}
function global_from_scam_pose(p:xyz_pose_type;c:scam_coord_type):xyz_pose_type;

var 
	pose:xyz_pose_type;
	
begin
	pose.location:=global_from_scam_point(p.location,c);
	pose.orientation:=
		xyz_unrotate(
			xyz_sum(
				p.orientation,c.orientation),c.orientation);
	global_from_scam_pose:=pose;
end;

{
	scam_project_sphere takes a sphere in SCAM coordinates and projects drawing
	of the sphere onto the image plane of a camera. The routine finds the circle
	on the surface of the sphere that is the outsline of the sphere as seen by
	the camera. It projects num_points points around this circle into the image
	and joins them to trace the sphere silhouette perimiter. It further joins
	the points with one another to provide some fill of the silhouette. The
	routine draws in the overlay, not the actual image. 
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
	min_points=2;
	
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
	If the number of points is fewer than two, we abort.
}
	if num_points<min_points then begin
		report_error('num_points<min_points in scam_project_sphere');
		exit;
	end;
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
	center_line.direction:=xyz_difference(sphere.pose.location,camera.pivot);
	theta:=arcsin(sphere.diameter*one_half/xyz_length(center_line.direction));
	axis.point:=camera.pivot;
	axis.direction:=xyz_perpendicular(center_line.direction);
	tangent.point:=xyz_axis_rotate(sphere.pose.location,axis,theta);
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
	pc:=bcam_image_position(sphere.pose.location,camera);
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
	num_points:integer);
	
const
	draw_perimeter=true;
	draw_axials=true;
	draw_radials=false;
	min_points=2;
	
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

begin
{
	If the number of points is fewer than two, we abort.
}
	if num_points<min_points then begin
		report_error('num_points<min_points in scam_project_shaft');
		exit;
	end;
{
	If the number of points is zero, or the number of faces is zero, exit.
}
	if num_points=0 then exit;
	if shaft.num_faces<=0 then exit;
{
	Apply the location and orientation of the shaft's pose to obtain the
	axis.
}
	axis.point:=shaft.pose.location;
	with axis.direction do begin x:=1; y:=0; z:=0; end;
	axis.direction:=xyz_rotate(axis.direction,shaft.pose.orientation);
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
		setlength(perimeter_a,num_points);
		with shaft do begin
			radial:=xyz_scale(xyz_perpendicular(axis.direction),
				diameter[face_num]*one_half);
			center:=xyz_sum(shaft.pose.location,
				xyz_scale(axis.direction,distance[face_num]));
			point:=xyz_sum(center,radial);
			
			for step:=0 to num_points-1 do begin
				projection:=bcam_image_position(point,camera);
				perimeter_a[step].x:=projection.x/w-ccd_origin_x;
				perimeter_a[step].y:=projection.y/w-ccd_origin_y;
				point:=xyz_axis_rotate(point,axis,2*pi/num_points);
			end;
			
			pc:=bcam_image_position(center,camera);
			ica.x:=pc.x/w-ccd_origin_x;
			ica.y:=pc.y/w-ccd_origin_y;
			
			for step:=0 to num_points-1 do begin
				if draw_perimeter then begin
					line.a:=perimeter_a[step];		
					line.b:=perimeter_a[(step+1) mod num_points];
					draw_overlay_xy_line(ip,line,scam_shaft_color);
				end;
				
				if ((face_num=0) and (diameter[face_num]>0))
					or ((face_num=num_faces-1) and (diameter[face_num]>0))
					or draw_radials then begin
					line.a:=perimeter_a[step];		
					line.b:=ica;
					draw_overlay_xy_line(ip,line,scam_shaft_color);
				end;
				
				if (face_num>0) and draw_axials then begin
					line.a:=perimeter_a[step];
					line.b:=perimeter_b[step];
					draw_overlay_xy_line(ip,line,scam_shaft_color);
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

