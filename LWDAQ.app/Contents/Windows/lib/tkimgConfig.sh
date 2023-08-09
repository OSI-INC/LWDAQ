# tkimgConfig.sh --
#
# This shell script (for sh) is generated automatically by tkimg's
# configure script.  It will create shell variables for most of
# the configuration options discovered by the configure script.
# This script is intended to be included by the configure scripts
# for tkimg extensions so that they don't have to figure this all
# out for themselves.  This file does not duplicate information
# already provided by tclConfig.sh, so you may need to use that
# file in addition to this one.
#
# The information in this file is specific to a single platform.

# tkimg's version number.
tkimg_VERSION='1.4.15'
tkimg_MAJOR_VERSION=''
tkimg_MINOR_VERSION=''
tkimg_RELEASE_LEVEL=''

# The name of the tkimg library (may be either a .a file or a shared library):
tkimg_LIB_FILE=tkimg1415.dll

# String to pass to linker to pick up the tkimg library from its
# build directory.
tkimg_BUILD_LIB_SPEC='-LE:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tkimg/base -ltkimg1415'

# String to pass to linker to pick up the tkimg library from its
# installed directory.
tkimg_LIB_SPEC='-LE:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/tkimg1.4.15 -ltkimg1415'

# The name of the tkimg stub library (a .a file):
tkimg_STUB_LIB_FILE=libtkimgstub1415.a

# String to pass to linker to pick up the tkimg stub library from its
# build directory.
tkimg_BUILD_STUB_LIB_SPEC='-LE:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tkimg/base -ltkimgstub1415'

# String to pass to linker to pick up the tkimg stub library from its
# installed directory.
tkimg_STUB_LIB_SPEC='-LE:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/tkimg1.4.15 -ltkimgstub1415'

# String to pass to linker to pick up the tkimg stub library from its
# build directory.
tkimg_BUILD_STUB_LIB_PATH='E:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/tkimg/base/libtkimgstub1415.a'

# String to pass to linker to pick up the tkimg stub library from its
# installed directory.
tkimg_STUB_LIB_PATH='E:/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/tkimg1.4.15/libtkimgstub1415.a'

# Location of the top-level source directories from which tkimg
# was built.  This is the directory that contains generic, unix, etc.
# If tkimg was compiled in a different place than the directory
# containing the source files, this points to the location of the
# sources, not the location where tkimg was compiled. This can
# be relative to the build directory.

tkimg_SRC_DIR='.'
