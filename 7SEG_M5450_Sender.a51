$nomod51
$include (89S52.mcu)

SOH EQU 0FAh
ETB EQU 0FBh
ACK EQU 0FCh
NAK EQU 0FDh

; DATA FORMAT
;Low Nibble bildet einen BCD Wert
;High Nibble ist als Parameter integriert
;Bit 4 kennzeichnet "Komma"
;Bit 5 kennzeichnet "Blinken"

PROG EQU RESET	;STARTING ADDRESS FOR THE PROGRAM
TastenPort EQU P1

LedTast bit P3.2
LedOK bit P3.3
LedError bit P3.4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TastRows EQU R3
tastenRamCount EQU R4
sendBufCtr EQU R5

;Variablen Deklaration
DSEG AT 48  
_50Hz_Teiler : DS 1
tastencode : DS 1
tastenPortLowNibble : DS 1
tastenRam : DS 11   ;wird auch als Sendepuffer verwendet 
sendBuf : DS 10
dlyVar : DS 2

BSEG AT 0 
_50Hz : DBIT 1
make : DBIT 1

ISEG AT 128
STACK : DS 1

CSEG AT Prog

ORG PROG + RESET     
LJMP startup    

ORG PROG + EXTI0
RETI

ORG PROG + TIMER0    ;SERVED
ljmp TIMER0_ISR

ORG PROG + EXTI1
RETI

ORG PROG + TIMER1
RETI

ORG PROG + SINT
RETI

ORG PROG + TIMER2
RETI
                              
TIMER0_ISR: ;Timer 0 Interrupt
;3900KHz @12MHZ; 3600KHz @11MHz
djnz _50Hz_Teiler, Retii  
mov _50Hz_Teiler, #78 
setb _50Hz                  

Retii:
RETI

ORG PROG + 100H 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
$include (time.a51)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                     
startup: 
mov SP, #Stack 
mov _50Hz_Teiler, #78 
clr _50Hz

 clr TR0
 mov TL0, #0
 mov TH0, #0
 mov TMOD, #00000010b  ;T0 und T1 im 8-Bit Autoreloadmodus
 setb TR0
 mov IE, #10000010b  ;T0 und Global Int. freigeben
 
;config serial port
mov scon, #01010010b ;8 Bit UART; Empfaenger freigegeben, SendeRegister ist leer       
mov RCAP2L, #0D9h ;(@9600bps AND @12MHZ RCAP2L=D9; @11MHZ RCAP2L=DC)
mov RCAP2H, #0FFh
mov T2CON, #34h  

mov TastenCode, #0FFh
clr make
mov R0, #tastenRam+0
mov tastenRamCount, #10


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;MAIN LOOP
LOOP:
jnb _50Hz, Loop
clr _50Hz
lcall Tastaturabfrage
jnb make, Loop
clr make
clr LedTast
lcall Tastenauswertung
sjmp Loop

;*****************************************************************************
;HAUPTPROGRAM ENDE************************************************************
;*****************************************************************************
Tastenauswertung:
mov A, TastenCode
cjne A, #0FFh, TastenauswertungFortsetzen
RET

TastenauswertungFortsetzen:
cjne A, #11101110b, Check_2
mov A, #1
sjmp CopyTastRamToSendBuf

Check_2:
cjne A, #11101101b, Check_3
mov A, #2
sjmp CopyTastRamToSendBuf

Check_3:
cjne A, #11101011b, Check_4
mov A, #3
sjmp CopyTastRamToSendBuf

Check_4:
cjne A, #11011110b, Check_5
mov A, #4
sjmp CopyTastRamToSendBuf

Check_5:
cjne A, #11011101b, Check_6
mov A, #5
sjmp CopyTastRamToSendBuf

Check_6:
cjne A, #11011011b, Check_7
mov A, #6
sjmp CopyTastRamToSendBuf

Check_7:
cjne A, #10111110b, Check_8
mov A, #7
sjmp CopyTastRamToSendBuf

Check_8:
cjne A, #10111101b, Check_9
mov A, #8
sjmp CopyTastRamToSendBuf

