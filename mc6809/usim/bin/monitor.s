uart		equ	$c000
system_stack	equ	$0200
user_stack	equ	$0400
vector_table	equ	$fff0
rom_start	equ	$e000

;
;		Start of System ROM
;
		org	rom_start

handle_reset	lds	#system_stack
		ldu	#user_stack
		andcc	#$f0
		orcc	#$60
		ldx	#system_ready
		lbsr	putstr

showprompt	ldx	#prompt
		lbsr	putstr

loop		lbsr	getchar
		lbsr	toupper
		lbsr	putchar
		cmpa	#$0a
		beq	showprompt
		bra	loop

package_io

putstr		pshs	a,x,cc
putstr_loop	lda	,x+
		beq	putstr_done
		bsr	putchar
		bra	putstr_loop
putstr_done	puls	a,x,cc
		rts

puthexbyte	pshs	cc
		rora
		rora
		rora
		rora
		bsr	puthexdigit
		rora
		rora
		rora
		rora
		rora
		bsr	puthexdigit
		puls	cc
		rts

puthexdigit	pshs	a,cc
		anda	#$0f
		adda	#$30
		cmpa	#$39
		ble	_puthexdigit1
		adda	#$27
_puthexdigit1	bsr	putchar
		puls	a,cc
		rts

putchar		sta	uart
		rts

getchar		lda	uart
		rts

package_str

toupper		pshs	cc
		cmpa	#$61
		bmi	toupper_done
		cmpa	#$7a
		bhi	toupper_done
		suba	#$20
toupper_done	puls	cc
		rts

tolower		pshs	cc
		cmpa	#$41
		bmi	tolower_done
		cmpa	#$5a
		bhi	tolower_done
		adda	#$20
tolower_done	puls	cc
		rts

prompt		string	"> \0"
system_ready	string	"System loaded and ready\012\0"

handle_undef	rti

handle_swi
handle_swi2
handle_swi3
handle_nmi	rti

;
;		System vector specification
;
		org	vector_table
		dw	handle_undef	; $fff0
		dw	handle_swi3	; $fff2
		dw	handle_swi2	; $fff4
		dw	handle_undef	; $fff6
		dw	handle_undef	; $fff8
		dw	handle_swi	; $fffa
		dw	handle_nmi	; $fffc
		dw	handle_reset	; $fffe

handle_reset	end
