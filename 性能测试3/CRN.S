#   CryptoNight test program
#   Run simplified CryptoNight memory-hard loop
#   Reference C code:
#   void crn(int pad[],unsigned int a,unsigned int b,unsigned int n) {
#       unsigned int k;
#       for (k=0; k!=1024; k++)
#           pad[k] = k;
#       for (k=0; k!=n; k++) {
#           unsigned int t, addr1, addr2;
#           addr1 = a & 0x3FF;
#           t = (a >> 1) ^ (pad[addr1] << 1); // Replace the AES step
#           pad[addr1] = t ^ b;
#           addr2 = t & 0x3FF;
#           b = t;
#           t = pad[addr2];
#           a += b * t;
#           pad[addr2] = a;
#           a ^= t;
#       } 
#   }
    .org 0x0
    .text
    .global _start
_start:
    # a0 -> pad
    # a1 -> a
    # a2 -> b
    # a3 -> n
    li.w        $a0, 0x80400000                             #00
    li.w        $a1, 0x4
    li.w        $a2, 0x2
    li.w        $a3, 0x10
    or          $t4,$zero,$a0         #t4 = pad              10
    or          $t3,$zero,$zero       #t3 = k 初始化
    li.w        $t0,0x400           #t0 = 0x400
fill_next:                        
    st.w        $t3,$t4,0            #pad[k] = k;
    addi.w      $t3,$t3,1            #t3 -> k k++             20
    addi.w      $t4,$t4,4            #t4为pad数组当前地址
    bne         $t3,$t0,fill_next    #k != 0x400

    or          $t1,$zero,$zero       #t1 -> k k = 0
    li.w        $t2,0x3ff            #t2 = 3ff                30
crn_hext:
    and         $t0,$a1,$t2           #addr1 = a & 0x3FF; 
    slli.w      $t0,$t0,2            #addr1*4用来取数据
    add.w       $t0,$a0,$t0           #pad+addr1*4
    ld.w        $t3,$t0,0            #t3 = pad[addr1]         40
    srli.w      $t4,$a1,1            #t4 = a >> 1
    slli.w      $t3,$t3,1            #t3 = pad[addr1] << 1
    xor         $t3,$t3,$t4           #t3 -> t   t3 = (a >> 1) ^ (pad[addr1] << 1)
    and         $t4,$t3,$t2           #t4 -> addr2  addr2 = t & 0x3FF        50
    xor         $a2,$t3,$a2           #a2 = t ^ b
    slli.w      $t4,$t4,2            #t4 = addr2*4
    st.w        $a2,$t0,0            #pad[addr1] = t ^ b
    add.w       $t4,$a0,$t4           #t4 = pad[addr2]        60
    ld.w        $t0,$t4,0            #t0 -> t  t = pad[addr2] 
    or          $a2,$zero,$t3         #a2 -> b  b = t
    mul.w       $t3,$t3,$t0           #t3 = b * t
    addi.w      $t1,$t1,1            #k++                     70
    add.w       $a1,$t3,$a1           #a1 -> a  a+= b * t
    st.w        $a1,$t4,0            #pad[addr2] = a
    xor         $a1,$t0,$a1           #a ^= t
    bne         $a3,$t1,crn_hext     #k != n                  80
end:
    bne         $a0,$zero,end