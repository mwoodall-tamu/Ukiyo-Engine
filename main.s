;========================
; ESET 349 Final Project
; Ukiyo-Engine
;
; Authors:
; David Castro
; Matthew Woodall
; 
; Date : 4/20/2026
; Version : 1.0.0
;========================
	
	AREA |.text|, CODE, READONLY
		
	IMPORT ITM_INIT
	IMPORT ITM_STRING
	IMPORT ITM_HEX
	IMPORT ITM_INT
		
	EXPORT __main
	
		
__main PROC
		BL ITM_INIT

		LDR R0, =0xDEADBEEF
		BL ITM_HEX
		
		MOV R0, R0
			
		ENDP
		END