# tkConfig.sh --
#
# This shell script (for sh) is generated automatically by Tk's
# configure script.  It will create shell variables for most of
# the configuration options discovered by the configure script.
# This script is intended to be included by the configure scripts
# for Tk extensions so that they don't have to figure this all
# out for themselves.  This file does not duplicate information
# already provided by tclConfig.sh, so you may need to use that
# file in addition to this one.
#
# The information in this file is specific to a single platform.

TK_DLL_FILE="tk87.dll"

# Tk's version number.
TK_VERSION='8.7'
TK_MAJOR_VERSION='8'
TK_MINOR_VERSION='7'
TK_PATCH_LEVEL='a6'

# -D flags for use with the C compiler.
TK_DEFS='-DPACKAGE_NAME=\"tk\" -DPACKAGE_TARNAME=\"tk\" -DPACKAGE_VERSION=\"8.7\" -DPACKAGE_STRING=\"tk\ 8.7\" -DPACKAGE_BUGREPORT=\"\" -DPACKAGE_URL=\"\" -DHAVE_STDIO_H=1 -DHAVE_STDLIB_H=1 -DHAVE_STRING_H=1 -DHAVE_INTTYPES_H=1 -DHAVE_STDINT_H=1 -DHAVE_STRINGS_H=1 -DHAVE_SYS_STAT_H=1 -DHAVE_SYS_TYPES_H=1 -DHAVE_UNISTD_H=1 -DSTDC_HEADERS=1 -DMODULE_SCOPE=extern -DTCL_CFG_DO64BIT=1 -DHAVE_NO_SEH=1 -DHAVE_STDBOOL_H=1 -DHAVE_CAST_TO_UNION=1 -DHAVE_INTPTR_T=1 -DHAVE_UINTPTR_T=1 -DHAVE_INTPTR_T=1 -DHAVE_UINTPTR_T=1 -DNDEBUG=1 -DTCL_CFG_OPTIMIZED=1 -DZIPFS_BUILD=1'

# Flag, 1: we built a shared lib, 0 we didn't
TK_SHARED_BUILD=1

# TK_DBGX used to be used to distinguish debug vs. non-debug builds.
# This was a righteous pain so the core doesn't do that any more.
TK_DBGX=

# The name of the Tk library (may be either a .a file or a shared library):
TK_LIB_FILE='libtk87.dll.a'

# Additional libraries to use when linking Tk.
TK_LIBS='-lnetapi32 -lkernel32 -luser32 -ladvapi32 -luserenv -lws2_32 -lgdi32 -lcomdlg32 -limm32 -lcomctl32 -lshell32 -luuid -lole32 -loleaut32 -lwinspool'

# Top-level directory in which Tcl's platform-independent files are
# installed.
TK_PREFIX='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release'

# Top-level directory in which Tcl's platform-specific files (e.g.
# executables) are installed.
TK_EXEC_PREFIX='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release'

# -l flag to pass to the linker to pick up the Tcl library
TK_LIB_FLAG='-l87'

# String to pass to linker to pick up the Tk library from its
# build directory.
TK_BUILD_LIB_SPEC='-LE:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tk/win -l87'

# String to pass to linker to pick up the Tk library from its
# installed directory.
TK_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib -l87'

# Location of the top-level source directory from which Tk was built.
# This is the directory that contains a README file as well as
# subdirectories such as generic, unix, etc.  If Tk was compiled in a
# different place than the directory containing the source files, this
# points to the location of the sources, not the location where Tk was
# compiled.
TK_SRC_DIR='E:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tk'

# Needed if you want to make a 'fat' shared library library
# containing tk objects or link a different wish.
TK_CC_SEARCH_FLAGS=''
TK_LD_SEARCH_FLAGS=''

# The name of the Tk stub library (.a):
TK_STUB_LIB_FILE='libtkstub87.a'

# -l flag to pass to the linker to pick up the Tk stub library
TK_STUB_LIB_FLAG='-ltkstub87'

# String to pass to linker to pick up the Tk stub library from its
# build directory.
TK_BUILD_STUB_LIB_SPEC='-LE:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tk/win -ltkstub87'

# String to pass to linker to pick up the Tk stub library from its
# installed directory.
TK_STUB_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib -ltkstub87'

# Path to the Tk stub library in the build directory.
TK_BUILD_STUB_LIB_PATH='E:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tk/win/libtkstub87.a'

# Path to the Tk stub library in the install directory.
TK_STUB_LIB_PATH='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/libtkstub87.a'
