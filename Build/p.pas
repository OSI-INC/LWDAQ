program p;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	scam,bcam,utils,images,image_manip;

var
	sc:scam_camera_type;
	q,qq:xy_point_type;
	r:xyz_point_type;
	line:xyz_line_type;
	sphere:xyz_sphere_type;
	cylinder:xyz_cylinder_type;
	d:real;
	i,j,k:integer;
	ip:image_ptr_type;
	i_ext,j_ext:integer;
	
begin
	writeln('Testing scam_from_image_point and image_from_scam_point');
	sc:=nominal_scam_camera(1);
	for i:=1 to 1000 do begin
		q.x:=2.590+random_0_to_1-0.5;
		q.y:=1.924+random_0_to_1-0.5;
		r:=scam_from_image_point(q,sc);
		qq:=image_from_scam_point(r,sc);
		if xy_separation(q,qq) > 0.001 then begin
			writeln(string_from_xy(q));
			writeln(string_from_xyz(r));
			writeln(string_from_xy(qq));
		end; 
	end;
	
	writeln('Testing xyz_line_crosses_sphere, should see a circle.');
	line.direction.x:=0;
	line.direction.y:=0;
	line.direction.z:=1;
	sphere.center.x:=0;
	sphere.center.y:=0;
	sphere.center.z:=0;
	sphere.radius:=5;
	i_ext:=20;
	j_ext:=8;
	for i:=-i_ext to +i_ext do write('-');
	writeln;
	for j:=j_ext downto -j_ext do begin
		write('|');
		for i:=-i_ext to +i_ext do begin
			line.point.x:=i*0.5;
			line.point.y:=j;
			line.point.z:=0;
			if xyz_line_crosses_sphere(line,sphere) then
				write('X')
			else
				write(' ')
		end;
		writeln('|');
	end;
	for i:=-i_ext to i_ext do write('-');
	writeln;
	
	
	writeln('Testing xyz_line_crosses_cylinder.');
	line.direction.x:=0;
	line.direction.y:=0;
	line.direction.z:=1;
	cylinder.face.point.x:=-5;
	cylinder.face.point.y:=-3;
	cylinder.face.point.z:=0;
	cylinder.face.normal.x:=1;
	cylinder.face.normal.y:=1;
	cylinder.face.normal.z:=0;
	cylinder.radius:=2;
	cylinder.length:=100;
	i_ext:=20;
	j_ext:=5;
	for i:=-i_ext to +i_ext do write('-');
	writeln;
	for j:=j_ext downto -j_ext do begin
		write('|');
		for i:=-i_ext to +i_ext do begin
			line.point.x:=i*0.5;
			line.point.y:=j;
			line.point.z:=0;
			if xyz_line_crosses_cylinder(line,cylinder) then
				write('X')
			else
				write(' ');
		end;
		writeln('|');
	end;
	for i:=-i_ext to +i_ext do write('-');
	writeln;
	
	writeln('Testing SCAM projection routines, +x left, +y up, as seen from camera.');
	ip:=new_image(20,40);
	with ip^.analysis_bounds do begin
		top:=0;
	end;
	clear_overlay(ip);
	sc:=nominal_scam_camera(0);
	sc.pixel_size:=0.01;
	sc.reference_point.x:=20*sc.pixel_size;
	sc.reference_point.y:=10*sc.pixel_size;

	sphere.center.x:=-200;
	sphere.center.y:=100;
	sphere.center.z:=1000;
	sphere.radius:=50;
	scam_project_sphere(ip,sphere,sc);
	
	sphere.center.x:=100;
	sphere.center.y:=0;
	sphere.center.z:=500;
	sphere.radius:=50;
	scam_project_sphere(ip,sphere,sc);

	sphere.center.x:=5;
	sphere.center.y:=5;
	sphere.center.z:=100;
	sphere.radius:=1;
	scam_project_sphere(ip,sphere,sc);
	
	cylinder.face.point.x:=0;
	cylinder.face.point.y:=-20;
	cylinder.face.point.z:=1000;
	cylinder.face.normal.x:=-0.04;
	cylinder.face.normal.y:=-0.02;
	cylinder.face.normal.z:=-1;
	cylinder.radius:=10;
	cylinder.length:=1000;
	scam_project_cylinder(ip,cylinder,sc);

	for i:=0 to ip^.i_size-1 do write('--');
	writeln;
	for j:=ip^.j_size-1 downto 0 do begin
		write('|');
		for i:=0 to ip^.i_size-1 do begin
			if get_ov(ip,j,i)=green_color then write('SS')
			else if get_ov(ip,j,i)=blue_color then write('CC')
			else write('  ');
		end;
		writeln('|');;
	end;
	for i:=0 to ip^.i_size-1 do write('--');
	writeln;
	
end.