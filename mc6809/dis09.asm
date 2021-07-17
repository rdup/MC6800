* Program Dis09 a 6809 machine code
*     disassembler for OS9.
*
* by J. Dubner June/1981
* (Byte, Feb. (1982) 340)
*
* adapted for OS9 in 1986 by:
*
*********************************
*   P. A. Vazquez  <vasquez@iqm.unicamp.br>
*
*  Instituto de Quimica - UNICAMP
*  Caixa Postal 6154
*  Campinas - CEP 13081
*  Sao Paulo - Brasil
*
* Actual version is 1.04 (1988)
*
      nam  Dis09
      ttl  OS9 machine code disassembler
      opt  l
*
      ifp1
      use  /d0/defs/os9defs
      endc
*
      mod fim,nome,tipo,rev,inicio,endata
nome  fcs "D9"
tipo  set prgrm+objct
rev   set reent+1
*
* user stack organization
* temporary storage
*
buf1sz   equ $30
         org 0
curadr   rmb 2  current disassembly adress
wrkadr   rmb 2 working adress
length   rmb 1 instruction length
page     rmb 1 opcode page
opcd     rmb 1 opcode
postb    rmb 1 opcode second byte
byte1    rmb 1 msb of operand
byte2    rmb 1 lsb of operand
indflg   rmb 1 indirect adressing flag
indbyt   rmb 1 indexed adressing flag
nxtbuf   rmb 2 next available byte of output buffer
lngtype  rmb 1
atrrev   rmb 1
flag     rmb 1
flagr    rmb 1
flageof  rmb 1
path     rmb 1
counter  rmb 2
header   rmb 2
size     rmb 2
entry    rmb 2
vrtad    rmb 2
vrwad    rmb 2
param    rmb 2
dp       equ .
*
*output buffer
*
buffer   rmb 4 adress
         rmb 1
         rmb 2 page hex bytes
         rmb 2 opcode hex bytes
         rmb 2 post byte hex bytes
hexb     rmb 4 operand hex bytes
         rmb 1
mnem     rmb 5 opcode mnemonic
         rmb 1
oprand   rmb 9 operand
         rmb 1
condit   rmb 8 condition code
         rmb 1
ascii    rmb 10 ascii code plus cr
endbuf   equ .
buf1     rmb buf1sz
buf2     rmb buf1sz
wrkbuf   rmb $100
         rmb $100
         rmb $100
endata   equ .

********
* entry point for execution
*
*
*inicio pshs  x
*       ldb   #dp-curadr
*       leax  curadr,u
*ini    clr   ,x+
*       decb
*       bne   ini
*       puls  x
inicio  stx   param
       clr flag
       clr flagr
       clr vrtad
       clr vrwad
       clr vrtad+1
       clr vrwad+1
       clr flageof

       lda   ,x    get parameter
       cmpa  #$0d  is there one ?
       beq   inic1 no send prompt
ini1   lbsr  getblank    get blanks of
       cmpa  #'-  options ?
       bne   ini4 no
       lda   ,x+  yes
       anda  #$5f
       cmpa  #'L is a 'l'
       beq   ini2
       clra   no
ini2   sta   flag  set flag
ini3   lbsr  getblank
ini4   leax  -1,x
       stx  param  save parameter pointer
       bra  inpd   go to program
*******************
inic1  leax msg1,pcr  send dis09 prompt
       lbsr  msg
       leax msg2,pcr  request for a file path
       lbsr  msg
       leax msg3,pcr  *
       lbsr  msg
       lbsr  answer
       stx   param
       bra  ini1
***************************
*
* LOAD & link to module
*
inpd pshs u        save variable area
     clra
     os9  f$link   if
     bhs  inpd2    module in RAM

inpd1 os9  f$load  else load it
      bhs  inpd2    if error
