* $Id: d5bug.asm,v 1.14 2021/07/20 01:10:57 rdup Exp rdup $
* $Log: d5bug.asm,v $
* Revision 1.14  2021/07/20 01:10:57  rdup
* Revision 1.0 of typing errors
*
* Revision 1.1  2021/07/07 06:04:21  rdup
* Initial revision
*
*RESET 
	NAM RESET
*	OPT CRET,LLN=80
	ORG $F000
******************************************
*
* RESET - COLD START ROUTINE
*
****************************************** 
RESET	NOP 		SET INTERRUPT MASK
	SEI		.
	LDX	#$E3FF	CLEAR RAM
CLRLOP	INX		.
	CLR	0,X	.
	CPX	#$E487	.
	BNE	CLRLOP	.
	LDX	#$E484	INITIALIZE SYSTEM PIA
	LDAA	#$7F	.
	STAA	0,X	.
	LDAA	#$FF	.
	STAA	2,X	.
	LDAA	#$06	.
	STAA	1,X	.
	STAA	3,X	.
	LDX	#$E418	DEFAULT USER STACK
	STX	USP	.
******************************************
*
* PROMPT - ROUTINE TO SET UP PROMPT CONDITIONS
*
******************************************
PROMPT	LDS	#STKTOP INIT SYSTEM STACK
	LDAA	#1      SET FIRST PASS
	STAA	ROLPAS  .
	CLR	UPROG   INIT FLAGS
	CLR	ROIFLG  .
	CLR	KYFLG   .
	CLR	FNCFL   .
	LDAA	#$40    DISPLAY PROMPT
	STAA	DISBUF  .
	LDAA	#%00011111 .
	JSR	CLRDS   .
	LDX	#FUNSEL EXECUTE FUNCTION SELECT
	STX	MNPTR   .
	JSR	ENNMI   ENABLE NMI
	JMP	PUT	& GO
*
******************************************
*
* GET ROUTINE TO READ A KEY
*
******************************************
GET	LDX	#PIA	POINT AT PIA
	LDAA	#$FF	.
	STAA	KPCOL,X	TO TURN OFF DISPLAY
	LDAA	#%00111111 COL 0, ALL ROWS
LPCOL	STAA	KPROW,X STORE INFO TO KEY MATRIX
	TST	KPCOL,X	MSB IS MUX BIT
	BPL	COLFND	BIT-7 LOW MEANS COL FOUND
	ADDA	#$40	INC COL BITS TO MUX
	BCC	LPCOL	CONTINUE FOR ALL COLS
	BRA	GET	KEY BOUNCED, START OVER
COLFND	ANDA	#$11000000 MASK TO SAVE ONLY COL
	STAA	KEY	WILL UPDATE LATER; JUST TEMP SAV
	LDAB	#$00100000 ROW 5
LPROW	TBA		COPY ROW INFO TO A-REG
	ORAA	KEY	COMBINE WITH COL INFO
	STAA	KPROW,X	DRIVE KEY MATRIX
	TST	KPCOL,X	MSB LOW = CLOSURE
	BPL	ROWFND
	LSRB		NEXT LOWER ROW BIT
	BNE	LPROW	LOOP TILL ALL ROWS TRIED
	BRA	GET	KEY BOUNCED, START OVER
ROWFND	CLRA		PREPARE TO FIND BINARY ROW #
LPFND	LSRB		LOOP BUILDS BINARY ROW #
	BCS	DUNROW	WHEN BIT FALLS OFF; A-REG HAS #
	INCA
	BRA	LPFND
DUNROW	ROL	KEY
	ROLA
	ROL	KEY
	ROLA		A-REG IS 000RRRCC
* A-REG NOW CONTAINS OFFSET FOR KEY LOOK-UP
CLOP	TST	KPCOL,X	SEE IF KEY STILL DOWN
	BPL	CLOP	WAIT TILL LET UP
	JSR	DLY25	DELAY TO DEBOUNCE
	LDX	#KYTBL	POINT AT TOP OF TABLE
	JSR	ADDAX	CALC ADDR OF KEY CODE
	LDAA	,X	GET KEY CODE
	STAA	KEY	SAVE KEY VALUE
	LDAB	#1
	STAB	KYFLG	INDICATE KEY PENDING
	LDAB	PIAROW	TO CLEAR NMI
DIDDLE	RTS		** RETURN **
*
* THIS RTS IS USED AS A DO-NOTHING SUB
* SO SYST CAN BE DISABLED EXCEPT DISPLAY
*


******************************************
*
* KYTBL - KEY VALUE TABLE
*
******************************************
KYTBL	FCB	$00	'D' KEY
	FCB	$0F	'F'
	FCB	$0E	'E'
	FCB	$0D	'D'
	FCB	$01	'1'
	FCB	$02	'2'
	FCB	$03	'3'
	FCB	$0C	'C'
	FCB	$04	'4'
	FCB	$05	'5'
	FCB	$06	'6'
	FCB	$0B	'B'
	FCB	$07	'7'
	FCB	$08	'8'
	FCB	$09	'9'
	FCB	$0A	'A'
	FCB	$84	'FS' FUNCTION SET
	FCB	$85	'FC' FUNCTION CLEAR
	FCB	$86	'P/L' PUNCH/LOAD
	FCB	$87	'T/B' TRACE/BREAK
	FCB	$80	'MD' MEMORY DISPLAY
	FCB	$81	'EX' ESCAPE
	FCB	$82	'RD' REGISTER DISPLAY
	FCB	$83	'GO'
*
******************************************
*
* PUT - DISPLAYS DATA IN DISBUF & CALLS THE
*       FUNCTIONING SUBROUTINE
*
******************************************
PUT	LDAB	#%00100000	INIT DIG ENABLE PATTERN
LP1P	LDX	#DISBUF-3	POINT AT DISPLAY BUFFER
	TBA			MAKE EXTRA COPY
LP2P	INX			POINT AT NEXT DIGIT
	ASLA			ADD 1 TO 'X' FOR EACH SHIFT
	BCC	LP2P		LOOP DEVELOPS DIGIT INFO ADDR
	LDAA	,X		GET SEG INFO
	COMA			ANODE DRIVERS ARE GND TRUE
	STAA	ANOD		STORE ANODE INFO TO PIA
	STAB	CATH		ENABLE DIGIT CATHODE
	JSR	DLY1		ON FOR 1 MILISECOND
	LDAA	#%11111111	1'S TURN OFF SEGS
	STAA	ANOD		TURN OFF ALL SEGS
	STAA	CATH		ENABLE ALL KPD ROWS
	PSHB			HAS ROTATING DIGIT ENABLE
	LDX	MNPTR		GET ADDRESS OF ACTIVE MAIN PROG
	JSR	,X		EXECUTE IT
****
**** SEE MANUAL
****
	PULB			RECOVER DIGIT ENABLE
	LSRB			NEXT DIGIT
	BNE	LP1P		NOT THRU WHOLE CYCLE
	BRA	PUT
*
******************************************
*
* FUNSEL - ROUTINE TO SELECT A FUNCTION FROM A KEY INPUT
*
******************************************
FUNSEL	TST	KYFLG		KEY PENDING ?
	BNE	KEYNOW		YES, TEST IT
	RTS			** RETURN ** NO KEY PENDING
