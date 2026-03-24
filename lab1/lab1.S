    .org 0x0
    .text
    .global _start
_start:
    addi.w      $t0,$zero,0x1   # t0 = 1          // 00
    addi.w      $t1,$zero,0x1   # t1 = 1          // 04
    lu12i.w     $a0,-0x7fc00    # a0 = 0x80400000 // 08
    addi.w      $a1,$a0,0x100   # a1 = 0x80400100 // 0c
loop:
    add.w       $t2,$t0,$t1     # t2 = t0+t1      // 10
    addi.w      $t0,$t1,0x0     # t0 = t1         // 14
    addi.w      $t1,$t2,0x0     # t1 = t2         // 18
    st.w        $t2,$a0,0x0                       // 1c                       
    ld.w        $t3,$a0,0x0                       // 20
    bne         $t2,$t3,end                       // 24
    addi.w      $a0,$a0,0x4     # a0 += 4         // 28
    bne         $a0,$a1,loop                      // 2c
end:
    bne         $a0,$zero,end                     // 30
