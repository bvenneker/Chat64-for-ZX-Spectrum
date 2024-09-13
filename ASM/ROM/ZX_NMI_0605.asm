   DEVICE ZXSPECTRUM48
   
   ; compiler = sjasmplus
   
   ; the NMI starts at $0066 and then jumps to this address $0605
   ; After compilation this code is inserted in the rom at adress $0605
   
   org $6000
  
main 
  DISP $0605                        ; code will be compiled to run from this address   
  
// $5C49 = 1 receive border color  
// $5C49 = 5 data length, low byte   (e register)
// $5C49 = 6 data length, high byte  (d register)
// $5C49 = 7 write program bytes
// $5C49 = 0 run the program 

// $5B02 = low byte data length
// $5B03 = high byte data length
// $5B04 = low byte data address (starting at $6000)
// $5B05 = high byte data address (starting at $6000)


  ld a, ($5C49)
  cp 0
  jp z, exit_nmi
  cp 1
  jp z, do_border_color
  cp 5
  jp z, do_data_length_LB
  cp 6
  jp z, do_data_length_HB
  cp 7
  jp z, do_program_bytes
  
  jp exit_nmi
  

do_border_color
  ld a,5                            ; set address $5C49 to 5 for the next 
  ld ($5C49),a                      ; time NMI is triggered
  in a,($00CB)                      ; Load a byte from the cartridge port into accumulator
  call $229B                        ; change the border color
  jp exit_nmi                       ; jump to exit nmi routine
  
do_data_length_LB                   ; receive data length low byte
  in a,($00CB)                      ; Load a byte from the cartridge port into a
  ld ($5B02),a                      ; Data length goes into DE, so E is the low byte
  ld a,6                            ; set address $5C49 to 6 for the next
  ld ($5C49),a                      ; time NMI is triggered
  jp exit_nmi                       ; jump to exit nmi routine
  
do_data_length_HB                   ; receive data length high byte
  in a,($00CB)                      ; Load a byte from the cartridge port into a
  ld ($5B03),a                      ; Data length goes into DE, so D is the high byte
  ld a,7                            ; set address $5C49 to 7 for the next
  ld ($5C49),a                      ; time NMI is triggered

  ld BC,$6000                       ; set the start address of our program (is fixed at $6000)
  ld a,b
  ld ($5B05),a                      ; store the high and low byte in addresses
  ld a,c                            ; $5B04 and $5B05
  ld ($5B04),a
  jp exit_nmi                       ; jump to exit nmi routine

do_program_bytes                    ; receive all program bytes 
  ld a,($5B05)                      ; set BC from addresses $5B04 and $5B05
  ld b,a
  ld a,($5B04)
  ld c,a
  
  in a,($00CB)                      ; Load a byte from the cartridge port into a
  ld (BC),a                         ; store the byte in BC (starting at $6000)
  inc BC                            ; increase BC for the next round
  ld a,b
  ld ($5B05),a
  ld a,c
  ld ($5B04),a
  
  ld a,($5B02)
  ld E,a
  ld a,($5B03)
  ld D,a
  dec DE                            ; decrease DE (data length) so we now when it is finished
  ld a,e
  ld ($5B02),a
  ld a,d
  ld ($5B03),a
  ld a,d                            ; load d in accumulator
  or e                              ; or operation on a with e, this will only result in zero
  jp nz, exit_nmi                   ; if both d and e are zero
  ld a,0                            ; 
  ld ($5C49),a                      ; set address $5C49 to 0 so the main program knows we are done 
//  jp exit_nmi                       ; jump to exit nmi routine
  
exit_nmi:
  pop iy
  pop ix
  pop hl
  pop de
  pop bc
  pop af
  
  retn                              ; return from interrupt routine!

  
PRNTIT    
  ld a, (DE)                      ; Get the character
  cp 255                          ; CP with 255
  ret z                           ; Ret if it is equal
  rst $10                         ; Otherwise print the character
  inc DE                          ; Inc to the next character in the string
  jr PRNTIT                       ; Loop   

cursor_l5:
  DB $16,5,0,$10,6,$13,0,$11,7,255


  DB "EOC" ; End of code            ; this is just here so I can find the end of code in the BIN file
  ENT                               ; End of the DISP command
  
; Deployment: binfile
   
  SAVEBIN "NMI_0605.bin",main
