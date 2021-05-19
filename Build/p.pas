program p;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}

{
uses
	utils,images,transforms,image_manip,rasnik,
	spot,bcam,shadow,wps,electronics,metrics;

procedure console_write(s:string);
begin writeln(s); end;

function console_read(s:string):string;
begin write(s);readln(s);console_read:=s; end;
}
procedure print_result(function calc(x:integer):integer;x:integer);
begin
   writeln(calc(x));
end; 

function calc_example(x:integer):integer;
begin
	calc_example:=x*x;
end;

var
	x:integer;
	
begin
	x:=100;
	print_result(calc_example,x);
end.
