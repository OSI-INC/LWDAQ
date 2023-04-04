program p;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

{
	Console-Only Test Progam for SCAM Routines. Place in LWDAQ/Build and type
	"make p" then "./p.exe" to run.
}

uses
	scam,bcam,utils,images,image_manip;
	
const
	width=80;
	height=40;

var
	sc:bcam_camera_type;
	q,qq:xy_point_type;
	r,rr:xyz_point_type;
	line:xyz_line_type;
	sphere:xyz_sphere_type;
	cylinder:xyz_cylinder_type;
	d:real;
	i,j,k:integer;
	ip:image_ptr_type;
	
begin
{	
	writeln('Testing xyz_axis_rotate');
	line.point.x:=0;
	line.point.y:=0;
	line.point.z:=0;
	line.direction.x:=0;
	line.direction.y:=0;
	line.direction.z:=-1;
	repeat 
		readln(r.x,r.y,r.z);
		rr:=xyz_axis_rotate(r,line,pi*0.5);
		writeln(string_from_xyz(rr),' ',xyz_length(rr):fsr:fsd);
	until (r.x=-1);
}
	
	writeln('Testing outline projection, mount +x left, mount +y up in view.');
	ip:=new_image(height,width);
	with ip^.analysis_bounds do begin
		top:=0;
	end;
	clear_overlay(ip);
	sc:=bcam_camera_from_string('scam 0 0 0 0 0 3 25 0');
	bcam_generic_pixel_um:=100;
	bcam_generic_center_x:=width*0.5*bcam_generic_pixel_um/um_per_mm;
	bcam_generic_center_y:=height*0.5*bcam_generic_pixel_um/um_per_mm;

	sphere:=xyz_sphere_from_string('0 0 100 5');
	scam_project_sphere_outline(ip,sphere,sc);

	write(' ');
	for i:=0 to ip^.i_size-1 do write('--');
	writeln;
	for j:=0 to ip^.j_size-1 do begin
		write('|');
		for i:=0 to ip^.i_size-1 do begin
			if get_ov(ip,j,i)=scam_sphere_color then write('SS')
			else if get_ov(ip,j,i)=scam_cylinder_color then write('CC')
			else if get_ov(ip,j,i)=scam_sphere_outline_color then write('OO')
			else write('  ');
		end;
		writeln('|');;
	end;
	write(' ');
	for i:=0 to ip^.i_size-1 do write('--');
	writeln;
	
end.