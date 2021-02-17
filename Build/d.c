// A library defined in C
// On MacOS compile with:
// gcc -shared d.c -o libd.dylib
// On Linux compile with:
// gcc -shared d.c -o libd.so -fPIC

#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <math.h>

int increment(int a) {
	return a+1;
}

int printstring(char* s ) {
	printf("String passed library is: \"%s\"\n",s);
	return strlen(s);
}

double sqroot(double x) {
	return sqrt(x);
}

int reportsizes() {
    int intType;
    float floatType;
    double doubleType;
    char charType;
    printf("Reporting sizes of variable types in C:\n");
    printf("Size of int: %zu bytes\n", sizeof(intType));
    printf("Size of float: %zu bytes\n", sizeof(floatType));
    printf("Size of double: %zu bytes\n", sizeof(doubleType));
    printf("Size of char: %zu byte\n", sizeof(charType));
    return 0;
}
