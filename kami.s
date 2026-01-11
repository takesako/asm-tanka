# macOS（x86_64 / Mach-O）
.section __TEXT,__text
.globl _main
_main:
# 5
    push  $2
    push  $4
    pop   %rdx
# 7
    pop   %rdi
    push  $0x0a9ea5e7 # UTF-8
    push  %rsp
# 5
    pop   %rsi
    movl  %edi, %eax
    bswap %eax # 02 00 00 00
# 7
    orl   $4, %eax
    syscall
    movl  %edi, %eax
# 7
    bswap %eax # 02 00 00 00
    orl   $1, %eax
    syscall
