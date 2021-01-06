{
	A library that exports a simple routine. Compile with:
	fpc d.pas -Px86_64
}
{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}
{$MACRO ON}

library d;

function increment(a:longint):longint; cdecl;
begin
	increment:=a+1;
end;

exports
	increment name '_increment';
end.

