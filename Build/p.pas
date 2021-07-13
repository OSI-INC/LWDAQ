program p;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	utils,images,transforms,image_manip,rasnik,
	spot,bcam,shadow,wps,electronics,metrics;

var
	gp:x_graph_ptr;
	s:string;
	i:integer;
	
begin
	i:=1;
	repeat 
		inc(i);
		gp:=new_x_graph(i);
		write(average_x_graph(gp));
		readln(s);
	until s='exit';
end.
