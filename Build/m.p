{
	A program that calls the above dynamic library. Goes with the dynamic
	library defined by d.pas. Compile with:
	fpc m.pas -Px86_64 -k-ld
}

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}
{$MACRO ON}

program m;
 
function increment(a:longint):longint; cdecl; external 'd' name 'increment';
 
var
	i:integer;
begin
	for i:= 1 to 20 do 
		writeln(increment(i));
end.
