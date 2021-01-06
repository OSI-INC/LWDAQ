# library neaded

import ctypes


# creat an instance of the dynamic link library

_libd = ctypes.CDLL( './libd.so' )


# define a python function to call a routine in the DLL

def inc( a ):

    return _libd.increment( ctypes.c_int( a ) )


# ctypes.c_int( a ) convert python int "a" to C int. "a" not being an int will raise data type error. 