*
KEYNOW	JSR	RDKEY		GET & ACKNOWLEDGE KEY
	BMI	FUNKY		IF FUNCTION KEY
	TST	FNCFL
	BNE	UFNK
	JSR	ROLL4		# ENTRY SO ROLL IT IN
	JSR	DYSCOD		CONVERT TO 7-SEG
	LDAA	#%00000011	
	JMP	CLRDS		BLANK LAST TWO DIGITS
*
UFNK	LDX	FNCPNT		POINT AT USER FUNCTION TABLE
	BRA	HASH
*
FUNKY	LDX	#SYSFNC		POINT AT SYSTEM FUNCTION TBL
HASH	ASLA			TWO BYTES PER ENTRY
	JSR	ADDAX		DEVELOP POINTER
	LDX	,X		GET JMP ADDR
	JMP	,X		** GO THERE **
*
SYSFNC	FDB	MEMBEG		'MD'
	FDB	PROMPT		'EX'
	FDB	REGBEG		'RD'
	FDB	GO		'GO'
	FDB	FSET		'FS'
	FDB	FCLR		'FC'
	FDB	TAPBEG		'P/L'
	FDB	BRKBEG		'T/B'
*
******************************************
*
* MISC - MISC ROUTINES
*
******************************************
* DECODE HEX TO 7-SEGMENT
*
DYSCOD	PSHA			SAVE REGS
	PSHB			.
	STX	XSAV1		.
	LDX	#HEXBUF		POINT AT HEX INFO
LP01	LDAA	,X		GET HEX BYTE
	TAB			MAKE EXTRA COPY
	LSRB			RIGHT JUSTIFY HIGH NIBLE
	LSRB			.
	LSRB			.
	LSRB			HIGH ORDER DIGIT IN B-REG
	ANDA	#$0F		LOW ORDER DIGIT IN A-REG
	PSHB			SAVE ON STACK
	PSHA			.
	INX			NEXT HEX BYTE
	CPX	#HEXBUF+3	DONE ?
	BNE	LP01		LOOP 3 TIMES
	LDX	#DISBUF+5	LAST DISPLAY BUFFER DIGIT
	LDAB	#5		LOOP INDEX
LP02	STX	XTMP1		SAVE TEMPORARILY
	LDX	#DYSTBL		POINT AT LOOK-UP TABLE
	PULA			GET A HEX DIGIT TO CONVERT
	JSR	ADDAX		POINT AT 7-SEG EQUIV
	LDAA	,X		GET IT
	LDX	XTMP1		RECOVER POINTER TO DISP BUFFER
	STAA	,X		STORE CONVERTED DIG
	DEX			NEXT DISPLAY POS
	DECB			LOOP INDEX
	BPL	LP02		CONTINUE FOR 6 DIGITS
	LDX	XSAV1		RECOVER ENTRY STATUS
	PULA
	PULB
	RTS			** RETURN **
*
*
DYSTBL	FCB	%00111111	'0'
	FCB	%00000110	'1'
	FCB	%01011011	'2'
	FCB	%01001111	'3'
	FCB	%01100110	'4'
	FCB	%01101101	'5'
	FCB	%01111101	'6'
	FCB	%00000111	'7'
	FCB	%01111111	'8'
	FCB	%01100111	'9'
	FCB	%01110111	'A'
	FCB	%01111100	'B'
	FCB	%00111001	'C'
	FCB	%01011110	'D'
	FCB	%01111001	'E'
	FCB	%01110001	'F'
*
* DELAY SUBS 
*
DLY25	STX	XSAVD	SAVE X ENTRY VALUE
	LDX	#2794	25 MS ENTRY POINT
	BRA	DLYLP
DLY1	STX	XSAVD	SAVE ENTRY VAL
	LDX	#109	1 MS COUNT
	BRA	DLYLP
DLYX	STX	XSAVD	REQUIRED FOR SIMILARITY TO DLY/25
DLYLP	DEX
	BNE	DLYLP	LOOP TILL X=0
	LDX	XSAVD	RECOVER ENTRY VALUE
	RTS		** RETURN **
*
* ROUTINE TO ADD X=X+A
*
ADDAX	STX	XSAVD	TO ALLOW CALCS
	ADDA	XSAVD+1	ADD LOW BYTES   	(a = a + Xl)
	STAA	XSAVD+1	UPDATE          	(Xl = a)
	BCC	ARND	IF NO CARRY; YOU'RE DONE
	INC	XSAVD	ADD CARRY TO HIGH BYTE	(Xh = Xh +1)
ARND	LDX	XSAVD	RESULT TO X-REG		(X=[Xh,Xl])
	RTS		** RETURN **
*
* CLEAR DISPLAY PER A-REG
*
CLRDS	STX	XSAV1		SAVE ENTRY VALUE
	LDX	#DISBUF+5	RIGHTMOST DIGIT
CLRLP	LSRA
	BCC	ARNCLR		IF BIT IN A-REG NOT SET
	CLR	,X
ARNCLR	DEX			NEXT DISPLAY
	CPX	#DISBUF-1	DONE ?
	BNE	CLRLP		CONTINUE 6 TIMES
	LDX	XSAV1		RECOVER ENTRY VALUE
	RTS		** RETURN **
*
ROLL2	STX	XSAV1		SAVE ENTRY VALUE
	LDX	HEXBUF		ADDR TO ROLL
	TST	ROLPAS		FIRST PASS ?
	BEQ	ARNCL2
	CLR	ROLPAS		THIS WAS PASS 1
	CLR	,X		CLEAR LOG ON FIRST PASS
	BRA	R2OUT
ARNCL2	ASL	,X
	ASL	,X
	ASL	,X
	ASL	,X		SHIFT ROLL BYTE	4 PLACES
R2OUT	ORAA	,X		COMBINE NEW DATA
	STAA	,X		UPDATE LOC
	LDX	XSAV1		RECOVER ENTRY VALUE
	RTS			** RETURN **
*
* ROLL 4 HEX INTO HEXBUF
*
ROLL4	PSHB			SAVE ENTRY VALUES
	TST	ROLPAS		PASS 1  7
	BEQ	ARNCL4		NO, CONTINUE
	CLR	ROLPAS		YES, CLEAR FIRST PASS FLAG &
	CLR	HEXBUF		CLR FIRST 4 DIGITS ON FIRST PASS
	STAA	HEXBUF+1	THEN PUT NEW DATA IN 4TH
	BRA	R4OUT		.
ARNCL4	ASLA			LEFT JUSTIFY NEW DIGIT
	ASLA			.
	ASLA			.
	ASLA			.
	LDAB	#3		LOOP INDEX
RO4LP	ROLA			ROLLA INTO HEXBUF
	ROL	HEXBUF+1	.
	ROL	HEXBUF		.
	DECB			.
	BPL	RO4LP		.
R4OUT	PULB			RECOVER B-REG
	RTS			** RETURN **
*
RDKEY	CLR	KYFLG		READ & ACKNOWLEDGE KEY
	LDAA	KEY		.
	RTS
******************************************
*
* MEMCH - MEMORY CHANGE/DISPLAY/OFFSET ROUTINE
*
******************************************
MEMBEG	LDX	#MEMCH
	STX	MNPTR		INIT MAIN POINTER
	CLR	FNCFL		SET FUNCTION FLAG TO ZERO
	LDX	HEXBUF		POINT AT ADDR TO DISPLAY
	JMP	NEWMEM		EXIT TO UPDATE DISPLAY
