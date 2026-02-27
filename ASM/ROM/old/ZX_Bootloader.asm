   DEVICE ZXSPECTRUM48
   ; compiler = sjasmplus
   
   ; this is the ZX Spectrum Boot Loader
   ; this code will be inserted in the standard rom at $1209, this is where normally
   ; the main basic loop starts.
   ; We leave the rest of the ROM in tact, our program needs it.
   
   org $6000

main 
  DISP $12A9                        ; code will be compiled to run from this address
  call $16B0
  LD A,$00
  CALL $1601
  ld HL,$0605                       ; point the NMI vector to a new location in ROM
  ld ($5CB0),HL                     ; NMI now points to 0605 (we rewrote that code too)

  
  ; bootloader code starts here:  
  ld a,1                            ; bootloader Mode 1
  ld ($5C49),a                      ; 
  

  ld a,2
  call $1601                        ; open channel 2 (top of screen)

  LD DE,text1
  call PRNTIT

  ld a, 100                         ; tell the ESP32 we are ready to receive data
  out ($00CB),a                     ; Send 100 to the cartridge                   
  
  
wait                                ; 
  LD a,($5C48)                      ; load border color
  OUT ($FE),a                       ; set border color
  inc a                             ; increase a
  and %00000101                     ; and operation to select specific bytes (1,4,and 5)
  LD ($5C48),a                      ; store as new border color
  
  ld a,($5C49)
  cp 1
  jr nz,no_delay
  
  ld b,214
mdelay  
  dec b  
  jp nz, mdelay

no_delay                            ; All the magic happens in the NMI routine at Rom address $0066
  ld a,($5C49)                      ; So we just wait here until address $5C49 becomes
  cp 0                              ; zero 
  jp nz, wait                       ;

  LD DE,text2
  call PRNTIT  
  
run                                 ; when we break out of the above loop
  jp $6000                          ; we end up here, so we jump to the start of the program
     

PRNTIT
    
    LD A, (DE)                      ; Get the character
    CP 255                          ; CP with 255
    RET Z                           ; Ret if it is zero
    RST $10                         ; Otherwise print the character
    INC DE                          ; Inc to the next character in the string
    JR PRNTIT                       ; Loop 
  
  
text1            ; "12345678901234567890123456789012"
  DB $16,0,0,$10,0,"Bootloader, loading from ESP    ",255
text2
  DB $16,20,0,$10,0,"Done.",255
  
 
  DB "EOC" ; End of code            ; this is just here so I can find the end of code in the BIN file
  ENT                               ; End of the DISP command
  
; Deployment: Bin file
  SAVEBIN "bootload_12A9.bin",main