********
* Not a module, open file
*
     lda  #READ.
     os9   i$open
     lbcs  exit1
     sta  path
     pshs u,x
     ldb  #SS.Size
     os9  i$getstt
     stx  header
     stu  size
     puls u,x
     inc  flagr
     lda  path
     ldy  #$100
     leax wrkbuf,u
     pshs x
     os9  i$read
     bhs  rfile
     cmpb e$eof
     lbne exit1
     inc  flageof
rfile sty  counter
     puls x
     bra loop

inpd2 exg  u,x     get header to x
     puls u        restore variable area
     stx  header   save header
     leax 2,x      get module size pointer
     sta  lngtype  save module specs.
     stb  atrrev
     sty  entry
     sty  curadr
     ldd  ,x        * Get module size
     addd header    * add header adress
     subd #$0003    * subtract CRC bytes
     std  size      * save # of bytes to disassembly
     ldx  curadr
     ldd  entry     * get entry point address
     subd header    * get offset
     std  vrtad     * virtual addres
*
**************************
*
* Main LOOP
*
loop bsr  disas   do one line
loop1 cmpd size    end of module ?
     bhs  exit     yes, goodbye
     tst  flag     line disassembly ?
     beq  loop     no
loop2 clra          yes
     leax buf2,u
     ldy  #1        get command
     os9  i$read
     bcs  exit1
     leax buf2,u
     lda  ,x
     anda #$5f
     cmpa #'Q      quit program ?
     beq  exit     yes, goodbye
     ldx  curadr   get next instruction pointer
     bra  loop
*************************
*
* EXIT procedure
*
exit tst flagr
     bne exit2
     ldx  param   get module name
     clra
     clrb
     os9 f$link   link to it
     blo exit1
     os9 f$unlink unlink
     blo exit1
     os9 f$unlink again
exit2 clrb    no errors
exit1 os9 f$exit  bye
************************
*
* Get Answer Subroutine
*
answer leax buf1,u
     ldy  #buf1sz
     clra
     os9  i$readln
     bcs  exit1
     leax buf1,u
     rts
********************
*
* Clear buffer subroutine
*
clbuf lda  #$20
      ldb  #endbuf-buffer
      leax buffer,u
clbf1 sta  ,x+
      decb
      bne clbf1
      rts
*********************
*
* PRINT subroutine
*
msg ldy #buf1sz
    lda #1
    os9 i$writln
    bcs exit1
    rts
*********************
*
* Get blanks off
*
getblank lda   ,x+
       cmpa  #$20
       beq   getblank
       rts
**********************
*
* Disassembler subroutine
*
disas stx  curadr
      ldx  vrtad
      stx  vrwad
      leax length,u
      ldb  #lngtype-length
init1 clr  ,x+
      decb
      bne  init1
      bsr clbuf
      ldx curadr
      stx wrkadr
      inc length
**********************
*
* main procedure
*
  ldd counter
  cmpd #$0a
  bhs  main
  tst  flageof
  bne  main
  ldd #$100
  subd counter
  pshs d
  leay wrkbuf,u
cp ldb ,x+
  stb ,y+
  dec counter
  bne cp
  tfr y,x
  puls y
  lda path
  os9 i$read
  bhs cp2
  cmpb e$eof
  lbne exit1
  inc flageof
cp2 ldd #$100
   std counter
   leax wrkbuf,u
   stx  curadr
   stx  wrkadr
main  ldb  ,x+

  cmpb #$10
  beq  main1
  cmpb #$11
  bne  main2
*
main1 stb page
  inc length
  ldb ,x+
  inc vrwad+1
  bne main2
  inc vrwad

main2 stx  wrkadr
  inc  vrwad+1
  bne  main21
  inc  vrwad
main21  stb  opcd
  cmpb #$80
  bhs    main3
  cmpb   #$40
  blo    main41
  andb   #$0f
  bra    main4

main3    andb   #$0f
  orb    #$40

main41   cmpb   #$3f
   bne    main4
   lda    page
   cmpa   #$10

