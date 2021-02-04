{
	A program that calls routines in external dynamic libraries. These libraries
	must be stored on disk with file names of the form X.dll (Windows),
	libX.dylib (MacOS), or lX.so (Linux), where "X" is the name of the library
	we provide in our Pascal code following an "external" directive.
}

program m;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}
{$MACRO ON}

{$IFDEF DARWIN}
	{
		On MacOS, we cannot compile an executable unless we provide paths to
		all the libraries that it requires. The compile-time linker
		will check that all routines external to the executable code are
		available in the libraries on disk, and embed a path to these libraries
		in the executable object. At run-time, the dynamic linker goes through all
		the undefined symbols in executable and loads libraries from disk to resolve
		them. Our compile command looks like:

		fpc m.pas -om.exe -k-lX -kLY
		
		The compile-time linker looks for a library libX.dylib, where X is the
		name given in our Pascal code, and it looks in directory Y, which may be
		a relative path. The command also instructs the compiler to name the
		executable m.exe.
	}
	{$define _LIB_:='d'}
	{$define _EXT_:=external}
{$ENDIF}


{$IFDEF WINDOWS}
	{
		On Windows, we cannot compile an executable unless we provide paths to
		all the libraries that it requires. The compile-time linker
		will check that all routines external to the executable code are
		available in the libraries on disk, and embed a path to these libraries
		in the executable object. At run-time, the dynamic linker goes through all
		the undefined symbols in executable and loads libraries from disk to resolve
		them. Our compile command looks like:

		fpc m.pas -om.exe -k-lX -kLY
		
		The compile-time linker looks for a library X.dll, where X is the name
		given in our Pascal code, and it looks in directory Y, which may be a
		relative path. The command also instructs the compiler to name the
		executable m.exe.
	}
	{$define _LIB_:='d'}
	{$define _EXT_:=external}
{$ENDIF}


{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	{ 
		On Linux, we don't need to link to external libraries at compile time.
		The linker trusts that the required routines will be available at
		run-time. At compile time all we need is:
		
		fpc m.pas -om.exe
		
		At run-time, all symbols undefined in the executable must be resolved.
		If the symbols are defined in memory already by the operating system,
		they are resolved immediately. Otherwise, the dynamic linker must load a
		library from disk. Our external routines will not be defined by the
		operating system, nor loaded as part of any other library, so we must
		specify in our Pascal code, after each "external" directive, the name of
		the library in which the routine is defined. If we say "d" for the
		library name, FPC embeds the name "libd.so" in the executable file as
		the name of the library that must be loaded. The dynamic linker looks
		for libd.so in the Linux library paths. In our case, libd.so is a local
		library we have compiled ourselves, so we must use the LD_LIBRARY_PATH
		environment variable to tell the dynamic linker where to find it.
		
		LD_LIBRARY_PATH="./"
		export LD_LIBRARY_PATH
	}
	{$define _LIB_:=}
	{$define _EXT_:=weakexternal}
{$ENDIF}{$ENDIF}


function increment(a:longint):longint; cdecl; _EXT_ _LIB_ name 'increment';
function print(s:PChar):longint; cdecl; _EXT_ _LIB_ name 'print';
function sqroot(x:real):real; cdecl; _EXT_ _LIB_ name 'sqroot';
function reportsizes:longint; cdecl; _EXT_ _LIB_ name 'reportsizes';

var 
	i:longint=42;
	x:real=21.0;
	
begin
	reportsizes;
	writeln('Passed string of length ',print('hello sailor'),' to library.');
	writeln('Increment of ',i:1,' is ',increment(i):1);
	writeln('The square root of ',x:1:3,' is ',sqroot(x):1:3);
end.