*
MEMCH	TST	KYFLG		SEE IF ANY KEY PENDING
	BNE	MEMNOW
	RTS			** RETURN **
*
MEMNOW	JSR	RDKEY		GET & ACKNOWLEDGE KEY
	LDX	HEXBUF		SAVES STEPS LATER
	LDAB	FNCFL		SEE IF IN OFFSET MODE
	BEQ	NORMAL		(NOT OFFSET MODE)
	BMI	CALDUN		IF OFFSET CALC FINISHED
	TSTA			CHECK KEY
	BMI	OFFUN		IF FUNCTION KEY
	JSR	ROLL4		ENTER NUMBER KEY
OFFOUT	JSR	DYSCOD		CONVERT TO 7-SEG
OFFEND	LDX	#$0077		"A"
	STX	DISBUF+4	STORE TO LAST DIGITS
OFFRET	RTS			** RETURN **
*
OFFUN	CMPA	#$83		'GO' ?
	BNE	OFFRET		IF NOT; EXIT
	LDX	HEXBUF		GET DESTINATION OF BRANCH
	DEX			ADJ INSTEAD OF ADJ'ING THE SOURCE
	STX	HEXBUF		UPDATE
	LDAA	HEXBUF+1	LOW BYTE OF DESTINATION
	LDAB	HEXBUF		HI BYTE
	SUBA	MEMSAV+1	SUBTRACT LOW BYTES
	SBCB	MEMSAV		SUBTRACT W/ CARRY
	TSTA			CHECK POLARITY OF LOW ORDER RESULT
	BPL	ARNINC		IF LO POS DON'T INC HI
	INCB			IF LOW WAS NEG INC HI $FF - $00
ARNINC	TSTB			IF B NOW ZERO; OFFSET IS IN RANGE
	BNE	BADOFF		IF NOT; TOO FAR
	STAA	HEXBUF+2	SAVE RESULT
	JSR	DYSCOD		CONVERT	TO 7-SEG
	LDAA	#%00111100	CLEAR FIRST 4 DISPLAYS
	JSR	CLRDS
	LDAA	#$80
	STAA	FNCFL		INDICATE CALC DONE; & OK
	RTS			** RETURN **
*
BADOFF	LDX	#$BAD0		
	STX	HEXBUF
	JSR	DYSCOD		WRITE *BAD* IN FIRST 3 DISPLAYS
	LDAA	#%00000111
	JSR	CLRDS		CLEAR UNUSED DIGITS
	LDAA	#$FF
	STAA	FNCFL		INDICATE OFFSET NOT VALID
	RTS			** RETURN **
*
CALDUN	INCB			IF IT WAS $FF IT'S NOW 0
	BEQ	BADCAL		OFFSET WAS BAD
	LDX	MEMSAV		RECOVER MEM ADDR
	CMPA	#$85		FUNCTION CLEAR KEY ?
	BEQ	MEMBAK		YES, DON'T SAVE OFFSET
	CMPA	#$83		'GO' ?
	BNE	OFFRET		'GO' IS ONLY VALID KEY HERE
	LDAA	HEXBUF+2	GET CALC'D OFFSET
	STAA	,X		STORE TO MEM
	INX			ADV TO NEXT MEM ADDR
	BRA	MEMBAK		BACK TO MEM CHANGE
*
BADCAL	CMPA	#$80		'MD' ?
	BNE	OFFRET		'MD' IS THE ONLY VALID KEY HERE
	LDX	MEMSAV		RECOVER MEM ADDRESS
MEMBAK	CLR	FNCFL		SIGNAL NOT IN OFFSET MODE
	BRA	NEWMEM		RE-ENTER MEM CHANGE
*
NORMAL	TSTA			SET COND CODES
	BPL	NUM		IF NUMBER KEY
	CMPA	#$80		'MD' ?
	BNE	NXM1		NO, CHECK FOR 'GO'
	DEX			BACK UP
	BRA	NEWMEM		.
*	
NXM1	CMPA	#$83		'GO' ?
	BNE	NXM2		NO, CHECK FOR 'FS'
	INX			YES, ADVANCE
	BRA	NEWMEM		.
NXM2	CMPA	#$84		'FS' ?
	BNE	MEMOUT		NO MORE VALID KEYS
	LDAA	$%00111111
	JSR	CLRDS		.
	LDAA	#1		.
	STAA	FNCFL		SET OFFSET MODE
	STAA	ROLPAS		SET FIRST PASS
	STX	MEMSAV		SAVE MEM CHG POINTER
	JMP	OFFEND
*
NUM	JSR	ROLL2		ENTER NEW DIGIT
	BRA	MEMOUT		DON'T SET FIRST PASS
*
NEWMEM	LDAA	#1
	STAA	ROLPAS		SET FIRST PASS FLAG
*
MEMOUT	LDAA	,X		GET DATA TO DISPLAY
	STAA	HEXBUF+2	UPDATE HEX BUFFER
	STX	HEXBUF		UPDATE ADDR
	JMP	DYSCOD		CONV TO 7-SEG
*

******************************************
*
* REGDIS - REGISTER DISPLAY/CHANGE ROUTINE
*
******************************************
REGBEG	TST	FNCFL		SEE IF IN VERIFY
	BEQ	NOTVRF
	CLR	FNCFL		SIGNAL VERIFY
	JMP	LDTAP		GO VERIFY TAPE
NOTVRF	LDX	#REGDIS
	STX	MNPTR		INIT MAIN POINTER
	LDX	#PUT		SET TO RTS...
	STX	STKTOP-1	WILL BE TO PUT
	LDS	#STKTOP-2	INIT STACK POINTER
	CLR	REGNO		INTI REG # = UPC
	LDAA	#1
	STAA	ROLPAS		INDICATE FIRST PAS
	BRA	REGOUT		TO UPDATE DISPLAY
*
REGDIS	TST	KYFLG		SEE IF ANY KEY PENDING
	BNE	REGNOW
	RTS
* 
REGNOW	JSR	RDKEY		GET & ACKNOWLEDGE KEY
	BMI	REGFNC		IF FUNCTION KEY
	JSR	ROLL4
	BRA	REGOUT		UPDATE DISPLAY & EXIT
*
REGFNC	CMPA	#$80		'MD' ?
	BNE	NXR1
	LDAA	REGNO
	DECA
	BPL	ARNR1
	LDAA	#5		WRAP AROUND
ARNR1	STAA	REGNO		UPDATE
	BRA	NEWREG		SET UP NEW REG ON EXIT
*
NXR1	CMPA	#$83		'GO'
	BNE	RUNONE		IGNORE INVALID ENTRY
	LDAA	REGNO
	INCA
	CMPA	#6		PAST ?
	BNE	ARNR2		
	CLRA			WRAP AROUND
ARNR2	STAA	REGNO		UPDATE
NEWREG	LDAA	#1
	STAA	ROLPAS
*
RUNONE	CMPA	#$87		T/B KEY ?
	BNE	REGOUT		NO, RETURN
	LDX	#REGBEG		YES, SET UP RETURN ADDR
	JMP	ROI		.
