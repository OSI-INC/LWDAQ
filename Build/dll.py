import ctypes
libd = ct.CDLL( './libd.so' )
libd.dll_sqrt.argtypes = [ ct.c_double ]
libd.dll_sqrt.restype = ct.c_double
libd.dll_sqrt( 9 )
libd.dll_print.argtypes = [ ct.c_char_p ]
libd.dll_print.restype = ct.c_int
libd.dll_print( b'Hello' )

