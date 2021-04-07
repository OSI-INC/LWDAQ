program p;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

uses
	utils,images,transforms,image_manip,rasnik,
	spot,bcam,shadow,wps,electronics,metrics;

procedure console_write(s:string);
begin writeln(s); end;

function console_read(s:string):string;
begin write(s);readln(s);console_read:=s; end;

procedure A (procedure B (procedure C));
begin
	B(C);
end;

var
	x:real;
	i:integer;
	
begin
	gui_writeln:=console_write;
	gui_readln:=console_read;
	gui_writeln('Hello from program p, which uses all analysis units.');
	
	for i:=0 to 15 do begin
		x:=i*2.0*pi/16;
		write(i:1,' ',x:fsr:fsd,' ');
		writeln(full_arctan(sin(x),cos(x)):fsr:fsd);
	end;
end.
