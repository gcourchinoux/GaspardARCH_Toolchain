typedef unsigned long U;
volatile U signature;
#define NI __attribute__((noinline))
NI long rec(long n) {return n<2?1:n*rec(n-1);}
NI long ten(long a,long b,long c,long d,long e,long f,long g,long h,long i,long j)
{return a+2*b+3*c+4*d+5*e+6*f+7*g+8*h+9*i+10*j;}
NI U largeframe(U x) {volatile U a[600];a[0]=x;a[599]=7;return a[0]+a[599];}
NI long cvt(signed char a,unsigned char b,short c,unsigned short d,int e,unsigned int f)
{return a+b+c+d+e+(long)f;}
struct pair {long a,b;};
NI struct pair pairs(struct pair p) {struct pair q;q.a=p.b+1;q.b=p.a+2;return q;}
NI int choice(int n) {switch(n){case 1:return 9;case 2:return 7;case 3:return 5;case 4:return 3;case 5:return 1;default:return -1;}}
NI U shifts(U a,unsigned n){return (a>>n)^(a<<n);}
NI long indirect(long (*f)(long),long n) {return f(n);}
void *memcpy(void *d,const void *s,U n){unsigned char *a=d;const unsigned char*b=s;while(n--)*a++=*b++;return d;}
void *memset(void *d,int c,U n){unsigned char*a=d;while(n--)*a++=c;return d;}
int main(void)
{
 U errors=0;struct pair a={11,29},b;
 if(rec(7)!=5040)errors|=1;
 if(ten(1,2,3,4,5,6,7,8,9,10)!=385)errors|=2;
 if(largeframe(35)!=42)errors|=4;
 if(cvt(-7,250,-300,60000,-40000,4000000000U)!=4000019943L)errors|=8;
 b=pairs(a);if(b.a!=30||b.b!=13)errors|=16;
 if(choice(3)!=5||choice(9)!=-1)errors|=32;
 if(indirect(rec,6)!=720)errors|=64;
 if(shifts(0x123456789abcdef0UL,17)!=0xacf13c6396dc4d5eUL)errors|=128;
 signature=errors?errors:0x600d;return errors!=0;
}