*
REGOUT	LDAA	REGNO
	ASLA
	ASLA			4-BYTES PER BLOCK ENTRY
	LDX	REGTBL		TOP OF INFO TABLE
	JSR	ADDAX		POINT AT TABLE ENTRY
	LDAA	3,X		GET 7-SEG INFO
	PSHA			SAVE ON STACK
	LDAA	2,X		.
	PSHA			.
	LDX	,X		GET ADDR OF DESIRED REG
	TST	ROLPAS		SEE IF NEW REG
	BEQ	NOTNEW
	LDAA	,X		STORE CURRENT VAL TO DISPLAY
	STAA	HEXBUF		.
	LDAA	1,X		.
	STAA	HEXBUF+1	.
*
NOTNEW	JSR	DYSCOD		TO CONVERT TO 7-SEG
	PULA			RECOVER DISPLAY CODES
	STAA	DISBUF+4	& STORE TO DISP BUFFER
	PULA			.
	STAA	DISBUF+5	.
	BPL	ARNR3		.
	CLR	DISBUF		CLEAR UNUSED DISPLAYS
	CLR	DISBUF+1	.
	BRA	ONLY1		.
ARNR3	LDAA	HEXBUF		UPDATE HIGH OF PSEUDO REG
	STAA	,X		.
ONLY1	LDAA	HEXBUF+1	.
	STAA	1,X		UPDATE LOW BYTE
	RTS			** RETURN **
*
*
REGTBL	FDB	UPC
	FCB	%01110011,%00111001
*
	FDB	UA-1
	FCB	%00000000,%11110111
*
	FDB	UB-1
	FCB	%00000000,%11111100
*
	FDB	UX
	FCB	%00000110,%01011110
*
	FDB	USP
	FCB	%01101101,%01110011
*
	FDB	UCC-1
	FCB	%00111001,%10111001
* 

******************************************
*
* BRKBEG - BREAKPOINT EDITOR
*
******************************************
BRKBEG	TST	FNCFL		FUNCTION FLAG SET ?
	BNE	BRKEDT		YES, EDIT BREAKPOINTS
	RTS			NO, TAKE NO ACTION
BRKEDT	LDX	#BRKPNT		SET MNPTR WITH BREAKPOINT ROUTINE
	STX	MNPTR		.
	LDAA	#$01		SET UP FOR ADDR INPUT
	STAA	ROLPAS		.
	JMP	DISBRK		DISPLAY NEXT BKPT
BRKPNT	TST	KYFLG		KEY PENDING ?
	BNE	BRKTST		YES, DECODE KEY ?
	RTS			NO, RETURN TO PUT
BRKTST	JSR	RDKEY		GET & ACKNOWLEDGE KEY
	CMPA	#$0F		HEX ?
	BHI	NOTHEX		NO, CHECK FOR FUNCTION
	JSR	ROLL4		YES, ROLL INTO HEXBUF
	JMP	DYSCOD		DISPLAY & RETURN TO PUT
NOTHEX	CMPA	#$84		FS KEY ?
	BNE	CKFC		NO, TRY FC
	BRA	BKTOTB		YES, ENTER AS BKPT & RETURN
CKFC	CMPA	#$85		FC KEY ?
	BNE	CKGO		NO, CHECK FOR GO
	JMP	BKFMTB		YES, REMOVE A BKPT
CKGO	CMPA	#$83		GO KEY ?
	BNE	DISDUN		YES, DISPLAY NEXT BKPT & RETURN
*
* DISBRK - DISPLAY NEXT BREAKPOINT
*
DISBRK	LDAA	BRKNO		GET # INTO HEXBUF
	STAA	HEXBUF+2	ANY BREAKPOINTS ?
	BEQ	BACK		NO, RETURN
	LDX	BKPNTR		YES, DISPLAY NEXT ONE
BKLOOP	INX			.
	INX			.
	INX			.
	INX			.
	CPX	#BRKEND		END OF TAB
	BNE	NOTEND		NO, GO TEST FOR BKPT
	LDX	#BRKTAB		YES, WRAP AROUND
NOTEND	TST	3,X		BREAKPOINT ?
	BEQ	BKLOOP		NO, TRY NEXT LOC
	STX	BKPNTR		YES, MOVE POINTER
	LDX	0,X		GET BKPT ADDR
	STX	HEXBUF		& DISPLAY IT
BACK	JSR	DYSCOD		.
	TST	BRKNO		ANY BREALPOINTS ?
	BNE	DISDUN		YES, RETURN
	LDAA	#$FE		MASK ALL BUT LSD
	JSR	CLRDS		.
DISDUN	RTS			RETURN TO PUT
*
* BKTOTB-ENTER A BREAKPOINT FROM HEXBUF INTO
*	THE TABLE & UPDATEBRKNO
*
BKTOTB	JSR	FNDBRK		BREAKPOINT EXIST?
	BCS	FULL		YES, RETURN
	BSR	BKNO		FIND OPEN SPACE
	LDAA	BRKNO		GET # OF BREAKPOINTS
	CMPA	#$05		FULL ?
	BGE	FULL		YES
* CHECK FOR RAM
	LDX	HEXBUF		TEST FOR RAM
	LDAA	0,X		.
	COMA			.
	COM	0,X		.
	CMPA	0,X		RAM ?
	BNE	FULL		NO, RETURN
	COMA			YES, RESTORE DATA
	STAA	0,X		.
* ENTER BKPT INTO TABLE
	LDX	BKPNTR		POINT INTO BREAKPOINT TAB
	STAA	2,X		SAV OPCODE
	LDAA	HEXBUF		GET OP CODE ADDR
	LDAB	HEXBUF+1	.
	STAA	0,X		INSERT BREAKPOINT
	STAB	1,X		.
	INC	BRKNO		COUNT BREALPOINT
	INC	3,X		FLAG BREAKPOINT
	INC	HEXBUF+2	UPDATE BKPT NO.
	JSR	DYSCOD		.
FULL	LDAA	#$01		RESET ROLPAS
	STAA	ROLPAS		.
	RTS			& RETURN
*
* BKFMTB - REMOVE A BREAKPOINT FROM BUFFER
*	& UPDATE BRKNO
*
BKFMTB	BSR	FNDBRK		BKPT (DISBUF) IN TABLE ?
	BCC	DISBRK		NO, RETURN
	LDX	BKPNTR		YES, GET ITS ADDR
	CLR	3,X		& REMOVE IT
	CLR	2,X		REMOVE OP CODE
	DEC	BRKNO		UPDATE	COUNT
	BRA	DISBRK		DISPLAY BKPT & RETURN
*
* BKNO - FIND NUMBER OF BREAKPOINTS, UPDATE BRKNO
*	 & PUT ADDRESS OF LAST OPEN SPACE INTO BKPNTR
*
BKNO	CLR	BRKNO
	LDX	#BRKTAB
BKLOP	TST	3,X		BREAKPOINT HERE ?
	BEQ	NEXT1		NO, TRY NEXT ENTRY
	INC	BRKNO		YES, COUNT IT
	BRA	ISBKPT		SO DONT SAVE ADDR
NEXT1	STX	BKPNTR		& SAVE ADDR
ISBKPT	INX			POINT TO NEXT ENTRY
	INX			.
	INX			.
	INX			.
	CPX	#BRKEND		DONE ?
	BNE	BKLOP		NO, CONTINUE
	LDAA	#$01		RESET ROLPAS
	STAA	ROLPAS		.
	RTS			YES
******************************************
*
* INBKS - INSERT BREAKPOINTS FROM TABLE TO MEM
*
******************************************
INBKS	TST	BRKNO		BREAKPOINTS ?
	BEQ	NOBPT		NO, RETURN
	LDX	#BRKTAB		YES, INSTALL'EM
