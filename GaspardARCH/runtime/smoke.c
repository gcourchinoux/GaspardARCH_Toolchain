volatile unsigned long signature;
__attribute__((noinline)) long add(long a,long b) { return a+b; }
int main(void) { long v=add(19,23); signature=(v==42)?0x600d:0xbad; return v!=42; }
