@echo off

REM
REM Long-Wire Data Acquisition Software (LWDAQ)
REM Copyright (C) 2009-2021 Kevan Hashemi, Brandeis University
REM Copyright (C) 2021 Kevan Hashemi, Open Source Instruments Inc.
REM
REM This program is free software; you can redistribute it and/or
REM modify it under the terms of the GNU General Public License
REM as published by the Free Software Foundation; either version 2
REM of the License, or (at your option) any later version.
REM
REM This program is distributed in the hope that it will be useful,
REM but WITHOUT ANY WARRANTY; without even the implied warranty of
REM MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
REM GNU General Public License for more details.
REM
REM You should have received a copy of the GNU General Public License
REM along with this program; if not, write to the Free Software
REM Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307.
REM
REM This program launches LWDAQ from a DOS prompt. You can pass options
REM --no-gui, --gui, or --no-console, as described in the LWDAQ manual.
REM After the option (if any), you can pass a TCL script that will be
REM executed by LWDAQ after it starts up and initialized. The script can
REM refer to itself by the name $LWDAQ_Info(configuration_file) to determine
REM its own location.
REM 
REM [01-APR-10] Modified code so it can handle spaces in LWDAQ directory
REM path. If the TCL script file has a space in it, we must enclose the file
REM name in double quotation marks when we pass the file name to the lwdaq.bat
REM command. Thus the following command works.
REM lwdaq.bat --no-console "Test Directory\test.tcl"
REM

REM ------------------------------------------
REM Determine the LWDAQ directory
REM ------------------------------------------

set LWDAQ_DIR=%~p0

REM ------------------------------------------
REM Default values for options and configuration 
REM file name.
REM ------------------------------------------

set script=%1
set gui_enabled=1
set console_enabled=0
set background=1
set option=--gui

REM ------------------------------------------
REM Attempt to extract options and configuration
REM file name from the command line parameters.
REM ------------------------------------------

if [%1]==[--no-gui] (
	set option=%1
	set gui_enabled=0
	set console_enabled=1
	set background=0
	set script=%2
) 
if [%1]==[--gui] (
	set option=%1
	set gui_enabled=1
	set console_enabled=0
	set background=1
	set script=%2
)
if [%1]==[--no-console] (
	set option=%1
	set gui_enabled=0
	set console_enabled=0
	set background=1
	set script=%2
)
if [%1]==[--child] (
	set option=%1
	set gui_enabled=1
	set console_enabled=0
	set background=1
	set script=%2
)
echo Option: %option%
echo Background: %background%
echo Console: %console_enabled%
echo Graphics: %gui_enabled%

REM ------------------------------------------
REM If the start-up script name is not an
REM empty string, check that it exists. If not
REM we abort our program with an error message.
REM Otherwise we report the file name to the
REM terminal. We ignore an empty string file
REM name.
REM ------------------------------------------

if [%script%]==[] (
	if [%option%]==[--no-console] (
		echo ERROR: No configuration file specified with no-console option.
		goto done
	) else (
		echo Configuration: none
		goto donescript
	)
)
if not exist %script% (
  echo ERROR: Bad option or script %script%.
  goto done
) else (
  echo Configuration: %script%
)
:donescript

REM ------------------------------------------
REM Choose the shell based upon the option.
REM ------------------------------------------

if [%gui_enabled%]==[0] (
  set shell=%LWDAQ_DIR%LWDAQ.app\Contents\Windows\bin\tclsh86.exe
)
if [%gui_enabled%]==[1] (
  set shell=%LWDAQ_DIR%LWDAQ.app\Contents\Windows\bin\wish86.exe
)
if not exist "%shell%" (
  echo ERROR: Cannot find shell %shell%.  
  goto done
) else (
  echo Shell: "%shell%"
)

REM ------------------------------------------
REM Set the initializer script for the shell.
REM ------------------------------------------

set initializer=%LWDAQ_DIR%LWDAQ.app\Contents\LWDAQ\Init.tcl
if not exist "%initializer%" (
  echo ERROR: Cannot find initializer %initializer%.
  goto done
) else (
  echo Initializer: "%initializer%"
)

REM ------------------------------------------
REM Run LWDAQ as a separate process or a process
REM within this batch file, depending upon the
REM options.
REM ------------------------------------------

if [%background%]==[0] (
  SETLOCAL
  set path="%path%"
  "%shell%" "%initializer%" %option% %script%
)
if [%background%]==[1] (
  start "LWDAQ %option%" "%shell%" "%initializer%" %option% %script%
)

:done