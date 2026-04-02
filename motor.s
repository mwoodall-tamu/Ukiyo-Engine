; ======== Motor Dirver ========
; Desc: Setup and use of A4988 motor
;		drivers, with bresenham MoveTo
; Date: 4/01/2026
; ==============================


; ====== A4988 Step Modes ======
; Step Mode		MS1	MS2	MS3
; Full Step		 0	 0	 0
; Half Step		 1	 0	 0
; Quarter Step	 0	 1	 0
; Eighth Step	 1	 1	 0
; Sixteenth Step 1	 1	 1
;
; Selected Mode : Half Step
; ==============================


; ==== GPIO Pin Allocation =====
; Driver 1
; STEP X = PA0
; DIR  X = PA1
;
; Driver 2
; STEP Y = PA2
; DIR  Y = PA3
;
; Both Drivers
; EN   	 = PA4
; 
; Homing
; HOME X = PA5
; HOME Y = PA6
; ==============================


; ====== Area Definition =======
	AREA |.text|, CODE, READONLY
	EXPORT MOTOR_INIT
	EXPORT HOME_MOTORS
	EXPORT MOVE_TO
; ==============================


; ========= Constants ==========
; GPIO Addresses
RCC_BASE    	EQU 0x40023800
RCC_AHB1ENR 	EQU (RCC_BASE + 0x30)
	
GPIOA_BASE  	EQU 0x40020000
GPIOA_MODER   	EQU (GPIOA_BASE + 0x00)
GPIOA_OTYPER  	EQU (GPIOA_BASE + 0x04)
GPIOA_OSPEEDR 	EQU (GPIOA_BASE + 0x08)
GPIOA_PUPDR   	EQU (GPIOA_BASE + 0x0C)
GPIOA_IDR     	EQU (GPIOA_BASE + 0x10)
GPIOA_ODR     	EQU (GPIOA_BASE + 0x14)
GPIOA_BSRR		EQU (GPIOA_BASE + 0x18)

; Delay Contants
DWT_CTRL		EQU 0xE0001000
DWT_CYCCNT		EQU 0xE0001004
CYC_PER_US		EQU 84 ; CPU is 84 MHz
	
MOTOR_DELAY		EQU 512 ; Run motors at 10-50 kHz, 512 for testing 64 for production

; Motor Constants
X_STEP_HIGH		EQU (1 << 0)
X_STEP_LOW		EQU (X_STEP_HIGH << 16)
X_FORWARD		EQU (1 << 1)
X_REVERSE		EQU	(X_FORWARD << 16)
Y_STEP_HIGH		EQU (1 << 3)
Y_STEP_LOW		EQU	(Y_STEP_HIGH << 16)
Y_FORWARD		EQU (1 << 4)
Y_REVERSE		EQU (Y_FORWARD << 16)
MOTOR_DISABLE	EQU (1 << 5)
MOTOR_ENABLE	EQU (MOTOR_DISABLE << 16)

STEP_X_MAX		EQU 10000
STEP_Y_MAX		EQU 8000