*******************************
*
* Trap system calls
*
   lbeq   syscall
*
*
main4    lda    #$4
     mul
     leax   mntab,pc
     leax   d,x
     leay   mnem,u
     ldb    #$4
main5 lda   ,x+
     sta    ,y+
     decb
     bne    main5
     leax   oprand,u
     stx    nxtbuf
     lda    mnem
     cmpa   #'*
     lbeq   ilegop

**************************
*
* select applicable processing routines
*
     lda    opcd
     cmpa   #$c0
     lbhs   opc0
     cmpa   #$80
     lbhs   op80
     cmpa   #$40
     bhs    op00
     cmpa   #$30
     lbhs   op30
     cmpa   #$20
     lbhs   op20
     cmpa   #$10
     bhs    op10
     bra    op00
**************************
* opcodes 00-0f and 40-7f
*
* trap illegal opcodes

op00     tst    page
     bne    op01
     cmpa   #$4e
     beq    op01
     cmpa   #$5e
     bne    op02
op01     lbra   ilegop
**************************
* register addresing

op02     anda   #$f0
     ldb    #'a
     cmpa   #$40
     beq    op03
     cmpa   #$50
     bne    op04
     ldb    #'b
op03     stb    mnem+3
     bra    op07
**************************
* indexed addressing

op04     cmpa   #$60
     bne    op05
     lbsr   index
     bra    op07
**************************
* extended addressing

op05     cmpa   #$70
     bne    op06
     lbsr   extend
     bra    op07

**************************
* direct addressing

op06     lbsr   direct
op07     lbra   finish
**************************
* opcodes 10-1f
* trap illegal opcodes

op10     ldb    page
     beq    op12
op11     lbra   ilegop
**************************
* process long branches

op12     cmpa   #$16
     beq    op13
     cmpa   #$17
     bne    op14
op13     lbra   op23
**************************
* process cc instructions

op14     cmpa   #$1a
     beq    op15
     cmpa   #$1c
     bne    op17
     lda    #'c
     sta    mnem+4
op15     lda    #'#
     lbsr   putch
     lbsr   direct
     leax   cctab,pcr
     leay   condit,u
     ldb    #8
cc1      lda    ,x+
     sta    ,y+
     decb
     bne    cc1
     lda    [wrkadr,u]
     sta    lngtype
     leax   condit,u
     ldd    #$2d08
cc2      lsl    lngtype
     bcs    cc3
     sta    ,x
cc3      leax   1,x
     decb
     bne    cc2
     leax   1,x
     stx    nxtbuf
op16     lbra   finish
**************************
* process register tranfers instructions

op17     cmpa   #$1e
     blo    op16
     inc    length
     ldb    [wrkadr,u]
     stb    byte1
     andb   #$88
     beq    op18
     cmpb   #$88
     bne    op11

op18     ldb    byte1
     lsrb
     lsrb
     lsrb
     lsrb
     bsr    reg
     cmpa   #'*
     beq    op11
     lda    #',
     lbsr   putch
     ldb    byte1
     bsr    reg
     cmpa   #'*
     beq    op11
     bra    op16

reg      andb   #$0f
     leax   regtab,pc
     lda    b,x
     lbsr   putch
     cmpb   #$05
     bne    reg1
     lda    #'c
     bra    reg3
reg1     cmpb   #$0a
     bne    reg2
     lda    #'c
     bra    reg3
reg2     cmpb   #$0b
     bne    reg4
     lda    #'p
reg3     lbsr   putch
reg4     rts
**************************
* opcodes 20-2f
* trap illegal opcodes

op20     ldb    page
     cmpb   #$11
     beq    op21
     cmpa   #$20
     bne    op22
     cmpb   #$00
     beq    op22
op21     lbra   ilegop
**************************
* process long branches

op22 cmpb   #$10
     bne    op26
op23 ldb    #3
     leax   mnem+2,u
