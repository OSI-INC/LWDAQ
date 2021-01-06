import ctypes
_libd = ctypes.CDLL( './libd.dylib' )
def inc( a ):
    return _libd.increment( ctypes.c_int( a ) )
