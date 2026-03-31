; ======== ITM/PRINT MODULE ========
; Description : Used for debug print
; Date : 3/31/2026
; ==================================

; ======== area definition ========
	AREA |.text|, CODE, READONLY
	EXPORT ITM_INIT
	EXPORT ITM_STRING
	EXPORT ITM_HEX
	EXPORT ITM_INT
; =================================

; ======== Constants ========
; Core Debug
DEMCR		equ 0xE000EDFC
TRACENA		equ (1 << 24)	; Enable TRACE debug system
		
; ITM Registers
ITM_LAR		equ 0xE0000FB0
ITM_TCR		equ 0xE0000E80
ITM_TER		equ 0xE0000E00
ITM_STIM0	equ 0xE0000000
		
; ITM Unlock Key
ITM_UNLOCK	equ	0xC5ACCE55
		
; ITM_TCR bits
ITMENA		equ (1 << 0) ; ITM Global Enable
SWOENA		equ (1 << 4) ; Single Wire Output Enable
; ============================

; ============ ITM_INIT ============
; Desc: Initialize ITM debug channel
; ==================================
ITM_INIT PROC
		PUSH {R11, LR}
		MOV R11, SP
		
		; Enable Trace
		LDR R0, =DEMCR
		LDR R1, [R0]
		ORR R1, R1, #TRACENA
		STR R1, [R0]

		; Unlock ITM Register
		LDR R0, =ITM_LAR
		LDR R1, =ITM_UNLOCK
		STR R1, [R0]

		; Enable ITM and SWO
		LDR R0, =ITM_TCR
		LDR R1, [R0]
		ORR R1, R1, #(ITMENA :OR: SWOENA)
		STR R1, [R0]

		; Enable ITM_STIM0
		LDR R0, =ITM_TER
		MOV R1, #1		; Enable ITM_STIM0
		STR R1, [R0]
		
		MOV SP, R11
		POP {R11, LR}
		BX LR
		ENDP
; ==================================


; ============ ITM_CHAR ============
; Desc: Send a single char over ITM
; Params: R0 = ASCII byte
; ==================================
ITM_CHAR PROC ;(R0 char)
		PUSH {R1, R2}
		
		LDR R1, =ITM_STIM0

wait_ready
		LDR R2, [R1]
		TST R2, #1
		BEQ wait_ready ; wait for ready signal
		
		STR R0, [R1] ; Send R0 char
		
		POP {R1, R2}
		BX LR
		ENDP
; ==================================


; =========== ITM_STRING ===========
; Desc  : Print a null terminated string
; Params: R0 = String start address
; ==================================
ITM_STRING PROC ; (R0 char*)
		PUSH {R4, LR} ; R4 used to save string address
		MOV R4, R0
	
string_loop
		LDRB R0, [R4]
		CMP R0, #0
		BEQ string_done
		
		BL ITM_CHAR
		
		ADD R4, R4, #1
		B string_loop
	
string_done
		POP {R4, LR}
		BX LR
		
		ENDP
; ==================================


; ============ ITM_HEX =============
; Desc: Converts and int32 to a hex
;		string and then prints it
; Params: R0 = int32
; ==================================
ITM_HEX	PROC
		; TODO : this stuff
		PUSH {R1, R2, LR}
		
		MOV R1, R0
		MOV R2, #28
		
		MOV R0, #'0'
		BL ITM_CHAR
		
		MOV R0, #'x'
		BL ITM_CHAR
		
hex_loop
		LSR R0, R1, R2
		AND R0, #0xF
		
		CMP R0, #10
		IT GE
		ADDGE R0, R0, #7
		ADD R0, R0, #0x30
		
		BL ITM_CHAR
		
		SUBS R2, R2, #4
		BGE hex_loop
		
		POP {R1, R2, LR}
		BX LR
		ENDP
; ==================================


; ============ ITM_INT =============
; Desc: Converts and int32 to a string
;		and prints it
; Params: R0 = int32
; ==================================
ITM_INT PROC ; (Print Integer R0)
		; Save previouse frame
		PUSH {R1, R2, R3, R4, R5, R11, LR} 
		MOV R11, SP
	
		; Allocate max character length aligned and clear
		SUB SP, SP, #16
		
		MOV R1, #0
		STR R1, [SP, #0]
		STR R1, [SP, #4]
		STR R1, [SP, #8]
	
		; If R0 positive
		CMP R0, #0
		BGE positive
		
		RSB R0, R0, #0
		MOV R5, #1
		B sign_done
	
positive
		MOV R5, #0
sign_done
	
		; For R1 in Range(32, 0, -1)
		MOV R1, #32
feed_loop
		LSR R3, R0, #31			; Carry in
		LSL R0, R0, #1			; Advance carry in

		MOV R4, #10
digit_loop
		LDRB R2, [SP, R4]		; Load Digit

		CMP  R2, #5				; Correct Range
		IT GE
		ADDGE R2, R2, #3

		ORR  R2, R3, R2, LSL #1	; Shift in carry bit
		
		AND  R3, R2, #0x10		; carry out
		LSR  R3, R3, #4
		
		AND  R2, R2, #0x0F		; Grab digit 0-9
		STRB R2, [SP, R4]
		
		SUBS R4, R4, #1
		BNE digit_loop
		; End For(Digit)
	
		SUBS R1, R1, #1
		BNE feed_loop
		; End For(32)

		; Print results
		MOV R1, #0
skip
		LDRB R0, [SP, R1]
		CMP R0, #0
		BNE start_int
		
		ADD R1, R1, #1
		CMP R1, #10
		BNE skip

start_int
		TST R5, #1
		BEQ int_loop
		
		MOV R0, #'-'
		BL ITM_CHAR

int_loop
		LDRB R0, [SP, R1]
		ADD R0, R0, #0x30
		
		BL ITM_CHAR
		
		ADD R1, R1, #1
		CMP R1, #11
		BNE int_loop
; End Print

		MOV SP, R11				; Restore previouse frame
		POP {R1, R2, R3, R4, R5, R11, LR}
		BX LR
		ENDP
; ==================================

		ALIGN
		END
			
; ======== END OF FILE ========