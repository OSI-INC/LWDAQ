// A shared library defined in C.
//
// On MacOS compile with:
//
// gcc -shared d.c -o libd.dylib
//
// On Linux compile with:
//
// gcc -shared d.c -o libd.so -fPIC
//
// On Windows compile with:
//
// gcc -shared d.c -o d.dll

#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <math.h>

int dll_inc(int a) {
	return a+1;
}

int dll_print(char* s ) {
	printf("String passed in to C library is: \"%s\"\n",s);
	return strlen(s);
}

double dll_sqrt(double x) {
	return sqrt(x);
}

int dll_sizes() {
    int intType;
    float floatType;
    double doubleType;
    char charType;
    printf("Reporting sizes of variable types in C:\n");
    printf("Size of int: %lu bytes\n", sizeof(intType));
    printf("Size of float: %lu bytes\n", sizeof(floatType));
    printf("Size of double: %lu bytes\n", sizeof(doubleType));
    printf("Size of char: %lu byte\n", sizeof(charType));
    return 0;
}