Check_9:
cjne A, #10111011b, Check_0
mov A, #9
sjmp CopyTastRamToSendBuf

Check_0:
cjne A, #01111101b, Check_Stern
mov A, #0
sjmp CopyTastRamToSendBuf

Check_Stern:       ;KOMMA
cjne A, #01111110b, Check_Raute
mov A, #','
sjmp CopyTastRamToSendBuf

Check_Raute:       ;SPACE
cjne A, #01111011b, Check_A
mov A, #10
sjmp CopyTastRamToSendBuf

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Check_A:
cjne A, #11100111b, Check_B
mov A, #'A'
sjmp ResTastBuf

Check_B:
cjne A, #11010111b, Check_C
mov A, #'B'
sjmp ResTastBuf

Check_C:
cjne A, #10110111b, Check_D
mov A, #'C'
sjmp ResTastBuf

Check_D:
cjne A, #01110111b, TastenauswertungExit
mov A, #'D'
;sjmp ResTastBuf

ResTastBuf:
mov R0, #tastenRam+0
mov @R0, A
inc R0
mov tastenRamCount, #10

TastenauswertungExit:
RET

;*****************************************************************************
CopyTastRamToSendBuf:  ;Param steht in ACC

djnz tastenRamCount, Save
mov @R0, A ; save last byte

mov tastenRamCount, #10
mov R0, #tastenRam+0

;Zum Senden vorbereiten
cjne @R0, #'A', checkB
sjmp VorbereiteZumSenden
checkB:
cjne @R0, #'B', checkC
sjmp VorbereiteZumSenden
checkC:
cjne @R0, #'C', checkD
sjmp VorbereiteZumSenden
checkD:
cjne @R0, #'D', CopyTastRamToSendBufExit

VorbereiteZumSenden:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;     
        mov R1, #sendBuf+0
        
        CopyNextToMsgRam:      
        mov A, @R0        
        mov @R1, A  
        inc R0
        mov A, @R0
        cjne A, #',', SchleifeFortsetzen
        mov A, @R1        
        setb ACC.4        
        mov @R1, A        
        inc R0
        inc R1
        djnz tastenRamCount, CopyNextToMsgRam      
        sjmp Senden   

        SchleifeFortsetzen:  
        inc R1              
        djnz tastenRamCount, CopyNextToMsgRam  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Senden:
mov tastenRamCount, #10
mov R0, #tastenRam+0

mov R1, #sendBuf+0
mov sendBuf+9, #etb
mov sendBufCtr, #11
mov A, #soh ;erstes SendByte
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;und versenden
SendNextByte:
jnb ti, $
clr ti
mov sbuf, A
mov A, @R1
inc R1
djnz sendBufCtr, SendNextByte

;auf ACK 15ms warten (1 Byte braucht 1ms @9K6)
mov dlyVar+1, #15
mov dlyVar+0, #0
Wait:
jb ri, ReadByte ;2 Zyklen
djnz dlyVar+0, Wait ;2 Zyklen
djnz dlyVar+1, Wait
sjmp CopyTastRamToSendBufExit ;Timeout

ReadByte:
mov A, sbuf
clr ri
cjne A, #ACK, CopyTastRamToSendBufExit
clr LedOK
mov A, #2
lcall F_Wait_s
setb LedOK

RET

CopyTastRamToSendBufExit:   ;Fehler signalisieren
clr LedError
mov A, #2
lcall F_Wait_s
setb LedError
RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Save:
mov @R0, A
inc R0
RET

;*****************************************************************************
Tastaturabfrage:
mov tastenPortLowNibble, #11110111b
mov TastRows, #4

TastaturAbfrage_1:
mov TastenPort, tastenPortLowNibble
mov A, TastenPort
orl A, #0Fh
cpl A
jz FetchScanRow
mov A, TastenPort
xrl A, TastenCode
jz ExitTastatur
mov TastenCode, TastenPort
setb make
RET

FetchScanRow:
mov A, tastenPortLowNibble
rr A
mov tastenPortLowNibble, A
djnz TastRows, TastaturAbfrage_1
mov TastenCode, #0FFh
setb LedTast

ExitTastatur:
RET
;****************************************************************

END