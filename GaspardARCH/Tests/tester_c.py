#!/usr/bin/env python3
"""Compile/link/run ABI tests in a LIMITED INTEGER MODEL, not on real hardware.
After installing the toolchain: python GaspardARCH/Tests/tester_c.py
GASPARDARC_PREFIX can override build-gaspardarc-install.
"""
from pathlib import Path
import subprocess,os,struct,sys
from modele_entier import execute,symbols
ROOT=Path(__file__).resolve().parents[2]
PREFIX=Path(os.environ.get('GASPARDARC_PREFIX',str(ROOT/'build-gaspardarc-install')))
OUT=ROOT/'build-tests-gaspardarc';OUT.mkdir(exist_ok=True)
def tool(name):
    p=PREFIX/'bin'/('gaspardarc-unknown-elf-'+name)
    return str(p)+('.exe' if os.name=='nt' else '')
def run(args):subprocess.run([str(a) for a in args],check=True)
run([tool('as'),ROOT/'GaspardARCH/runtime/crt0.S','-o',OUT/'crt0.o'])
for opt in ['-O0','-O2','-Os']:
    out=OUT/('abi'+opt)
    run([tool('gcc'),opt,'-ffreestanding','-fno-builtin','-c',ROOT/'GaspardARCH/Tests/abi-integer.c','-o',str(out)+'.o'])
    run([tool('ld'),'-T',ROOT/'GaspardARCH/runtime/board.ld',OUT/'crt0.o',str(out)+'.o','-o',str(out)+'.elf'])
    mem,steps=execute(str(out)+'.elf');syms=symbols(str(out)+'.elf')
    def value(name):return sum(mem.get(syms[name]+i,0)<<(8*i) for i in range(8))
    assert value('signature')==0x600d and value('__exit_code')==0, (opt,value('signature'))
    print(opt+': OK, signature=0x600d, '+str(steps)+' instructions dans le modèle entier limité')
if '--libgcc' in sys.argv:
    lib=Path(subprocess.check_output([tool('gcc'),'-print-libgcc-file-name']).decode().strip())
    if not lib.exists():raise SystemExit('Construire et installer libgcc avant --libgcc')
    for opt in ['-O0','-O2']:
        out=OUT/('libgcc'+opt)
        run([tool('gcc'),opt,'-ffreestanding','-c',ROOT/'GaspardARCH/Tests/libgcc-integer.c','-o',str(out)+'.o'])
        run([tool('ld'),'-T',ROOT/'GaspardARCH/runtime/board.ld',OUT/'crt0.o',str(out)+'.o',lib,'-o',str(out)+'.elf'])
        mem,steps=execute(str(out)+'.elf');syms=symbols(str(out)+'.elf')
        assert value('signature')==0x600d and value('__exit_code')==0
        print(opt+': auxiliaires libgcc OK dans le modèle entier limité')
