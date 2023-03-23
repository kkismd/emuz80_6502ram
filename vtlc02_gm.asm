;234567890123456789012345678901234567890123456789012345
!cpu 65c02
;-----------------------------------------------------;
;             VTL-2 for the 65C02 (VTLC02)            ;
;           Original Altair 680b version by           ;
;          Frank McCoy and Gary Shannon 1977          ;
;    2012: Adapted to the 6502 by Michael T. Barry    ;
;-----------------------------------------------------;
;        Copyright (c) 2012, Michael T. Barry
;       Revision B (c) 2015, Michael T. Barry
;       Revision C (c) 2015, Michael T. Barry
;      Revision C02 (c) 2022, Michael T. Barry
;               All rights reserved.
;
; VTLC02 is a ligntweight "self-contained" IDE, and
;   features a command line, program editor and
;   language interpreter, all in 970 bytes of dense
;   65C02 machine code.  The "only" thing missing is
;   a method to save your program, but this Kowalski
;   version assumes that you will be pasting code
;   from the simulator host.
;
; Redistribution and use in source and binary forms,
;   with or without modification, are permitted,
;   provided that the following conditions are met: 
;
; 1. Redistributions of source code must retain the
;    above copyright notice, this list of conditions
;    and the following disclaimer. 
; 2. Redistributions in binary form must reproduce the
;    above copyright notice, this list of conditions
;    and the following disclaimer in the documentation
;    and/or other materials provided with the
;    distribution. 
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS
; AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
; FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
; SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
; NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
; IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;-----------------------------------------------------;
; Except for the differences discussed below, VTLC02
;   was created to duplicate the OFFICIALLY DOCUMENTED
;   behavior of Frank's 680b version, detailed here:
;     http://www.altair680kit.com/manuals/Altair_
;     680-VTL-2%20Manual-05-Beta_1-Searchable.pdf
;   These versions ignore all syntax errors and plow
;   through VTL-2 programs with the assumption that
;   they are "correct", but in their own unique ways,
;   so any claims of compatibility are null and void
;   for VTL-2 code brave (or stupid) enough to stray
;   from the beaten path.
;
; Differences between the 680b and 65c02 versions:
; * {&} and {*} are initialized on entry.
; * Division by zero returns 65535 for the quotient and
;     the dividend for the remainder (the original 6800
;     version froze).
; * The 65c02 has NO 16-bit registers (other than PC)
;     and less overall register space than the 6800,
;     so the interpreter reserves some obscure VTLC02
;     variables {@ $ ( ) 0 1 2 3 4 5 6 7 8 9 < > : ?}
;     for its internal use (the 680b version used a
;     similar tactic, but differed in the details).
;     Parentheses nested deeper than nine levels may
;     result in unintended side-effects.
; * Users wishing to call a machine language subroutine
;     via the system variable {>} must pass 2 params
;     address and value seperated by comma {,}. 
;     (for example, >=768,123). <GM modification>
; * The x register is used to point to a simple VTLC02
;     variable (it can't point explicitly to an array
;     element like the 680b version because it's only
;     8-bits).  In the comments, var[x] refers to the
;     16-bit contents of the zero-page variable pointed
;     to by register x (residing at addresses x, x+1).
; * The y register is used as a pointer offset inside
;     a VTLC02 statement (easily handling the maximum
;     statement length of about 128 bytes).  In the
;     comments, @[y] refers to the 16-bit address
;     formed by adding register y to the value in {@}.
; * The behavior of this interpreter is similar to the
;     680b version, but it has been reorganized into a
;     more 65c02-friendly format (65c02s have no 'bsr'
;     instruction, so 'stuffing' subroutines within 128
;     bytes of the caller is only advantageous for
;     relative branches).
; * This version is based on the original port, which
;     was wound rather tightly, in a failed attempt to
;     fit it into 768 bytes like the 680b version; many
;     structured programming principles were sacrificed
;     in that effort.  The 65c02 simply requires more
;     instructions than the 6800 does to manipulate 16-
;     bit quantities, but the overall performance is
;     better due to the 65c02's lower average clocks/
;     instruction ratio, and optimizations not present
;     in the original verison.
; * VTLC02 is my free gift (?) to the world.  It may be
;     freely copied, shared, and/or modified by anyone
;     interested in doing so, with only the stipulation
;     that any liabilities arising from its use are
;     limited to the price of VTLC02 (nothing).
;-----------------------------------------------------;
; 2015: Revision B included some space optimizations
;         (suggested by dclxvi) and enhancements
;         (suggested by mkl0815 and Klaus2m5):
;
; * Bit-wise operators & | ^ (and, or, xor)
;   Example:  A=$|128) Get a char and set hi-bit
;
; * Absolute addressed 8-bit memory load and store
;   via the {< @} facility:
;   Example:  <=P) Point to the I/O port at P
;             @=@&254^128) Clear bit 0 & flip bit 7
;
; 2015: Revision C includes further enhancements
;   (suggested by Klaus2m5):
;
; * "THEN" and "ELSE" operators [ ]
;     A[B returns 0 if A is 0, otherwise returns B.
;     A]B returns B if A is 0, otherwise returns 0.
;
; * Some effort was made to balance interpreter code
;     density with interpreter performance, while
;     remaining within the 1KB constraint.  Structured
;     programming principles remained at low priority.
;-----------------------------------------------------;
; VTLC02 variables occupy RAM addresses $0080 to $00ff,
;   and are little-endian, in the 65c02 tradition.
; The use of lower-case and some control characters for
;   variable names is allowed, but not recommended; any
;   attempts to do so would likely result in chaos, due
;   to aliasing with upper-case and system variables.
; Variables tagged with an asterisk are used internally
;   by the interpreter and may change without warning.
;   {@ 0..9 : > ?} are (usually) intercepted by the
;   interpreter, so their internal use by VTLC02 is
;   "safe".  The same cannot be said for {; < =}, so be
;   careful!
at       = $80      ; {@}* internal pointer / mem byte
; VTLC02 standard user variable space
;          $82      ; {A B C .. X Y Z [ \ ] ^ _}
; VTLC02 system variable space
space    = $c0      ; { }* gosub & return stack pointer
bang     = $c2      ; {!}  return line number / gosub
quote    = $c4      ; {"}  current statement command
pound    = $c6      ; {#}  current line number
dolr     = $c8      ; {$}  character I/O
remn     = $ca      ; {%}  remainder of last division
ampr     = $cc      ; {&}  pointer to start of array
tick     = $ce      ; {'}  pseudo-random number
lparen   = $d0      ; {(}* old line # / begin sub-exp
rparen   = $d2      ; {)}  end sub-exp / start comment
star     = $d4      ; {*}  pointer to end of free mem
;          $d6      ; {+ , - . /}  valid user variables
; Interpreter argument stack space
arg      = $e0      ; {0 1 2 3 4 5 6 7 8 9 :}*
; Rarely used variables and argument stack overflow
semi     = $f6      ; {;}  if statement
lthan    = $f8      ; {<}* byte pointer for peek/poke
equal    = $fa      ; {=}* pointer to start of program
gthan    = $fc      ; {>}* temp / call ML subroutine
ques     = $fe      ; {?}* temp / terminal I/O
;
nulstk   = $01ff    ; system stack resides in page 1
;-----------------------------------------------------;
; Equates for the Kowalski 65c02 simulator
ESC      = 27       ; "Cancel current input line" key
CR       = 13       ; newline for output
LF       = 10       ; line feed char
BS       = 8        ; "Delete last keypress" key
EOF      = $ff      ; end of file mark
OP_OR    = '|'      ; Bit-wise OR operator
linbuf   = $0200    ; input line buffer
prgm     = $0400    ; VTLC02 program grows from here
himem    = $adff    ;   ... up to the top of user RAM
vtlstck  = $af00    ; gosub stack space
vtlc02   = $ea00    ; interpreter cold entry point
;                     (warm entry point is startok)
; io_area  = $f000      ;configure simulator terminal I/O
; acia_tx  = io_area+1  ;acia tx data register
; acia_rx  = io_area+4  ;acia rx data register

; EMUZ80 serial I/O
ACIAC    = $B018
ACIAD    = $B019
CONINIT  = $FD1B
CONIN    = $FD28
CONST    = $FD33
CONOUT   = $FD39
;=====================================================;
    *= vtlc02
;-----------------------------------------------------;
; Initialize program area pointers and start VTLC02
; 17 bytes
    lda  #<prgm     ;
    sta  equal      ; {=} -> empty program
    sta  ampr       ; {&} -> empty program
    lda  #>prgm     ;
    sta  equal+1    ;
    sta  ampr+1     ;
    lda  #EOF       ; EOF mark
    sta  (ampr)     ;
    lda  #<himem    ;
    sta  star       ; {*} -> top of user RAM
    lda  #>himem    ;
    sta  star+1     ;
    jsr  CONINIT
startok:
    sec             ; request "OK" message
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Start/restart VTLC02 command line with program intact
; 27 bytes
start:
    lda  #0         ;
    sta  space      ; clear vtl stack pointer
    cld             ; a sensible precaution
    ldx  #<nulstk   ;
    txs             ; drop whatever is on the stack
    bcc  user       ; skip "OK" if carry clear
    ldy  #252       ; (-4)
prompt:
    lda  okay-252,y ; output "\nOK\n" to console
    jsr  outch      ;   print char
    iny             ;   advance y
    bne  prompt     ; continue until y wraps
user:
    jsr  inln       ; input a line from the user
    ldx  #pound     ; cvbin destination = {#}
    jsr  cvbin      ; does line start with a number?
    beq  direct     ;   no: execute direct statement
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Delete/insert/replace program line or list program
; 7 bytes
    clc             ;
    lda  pound      ;
    ora  pound+1    ; {#} = 0?
    bne  edit       ;   no: delete/insert/replace line
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; List program to terminal and restart "OK" prompt
; entry:  Carry must be clear
; uses:   findln:, outch:, prnum:, prntln:, {@ (}
; exit:   to command line via findln:
; 21 bytes
list_:
    jsr  findln     ; find program line >= {#}
    ldx  #lparen    ; line number for prnum
    jsr  prnum      ; print the line number
    lda  #' '       ; print a space instead of the
    jsr  outch      ;   line length byte
    ldx  #0         ; zero for delimiter
    iny
    jsr  prntln     ; print the rest of the line
    sec             ; prepare for next line
    bra  list_      ;
;-----------------------------------------------------;
; The main program execution loop
; entry:  with (cs) via "beq direct" in user:
; exit:   to command line via findln: or "beq start"
; 45 bytes
progr:
    beq  eloop0     ; if {#} = 0 then ignore and
    ldy  lparen+1   ;   continue (false branch)
    ldx  lparen     ; else did {#} change?
    cpy  pound+1    ;   yes: perform a branch, with
    bne  branch     ;     carry flag conditioned for
    cpx  pound      ;     the appropriate direction.
    beq  eloop      ;   no: execute next line (cs)
branch:
    inx             ;   execute a VTLC02 branch
    bne  branch2    ;
    iny             ;
branch2:
    stx  bang       ;   {!} = {(} + 1 (return ptr)
    sty  bang+1     ;
eloop0:
    rol             ;
    eor  #1         ; complement carry flag
    ror             ;
eloop:
    jsr  findln     ; find first/next line >= {#}
    iny             ; skip over the length byte
direct:
    php             ; (cc: program, cs: direct)
    jsr  exec       ; execute one VTLC02 statement
    plp
    lda  pound      ; update Z for {#}
    ora  pound+1    ; if program mode then continue
    bcc  progr      ; if direct mode, did {#} change?
    beq  start      ;   no: restart "OK" prompt
    bne  eloop0     ;   yes: execute program from {#}
;-----------------------------------------------------;
; Delete/insert/replace program line and restart the
;   command prompt (no "OK" means success)
; entry:  Carry must be clear
; uses:   find:, start:, linbuf, {@ > # & * (}
; 147 bytes
edit:
    phy             ; save linbuf offset pointer
    jsr  find       ; point {@} to first line >= {#}
    bcs  insrt      ;
    eor  pound      ; if line doesn't already exist
    bne  insrt      ;   then skip deletion process
    cpx  pound+1    ;
    bne  insrt      ;
    lda  (at),y     ;
    tay             ; y = length of line to delete
    eor  #-1        ;
    adc  ampr       ; {&} = {&} - y
    sta  ampr       ;
    bcs  delt       ;
    dec  ampr+1     ;
delt:
    lda  at         ;
    sta  gthan      ; {>} = {@}
    lda  at+1       ;
    sta  gthan+1    ;
delt2:
    lda  gthan      ;
    cmp  ampr       ; delete the line
    lda  gthan+1    ;
    sbc  ampr+1     ;
    bcs  insrt      ;
    lda  (gthan),y  ;
    sta  (gthan)    ;
    inc  gthan      ;
    bne  delt2      ;
    inc  gthan+1    ;
    bra  delt2      ;
insrt:
    plx             ; x = linbuf offset pointer
    lda  pound      ;
    pha             ; push the new line number on
    lda  pound+1    ;   the system stack
    pha             ;
    ldy  #2         ;
cntln:
    inx             ;
    iny             ; determine new line length in y
    lda  linbuf-1,x ;   and push statement string on
    pha             ;   the system stack
    bne  cntln      ;
    cpy  #4         ; if empty line then skip the
    bcc  markeof    ;   insertion process
    tya             ;
    tax             ; save new line length in x
    clc             ;
    adc  ampr       ; calculate new program end
    sta  gthan      ; {>} = {&} + y
    lda  #0         ;
    adc  ampr+1     ;
    sta  gthan+1    ;
    lda  gthan      ;
    cmp  star       ; if {>} >= {*} then the program
    lda  gthan+1    ;   won't fit in available RAM,
    sbc  star+1     ;   so drop the stack and abort
    bcs  markeof    ;   to the "OK" prompt
slide:
    lda  ampr       ;
    bne  slide2     ;
    dec  ampr+1     ;
slide2:
    dec  ampr       ;
    lda  ampr       ;
    cmp  at         ;
    lda  ampr+1     ;
    sbc  at+1       ;
    bcc  move2      ; slide open a gap inside the
    lda  (ampr)     ;   program just big enough to
    sta  (ampr),y   ;   hold the new line
    bra  slide      ;
move2:
    pla             ; pull the statement string and
    dey             ;   the new line number and store
    sta  (at),y     ;   them in the program gap
    bne  move2      ;
    ldy  #2         ;
    txa             ;
    sta  (at),y     ; store length after line number
    lda  gthan      ;
    sta  ampr       ; {&} = {>}
    lda  gthan+1    ;
    sta  ampr+1     ;
markeof:
    lda  #EOF       ; EOF mark
    sta  (ampr)
jstart:
    jmp  start      ; drop stack, restart cmd prompt
;-----------------------------------------------------;
; {$=...} statement handler; called from exec:
joutch:
    jsr  outch      ;
    jmp  execend    ;
;-----------------------------------------------------;
; General purpose print
; If a key was pressed, pause for another keypress
;   before returning.  If either of those keys was a
;   ctrl-C, drop the stack and restart the "OK" prompt
;   with the user program intact
; entry:  @[y] -> string, x = delimiter char
; exit:   (normal) @[y] -> byte after delimiter
;         (ctrl-C) drop the stack & restart "OK" prompt
outmsg:
    stx  ques       ; store delimiter
outloop:
    lda  (at),y     ; get char
    iny             ;
    cmp  ques       ; found delimiter ?
    beq  outrts     ;   yes: finish up (y = next char)
    jsr  outch      ;   no: print char to terminal
    bra  outloop    ; loop to next char
outrts:
    jsr  pause      ; check for pause or abort
    rts             ;
;-----------------------------------------------------;
; {?="..."} Print string literal
; entry:  @[y] -> string start quote, a = delimiter /"/
strng:
    tax             ; set delimiter
    iny             ; next to quote     -> /?="X.."/
    jsr  outmsg     ; print until delimiter
    lda  (at),y     ; get byte after delimiter
    cmp  #';'       ; if trailing char is ';' ?
    beq  strng2     ;   yes: skip newline
    lda  #CR        ;   no: print newline
    jsr  outch      ;
    dey             ; cancel next increment
strng2:
    iny             ; skip ';'
    lda  (at),y     ; fetch next char -> /?="...";X.../
    sty  dolr+1
    sta  dolr
    bra  execend
;-----------------------------------------------------;
; Print \0 terminated line from @[y] and newline
prntln:
    ldx  #0         ; set delimiter
    jsr  outmsg     ;
    lda  #CR        ; print newline
    jmp  outch      ;
;-----------------------------------------------------;
; Execute a (hopefully) valid VTLC02 statement at @[y]
; entry:   @[y] -> left-side of statement
; uses:    nearly everything
; exit:    note to machine language subroutine {>=...}
;            users: no registers or variables are
;            required to be preserved except the system
;            stack pointer, the text base pointer {@},
;            and the original line number {(}
; if there is a '"' directly after the assignment
;   operator, the statement will execute as {?="...},
;   regardless of the variable named on the left side
; 83 bytes
exec:
    jsr  getbyte    ; fetch left-side variable name
    beq  execrts    ; do nothing with a null statement
    sty  quote      ; save statement start pos
    iny             ;
    cmp  #')'       ; same for a full-line comment
    beq  execrts    ;
    cmp  #']'       ;
    beq  retstmt0   ;
    cmp  #'{'       ;
    beq  dostmt0    ;
    ldx  #arg       ; initialize argument stack
    jsr  convp      ; arg[{0}] -> left-side variable
    jsr  getbyte    ; skip over assignment operator
    jsr  skpbyte    ; is right-side a literal string?
    cmp  #'"'       ;   yes: print the string with
    beq  strng      ;     trailing ';' check & return
    ldx  arg        ; check left-side var name
    cpx  #ques      ; if {?=...} statement then print
    beq  prnumx0    ;   in variouse format
    ldx  #arg+2     ; point eval to arg[{1}]
    jsr  eval       ; evaluate right-side in arg[{1}]
    sta  dolr       ; save last char
    sty  dolr+1     ; save last index
    lda  arg+2      ;
    ldx  arg+1      ; was left-side an array element?
    bne  exec3      ;   yes: skip to default actions
    ldx  arg        ;
    cpx  #at        ; if {@=...} statement then poke
    beq  poke       ;   low half of arg[{2}] to arg[{1}]
    cpx  #dolr      ; if {$=...} statement then print
    beq  joutch     ;   arg[{1}] as ASCII character
    cpx  #lthan     ; if {<=...} statement then poke
    beq  poke16     ;   arg[{2}] to arg[{1}]
    cpx  #gthan     ; if {>=...} statement then call
    beq  usr        ;   user-defined ml routine
    cpx  #semi      ; if {;=...} statement then
    beq  ifstmt     ;   exec if-then statement
    cpx  #ampr      ; if {&=...} 
    beq  prgman0    ;   exec new statement
    cpx  #equal     ; if {==...} 
    beq  prgman0    ;   exec search-end statement
    cpx  #bang      ; if {!=...}
    beq  gosub0     ;   exec gosub statement
exec3:
    sta  (arg)      ;
    adc  tick+1     ; store arg[{1}] in the left-side
    rol             ;   variable
    tax             ;
    ldy  #1         ;
    lda  arg+3      ;
    sta  (arg),y    ;
    adc  tick       ; pseudo-randomize {'}
    rol             ;
    sta  tick+1     ;
    stx  tick       ;
execend:
    ldy  dolr+1     ; restore last index
    lda  dolr       ; restore last char
    cmp  #' '       ; statement seperator?
    bne  execrts    ;   no: exec end
execend2:
    lda  (at),y     ; check next char
    cmp  #' '       ;   is space ?
    bne  exec       ;   no: go next statement
    iny             ;   yes: skip all spaces
    bra  execend2   ;
execrts:
    rts             ;
retstmt0:
    jmp  retstmt
dostmt0:
    jmp  dostmt
prnumx0:
    jmp prnumx
prgman0:
    jmp  progman    ; program management commands
gosub0:
    jmp  gosub
usr:
    jsr  usr2       ; call user ml and
    sta  gthan+1    ;  result a:x set to gthan
    stx  gthan      ;
    bra  execend    ;
usr2:
    lda  arg+5      ; jump to user ml routine with
    ldx  arg+4      ;   arg[{2}] in a:x (MSB:LSB)
    jmp  (arg+2)    ; {"} must point to valid 6502 code
poke:
    lda  arg+4      ; arg[{2}] low to a
    sta  (arg+2)    ; use arg[{1}] as pointer
    jmp  execend
poke16:
    lda  arg+4      ; arg[{2}] low to a
    sta  (arg+2)    ; use arg[{1}] as pointer
    ldy  #1         ;
    lda  arg+5      ; arg[{2}] high to a
    sta  (arg+2),y  ; use arg[{1}] as pointer
    jmp  execend
ifstmt:
    ora  arg+3      ; arg is 0?
    beq  execrts    ;   yes: end exec
    bne  execend    ;   no: go next statement
;-----------------------------------------------------;
; {?=...} handler with variouse format; called by exec:
; y index pos
;    print decimal -> {?=X..."}  start quote
;    print 1 hex   -> {?$X"..."}  equal sign
;    print 2 hex   -> {??X"..."}  equal sign
prnumx:
    phy             ; save current pos
    ldy  quote      ; fetch 1 byte
    iny             ;   next to '?'
    lda  (at),y     ;
    ply             ; restore current pos
    cmp  #'='       ; is '=' ?
    bne  prnumx2    ;   no: print hex
    ldx  #arg+2     ; point eval to arg[{1}]
    jsr  eval       ; evaluate right-side in arg[{1}]
    sta  dolr       ; save last char
    sty  dolr+1     ; save last index
    bra  prnum0
prnumx2:
    iny
    ldx  #arg+2     ; point eval to arg[{1}]
    cmp  #'?'       ; command is '??=' ?
    beq  prnumx3    ;   yes: print double hex
    jsr  eval       ; evaluate right-side in arg[{1}]
    sta  dolr       ; save last char
    sty  dolr+1     ; save last index
    lda  arg+2      ;
    jsr  prhex
    bra  execend
prnumx3:
    jsr  eval       ; evaluate right-side in arg[{1}]
    sta  dolr       ; save last char
    sty  dolr+1     ; save last index
    lda  arg+3      ;
    jsr  prhex
    lda  arg+2      ;
    jsr  prhex
    jmp  execend
;-----------------------------------------------------;
; Print signed decimal number
; 20 bytes
prnum0:
    ldx  #arg+2     ; set pointer x -> arg[{1}]
    lda  1,x        ; test minus sign bit of msb
    bpl  prplus     ;
    jsr  negate     ;
    lda  #'-'       ; print '-' sign
    jsr  outch
prplus:
    jsr  prnum
    jmp  execend
;-----------------------------------------------------;
; negate var[x]
; 14 bytes
negate:
    lda  #0
    sec
    sbc  0,x
    sta  0,x
    lda  #0
    sbc  1,x
    sta  1,x
negrts:
    rts
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Print var[x] as unsigned decimal number (0..65535)  ;
; Clever V-flag trick comes courtesy of John Brooks.  ;
; entry:   var[x] = number to print                   ;
; uses:    outch:                                     ;
; exit:    var[x] = a = 0                             ;
; 36 bytes                                            ;
prnum:
    phy             ; save y
    lda  #0         ; stack sentinel
prnum2:             ; repeat {
    pha             ;   stack ASCII digit
    lda  #0         ;   remainder = 0 
    clv             ;   (sets if quotient > 0)
    ldy  #16        ;   16-bit divide by ten
prnum3:
    cmp  #5         ;     partial rem >= radix/2?
    bcc  prnum4     ;
    sbc  #133       ;     yes: update rem, set V
    sec             ;     and C for non-zero quot
prnum4:
    rol  0,x        ;     new quotient gradually 
    rol  1,x        ;       replaces var[x]
    rol             ;     new remainder gradually
    dey             ;       replaces a
    bne  prnum3     ;   continue 16-bit divide 
    ora  #'0'       ;   convert remainder to ASCII
    bvs  prnum2     ; } until no more digits
prnum5:
    jsr  outch      ; print digits in descending
    pla             ;   order until stack sentinel
    bne  prnum5     ;   is encountered
    ply             ; restore y
    rts             ;
;-----------------------------------------------------;
; Print a as hexadecimal number (00 .. FF)
prhex:
    pha             ; save a for lsb
    lsr             ; msb to lsb position
    lsr
    lsr
    lsr
    jsr  prhex2
    pla
prhex2:
    and  #$0f       ; mask LSD
    clc
    adc  #$30       ; add '0'
    cmp  #$3a       ; digit?
    bcc  prhex3     ;   yes: print it
    adc  #$06       ; add offset to letter
prhex3:
    jsr  outch
    rts
;-----------------------------------------------------;
; Program management commands "new" and "search-end"
progman:
    phy             ; save index
    ldy  quote      ; read original
    lda  (at),y     ;  command char
    ply             ; restore index
    cmp  #'}'       ; until ?
    beq  untlstmt   ;   yes: go to routine
    lda  pound      ;
    ora  pound+1    ; direct mode?
    bne  progman3   ;   no: normal assignment
    lda  arg+2      ;
    ora  arg+3      ; arg is 0 ?
    bne  progman3   ;   no: normal assignment
    cpx  #ampr      ; new statement ?
    bne  progman2   ;   no: go next one
    lda  equal      ;   yes: process new command
    sta  ampr       ;
    lda  equal+1    ; {=} -> {&}
    sta  ampr+1     ;
    lda  #EOF       ; EOF mark
    sta  (ampr)     ;
    jmp  execend
progman2:
    cpx  #equal     ; search-end statement ?
    bne  progman3   ;   no: go next one
    lda  equal      ; set program top address
    sta  gthan      ;   to search pointer
    lda  equal+1    ; {>} = {=}
    sta  gthan+1    ;
srchend:
    lda  (gthan)
    cmp  #EOF
    beq  srchend2
    ldy  #2
    lda  (gthan),y  ; line length -> a
    clc             ; move pointer to next line
    adc  gthan      ;
    sta  gthan      ;
    lda  #0         ;
    adc  gthan+1    ;
    sta  gthan+1    ;
    bra  srchend    ; go next loop
srchend2:
    lda  gthan      ; {&} = {>}
    sta  ampr       ;
    lda  gthan+1    ;
    sta  ampr+1     ;
    lda  #EOF       ;
    sta  (ampr)     ;
    jmp  execend    ;
progman3:
    lda  arg+2      ;
    jmp  exec3      ;
;-----------------------------------------------------;
; until statement
untlstmt:
    lda  arg+2      ; arg is 0?
    ora  arg+3      ;
    beq  retstmt    ;   yes: false case -> loop again
    ldy  space      ;   no: true case -> loop end
    dey             ; drop stack and
    dey             ;   goto next statement
    dey             ;
    bpl  untlend    ;
    ldy  #0         ; reset stack for fail safe
untlend:
    sty  space      ; udpate stack poiner
    jmp  execend    ; goto next
;-----------------------------------------------------;
; gosub statement
gosub:
    lda  pound      ;
    ora  pound+1    ; direct mode?
    beq  gosub2     ;   yes: return to command line
    jsr  pshstk     ;    no: push line # and offset
    lda  arg+2      ; new line no high
    sta  pound      ;
    lda  arg+3      ; new line no low
    sta  pound+1    ;
    rts             ; goto next line
gosub2:
    jmp  start      ;
pshstk:
    phy             ; save line index
    ldy  space      ; stack pointer to y
    lda  at         ;
    sta  vtlstck,y  ; line address high
    iny             ;
    lda  at+1       ;
    sta  vtlstck,y  ; line address low
    iny             ;
    pla             ; restore index to a
    sta  vtlstck,y  ; inline index
    iny             ;
    sty  space      ; update stack pointer
    rts
;-----------------------------------------------------;
; return from subroutine
retstmt:
    ldy  space      ; check stack is empty ?
    beq  retstop    ;   yes: stop program
    dey             ;
    lda  vtlstck,y  ; load line index
    pha             ; save index
    dey             ;
    lda  vtlstck,y  ; load line addr low
    sta  at+1       ;
    dey             ;
    sty  space      ; update stack pointer
    lda  vtlstck,y  ; load line addr high
    sta  at         ;
    lda  (at)       ; load line no high
    sta  pound      ; set current line no high
    sta  lparen     ; set original line no high
    ldy  #1         ;
    lda  (at),y     ; load line no low
    sta  pound+1    ;
    sta  lparen+1   ;
    pla             ; restore index
    tay             ;   to y
    jmp  exec       ; continue exec
retstop:
    sec
    jmp  start      ; return to OK prompt.
;-----------------------------------------------------;
; do-while loop statement
dostmt:
    dey
    jsr  pshstk     ; save current point to stack
    tay             ; now point to '{'
    iny
    iny
    jmp  exec
;-----------------------------------------------------;
; Evaluate a (hopefully) valid VTLC02 expression at
;   @[y] and place its calculated value in arg[x]
; A VTLC02 expression is defined as a string of one or
;   more terms, separated by operators and terminated
;   with a '\0' or an unmatched ')'
; A term is defined as a variable name, a decimal
;   constant, or a parenthesized sub-expression; terms
;   are evaluated strictly from left to right
; A variable name is defined as a user variable, an
;   array element expression enclosed in {: )}, or a
;   system variable (which may have side-effects)
; entry:   @[y] -> expression text, x -> argument
; uses:    getval:, oper:, {@}, argument stack area
; exit:    arg[x] = result, @[y] -> next text
; 27 bytes                                            ;
eval:
    jsr  getval     ; get first term into arg[x]
eval2:
    jsr  getbyte    ; end of expression '\0', ')' or ' '?
    beq  getrts     ;   yes: done
    iny             ;
    cmp  #')'       ;
    beq  getrts     ;
    cmp  #' '       ;
    beq  getrts     ;
    pha             ;   no: stack alleged operator
    inx             ; advance the argument stack
    inx             ;   pointer
    jsr  getval     ; arg[x+2] = value of next term
    dex             ;
    dex             ;
    pla             ; retrieve and apply operator
    jsr  oper       ;   to arg[x], arg[x+2]
    bra  eval2      ; loop until end of expression
;-----------------------------------------------------;
; Get numeric value of the term at @[y] into var[x]
; Some examples of valid terms:  123, $, H, (15-:J)/?)
; 75 bytes
getval:
    jsr  cvbin      ; decimal constant at @[y]?
    bne  getrts     ;   yes: return with it in var[x]
    jsr  getbyte    ;
    iny             ;
    cmp  #'?'       ; user line input?
    bne  getval1    ;
    phy             ;   yes:
    lda  at         ;     save @[y]
    pha             ;     (current expression ptr)
    lda  at+1       ;
    pha             ;
    jsr  inln       ; input expression from user
    jsr  eval       ; evaluate, var[x] = result
    pla             ;
    sta  at+1       ;
    pla             ;
    sta  at         ; restore @[y]
    ply             ;
    rts             ; skip over "?" and return
getval1:
    cmp  #'-'       ; minus sign ?
    bne  getval2    ;
    jsr  cvbin      ; evaluate next term
    jsr  negate     ;   and negate
    bra  getrts     ;
getval2:
    cmp  #'$'       ; user char input?
    bne  getval3    ;
    jsr  inch       ;   yes: input one char
    bra  getval5    ;
getval3:
    cmp  #'"'       ; char constant?
    bne  getval3a   ;
    jsr  getbyte    ;   yes: get next char
    iny             ;
    iny             ; skip enclosing quote
    bra  getval5    ;
getval3a:
    cmp  #'('       ; sub-expression?
    beq  eval       ;   yes: evaluate it recursively
    jsr  convp      ;   no: first set var[x] to the
    lda  (0,x)      ;     named variable's address,
    pha             ;     then replace that address
    inc  0,x        ;     with the variable's actual
    bne  getval4    ;     value before returning
    inc  1,x        ;
getval4:
    lda  (0,x)      ;
    sta  1,x        ; store high-byte of term value
    pla             ;
getval5:
    sta  0,x        ; store low-byte of term value
getrts:
    rts             ;
;-----------------------------------------------------;
; var[x] = (var[x]*var[x+2])mod65536 (unsigned)
; uses:    plus:, {>}
; exit:    var[x+2] and {>} are modified
; 39 bytes
mul:
    lda  0,x        ;
    sta  gthan      ;
    lda  1,x        ; copy multiplicand to {>}
    sta  gthan+1    ;
    stz  0,x        ; zero the product to begin
    stz  1,x        ;
    !byte  $cd        ; "cmp abs" naked op-code
mul1:
    rol  3,x        ;
mul2:
    lda  gthan      ;
    ora  gthan+1    ;
    beq  mulrts     ; exit early if multiplicand = 0
    lsr  gthan+1    ;
    ror  gthan      ; right-shift multiplicand
    bcc  mul3       ; check the bit shifted out
    jsr  plus       ; form the product in var[x]
mul3:
    asl  2,x        ; left-shift multiplier
    bne  mul1       ;
    rol  3,x        ;
    bne  mul2       ; loop until multiplier = 0
mulrts:
    rts             ;
;-----------------------------------------------------;
; Set var[x] to the address of the variable named in a
; entry:   a holds variable name, @[y] -> text holding
;            array index expression (if a = ':')
; uses:    plus:, eval:, oper8d:, {@ &}
; exit:    (eq): var[x] -> variable, @[y] unchanged
;          (ne): var[x] -> array element,
;                @[y] -> following text
; 19 bytes
convp:
    cmp  #':'       ; array element?
    bne  simple     ;   no: simple variable
    jsr  eval       ;   yes: evaluate array index at
    asl  0,x        ;     @[y] and advance y
    rol  1,x        ;
    lda  ampr       ;   var[x] -> array element
    sta  2,x        ;     at address 2*index+&
    lda  ampr+1     ;
    sta  3,x        ;
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; var[x] += var[x+2]
; 14 bytes
plus:
    clc             ;
    lda  0,x        ;
    adc  2,x        ;
    sta  0,x        ;
    lda  1,x        ;
    adc  3,x        ;
plus2:
    sta  1,x        ;
    rts             ;
;-----------------------------------------------------;
; var[x] -= var[x+2]
; expects:  (cs), pre-decremented x
; 10 bytes
minus:
    jsr  minus2     ;
    inx             ;
minus2:
    lda  1,x        ;
    sbc  3,x        ;
    bra  plus2      ;
;-----------------------------------------------------;
; The following section is designed to translate the
;   named simple variable from its ASCII value to its
;   zero-page address.  In this case, 'A' translates
;   to $82, '!' translates to $c2, etc.  The method
;   employed must correspond to the zero-page equates
;   above, or strange and not-so-wonderful bugs will
;   befall the weary traveller on his or her porting
;   journey.
; 5 bytes
simple:
    asl             ; form simple variable address
    ora  #$80       ; mapping function is (a*2)|128
    bra  oper8d     ;
;-----------------------------------------------------;
; Apply the binary operator in a to var[x] and var[x+2]
; Valid VTLC02 operators are {* + / [ ] - | ^ & < = > ,}
; {>} is defined as greater than _or_equal_
; An undefined operator will be interpreted as one of
;   the three comparison operators
; 37 bytes
oper:
    cmp  #'+'       ; addition operator?
    beq  plus       ;
    cmp  #'*'       ; multiplication operator?
    beq  mul        ;
    cmp  #'/'       ; division operator?
    beq  divsig0    ;
    cmp  #'['       ; "then" operator?
    beq  then_      ;
    cmp  #']'       ; "else" operator?
    beq  else_      ;
    cmp  #','       ; comma operator?
    beq  and_rt     ;
    cmp  #'@'       ; peek oper
    beq  peek0      ;
    dex             ; (factored from the following ops)
    cmp  #'-'       ; subtraction operator?
    beq  minus      ;
    cmp  #OP_OR     ; bit-wise or operator?
    beq  or_        ;
    cmp  #'^'       ; bit-wise xor operator?
    beq  xor_       ;
    cmp  #'&'       ; bit-wise and operator?
    beq  and_       ;
    cmp  #'#'       ; not equal operator
    beq  noteq      ;
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Apply comparison operator in a to var[x] and var[x+2]
;   and place result in var[x] (1: true, 0: false)
; expects:  (cs), pre-decremented x
; 28 bytes
    eor  #'<'       ; 0: '<'  1: '='  2: '>'
    sta  gthan      ; other values in a are undefined,
    jsr  minus      ;   but _will_ produce some result
    ; test sign bit of msb
    lda  1,x
    bpl  opgte
    ; if minus ? ... a < b
    ;   if gthan is 0 -> true else false
    lda  gthan
    bne  opfalse
    beq  optrue
opgte:
    ; 0: '<'  1: '='  2: '>'
    ; if plus or zero ... a >= b
    ;  if gthan is 1 -> true else false
    ora  0,x
    beq  opeql 
    ; a > b
    ;   if gthan is 0 -> false, 1 -> false, 2 -> true
    lda  gthan
    cmp  #2
    bra  opend
opeql:
    ; a = b
    ;   if gthan is 0 -> false, 1 -> true, 2 -> true
    lda  gthan
    beq  opfalse
optrue:
    sec
    bra  opend
opfalse:
    clc
opend:
    lda  #0
    adc  #0         ;
    and  #1         ; var[x] = 1 (true), 0 (false)
oper8d:
    sta  0,x        ;
oper8e:
    stz  1,x        ;
oper8f:
    rts             ;
;-----------------------------------------------------;
divsig0:
    bra divsig
;-----------------------------------------------------;
; var[x] &= var[x+2]
; expects:  pre-decremented x
; 10 bytes
and_:
    jsr  and_2      ;
    inx             ;
and_2:
    lda  1,x        ;
    and  3,x        ;
and_rt:
    rts             ;
;-----------------------------------------------------;
; var[x] |= var[x+2]
; expects:  pre-decremented x
; 10 bytes
or_:
    jsr  or_2       ;
    inx             ;
or_2:
    lda  1,x        ;
    ora  3,x        ;
    bra  and_rt     ;
;-----------------------------------------------------;
; var[x] ^= var[x+2]
; expects:  pre-decremented x
; 10 bytes
xor_:
    jsr  xor_2      ;
    inx             ;
xor_2:
    lda  1,x        ;
    eor  3,x        ;
    bra  and_rt     ;
;-----------------------------------------------------;
; A[B returns 0 if A is 0, otherwise returns B
; 14 bytes
then_:
    lda  0,x        ;
    ora  1,x        ;
    beq  oper8f     ;
then_2:
    lda  2,x        ;
    sta  0,x        ;
    lda  3,x        ;
    bra  and_rt     ;
;-----------------------------------------------------;
; A]B returns B if A is 0, otherwise returns 0
; 10 bytes
else_:
    lda  0,x        ;
    ora  1,x        ;
    beq  then_2     ;
    stz  0,x        ;
    bra  oper8e     ;
;-----------------------------------------------------;
peek0:
    jmp peek
;-----------------------------------------------------;
noteq
    jsr  minus      ; var[x] = var[x] - var[x+2]
    lda  1,x        ; test var[x]
    ora  0,x        ;
    bne  noteq1     ;
    stz  0,x        ; var[x] == 0 -> false (0)
    bra  noteq2
noteq1:
    lda  #1         ; var[x] <> 0 -> true (1)
    sta  0,x
noteq2:
    stz  1,x
    rts
;-----------------------------------------------------;
; division for signed number
divsig:
    stz  ques       ; init sign strage
    stz  ques+1     ;
    ; test msb of var[x] sign bit
    lda  1,x        ; msb of var[x]
    bpl  divpls
    inc  ques       ; if minus case
    jsr  negate
divpls:
    ; test msb of var[x+2] sign bit
    lda  3,x        ; msb of var[x+2]
    bpl  divpls2
    inc  ques+1     ; if minus
    inx
    inx
    jsr  negate
    dex
    dex
divpls2:
    ; do unsigned div and restore sign
    jsr  div
    lda  ques
    eor  ques+1
    beq  dvskp
    jsr  negate
    phx
    ldx  #remn
    jsr  negate
    plx
dvskp:    
    rts
;-----------------------------------------------------;
; var[x] = var[x]/var[x+2] (unsigned), {%} = remainder
;   var[x] /= 0 produces {%} = var[x], var[x] = 65535
; 39 bytes                                            ;
div:
    phy             ;
    ldy  #16        ; loop counter
    lda  #0         ;
    sta  remn+1     ; {%} = 0
div2:
    asl  0,x        ; dividend gradually becomes
    rol  1,x        ;   the quotient
    rol             ; {%} gradually becomes the
    rol  remn+1     ;   remainder
    cmp  2,x        ;
    pha             ;
    lda  remn+1     ;
    sbc  3,x        ; partial remainder >= divisor?
    bcc  div3       ;
    sta  remn+1     ;
    pla             ;   yes: update the partial
    sbc  2,x        ;     remainder and set the low
    inc  0,x        ;     bit of partial quotient
    !byte  $c9      ;     "cmp #" naked op-code
div3:
    pla             ;
    dey             ;
    bne  div2       ; loop 16 times
    sta  remn       ;
    ply             ;
    rts             ;
peek:
    jsr  plus       ; var[x] = var[x] + var[x+2]
    lda  (0,x)      ; use var[x] as pointer
    sta  0,x        ; store it
    stz  1,x        ;
    rts             ;
;-----------------------------------------------------;
; If text at @[y] is an unsigned decimal or hex constant,
;   translate it into var[x] (mod 65536) and update y
; entry:   @[y] -> text containing possible constant;
;            leading space characters are skipped, but
;            any spaces encountered after a conversion
;            has begun will end the conversion.
; used by: user:, getval:
; uses:    mul:, plus:, var[x], var[x+2], {@ > ?}
; exit:    (ne): var[x] = constant, @[y] -> next text
;          (eq): var[x] = 0, @[y] unchanged
;          (cs): in all but the truly strangest cases
; 41 bytes
cvbin:
    stz  0,x        ; var[x] = 0
    stz  1,x        ;
    stz  3,x        ;
    jsr  getbyte    ; skip any leading spaces
    sty  ques       ; save pointer
    cmp  #'0'
    beq  cvhex2
    bra  cvbin3     ;
cvbin2:
    pha             ; save decimal digit
    lda  #10        ;
    sta  2,x        ;
    jsr  mul        ; var[x] *= 10
    stz  3,x        ;
    pla             ; retrieve decimal digit
    sta  2,x        ;
    jsr  plus       ; var[x] += digit
    iny             ;
    lda  (at),y     ; grab next char
cvbin3:
    eor  #'0'       ; if char at @[y] is not a
    cmp  #10        ;   decimal digit then stop
    bcc  cvbin2     ;   the conversion
    cpy  ques       ; (ne) if valid, (eq) if not
    rts             ;
;-----------------------------------------------------;
; If text at @[y] is an unsigned hexadecimal constant,
;   translate it into var[x] (mod 65536) and update y
cvhex:
    pha             ; save decimal digit
    lda  #16        ;
    sta  2,x        ;
    jsr  mul        ; var[x] *= 16
    stz  3,x        ;
    pla             ; retrieve decimal digit
    sta  2,x        ;
    jsr  plus       ; var[x] += digit
    iny             ;
    lda  (at),y     ; grab next char
cvhex2:
    eor  #'0'       ; if char at @[y] is not a
    cmp  #10        ;   decimal digit then 
    bcc  cvhex      ;   the conversion
    eor  #'0'       ; restore a by eor twice.
    sec             ;
    sbc  #'A'- 10   ; when a is 'A' -> value is 10.
    cmp  #10        ; A >= 10 ?
    bcc  cvhex3     ;   no: stop conv
    cmp  #16        ; A < 16 ?
    bcc  cvhex      ;   yes: go to conversion
cvhex3:
    cpy  ques       ; restore y
    rts             ;
;-----------------------------------------------------;
; Accept input line from user and store it in linbuf,
;   zero-terminated (allows very primitive edit/cancel)
; entry:   (jsr to inln or newln, not inln6)
; used by: user:, getval:
; uses:    inch:, outnl:, linbuf, {@}
; exit:    @[y] -> linbuf
; 42 bytes
inln6:
    cmp  #ESC       ; escape?
    beq  newln      ;   yes: discard entire line
    iny             ; line limit exceeded?
    bpl  inln2      ;   no: keep going
newln:
    lda  #CR        ;   yes: discard entire line
    jsr  outch      ;
inln:
    lda  #<linbuf   ; entry point: start a fresh line
    sta  at         ; {@} -> input line buffer
    lda  #>linbuf   ;
    sta  at+1       ;
    ldy  #1         ;
inln5:
    dey             ;
    bmi  newln      ;
inln2:
    jsr  inch       ; get (and echo) one keypress
    cmp  #BS        ; backspace?
    beq  inln5      ;   yes: delete previous char
    cmp  #CR        ; enter?
    bne  inln3      ;
    lda  #0         ;   yes: replace with '\0'
inln3:
    sta  (at),y     ; put key in linbuf
    bne  inln6      ; continue if not '\0'
    tay             ; y = 0
    rts             ;
;-----------------------------------------------------;
; Fetch a byte at @[y], ignoring space characters
; 10 bytes
skpbyte:
    iny             ; skip over current char
getbyte:
    lda  (at),y     ;
    rts             ;
;-----------------------------------------------------;
; Find the first/next stored program line >= {#}
; entry:   (cc): start search at program beginning
;          (cs): start search at next line
;                ({@} -> beginning of current line)
; used by: edit:, findln:
; uses:    {= @ # & (}
; exit:    (cs): {@} = {&}, x:a and {(} invalid, y = 2
;          (cc): {@} -> beginning of found line, y = 2,
;                x:a = {(} = actual found line number
; 52 bytes
find:
    lda  equal      ;
    ldx  equal+1    ;
    ldy  #2         ;
    bcc  find1st    ; (cc): search begins at first line
    ldx  at+1       ;
    clc             ;
findnxt:
    lda  at         ; {@} -> next line (or {&} if
    adc  (at),y     ;   there is no next line ...)
    bcc  find5      ;
    inx             ;
find1st:
    stx  at+1       ;
find5:
    sta  at         ;
    cpx  ampr+1     ; {@} >= {&} (end of program)?
    bcc  find6      ;
    cmp  ampr       ;
    bcs  findrts    ;   yes: line not found (cs)
find6:
    lda  (at)       ;
    sta  lparen     ; {(} = current line number
    cmp  pound      ;
    dey             ;
    lda  (at),y     ;
    iny             ;
    sta  lparen+1   ;
    sbc  pound+1    ; if {(} < {#} then try the next
    bcc  findnxt    ;   program line
    clc             ; found line (cc)
    lda  lparen     ;
    ldx  lparen+1   ;
findrts:
    rts             ;
;-----------------------------------------------------;
; Point @[y] to the first/next program line >= {#}
; entry:   (cc): start search at beginning of program
;          (cs): start search at next line
;                ({@} -> beginning of current line)
; used by: list_:, progr:
; uses:    find:, prgm, {@ # & (}
; exit:    if line not found then abort to "OK" prompt
;          else {@} -> found line, x:a = {#} = {(} =
;            actual line number, y = 2, (cc)
; 13 bytes
findln:
    jsr  find       ; find first/next line >= {#}
    bcs  istart     ; if end then restart "OK" prompt
    sta  pound      ; {#} = {(}
    stx  pound+1    ;
    rts             ;
istart:
    jmp  start      ; drop stack, restart "OK" prompt
;-----------------------------------------------------;
; Check for user keypress and return if none has
;   arrived.  Otherwise, pause for another keypress
;   before returning.  If either key is ctrl-C then
;   drop the stack and restart the "OK" prompt.
; 23 bytes
pause:
    jsr  inkey      ;
    beq  inkeyr     ; return if no keypress
waitkey:
    jsr  inkey      ;
    beq  waitkey    ; wait for a keypress
    rts             ; return with it in a
inkey:
    ; lda  acia_rx    ; has a keypress arrived?
    ; beq  inkeyr     ;   no: return immediately
    ; cmp  #3         ; ctrl-C?
    ; beq  istart     ;   yes: abort to "OK" prompt
    ; cmp  #LF        ; ignore LF (Kowalski)
    jsr  CONST
    beq  inkeyr
    jsr  CONIN
    cmp  #3
    beq  istart
inkeyr:
    rts             ;
;-----------------------------------------------------;
; Wait for key from I/O window into a and echo
; Drop stack and abort to "OK" prompt if ctrl-C
; 3 bytes
inch:
    jsr  waitkey    ; wait for keypress, fall through
; - - - - - - - - - - - - - - - - - - - - - - - - - - ;
; Print ASCII char in a to I/O window
; 16 bytes
outch:
    ; cmp  #CR        ;
    ; bne  not_cr     ;
    ; lda  #LF        ; add LF to CR (Kowalski)
    ; sta  acia_tx    ; emit LF via transmit register
    ; lda  #CR        ;
not_cr:
    ; sta  acia_tx    ; emit char via transmit register
    jsr  CONOUT
    rts             ;
;-----------------------------------------------------;
; "\nOK\n" prompt
; 4 bytes
okay:
    !text  CR,"OK",CR
;-----------------------------------------------------;
    ; .end vtlc02     ; set start address
