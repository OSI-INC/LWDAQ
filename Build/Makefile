# LWDAQ Makefile for MacOS, Linux, and Windows. 
# =============================================

# This Makefile requires the Free Pascal Compiler (FPC).
# (C) 2004-2020, Kevan Hashemi, Brandeis University

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

# Determine the location of the TCL/TK libraries and the
# GCC libraries. On Unix, we assume the libraries are in one 
# of the default library paths. On MacOS, Linux, and Windows,
# we use the libraries bundled in LWDAQ.app.
TCL_FLAGS = 
FPC_FLAGS = -Px86_64 -O3

ifeq ($(OS),MacOS)
	TCL_FLAGS = -Ff../LWDAQ.app/Contents/Frameworks
	FPC_FLAGS = -Px86_64 -O3 -WM10.9
endif

ifeq ($(OS),Windows)
	TCL_FLAGS = -k-L../LWDAQ.app/Contents/Windows/bin
	FPC_FLAGS = -Px86_64 -O3 
endif

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

# The p target is an executable that uses all the analysis units,
# but does not need the wrapper provided by analysis.a. When we
# call fpc, we don't list all the objects it needs to link the
# executable, because it looks for those automatically, by consulting
# the main program source code.
p: p.pas $(OBJA)
	fpc $< -op.exe $(FPC_FLAGS) 

# The test target is an executable that runs a suit of tests of our
# analysis library routines.
test: test.pas $(OBJA)
	fpc $< -otest.exe $(FPC_FLAGS) 

# Compile the LWDAQ shared library. We don't list all the required
# objects in the fpc command line because fpc will look for them
# as it compiles the dynamic library.
$(LWDAQ): $(SRC_DIR)/lwdaq.pas $(OBJA) $(OBJB)
	fpc $< -o./$@ $(FPC_FLAGS) $(TCL_FLAGS)
	cp -f $@ $(LWDAQ_DIR)/$@

# Compile the analysis dynamic library as target "analysis".
analysis: $(SRC_DIR)/analysis.pas $(OBJA)
	fpc $< -FE./ $(FPC_FLAGS)
		
# Compile pascal source files into objects in the local directory. 
%.o: $(SRC_DIR)/%.pas
	fpc $< -o./$*.o $(FPC_FLAGS)
	
# Clean up all intermediate and product files.
clean: 
	rm -f *.o *.ppu *.res *.so* *.a *.exe *.dylib
	
