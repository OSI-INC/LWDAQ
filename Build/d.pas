{
	A dynamic library that exports some routines. Compile on all platforms with:

	fpc d.pas -Px86_64

	The result will be a shared library called  d.dll (Windows), libd.dylib
	(MacOS), or libd.so (Linux).
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
	const exp_prefix='';
{$ENDIF}

{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	{ 
		We do not add an underscore to the start of any exported routine names,
		for consistency with the GCC linker on Linux.
	}
	const exp_prefix='';
{$ENDIF}{$ENDIF}


function dll_inc(a:longint):longint; cdecl;
begin
	dll_inc:=a+1;
end;

function dll_print(s:PChar):longint; cdecl;
begin
	writeln('String passed into Pascal library is: "'+s+'"');
	dll_print:=length(s);
end;

function dll_sqrt(x:real):real; cdecl;
begin
	dll_sqrt:=sqrt(x);
end;

function dll_sizes:longint; cdecl;
begin
	writeln('Reporting sizes of variable types in Pascal:');
	writeln('Size of integer is ',sizeof(integer),' bytes.');
	writeln('Size of longint is ',sizeof(longint),' bytes.');
	writeln('Size of real is ',sizeof(real),' bytes.');
	writeln('Size of extended is ',sizeof(extended),' bytes.');
	writeln('Size of char is ',sizeof(char),' bytes.');
	dll_sizes:=0;
end;

exports
	dll_inc name exp_prefix+'dll_inc',
	dll_print name exp_prefix+'dll_print',
	dll_sqrt name exp_prefix+'dll_sqrt',
	dll_sizes name exp_prefix+'dll_sizes';
end.