CKBKPT	TST	3,X		BREAKPOINT ?
	BEQ	NEXT2		NO, TRY NEXT ENTRY
* INSTALL THE BREAKPOINT
	STX	BKPNTR		SAVE X
	LDAA	#$3F		SWI
	LDX	0,X		GET ADDR
	LDAB	0,X		GET OP CODE
	STAA	0,X		STORE SWI
	LDX	BKPNTR		RESTORE X
	STAB	2,X		SAVE OPCODE
*	NEXT ENTRY
NEXT2	INX			.
	INX			.
	INX			.
	INX			.
	CPX	#BRKEND		DONE ?
	BNE	CKBKPT		NO, CONTINUE
NOBPT	RTS
******************************************
*
* OUTBKS - REMOVE BREAKPOINTS FROM MEMORY
*
******************************************
OUTBKS	LDX	#BRKTAB		POINT TO BREAKPOINT TAB
REMOV1	LDAA	2,X		OP CODE ?
	BEQ	NEXT3		NO, TRY NEXT ENTRY
* REMOVE BREAKPOINT FROM RAM
	STX	BKPNTR		SAVE X
	LDX	0,X		GET MEM ADDR
	STAA	0,X		INSERT OPCODE
	LDX	BKPNTR		RESTORE X
* NEXT ENTRY
NEXT3	INX			.
	INX			.
	INX			.
	INX			.
	CPX	#BRKEND		DONE ?
	BNE	REMOV1		NO, CONTINUE
	RTS			YES, RETURN
*
* FDBRK - FIND BREAKPOINT (NEXBUF) IN BRKTAB
* 	 BRKPNTR POINTS AT BREAKPOINT & CARRY
*	 IS SET IF BREAKPOINT EXISTS, ELSE C IS =R"'0"
*
FNDBRK	LDAA	HEXBUF		BREAKPOINT MSB
	LDAB	HEXBUF+1	BREAKPOINT LDB
	LDX	#BRKTAB		BREAKPOINT TAB
BRKLOP	CMPA	0,X		MATCH ?
	BEQ	CKLSB		YES
NEXT	INX			NO POINT TO NEXT
	INX			.
	INX			.
	INX			.
	CPX	#BRKEND		DONE ?
	BNE	BRKLOP		NO, CONTINUE
	CLC			YES, BUT NO BKPT
	RTS
CKLSB	CMPB	1,X		MATCH ?
	BNE	NEXT		NO, TRY NEXT ENTRY
	TST	3,X		BREAKPOINT ACTIVE ?
	BEQ	NEXT		NO TRY AGAIN
	SEC			YES, FOUND IT
	STX	BKPNTR		SAVE ADDR
	RTS
******************************************
*
* FSET - SET FUNCTION FLAG & DISPLAY "FS"
*
******************************************
FSET	LDAA	#$01		TO SET FUNCTION FLAG
	LDX	#$716S		CODE FOR "FS"
FOUT	STAA	FNCFL		
	STX	DISBUF+4	.
	RTS			RETURN TO PUT
******************************************
*
* FCLR - CLEAR FUNCTION FLAG & LAST 2 DIGITS
*
******************************************
FCLR	CLRA			TO CLEAR FUNCTION FLAG
	LDX	#$0000		TO CLEARLAST 2 DIGITS
	BRA	FOUT
******************************************
*
* TAPES - SOFTWARE CASSETE TAPE INTERFACE
*
******************************************
TAPBEG	TST	FNCFL		SEE IF PUNCH OR LOAD
	BEQ	PCH
LDTAP	JSR	LOAD		DO LOAD (OR VERF)
	JMP	PROMPT		WHEN DONE
*
PCH	LDX	#BEGEND		POINT AT BEGEND ROUTINE
	STX	MNPTR		ACTIVATE
	LDAA	#$BB
	BRA	CONOUT		DISPLAY	BB IN LAST DISPLAYS
*
BEGEND	TST	KYFLG		SEE IF KEY PENDING
	BNE	ASNOW
	RTS			** RETURN NO KEY **
*
ASNOW	JSR	RDKEY		READ & ACKNOWLEDGE KEY
	BMI	FUNK		FUNCTION KEY
	JSR	ROLL4		ENTER NEW NUMBER
	BRA	DYSOUT		CONVERT TO 7-SEG & LEAVE
*
FUNK	LDAA	#$EE
	CMPA	HEXBUF+2	END ADDR DONE ?
	BEQ	DOPCH		GO DO PUNCH
	LDX	HEXBUF		SAVE ENTERED ADDR
	STX	BEGAD		
CONOUT	STAA	HEXBUF+2	'EE' OR 'BB' TO LAST DISPLAYS
	CLR	HEXBUF		CLEAR FIRST FOUR NIBBLES
	CLR	HEXBUF+1	
DYSOUT	JMP	DYSCOD		CONV & RETURN
*
DOPCH	LDX	HEXBUF		SAVE ENTERED ADDR
	STX	ENDAD
	JSR	PUNCH		PUNCH TAPE
	JMP	PROMPT		WHEN DONE
*
******************************************
* FEDGE - ROUTINE TO LOCATE AN EDGE (POS OR NEG)
*         AND DETERMINE DISTANCE TO IT (TIME)
*		EXECUTION TIME TUNNED
******************************************
*				FOR BSR
FEDGE	LDAA	#5		START COUNT=FIXED (-1)
	LDAB	PIADP		CLEAR INTERRUPT
	NOP			DELAY
LOOPF	INCA			DURATION COUNT IN A-REG
	LDAB	PIACR		CHECK FOR EDGE FOUND
	BPL	LOOPF		IF NOT KEEP LOOKING
	EORB	#$02		INVERT EDGE SENSE CONTROL
	STAB	PIACR		PIA LOOKS FOR OTHER EDGE
	RTS			** RETURN **

******************************************
* TIN - READ 1 BYTE FROM TAPE
*       TIME TUNNED
*
******************************************
*				FOR JSR
TIN	LDAA	$FF
	STAA	BYTE		INITIALIZE BYTE
	CLR	CYCNT		
	CLR	CYCNT+1		INIT BIT-TIME COUNT
	CLR	GOOD1S		INIT LOGIC SENSE
	BSR	FEDGE		[22/21+-5] SYNC TO AN EDGE
	TST	*		DELAY
NOTSH	TST	*		DELAY
	STAA	OLD		*
	BSR	FEDGE		[22/21+-5] MEASURE TO NEXT EDGE
	CMPA	#27		<1.5 SHORT HALF ?
	BGE	NOTSH		MUST FIND SHORT FIRST
LOOPS	STAA	OLD		SAVE LAST COUNT
	BSR	FEDGE		[22/21+-5] MEASURE TO NEXT
	TAB			MAKE EXTRA COPY
	ADDB	OLD		SUM OF LAST 2
	CMPB	#43		> 2.33 NOM. SHORTS?
	BLE	LOOPS		KEEP LOOKING FOR LONG
*
* EDGE SENSE SET-UP TO SENSE TRAILING EDGES OF CYCLES
* & YOU ARE IN THE MIDDLE OF THE FIRST LONG CYCLE
*
	JMP	*+3		DELAY
	LDAB	PIADP		CLEAR	INTERRUPT FLAG
	ADDA	#5		COMPENSATE FOR PROCESSING
	BRA	SYNCIN		BRANCH INTO COUNT LOOP
