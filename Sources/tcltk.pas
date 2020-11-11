{
Interface Between TCL/TK and Pascal
Copyright (C) 2004-2020 Kevan Hashemi, Brandeis University

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
}

unit Tcltk;

{$MODESWITCH CLASSICPROCVARS+}
{$LONGSTRINGS ON}
{$MACRO ON}

interface

uses
	utils;

const
	Tcl_Error=1;
	Tcl_OK=0;
	Tcl_MaxArgs=100;
	Tcl_ArgChar='-';

type
	Tcl_ArgList = array [0..Tcl_MaxArgs] of pointer;
	Tcl_CmdProc=
		function(data,interp:pointer;argc:integer;var argv:Tcl_ArgList):integer;
	Tcl_CmdDeleteProc=procedure(data:pointer);
	Tk_PhotoPixelElement=(red,green,blue,alpha);
	Tk_PhotoImageBlock=record
		pixelptr:pointer;
		width,height,pitch,pixelSize:integer;
		offset:array [Tk_PhotoPixelElement] of integer;
	end;

	
{$IFDEF DARWIN}
	{
		On MacOS, fpc won't make a dynamic library unless it gets to look at
		the Tcl library, in its framework. So we declare the Tcl framework here
		and on the fpc command line we and option like:
		
		fpc lwdaq -olwdaq.so_MacOS -k-F../LWDAQ.app/Contents/Frameworks
		
		This command forces the output to be lwdaq.dylib instead of liblwdaq.dylib
		and points the linker to the framework. When we load the library into
		Tcl, we can specify a relative path.

		We must add an underscrore to exported routine names on MacOS because Tcl will
		add an underscore.
	}
	const tcl_ld_prefix='_';
	{$linkframework Tcl}
	{$linkframework Tk}
	{$define _TCLLIB_:=}
	{$define _TKLIB_:=}
	{$define _EXT_:=external}
{$ENDIF}


{$IFDEF WINDOWS}
	{
		On Windows we have to have tcl86.dll present. But the cdecl calling
		convention, as implemented by FPC on Windows, wants to add an underscore
		to external routine names. We defeat this FPC policy by declaring the
		name of the library that contains the routine, and FPC ends up adding
		the underscore in front of the library name, then discarding the
		underscore. This may be a bug in FPC, and if so it may be fixed later,
		which will require us to find another work-around. We specify only the
		name of the library, and specify the path to the library at compile time
		with.

		fpc lwdaq -olwdaq.so_Windows -Px86_64 -k-L../LWDAQ.app/Contents/Windows/bin
		
		When we load the library into Tcl we can specify a relative path. We
		must add an underscrore to exported routine names on Windows because Tcl
		will add an underscore.
	}
	const tcl_ld_prefix='_';
	{$define _TCLLIB_:='tcl86'}
	{$define _TKLIB_:='tk86'}
	{$define _EXT_:=external}
{$ENDIF}


{$IFNDEF WINDOWS}{$IFNDEF DARWIN}
	{ 
		On Linux, we don't need to link to the TclTk libraries to make our dynamic
		library. The linker trusts that the required routines will be made available
		at the time of the dynamic link. We have no underscore to add to the exported
		names on Linux.
		
		fpc lwdaq -olwdaq.so_Linux

		When we load the library into Tcl we must specify an absolute path to
		the library file. On Linux, we don't add underscores in front of our
		routine names because the Tcl load routine will not add an underscore.
	}
	{$define _TCLLIB_:=}
	{$define _TKLIB_:=}
	{$define _EXT_:=weakexternal}
	const tcl_ld_prefix='';
{$ENDIF}{$ENDIF}


{
	External declarations of Tcl/TK library commands provided by the Tcl and Tk
	libraries. We use the _TCLLIB_ and _TKLIB_ macros to substitute the library
	names on Windows, but to leave no library name on MacOS and Linux.
}
function Tcl_CreateObjCommand (interp:pointer;s:PChar;cmd:Tcl_CmdProc;
	data:integer;delete_proc:Tcl_CmdDeleteProc):pointer; 
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_CreateObjCommand';
function Tcl_Eval (interp:pointer;s:PChar):integer;
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_Eval';
function Tcl_EvalFile (interp:pointer;s:PChar):integer;
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_EvalFile';
function Tcl_GetByteArrayFromObj(obj_ptr:pointer;var size:integer):pointer;
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_GetByteArrayFromObj';
function Tcl_GetObjResult (interp:pointer):pointer; 
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_GetObjResult';
function Tcl_GetStringFromObj (obj_ptr:pointer;var size:integer):PChar;
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_GetStringFromObj';
function Tcl_GetVar(interp:pointer;name:PChar;flags:integer):PChar;
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_GetVar';
function Tcl_InitStubs (interp:pointer;s:PChar;e:integer):pointer;
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_InitStubs';
function Tcl_NewByteArrayObj(bp:pointer;size:integer):pointer;
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_NewByteArrayObj';
function Tcl_PkgProvide (interp:pointer;name,version:PChar):integer; 
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_PkgProvide';
procedure Tcl_SetByteArrayObj(obj_ptr,bp:pointer;size:integer);
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_SetByteArrayObj';
procedure Tcl_SetObjResult (interp,obj_ptr:pointer);
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_SetObjResult';
procedure Tcl_SetStringObj (obj_ptr:pointer;s:PChar;l:integer);
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_SetStringObj';
function Tcl_SetVar(interp:pointer;name:PChar;value:PChar;flags:integer):PChar;
	cdecl; _EXT_ _TCLLIB_ name 'Tcl_SetVar';