op24 lda    ,x+
     sta    ,x
     leax   -2,x

    decb
     bne    op24
     lda    #'l
     sta    1,x
     lbsr   rel16
op25 lbra   finish
**************************
* process short branches

op26 lbsr   rel8
     bra    op25
**************************
* opcodes 30-3f
* trap illegal opcodes

op30 ldb    page
     cmpa   #$3f
     beq    op301
     cmpb   #0
     beq    op32
     lbra   ilegop
**************************
* process 'lea' instructions

op32 cmpa    #$33
     bhi     op34
     lbsr    index
op33 lbra    finish
**************************
* process stack instructions

op34 cmpa    #$3c
     beq     op302
     cmpa    #$37
     bhi     op33
     inc     length
     lda     [wrkadr,u]
     sta     byte1
     sta     byte2
     clrb
op35 lsl     byte2
     bcc     op300
     leax    stktab,pc
     lda     b,x
     cmpa    #'s
     bne     op36
     cmpa    mnem+3
     bne     op36
     lda     #'u
op36 lbsr    putch
     cmpa    #'p
     beq     op37
     cmpa    #'c
     bne     op38
op37 lda     #'c
     lbsr    putch
     bra     op39
op38 cmpa    #'d
     bne     op39
     lda     #'p
     lbsr    putch
     bra     op39
op39 lda     #',
     lbsr    putch
op300 incb
     cmpb    #8
     bne     op35
     ldx     nxtbuf
     leax    -1,x
     stx     nxtbuf
     bra     op33
**************************
* process 'swi'

op301 cmpb     #0
     beq     op33
     addb    #$21
     stb     mnem+3
     bra     op33
**************************
* process 'cwai'

op302 lda     #'#
     lbsr    putch
     lbsr    direct
     lbra    finish
**************************
* opcodes 80-bf
* process 'bsr' as special case

op80 ldb     page
     cmpa    #$8d
     bne     op81
     cmpb    #$00
     lbne    ilegop
     lda     #'b
     sta     mnem
     lbsr    rel8
     lbra    finish
**************************
* get mnemonic as required by page

op81 anda    #$8f
     cmpa    #$83
     bne     op83
     cmpb    #$00
     beq     op800
     lda     #'c
     sta     mnem
     lda     #'m
     sta     mnem+1
     lda     #'p
     sta     mnem+2
     lda     #'d
     cmpb    #$10
     beq     op82
     lda     #'u
op82 sta     mnem+3
     bra     op800
op83 cmpa    #$8c
     bne     op85
     cmpb    #$00
     beq     op800
     lda     #'y
     cmpb    #$10
     beq     op84
     lda     #'s
op84 sta     mnem+3
     bra     op800

op85 cmpa    #$8e
     blo     op86
     cmpb    #$11
     lbeq    ilegop
     cmpb    #$00
     beq     op800
     lda     #'y
     sta     mnem+2
     bra     op800
op86 cmpb    #$00
     lbne    ilegop

* jointly process 80-bf and c0-ff
* trap illegal opcodes

op800 lda     opcd
     anda    #$bf
     cmpa    #$87
     beq     op801
     cmpa    #$8d
     beq     op801
     cmpa    #$8f
     bne     op802
op801 lbra    ilegop

* process extended addressing

op802 lda     opcd
     anda    #$30
     cmpa    #$30
     bne     op803
     lbsr    extend
     lbra    finish

* process indexed addressing

op803 cmpa    #$20
     bne     op804
     lbsr    index
     lbra    finish

* process direct addressing

op804 cmpa    #$10
     bne     op805
     lbsr    direct
     lbra    finish

* process immediate addressing

op805 lda      #'#
     lbsr     putch
     lda      opcd
     anda     #$8f
     cmpa     #$83
     beq      op806
     cmpa     #$8c
     bhs      op806
     lbsr     direct
     lbra     finish
op806 lbsr     extend
     lbra     finish

*  opcodes c0-cf
* change mnemonics and trap illegal opcodes

