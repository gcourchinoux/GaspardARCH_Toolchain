"""Limited integer execution model used for compiler smoke tests, not a hardware simulator."""
from pathlib import Path
import struct
MASK=(1<<64)-1
def sx(v,n):return (v^(1<<(n-1)))-(1<<(n-1))
def execute(path,limit=1000000):
    b=Path(path).read_bytes();mem={};regs=[0]*32
    pc=struct.unpack_from('<Q',b,24)[0];po=struct.unpack_from('<Q',b,32)[0];pe,pn=struct.unpack_from('<HH',b,54)
    for i in range(pn):
        typ,fl,off,va,pa,fs,ms,al=struct.unpack_from('<IIQQQQQQ',b,po+i*pe)
        if typ==1:
            for k,v in enumerate(b[off:off+fs]):mem[va+k]=v
    def read(a,n):
        if a%n:raise ValueError('unaligned read '+hex(a))
        return sum(mem.get(a+i,0)<<(8*i) for i in range(n))
    def write(a,v,n):
        if a%n:raise ValueError('unaligned store '+hex(a))
        for i in range(n):mem[a+i]=(v>>(8*i))&255
    for steps in range(limit):
        if pc&3:raise ValueError('unaligned PC')
        w=read(pc,4);op=w&127;d=(w>>7)&31;f=(w>>12)&7;a=(w>>15)&31;c=(w>>20)&31;fun=w>>25
        x=regs[a];y=regs[c];imm=sx(w>>20,12);nextpc=pc+4;val=None;word=False
        if op in [0x33,0x3b]:
            word=op==0x3b;n=32 if word else 64;xx=x&((1<<n)-1);yy=y&((1<<n)-1)
            if fun==1:
                if f==0:val=xx*yy
                elif f in [4,5,6,7]:
                    if not yy:raise ValueError('division by zero')
                    v1=sx(xx,n) if f in [4,6] else xx;v2=sx(yy,n) if f in [4,6] else yy
                    q=(abs(v1)//abs(v2))*(-1 if (v1<0)!=(v2<0) else 1)
                    val=q if f in [4,5] else v1-q*v2
                else:raise ValueError('unimplemented multiply-high')
            elif f==0:val=xx-yy if fun==32 else xx+yy
            elif f==1:val=xx<<(yy&(n-1))
            elif f==2:val=int(sx(xx,n)<sx(yy,n))
            elif f==3:val=int(xx<yy)
            elif f==4:val=xx^yy
            elif f==5:val=(sx(xx,n) if fun==32 else xx)>>(yy&(n-1))
            elif f==6:val=xx|yy
            elif f==7:val=xx&yy
        elif op in [0x13,0x1b]:
            word=op==0x1b;n=32 if word else 64;xx=x&((1<<n)-1);sh=c if word else (w>>20)&63
            if f==0:val=xx+imm
            elif f==1:val=xx<<sh
            elif f==2:val=int(sx(x,64)<imm)
            elif f==3:val=int(x<(imm&MASK))
            elif f==4:val=x^(imm&MASK)
            elif f==5:val=(sx(xx,n) if w&(1<<30) else xx)>>sh
            elif f==6:val=x|(imm&MASK)
            elif f==7:val=x&(imm&MASK)
        elif op==0x37:val=sx(w&0xfffff000,32)
        elif op==0x17:val=pc+sx(w&0xfffff000,32)
        elif op==3:
            size=1<<(f&3);v=read((x+imm)&MASK,size);val=v if f>=4 else sx(v,size*8)
        elif op==0x23:
            off=sx(((w>>25)<<5)|((w>>7)&31),12);write((x+off)&MASK,y,1<<f)
        elif op==0x63:
            cond={0:x==y,1:x!=y,4:sx(x,64)<sx(y,64),5:sx(x,64)>=sx(y,64),6:x<y,7:x>=y}[f]
            if cond:nextpc=pc+sx(((w>>25)<<5)|((w>>7)&31),12)*4
        elif op==0x6f:val=pc+4;nextpc=pc+sx(w>>12,20)*4
        elif op==0x67:val=pc+4;nextpc=(x+imm)&~3
        elif op!=0x0f:raise ValueError('unknown instruction '+hex(w)+' at '+hex(pc))
        if val is not None and d:regs[d]=(sx(val&0xffffffff,32) if word else val)&MASK
        regs[0]=0
        if nextpc==pc and op==0x6f and d==0:return mem,steps+1
        pc=nextpc&MASK
    raise ValueError('instruction limit exceeded')

def symbols(path):
    b=Path(path).read_bytes();o=struct.unpack_from('<Q',b,40)[0];e,n,ss=struct.unpack_from('<HHH',b,58)
    sh=[struct.unpack_from('<IIQQQQIIQQ',b,o+i*e) for i in range(n)];out={}
    for s in sh:
        if s[1]!=2:continue
        strings=sh[s[6]];st=b[strings[4]:strings[4]+strings[5]]
        for p in range(s[4],s[4]+s[5],s[9]):
            name,info,other,ndx,value,size=struct.unpack_from('<IBBHQQ',b,p)
            if name:out[st[name:st.index(0,name)].decode()]=value
    return out
