/* Example RAM image, not a physical board specification. */
OUTPUT_FORMAT("elf64-gaspardarc")
OUTPUT_ARCH(gaspardarc)
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x10000, LENGTH = 1M }
SECTIONS {
 .text : { KEEP(*(.text._start)) *(.text .text.*) } > RAM
 .rodata : { *(.rodata .rodata.*) } > RAM
 .data : { *(.data .data.*) } > RAM
 .bss (NOLOAD) : { __bss_start = .; *(.bss .bss.*) *(COMMON) __bss_end = .; } > RAM
 . = ALIGN(16); __heap_start = .;
 __stack_top = ORIGIN(RAM) + LENGTH(RAM);
 ASSERT(__heap_start + 4096 < __stack_top, "not enough RAM for stack")
}
