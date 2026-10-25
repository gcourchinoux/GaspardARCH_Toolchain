#!/usr/bin/env python3
"""Compare .text in a linked ELF64 against the supplied independent word list.
Usage: python verifier_elf.py chemin/test.elf [chemin/expected.txt]
No external Python packages required.
"""
import re
import struct
import sys
from pathlib import Path

def section(path, name):
    b=Path(path).read_bytes()
    if b[:6] != b'\x7fELF\x02\x01':
        raise ValueError('ELF64 little endian requis')
    if struct.unpack_from('<H',b,18)[0] != 0xfe64:
        raise ValueError('e_machine GaspardARC privé attendu : 0xfe64')
    off=struct.unpack_from('<Q',b,40)[0]
    ents,num,strings=struct.unpack_from('<HHH',b,58)
    headers=[struct.unpack_from('<IIQQQQIIQQ',b,off+i*ents) for i in range(num)]
    sh=headers[strings]; names=b[sh[4]:sh[4]+sh[5]]
    for sh in headers:
        end=names.index(b'\0',sh[0])
        if names[sh[0]:end].decode()==name:
            return sh[3],b[sh[4]:sh[4]+sh[5]]
    raise ValueError('Section absente : '+name)

def main():
    if len(sys.argv)<2:
        raise SystemExit(__doc__)
    expected=Path(sys.argv[2]) if len(sys.argv)>2 else Path(__file__).resolve().parents[1]/'isa_risc64_test.expected.txt'
    base,data=section(sys.argv[1],'.text')
    total=0; errors=[]
    for line in expected.read_text(encoding='utf-8-sig').splitlines():
        m=re.match(r'^([0-9a-fA-F]{8})\s+([0-9a-fA-F]{8})\s',line)
        if not m:continue
        a,w=(int(x,16) for x in m.groups()); total+=1
        actual=struct.unpack_from('<I',data,a-base)[0] if 0<=a-base<=len(data)-4 else None
        if actual!=w:errors.append((a,w,actual,line))
    if total==0:
        raise ValueError('Aucun mot attendu trouvé dans '+str(expected))
    for a,w,actual,line in errors[:30]:
        print(f'{a:08x}: attendu {w:08x}, obtenu '+('hors section' if actual is None else f'{actual:08x}')+' | '+line)
    print(f'{total-len(errors)}/{total} mots conformes ; {len(errors)} différences')
    return bool(errors)

if __name__=='__main__':sys.exit(main())
