UART_ISR:
	push	psw
	push	acc
	
	setb RS0 ; Select Registerbank #1
	jb  ti, xmit             
        clr ri
      
        mov a, sbuf        

        cjne A, #SOH, DatenEmpfangen                       
        lcall PrepareDataReception    ;Datenempfang vorbereiten   
        pop	acc
	pop	psw
	RETI

DatenEmpfangen:    
        djnz byteCtr, SaveData        
        mov @R0, A  ;letztes Byte(ETB)
        ;Abschlussroutine  
        cjne A, #ETB, SendNAK         
        ;Hier inBuf nach msgRam kopieren        
        mov byteCtr, #8          
        mov R0, #inBuf+1 ;ABCD überspringen        
             
        mov A, inBuf+0
        cjne A, #'A', check_B
        mov R1, #msgRam+0
        sjmp CopyNextToMsgRam
        
        check_B:
        cjne A, #'B', check_C
        mov R1, #msgRam+8
        sjmp CopyNextToMsgRam
        
        check_C:
        cjne A, #'C', check_D
        mov R1, #msgRam+16
        sjmp CopyNextToMsgRam
        
        check_D:
        cjne A, #'D', SendNAK
        mov R1, #msgRam+24
        
CopyNextToMsgRam:
        mov A, @R0        
        mov @R1, A        
        inc R0
        inc R1
        djnz byteCtr, CopyNextToMsgRam      
        lcall SaveToEeprom     
                  
        mov answerToPC, #ACK          
        sjmp SendAnswer

SendNAK:   
        mov answerToPC, #NAK           

SendAnswer:               
        clr TransferComplete
        setb ti 
        pop	acc
	pop	psw
	RETI

SaveData:
        mov @R0, A        
        inc R0
	pop	acc
	pop	psw
	RETI


;;;;;;;;;;;;;;;;;;;;,,
xmit:
jnb TransferComplete, xmit2
clr ti
pop acc
pop psw
RETI

xmit2:
clr ti
mov sbuf, answerToPC
setb TransferComplete
pop acc
pop psw
RETI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PrepareDataReception:
mov R0, #inBuf+0
mov byteCtr, #inBufCount
PrepareDataReception_1:
mov @R0, #0
inc R0
djnz byteCtr, PrepareDataReception_1
mov R0, #inBuf+0
mov byteCtr, #inBufCount
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init_uart_intr:       
        mov scon, #01010000b        ;config serial port (ri and ti cleared)        
        mov RCAP2L, #0D9h ;(@9600bps AND @12MHZ RCAP2L=D9; @11MHZ RCAP2L=DC)
        mov RCAP2H, #0FFh
        mov T2CON, #34h   
RET