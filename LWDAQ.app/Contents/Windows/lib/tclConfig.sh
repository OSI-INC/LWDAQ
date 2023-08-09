# tclConfig.sh --
#
# This shell script (for sh) is generated automatically by Tcl's
# configure script.  It will create shell variables for most of
# the configuration options discovered by the configure script.
# This script is intended to be included by the configure scripts
# for Tcl extensions so that they don't have to figure this all
# out for themselves.
#
# The information in this file is specific to a single platform.

TCL_DLL_FILE="tcl87.dll"

# Tcl's version number.
TCL_VERSION='8.7'
TCL_MAJOR_VERSION='8'
TCL_MINOR_VERSION='7'
TCL_PATCH_LEVEL='a6'

# C compiler to use for compilation.
TCL_CC='gcc'

# -D flags for use with the C compiler.
TCL_DEFS='-DPACKAGE_NAME=\"tcl\" -DPACKAGE_TARNAME=\"tcl\" -DPACKAGE_VERSION=\"8.7\" -DPACKAGE_STRING=\"tcl\ 8.7\" -DPACKAGE_BUGREPORT=\"\" -DPACKAGE_URL=\"\" -DTCL_CFGVAL_ENCODING=\"utf-8\" -DHAVE_STDIO_H=1 -DHAVE_STDLIB_H=1 -DHAVE_STRING_H=1 -DHAVE_INTTYPES_H=1 -DHAVE_STDINT_H=1 -DHAVE_STRINGS_H=1 -DHAVE_SYS_STAT_H=1 -DHAVE_SYS_TYPES_H=1 -DHAVE_UNISTD_H=1 -DSTDC_HEADERS=1 -DMODULE_SCOPE=extern -DTCL_CFG_DO64BIT=1 -DHAVE_NO_SEH=1 -DHAVE_STDBOOL_H=1 -DHAVE_CAST_TO_UNION=1 -DTCL_WITH_EXTERNAL_TOMMATH=1 -DMP_64BIT=1 -DHAVE_ZLIB=1 -DHAVE_INTPTR_T=1 -DHAVE_UINTPTR_T=1 -DZIPFS_BUILD=1 -DHAVE_INTRIN_H=1 -DHAVE_WSPIAPI_H=1 -DNDEBUG=1 -DTCL_CFG_OPTIMIZED=1'

# TCL_DBGX used to be used to distinguish debug vs. non-debug builds.
# This was a righteous pain so the core doesn't do that any more.
# DEPRECATED, will be removed in Tcl 9!
TCL_DBGX=''

# Default flags used in an optimized and debuggable build, respectively.
TCL_CFLAGS_DEBUG='-g'
TCL_CFLAGS_OPTIMIZE='-O2 -fomit-frame-pointer'

# Default linker flags used in an optimized and debuggable build, respectively.
TCL_LDFLAGS_DEBUG=''
TCL_LDFLAGS_OPTIMIZE=''

# Flag, 1: we built a shared lib, 0 we didn't
TCL_SHARED_BUILD=1

# The name of the Tcl library (may be either a .a file or a shared library):
TCL_LIB_FILE='libtcl87.dll.a'

# The name of a zip containing the /library and /encodings (may be either a .zip file or a shared library):
TCL_ZIP_FILE='libtcl8.7a6.zip'

# Flag to indicate whether shared libraries need export files.
TCL_NEEDS_EXP_FILE=

# String that can be evaluated to generate the part of the export file
# name that comes after the "libxxx" (includes version number, if any,
# extension, and anything else needed).  May depend on the variables
# VERSION.  On most UNIX systems this is ${VERSION}.exp.
TCL_EXPORT_FILE_SUFFIX='${NODOT_VERSION}.a'

# Additional libraries to use when linking Tcl.
TCL_LIBS='-lnetapi32 -lkernel32 -luser32 -ladvapi32 -luserenv -lws2_32'

# Top-level directory in which Tcl's platform-independent files are
# installed.
TCL_PREFIX='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release'

# Top-level directory in which Tcl's platform-specific files (e.g.
# executables) are installed.
TCL_EXEC_PREFIX='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release'

# Flags to pass to cc when compiling the components of a shared library:
TCL_SHLIB_CFLAGS=''

# Flags to pass to cc to get warning messages
TCL_CFLAGS_WARNING='-Wall -Wextra -Wshadow -Wundef -Wwrite-strings -Wpointer-arith -Wc++-compat -fextended-identifiers'