opc0 ldb      page
     anda     #$cf
     cmpa     #$cb
     bhi      opc3
     cmpa     #$c3
     bne      opc0a
     lda      #'a
     sta      mnem
     lda      #'d
     sta      mnem+1
     sta      mnem+2
     sta      mnem+3
     bra      opc2
opc0a leax     mnem+2,u
     lda      ,x
     cmpa     #'a
     beq      opc1
     leax 1,x
opc1 inc      ,x
opc2 cmpb     #$00
     beq      opc8
     bra      ilegop
opc3 cmpa     #$cd
     bhi      opc6
     bne      opc5
     lda      #'s
     sta      mnem
     lda      #'t
opc4 sta      mnem+1
     lda      #'d
     sta      mnem+2
     lda      #$20
     sta      mnem+3
     bra      opc2
opc5 lda      #'l
     sta      mnem
     lda      #'d
     bra      opc4
opc6 cmpb     #$11
     beq      ilegop
     lda      #'u
     cmpb      #$00
     beq       opc7
     lda       #'s
opc7 sta       mnem+2
opc8 lbra      op800

* illegal opcodes routine

ilegop leax    mnileg,pc
     leay      mnem,u
     ldb       #4
ilop1 lda      ,x+
     sta       ,y+
     decb
     bne       ilop1
     leax      oprand,u
     stx       nxtbuf
     lda       #'$
     lbsr      putch
     lda       opcd
     lbsr      put2h
     lbsr      alpha
     lda       #$0d
     lbsr      putch
     lda       #1
     pshs      a
     lbra      eoj4

* process indexed addressing mode

index inc  length
     ldx   wrkadr
     ldb   ,x+
     stx   wrkadr
     inc   vrwad+1
     bne   index1
     inc   vrwad
index1 stb indbyt
     stb   byte1

* check for indirect addressing

     andb       #$90
     cmpb       #$90
     bne        ind1
     com        indflg
     lda        #'[
     lbsr       putch

* auto increment/decrement addressing

ind1 ldb        indbyt
     andb       #$8f
     cmpb       #$80
     blo        ind5
     cmpb       #$83
     bhi        ind5
     lda        indbyt
     anda       #$11
     cmpa       #$10
     beq        ilegop
     lda        #',
     lbsr       putch
     cmpb       #$81
     bhi        ind3
     lbsr       getreg
     lda        #'+
     lbsr       putch
     cmpb       #$81
     bne        ind2
     lbsr       putch
ind2 lbra       indend
ind3 lda        #'-
     lbsr       putch
     cmpb       #$83
     bne        ind4
     lbsr       putch
ind4 lbsr       getreg
     lbra       indend

* accumulator offset

ind5 lda         #'a
     cmpb        #$86
     beq         ind6
     lda         #'b
     cmpb        #$85
     beq         ind6
     lda         #'d
     cmpb        #$8b
     bne         ind7
ind6 lbsr        putch
     lda         #',
     lbsr        putch
     lbsr        getreg
     lbra        indend

* constant offset from pc

ind7 cmpb        #$8d
     beq         ind8
     cmpb        #$8c
     bne         ind10
ind8 lda         indbyt
     sta         postb
     cmpb        #$8d
     beq         ind9
     lbsr        rel8
ind8a lda         #',
     lbsr        putch
     lda         #'p
     lbsr        putch
     lda         #'c
     lbsr        putch
     lbra        indend
ind9 lbsr        rel16
     bra         ind8a

* constant offset (zero)

ind10 cmpb #$84
     bne  ind12
     clra
ind11 pshs  a
     lda  #'$
     lbsr putch
     puls a
ind11a lbsr put2h
     lda  #',
     lbsr putch
     bsr  getreg
     lbra  indend

* 5-bit offset

