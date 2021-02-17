import ctypes

def call( library, routine, data_types, inputs ):

    '''
    This function calls a routine from a dynamic link library, returning its
    output.


    Arguments:

    library: String. The location and name of the dynamic link library. Ex:
    './lib_a.so' or '../folder_b/lib_b.so'

    routine: String. The name of the routine.

    data_types: List. The elements of it should be strings saying the C data
    types for each input from 'inputs'. Ex: [ 'c_int', 'c_float', 'c_wchar_p' ],
    which are int, float, and string in python respectively.

    inputs: List. The elements of it should be the arguments of the routine.
    They can vary in python data types. Use empty list if no argument is needed.
    Ex: [ 23, 3.141, 'hello, world' ]

    For more information on data types in ctypes, visit
    https://docs.python.org/3/library/ctypes.html#fundamental-data-types

    '''


    # Error messages

    fn = __file__.split('/')[-1].split('.')[0]

    if type( library ) != str:

        print( 'Error from ' + fn + '.call. ' )
        print( 'Error: Argument "library" should be a string. ' )

        return None

    if type( routine ) != str:

        print( 'Error from ' + fn + '.call. ' )
        print( 'Error: Argument "routine" should be a string. ' )

        return None


    if type( data_types ) != list or type( inputs ) != list:

        print( 'Error from ' + fn + '.call. ' )
        print( 'Error: Arguments "data_types" and "inputs" should be lists. ' )

        return None

    if len( data_types ) != len( inputs ):

        print( 'Error from ' + fn + '.call. ' )
        print( 'Error: Lists "data_types" and "inputs" should have the same length. ' )

        return None


    # global variable for the dynamic link library

    global lib

    lib = ctypes.CDLL( library )


    # initialize list for arguments

    args = []


    # iterate through inputs with their data types to have strings saying things such as:
    # ctypes.c_int(100)

    for ( dt, inp ) in zip( data_types, inputs ):

        if type( inp ) == str:

            inp = '\"' + inp + '\"'

        args.append( 'ctypes.' + dt + '(' + str(inp) + ')' )


    # write string that calls the routine from the lib, with argument(s) listed
    # ex: lib.routine_a( ctypes.c_int( 100 ), ctypes.c_float(3.141) )

    args_joint = ','.join( args )

    code_str = 'lib.' + routine + '(' + args_joint + ')'


    # print( code_str )


    # Execute the string of code and store the output. 

    exec( 'output = ' + code_str, globals() )

    return output