# Extra flags to pass to cc:
TCL_EXTRA_CFLAGS='-pipe -DHAVE_CPUID=1 -finput-charset=UTF-8'

# Base command to use for combining object files into a shared library:
TCL_SHLIB_LD='${CC} -shared'

# Base command to use for combining object files into a static library:
TCL_STLIB_LD='${AR} cr'

# Either '$LIBS' (if dependent libraries should be included when linking
# shared libraries) or an empty string.  See Tcl's configure.ac for more
# explanation.
TCL_SHLIB_LD_LIBS='${LIBS}'

# Suffix to use for the name of a shared library.
TCL_SHLIB_SUFFIX='.dll'

# Library file(s) to include in tclsh and other base applications
# in order to provide facilities needed by DLOBJ above.
TCL_DL_LIBS=''

# Flags to pass to the compiler when linking object files into
# an executable tclsh or tcltest binary.
TCL_LD_FLAGS=''

# Flags to pass to cc/ld, such as "-R /usr/local/tcl/lib", that tell the
# run-time dynamic linker where to look for shared libraries such as
# libtcl.so.  Used when linking applications.  Only works if there
# is a variable "LIB_RUNTIME_DIR" defined in the Makefile.
TCL_CC_SEARCH_FLAGS=''
TCL_LD_SEARCH_FLAGS=''

# Additional object files linked with Tcl to provide compatibility
# with standard facilities from ANSI C or POSIX.
TCL_COMPAT_OBJS=''

# Name of the ranlib program to use.
TCL_RANLIB='ranlib'

# -l flag to pass to the linker to pick up the Tcl library
TCL_LIB_FLAG=''

# String to pass to linker to pick up the Tcl library from its
# build directory.
TCL_BUILD_LIB_SPEC='-LE:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tcl/win -ltcl87'

# String to pass to linker to pick up the Tcl library from its
# installed directory.
TCL_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib -ltcl87'

# String to pass to the compiler so that an extension can
# find installed Tcl headers.
TCL_INCLUDE_SPEC='-I/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/include'

# Indicates whether a version numbers should be used in -l switches
# ("ok" means it's safe to use switches like -ltcl7.5;  "nodots" means
# use switches like -ltcl75).  SunOS and FreeBSD require "nodots", for
# example.
TCL_LIB_VERSIONS_OK=''

# String that can be evaluated to generate the part of a shared library
# name that comes after the "libxxx" (includes version number, if any,
# extension, and anything else needed).  May depend on the variables
# VERSION and SHLIB_SUFFIX.  On most UNIX systems this is
# ${VERSION}${SHLIB_SUFFIX}.
TCL_SHARED_LIB_SUFFIX='${NODOT_VERSION}.dll'

# String that can be evaluated to generate the part of an unshared library
# name that comes after the "libxxx" (includes version number, if any,
# extension, and anything else needed).  May depend on the variable
# VERSION.  On most UNIX systems this is ${VERSION}.a.
TCL_UNSHARED_LIB_SUFFIX='${NODOT_VERSION}.a'

# Location of the top-level source directory from which Tcl was built.
# This is the directory that contains a README file as well as
# subdirectories such as generic, unix, etc.  If Tcl was compiled in a
# different place than the directory containing the source files, this
# points to the location of the sources, not the location where Tcl was
# compiled.
TCL_SRC_DIR='E:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tcl'

# List of standard directories in which to look for packages during
# "package require" commands.  Contains the "prefix" directory plus also
# the "exec_prefix" directory, if it is different.
TCL_PACKAGE_PATH='{/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib}'

# Tcl supports stub.
TCL_SUPPORTS_STUBS=1

# The name of the Tcl stub library (.a):
TCL_STUB_LIB_FILE='libtclstub87.a'

# -l flag to pass to the linker to pick up the Tcl stub library
TCL_STUB_LIB_FLAG='-ltclstub87'

# String to pass to linker to pick up the Tcl stub library from its
# build directory.
TCL_BUILD_STUB_LIB_SPEC='-LE:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tcl/win -ltclstub87'

# String to pass to linker to pick up the Tcl stub library from its
# installed directory.
TCL_STUB_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib -ltclstub87'

# Path to the Tcl stub library in the build directory.
TCL_BUILD_STUB_LIB_PATH='E:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tcl/win/libtclstub87.a'

# Path to the Tcl stub library in the install directory.
TCL_STUB_LIB_PATH='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/libtclstub87.a'