; ======== MOTOR_INIT ==========
; Desc: Initialize GPIO pin for
;		both driver boards
; ==============================
MOTOR_INIT PROC
	PUSH {R0, R1, R2}
	
	; Enable GPIO group A
	LDR R0, =RCC_BASE
	LDR R1, [R0, #0x30]		;RCC_AHB1ENR
	ORR R1, R1, #(1 << 0)	;Enable group A
	STR R1, [R0, #0x30]
	
	; Setup GPIO A pinmodes
	LDR R0, =GPIOA_MODER
	LDR R1, [R0]
	
	LDR R2, =0x3FFF			;Clear pins 0-6
	BIC R1, R1, R2
	LDR R2, =0x0155			;Set pins 0-4 as output and 5-6 and input
	ORR R1, R1, R2
	
	STR R1, [R0]
	
	; Setup GPIO A pull-up
	LDR R0, =GPIOA_PUPDR
	LDR R1, [R0]
	
	LDR R2, =0x3C00			;Clear pin 5-6
	BIC R1, R1, R2
	LDR R2, =0x1400			;Set pin 5-6 and pull-up
	ORR R1, R1, R2
	
	STR R1, [R0]
	
	; Reset motors
	LDR R0, =GPIOA_ODR
	MOV R1, #0x10
	STR R1, [R0]
	
	; Enable DWT_CYCCNT
	LDR R0, =DWT_CTRL
	LDR R1, [R0]
	ORR R1, R1, #1
	STR R1, [R0]
	
	; Clear DWT_CYCCNT
	LDR R0, =DWT_CYCCNT
	MOV R1, #0
	STR R1, [R0]
	
	POP {R0, R1, R2}
	BX LR
	ENDP
; ==============================


; =========== DELAY ============
; Desc: Busy wait delay function
; Params: R0 delay amount
; ==============================
DELAY PROC
	PUSH {R1, R2, R3}
	
	LDR R1, =CYC_PER_US
	MUL R0, R0, R1
	
	;Find end cycle
	LDR R1, =DWT_CYCCNT
	LDR R2, [R1]
	
delay_loop
	LDR R3, [R1]
	SUB R3, R3, R2
	CMP R3, R0
	BLO delay_loop
	
	POP {R1, R2, R3}
	BX LR
	ENDP
; ==============================


; ======== HOME_MOTORS =========
; Desc: Move the motors to (0, 0)
;		So they know where they are
; Iternal:
; R0 : Delay us
; R1 : ODR
; R2 : IDR
; R3 : ODR Write value
; ==============================
HOME_MOTORS PROC
	PUSH {R0, R1, R2, R3, LR}
	
	;Initial values / motor enable
	MOV R0, #1024
	LDR R1, =GPIOA_BSRR
	LDR R2, =GPIOA_IDR
	LDR R3, =(MOTOR_ENABLE :OR: X_REVERSE :OR: Y_REVERSE)
	STR R3, [R1]
	
HOME_X_LOOP
	LDR R3, [R2]
	TST R3, #(1 << 5)
	BEQ END_HOME_X
	
	LDR R3, =X_STEP_HIGH
	STR R3, [R1]
	BL DELAY
	
	LDR R3, =X_STEP_LOW
	STR R3, [R1]
	BL DELAY
	
	B HOME_X_LOOP
END_HOME_X

HOME_Y_LOOP
	; Check homing switch PA6
	LDR R3, [R2]
	TST R3, #(1 << 6)
	BEQ END_HOME_Y
	
	LDR R3, =Y_STEP_HIGH
	STR R3, [R1]
	BL DELAY
	
	LDR R3, =Y_STEP_LOW
	STR R3, [R1]
	BL DELAY
	
	B HOME_Y_LOOP
END_HOME_Y
	
	;Motor Disable
	LDR R1, =GPIOA_BSRR
	LDR R3, =MOTOR_DISABLE
	STR R3, [R1]
	
	POP {R0, R1, R2, R3, LR}
	BX LR
	ENDP
; ==============================


; ========== MOVE_TO ===========
; Desc: Move the motors to a new
;		position using bresenham
; Params: R0 = X0, R1 = Y0
;		  R2 = X1, R3 = Y1
; Internal:
; 	R0 : Scratch / Delay
; 	R1 : BSRR
; 	R2 : x0, R3 : y0
; 	R4 : x1, R5 : y1
; 	R6 : dx, R7 : dy
; 	R8 : sx, R9 : sy
;	R10: D
; ==============================
MOVE_TO PROC
	PUSH {R4, R5, R6, R7, R8, R9, R10, LR}
	
	MOV R2, R0
	MOV R3, R1
	MOV R4, R2
	MOV R5, R3
	
	LDR R1, =GPIOA_BSRR
	LDR R0, =MOTOR_ENABLE
	
	SUBS R6, R4, R2
	MOVEQ R8, #0
	ITT GE
	MOVGE R8, #1
	ORRGE R0, #X_FORWARD
	ITTT LT
	MOVLT R8, #-1
	RSBLT R6, R6, #0 ; dx = abs(dx)
	ORRLT R0, #X_REVERSE
	
	SUBS R7, R5, R3
	MOVEQ R9, #0
	ITT GE
	MOVGE R9, #1
	ORRGE R0, #Y_FORWARD
	ITTT LT
	MOVLT R9, #-1
	RSBLT R7, R7, #0 ; dy = abs(dy)
	ORRLT R0, #Y_REVERSE
	
	STR R0, [R1]
	
	CMP R6, R7
	IT GE
	RSBGE R10, R6, R7, LSL #1
	IT LT
	RSBLT R10, R7, R6, LSL #1
	BLT LINE_Y_LOOP
	
LINE_X_LOOP
	CMP R10, #0
	MOV R0, #0
	
	; if D > 0
	ITTTT GT
	ADDGT R3, R3, R9 ; Step Motor Y
	ADDGT R10, R10, R7, LSL #1
	SUBGT R10, R10, R6, LSL #1
	ORRGT R0, #Y_STEP_HIGH
	; else
	IT LE
	ADDLE R10, R10, R7, LSL #1
	; end if
	
	; step motors
	ORR R0, #X_STEP_HIGH
	STR R0, [R1]
	
	MOV R0, #MOTOR_DELAY
	BL DELAY
	
	MOV R0, #(X_STEP_LOW :OR: Y_STEP_LOW)
	STR R0, [R1]
	
	MOV R0, #MOTOR_DELAY
	BL DELAY
	
	ADD R2, R2, R8 ; Step Motor X
	CMP R2, R4
	BNE LINE_X_LOOP
	B END_LINE
	
LINE_Y_LOOP
	CMP R10, #0
	MOV R0, #0
	
	ITTTT GT
	ADDGT R2, R2, R8 ; step x motor
	ADDGT R10, R10, R6, LSL #1
	SUBGT R10, R10, R7, LSL #1
	ORRGT R0, #X_STEP_HIGH
	
	IT LE
	ADDLE R10, R10, R6, LSL #1
	
	ORR R0, #Y_STEP_HIGH
	STR R0, [R1]
	
	MOV R0, #MOTOR_DELAY
	BL DELAY
	
	MOV R0, #(X_STEP_LOW :OR: Y_STEP_LOW)
	STR R0, [R1]

	MOV R0, #MOTOR_DELAY
	BL DELAY

	ADD R3, R3, R9 ; Step Motor Y
	CMP R3, R5
	BNE LINE_Y_LOOP
	
END_LINE

	MOV R0, #MOTOR_DISABLE
	STR R0, [R1]
	
	POP {R4, R5, R6, R7, R8, R9, R10, LR}
	BX LR
	ENDP
; ==============================


; ======== END_OF_FILE =========

	ALIGN
	END

; ==============================