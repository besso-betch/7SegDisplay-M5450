$nomod51
$include (89S8253.mcu)

SOH EQU 0FAh
ETB EQU 0FBh
ACK EQU 0FCh
NAK EQU 0FDh

eemen EQU 00001000b
eemwe EQU 00010000b
eeld  EQU 00100000b

DataEnable bit P1.0
DataIn  bit P1.1
Clock bit P1.2

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
driverRam : DS 4
_400Hz_Teiler : DS 1

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
_400Hz : DBIT 1

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
djnz _400Hz_Teiler, Retii     ;400Hz Teiler
mov _400Hz_Teiler, #8
setb _400Hz          

Retii:
RETI

ORG PROG + 100H 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
$include (uart.a51)
$include (time.a51)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;                     
startup: 
clr DataEnable
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
mov row,#00000001b    ;row1
mov _400Hz_Teiler, #9
clr  _400Hz 

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
jnb _400Hz, Loop
clr _400Hz
lcall Display
sjmp Loop

;*****************************************************************************
;HAUPTPROGRAM ENDE************************************************************
;*****************************************************************************
;Hier muessen 35 Bit herausgeschoben werden + 1 Bit fuer den Start
Display:
anl ScanPort, #00000000b
cjne row, #1, checkRow1
mov driverRam+0, msgRam+0
mov driverRam+1, msgRam+8
mov driverRam+2, msgRam+16
mov driverRam+3, msgRam+24
lcall getPat
ljmp M5450

checkRow1:
cjne row, #2, checkRow2
mov driverRam+0, msgRam+1
mov driverRam+1, msgRam+9
mov driverRam+2, msgRam+17
mov driverRam+3, msgRam+25
lcall getPat
ljmp M5450

checkRow2:
cjne row, #4, checkRow3
mov driverRam+0, msgRam+2
mov driverRam+1, msgRam+10
mov driverRam+2, msgRam+18
mov driverRam+3, msgRam+26
lcall getPat
ljmp M5450

checkRow3:
cjne row, #8, checkRow4
mov driverRam+0, msgRam+3
mov driverRam+1, msgRam+11
mov driverRam+2, msgRam+19
mov driverRam+3, msgRam+27
lcall getPat
ljmp M5450
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
checkRow4:
cjne row, #16, checkRow5
mov driverRam+0, msgRam+4
mov driverRam+1, msgRam+12
mov driverRam+2, msgRam+20
mov driverRam+3, msgRam+28
lcall getPat
ljmp M5450

checkRow5:
cjne row, #32, checkRow6
mov driverRam+0, msgRam+5
mov driverRam+1, msgRam+13
mov driverRam+2, msgRam+21
mov driverRam+3, msgRam+29
lcall getPat
ljmp M5450

checkRow6:
cjne row, #64, checkRow7
mov driverRam+0, msgRam+6
mov driverRam+1, msgRam+14
mov driverRam+2, msgRam+22
mov driverRam+3, msgRam+30
lcall getPat
ljmp M5450

checkRow7:
cjne row, #128, DisplayExit
mov driverRam+0, msgRam+7
mov driverRam+1, msgRam+15
mov driverRam+2, msgRam+23
mov driverRam+3, msgRam+31
lcall getPat
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
mov A, row
orl ScanPort, A
rl A
mov row, A 

cjne A, #00000001b, DisplayExit
mov row, #00000001b
DisplayExit:
RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OutputData:
rlc A
mov dataIN, C
setb clock      ;Takt Begin
clr clock      ;Takt Ende
djnz bitCtr, OutputData
RET

;******************************************************************************
getPat:
mov A, driverRam+0 
mov KommaChecker, A
anl A, #00001111b
add A, #_7Seg_Table-$-3
movc a, @a+pc
mov driverRam+0, A 

mov A, KommaChecker
jnb ACC.5, LoadPat0
jnb blink, LoadPat0
mov driverRam+0, #0
ljmp GetPat1
LoadPat0:
jnb ACC.4, getPat1
mov A, driverRam+0
setb ACC.0
mov driverRam+0, A

GetPat1:
mov A, driverRam+1 
mov KommaChecker, A
anl A, #00001111b  
add A, #_7Seg_Table-$-3
movc a, @a+pc
mov driverRam+1, A  

mov A, KommaChecker
jnb ACC.5, LoadPat1
jnb blink, LoadPat1
mov driverRam+1, #0
ljmp GetPat2

LoadPat1:
jnb ACC.4, getPat2
mov A, driverRam+1
setb ACC.0
mov driverRam+1, A

GetPat2:
mov A, driverRam+2  
mov KommaChecker, A
anl A, #00001111b
add A, #_7Seg_Table-$-3
movc a, @a+pc 
mov driverRam+2, A 

mov A, KommaChecker
jnb ACC.5, LoadPat2
jnb blink, LoadPat2
mov driverRam+2, #0
ljmp GetPat3

LoadPat2:
jnb ACC.4, getPat3
mov A, driverRam+2
setb ACC.0
mov driverRam+2, A

GetPat3:
mov A, driverRam+3 
mov KommaChecker, A
anl A, #00001111b
add A, #_7Seg_Table-$-3
movc a, @a+pc 
mov driverRam+3, A 

mov A, KommaChecker
jnb ACC.5, LoadPat3
jnb blink, LoadPat3
mov driverRam+3, #0
ljmp GetPatExit

LoadPat3:
jnb ACC.4, getPatExit
mov A, driverRam+3
setb ACC.0
mov driverRam+3, A

getPatExit:
cjne row, #01000000b, getPatExit1 
mov A, msgRam+6
cjne A, #10, getPatExit1  
mov driverRam+1, _7segMuster+1
mov driverRam+2, _7segMuster+0

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