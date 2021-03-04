{
	A program that calls routines in an external dynamic library. This library
	must be stored in the same directory as the program executable, and must be
	named X.dll (Windows), libX.dylib (MacOS), or libX.so (Linux), where X is the
	library name given in the compiler directive below.
}

program m;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}
{$MACRO ON}

{$define _LIB_:='d'}

{$IFDEF DARWIN}
	{
		On MacOS, we cannot compile an executable unless we provide paths to all
		the libraries that it requires. The compile-time linker will check that
		all routines external to the executable code are available in the
		libraries on disk, and embed a path to these libraries in the executable
		object. At run-time, the dynamic linker goes through all the undefined
		symbols in executable and loads libraries from disk to resolve them. Our
		compile command looks like:

		fpc m.pas -om.exe -k-lX -k-LY -Px86_64

		The compile-time linker looks for a library libX.dylib, where X is the
		name given in our Pascal code, and it looks in directory Y, which may be
		a relative path. The command also instructs the compiler to name the
		executable m.exe. Now run with:

		./m.exe
	}
	{$define _EXT_:=external}
{$ENDIF}


{$IFDEF WINDOWS}
	{
		On Windows, we don't need to link to external libraries at compile time.
		The linker trusts that the required routines will be available at run-time.

		fpc m.pas -om.exe -k-lX -k-LY -Px86_64

		The compile-time linker looks for a library X.dll, where X is the name
		given in our Pascal code, and it looks in directory Y, which may be a
		relative path. The command also instructs the compiler to name the
		executable m.exe. Now run with:

		./m.exe
	}
	{$define _EXT_:=external}
{$ENDIF}


{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	{ 
		On Linux, we don't need to link to external libraries at compile time.
		The linker trusts that the required routines will be available at
		run-time. At compile time all we need is:
		
		fpc m.pas -om.exe -Px86_64
		
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
		
		Now run with:
		
		./m.exe
	}
	{$define _EXT_:=weakexternal}
{$ENDIF}{$ENDIF}


function dll_inc(a:longint):longint; cdecl; _EXT_ _LIB_ name 'dll_inc';
function dll_print(s:PChar):longint; cdecl; _EXT_ _LIB_ name 'dll_print';
function dll_sqrt(x:real):real; cdecl; _EXT_ _LIB_ name 'dll_sqrt';
function dll_sizes:longint; cdecl; _EXT_ _LIB_ name 'dll_sizes';

var 
	i:longint=42;
	x:real=21.0;

begin
	writeln('Hello world from m.pas.');
	dll_sizes;
	writeln('Passed string of length ',dll_print('hello sailor'),' to library.');
	writeln('Increment of ',i:1,' is ',dll_inc(i):1);
	writeln('The square root of ',x:1:3,' is ',dll_sqrt(x):1:3);
end.