LPOUT	LDAA	#0		INIT BIT TIME COUNT
	BRA	LPMID		DELAY
LPMID	CLR	CYCNT
	STAA	CYCNT+1		ESTABLISH BIT-TIME COUNT
	CLR	GOOD1S		INIT LOGIC SENSE
LPIN	LDAA	#10		FIXED TIME (-1)= INIT COUNT
LOOP1	INCA			A-REG HOLDS DURATION COUNT
SYNCIN	LDAB	PIACR		EDGE YET ?
	BPL	LOOP1		IF NOT; KEEP LOOKING
	LDAB	PIADP		CLEAR INTERRUP FLAG
	TST	*		DELAY TO MAKE PASS TIME...
	NOP			EVEN MULTIPLE OF LOOP TIME
	CMPA	#52		<1.4 SHORT ?
	BLT	SHRT
	INC	GOOD1S
	BRA	WITHIN
SHRT	DEC	GOOD1S		GOOD1S POS MEANS 0
	BRA	WITHIN		DELAY
WITHIN	LDAB	CYCNT		HIGH BYTE
	ADDA	CYCNT+1		ADD CURRENT TO BIT-TIME COUNT
	STAA	CYCNT+1		UPDATE
	ADCB	#0		ADD IN CARRY
	STAB	CYCNT		UPDATE HIGH BYTE
	BNE	CHKOVR		IF CARRY; BIT MAY BE OVER
	NOP			DELAY
	BRA	NOTOVR		BIT NOT OVER
CHKOVR	CMPA	#23		(279-245)
	BGE	BITOVR		BIT-TIME EXPIRED
NOTOVR	LDAB	#5		[38]
	DECB			*
	BPL	*-1		*
	JMP	*+3		
	BRA	LPIN
*
* END OF BIT TIME
*
BITOVR	ASL	GOOD1S		LOGIC SENSE TO CARRY
	ROR	BYTE		SHIFT NEW BIT INTO BYTE
	BCC	TINDUN		DONE WHEN START FALLS OUT
	CMPA	#93		>2.5 NOM. SHORTS ?
	BLT	LPOUT		NO; BIT-TIM STARTS AT 0
	LDAA	#36		YES; TRY MAINTAIN FRAMING
	BRA	LPMID		NEXT BIT-TIME
*
* DATA BYTE READ; CLEAN-UP AND LEAVE
*
TINDUN	LDAA	BYTE		GET CURRENT BYTE
	ADDA	CHKSM		ADD TO CHECKSUM
	STAA	CHKSM		UPDATE
	LDAA	BYTE		GET RECEIVED BYTE IN A-REG
	RTS			** RETURN **
******************************************
* BIT1 - SEND A LOGIC 1 BIT-TIME
*        LESS 177 CLOCK CYCLES
*           TIME TUNNED
******************************************
*				FOR BSR
BIT1	LDAB	#15		# SHORT H-CYCS (-1)
LOOPB1	JSR	INVRT		[20/51] TRANSMIT EDGE
	LDAA	#24		[152] 2 DELAY
	DECA			" 2
	BPL	*-1		" 4
	BRA	*+2		4 DELAY
	DECB			2 1 LESS HALF CYCLE
	BNE	LOOPB1		4 TILL 2ND EDGE
	JSR	INVRT		[20/51] 15TH EDGE IN BIT-TIME
	RTS			5 ** RETURN ** 177 CYC TO NXT
******************************************
* BIT0 - SEND A LOGIC O BIT-TIME
*        LESS 177 CLOCK CYCLES
*           TIME TUNNED
******************************************
*				FOR BSR
BIT0	LDAB	#7		2 LONG H-CYCS (-1)
LOOPB0	JSR	INVRT		[20/5] TRANSMIT EDGE
	LDAA	#56		[344] 2 DELAY
	DECA			" 2
	BPL	*-1		" 4
	NOP			2 DELAY
	DECB			2 1 LESS TO GO
	BNE	LOOPB0		4 TILL 2ND LAST EDGE
	JSR	INVRT		[20/5] 7TH EDGE IN BIT-TIME
	LDAA	#29		[182] 2 DELAY
	DECA			" 2
	BPL	*-1		" 4
	JMP	*+3		3 DELAY
	NOP			3 *
	RTS			5 ** RETURN ** 177 CYC TO NXT
******************************************
* INVRT - ROUTINE TO TRANSMIT A RISING
*         OR FALLING EDGE TO THE CASSETTE
*             TIME TUNNED
******************************************
*				FOR JSR
INVRT	LDAA	#$80		2
	EORA	PIADPB		4
	STAA	PIADPB		5 INVERT OUTPUT
	RTS			5 ** RETURN **
******************************************
* PNCHB - PUNCH 1 BITE TO TAPE, INCLUDES
*         START BIT, DATA, AND ALL BUT LAST HALF-CYCLE
*         OF STOP BITS
*                    TIME TUNNED
******************************************
*				9 FOR JSR
PNCHB	STAA	BYTE		5 SAVE BYTE TO PUNCH
	BSR	BIT0		[30/<177>] SEND START BIT
	LDAA	#9		2 # BITS IN BYTE (+2 STOP) (-1)
	STAA	NBITS		5 ESTABLISH BIT COUNT
	TST	*		6 DELAY
LPPOUT	LDAA	#19		[122] 2 DELAY
	DECA			" 2
	BPL	*-1		" 4
	SEC			2 SO LAST 2 BIT TIMES = 1 'S
	ROR	BYTE		6 LOGIC SENSE TO CARRY
	BCS	DO1		4 IF LOGIC 1
	BSR	BIT0		[30/<177>] XMIT A 0 BIT-TIME
	JMP	ENDBIT		3
DO1	BSR	BIT1		[30/<177>] XMIT A 1 BIT-TIME
	JMP	ENDBIT		3 MATCHING DELAY
ENDBIT	DEC	NBITS		6 1 LESS BIT-TIME TO GO
	BPL	LPPOUT		4 CONTINUE FOR BYTE+STOP BITS
	RTS			5 ** RETURN ** 159 CYC TO NXT
******************************************
* PUNCH - FORMAT AND PUNCH A CASSETE DATA FILE
*         INCLUDING LEADER AND CHECKSUM
*             EXECUTION TIME TUNNED
*
******************************************
*                                 9 FOR JSR
PUNCH	LDX	#840		3 COUNT FOR 30-SEC LEADER
LLOOP	LDAA	#$FF		2 LEADER CHARACTER
	LDAB	#16		[104] 2 DELAY
	DECB			* 2
	BPL	*-1		* 4
	JSR	PNCHB		[44/<159>] PUNCH A LEADER CHAR
	DEX			4
	BNE	LLOOP		4 CONTINUE FOR 30-SEC
*
* LEADER FINISHED
*
	LDAA	#'S		2 BLOCH START CHAR
	LDAB	#16		[104] 2 DELAY
	DECB			* 2
	BPL	*-1		* 4
	JSR	PNCHB		[44/<159>] PUNCH START CHAR
	NOP			2 DELAY
	CLR	CHKSM		6 INITIALIZE CHECKSUM
	LDX	#BEGAD		3 POINTAT FIRST ADDR BYTE0LT
