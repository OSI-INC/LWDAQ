#include <stdio.h>
#include <string.h>
#include <stddef.h>

int func( int a, float b, wchar_t* c ) {

	printf( "The integer argument is: %i\n", a );
	printf( "Doubling the integer gives: %i\n\n", (a*2) );

	printf( "The float argument is: %f\n", b );
	printf( "Doubling the float is: %f\n\n", (b*2.) );

	printf( "The string argument is: %ls\n", c );

	return 0;
}
