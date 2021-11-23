# LWDAQ Makefile for MacOS, Linux, and Windows. 
# =============================================

# This Makefile requires the Free Pascal Compiler (FPC).
# (C) 2004-2020, Kevan Hashemi, Brandeis University
# (C) 2021, Kevan Hashemi, Open Source Instruments Inc.

# Determine the operating system. Our Default
# operating system is Unix.
OS = Unix
ifneq ($(shell uname -a | grep -i Darwin),)
	OS = MacOS
endif
ifneq ($(shell uname -a | grep -i Windows),)
	OS = Windows
endif
ifneq ($(shell uname -a | grep -i Linux),)
	OS = Linux
endif

# Determine the local architecture. We support only 64-bit Intel.
ARCH = x86_64

# Determine the location of the TCL/TK libraries and the GCC libraries. On Unix,
# we assume the libraries are in one of the default library paths.
TCL_FLAGS = 
FPC_FLAGS = -Px86_64 -O3

# On Windows, we tell FPC compiler where it can find the TclTk libraries, so
# that it can embed a path to these libraries in the compiled object. At
# run-time, the dynamic linker will check to see if the libraries with the
# specified path are loaded, and if so, link to them. If the libraries are not
# loaded, the dynamic linker will load them from disk. The TclTk libraries are
# in a Framework directory structure that FPC understands. We specify the
# framework directory with the -Ff flag.
ifeq ($(OS),MacOS)
	TCL_FLAGS = -Ff../LWDAQ.app/Contents/Frameworks
	FPC_FLAGS = -Px86_64 -O3 -WM10.9
endif

# On Windows, we tell FPC where it can find the TclTk libraries, so that it can
# embed a path to these libraries in the compiled object. At run-time, the
# dynamic linker will check to see if the libraries with the specified path are
# loaded, and if so, link to them. If the libraries are not loaded, the dynamic
# linker will load them from disk. The TclTk libraries are in a particular place
# in our LWDAQ bundle, and must be named X.dll, where X is the library root name
# we specify in our Pascal code. 
ifeq ($(OS),Windows)
	TCL_FLAGS = -k-L../LWDAQ.app/Contents/Windows/bin
	FPC_FLAGS = -Px86_64 -O3
endif

# On Linux, weak linking is the default, so we don't have to tell the Pascal
# compiler the location of the TclTk libraries at compile time. At run-time, 
# the dynamic linker will try to resolve undefined symbols by looking at those
# libraries already loaded by the process and the operating syste. The Pascal
# routines that call TclTk routines will be linked to the TclTk libraries loaded
# by the LWDAQ process, which is itself a TclTk interpreter. The -Cg option
# tells FPC to generate position-independent code (PIC), which is necessary for
# the ultimate creation of a dynamic link library.
ifeq ($(OS),Linux)
	TCL_FLAGS = 
	FPC_FLAGS = -Px86_64 -O3 -Cg
endif

# Names and locations of shared libraries.
LWDAQ_DIR = ../LWDAQ.app/Contents/LWDAQ
LWDAQ = lwdaq.so_$(OS)

# Location of the Pascal sources for units and libraries.
SRC_DIR = ../Sources

# Objects required to create LWDAQ, ANALYSIS, and p targets.
OBJA = utils.o images.o transforms.o image_manip.o rasnik.o spot.o bcam.o \
	shadow.o wps.o electronics.o metrics.o

# Objects required by LWDAQ only.
OBJB = tcltk.o

# Our default product is the LWDAQ shared library.
products: $(LWDAQ)

# The p target is an executable that uses all the analysis units, but does not
# need the wrapper provided by analysis.a. When we call fpc, we don't list all
# the objects it needs to link the executable, because it looks for those
# automatically, by consulting the main program source code.
p: p.pas $(OBJA)
	fpc $< -op.exe $(FPC_FLAGS) 

# The test target is an executable that runs a suit of tests of our analysis
# library routines.
test: test.pas $(OBJA)
	fpc $< -otest.exe $(FPC_FLAGS)

# Compile the LWDAQ shared library. We don't list all the required objects in
# the fpc command line because fpc will look for them as it compiles the dynamic
# library. On MacOS when compiling our library with refence to the Tcl 8.7 
# framework, we find that the Tcl library self-reference is an absolute path
# to the Tcl library in a /Library subdirectory, as if it had been installed
# in the operating system, so our lwdaq library will try to find the Tcl 
# library in the /Library location, where it may not exist, and even if it 
# does exist, we don't want to use it. We change the path to the Tcl library
# used by our lwdaq library using the install_name_tool command.
$(LWDAQ): $(SRC_DIR)/lwdaq.pas $(OBJA) $(OBJB)
	fpc $< -o./$@ $(FPC_FLAGS) $(TCL_FLAGS)
	cp -f $@ $(LWDAQ_DIR)/$@
ifeq ($(OS),MacOS)
	install_name_tool -change \
	  /Library/Frameworks/Tcl.framework/Versions/8.7/Tcl \
	  @executable_path/../Frameworks/Tcl.framework/Versions/8.7/Tcl \
	  $(LWDAQ_DIR)/$@
endif

# Compile the analysis dynamic library as target "analysis".
analysis: $(SRC_DIR)/analysis.pas $(OBJA)
	fpc $< -FE./ $(FPC_FLAGS)
		
# Compile pascal source files into objects in the local directory. 
%.o: $(SRC_DIR)/%.pas
	fpc $< -o./$*.o $(FPC_FLAGS)
	
# Clean up all intermediate and product files.
clean: 
	rm -f *.o *.ppu *.res *.so* *.a *.exe *.dylib *.dll
	