function Tk_FindPhoto(interp:pointer;imageName:PChar):pointer;
	cdecl; _EXT_ _TKLIB_ name 'Tk_FindPhoto';
function Tk_InitStubs (interp:pointer;s:PChar;e:integer):pointer;
	cdecl; _EXT_ _TKLIB_ name 'Tk_InitStubs';
procedure Tk_PhotoBlank(handle:pointer);
	cdecl; _EXT_ _TKLIB_ name 'Tk_PhotoBlank';
procedure Tk_PhotoSetSize(inerp:pointer;handle:pointer;width,height:integer);
	cdecl; _EXT_ _TKLIB_ name 'Tk_PhotoSetSize';
function Tk_PhotoGetImage(handle,blockptr:pointer):integer;
	cdecl; _EXT_ _TKLIB_ name 'Tk_PhotoGetImage';
procedure Tk_PhotoPutBlock(interp,handle,blockptr:pointer;x,y,width,height,comprule:integer);
	cdecl; _EXT_ _TKLIB_ name 'Tk_PhotoPutBlock';
procedure Tk_PhotoPutZoomedBlock(interp,handle,blockptr:pointer;x,y,width,height,
	zoomX,zoomY,subsampleX,subsampleY,comprule:integer);
	cdecl; _EXT_ _TKLIB_ name 'Tk_PhotoPutZoomedBlock';

{
	Tcl routines implemented as macros in the C header file, here re-constructed
	in pascal.
}
function Tcl_IsShared(obj_ptr:pointer):integer;
procedure Tcl_DecRefCount(obj_ptr:pointer);
procedure Tcl_IncRefCount(obj_ptr:pointer);

{
	Indirect calls to Tcl/TK commands. These are not in the TCL/TK libraries.
}
function Tcl_ObjBoolean(obj_ptr:pointer):boolean;
function Tcl_ObjInteger(obj_ptr:pointer):integer;
function Tcl_ObjReal(obj_ptr:pointer):real;
function Tcl_ObjString(obj_ptr:pointer):string;
function Tcl_RefCount(obj_ptr:pointer):integer;
procedure Tcl_SetReturnString(interp:pointer;s:string);
procedure Tcl_SetReturnByteArray(interp,bp:pointer;size:integer);

implementation

{
	Tcl_RefCount returns the number of users of the specified object.
}
function Tcl_RefCount(obj_ptr:pointer):integer;
begin Tcl_RefCount:=integer_ptr(obj_ptr)^; end;

{
	Tcl_IsShared returns 1 if the specified object has more than one
	user, and zero otherwise.
}
function Tcl_IsShared(obj_ptr:pointer):integer;
begin 
   if (Tcl_RefCount(obj_ptr)>1) then Tcl_IsShared:=1
   else Tcl_IsShared:=0;
end;

{
	Tcl_IncRefCount registers another user with an object.
}
procedure Tcl_IncRefCount(obj_ptr:pointer);
begin inc(integer_ptr(obj_ptr)^); end;

{
	Tcl_DecRefCount unregisters a user from an object.
}
procedure Tcl_DecRefCount(obj_ptr:pointer);
begin dec(integer_ptr(obj_ptr)^); end;

{
	Tcl_ObjString returns a pointer to a file string from a TCL object. 
	If the string is too long, we return an empty string.
}
function Tcl_ObjString(obj_ptr:pointer):string;
var s:string;size:integer;
begin
	s:=Tcl_GetStringFromObj(obj_ptr,size);
	Tcl_ObjString:=s;
end;

{
	Tcl_ObjBoolean returns true if the string representation
	of the specified object satisfies boolean_from_string.
}
function Tcl_ObjBoolean(obj_ptr:pointer):boolean;
begin
	Tcl_ObjBoolean:=boolean_from_string(Tcl_ObjString(obj_ptr))
end;

{
	Tcl_ObjInteger returns the integer representation of
	the specified object. If the object has no integer
	representation, then the routine returns zero.
}
function Tcl_ObjInteger(obj_ptr:pointer):integer;
var okay:boolean;
begin
	Tcl_ObjInteger:=integer_from_string(Tcl_ObjString(obj_ptr),okay);
end;

{
	Tcl_ObjReal returns the real-number representation of
	the specified object. If the object has no real-number
	representation, then the routine returns zero.
}
function Tcl_ObjReal(obj_ptr:pointer):real;
var okay:boolean;
begin
	Tcl_ObjReal:=real_from_string(Tcl_ObjString(obj_ptr),okay);
end;

{
	Tcl_SetReturnString sets the interpreter return object
	equal to the contents of the specified string.
}
procedure Tcl_SetReturnString(interp:pointer;s:string);
begin
	Tcl_SetStringObj(Tcl_GetObjResult(interp),PChar(s),-1);
end;

{
	Tcl_SetReturnByteArray sets the interpreter return object equal
	to the specified byte array object.
}
procedure Tcl_SetReturnByteArray(interp,bp:pointer;size:integer);
begin
	Tcl_SetByteArrayObj(Tcl_GetObjResult(interp),bp,size);
end;

end.