ind12 bitb #$80
     bne  ind13
     tst  indflg
     bne  ind18
     ldb  indbyt
     andb #$1f
     bitb #$10
     beq  ind12a
     lda  #'-
     lbsr putch
     orb  #$e0
     negb
ind12a tfr   b,a
     bra   ind11

* 8-bit offset

ind13 lda indbyt
     sta  postb
     cmpb #$88
     bne  ind15
     inc  length
     ldb  [wrkadr,u]
     stb  byte1
     bpl  ind14
     lda  #'-
     lbsr putch
     negb
ind14 tfr  b,a
     bra ind11

* 16-bit offset

ind15 cmpb #$89
     bne     ind16
     inc     length
     inc     length
     ldd     [wrkadr,u]
     std     byte1
     pshs a
     lda  #'$
     lbsr putch
     puls a
     lbsr    put2h
     tfr     b,a
     bra     ind11a

* extended indirect

ind16 lda     indbyt
     cmpa    #$9f
     bne     ind18
     sta     postb
     bsr     extend
     bra     indend

* trap illegal index modes

ind18 lbra        ilegop

* get  index register

getreg pshs    b
     ldb     indbyt
     lda     #'x
     andb    #$60
     beq     getr1
     lda     #'y
     cmpb    #$20
     beq     getr1
     lda     #'u
     cmpb    #$40
     beq     getr1
     lda     #'s
getr1 bsr    putch
     puls    b
     rts

* finish up indexed processing

indend tst     indflg
     beq     inden1
     lda     #']
     bsr     putch
inden1 rts

* process direct adressing mode

direct inc      length
     lda      #'$
     bsr      putch
     lda      [wrkadr,u]
     sta      byte1
     bsr      put2h
     rts

* process extended addressing mode

extend bsr       direct
     inc       length
     inc       wrkadr+1
     bne       ext1
     inc       wrkadr
ext1 inc       vrwad+1
     bne       ext2
     inc       vrwad+1
ext2 lda       [wrkadr,u]
     sta       byte2
     bsr       put2h
     rts

* process relative addressing modes

rel8 inc       length
     lda       #'(
     bsr       putch
     lda       [wrkadr,u]
     tfr       a,b
     sta       byte1
     sex
     addd      #1
rel8a addd     vrwad
     bsr       put2h
     tfr       b,a
     bsr       put2h
     lda       #')
     bsr       putch
     rts
rel16 inc       length
     inc       length
     lda       #'(
     bsr       putch
     ldd       [wrkadr,u]
     sta       byte1
     stb       byte2
     addd      #2
     bra       rel8a

* output routines
* put 2 hex characters from A reg into buffer

put2h pshs      a
     bsr       put2hl
     puls      a
     bsr       put2hr
     rts
put2hl lsra
     lsra
     lsra
     lsra
put2hr anda   #$f
     adda   #'0
     cmpa   #'9
     bls    putch
     adda   #7

* put ascii character into buffer and bump buffer pointer

putch ldx   nxtbuf
      sta   ,x+
      stx   nxtbuf
      rts

* end of job routine
* terminate buffer with cr

finish bsr  alpha
      lda   #$0d
      bsr   putch

* put current address and opcode bytes into buffer

      leax   buffer,u
      stx    nxtbuf
      lda    vrtad
      bsr    put2h
      lda    vrtad+1
      bsr    put2h
      lda    #$20
      bsr    putch
      lda    length
      pshs   a
      lda    page
      beq    eoj1
      bsr    put2h
      dec    length
eoj1  lda    opcd
      bsr    put2h
      dec    length
      lda    postb
      beq    eoj2
      bsr    put2h
      dec    length

* output operand bytes

eoj2  tst    length
      beq    eoj4
      lda    byte1
      bsr    put2h
      dec    length
      beq    eoj4
      lda    byte2
      bsr    put2h

* output entire buffer to console

eoj4  leax   buffer,u
      lda    #1
      ldy    #endbuf-buffer
      os9    i$writln
      lbcs   exit1

