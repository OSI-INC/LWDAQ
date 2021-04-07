# Python Test Interface [25-MAR-21]
# (c) 2021 Xinfei Huang, Brandeis University
# (c) 2021 Kevan Hashemi, Brandeis University 

# To load and reload this libary use:
# import importlib
# importlib.reload(dll)

# Import the ctypes module that allows us to work with dynamic libraries.
import ctypes

# import the os module that allows us to get directory listings.
import os

# Two ways to load the dll, one commented out.
libd = ctypes.CDLL( os.getcwd() + r'/analysis.dll' )

# The dll_inc routine takes a four-byte integer as input, increments the
# integer, and returns it as a four-byte integer.
x = 999
libd.dll_inc.argtypes = [ ctypes.c_int ]
libd.dll_sqrt.restype = ctypes.c_int
print('Increment of',x,'is',libd.dll_inc(x))

# For each routine we want to use, we define its argument types and result
# types. We begin with the dll_sqrt routine, which takes an eight-byte real
# argument and returns an eight-byte real result. To run the square root
# routine, the library must have loaded a math library of some kind.
libd.dll_sqrt.argtypes = [ ctypes.c_double ]
libd.dll_sqrt.restype = ctypes.c_double
x = 123456.00
print('The square root of %.1f' %x,'is %.1f.' %libd.dll_sqrt(x))

# The dll_print routine accepts a pointer to a null-terminated string and
# returns the length of the string as an integer. The print routine itself
# printes the string to the console. To run the print routine, the library
# must have loaded a console library of some kind.
libd.dll_print.argtypes = [ ctypes.c_char_p ]
libd.dll_print.restype = ctypes.c_int
s = b'Greetings from Python'
print('Library says string length was',libd.dll_print(s),'characters')

# The random_0_to_1 routine takes no parameters and returns an eight-byte
# real-valued number between zero and one. The library must have loaded
# a math library of some kind.
libd.random_0_to_1.argtypes = [ ]
libd.random_0_to_1.restype = ctypes.c_double
print('Here is a random number between zero and one: %.3f' %libd.random_0_to_1())

# The error_function routine returns the error function of an eight-byte
# real. The result is an eight-byte real.
x = 2.0
libd.error_function.argtypes = [ ctypes.c_double ]
libd.error_function.restype = ctypes.c_double
print('Error function of %.3f' %x,'is %.6f' %libd.error_function(x))

# Image-handling routines.
from PIL import Image

def main():
    return None

def daq_to_bytes( img_dir ):    
    f = open( img_dir, 'rb' )
    b = f.read()
    return b

def display_bytes( byte_obj ):
    b_info = byte_obj[:12]
    rows = int( b_info[0] )*16*16 + int( b_info[1] ) + 1
    columns = int( b_info[2] )*16*16 + int( b_info[3] ) + 1
    im = Image.frombytes( 'P', ( columns, rows ), byte_obj, 'raw' )
    im.show()
    return None
    
def display_gif( img_dir ):
    im = Image.open( img_dir )
    im.show()
    return None

if __name__ == '__main__':
    main()

# The following routines exercise our image methods library.
#import img_methods
#bytes_obj = daq_to_bytes('Rasnik.daq' )
#display_bytes( bytes_obj ) 

