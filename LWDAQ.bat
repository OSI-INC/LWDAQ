@echo off

REM
REM Long-Wire Data Acquisition Software (LWDAQ)
REM Copyright (C) 2009-2021 Kevan Hashemi, Brandeis University
REM Copyright (C) 2022-2023 Kevan Hashemi, Open Source Instruments Inc.
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
REM --no-gui, --gui, --no-console, or --spawn to launch the program in 
REM various configurations, as described in the LWDAQ manual. The options
REM --quiet and --verbose control if this batch file reports anything
REM under normal operation, verbose being the default. After the options,
REM if any, comes the name of a TCL script that will be executed by LWDAQ after 
REM it starts up. The first parameter after the options is always a configuration
REM file or an empty string. Any further parameters will be passed into
REM the LWDAQ program.
REM 

REM ------------------------------------------
REM Determine the LWDAQ directory
REM ------------------------------------------

set LWDAQ_DIR=%~p0

REM ------------------------------------------
REM Default values for options and configuration 
REM file name.
REM ------------------------------------------

set gui_enabled=1
set background=1
set option=--spawn
set verbose=0
set pmt=

REM ------------------------------------------
REM Attempt to extract options and configuration
REM file name from the command line parameters.
REM ------------------------------------------

:optionloop
set op=%1
set script=%op%
if [%op%]==[] (
	goto optiondone
)
if [%op%]==[--quiet] (
	set verbose=0
	shift
	goto optionloop
)
if [%op%]==[--verbose] (
	set verbose=1
	shift
	goto optionloop
)
if [%op%]==[--prompt] (
	set pmt=
	shift
	goto optionloop
)
if [%op%]==[--no-prompt] (
	set pmt=%op%
	shift
	goto optionloop
)
if [%op%]==[--gui] (
	set option=%op%
	set gui_enabled=1
	set background=0
	shift
	goto optionloop
)
if [%op%]==[--no-gui] (
	set option=%op%
	set gui_enabled=0
	set background=0
	shift
	goto optionloop
) 
if [%op%]==[--no-console] (
	set option=%op%
	set gui_enabled=0
	set background=1
	shift
	goto optionloop
)
if [%op%]==[--spawn] (
	set option=%op%
	set gui_enabled=1
	set background=1
	shift
	goto optionloop
)
if [%op:~0,2%] equ [--] (
	echo ERROR: Unrecognised option "%op%".
	goto done
)
:optiondone

REM ------------------------------------------
REM Assemble the remaining options into a new 
REM variable.
REM ------------------------------------------

set args=
:argloop
if [%1] neq [] (
	set args=%args% %1
	shift
	goto argloop
)

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
	) 
)

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
  echo ERROR: Cannot find shell "%shell%".  
  goto done
) 

REM ------------------------------------------
REM Report on options and configuration found.
REM ------------------------------------------
if [%verbose%]==[1] (
	echo OS: Windows
	echo OPTION: %option%
	echo GUI_ENABLED: %gui_enabled%
	echo RUN_IN_BACKGROUND: %background%
	echo LOCAL_DIR: %cd%
	if [%script%]==[] (
		echo CONFIG_FILE: None
	) else (
		echo CONFIG_FILE: %script%
	)
  	echo SHELL: "%shell%"
)

REM ------------------------------------------
REM Set the initializer script for the shell.
REM ------------------------------------------

set initializer=%LWDAQ_DIR%LWDAQ.app\Contents\LWDAQ\Init.tcl

REM ------------------------------------------
REM Run LWDAQ as a separate process or a process
REM within this batch file, depending upon the
REM options.
REM ------------------------------------------

SETLOCAL
set path="%path%"
if [%background%]==[0] (
  "%shell%" "%initializer%" %option% %pmt% %script% %args%
)
if [%background%]==[1] (
  start "LWDAQ %option%" "%shell%" "%initializer%" %option% %pmt% %script% %args%
)

:done