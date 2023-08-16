#!/bin/sh
DoExitAsm ()
{ echo "An error occurred while assembling $1"; exit 1; }
DoExitLink ()
{ echo "An error occurred while linking $1"; exit 1; }
OFS=$IFS
IFS="
"
/Library/Developer/CommandLineTools/usr/bin/ld       -order_file ./symbol_order.fpc -dynamic -dylib -multiply_defined suppress -L. -o /Users/haleyhashemi/OSI/LWDAQ/Build/lwdaq.so_MacOS `cat ./link1537.res` -filelist ./linkfiles1537.res -exported_symbols_list ./linksyms1537.fpc
if [ $? != 0 ]; then DoExitLink ; fi
IFS=$OFS
