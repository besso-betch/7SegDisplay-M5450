$nomod51
$include (89S8253.mcu)

SOH EQU 0FAh
ETB EQU 0FBh
ACK EQU 0FCh
NAK EQU 0FDh

eemen EQU 00001000b
eemwe EQU 00010000b
eeld  EQU 00100000b

DataIn  bit P1.0
Clock bit P1.1
DataIn_1  bit P1.2    ;Second M5450
Clock_1 bit P1.3

llPort EQU P2
ScanPort EQU P2

; DATA FORMAT
;Low Nibble bildet einen BCD Wert
;High Nibble ist als Parameter integriert
;Bit 4 kennzeichnet "Komma"
;Bit 5 kennzeichnet "Blinken"

PROG EQU RESET	;STARTING ADDRESS FOR THE PROGRAM

inBufCount EQU 10
byteCtr EQU R3 ;wird in Empfangsroutine verwendet(uart.a51)
Row EQU R2

;Variablen Deklaration
DSEG AT 48  
msgRam : DS 32
driverRam : DS 8
driverRamTemp : DS 4
_200Hz_Teiler : DS 1

bitCtr : DS 1
copyCtr : DS 1
KommaChecker : DS 1
animChar : DS 1
LEDmuster : DS 1
llTimer : DS 1
_7segMuster : DS 2
temp1 : DS 1
answerToPC : DS 1
inBuf : DS 10 ;1 AddrField  +   8Digits +  1ETB

BSEG AT 0 
_200Hz : DBIT 1

blink : DBIT 1 
llDirection : DBIT 1
TransferComplete : DBIT 1

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

ORG PROG + SINT       ;SERVED
ljmp uart_isr

ORG PROG + TIMER2
RETI
                              
TIMER0_ISR: ;Timer 0 Interrupt
;3900KHz @12MHZ; 3600KHz @11MHz
djnz _200Hz_Teiler, Retii     ;200Hz Teiler
mov _200Hz_Teiler, #18
setb _200Hz          

Retii:
RETI

ORG PROG + 100H 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
$include (uart.a51)
$include (time.a51)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                     
startup: 
mov ScanPort, #0
mov SP, #Stack 

;von eeprom laden
        orl eecon, #eemen ;eeprom einschalten             
        mov R1, #msgRam+0        
        mov dptr, #0 ; zeiger auf eeprom adresse        
        mov byteCtr, #32        

LoadByte:              
        movx A, @DPTR
        mov @R1, A       
        inc R1        
        inc dptr        
        djnz byteCtr, LoadByte               
        xrl eecon, #eemen ;eeprom auschalten           

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
mov row,#11h    ;row1
mov _200Hz_Teiler, #18
clr  _200Hz 

lcall PrepareDataReception 
lcall init_uart_intr

 mov TL0, #0
 mov TH0, #0
 mov TMOD, #00000010b  ;T0 im 8-Bit Autoreloadmodus
 setb TR0
 mov IP, #00010000b ;Prioritaet fuer Serial Port
 mov IE, #10010010b  ;T0, ES, und EA Interrupt freigeben
 
 mov animChar, #10000000b
 mov copyCtr, #24
 lcall AnimDisp  ;Dauert ca. 6 Sekunden
 mov ScanPort, #0
 
 mov LEDmuster, #01111111b
 mov llTimer, #5
 mov _7segMuster+1, #00000100b
 mov _7segMuster+0, #1000000b
 mov temp1, #2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;MAIN LOOP
LOOP:
jnb _200Hz, Loop
clr _200Hz
lcall Display
sjmp Loop

;*****************************************************************************
;HAUPTPROGRAM ENDE************************************************************
;*****************************************************************************
;Hier muessen 35 Bit herausgeschoben werden + 1 Bit fuer den Start
Display:
anl ScanPort, #00000000b
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;0
cjne row, #11h, checkRow1
mov driverRamTemp+0, msgRam+0
mov driverRamTemp+1, msgRam+4
mov driverRamTemp+2, msgRam+8
mov driverRamTemp+3, msgRam+12
lcall getPat
mov driverRam+0, driverRamTemp+0
mov driverRam+1, driverRamTemp+1
mov driverRam+2, driverRamTemp+2
mov driverRam+3, driverRamTemp+3

mov driverRamTemp+0, msgRam+16
mov driverRamTemp+1, msgRam+20
mov driverRamTemp+2, msgRam+24
mov driverRamTemp+3, msgRam+28
lcall getPat
mov driverRam+4, driverRamTemp+0
mov driverRam+5, driverRamTemp+1
mov driverRam+6, driverRamTemp+2
mov driverRam+7, driverRamTemp+3
LJMP M5450

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;1
checkRow1:
cjne row, #22h, checkRow2
mov driverRamTemp+0, msgRam+1
mov driverRamTemp+1, msgRam+5
mov driverRamTemp+2, msgRam+9
mov driverRamTemp+3, msgRam+13
lcall getPat
mov driverRam+0, driverRamTemp+0
mov driverRam+1, driverRamTemp+1
mov driverRam+2, driverRamTemp+2
mov driverRam+3, driverRamTemp+3