* set up for next line of disassembly

      puls   b
      stb    length
      negb
      sex
      addd   counter
      std    counter
      ldb    length
      sex
      pshs   d
      addd   vrtad
      std    vrtad
      puls   d
      addd   curadr
      std    curadr
      ldx    curadr
      rts
*
* Subroutine alpha
*
alpha leax  ascii,u
     ldb   length
     lda   page
     beq   alph1
     decb
     bsr   char

alph1 lda   opcd
     bsr   char
     decb
     beq   alph3

     lda   postb
     beq   alph2
     bsr   char
     decb
     beq   alph3

alph2 lda   byte1
     bsr   char
     decb
     beq   alph3
     lda   byte2
     bsr   char
alph3 stx   nxtbuf
     rts
*
* Subroutine char
*
char anda      #$7f
     cmpa      #$1e
     bhi       char1
     lda       #'.
char1 sta       ,x+
     rts
     ttl Constant Tables
     pag
************************************
*
* transfer instruction register table
*
regtab    fcc    /dxyusp**abcd****/
*
************************************
*
* stack register table
*
stktab    fcc    /psyxdbac/
*
* condition code table
*
cctab     fcc  /efhinzvc/
*
*********************************************
*
*  Messages
*
msg1    fcb  $0c
        fcc /      OS9 Machine Code Disassembler/
        fcb  $0d
*
msg2    fcb  $0a,$0a
        fcc /Input pathname to file to disassemble/
        fcb  $0d
*
msg3    fcb  $0a,$0a,$0a
        fcc  /Pathname ?  /
        fcb  $0a,$0a,$0d
*************************

     ttl Mnemonic table
     pag
