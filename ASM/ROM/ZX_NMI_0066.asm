   DEVICE ZXSPECTRUM48
 ; compiler = sjasmplus
 
 ; this replaces the normal NMI routine in the ROM
 ; the binary code should be inserted at $0066 in the ROM
   
   org $6000
  
main 
  DISP $0066                        ; code will be compiled to run from this address
  push af
  push bc
  push de
  push hl
  push ix
  push iy
                           
  ld HL,($5CB0)                     ; Read the nmi vector
  jp HL                             ; Jump to the NMI routine
  DB "EOC" ; End of code            ; this is just here so I can find the end of code in the BIN file
  ENT                               ; End of the DISP command
  
  
; Deployment: Binfile
   
  SAVEBIN "NMI_0066.bin",main