mov driverRamTemp+0, msgRam+17
mov driverRamTemp+1, msgRam+21
mov driverRamTemp+2, msgRam+25
mov driverRamTemp+3, msgRam+29
lcall getPat
mov driverRam+4, driverRamTemp+0
mov driverRam+5, driverRamTemp+1
mov driverRam+6, driverRamTemp+2
mov driverRam+7, driverRamTemp+3
LJMP M5450

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;2
checkRow2:
cjne row, #44h, checkRow3
mov driverRamTemp+0, msgRam+2
mov driverRamTemp+1, msgRam+6
mov driverRamTemp+2, msgRam+10
mov driverRamTemp+3, msgRam+14
lcall getPat
mov driverRam+0, driverRamTemp+0
mov driverRam+1, driverRamTemp+1
mov driverRam+2, driverRamTemp+2
mov driverRam+3, driverRamTemp+3

mov driverRamTemp+0, msgRam+18
mov driverRamTemp+1, msgRam+22
mov driverRamTemp+2, msgRam+26
mov driverRamTemp+3, msgRam+30
lcall getPat
mov driverRam+4, driverRamTemp+0
mov driverRam+5, driverRamTemp+1
mov driverRam+6, driverRamTemp+2
mov driverRam+7, driverRamTemp+3
LJMP M5450

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;3
checkRow3:
cjne row, #88h, DisplayExit
mov driverRamTemp+0, msgRam+3
mov driverRamTemp+1, msgRam+7
mov driverRamTemp+2, msgRam+11
mov driverRamTemp+3, msgRam+15
lcall getPat
mov driverRam+0, driverRamTemp+0
mov driverRam+1, driverRamTemp+1
mov driverRam+2, driverRamTemp+2
mov driverRam+3, driverRamTemp+3

mov driverRamTemp+0, msgRam+19
mov driverRamTemp+1, msgRam+23
mov driverRamTemp+2, msgRam+27
mov driverRamTemp+3, msgRam+31
lcall getPat
mov driverRam+4, driverRamTemp+0
mov driverRam+5, driverRamTemp+1
mov driverRam+6, driverRamTemp+2
mov driverRam+7, driverRamTemp+3


LJMP M5450

DisplayExit:
RET
;;;;;;;;;;;;;;;************************************************
M5450:

clr clock
setb DataIN ;Startbit  wird reingecklockt
setb clock 
clr clock

mov A, driverRam+0
mov bitCtr, #8
lcall OutputData

mov A, driverRam+1
mov bitCtr, #8
lcall OutputData

mov A, driverRam+2
mov bitCtr, #8
lcall OutputData

mov A, driverRam+3
mov bitCtr, #8
lcall OutputData

mov bitCtr, #3  ;Ist egal was hier steht (in DPTR)                                                                             
lcall OutputData

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;,,,
clr clock_1
setb DataIN_1 ;Startbit  wird reingecklockt
setb clock_1 
clr clock_1

mov A, driverRam+4
mov bitCtr, #8
lcall OutputData_1

mov A, driverRam+5
mov bitCtr, #8
lcall OutputData_1

mov A, driverRam+6
mov bitCtr, #8
lcall OutputData_1

mov A, driverRam+7
mov bitCtr, #8
lcall OutputData_1

mov bitCtr, #3  ;Ist egal was hier steht (in DPTR)                                                                             
lcall OutputData_1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;,,,
mov A, row
orl ScanPort, A 
rl A
mov row, A 
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OutputData:
rlc A
mov dataIN, C
setb clock      ;Takt Begin
clr clock      ;Takt Ende
djnz bitCtr, OutputData
RET

OutputData_1:
rlc A
mov dataIN_1, C
setb clock_1      ;Takt Begin
clr clock_1      ;Takt Ende
djnz bitCtr, OutputData_1
RET

;******************************************************************************
getPat:
mov A, driverRamTemp+0 
mov KommaChecker, A
anl A, #00001111b
add A, #_7Seg_Table-$-3
movc a, @a+pc
mov driverRamTemp+0, A 

mov A, KommaChecker
jnb ACC.5, LoadPat0
jnb blink, LoadPat0
mov driverRamTemp+0, #0         
ljmp GetPat1
LoadPat0:
jnb ACC.4, getPat1
mov A, driverRamTemp+0
setb ACC.0
mov driverRamTemp+0, A

GetPat1:
mov A, driverRamTemp+1 
mov KommaChecker, A
anl A, #00001111b  
add A, #_7Seg_Table-$-3
movc a, @a+pc
mov driverRamTemp+1, A  

mov A, KommaChecker
jnb ACC.5, LoadPat1
jnb blink, LoadPat1
mov driverRamTemp+1, #0
ljmp GetPat2