ADLOOP	LDAA	0,X
	TAB			2 EXTRACOPY
	ADDB	CHKSM		4 ADDR IS PART OF CHECKSUM
	STAB	CHKSM		5 UPDATE
	NOP			2 DELAY
	LDAB	#13		[86] 2
	DECB			* 2
	BPL	*-1		* 4
	JSR	PNCHB		[44/<159>] PUNCH ADDR BYTE
	INX			4 ADV TO NEXT ADDR BYTE
	CPX	#BEGAD+4	3 DONE YET ?
	BNE	ADLOOP		4 CONTINUE FOR 4 ADDR CHARS
*
* READY TO PUNCH DATA
*
	NOP			2 DELAY
	NOP			2 DELAY
	LDX	BEGAD		5 GET BEG ADDR OF DATA
DLOOP	LDAA	0,X		5 GET A DATA BYTE
	TAB			2 EXTRA COPY
	ADDB	CHKSM		4 ADD TO CHKSUM
	STAB	CHKSM		5 UPDATE
	STAB	CHKSM		5 DELAY
	LDAB	#11		[74] 2
	DECB			* 2
	BPL	*-1		* 4
	JSR	PNCHB		[44/<159>] PUNCH DATA BYTE
	JMP	*+3		3 DELAY
	CPX	ENDAD		5 SEE IF DONE
	BEQ	DUNDAT		1 IF FINISHED
	INX			4 ELSE ADV TO NXT
	BRA	DLOOP		4 AND CONTINUE LOOP
*
* READY TO PUNCH CHECKSUM
*
DUNDAT	NEG	CHKSM		6 SUM INCL, CHECK WILL BE 0
	LDAA	CHKSM		4 PREPARE TO SEND
	LDAB	#20		[128] 2
	DECB			* 2
	BPL	*-1		* 4
	JSR	PNCHB		[44/<159>] PUNCH CHECKSUM
	RTS			5 ** RETURN **
******************************************
*
* LOAD - LOAD OR VERIFY A DATA FILE FROM
*        CASSETTE TAPE
*
******************************************
*				9 FOR A JSR
LOAD	JSR	TIN		[56/101+-5] READ A BYTE FROM TAPE
	CMPA	#'S		2 BLOCK START ?
	BNE	LOAD		4 NO; TRY AGAIN
*
* BLOCK START FOUND; NOW READ BEG & END ADDR AREA
*
	LDX	#BEGAD		3 POINT AR ADDR AREA
	CLR	CHKSM		6 INITIALIZE CHECKSUM
LOPAD	JSR	TIN		[56/101+-5] GET ADDR CHAR
	STAA	0,X		6 STORE RECIEVED ADDR CHAR
	INX			4 POINT AT NEXT ADDR LOC
	CPX	#BEGAD+4	3 DONE GETTING ADDR'S ?
	BNE	LOPAD		4 NO; CONTINUE
*
* READY TO READ DATA
*
	LDX	BEGAD		5 POINT TO WHERE DATA GOES
LOPDAT	JSR	TIN		[56/101+-5] GET DATA FROM TAPE
	TST	FNCFL		6 SEE IF LOAD OR VERF ?
	BEQ	VERF		4 IF NOT SET; IT'S VERF
	STAA	0,X		6 IT'S LOAD SO STORE DATA
	BRA	LOPBOT		4 GO TO BOTTOM OF LOOP
VERF	CMPA	0,X		5 JUST COMPARE TO MEM
	BNE	BAD		4 IF NON-COMPARE; SIGNAL ERROR
LOPBOT	CPX	ENDAD		5 DONE ?
	BEQ	CHKCHK		4 IF SO; CHECK CHECKSUM
	INX			4 POINT AT NEXT DATA LOC
	BRA	LOPDAT		4 AND CONTINUE LOAD/VRFY
*
* DATA FINISHED... NOW CHECK CHECSUM
*
CHKCHK	JSR	TIN		[56/105+-5] GET CHECKSUM
	TST	CHKSM
	BNE	BAD		4 IF NOT ZERO; BAD CHECKSUM
	RTS			5 ** RETURN **
*
BAD	STX	UX		6 S0 USER CAN SEE END ADDR
	STAA	UA		5 S0 USER CAN CHECK IT
	TST	FNCFL		CHECK FOR ERROR	OVERRIDE
	BPL	STOP
	RTS			** RETURN ** NO MESSAGE
*
STOP	LDX	#$7177		"FA"
	STX	DISBUF
	LDX	#$0638		"IL"
	STX	DISBUF+2
	JMP	ALTBAD		PRINT "FAIL ??"
******************************************
*
* GO - GOT TO USER PROGRAM
*
******************************************
GO	TST	ROLPAS		HEX DATA PRIOR TO 'GO'
	BNE	CONTIN		IF NOT; ASSUME UPC
	LDX	HEXBUF		GET ENTERED VALUE
	STX	UPC		STORE AS GO ADDR
CONTIN	LDX	#GO1		RETURN ADDR AFTER ROI
ROI	STX	ROIBAK		SAVE IN RAM
	LDAA	#1
	STAA	ROIFLG		SIGNAL SINGLE TRACE
	BRA	GOTO		EXIT (NO BREAKS)
* COME HERE AFTER RUNNING ONE INSTRUCTION
GO1	JSR	INBKS		INSTALL BREAKPOINTS
GOTO	LDS	USP		GET USER'S STACK POINTER
	LDAA	#$55		START TEST FOR EXISTANCE OF STK
	PSHA
	PULA
	CMPA	#$55		DID IT GO ?
	BNE	BADSTK		NO. STACK IS BAD
	LDAA	UPC+1		LOW BYTE
	PSHA			STACK FOR RTS
	LDAA	UPC		HIGH BYTE
	PSHA	
	LDAA	#$AA		SEE IF STACK STILL OK
	PSHA
	PULA
	CMPA	#$AA
	BEQ	GOEXIT		OK; FINAL EXIT SEQ
BADSTK	LDX	#$406D		MESSAGE *-DP- ??* TO 7-SEG
	STX	DISBUF
	LDX	#$7340
	STX	DISBUF+2
ALTBAD	LDX	#$5353
	STX	DISBUF+4
	LDS	#STKTOP		INIT TO GOOD AREA
	LDX	#DIDDLE		DO-NOTHING SUB
	STX	MNPTR		STORE AS MAIN PROG
	JMP	PUT		ONLY ESCAPE IS RESET OR 'EX'
*
GOEXIT	LDX	UX		RECOVER USER STATUS
	LDAB	UB
	LDAA	UA
	PSHA			TEMP SAVE ON USER STACK
	LDAA	#1
	STAA	UPROG		FLAG SIGNALS IN USER PROG
	TST	ROIFLG		TRACE EXIT ?
	BEQ	ABSOUT		IF NOT;; JUST GET GOING
	LDAA	#$3C
	STAA	PIACRA		HOLDS TRACE COUNTER RESET
	LDAA	PIAPB		READ TO CLEAR ANY INT FLAG
	LDAA	#$0E
	STAA	PIACRB		ENABLE TRACE NMI
	LDAA	#$34
	STAA	PIACRA		RELEASE TIMER
ABSOUT	LDAA	UCC		TIMED EXIT TO USER PROG
	TAP			SET USER COND CODES
	PULA			SET USER A-REG; DON'T MESS 'CC'
	RTS			*** EXIT TO USER PROG ***
