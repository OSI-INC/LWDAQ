# vectclConfig.sh --
# 
# This shell script (for sh) is generated automatically by VecTcl's
# configure script.  It will create shell variables for most of
# the configuration options discovered by the configure script.
# This script is intended to be included by the configure scripts
# for VecTcl extensions so that they don't have to figure this all
# out for themselves.  This file does not duplicate information
# already provided by tclConfig.sh, so you may need to use that
# file in addition to this one.
#
# The information in this file is specific to a single platform.

# VecTcl's version number.
vectcl_VERSION='0.3'
VECTCL_VERSION='0.3'

# The name of the VecTcl library (may be either a .a file or a shared library):
vectcl_LIB_FILE=vectcl03.dll
VECTCL_LIB_FILE=vectcl03.dll

# String to pass to linker to pick up the VecTcl library from its
# build directory.
vectcl_BUILD_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/vectcl -lvectcl03'
VECTCL_BUILD_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/vectcl -lvectcl03'

# String to pass to linker to pick up the VecTcl library from its
# installed directory.
vectcl_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/vectcl0.3 -lvectcl03'
VECTCL_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/vectcl0.3 -lvectcl03'

# The name of the VecTcl stub library (a .a file):
vectcl_STUB_LIB_FILE=libvectclstub03.a
VECTCL_STUB_LIB_FILE=libvectclstub03.a

# String to pass to linker to pick up the VecTcl stub library from its
# build directory.
vectcl_BUILD_STUB_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/vectcl -lvectclstub03'
VECTCL_BUILD_STUB_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/vectcl -lvectclstub03'

# String to pass to linker to pick up the VecTcl stub library from its
# installed directory.
vectcl_STUB_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/vectcl0.3 -lvectclstub03'
VECTCL_STUB_LIB_SPEC='-L/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/vectcl0.3 -lvectclstub03'

# String to pass to linker to pick up the VecTcl stub library from its
# build directory.
vectcl_BUILD_STUB_LIB_PATH='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/vectcl/libvectclstub03.a'
VECTCL_BUILD_STUB_LIB_PATH='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/rcompile/vectcl/libvectclstub03.a'

# String to pass to linker to pick up the VecTcl stub library from its
# installed directory.
vectcl_STUB_LIB_PATH='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/vectcl0.3/libvectclstub03.a'
VECTCL_STUB_LIB_PATH='/e/gitlab-runner/builds/Uyyf6o_gt/0/product/tcltk/release/lib/vectcl0.3/libvectclstub03.a'

# String to pass to the compiler so that an extension can
# find installed VecTcl headers.
vectcl_INCLUDE_SPEC='@vectcl_INCLUDE_SPEC@'
VECTCL_INCLUDE_SPEC='@vectcl_INCLUDE_SPEC@'