LoadPat1:
jnb ACC.4, getPat2
mov A, driverRamTemp+1
setb ACC.0
mov driverRamTemp+1, A

GetPat2:
mov A, driverRamTemp+2  
mov KommaChecker, A
anl A, #00001111b
add A, #_7Seg_Table-$-3
movc a, @a+pc 
mov driverRamTemp+2, A 

mov A, KommaChecker
jnb ACC.5, LoadPat2
jnb blink, LoadPat2
mov driverRamTemp+2, #0
ljmp GetPat3

LoadPat2:
jnb ACC.4, getPat3
mov A, driverRamTemp+2
setb ACC.0
mov driverRamTemp+2, A

GetPat3:
mov A, driverRamTemp+3 
mov KommaChecker, A
anl A, #00001111b
add A, #_7Seg_Table-$-3
movc a, @a+pc 
mov driverRamTemp+3, A 

mov A, KommaChecker
jnb ACC.5, LoadPat3
jnb blink, LoadPat3
mov driverRamTemp+3, #0
ljmp GetPatExit

LoadPat3:
jnb ACC.4, getPatExit
mov A, driverRamTemp+3
setb ACC.0
mov driverRamTemp+3, A

getPatExit:
cjne row, #44h, getPatExit1 
mov A, msgRam+6
cjne A, #10, getPatExit1  
mov driverRamTemp+1, _7segMuster+1
mov driverRamTemp+2, _7segMuster+0

getPatExit1:
RET     

;7 Segment LookUp Table
_7Seg_Table:
db 11111100b ;0
db 01100000b ;1
db 11011010b ;2
db 11110010b ;3
db 01100110b ;4
db 10110110b ;5
db 10111110b ;6
db 11100000b ;7
db 11111110b ;8
db 11110110b ;9
db 00000000b ;blank

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UpdateTimer:
djnz llTimer, ExitUpdateTimer
mov llTimer, #5
cpl llDirection

jb llDirection, changeLedPattern
mov ledMuster, #01111111b
RET

changeLedPattern:
mov ledMuster, #00111111b

ExitUpdateTimer:
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AnimDisp:
clr clock
setb DataIN ;Startbit  wird reingecklockt
setb clock 
clr clock

mov A, animChar
mov bitCtr, #8
lcall OutputData

mov A, animChar
mov bitCtr, #8
lcall OutputData

mov A, animChar
mov bitCtr, #8
lcall OutputData

mov A, animChar
mov bitCtr, #8
lcall OutputData

mov bitCtr, #3  ;Ist egal was hier steht (in DPTR)                                                                             
lcall OutputData
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;,,,
clr clock_1
setb DataIN_1 ;Startbit  wird reingecklockt
setb clock_1 
clr clock_1

mov A, animChar
mov bitCtr, #8
lcall OutputData_1

mov A, animChar
mov bitCtr, #8
lcall OutputData_1

mov A, animChar
mov bitCtr, #8
lcall OutputData_1

mov A, animChar
mov bitCtr, #8
lcall OutputData_1

mov bitCtr, #3  ;Ist egal was hier steht (in DPTR)                                                                             
lcall OutputData_1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

mov ScanPort, #0FFh
mov A, #100
lcall F_wait_m

mov A, animChar
rr A
mov animChar, A

djnz copyCtr, AnimDisp

RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Lauflicht:
mov A, ledMuster

jb llDirection, RotateLeft
rr A
mov llPort, A
mov ledMuster, A
RET

RotateLeft:
rl A
mov llPort, A
mov ledMuster, A
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
AnimSmS:
djnz temp1, ExitAnimSmS
 mov A, _7segMuster+1
 rl A
 cjne A, #00000001b, saveAnimSmS1 
 mov A, #00000100b
 saveAnimSmS1: 
 mov _7segMuster+1, A
 
 mov A, _7segMuster+0
 rr A
 cjne A, #00000010b, saveAnimSmS0 
 mov A, #10000000b
 saveAnimSmS0:
 mov _7segMuster+0, A
 
 mov temp1, #3

ExitAnimSmS:
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SaveToEeprom:
        orl eecon, #eemen ;eeprom einschalten        
        orl eecon, #eemwe ;schreiben in eeprom ermöglichen        
        orl eecon, #eeld ;zuerst nur laden(page write ermöglichen)        

        mov R1, #msgRam+0        
        mov dptr, #0 ; zeiger auf eeprom adresse        
        mov byteCtr, #31        

SaveToEeprom1:
        mov A, @R1        
        movx @dptr, A        
        inc R1        
        inc dptr        
        djnz byteCtr, SaveToEeprom1        
        xrl eecon, #eeld        
        mov A, @R1        
        movx @dptr, A         
        mov A, #5     ;5 ms auf schreibende warten   
        lcall F_wait_m                                    
        xrl eecon, #eemwe ;schreiben in eeprom abschalten          
        xrl eecon, #eemen ;eeprom auschalten  

RET
END