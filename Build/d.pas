{
	A dynamic library that exports some routines. Compile on all platforms
	with:
	
	fpc d.pas -Px86_64
	
	The result will be a shared library called  d.dll (Windows), libd.dylib (MacOS), 
	or libd.so (Linux).
}

library d;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}
{$MACRO ON}

{$IFDEF DARWIN}
	{
		We must add an underscrore to the names of routines we export, consistent
		with the GCC linker on MacOS.
	}
	const exp_prefix='_';
{$ENDIF}

{$IFDEF WINDOWS}
	{
		We must add an underscrore to the names of routines we export, consistent
		with the GCC linker on Windows.
	}
	const exp_prefix='_';
{$ENDIF}

{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	{ 
		We do not add an underscore to the start of any exported routine names,
		for consistency with the GCC linker on Linux.
	}
	const exp_prefix='';
{$ENDIF}{$ENDIF}


function increment(a:longint):longint; cdecl;
begin
	increment:=a+1;
end;

function printstring(s:PChar):longint; cdecl;
begin
	writeln('String passed into Pascal library is: "'+s+'"');
	printstring:=length(s);
end;

function sqroot(x:real):real; cdecl;
begin
	sqroot:=sqrt(x);
end;

function reportsizes:longint; cdecl;
begin
	writeln('Reporting sizes of variable types in Pascal:');
	writeln('Size of integer is ',sizeof(integer),' bytes.');
	writeln('Size of longint is ',sizeof(longint),' bytes.');
	writeln('Size of real is ',sizeof(real),' bytes.');
	writeln('Size of extended is ',sizeof(extended),' bytes.');
	writeln('Size of char is ',sizeof(char),' bytes.');
	reportsizes:=0;
end;

exports
	increment name exp_prefix+'increment',
	printstring name exp_prefix+'printstring',
	sqroot name exp_prefix+'sqroot',
	reportsizes name exp_prefix+'reportsizes';
end.