*
******************************************
*
* INTERRUPTS - INTERRUPT HANDLING ROUTINES
*
******************************************
NMINT	NOP			SET IRQ FLAG
	SEI			.
	LDAA	#$04		PIA DISABLE CODE
	STAA	PIACRB		DISABLE NMI'S DURIN SERVICE
	LDAA	PIACRB		READ INT STATUS
	BPL	SAVE		IF RETURN FROM TRACE
* KEY CLOSURE CAUSED NMI
	JSR	GET		FIND AND DEBOUNCE KEY
	CMPA	#$81		'EX' ?
	BEQ	ABORT
	BSR	ENNMI		RE-ENABLE INTERRUPT
	RTI
* 'EX' KEY: PROMPT OR ABORT
ABORT	TST	UPROG		ESCAPE FROM USER PROG ?
	BNE	SAVE		IF ESCAPE FROM USER PROG
	JMP	PROMPT		*** ALREADY IN OPT-SYST ***
SAVE	STS	USP		SAVE POINTER TO USER REGS
	LDS	#STKTOP		INIT TO SYST AREA
	BSR	SVSTAT		RECOVER STATUS AT 'EX' TIME
	BSR	ENNMI		RE-ENABLE KEY NMI
	CLR	UPROG		SIGNAL NOT IN USER PROGRAM
	TST	ROIFLG		IS THIS RETURN FROM TRACE ?
	BEQ	NOTROI		IF NOT
	CLR	ROIFLG		SIGNAL NOT ROI NOW
	LDX	ROIBAK		GET RETURN ADDRESS
	JMP	0,X		AND RETURN FROM ROI
NOTROI	JMP	REGBEG		*** TO REG DISPLAY ***
*
*
ENNMI	LDAA	PIAPB		TO CLEAR FLAGS LDAA	#$07		ENABLE KEY INTERRUPT FLAGS
	STAA	PIACRB		TO PIA CONTROL REGISTER
	LDAA	#$FF	
	STAA	PIAPB		ENABLE ALL KEY ROWS
	RTS			** RETURN ** 		
*
*
SVSTAT	LDS	USP		POINT AT STACKED STATUS
	LDX	#UCC		POINT AT PSEUDO REG AREA
SVLOOP	PULA			GET STACKED BYTE
	STAA	,X		STORE AT PSEUDO REG RAM LOC
	INX			POINT AT NEXT REG LOC
	CPX	#UPC+2		PAST END ?
	BNE	SVLOOP		IF NOT CONTINUE LOOP
	STS	USP		SAVE USER SP AT AT INTERRUPT TIME
	LDS	#STKTOP-2	SET FOR RETURN
	RTS			** RETURN **
*
*
SWINT	NOP			SET IRQ FLAG
	SEI			.
	STS	USP		POINTER TO USER'S REGS
	LDS	#STKTOP		INIT TO SYST AREA
	BSR	SVSTAT		RECOVER BREAK STATUS
	LDX	UPC		BACK PROG CNTR
	DEX			.
	STX	UPC		.
	JSR	OUTBKS		TAKE OUT BREAKPOINTS
	CLR	UPROG		SIGNAL NOT IN-USER PROG
	JMP	REGBEG		*** TO REG DISPLAY ***
*
*
UIRQ	LDX	UIRQV		GET USER IRQ VECTOR
	JMP	0,X		*** GO TO USER SERVICE ROUTINE ***
*
******************************************
*
	ORG	$E419
*
* DEFS - DEFINITIONS AND SCRATCH LOCATIONS
*
******************************************
MNPTR	RMB	2		POINTER TO ACTIVE SUBROUTINE
KEY	RMB	1		KEY DATA
KYFLG	RMB	1		KEY PENDING FLAG
DISBUF	RMB	6		DISPLAY BUFFER
ROLPAS	RMB	1		FIRST PASS OF DATA ROL-ENT
XSAVD	RMB	2		X SCRATCH
XSAV1	RMB	2		.
XTMP1	RMB	2		.
MEMSAV	RMB	2		SAVE MEM POINTER DURING OFFSET CALL
HEXBUF	RMB	3		HEX INPUT BUFFER
USP	RMB	2		USER STACK POINTER
UCC	RMB	1		USER CONDITION CODE
UB	RMB	1		USER B REGISTER
UA	RMB	1		USER A REGISTER
UX	RMB	2		USER x REGISTER
UPC	RMB	2		USER PROGRAM COUNTER
ROIFLG	RMB	1		RUN-ONE-INSTRUCTION FLAG
ROIBAK	RMB	2		ADDRESS TO RETURN AFTER ROI
UPROG	RMB	1		FLAG INDICATE IN-USER-PROG
UIRQV	RMB	2		ADDR OF USER'S IRQ SERVICE ROUTINE
FNCFL	RMB	1		SPECIAL FUNCTION FLAG
FNCPNT	RMB	2		POINT TO USER'S SPECIAL FUNCTION
REGNO	RMB	1		REGISTER NUMBER (USED IN REGDIS)
BKPNTR	RMB	2		POINTS TO BREAKPOINT TABLE
BRKNO	RMB	1		# OF BREAKPOINTS IN TABLE
BRKTAB	RMB	20		BREAKPOINT TABLE
BRKEND	EQU	*		END OF TABLE 
*
* CASSETTE INTERFACE SCRATCH LOCATION
*
BYTE	RMB	1		DATA BUFFER
CYCNT	RMB	2		CYCLE COUNT REG
GOOD1S	RMB	1		# NUMBER OF GOOD 1'S
OLD	RMB	1
CHKSM	RMB	1		CHECKSUM REG
NBITS	RMB	1		
BEGAD	RMB	2		BEGGINING ADDRESS
ENDAD	RMB	2		END ADDRESS
*
PIA	EQU	$E484		SYSTEM PIA BASE ADDRESS
KPCOL	EQU	$0		KEYPAD COL PORT OFFSET
KPROW	EQU	$2		KEYPAD ROW PORT	OFFSET
ANOD	EQU	$E484		DISPLAY SEG ANODES
CATH	EQU	$E486		DISPLAY CATHODES
PIAROW	EQU	$E486		EXTENDED MODE ROW PORT ADDR
PIADPB	EQU	$E486		PIA DATA PORT B
PIACR	EQU	$E485		PIA CONTROL REG A
PIADP	EQU	$E484		PIA DATA PORT A
PIACRA	EQU	$E485		PIA CONTROL REG A
PIACRB	EQU	$E487		PIA CONTROL REG B
PIAPB	EQU	$E486		PIA DATA PORT B
STKTOP	EQU	$E47E		TOP OF SYSTEM STACK
*
* SYSTEM VECTORS
*
* ON MEK6802D5 EITHER UPPER HALF
* OF D5BUG ($F400-F7FF) MUST "MIRROR"
* INTO ADDRESSES ($FC00-FFFF) OR
* ELSE USER MUST SUPPLY PROM
* MAPPED IN ($FC00-FFFF) AREA WHICH 
* CONTAINS ALTERNATE VECTORS.
* IN THE CASE OF "MIRRORING" THE
* FOLLOWING VECTORS WOULD ALSO 
* APPEAR AT THE NORMAL 6802
* VECTOR LOCATIONS ($FFF8-FFFF)
	ORG	$F7F8
	FDB	UIRQ		USER IRQ VECTOR
	FDB	SWINT		SOFTWARE INTERRUPT VECTOR
	FDB	NMINT		NON MASKABLE INTERRUPT VECTOR
	FDB	RESET		RESTART VECTOR
	END
******************************************
