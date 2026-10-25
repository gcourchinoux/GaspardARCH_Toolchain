/* { dg-do compile } */
/* { dg-options "-O2 -ffreestanding" } */
long add64(long a,long b) { return a+b; }
int add32(int a,int b) { return a+b; }
long load64(const long *p) { return *p; }
int cmp(long a,long b) { return a < b; }
extern long other(long);
long nonleaf(long x) { return other(x)+x; }
