program p;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	scam,bcam,utils,images,image_manip;

var
	sc:scam_camera_type;
	q,qq:xy_point_type;
	r:xyz_point_type;
	d:real;
	i:integer;
	
begin
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
end.