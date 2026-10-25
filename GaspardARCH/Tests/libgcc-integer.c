typedef unsigned long U;
volatile U input=0x0123456789abcdefUL;
volatile U signature;
int main(void)
{
 U v=input;int bad=0;
 if(__builtin_popcountl(v)!=32)bad|=1;
 if(__builtin_clzl(v)!=7)bad|=2;
 if(__builtin_ctzl(v)!=0)bad|=4;
 if(__builtin_bswap64(v)!=0xefcdab8967452301UL)bad|=8;
 signature=bad?bad:0x600d;return bad!=0;
}