***********************************
*
* mnemonic table
*
mnileg    fcc    /fcb /
mntab     fcc    /neg /
          fcc    /*** /
          fcc    /*** /
          fcc    /com /
          fcc    /lsr /
          fcc    /*** /
          fcc    /ror /
          fcc    /asr /
          fcc    /asl /
          fcc    /rol /
          fcc    /dec /
          fcc    /*** /
          fcc    /inc /
          fcc    /tst /
          fcc    /jmp /
          fcc    /clr /
          fcc    /*** /
          fcc    /*** /
          fcc    /nop /
          fcc    /sync/
          fcc    /*** /
          fcc    /*** /
          fcc    /bra /
          fcc    /bsr /
          fcc    /*** /
          fcc    /daa /
          fcc    /orcc/
          fcc    /*** /
          fcc    /andc/
          fcc    /sex /
          fcc    /exg /
          fcc    /tfr /
          fcc    /bra /
          fcc    /brn /
          fcc    /bhi /
          fcc    /bls /
          fcc    /bhs /
          fcc    /blo /
          fcc    /bne /
          fcc    /beq /
          fcc    /bvc /
          fcc    /bvs /
          fcc    /bpl /
          fcc    /bmi /
          fcc    /bge /
          fcc    /blt /
          fcc    /bgt /
          fcc    /ble /
          fcc    /leax/
          fcc    /leay/
          fcc    /leas/
          fcc    /leau/
          fcc    /pshs/
          fcc    /puls/
          fcc    /pshu/
          fcc    /pulu/
          fcc    /*** /
          fcc    /rts /
          fcc    /abx /
          fcc    /rti /
          fcc    /cwai/
          fcc    /mul /
          fcc    /*** /
          fcc    /swi /
          fcc    /suba/
          fcc    /cmpa/
          fcc    /sbca/
          fcc    /subd/
          fcc    /anda/
          fcc    /bita/
          fcc    /lda /
          fcc    /sta /
          fcc    /eora/
          fcc    /adca/
          fcc    /ora /
          fcc    /adda/
          fcc    /cmpx/
          fcc    /jsr /
          fcc    /ldx /
          fcc    /stx /
     ttl System Calls Subroutine
     pag
*
***************************
*
*  System Calls processing
*

syscall  inc    length
         ldd    #$4f53   = 'OS'
         std    mnem
         lda    #'9
         sta    mnem+2
         ldb    ,x+
         stb    postb
         stx    wrkadr,u
         inc    vrwad+1
         bne    sys1
         inc    vrwad
sys1     leay   oprand,u
         lda    #'f
         cmpb   #$1d
         bhi    sys5
         sta    ,y+
         leax   tcall,pc
*
sys3     lda    #6
         mul
         leax   d,x
         ldb    #6
*
sys4     lda    #'$
         sta    ,y+
sys41    lda    ,x+
         sta    ,y+
         decb
         bne    sys41
         leay   ,y+
         sty    nxtbuf,u
         lbra   finish
*
sys5    cmpb  #$51
        bhi   sys10
        sta   ,y+
        subb  #$28
        leax  tcall1,pc
        bra   sys3
*
sys10   cmpb   #$90
        lbhi    main4
        cmpb   #$7f
        bhi    sys101
        lbra   main4
sys101  leax   tcall2,pc
        subb   #$80
        lda    #'i
        sta    ,y+
        bra    sys3
*
*
*
     ttl  System Calls Table #1
     pag
tcall   fcc  /link  /
        fcc  /load  /
        fcc  /unlink/
        fcc  /fork  /
        fcc  /wait  /
        fcc  /chain /
        fcc  /exit  /
        fcc  /mem   /
        fcc  /send  /
        fcc  /icpt  /
        fcc  /sleep /
        fcc  /sspd  /
        fcc  /id    /
        fcc  /sprior/
        fcc  /sswi  /
        fcc  /perr  /
        fcc  /prsnam/
        fcc  /cmpnam/
        fcc  /schbit/
        fcc  /allbit/
        fcc  /delbit/
        fcc  /time  /
        fcc  /stime /
        fcc  /crc   /
        fcc  /gprdsc/
        fcc  /gblkmp/
        fcc  /gmoddr/
        fcc  /cpymem/
        fcc  /suser /
        fcc  /unload/
     ttl System Calls Table #2
     pag
******************************************
*
* Table #2
*

tcall1  fcc  /srqmem/
        fcc  /srtmem/
        fcc  /irq   /
        fcc  /ioqu  /
        fcc  /aproc /
        fcc  /nproc /
        fcc  /vmodul/
        fcc  /find64/
        fcc  /all64 /
        fcc  /ret64 /
        fcc  /ssvc  /
        fcc  /iodel /
        fcc  /slink /
        fcc  /boot  /
        fcc  /btmem /
        fcc  /gprocp/
        fcc  /move  /
        fcc  /allram/
        fcc  /allimg/
        fcc  /delimg/
        fcc  /setimg/
        fcc  /freelb/
        fcc  /freehb/
        fcc  /alltsk/
        fcc  /deltsk/
        fcc  /settsk/
        fcc  /restsk/
        fcc  /reltsk/
        fcc  /datlog/
        fcc  /dattmp/
        fcc  /ldaxy /
        fcc  /ldaxyp/
        fcc  /ldddxy/
        fcc  /ldabx /
        fcc  /stabx /
        fcc  /allprc/
        fcc  /delprc/
        fcc  /elink /
        fcc  /fmodul/
        fcc  /mapblk/
        fcc  /clrblk/
        fcc  /delram/

     ttl  System Calls Table #3
     pag
*
****************************************
*
* Table #3
*

tcall2  fcc  /attach/
        fcc  /detach/
        fcc  /dup   /
        fcc  /create/
        fcc  /open  /
        fcc  /makdir/
        fcc  /chgdir/
        fcc  /delete/
        fcc  /seek  /
        fcc  /read  /
        fcc  /write /
        fcc  /readln/
        fcc  /writln/
        fcc  /getstt/
        fcc  /setstt/
        fcc  /close /
        fcc  /deletx/
****************
*
        emod
fim     equ    *
        end
