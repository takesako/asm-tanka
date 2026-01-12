# macOS（x86_64 / Mach-O）
.section __TEXT,__text
.globl _main
_main:
# 5
    push  $0x0a9ea5e7 # UTF-8
# 7
    push  $0x02000004 # write
    pop   %rax
    push  %rsp
# 5
    pop   %rsi
    push  $1
    push  $4
# 7
    pop   %rdx
    pop   %rdi
    syscall
    push  $0
    pop   %rdi
# 7
    movl  $0x02000001, %eax # exit
    syscall
