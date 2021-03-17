import ctypes
libd = ctypes.cdll( 'd.dll' )
libd.dll_sqrt.argtypes = [ ctypes.c_double ]
libd.dll_sqrt.restype = ctypes.c_double
libd.dll_sqrt( 9 )
libd.dll_print.argtypes = [ ctypes.c_char_p ]
libd.dll_print.restype = ctypes.c_int
libd.dll_print( b'Hello' )

