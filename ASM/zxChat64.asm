; character table: https://worldofspectrum.org/ZXBasicManual/zxmanappa.html;
; character builder: http://www.amelyn.com/speccy_character_builder/;
; Rom : https://skoolkid.github.io/rom/maps/all.html;
                                        ;
  DEVICE ZXSPECTRUM48                   ;
  org $6000                             ;
                                        ;
                                        ;
;                                       ;
; ROM routine addresses                 ;
;                                       ;
ROM_CLS           = $0DAF               ; Clears the screen and opens channel 2
ROM_OPEN_CHANNEL  = $1601               ; Open a channel
;                                       ;
; PRINT control codes - work with ROM_PRINT and RST 0x10;
;                                       ;
INK       = $10                         ;
PAPER     = $11                         ;
FLASH     = $12                         ;
BRIGHT    = $13                         ;
INVERSE   = $14                         ;
OVER      = $15                         ;
AT        = $16                         ;
SYMSHFT_I = $AC                         ;
SYMSHFT_A = $E2                         ;
SYMSHFT_W = $C9                         ;
SYMSHFT_S = $C3                         ;
SYMSHFT_Q = $C7                         ;
ARROWUP   = $5e
PIPE      = $7c 
STEP      = $cd 
BACKSLASH = $5C
ACCO      = $7B
ACCC      = $7D
TO        = $CC
THEN      = $CB
AND       = $C6
OR        = $C5
BRACO     = $5B
BRACC     = $5D
CR        = $0C                         ;
SPACE     = $20                         ;
DELETE    = $0C                         ;
CURSOR_L  = $08                         ;
CURSOR_R  = $09                         ;
CURSOR_D  = $0A                         ;
CURSOR_U  = $0B                         ;
COPYRIGHT = $7F                         ;
ENTER     = $0D                         ;
REPDEL    = $23                         ;
                                        ;
SCREEN_START = $4000                    ;
SCREEN_SIZE  = $1aff                    ; pixels and attributes
CARTRIDGE_IO = $00FB                    ; IO port address for the cartridge  (11111011, A2 is low)
PRINTER_IO   = $00F7                    ; IO port address for the ZX Printer (11110111, A3 is low)
                                        ;
                                        ;
init:                                   ;  
                                        ;
  im 1                                  ; interrupt mode 1,Use ROM based interrupt routine   
                                        ;
  ld HL, nmi_routine                    ; change NMI vector
  ld ($5CB0),HL                         ;
                                        ;
  ld a,($5c3b)                          ; set keyboard mode to L
  or  %00001000                         ;
  and %11101111
  ld ($5c3b),a                          ;
  SET 3,(IY+$01)                         ; set keyboard mode to L
  EI                                    ; enable maskable interrups
  call create_custom_chars              ;
  ld a,0                                ;
  ld (HAVE_PRV_BACKUP),a                ;
  ld (HAVE_PUB_BACKUP),a                ;
  ld (LASTKEY),a                        ;  
  ld (EMUMODE),a                       ;
  call $229B                            ; screen border black
  ld a,7                                ;
  ld(INKCOLOR),a                        ;
                                        ;
  call open_channel_top                 ;
  call ROM_CLS                          ;
  ld a, black | white                   ; clear the screen. Set paper to Black, INK to white,  
  call cls_attributes                   ;
  call start_screen                     ;
  call create_custom_chars2             ;
  call clear_screen                     ; clear the screen. Set paper to Black, INK to white,  
  call are_we_in_the_matrix             ;
  call get_status                       ;
  ld a, (CONFIGSTATUS)                  ;
  cp 'e'                                ;
  jp z, first_main_menu                 ;
start:                                  ;
  call clear_screen
  LD DE, DLINE                          ; draw the divider line
  CALL PRNTIT                           ;
  LD DE, MHELPLINE                      ;
  CALL PRNTIT                           ;
  ld a,(EMUMODE)                        ;
  cp 0                                  ;
  jp z, not_emulation                   ;
  LD DE, NOCART                         ;  
  call PRNTIT                           ;
  call sound_error                      ;
                                        ;
not_emulation                           ;
main_chat_function                      ; 
  ld a,1                                ;
  ld (SCREEN_ID),a                      ; ID 1 = public chat, ID 3= private chat
  call cursor_to_line_one               ;
                                        ;
  call clear_message_lines              ;
  jp key_loop                           ;
key_loop:                               ;
                                        ;
  call flash_cursor                     ;
                                        ;
scan_key:                               ;
  call check_for_messages               ;
  call key_input                        ; Get last key pressed
  jp nc,scan_key                        ; If C is clear, keep waiting for key press
  cp SYMSHFT_I                          ; a key has been pressed
  jp z,do_ink                           ; If Symbol Shift + I, wait for ink color
  cp SYMSHFT_A                          ; If Symbol Shift + A, switch between public and private
  jp z,switch_pub_priv                  ;
  cp SYMSHFT_W                          ; If Symbol Shift + W, also switch between public and private
  jp z,switch_pub_priv                  ;
  cp SYMSHFT_S                          ; If Symbol Shift + S, send the message
  jp z, send_message                    ;
  cp ENTER                              ;
  jp z,handle_enter                     ; If ENTER code, handle the enter key
  cp DELETE                             ; If Delete key, handle the backspace function
  jp z,backspace                        ;
  cp CURSOR_D                           ;
  jp z, handle_down                     ;
  cp CURSOR_U                           ;
  jp z, handle_up                       ;
  cp CURSOR_L                           ;
  jp z, handle_left                     ;
  cp CURSOR_R                           ;
  jp z, handle_right                    ;
  cp SYMSHFT_Q                          ; If Symbol Shift + Q
  jp z, exit_to_main_menu               ;
cp_and                                  ; replace the AND with [
  cp AND                                ;
  jp nz, cp_or                          ;
  ld a, BRACO                           ;
cp_or                                   ; replace the OR with ]
  cp OR                                 ;
  jp nz, cp_then                        ;
  ld a, BRACC                           ;
cp_then                                 ; replace THEN with }
  cp THEN                               ;
  jp nz,cp_to                           ;
  ld a, ACCC                            ;
cp_to                                   ; replace TO with {
  cp TO                                 ;
  jp nz,cp_step                         ;
  ld a, ACCO                            ;
cp_step                                 ; replace STEP with /
  cp STEP                               ; 
  jp nz, cp_arrow_up                    ;
  ld a,BACKSLASH                        ; 
cp_arrow_up                             ; replace arrow up with |
  cp ARROWUP                            ;
  jp nz, cp_space                       ;
  ld a, PIPE                            ;
cp_space                                ;
  cp SPACE                              ;
  jp m,key_loop                         ; If code < space character, ignore
  cp COPYRIGHT+1                        ;
  jp p,key_loop                         ; If code > copyright character, ignore
  jp print                              ; Else, print the character
do_ink:                                 ;
  ld a,INK : rst $10                    ; "print" INK code
  call sound_click2                     ;
ink_loop:                               ;
  call key_input                        ;
  jp nc,ink_loop                        ; wait for another key press
  cp $31                                ;
  jp m,reset_ink                        ; if code < '1', reset ink color
  cp $38                                ;
  jp p,reset_ink                        ; if code >= '8', reset ink color
  sub $30                               ; get numerical value of numeral character...
  ld (INKCOLOR),a                       ;
  jp print                              ; ...and "print" it as ink value
reset_ink:                              ;
  ld a,7                                ; reset ink to black by "printing" zero
print:                                  ;
  rst $10                               ; print final code
  jp check_line_end                     ; if we are at the the end of a line, be carefull!
  jp key_loop                           ; loop back to key_loop
                                        ;
                                        ;
backspace:                              ;
  call get_cursor_colm                  ; backspace..
  ld a, (COLMPOS)                       ; if we are on the very last position
  cp 31                                 ; on the last line, backspace should also
  jp nz, check_zero                     ; delete that very last character
  ld a,(LINEPOS)                        ; 
  cp 3                                  ;
  jp nz, check_zero                     ; so on line 3
  ld a,SPACE    : rst $10               ; put a space on the current position
  ld a,CURSOR_L : rst $10               ; step back one position and continue with
check_zero                              ; the normal backspace routine
  cp 0                                  ; If we are on the left most position
  jp nz , bs_simple                     ; and on the first position, backspace is not possible
  ld a, 1                               ;
  ld (FROMBS), a                        ;
  jp handle_left                        ;
bs_simple:                              ;
  ld a,CURSOR_L : rst $10               ; backspace meanse stepping left, 
  ld a,SPACE    : rst $10               ; printing a space,
  ld a,CURSOR_L : rst $10               ; and stepping left again
  jp key_loop                           ;
                                        ;
handle_enter:                           ;
  ld a, 1                               ;
  ld (FROMENTER), a                     ;
  ld a,(LINEPOS)                        ; 
  cp 3                                  ; Enter on the third line causes
  jp z, send_message                    ; the message to be sent
  cp 1                                  ; on other lines, we just drop down one line
  jp z, cursor_to_second_line           ; 
  cp 2                                  ;
  jp z, cursor_to_third_line            ;
  ld a, 0                               ;
  ld (FROMENTER), a                     ;
  jp key_loop                           ;
                                        ;
check_bs:                               ;
  ld a,(FROMBS)                         ;
  cp 0                                  ;
  jp z, key_loop                        ;
  ld a,32 : rst $10                     ; print a space character
  ld a,0                                ;
  ld (FROMBS),a                         ;
  ret                                   ;
                                        ;
cursor_to_first_line:                   ;
  call get_cursor_colm                  ;
  ld a, (COLMPOS)                       ;
  ld (COLMPOSOLD),a                     ;
  call open_channel_top                 ;
  LD DE, CURSOR_LINE1                   ;
  CALL PRNTIT                           ;
  ld a,1                                ;
  ld (LINEPOS),a                        ;
  ld a,AT  : rst $10                    ;
  ld a,21  : rst $10                    ;
  ld a,(COLMPOSOLD) : rst $10           ;
  ld a,INK :rst $10                     ;
  ld a,(INKCOLOR) : rst $10             ;
  call check_bs                         ;
  jp handle_left                        ;
                                        ;
cursor_to_second_line:                  ;
  call get_cursor_colm                  ;
  ld a,(COLMPOS)                        ;
  ld (COLMPOSOLD),a                     ;
  ld a,(FROMENTER)                      ;
  cp 0                                  ;
  jp z,ctsl1                            ;
  ld a,0                                ;
  ld (FROMENTER),a                      ;
  ld (COLMPOSOLD),a                     ;
ctsl1:                                  ;
  call open_channel_bottom              ;
  LD DE, CURSOR_LINE2                   ;
  CALL PRNTIT                           ;
  ld a,INK :rst $10                     ;
  ld a,(INKCOLOR) : rst $10             ;
  ld a,2                                ;
  ld (LINEPOS),a                        ;
  ld a,AT : rst $10                     ;
  ld a,0  : rst $10                     ;
  ld a,(COLMPOSOLD)                     ;
  rst $10                               ;
  call check_bs                         ;
  jp handle_left                        ;
                                        ;
                                        ;
cursor_to_third_line:                   ;
  call get_cursor_colm                  ;
  ld a,(COLMPOS)                        ;
  ld (COLMPOSOLD),a                     ;
  ld a,(FROMENTER)                      ;
  cp 0                                  ;
  jp z,cttl1                            ;
  ld a,0                                ;
  ld (FROMENTER),a                      ;
  ld (COLMPOSOLD),a                     ;
cttl1:                                  ;
  call open_channel_bottom              ;
  LD DE, CURSOR_LINE3                   ;
  CALL PRNTIT                           ;
                                        ;
  ld a,3                                ;
  ld (LINEPOS),a                        ;
  ld a,AT : rst $10                     ;
  ld a,1  : rst $10                     ;
  ld a,(COLMPOSOLD)                     ;
  rst $10                               ;
  ld a,INK :rst $10                     ;
  ld a,(INKCOLOR) : rst $10             ;
  jp key_loop                           ;
                                        ;
handle_down:                            ;
  ld a,(LINEPOS)                        ;
  cp 1                                  ;
  jp z, cursor_to_second_line           ;
  cp 2                                  ;
  jp z, cursor_to_third_line            ;
  jp key_loop                           ;
                                        ;
                                        ;
handle_up:                              ;
  ld a,(LINEPOS)                        ;
  cp 1                                  ;
  jp z, key_loop                        ;
  cp 2                                  ;
  jp z, cursor_to_first_line            ;
  cp 3                                  ;
  jp z, cursor_to_second_line           ;
                                        ;
handle_right:                           ;
  call get_cursor_colm                  ; get current possition of cursor
  ld a ,(COLMPOS)                       ;
  add 1                                 ; add 1
  ld (COLMPOS),a                        ; store new value
                                        ;
  ld a,(LINEPOS)                        ;
  cp 2                                  ;
  jp z, right_on_second_line            ;
  cp 3                                  ;
  jp z, right_on_third_line             ;
                                        ;
  ld a ,(COLMPOS)                       ; we are on line 1 of the input text field
  cp 32                                 ;
  jp nz, hr_skip                        ;
  ld a,0                                ;
  ld (COLMPOS),a                        ;
hr_skip:                                ;
  ld a,AT : rst $10                     ; move the cursor to screen line 21
  ld a,21 : rst $10                     ; move the cursor to colum (Columpos)
  ld a ,(COLMPOS) : rst $10             ;
  ld a ,(COLMPOS)                       ;
  cp 0                                  ;
  jp nz,key_loop                        ; return to key input loop
  jp handle_down                        ;
                                        ;
right_on_second_line:                   ;
  ld a,(COLMPOS)                        ;
  cp 32                                 ;
  jp nz, hr_skip2                       ;
  ld a, 0                               ;
  ld (COLMPOS),a                        ;
  ld a,3                                ;
  ld (LINEPOS),a                        ;
  jp right_on_third_line                ;
hr_skip2                                ;
  ld a,AT : rst $10                     ; we are on line 2 of the input text field,move the cursor to screen line 0
  ld a,0  : rst $10                     ; move the cursor to colum (Columpos)
  ld a ,(COLMPOS) : rst $10             ;
  jp key_loop                           ; return to key input loop
                                        ;
right_on_third_line:                    ;
  ld a,(COLMPOS)                        ; on line 3 you should not be able to go right
  cp 32                                 ; after position 32
  jp z, key_loop                        ; jump back if we are on position 32
  ld a,AT                               ; we are on line 3 of the input text field
  rst $10                               ; move the cursor to screen line 1
  ld a,1                                ; move the cursor to colum (Columpos)
  rst $10                               ;
  ld a ,(COLMPOS)                       ;
  rst $10                               ;
  jp key_loop                           ; return to key input loop
                                        ;
                                        ;
handle_left:                            ;
  call get_cursor_colm                  ;
  ld a ,(COLMPOS)                       ;
  cp 0                                  ;
  jp nz, hl_go_left                     ;
  ld a,(LINEPOS)                        ;
  cp 1                                  ;
  jp z,key_loop                         ;
  cp 2                                  ;
  jp z, hl_2                            ;
  ld a, AT : rst $10                    ; so we are on line 3
  ld a, 1 : rst $10                     ;
  ld a,31 : rst $10                     ;
  jp handle_up                          ;
hl_2:                                   ;
  ld a, AT : rst $10                    ; so we are on line 2
  ld a, 0  : rst $10                    ;
  ld a,31  : rst $10                    ;
  jp handle_up                          ;
hl_go_left:                             ;
  ld a,CURSOR_L : rst $10               ;
  jp key_loop                           ;
                                        ;
exit_to_main_menu:                      ;
  call backup_screen                    ;
  jp main_menu                          ;
                                        ;
clear_screen:                           ;
  call ROM_CLS                          ;
  ld a, black | white | bright          ; clear the screen. Set paper to Black, INK to white
  call cls_attributes                   ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Are we in the matrix?                 ;
; ---------------------------------------------------------------------
are_we_in_the_matrix:                   ;
                                        ; this is to check if a real cartridge is attached
                                        ; or if we are running in a simulator
                                        ;
                                        ;
  ld a, 253                             ; set tempbyte to 253
  ld (TEMPBYTE),a                       ;
matrix_retry:
  ld a,(TEMPBYTE)
  cp 0
  jp z, matrix_exit
  ld a, 245                             ; Load number #245 (to check if the esp32 is connected)
  call sendbyte                         ; write the byte to IO1
                                        ;
  ld a,255                              ; 
  ld (DELAY),a                          ;
  call jdelay                           ;
                                        ; Send the ROM version to the cartrdige
  ld DE,VERSION                         ;
sendversion                             ;
  ld a,(DE)                             ;
  call sendbyte                         ;
  cp 128                                ;
  jp z, matrix_n                        ;
  inc DE                                ;
  jr sendversion                        ;
matrix_n                                ;
  ld a,255                              ;
  ld (DELAY),a                          ;
  call jdelay                           ;
                                        ;
  in a,(CARTRIDGE_IO)                   ;
  cp 128                                ;
  jp z, matrix_exit                     ;
  ld a,1                                ;
  ld (EMUMODE),a                       ;
  ld a,(TEMPBYTE)
  inc a
  ld (TEMPBYTE),a
  jp matrix_retry                       ;
  
matrix_exit                             ;
  call jdelay                           ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Send the message                      ;
; ---------------------------------------------------------------------
send_message:                           ;
                                        ; check if the message starts with '@'
  ld b,0                                ;
  ld c,21                               ;
  call read_from_screen                 ;
  cp '@'                                ;
  jr z, sm_is_priv                      ;
                                        ;
  ld a, (SCREEN_ID)                     ; the message is not meant to be private, this is a problem in the PM screen
  cp 1                                  ;
  jp z,sm_screen_go                     ; on screen 1 this is fine, continue
  call save_cur_pos                     ;
  call backup_screen                    ;
  call clear_screen                     ;
  call open_channel_top                 ;
  ld DE, PM_ERROR                       ; on screen 3, this is an issue, display the error
  call PRNTIT                           ;
  call sound_error                      ;
  call wait_any_key                     ;
  call restore_priv_screen              ; clear the error and return
  call restore_cur_pos                  ;
  jp scan_key                           ; jump back, do not send the message
                                        ;
sm_is_priv                              ;
  ld b,0                                ;
  ld c,21                               ;
  ld DE,PMUSER                          ;
copy_pmuser                             ; copy the first word (like for example @Eliza ) to the PMUSER variable
  push DE                               ;
  push BC                               ;
  call read_from_screen                 ;  
  pop BC                                ;
  pop DE                                ;
  ld (DE),a                             ;
  cp " "                                ;
  jp z,end_pm_user                      ;
  inc DE                                ;
  inc b                                 ;
  jr copy_pmuser                        ;
                                        ;
end_pm_user                             ;
  inc DE                                ;
  ld a," "                              ;
  ld (DE),a                             ;
  inc DE                                ;
  ld a,128                              ;
  ld (DE),a                             ;
                                        ;
sm_is_priv2                             ;
  ld a, (SCREEN_ID)                     ; The message is private. so we should be on screen 3. If not, fix it!
  cp 3                                  ;
  jr z , sm_screen_go                   ; No problem, continue
  call save_cur_pos                     ;
  call backup_screen                    ;
  call clear_screen                     ;
  call open_channel_top                 ;
  ld DE, PM_ERROR2                      ; on screen 3, this is an issue, display the error
  call PRNTIT                           ;
  call sound_error                      ;
  call wait_any_key                     ;
  call restore_pub_screen               ; clear the error and return
  call restore_cur_pos                  ;
  jp scan_key                           ; jump back, do not send the message
                                        ;
sm_screen_go                            ;
                                        ; read the three message lines and send them to the cartridge
  call sound_click2                     ;
  ld DE, TXBUFFER                       ; read message lines and put it in the buffer
                                        ;
  ld c,21                               ;
  ld a,0                                ;
  ld (TEMPCOLOR),a                      ;
                                        ;
sm_read_lines                           ;
  ld b,0                                ;
sm_line1                                ;
  call get_color                        ;
  ld a,(TEMPCOLOR)                      ;
  cp h                                  ;
  jr z,sm_no_change1                    ;
  ld a,h                                ;
  ld (TEMPCOLOR),a                      ;
  ld (DE),a                             ;
  inc DE                                ;
sm_no_change1                           ;
  push DE                               ;
  push BC                               ;
  call read_from_screen                 ;
  pop BC                                ;
  pop DE                                ;
  ld (DE),a                             ;
  inc DE                                ;
  inc b                                 ;
  ld a,b                                ;
  cp 32                                 ;
  jp nz,sm_line1                        ;
  ld a, (SCREEN_ID)                     ; Skip padding the lines to 40 long
  cp 3                                  ; on the private message screen.
  jp z,no_padding                       ; it is not needed..
sm_pad40                                ;
  ld a,32                               ; fill the line with spaces until it is 40 long (for compatibility with C64)
  ld (DE),a                             ;
  inc DE                                ;
  inc b                                 ;
  ld a,b                                ;
  cp 41                                 ;
  jp nz,sm_pad40                        ;
  dec DE                                ;
no_padding
  inc c                                 ; inc c to go to the next line
  ld a,c                                ;
  cp 24                                 ; exit after 3 lines (21,22,and 23)
  jp nz, sm_read_lines                  ;
                                        ;
  dec DE                                ;
  ld a,128                              ;
  ld (DE),a                             ;
                                        ;
  ld a,253                              ; command byte 253 = new public message
  call sendbyte                         ;
                                        ;
  ld a,100                              ;
  ld (DELAY),a                          ;
  call jdelay                            ;
                                        ;
  ld DE,TXBUFFER                        ; send the TXBUFFER
sm_tx_loop                              ;
  ld a,(DE)                             ;
  call sendbyte                         ;
  cp 128                                ;
  jp z,sm_exit                          ;
  inc DE                                ;
  jr sm_tx_loop                         ;
                                        ;
sm_exit                                 ;
  call clear_message_lines              ;
  ld a,250                              ;
  ld (DELAY),a                          ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  call do_check                         ; check for messages to get your own message back quick
  ld a, (SCREEN_ID)                     ;
  cp 1                                  ;
  jp z, key_loop                        ;
  call type_last_PMUSER                 ;
  jp backspace                          ;
                                        ;
; ---------------------------------------------------------------------
; Get char color                        ;
; b = column (0,31)                     ;
; c = line   (21,22,23)                 ;
; output color is in H                  ;
; ---------------------------------------------------------------------
get_color:                              ;
  push DE                               ;
  push BC                               ;
  inc b                                 ;
  ld a,c                                ;
  cp 23                                 ;
  jr z,gc23                             ;
  cp 22                                 ;
  jr z,gc22                             ;
                                        ;
gc21                                    ;
  ld DE,$5A9F                           ; start address on line 21 = $5AA0 - 1 = $5A9F
  jr gc_go                              ;
gc22                                    ;
  ld DE,$5ABF                           ; start address on line 22
  jr gc_go                              ;
gc23                                    ;
  ld DE,$5ADF                           ; start address on line 23
                                        ;
gc_go                                   ;
  inc DE                                ; advance the pointer to the position in the line
  djnz gc_go                            ; until b==0
                                        ;
  ld a,(DE)                             ;
  and %00000111                         ; only get the color attribute
  add a,144                             ; add 144 to match the C64 colors
  ld h,a                                ;
  pop BC                                ;
  pop DE                                ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Clear the message lines               ;
; ---------------------------------------------------------------------
clear_message_lines:
  call open_channel_top                 ; fill the message lines with spaces
  ld a, AT : rst $10                    ; we do not use the rom function to clear the lines
  ld a, 21 : rst $10                    ; because we need to fill them with actual space characters
  ld a, 0: rst $10                      ; otherwise, the flash cursor routine will not work
  ld a, PAPER : rst $10                 ;
  ld a, 0: rst $10                      ;
  ld a, INK : rst $10                   ;
  ld a, 7: rst $10                      ;
  ld b, 32                              ;
cl_loop1                                ;
  ld a, ' ': rst $10                    ;
  djnz cl_loop1                         ; decrease B and jump when not zero  
                                        ;
  call open_channel_bottom              ;
  ld a, AT : rst $10                    ;
  ld a, 0 : rst $10                     ;
  ld a, 0: rst $10                      ;
  ld b, 64                              ;
cl_loop2                                ;
  ld a, ' ': rst $10                    ;
  djnz cl_loop2                         ; decrease B and jump when not zero
  call cursor_to_line_one               ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Switch between public and private messaging;
; ---------------------------------------------------------------------
switch_pub_priv:                        ;
  call backup_screen                    ;
  ld a,(SCREEN_ID)                      ; ID 1 = public chat, ID 3= private chat, ID 5 = Main Menu
  cp 1                                  ;
  jp z, goto_priv                       ;
  cp 3                                  ;
  jp z, goto_pub                        ;
  jp key_loop                           ;
goto_priv:                              ;
  ld a,3                                ;
  ld (SCREEN_ID),a                      ;
  ld a,(HAVE_PRV_BACKUP)                ;
  cp 1                                  ;
  jp nz,goto_new_private_screen         ;
  call restore_priv_screen              ;
  call cursor_to_line_one               ;
  call type_last_PMUSER                 ;
  jp backspace                          ;
goto_new_private_screen:                ;
  call clear_screen                     ;
  call open_channel_top                 ;
  LD DE, MLINES_PRIVATE                 ;
  CALL PRNTIT                           ;
  LD DE, DLINE                          ; draw the divider line
  CALL PRNTIT                           ;
//  LD DE, FAKECHAT2
//  CALL PRNTIT  
  call cursor_to_line_one               ;
  call type_last_PMUSER                 ;

  jp key_loop                           ;
goto_pub:                               ;
  ld a,1                                ;
  ld (SCREEN_ID),a                      ;
  call restore_pub_screen               ;
  call cursor_to_line_one               ;
  call pm_zero                          ; clear the [ PM 01 ] part
  jp key_loop                           ;
                                        ;
type_last_PMUSER:                       ;                                                                              
  ld a, AT : rst $10                    ;
  ld a,21 : rst $10                     ;
  ld a,0 : rst $10                      ;
  ld DE, PMUSER                         ;
  CALL PRNTIT                           ;               
  ret                                   ;
; ---------------------------------------------------------------------
; Open Channel                           
; ---------------------------------------------------------------------
open_channel_top                        ;
  ld a,2                                ; open output channel 2 (top part of the screen)
  call ROM_OPEN_CHANNEL                 ;
  ret                                   ;
                                        ;
open_channel_bottom                     ;
  ld a,1                                ; open output channel 1 (bottom part of the screen)
  call ROM_OPEN_CHANNEL                 ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; get the config status, servername and ESP version;
; ---------------------------------------------------------------------
get_status:                             ;
  ld a, (EMUMODE)                      ;
  cp 1                                  ;
  jr nz, gs661                          ;
  ld a,'d'                              ;
  ld (CONFIGSTATUS),a                   ;
  ret                                   ;
gs661                                   ;
  ld b,236                              ;
  call send_start_byte_ff               ; after this call, the RXBUFFER contains:
                                        ; Configured<byte 129>Server<byte 129>SWVersion<byte 128>
                                        ;
  ld a,1                                ; Save the first part (Configured status)
  call splitRXbuffer                    ;
                                        ; copy the splitbuffer to CONFIGSTATUS
  ld DE,SPLITBUFFER                     ;
  ld a,(DE)                             ;
  ld (CONFIGSTATUS),a                   ;
                                        ;
  ld a,2                                ; Save the second part (Server name)
  call splitRXbuffer                    ; SPLITBUFFER now contains the servername
                                        ;
  ld DE,SPLITBUFFER                     ;
  ld HL,SERVERNAME                      ;
find128                                 ;
  ld a,(DE)                             ;
  ld (HL),a                             ;
  cp 128                                ;
  jp z, gs_next                         ;
  inc DE                                ;
  inc HL                                ;
  jr find128                            ;
                                        ;
gs_next                                 ;
  ld a,3                                ; Save the third part (SW Version)
  call splitRXbuffer                    ; SPLITBUFFER now contains the esp version
                                        ;
  ld DE,SPLITBUFFER                     ;
  ld HL,ESPVERSION                      ;
find128_2                               ;
  ld a,(DE)                             ;
  ld (HL),a                             ;
  cp 128                                ;
  jp z, gs_exit                         ;
  inc DE                                ;
  inc HL                                ;
  jr find128_2                          ;
                                        ;
gs_exit                                 ;
  ret                                   ;
  
; ---------------------------------------------------------------------
; Main Menu                             ;
; ---------------------------------------------------------------------
first_main_menu:  
  ld a,9                                ;
  ld (SCREEN_ID),a 
main_menu:                              ;
  ld a,0                                ;
  ld (ESCAPE),a                         ;
  ld a,(EMUMODE)                        ;
  cp 1                                  ;
  jp z,emulation1                            ;
  call get_status                       ;
  ld a,(CHECK_UPDATE)                   ;
  cp 2                                  ;
  call z,update_screen                  ;
                                        ;
emulation1                                   ;
  call clear_screen                     ;
  ld DE,MLINES      : CALL PRNTIT       ;
  ld DE,MLINES_MAIN : CALL PRNTIT       ;
  ld DE,MLINE_MAIN1 : CALL PRNTIT  ;    ; wifi setup
                                        ;
  ld a, (CONFIGSTATUS)                  ;
  cp 'e'                                ; empty
  jp z, skip1                           ;
                                        ;
  ld DE,MLINE_MAIN2 : CALL PRNTIT  ;    ; account setup
  ld a, (CONFIGSTATUS)                  ;
  cp 's'                                ; server done
  jp z, skip1                           ;
                                        ;
  
                                        ;
;  ld a, (CONFIGSTATUS)                  ;
;  cp 's'                                ; registration done
;  jp z, skip1                           ;
  ld DE,MLINE_MAIN3 : CALL PRNTIT  ;    ; server setup
                                        ;
                                        ;
  ld DE,MLINE_MAIN4 : CALL PRNTIT  ;    ; user list
                                        ;
skip1                                   ;
  ld DE,MLINE_MAIN5 : CALL PRNTIT       ;
  ld DE,MLINE_MAIN6 : CALL PRNTIT       ;
  ld DE,MLINE_MAIN7 : CALL PRNTIT       ;
  call open_channel_bottom              ;
  ld DE,MLINE_VERSION                   ;
  CALL PRNTIT                           ;
  ld a, AT : rst $10                    ;
  ld a, 0 : rst $10                     ;
  ld a, 22 : rst $10                    ;
  ld DE, ESPVERSION                     ;
  CALL PRNTIT                           ;
  ld a, AT : rst $10                    ;
  ld a, 0 : rst $10                     ;
  ld a, 12 : rst $10                    ;
  ld DE, VERSION                        ;
  CALL PRNTIT                           ;
                                        ;
  call open_channel_top                 ;
                                        ;
scan_main_menu_key:                     ;
  call key_input ;                      ; Get last key pressed
  jp nc,scan_main_menu_key              ; If C is clear, keep waiting for key press
  cp "7"                                ; Key 7 has been pressed
  jp z, exit_from_main_menu             ;
  cp 27                                 ; Escape Key (on external keyboard) has been pressed
  jp z, exit_from_main_menu             ;
  cp "1"                                ;
  jp z, goto_wifi_setup                 ;
  cp "2"                                ;
  jp z, goto_account_setup              ;
  cp "3"                                ;
  jp z, goto_server_setup               ;
  cp "4"                                ;
  jp z, goto_user_list                  ;
  cp "5"                                ;
  jp z, goto_help_screen                ;
  cp "6"                                ;
  jp z, goto_about_screen               ;
  jp scan_main_menu_key                 ;
                                        ;
exit_from_main_menu:                    ;
  ld a,(SCREEN_ID)                      ;
  cp 9
  jp z, start
  cp 1                                  ;
  jp z,exit_to_pub                      ;
  call restore_priv_screen              ;
  call cursor_to_line_one               ;
  jp key_loop                           ;
                                        ;
exit_to_pub:                            ;
  call restore_pub_screen               ;
  call cursor_to_line_one               ;
  jp key_loop                           ;
                                        ;
goto_wifi_setup:                        ;
  jp wifi_setup                         ;
                                        ;
goto_server_setup:                      ;
  jp server_setup                       ;
                                        ;
goto_account_setup:                     ;
  jp account_setup                      ;
                                        ;
goto_user_list:                         ;
  jp user_list                          ;
                                        ;
goto_help_screen:                       ;
  jp help_screen                        ;
                                        ;
goto_about_screen:                      ;
  jp about_screen                       ;
                                        ;
; ---------------------------------------------------------------------
; Cursor to line one                    ;
; ---------------------------------------------------------------------
cursor_to_line_one:                     ;
  call open_channel_top                 ;
  LD DE, CURSOR_LINE1                   ;
  CALL PRNTIT                           ;
  ld a,1                                ;
  ld (LINEPOS),a                        ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Create input field                    ;
; row in d                              ;
; colm in e                             ;
; ---------------------------------------------------------------------
input_field:                            ;
  ld a,AT : rst $10                     ; move the cursor
  ld a,d  : rst $10                     ; to position d,e  (row,column)
  ld a,e  : rst $10                     ;
  ld (HOMECOLM),a                       ; also store e as HOMECOLM
                                        ;
if_start:                               ;
  call flash_cursor_on_input            ;
                                        ;
if_key_scan:                            ;
  call key_input                        ;
  jp nc, if_key_scan                    ;
  cp ENTER                              ;
  jp z, if_exit                         ;
  cp 27                                 ;
  jp z, if_escape                       ;
  cp DELETE                             ; If Delete key, handle the backspace function
  jp z,if_backspace                     ;
  cp SPACE                              ;
  jp m,if_key_scan                      ; If code < space character, ignore
  cp COPYRIGHT+1                        ;
  jp p,if_key_scan                      ; If code > copyright character, ignore
  call if_print                         ; Else, print the character
  jp if_key_scan                        ;
                                        ;
if_backspace:                           ;
  call unflash_cursor_on_input          ;
  ld a, (HOMECOLM)                      ; put homecolm in c ,via a
  ld c,a                                ;
  ld a, (COLMPOS)                       ; put colmpos in a
  cp c                                  ; compare a against c
  jp z,if_start                         ;
  ld a,8  : rst $10                     ;
  ld a,32 : rst $10                     ;
  ld a,8  : rst $10                     ;
  call flash_cursor_on_input            ;
  jp if_key_scan                        ;
                                        ;
if_print:                               ;
  rst $10                               ; print the character
  call get_cursor_colm                  ;
  ld a, (COLMPOS)                       ;
  cp 32                                 ;
  jp nz,if_not_eol                      ;
  ld a,8                                ;
  rst $10                               ;
if_not_eol:                             ;
  call flash_cursor_on_input            ;
  ret                                   ;
                                        ;
if_escape:                              ;
  ld a, 1                               ;
  ld (ESCAPE),a                         ;
if_exit:                                ;
  call unflash_cursor_on_input          ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Update screen                         ;
; ---------------------------------------------------------------------
update_screen:                          ;
  call clear_screen                     ;
  ld DE, MLINES                         ;
  CALL PRNTIT                           ;
  ld DE, MLINES_UPDATE                  ;
  CALL PRNTIT                           ;
  call open_channel_bottom              ;
  ld DE,MLINE_VERSION                   ;
  CALL PRNTIT                           ;
  ld a, AT : rst $10                    ;
  ld a, 0 : rst $10                     ;
  ld a, 22 : rst $10                    ;
  ld DE, ESPVERSION                     ;
  CALL PRNTIT                           ;
  ld a, AT : rst $10                    ;
  ld a, 0 : rst $10                     ;
  ld a, 12 : rst $10                    ;
  ld DE, VERSION                        ;
  CALL PRNTIT                           ;
  
  ld a,(TEMPBYTE)                       ; if tempbyte contains 123
  cp 123                                ; then go straight into the update
  jp z, do_update                       ; without asking the user.
  
scan_update_key                         ;
  call key_input ;                      ; Get last key pressed
  jp nc,scan_update_key                 ; If C is clear, keep waiting for key press
  cp "n"                                ; Key has been pressed
  jr z, exit_main_menu                  ;
  cp "y"                                ;
  jp z, do_update                       ;
  jp scan_update_key                    ;
                                        ;
do_update                               ;
  call open_channel_top                 ; 
  ld de,update_bar                      ;
  CALL PRNTIT                           ;
                                        ;
  call jdelay                           ;
  ld a, 232                             ; send the update command
  call sendbyte                         ;
                                        ; send confirmation
  call jdelay                           ;
  ld DE,text_update                     ;  
confirm_update                          ;
  ld a,(DE)                             ;
  call sendbyte                         ;
  cp 128                                ;
  jp z,do_update_bar1                   ;
  inc DE                                ;
  jr confirm_update                     ;
                                        ;
do_update_bar1                          ;
  ld HL, get_progress                   ; change NMI vector
  ld ($5CB0),HL                         ; the update procedure uses a different NMI routine
  ld a,1                                ;
  ld (LINEPOS),a                        ;
  ld a,INVERSE : rst $10                ;
  ld a,0 : rst $10                      ;
                                        ;
do_update_bar                           ;
  ld a,AT : rst $10                     ;
  ld a,14 : rst $10                     ;
  ld a,(LINEPOS) : rst $10              ;
  ld a,$9F : rst $10                    ;
                                        ;
  ld a,(LINEPOS)                        ;
  cp 29                                 ;
  jp z, update_done                     ;
  jp do_update_bar                      ;
                                        ;
                                        ;
                                        ;
exit_main_menu                          ;
  ld a,0                                ;
  ld (CHECK_UPDATE),a                   ;
                                        ;
upd_exit                                ;
  ret                                   ;
                                        ;
update_done                             ;
  ld de,text_update_done                ;
  CALL PRNTIT                           ;
  jp reset_wait                         ;
                                        ;
get_progress                            ; this is the NMI routine when the update runs
  ld a,(LINEPOS)                        ;
  inc a                                 ;
  ld (LINEPOS),a                        ;
                                        ;
exit_progres                            ;
  pop iy                                ;
  pop ix                                ;
  pop hl                                ;
  pop de                                ;
  pop bc                                ;
  pop af                                ;
  retn                                  ; return from interrupt routine!
                                        ;
; ---------------------------------------------------------------------
; WiFi Setup                            ;
; ---------------------------------------------------------------------
wifi_setup:                             ;
  call clear_screen                     ;
  ld DE, MLINES                         ;
  CALL PRNTIT                           ;
  ld DE, MLINES_WIFI                    ;
  CALL PRNTIT                           ;
  ld DE, MLINE_CHANGE                   ;
  CALL PRNTIT                           ;
  ld DE, MLINE_MAIN7                    ;
  CALL PRNTIT                           ;
  ld DE,WFSSID                          ;
  CALL PRNTIT                           ;
  ld a,(EMUMODE)                        ;
  cp 1                                  ;
  jp  z,wifi_edit_or_exit               ;
                                        ;
  ld b,248                              ; ask the wifi connection status
  call send_start_byte_ff               ; after this call, the RXBUFFER contains the connection status
  ld a,AT : rst $10                     ;
  ld a,21 : rst $10                     ;
  ld a,0 : rst $10                      ;
  ld DE,RXBUFFER                        ;
  call PRNTIT                           ;
  ld DE,RXBUFFER                        ;
  ld a,(DE)                             ;
  cp 'N'                                ;
  jp z, connect_error                   ;
  cp 'C'                                ;
  jp z, connect_good                    ;
  jp connect_unknown                    ;
                                        ;
connect_error                           ;
  call sound_error                      ;
  jp connect_unknown                    ;
                                        ;
connect_good                            ;
  call sound_bell2                      ;
                                        ;
                                        ;
connect_unknown                         ;
  ld b,251                              ;
  call send_start_byte_ff               ; after this call, the RXBUFFER contains:
                                        ; SSID<byte 129>Password<byte 129>GMToffset<byte 128>
                                        ;
  ld a,1                                ; Print the current SSID on screen
  call splitRXbuffer                    ;
  ld a,AT : rst $10                     ;
  ld a,4 : rst $10                      ;
  ld a,6 : rst $10                      ;
  ld a,INK : rst $10                    ;
  ld a,5 :rst $10                       ;
  ld DE,SPLITBUFFER                     ;
  call PRNTIT                           ;
                                        ;
  ld a,2                                ; Print the current Password on screen
  call splitRXbuffer                    ;
  ld a,AT : rst $10                     ;
  ld a,6 : rst $10                      ;
  ld a,10 : rst $10                     ;
  ld DE,SPLITBUFFER                     ;
  call PRNTIT                           ;
                                        ;
  ld a,3                                ; Print the current time offset on screen
  call splitRXbuffer                    ;
  ld a,AT : rst $10                     ;
  ld a,8 : rst $10                      ;
  ld a,22 : rst $10                     ;
  ld DE,SPLITBUFFER                     ;
  call PRNTIT                           ;
                                        ;
wifi_edit_or_exit:                      ;
  call key_input ;                      ; Get last key pressed
  jp nc,wifi_edit_or_exit               ; If C is clear, keep waiting for key press
  cp "7"                                ; Key has been pressed
  jp z, main_menu                       ;                
  cp "1"                                ;
  jp z,wifi_input_fields                ;
  jp wifi_edit_or_exit                  ;
                                        ;
wifi_input_fields:                      ;
                                        ; input fields
  ld d, 4                               ; set line (or row) for the input field SSID
  ld e, 6                               ; set column for the input field
  call input_field                      ;
  ld a, (ESCAPE)                        ;
  cp 1                                  ;
  jp z, main_menu                       ;
  ld d, 6                               ; set line (or row) for the input field PASSWORD
  ld e, 10                              ; set column for the input field
  call input_field                      ;
  ld a, (ESCAPE)                        ;
  cp 1                                  ;
  jp z, main_menu                       ;
  ld d, 8                               ; set line (or row) for the input field GMT OFFSET
  ld e, 22                              ; set column for the input field
  call input_field                      ;
  ld a, (ESCAPE)                        ;
  cp 1                                  ;
  jp z, main_menu                       ;
  ld DE, MLINE_SAVE                     ;
  CALL PRNTIT                           ;
                                        ;
scan_wifi_menu_key:                     ;
  call key_input ;                      ; Get last key pressed
  jp nc,scan_wifi_menu_key              ; If C is clear, keep waiting for key press
  cp "7"                                ; Key has been pressed
  jp z, main_menu                       ;
  cp 27                                 ; Esc Key (on external keyboard) has been pressed
  jp z, main_menu                       ;
                                        ;
  cp "1"                                ;
  jp z, save_wifi_settings              ;
  jp scan_wifi_menu_key                 ;
                                        ;
save_wifi_settings:                     ;
  ld a,252                              ; command byte 252 tells the cartridge we
                                        ; are sending the wifi credentials
  call sendbyte                         ; send the command byte to the cartridge
                                        ;
                                        ; send_ssid
  ld c,4                                ; ssid starts at line 4
  ld b,6                                ; ssid starts at column 6
  call send_out_line                    ;
                                        ;
                                        ; send_password
  ld c,6                                ; password starts at line 6
  ld b,10                               ; nickname starts at column 10
  call send_out_line                    ;
                                        ;
                                        ; send_time_offset
  ld c,8                                ; time offset starts at line 8
  ld b,22                               ; time offset starts at column 22
  call send_out_line                    ;
                                        ;
  ld a,255                              ;
  ld (DELAY),a                          ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
  call jdelay                           ;
                                        ;
  jp wifi_setup                         ;
                                        ;
; ---------------------------------------------------------------------
; Account Setup                         ;
; ---------------------------------------------------------------------
account_setup:                          ;
  call clear_screen                     ;
  ld DE, MLINES                         ;
  CALL PRNTIT                           ;
  ld DE, MLINES_ACCOUNT                 ;
  CALL PRNTIT                           ;
  ld DE, MLINE_MAIN7                    ;
  CALL PRNTIT                           ;
  ld DE, ACCOUNTSETUP                   ;
  CALL PRNTIT                           ;
  ld a,(EMUMODE)                       ;
  cp 1                                  ;
  jp z,account_edit_or_exit             ;
  ld b,243                              ;
  call send_start_byte_ff               ; RXBUFFER now contains macaddress[32]regid[32]nickname[32]regstatus[128]
                                        ;
  ld a,1                                ; Print the current Mac address on screen
  call splitRXbuffer                    ;
  ld a,AT : rst $10                     ;
  ld a,4 : rst $10                      ;
  ld a,13 : rst $10                     ;
  ld a,INK : rst $10                    ;
  ld a,5 :rst $10                       ;
  ld DE,SPLITBUFFER                     ;
  call PRNTIT                           ;
                                        ;
  ld a,2                                ; Print the current reg id on screen
  call splitRXbuffer                    ;
  ld a,AT : rst $10                     ;
  ld a,6 : rst $10                      ;
  ld a,8 : rst $10                      ;
  ld DE,SPLITBUFFER                     ;
  call PRNTIT                           ;
                                        ;
  ld a,3                                ; Print the current Nick Name on screen
  call splitRXbuffer                    ;
  ld a,AT : rst $10                     ;
  ld a,8 : rst $10                      ;
  ld a,11 : rst $10                     ;
  ld DE,SPLITBUFFER                     ;
  call PRNTIT                           ;
                                        ;
  ld a,4                                ; Get the registration status
  call splitRXbuffer                    ;
  ld a,(SPLITBUFFER)                    ;
  cp 'u'                                ; reg status 21 means unregisterd!
  jp z, unreg                           ;
  cp 'n'                                ; reg status 14 = registration is good but nickname is taken
  jp z, name_taken                      ;
  cp 'r'                                ; succes!!
  jp z, reg_good                        ;
                                        ;
unreg                                   ;
  ld DE,text_unreg_error                ;
  call PRNTIT                           ;
  jr account_edit_or_exit ;input_fields                       ;
name_taken                              ;
  ld DE,text_name_taken                 ;
  call PRNTIT                           ;
  jr input_fields                       ;
reg_good                                ;
  ld DE,text_registration_ok            ;
  call PRNTIT                           ;
                                        ;
account_edit_or_exit:                   ;
  call key_input ;                      ; Get last key pressed
  jp nc,account_edit_or_exit            ; If C is clear, keep waiting for key press
  cp "7"                                ; Key has been pressed
  jp z, main_menu                       ;                 
  cp "1"                                ;
  jp z,input_fields                     ;
  cp "6"                                ;
  jp z, reset_screen                    ;                                           
  jp account_edit_or_exit               ;
                                        ;
input_fields                            ;
  ld a,INK : rst $10                    ;
  ld a,5   : rst $10                    ;
  ld d, 6                               ; set line (or row) for the input field registration id
  ld e, 8                               ; set column for the input field
  call input_field                      ;
  ld a, (ESCAPE)                        ;
  cp 1                                  ;
  jp z, main_menu                       ;
  ld d, 8                               ; set line (or row) for the input field nickname
  ld e, 11                              ; set column for the input field
  call input_field                      ;
  ld a, (ESCAPE)                        ;
  cp 1                                  ;
  jp z, main_menu                       ;                  
                                        ;
reg_menu                                ;
  ld a,AT :  rst $10                    ;
  ld a,13 :  rst $10                    ;
  ld a,2  :  rst $10                    ;
  ld DE, MLINE_SAVE+3                   ; skip the AT command in this line
  CALL PRNTIT                           ;
                                        ;
scan_account_menu_key:                  ;
  call key_input                        ; Get last key pressed
  jp nc,scan_account_menu_key           ; If C is clear, keep waiting for key press
  cp "7"                                ; Key has been pressed
  jp z, main_menu                       ;
  cp 27                                 ; Esc Key on external keyboard has been pressed
  jp z, main_menu                       ;                               
  cp "1"                                ;
  jp z, save_account_settings           ;
  cp "6"                                ;
  jp z, reset_screen                    ;
  jp scan_account_menu_key              ;
                                        ;
save_account_settings:                  ;
                                        ; 240 = C64 sends the new registration id and nickname to ESP32;
  ld a,240                              ; command byte 240 tells the cartridge we are sending the new registration id and nickname to ESP32
  call sendbyte                         ; send the command byte to the cartridge
                                        ; send_registration_id                   
  ld c,6                                ; registration id starts at line 6
  ld b,8                                ; registration id starts at column 8
  call send_out_line                    ;
                                        ; send_nickname                          
  ld c,8                                ; nickname starts at line 6
  ld b,11                               ; nickname starts at column 11
  call send_out_line                    ;
                                        ;
  ld a,250                              ;
  ld (DELAY),a                          ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
                                        ;
  jp z, account_setup                   ;
; ---------------------------------------------------------------------
; Server Setup                          ;
; ---------------------------------------------------------------------
server_setup:                           ;
  call clear_screen                     ;
  ld DE, MLINES                         ;
  CALL PRNTIT                           ;
  ld DE, MLINES_SERVER                  ;
  CALL PRNTIT                           ;
  ld DE, MLINE_CHANGE                   ;
  CALL PRNTIT                           ;
  ld DE, MLINE_MAIN7                    ;
  CALL PRNTIT                           ;
  ld DE, SERVERSETUP                    ;
  CALL PRNTIT                           ;
  ld a,AT: rst $10                      ;
  ld a,4: rst $10                       ;
  ld a,8: rst $10                       ;
  ld DE,SERVERNAME                      ;
  CALL PRNTIT                           ;
                                        ;
  ld a,(EMUMODE)                       ;
  cp 1                                  ;
  jp z, server_edit_or_exit             ;
  ld a,238                              ;
  call sendbyte                         ;
  ld a,250                              ;
  ld (DELAY),a                          ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
                                        ;
  ld b,237                              ;
  call send_start_byte_ff               ; RXBUFFER now contains the connection status
  ld a,AT: rst $10                      ;
  ld a,21: rst $10                      ;
  ld a,0: rst $10                       ;
  ld DE,RXBUFFER                        ;
  CALL PRNTIT                           ;
                                        ;
server_edit_or_exit:                    ;
  call key_input ;                      ; Get last key pressed
  jp nc,server_edit_or_exit             ; If C is clear, keep waiting for key press
  cp "7"                                ; Key has been pressed
  jp z, main_menu                       ;                
  cp "1"                                ;
  jp z,server_input_fields              ;                              
  jp account_edit_or_exit               ;
                                        ;
server_input_fields:                    ;
  ld a,INK : rst $10                    ;
  ld a,7 : rst $10                      ; 
  ld d, 4                               ; set line (or row) for the input field Server name
  ld e, 8                               ; set column for the input field
  call input_field                      ;
  ld a, (ESCAPE)                        ; 
  cp 1                                  ;
  jp z, main_menu                       ;
  ld DE, MLINE_SAVE                     ;
  CALL PRNTIT                           ;
                                        ;
scan_server_menu_key:                   ;
  call key_input                        ; Get last key pressed
  jp nc,scan_server_menu_key            ; If C is clear, keep waiting for key press
  cp "7"                                ; Key has been pressed
  jp z, main_menu                       ;
  cp 27                                 ; Esc Key on external keyboard has been pressed
  jp z, main_menu                       ;
  cp "1"                                ;
  jp z, save_server_settings            ;
  jp scan_server_menu_key               ;
                                        ;
save_server_settings:                   ;
                                        ; 246 = set chatserver ip/fqdn
  ld a,246                              ; command byte 246 tells the cartridge we are sending the new server name to ESP32
  call sendbyte                         ; send the command byte to the cartridge
;send server name                       ;
  ld c,4                                ; server name starts at line 4
  ld b,8                                ; server name starts at column 8
  ld DE,SERVERNAME                      ;
read_server_name                        ;
  push bc                               ;
  push DE                               ;
  call read_from_screen                 ; character from screen goes into A
  pop DE                                ; 
  ld (DE),a                             ;
  call sendbyte                         ; Send A to cartridge port
  pop bc                                ;
  inc b                                 ;
  inc DE                                ;
  ld a,b                                ;
  cp 33                                 ;
  jp nz,read_server_name                ;
                                        ;
  ld a,128                              ; end the transmission with byte 128
  call sendbyte                         ; Send A to cartridge port
  call jdelay                            ;
  call jdelay                            ;                                         
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  call jdelay                            ;
  jp z, server_setup                    ;
                                        ;
; ---------------------------------------------------------------------
; User list                             ;
; ---------------------------------------------------------------------
user_list:                              ;
  ld a,234                              ; On the very first page we need cmd code 234
  ld (TEMPI),a                          ; on next pages we need 233
ul_start:                               ;
  call clear_screen                     ;
  ld DE, MLINES                         ;
  CALL PRNTIT                           ;
  ld DE, MLINES_USERS                   ;
  CALL PRNTIT                           ;
  ld DE, USERLISTMENU                   ;
  CALL PRNTIT                           ;
  ld DE, FAKELIST                       ;
  CALL PRNTIT                           ;
  ld a,(EMUMODE)                        ;
  cp 1                                  ;
  jp z, scan_user_list                  ;
  ld a,(TEMPI)                          ;
  ld b, a                               ;
  call send_start_byte_ff               ; RXBUFFER now contains the first group of users
  ld DE, RXBUFFER                       ;
  CALL PRNTIT                           ;
                                        ;
  ld b, 233                             ;
  call send_start_byte_ff               ; RXBUFFER now contains the second group of users
  ld DE, RXBUFFER                       ;
  CALL PRNTIT                           ;
                                        ;
scan_user_list                          ;
  call key_input                        ; Get last key pressed
  jp nc,scan_user_list                  ;
  cp "7"                                ;
  jp z, main_menu                       ;
  cp 27                                 ; Esc Key on external keyboard  has been pressed
  jp z, main_menu                       ;
  cp "n"                                ; go to next page
  jp z, ul_next_page                    ;
  cp "p"                                ;
  jp z, user_list                       ; back to page zero
  jp scan_user_list                     ;
                                        ;
ul_next_page                            ;
  ld a,233                              ;
  ld (TEMPI),a                          ;
  jp ul_start                           ;
                                        ;
; ---------------------------------------------------------------------
; About Screen                          ;
; ---------------------------------------------------------------------
about_screen:                           ;
  call clear_screen                     ;
  ld DE, MLINES                         ;
  CALL PRNTIT                           ;
  ld DE, MLINES_ABOUT                   ;
  CALL PRNTIT                           ;
  ld DE, ABOUTPAGE                      ;
  CALL PRNTIT                           ;
                                        ;
scan_about_keys:                        ;
  call key_input                        ; Get last key pressed
  jp nc,scan_about_keys                 ;
  cp "7"                                ;
  jp z, main_menu                       ;
  cp 27                                 ; Esc Key on external keyboard has been pressed
  jp z, main_menu                       ;
  jp z, main_menu                       ;
  jp scan_about_keys                    ;
                                        ;
                                        ;
; ---------------------------------------------------------------------
; HELP Screen                           ;
; ---------------------------------------------------------------------
help_screen:                            ;
  call clear_screen                     ;
  ld DE, MLINES                         ;
  CALL PRNTIT                           ;
  ld DE, MLINES_HELP                    ;
  CALL PRNTIT                           ;
  ld DE, HELPPAGE                       ;
  CALL PRNTIT                           ;
                                        ;
scan_help_keys:                         ;
  call key_input                        ; Get last key pressed
  jp nc,scan_help_keys                  ;
  cp "7"                                ;
  jp z, main_menu                       ;
  cp 27                                 ; esc key has been pressed on external keyboard
  jp z, main_menu                       ;
  jp scan_help_keys                     ;
                                        ;
; ---------------------------------------------------------------------
; RESET Screen                          ;
; ---------------------------------------------------------------------
reset_screen:                           ;
  call clear_screen                     ;
  ld DE, MLINES                         ;
  CALL PRNTIT                           ;
  ld DE, RESETLINES                     ;
  CALL PRNTIT                           ;
                                        ;
scan_reset_keys:                        ;
  call key_input                        ; Get last key pressed
  jp nc,scan_reset_keys                 ;
  cp "y"                                ;
  jp z, do_reset                        ;
  jp main_menu                          ;
                                        ;
do_reset:                               ;
  call jdelay                            ;
  ld a,244                              ;
  call sendbyte                         ;
  call jdelay                            ;
  ld DE,text_reset                      ;
confirm_reset                           ;
  ld a,(DE)                             ;
  call sendbyte                         ;
  cp 128                                ;
  jp z,reset_wait                       ;
  inc DE                                ;
  jr confirm_reset                      ;
                                        ;
reset_wait                              ;
  jp reset_wait                         ;
                                        ;
                                        ;
; ---------------------------------------------------------------------
; Send out Line                         ;
; b = column                            ;
; c = line                              ;
; transmission ends when line ends      ;
; ---------------------------------------------------------------------
send_out_line:                          ;
                                        ;
sol_read_line                           ;
  push bc                               ;
  call read_from_screen                 ; character from screen goes into A
  call sendbyte                         ; Send A to cartridge port
  pop bc                                ;
  inc b                                 ;
  ld a,b                                ;
  cp 33                                 ;
  jp nz,sol_read_line                   ;
                                        ;
  ld a,128                              ; end the transmission with byte 128
  call sendbyte                         ; Send A to cartridge port
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; flash the cursor (set flash attribute on cursor location);
; ---------------------------------------------------------------------
flash_cursor:                           ;
  ld b,96                               ; first disable flash on all positions
  ld DE, $5AA0                          ;
loop_fc:                                ; loop over the 3 message lines
  ld a, (DE)                            ; starting at $5AA0
  and %01111111                         ; and set the flash attribute to 0
  ld (DE),a                             ;
  inc DE                                ; increase DE to go to the next address
  djnz loop_fc                          ; decrease B and jump back if not zero
                                        ;
do_fc:                                  ; now calculate the cursor position
  ld HL, $5A80                          ; start at the start of the divider line
  ld a, (LINEPOS)                       ; get the line number 1,2 or 3
  ld DE,32                              ; load 32 (length of one line) in DE
loop2_fc:                               ;
  add HL,DE                             ; add 32 to the start address
  dec a                                 ; repeat at many times as the line number 1,2 or 3
  jp nz, loop2_fc                       ;
  call get_cursor_colm                  ; Now we are on the right line, get the column
  ld a,(COLMPOS)                        ;
  ld E, a                               ; store the column in DE
  ld D, 0                               ;
  add HL,DE                             ; add the column to the address in HL
  ld a, (HL)                            ; load the VALUE of HL
  or 128                                ;
  ld (HL),a                             ; store it back into the address
  ret                                   ; return, we are done
                                        ;
unflash_cursor_on_input:                ;
  ld a,0                                ;
  ld (FLASHCURSOR),a                    ;
  jp fc_l2                              ;
flash_cursor_on_input:                  ;
  ld (TEMPBYTE),a                       ; save the a register for later
  ld a,1                                ;
  ld (FLASHCURSOR),a                    ;
fc_l2:                                  ;
  call get_cursor_pos1                  ; fill variables ROWPOS and COLMPOS
  ld HL,$5800                           ;
  ld a, (ROWPOS)                        ;
  ld DE,32                              ;
fci_loop1:                              ;
  add HL,DE                             ;
  dec a                                 ;
  jp nz,fci_loop1                       ;
                                        ; now we are on the right row,
  ld a,(COLMPOS)                        ;
  ld e,a                                ;
  ld D,0                                ;
                                        ;
  add HL,DE                             ;
  ld a,(FLASHCURSOR)                    ;
  cp 0                                  ;
  jp nz, fc_set                         ;
fc_unset:                               ;
  ld a,(HL)                             ;
  and %01111111                         ;
  ld (HL),a                             ;
  jp fc_exit                            ;
fc_set:                                 ;
  ld a,(HL)                             ;
  or 128                                ;
  ld (HL),a                             ;
fc_exit:                                ;
  ld a,(TEMPBYTE)                       ; restore the a register
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Check if we are at the end of a line, prevent scrolling;
; ---------------------------------------------------------------------
check_line_end:                         ;
  call get_cursor_colm                  ; get the cursor column
  ld a ,(COLMPOS)                       ;
  cp 32                                 ; compare it with 32
  jp m,key_loop                         ; if lower then no worries, return to key_loop
  ld a,(LINEPOS)                        ; if we are at the end of the line
  cp 3                                  ; test if we are on line 3 (final line)
  jp m,cl_back_home                     ; if not, go to the cl_back_home label
  ld a,CURSOR_L                         ; if we are at the end of line 3, put the cursor back (left) 1 position
  rst $10                               ;
  jp key_loop                           ; and jump back to the key loop
cl_back_home:                           ;
  ld b, 32                              ; create a loop to loop 32 times
cl_loop:                                ;
  ld a,CURSOR_L                         ; give the cursor left command
  rst $10                               ;
  djnz cl_loop                          ; decrement b and continue the loop if not zerp 
  jp handle_down                        ; once we arived at the start of the line, give the handle_down command
                                        ;
; ---------------------------------------------------------------------
; Fill the COLMPOS variable with the current cursor column;
; ---------------------------------------------------------------------
get_cursor_colm:                        ;
  ld a,(LINEPOS)                        ;
  cp 1                                  ;
  jp z, get_cursor_pos1                 ;
  ld a, ($5C8A)                         ;
  neg                                   ;
  add 33                                ;
  ld (COLMPOS),a                        ;
  ret                                   ;
                                        ;
get_cursor_pos1:                        ;
  ld a, ($5C88)                         ;
  neg                                   ;
  add 33                                ;
  ld (COLMPOS),a                        ;
  ld a, ($5C89)                         ;
  neg                                   ;
  add 24                                ;
  ld (ROWPOS),a                         ;
  ret                                   ;
; ---------------------------------------------------------------------
; My print routine                      ;
; DE: Address of the string             ;
; ---------------------------------------------------------------------
PRNTIT:                                 ;
  LD A, (DE)                            ; Get the character
  CP 128                                ; CP with 128
  RET Z                                 ; Ret if it is equal
  RST $10                               ; Otherwise print the character
  INC DE                                ; Inc to the next character in the string
  JR PRNTIT                             ; Loop
  ret                                   ;

; ---------------------------------------------------------------------
; Scroll screen up, 1 line              ;
; ---------------------------------------------------------------------
scroll_up:                              ;
  ld a,(SCREEN_ID)                      ;
  cp 3                                  ;
  jp nz, scroll_first_8                 ; on the private screen we need to
scroll_first_6                          ; skip the first 2 lines
  ld a,5                                ; scroll the first 6 lines up
  ld (TEMPL),a                          ;
  ld DE,$4040                           ; copy bytes, HL= source, DE= Destination, BC=data Length
  ld HL,$4060                           ;
  ld BC,$20                             ;
  call block_shift                      ;
  jp scroll_second_8                    ;
                                        ;
scroll_first_8                          ;
  ld a,8                                ; scroll the first 8 lines up
  ld (TEMPL),a                          ;
  ld DE,$4000                           ; copy bytes, HL= source, DE= Destination, BC=data Length
  ld HL,$4020                           ;
  ld BC,$20                             ;
  call block_shift                      ;
                                        ;
scroll_second_8                         ;
  ld a,8                                ; scroll the next 8 lines up
  ld (TEMPL),a                          ;
  ld DE,$40E0                           ; copy bytes, HL= source, DE= Destination, BC=data Length
  ld HL,$4800                           ;
  ld BC,$20                             ;
  call block_shift                      ;
                                        ;
  ld a,4                                ; scroll the final 4 lines up
  ld (TEMPL),a                          ;
  ld DE,$48E0                           ; copy bytes, HL= source, DE= Destination, BC=data Length
  ld HL,$5000                           ;
  ld BC,$20                             ;
  call block_shift                      ;
                                        ;
  ld a,(SCREEN_ID)                      ; next we need to shift all attributes up
  cp 1                                  ; 
  jp z, atr_skip                        ;
  ld DE,$5840                           ; next we need to shift all attributes up
  ld HL,$5860                           ; attributes start at $5840 (on the private screen)
  ld BC,$240                            ;
  ldir                                  ;
  jp clear20                            ;
atr_skip                                ;
  ld DE,$5800                           ; attributes start at $5800 on the public screen
  ld HL,$5820                           ;
  ld BC,$280                            ;
  ldir                                  ;
clear20                                 ;
  ld a,0                                ; clear row 20
  ld b,32                               ;
  ld c,8                                ;
  ld DE,$5060                           ;
su_clear_loop                           ;
  call su_clear                         ;
  ld b,32                               ;
  ld HL,$E0                             ;
  add DE,HL                             ;
  dec c                                 ;
  jp nz, su_clear_loop                  ;
  jp scroll_exit                        ;
                                        ;
su_clear                                ;
  ld (DE),a                             ;
  inc DE                                ;
  djnz su_clear                         ;
  jp scroll_exit                        ;
                                        ;
block_shift                             ;
  push HL                               ;
  push HL                               ;
  push BC                               ;
  call shift_scan_lines                 ;
  pop BC                                ;
  pop DE                                ;
  pop HL                                ;
  add HL,BC                             ;
  ld a,(TEMPL)                          ;
  dec a                                 ;
  ld (TEMPL),a                          ;
  cp 0                                  ;
  jp nz, block_shift                    ;
  jp scroll_exit                        ;
                                        ;
shift_scan_lines                        ;
  ldir                                  ;
  ld bc,0                               ;
  push bc                               ;
shift_loop                              ;
  ld BC,$E0                             ;
  add DE,BC                             ;
  add HL,BC                             ;
  ld BC,$20                             ;
  ldir                                  ;
  pop bc                                ;
  inc b                                 ;
  push bc                               ;
  ld a,b                                ;
  cp 7                                  ;
  jp nz,shift_loop                      ;
  pop bc                                ;
                                        ;
scroll_exit                             ;
                                        ;
  ret                                   ;
; ---------------------------------------------------------------------
; Clear screen with attributes          ;
; IN  - A contains the attribute value to initialize the screen to;
; OUT - Trashes HL, DE, BC              ;
; ---------------------------------------------------------------------
cls_attributes:                         ;
  ld hl, $5800                          ; start at attribute start
  ld de, $5800 + 1                      ; copy to next address in attributes
  ld bc, $300 - 1                       ; 'loop' attribute size minus 1 times
  ld (hl), a                            ; initialize the first attribute
  ldir                                  ; fill the attributes
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Read message lines to TX buffer       ;
; ---------------------------------------------------------------------
read_message_lines:                     ;
  ld c,21                               ;
  ld b,0                                ;
rm_read_line:                           ;
  call read_from_screen                 ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Read char from screen                 ;
; B register = column                   ;
; C register = line                     ;
; result is in A                        ;
; ---------------------------------------------------------------------
read_from_screen:                       ;
  ld HL,($5C36)                         ; CHARS plus +0100 gives HL pointing to the character set.
  ld DE,$0100                           ;
  add HL,DE                             ;
  ld A,C                                ; Line number is copied to A.
  rrca                                  ; The number 32*(x mod 8)+y is formed in A and copied to E. This is the low byte of the required screen address.
  rrca                                  ;
  rrca                                  ;
  and $E0                               ;
  xor B                                 ;
  ld E,A                                ;
  ld A,C                                ; Line number is copied to A again.
  and $18                               ; Now the number 64+8*INT (x/8) is inserted into D. DE now holds the screen address.
  xor $40                               ;
  ld D,A                                ;
  ld B,$60                              ; B counts the 96 characters.
RS_SCRN_LP:                             ;
  push BC                               ; Save the count.
  push DE                               ; And the screen pointer.
  push HL                               ; And the character set pointer.
  ld A,(DE)                             ; Get first row of screen character.
  xor (HL)                              ; Match with row from character set.
  jr Z,RS_SC_MTCH                       ; Jump if direct match found.
  inc A                                 ; Now test for match with inverse character (get +00 in A from +FF).
  jr NZ,RS_SCR_NXT                      ; Jump if neither match found.
  dec A                                 ; Restore +FF to A.
RS_SC_MTCH:                             ;
  ld C,A                                ; Inverse status (+00 or +FF) to C.
  ld B,7                                ; B counts through the other 7 rows.
RS_SC_ROWS:                             ;
  inc D                                 ; Move DE to next row (add +0100).
  inc HL                                ; Move HL to next row (i.e. next byte).
  ld A,(DE)                             ; Get the screen row.
  xor (HL)                              ; Match with row from the ROM.
  xor C                                 ; Include the inverse status.
  jr nz,RS_SCR_NXT                      ; Jump if row fails to match.
  djnz RS_SC_ROWS                       ; Jump back till all rows done.
  pop BC                                ; Discard character set pointer.
  pop BC                                ; And screen pointer.
  pop BC                                ; Final count to BC.
  ld A,$80                              ; Last character code in set plus one.
  sub B                                 ; A now holds required code.
  ret                                   ; return, a holds the character code
RS_SCR_NXT:                             ;
  pop HL                                ; Restore character set pointer.
  ld DE,$0008                           ; Move it on 8 bytes, to the next character in the set.
  add HL,DE                             ;
  pop DE                                ; Restore the screen pointer.
  pop BC                                ; And the counter.
  djnz RS_SCRN_LP                       ; Loop back for the 96 characters.
  ld C,B                                ; Stack the empty string (length zero).
RS_SCR_STO:                             ;
  ret                                   ; return, the accumulator holds the character code
                                        ;
; ---------------------------------------------------------------------
; sounds, click and bells               ;
; ---------------------------------------------------------------------
sound_click:                            ; This code if copied from ROM at 0f3b, part of the editor routine
  PUSH AF                               ; Save AF temporarily.
  LD D,$00                              ; Fetch the duration of the keyboard click (PIP)
  LD E,(IY-$01)                         ; Fetch the duration of the keyboard click
  LD HL,$00C8                           ; Fetch the Pitch
  call $03B5                            ; Call beeper
  POP AF                                ; Restore AF
  ret                                   ;
sound_click2:                           ;
  PUSH AF  
  ld DE, 5                              ;
  ld HL, 1300                           ;
  call $03B5                            ;
  POP AF
  ret                                   ;
                                        ;
sound_bell2:                            ;
  PUSH AF
  ld DE, 30                             ;
  ld HL, 2800                           ;
  call $03B5                            ;
  ld DE, 60                             ;
  ld HL, 1800                           ;
  call $03B5                            ;
  POP AF
  ret                                   ;
sound_error:                            ;
  ld DE, Song_error                     ;  
  call Play                             ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Backup and restore Screen             ;
; SCREEN_START = $4000                  ;
; SCREEN_SIZE =  $1aff                  ;
; ---------------------------------------------------------------------
backup_screen:                          ;
  ld a,(SCREEN_ID)                      ;
  cp 1                                  ;
  jp z, backup_pub_screen               ;
  jp backup_priv_screen                 ;
                                        ;
backup_pub_screen:                      ;
  ld a ,1                               ;
  ld (HAVE_PUB_BACKUP),a                ;
  ld hl, SCREEN_START                   ; start address of screen information + attributes information (like color)
  ld de, SCREEN_PUB_BACKUP              ; start address of the backup location
  ld bc, SCREEN_SIZE                    ; length of all data (pixels and attributes)
  ldir                                  ; copy bytes, HL= source, DE= Destination, BC=data Length
  ret                                   ;
                                        ;
restore_pub_screen:                     ;
  ld de, SCREEN_START                   ; start address of screen information + attributes information (like color)
  ld hl, SCREEN_PUB_BACKUP              ; start address of the backup location
  ld bc, SCREEN_SIZE                    ; length of all data (pixels and attributes)
  ldir                                  ; copy bytes, HL= source, DE= Destination, BC=data Length
  ret                                   ;
                                        ;
backup_priv_screen:                     ;
  ld a ,1                               ;
  ld (HAVE_PRV_BACKUP),a                ;
  ld hl, SCREEN_START                   ; start address of screen information + attributes information (like color)
  ld de, SCREEN_PRIV_BACKUP             ; start address of the backup location
  ld bc, SCREEN_SIZE                    ; length of all data (pixels and attributes)
  ldir                                  ; copy bytes, HL= source, DE= Destination, BC=data Length
  ret                                   ;
                                        ;
restore_priv_screen:                    ;
  ld de, SCREEN_START                   ; start address of screen information + attributes information (like color)
  ld hl, SCREEN_PRIV_BACKUP             ; start address of the backup location
  ld bc, SCREEN_SIZE                    ; length of all data (pixels and attributes)
  ldir                                  ; copy bytes, HL= source, DE= Destination, BC=data Length
  ret                                   ;
                                        ;
create_custom_chars:                    ; 
  ld HL,custom_chars                    ;
  ld DE,$FF58                           ;
  ld BC,8*14                            ;
  LDIR                                  ;
  ret                                   ;
                                        ;
create_custom_chars2:                   ;  After the start screen we need some other custom chars
  ld HL,custom_chars2                   ;
  ld DE,$FF60                           ;
  ld BC,8*19                            ;
  LDIR                                  ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Start Screen                          ;
; ---------------------------------------------------------------------
start_screen:                           ;
  ld HL,$4000                           ; Draw the thick lines on start screen
  ld a,255                              ; I could have done this by 'printing' the chracters to screen
  ld (HL),a                             ; but this is faster and I don't like to see the
  ld BC,$00c0-1                         ; screen building up at the start screen.
  ld DE,$4001                           ;
  ldir                                  ;
                                        ;
  ld HL,$4000                           ; Draw the thick lines on start screen
  ld DE,$4100                           ;
  ld BC,$00c0                           ;
  ldir                                  ;
                                        ;
  ld HL,$4000                           ; Draw the thick lines on start screen
  ld DE,$4200                           ;
  ld BC,$00c0                           ;
  ldir                                  ;
                                        ;
  ld HL,$4000                           ; Draw the thick lines on start screen
  ld DE,$4300                           ;
  ld BC,$00c0                           ;
  ldir                                  ;
                                        ;
  ld HL,$4000                           ; Draw the thick lines on start screen
  ld DE,$5040                           ;
  ld BC,$00c0                           ;
  ldir                                  ;
  ld HL,$4000                           ; Draw the thick lines on start screen
  ld DE,$5140                           ;
  ld BC,$00c0                           ;
  ldir                                  ;
                                        ;
  ld HL,$4000                           ; Draw the thick lines on start screen
  ld DE,$5240                           ;
  ld BC,$00c0                           ;
  ldir                                  ;
                                        ;
  ld HL,$4000                           ; Draw the thick lines on start screen
  ld DE,$5340                           ;
  ld BC,$00c0                           ;
  ldir                                  ;
                                        ;
  call open_channel_bottom              ; draw the stars on the bottom 3 lines
  ld DE, sc_lines2                      ;
  call PRNTIT                           ;
  call open_channel_top                 ;
  ld DE, sc_lines1                      ; draw the stars on the rest of the lines
  call PRNTIT                           ;
                                        ;
  ld DE,sc_big_text                     ; Draw the big text on the start screen
  call PRNTIT                           ;  
  ld DE, Song_start                     ;
  call Play                             ;                                      
                                        ;
sc_wait_for_key:                        ; Wait for a key press
  call animate_stars                    ;
  ld a,80                               ;
  ld (DELAY),a                          ;
  call jdelay                           ;
  call key_input                        ; Get last key pressed
  jp nc,sc_wait_for_key                 ; If C is clear, keep waiting for key press
  cp DELETE
  jp z,force_update
  ld a,0                                ;
  ld ($FFE1),a                          ;
  ret                                   ;
                                        ;
animate_stars:                          ; animate the stars by shifting the color attributes
                                        ; attributes start at $5800
                                        ; top lines go to the left
                                        ; LDIR = copy bytes, HL= source, DE= Destination, BC=data Length
  ld a, 6                               ;
  ld (TEMPI),a                          ;
  ld HL,$5800                           ; Start of the first line
as_loop:                                ;
  call as_shift_line_l                  ;
  ld HL,DE                              ;
  inc HL                                ;
  ld a, (TEMPI)                         ;
  dec a                                 ;
  ld (TEMPI),a                          ;
  cp 0                                  ;
  jp nz,as_loop                         ;
  jp as_loop2                           ;
                                        ;
as_shift_line_l:                        ;
  ld a,(HL)                             ;
  ld (TEMPBYTE),a                       ;
  ld DE,HL                              ;
  inc HL                                ;
  ld BC,31                              ;
  LDIR                                  ;
  ld a,(TEMPBYTE)                       ;
  ld (DE),a                             ;
  ret                                   ;
                                        ;
as_loop2:                               ;
  ld a, 6                               ;
  ld (TEMPI),a                          ;
  ld DE,$5AFF                           ; end of the LAST line
as_loop3:                               ;
  call as_shift_line_r                  ;
  dec HL                                ;
  dec DE                                ;
  ld a, (TEMPI)                         ;
  dec a                                 ;
  ld (TEMPI),a                          ;
  cp 0                                  ;
  jp nz,as_loop3                        ;
  ret                                   ;
                                        ;
as_shift_line_r:                        ;
                                        ; start at 5A60
                                        ; LDDR = copy bytes, HL= source, DE= Destination, BC=data Length
  ld BC,31                              ;
  ld a,(DE)                             ;
  ld (TEMPBYTE),a                       ;
  ld HL,DE                              ;
  dec HL                                ;
  LDDR                                  ;
  ld a,(TEMPBYTE)                       ;
  ld (DE),a                             ;
  ret                                   ;

; ---------------------------------------------------------------------
; Force an update.. or reload the firmware from the website.
; ---------------------------------------------------------------------
force_update:
  ld a,123                              ; set tempbyte to 123
  ld (TEMPBYTE),a                       ;
  call create_custom_chars2             ; create custom chars for the loading bar
  jp update_screen                      ; and jump directly to the update screen

; ---------------------------------------------------------------------
; Delay Routine                         ;
; ---------------------------------------------------------------------
jdelay:                                  ;
  ld a,(DELAY)                          ;
delay_loop0:                            ;
  ld b,255                              ;
delay_loop1:                            ;
  djnz delay_loop1                      ;
  dec a                                 ;
  jp nz,delay_loop0                     ;
  ret                                   ;
                                        ;
delay2:
  call jdelay
  call jdelay
  call jdelay
  ret
; ---------------------------------------------------------------------
;  Send a byte to the cartridge         ;
;  byte in A                            ;
; ---------------------------------------------------------------------
sendbyte:                               ;
  call wait_for_ready_to_receive        ; wait for ready to receive
  
  out (CARTRIDGE_IO),a                  ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
;  Wait for ready to receive            ;
;  Wait until the cartridge is ready to receive the next byte;
; ---------------------------------------------------------------------
wait_for_ready_to_receive:              ;
  push af                               ;
rtr_wait_loop                           ;
  in a,(CARTRIDGE_IO)                   ;
  and %10000000                         ;
  cp  %10000000                         ;
  jp nz,rtr_wait_loop                   ;
  pop af                                ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Send a command byte to the cartridge and wait for response;
; command in b                          ;
; ---------------------------------------------------------------------
send_start_byte_ff:                     ;
  ld a,0                                ;
  ld (RXINDEX),a                        ;
  ld (RXFULL),a                         ;
  ld a,b                                ;
  call sendbyte                         ;
wait_message_complete                   ;
  ld a,(RXFULL)                         ; load RXFULL flag
  cp 0                                  ; compare with zero
  jp z, wait_message_complete           ;
ret                                     ;
                                        ;
; ---------------------------------------------------------------------
; Save and restore cursor position      ;
; ---------------------------------------------------------------------
save_cur_pos:                           ;
  call get_cursor_colm                  ;
  ld a, (COLMPOS)                       ;
  ld (CURSPOSBACKUP),a                  ;
  ret                                   ;
restore_cur_pos:                        ;
  ld a,(LINEPOS)                        ;
  cp 1                                  ;
  jp z, rc_go_l1                        ;
  cp 2                                  ;
  jp z, rc_go_l2                        ;
  cp 3                                  ;
  jp z, rc_go_l3                        ;
  ret                                   ;
                                        ;
rc_go_l1:                               ;
  call open_channel_top                 ;
  ld a,AT : rst $10                     ;
  ld a,21 : rst $10                     ;
  jr rc_paper_and_ink                   ;
rc_go_l2:                               ;
  call open_channel_bottom              ;
  ld a,AT : rst $10                     ;
  ld a,0 : rst $10                      ;
  jr rc_paper_and_ink                   ;
rc_go_l3:                               ;
  call open_channel_bottom              ;
  ld a,AT : rst $10                     ;
  ld a,1 : rst $10                      ;
                                        ;
rc_paper_and_ink                        ;
  ld a,(CURSPOSBACKUP) : rst $10        ;
  ld a,PAPER : rst $10                  ;
  ld a,0 : rst $10                      ;
  ld a,INK :rst$10                      ;
  ld a,(INKCOLOR) : rst$10              ;
  ret                                   ;
                                        ;
;----------------------------------------------------------------------
;  check for messages                   ;
;----------------------------------------------------------------------
check_for_messages:                     ;
  ld a, (EMUMODE)                      ;
  cp 1                                  ;
  jp z, ch_exit                         ;
                                        ;
  ld a, ($5c79)                         ; check counter
  cp 1                                  ; if this counter is larger than 1
  jp p,do_check                         ; we check for messages
  ret                                   ;
                                        ;
do_check                                ;
  ld a, (SCREEN_ID)                     ;
  cp 1                                  ;
  jr z, do_check_pub                    ;
do_check_priv                           ;
  ld b, 247                             ; command code 247 = ask for private messages
  call send_start_byte_ff               ; after this call, the RXBUFFER contains:
  ld a,(RXBUFFER)                       ; 128 or a private message
  cp 128                                ; compare to 128
  jp z, no_message                      ;
  call display_message                  ; display the message
  jp ch_exit                            ;
do_check_pub                            ;
  ld b, 254                             ; command code 254 = ask for public messages
  call send_start_byte_ff               ; after this call, the RXBUFFER contains:
  ld a,(RXBUFFER)                       ; 128 or a message
  cp 128                                ;
  jp z, no_message                      ;
  call display_message                  ; display the message
  jp ch_exit                            ;
                                        ;
no_message                              ;
  ld a,0                                ; reset the counter
  ld ($5c79),a                          ;
  ld a,128                              ;
  ld ($5c78),a                          ;
  call check_for_updates                ;
                                        ;
  ld a, (SCREEN_ID)                     ; only on public screen
  cp 3                                  ; get the pm count
  jr z, ch_exit                         ;
  call get_pm_count                     ;
  call nz, display_pm_count             ;
                                        ;
ch_exit                                 ;
  ret                                   ;
                                        ;
;----------------------------------------------------------------------
; GET PM COUNT                          ;
;----------------------------------------------------------------------
get_pm_count:                           ;
  ld b,241                              ; command code 254 = ask for public messages
  call send_start_byte_ff               ; after this call, the RXBUFFER contains:
  ld HL,RXBUFFER                        ; "--" or "01" to "10"
  ld a,(HL)                             ; copy RXBUFFER to PMCOUNT
  ld DE,PMCOUNT                         ; just the first 2 characters
  ld (DE),a                             ;
  inc HL                                ;
  inc DE                                ;
  ld a,(HL)                             ;
  ld (DE),a                             ;
  ret                                   ;
                                        ;
display_pm_count:                       ;
  ld DE,PMCOUNT +1                      ;
  ld a,(DE)                             ;
  cp '-'                                ;
  jr z, pm_zero                         ;
  ld HL,text_pm_count                   ;
  ld d,20                               ;
  ld e,20                               ;
  call Print_String                     ;
  ld d,20                               ;
  ld e,20                               ;
  CALL Get_Char_Address                 ; get the screen adddress
  ld HL,$ffa0                           ; address of custom chat -[
  ld b,8                                ;
  call Print_Char_91                    ;
  ld d,20                               ;
  ld e,26                               ;
  CALL Get_Char_Address                 ;
  ld HL,$ffa8                           ; address of custom chat ]-
  ld b,8                                ;
  call Print_Char_91                    ;
  ret                                   ;
                                        ;
                                        ;
Print_Char_91:                          ;
  LD A,(HL)                             ; Get the byte from the ROM into A
  LD (DE),A                             ; Stick A onto the screen
  INC HL                                ; Goto next byte of character
  INC D                                 ; Goto next line on screen
  DJNZ Print_Char_91                    ; Loop around whilst it is Not Zero (NZ)
  ret                                   ;
                                        ;
                                        ;
pm_zero:                                ;
  ld HL,text_pm_count0                  ;
  ld d,20                               ;
  ld e,20                               ;
  call Print_String                     ;
  ld HL,$5380                           ;
  ld (HL),255                           ;
  ld DE,HL                              ;
  inc DE                                ;
  ld BC, 31                             ;
  LDIR                                  ;
  ld HL,$5480                           ;
  ld (HL),255                           ;
  ld DE,HL                              ;
  inc DE                                ;
  ld BC, 31                             ;
  LDIR                                  ;
  ld DE,PMCOUNT                         ;
  ld a,"-"                              ;
  ld (DE),a                             ;
  inc DE                                ;
  ld (DE),a                             ;
  ret                                   ;
;----------------------------------------------------------------------
; insert a message                      ;
; message is in RXBUFFER                ;
;----------------------------------------------------------------------
display_message:                        ;
                                        ;
  ld a, (SCREEN_ID)                     ;
  cp 1                                  ;
  jr z, dm_pub_sound                    ;
                                        ;
dm_priv_sound:                          ;
  ld DE, Song_nm                        ;
  call Play                             ;
  jr dm_continue                        ;
dm_pub_sound:                           ;
  ld DE, Song_nm                        ;
  call Play                             ;
                                        ;
dm_continue                             ;
  ld a,(RXBUFFER)                       ; the first byte in RXBUFFER is the number of lines
scr_loop                                ;
  push af                               ;
  call scroll_up                        ;
  pop af                                ;
  dec a                                 ;
  cp 0                                  ;
  jp nz, scr_loop                       ;
                                        ;
  call save_cur_pos                     ; save cursor position
  call open_channel_top                 ;
  ld de,RXBUFFER                        ;
  inc DE                                ; skip the first byte
  call PRNTIT                           ;
                                        ;
dm_skip                                 ;
  call restore_cur_pos                  ; restore cursor position
                                        ;
  ld a,1                                ; reset the counter to check again quick!
  ld ($5c78),a                          ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Key input routine                     
; This is a very short version of the ROM routine at $10A8
; This version prevents the user from changing the cursor Mode
; ---------------------------------------------------------------------
key_input:                              ;
  ccf                                   ;
  ld a, (INKEY)                         ; INKEY is a key we received from an external keyboard
  cp 0                                  ; see if it is zero
  jp z, check_MN                        ; if so, scan the internal keyboard
  push af                               ; if we did get a key from the external keyboard
  ld a,0                                ; load it into the accumulator
  ld (INKEY) ,a                         ; 
  pop af                                ;                                 
  RET                                   ;  
                                        ;
key_in                                  ;
  BIT 5,(IY+$01)                        ; Return with both carry and zero flags reset if no new key has
  jr z, exit_key                        ;   
  LD A,($5C08)                          ; Otherwise fetch the code (LAST-K) and signal that it has been
  RES 5,(IY+$01)                        ; taken (reset bit 5 of FLAGS).
  cp "M"                                ;
  jp z, exit_key                        ;
  cp "N"                                ;
  jp z, exit_key                        ;
  call sound_click                      ;
  PUSH AF                               ;
  ld a,0                                ;
  ld(LASTM),a                           ; 
  ld(LASTN),a                           ;
  POP AF                                ;
  SCF                                   ; Show a code has been found and return.
  RET                                   ;
exit_key                                ; 
  RET                                   ;
                                        ;
check_MN:                               ; This is to work around a bug in 128 machines                                        
  LD BC, $FEFE                          ; running in 48k mode, M and N respond intermittent to key strokes
  IN A,(C)                              ; 
  AND 31                                ;
  CP 30                                 ; is shift pressed?
  jp z,checkM                           ; yes?, check M key  
  ld a,0                                ; clear a
  jp key_in                             ; no? , return                                           
                                        ;
checkM:                                 ; This is to work around a bug in 128 machines   
  ld BC, $7FFE                          ; running in 48k mode, M and N respond intermittent to key strokes
  IN A,(C)                              ;
  AND 31                                ;
  CP 27                                 ;
  jp nz, checkN                         ;  
  ld a,(LASTM)                          ;
  cp 1                                  ;
  jp z, release_m                       ;
  ld a,1                                ;
  ld (LASTM),a                          ;
  call sound_click                      ;
  ld a,"M"                              ;
  RES 5,(IY+$01)                        ;
  SCF                                   ;
  RET                                   ;
                                        ;
release_m:                              ; This is to work around a bug in 128 machines 
  ld a,0                                ; running in 48k mode, M and N respond intermittent to key strokes
  ld(LASTM),a                           ;
  ld BC, $7FFE                          ;
  IN A,(C)                              ;
  AND 31                                ;
  CP 27                                 ; 
  jp z, release_m                       ;
  ld a,100                              ;
  ld (DELAY),a                          ;
  CALL jdelay                           ;
  ld a,0                                ;
  ccf                                   ;
  RET                                   ;
                                        ;
checkN:                                 ; This is to work around a bug in 128 machines 
  ld BC, $7FFE                          ; running in 48k mode, M and N respond intermittent to key strokes
  IN A,(C)                              ;
  AND 31                                ;
  CP 23                                 ;
  jp nz, key_in                         ;  
  ld a,(LASTN)                          ;
  cp 1                                  ;
  jp z , release_N                      ;
  ld a,1                                ;
  ld (LASTN),a                          ;
  call sound_click                      ;
  ld a,"N"                              ;
  RES 5,(IY+$01)                        ;
  SCF                                   ;
  RET                                   ;
                                        ;
release_N:                              ; This is to work around a bug in 128 machines 
  ld a,0                                ; running in 48k mode, M and N respond intermittent to key strokes
  ld(LASTN),a                           ;
  ld BC, $7FFE                          ;
  IN A,(C)                              ;
  AND 31                                ;
  CP 23                                 ;
  jp z, release_N                       ; 
  ld a,100                              ;
  ld (DELAY),a                          ;
  CALL jdelay                           ;
  ld a,0                                ;
  ccf                                   ;
  RET                                   ;
                                        ;
LASTM: DB 0                             ;
LASTN: DB 0                             ;
; ---------------------------------------------------------------------
; SUB ROUTINE TO SPLIT RXBUFFER         ;
; A = element to keep                   ;
; ---------------------------------------------------------------------
splitRXbuffer:                          ;
  ld b,a                                ; RXBUFFER now contains FOR EXAMPLE macaddress[129]regid[129]nickname[129]regstatus[128]
  ld DE, RXBUFFER                       ;
  ld HL, SPLITBUFFER                    ;
sb_read                                 ; read a byte from the buffer
  ld a, (DE)                            ; copy that byte to the split buffer
  ld (HL),a                             ; until we find byte 129 or 128
  cp 129                                ;
  jp z, foundEnd                        ;
  cp 128                                ;
  jp z, foundEnd                        ;
  inc DE                                ;
  inc HL                                ;
  jp sb_read                            ;
                                        ;
foundEnd                                ;
  ld a,128                              ;
  ld (HL),a                             ; load 128 (the end byte) into the splitbuffer
  dec b                                 ; decrease b. b holds a number that indicates the item we need
  jp z,sb_exit                          ;
  inc DE                                ;
  ld HL,SPLITBUFFER                     ;
  jp sb_read                            ;
                                        ;
sb_exit                                 ;
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Check for updates                     ;
; ---------------------------------------------------------------------
check_for_updates:                      ;
  ld a, (CHECK_UPDATE)                  ;
  cp 0                                  ;
  jr z, cu_exit                         ;
  cp 2                                  ;
  jr z, cu_exit                         ;
                                        ;
                                        ;
  ld b, 239                             ; command code 239 = ask if updates are available
  call send_start_byte_ff               ; after this call, the RXBUFFER contains:
  ld a,(RXBUFFER)                       ; 128 or new version numbers
  cp 128                                ;
  jr z, cu_exit                         ;
  ld HL,RXBUFFER                        ; copy the new versions to the variables
  ld DE,NEW_ROM                         ;
  ld BC,4                               ;
  LDIR                                  ;
  inc HL                                ;
  ld DE,NEW_ESP                         ;
  ld BC,4                               ;
  LDIR                                  ;
  call save_cur_pos                     ;
  call scroll_up                        ; 
  call scroll_up                        ; 
  ld DE, sysmessage_update              ;
  CALL PRNTIT                           ;
  ld a, 2                               ;
  ld (CHECK_UPDATE),a                   ;
  ld DE, Song_update                    ;
  call Play                             ;                                      
  call restore_cur_pos                  ;
cu_exit                                 ;
  ret                                   ;

; ---------------------------------------------------------------------
; wait for any key                      ;
; ---------------------------------------------------------------------
wait_any_key:                           ;
  call key_input                        ;
  jr nc,wait_any_key                    ;
  ret                                   ;
; ---------------------------------------------------------------------
; Print a single character out to a screen address;
;  A: Character to print                ;
;  D: Character Y position              ;
;  E: Character X position              ;
; ---------------------------------------------------------------------
Print_Char:                             ;
  LD HL, $3C00                          ; Character set bitmap data in ROM
  LD B,0                                ; BC = character code
  LD C, A                               ;
  SLA C                                 ; Multiply by 8 by shifting
  RL B                                  ;
  SLA C                                 ;
  RL B                                  ;
  SLA C                                 ;
  RL B                                  ;
  ADD HL, BC                            ; And add to HL to get first byte of character
  CALL Get_Char_Address                 ; Get screen position in DE
  LD B,8                                ; Loop counter - 8 bytes per character
Print_Char_L1                           ;
  LD A,(HL)                             ; Get the byte from the ROM into A
  LD (DE),A                             ; Stick A onto the screen
  INC HL                                ; Goto next byte of character
  INC D                                 ; Goto next line on screen
  DJNZ Print_Char_L1                    ; Loop around whilst it is Not Zero (NZ)
  RET                                   ;
                                        ;
; ---------------------------------------------------------------------
; Get screen address from a character (X,Y) coordinate;
; D = Y character position (0-23)       ;
; E = X character position (0-31)       ;
; Returns screen address in DE          ;
; ---------------------------------------------------------------------
Get_Char_Address:                       ;
  LD A,D                                ;
  AND %00000111                         ;
  RRA                                   ;
  RRA                                   ;
  RRA                                   ;
  RRA                                   ;
  OR E                                  ;
  LD E,A                                ;
  LD A,D                                ;
  AND %00011000                         ;
  OR %01000000                          ;
  LD D,A                                ;
  RET                                   ; Returns screen addr
                                        ;
;----------------------------------------------------------------------
; My print routine                      ;
; HL: Address of the string             ;
;  D: Character Y position              ;
;  E: Character X position              ;
;----------------------------------------------------------------------
Print_String:                           ;
  LD A, (HL)                            ; Get the character
  CP 128                                ; CP with 0
  RET Z                                 ; Ret if it is zero
  INC HL                                ; Skip to next character in string
  CP 32                                 ; CP with 32 (space character)
  JR C, Print_String                    ; If < 32, then don't ouput
  PUSH DE                               ; Save screen coordinates
  PUSH HL                               ; And pointer to text string
  CALL Print_Char                       ; Print the character
  POP HL                                ; Pop pointer to text string
  POP DE                                ; Pop screen coordinates
  INC E                                 ; Inc to the next character position on screen
  JR Print_String                       ; Loop
  ret                                   ;
                                        ;
; ---------------------------------------------------------------------
; Play Song Routine                           
; Point to the sond in DE
; ld   DE, Song_2  ; point to the song
; ---------------------------------------------------------------------
Play:                                   ;
        ld   (ptrSound), DE             ;
p2                                      ;
        ld   hl, (ptrSound)             ; point to the song
        ld   e, (hl)                    ; load frequency in DE
        inc  hl                         ;
        ld   d, (hl)                    ; DE now contains frequency
        ld   a, d                       ;
        or   e                          ; if DE NOT contains $0000, continue    
        jr   nz, play_cont              ;
        ret                             ;
                                        ;
play_cont                               ;
        inc  hl                         ;
        ld   c, (hl)                    ;
        inc  hl                         ;
        ld   b, (hl)                    ;
        inc  hl                         ;
        ld   (ptrSound), hl             ;
        ld   h, b                       ;
        ld   l, c                       ;
        call $03B5                      ;
        jr p2                           ;
                                        ;
; ---------------------------------------------------------------------
; NMI Routine                           ;
; ---------------------------------------------------------------------
nmi_routine:                            ;
  in a, (CARTRIDGE_IO)                  ;
  cp 201                                ;
  jr nz,nmi_no_key                      ;
  ld a,100                              ;
  ld (DELAY),a                          ;
  call jdelay                           ;
  in a, (CARTRIDGE_IO)                  ;
  ld (INKEY),a                          ;
  jr exit_nmi                           ;
                                        ;
nmi_no_key                              ;
  ld a,(RXINDEX)                        ;
  ld c,a                                ;
  ld b,0                                ;
  ld de, RXBUFFER                       ;
  add de,bc                             ;
                                        ;
  in a,(CARTRIDGE_IO)                  ; read a byte from the cartridge
                                        ;
  ld (de),a                             ;
  cp 128                                ;
  jp z,message_complete                 ;
  ld a,c                                ;
  inc a                                 ;
  ld (RXINDEX),a                        ;
  jr exit_nmi                           ;
                                        ;
message_complete                        ;
  ld a,(RXINDEX)                        ;
  cp 0                                  ;
  jp nz, not_empty                      ;
  ld a, 2                               ;
  ld (RXFULL),a                         ;
  jr exit_nmi                           ;
                                        ;
not_empty                               ;
  ld a, 1                               ; Store #1 in the RXFULL indicator
  ld (RXFULL),a                         ;
                                        ;
exit_nmi                                ;
  pop iy                                ;
  pop ix                                ;
  pop hl                                ;
  pop de                                ;
  pop bc                                ;
  pop af                                ;
  retn                                  ; return from interrupt routine!
                                        ;
; ---------------------------------------------------------------------
; Static text lines                      
; ---------------------------------------------------------------------
VERSION:  .BYTE "3.79",128  // ALSO CHANGE VERSION IN COMMON.H, 
                         // AND ALSO CHANGE DATE IF NEEDED
                           
NOCART: DB AT,5,5,INK,red,PAPER,0,BRIGHT,1,"Cartridge not installed",128

DLINE: DB AT, 20,0, INK, white, PAPER, 0, BRIGHT,0
  BLOCK 32,$90                          ;
  DB 128                                
  
MLINES: DB AT,  0,0, INK, green, PAPER, 0, BRIGHT,1
  BLOCK 32,$90                          
  DB AT,  2,0  
  BLOCK 32,$90                          
  DB AT, 20,0  
  BLOCK 32,$90                          
  DB 128                                

; Menu titles  
MLINES_MAIN:    DB AT, 1,10, INK, yellow,BRIGHT,1,"MAIN MENU",128
MLINES_WIFI:    DB AT, 1,10, INK, yellow,BRIGHT,1,"WiFi SETUP",128
MLINES_SERVER:  DB AT, 1,9, INK, yellow,BRIGHT,1,"SERVER SETUP",128
MLINES_ACCOUNT: DB AT, 1,8, INK, yellow,BRIGHT,1,"ACCOUNT SETUP",128
MLINES_ABOUT:   DB AT, 1,9, INK, yellow,BRIGHT,1,"ABOUT CHAT64",128
MLINES_HELP:    DB AT, 1,13, INK, yellow,BRIGHT,1,"HELP",128
MLINES_USERS:   DB AT, 1,10, INK, yellow,BRIGHT,1,"USER LIST",128
MLINES_PRIVATE: DB AT, 0,0,INK,green,BRIGHT,0,PAPER,0,"private messaging               ",AT,1,0;
  BLOCK 32,$9c
  DB AT, 0,0,OVER,1
  BLOCK 32,$9c
  DB OVER,0,128
 
MLINES_UPDATE:  DB AT, 1,7, INK, yellow,BRIGHT,1,"UPDATE AVAILABLE"
                DB AT, 5,0,INK,white,BRIGHT,0,"There is a new version availableDo you want to upgrade? ",INK,green,BRIGHT,1,"Y/N"
                DB AT, 8,0,INK,white,BRIGHT,0,"New ROM version: ",INK,green,BRIGHT,1
NEW_ROM:        DB "x.xx"                                
                DB AT, 9,0,INK,white,BRIGHT,0,"New ESP version: ",INK,green,BRIGHT,1
NEW_ESP:        DB "y.yy"
                DB 128
                
                                        
ABOUTPAGE: DB AT,4,0,INK,white,BRIGHT,1,"Initially developed by Bart as a"
  DB "proof of concept on Commodore 64",13,13,"A new version "
  DB "of CHAT64 is now available to everyone.",13
  DB "We proudly bring you Chat64 on  ZX Spectrum!",13,13
  DB "Made by Bart Venneker and Theo  van den Belt in 2024"
  DB 13,13,"Hardware, software and manuals  are available on Github"
  DB 13,13,"github.com/bvenneker/Chat64-for-ZX-Spectrum"
  DB AT,21,5,INK,cyan,"[7] Exit to main menu",128
           

HELPPAGE: DB AT,3,0,INK,red,BRIGHT,1,$91,$92,$93,$94
  DB INK,white,BRIGHT,1,"+ Q = Main menu",13,INK,red,BRIGHT,1,$95,$96,$97,$98
  DB AT,5,0,INK,red,BRIGHT,1,$91,$92,$93,$94
  DB INK,white,BRIGHT,1,"+ I = Change ink color",13,INK,red,BRIGHT,1,$95,$96,$97,$98,INK,white,BRIGHT,1,"      follow with 1-7"
  DB AT,7,0,INK,red,BRIGHT,1,$91,$92,$93,$94
  DB INK,white,BRIGHT,1,"+ S = Send message",13,INK,red,BRIGHT,1,$95,$96,$97,$98,INK,white,BRIGHT,1,"      or enter on third line"
  DB AT,9,0,INK,red,BRIGHT,1,$91,$92,$93,$94
  DB INK,white,BRIGHT,1,"+ W = Toggle between Public",13,INK,red,BRIGHT,1,$95,$96,$97,$98,INK,white,BRIGHT,1,"      and Private messages"
  DB 13,13,"In private mode, start your message with @Username to send a message to that user"
  DB 13,13,"Start your message with",INK,red," @Eliza  ",INK,white,"to chat with our I.A. Chatbot"
  DB AT,21,5,INK,cyan,"[7] Exit to main menu",128

MHELPLINE: DB AT, 19,0,INK, white,PAPER,0,BRIGHT,1,"Press ",INK,2,$95,$96,$97,$98,INK,white,"+Q for menu";
  DB AT, 18,6,INK,2,$91,$92,$93,$94,128



MLINE_MAIN1:   DB AT, 5,2,INK, cyan, BRIGHT,1, "[1] WiFi Setup",128
MLINE_MAIN2:   DB AT, 7,2,INK, cyan, BRIGHT,1, "[2] Account Setup",128
MLINE_MAIN3:   DB AT, 9,2,INK, cyan, BRIGHT,1, "[3] Server Setup",128
MLINE_MAIN4:   DB AT, 11,2,INK, cyan, BRIGHT,1,"[4] User List",128
MLINE_MAIN5:   DB AT, 13,2,INK, cyan, BRIGHT,1,"[5] Help",128
MLINE_MAIN6:   DB AT, 15,2,INK, cyan, BRIGHT,1,"[6] About this software",128
MLINE_MAIN7:   DB AT, 17,2,INK, cyan, BRIGHT,1,"[7] Exit",128
MLINE_SAVE:    DB AT, 15,2,INK, cyan, BRIGHT,1,"[1] Save Settings  ",128
MLINE_CHANGE:  DB AT, 15,2,INK, cyan, BRIGHT,1,"[1] Change Settings",128
MLINE_VERSION: DB AT, 0,0,INK,yellow,BRIGHT,1, "Version ROM x.xx, ESP 3.76  "
VERSION_DATE:  DB AT, 0,27,"06/25",128
                                                                                                  
sysmessage_update: DB AT,18,0,INVERSE,1,INK,green,BRIGHT,1,"New version available,          ",13,"press [symbol-shift] + Q        ",INVERSE,0,128

WFSSID: DB AT, 4,1,INK,7,"SSID:", AT,6,1,"Password:",AT ,8,1,"Time offset from GMT:", AT,10,0,INK,green
  BLOCK 32,$90
  DB 128                                
  
SERVERSETUP: DB AT, 4,1,INK,7,"Server:", AT,6,1,"Example 'www.chat64.nl'", AT,8,0,INK,green
  BLOCK 32,$90                          ;
  DB 128                                
  
ACCOUNTSETUP: DB AT, 4,1,INK,7,"MAC Address:", AT,6,1,"Reg ID:",AT ,8,1,"Nick Name:", AT,10,0,INK,green;
  BLOCK 32,$90                          ;
  DB AT, 15,2,INK, cyan, BRIGHT,1,   "[6] Reset to factory defaults"
  DB AT, 13,2,"[1] Change Settings",128
              
RESETLINES: DB AT, 1,8,INK,yellow,BRIGHT,1,"RESET CARTRIDGE?"
  DB AT, 5,0,INK, red, BRIGHT,1,"WARNING:", INK,7,"This will reset your    cartridge to factory defaults"
  DB ",  you will need to go through the setup and registration process  again",13,13,"Continue with reset? (y/n)"
  DB 128                                

USERLISTMENU: DB AT,21,0,INK, cyan,BRIGHT,1,"[p] previous  [n] next  [7] Exit",128
CURSOR_LINE1: DB AT, 21,0,PAPER,0,INK,white,128
CURSOR_LINE2: DB AT, 0,0,128
CURSOR_LINE3: DB AT, 1,0,128
                                        
text_unreg_error: DB AT,21,0,INK,2,"Error: Unregistered Cartridge",128
text_name_taken:  DB AT,21,0,INK,2,"Error: nickname already taken",128
text_registration_ok: DB AT,21,0,INK,4,"Registration was successful", 128
text_reset: DB "RESET!",128
text_update: DB "UPDATE!",128
                                        ;
PM_ERROR:   DB AT, 3,0,INK,red,BRIGHT,1,PAPER,0,"Message should start with '@'   ",AT,2,0
  BLOCK 32,$90  
  DB AT,4,0 
  BLOCK 32,$90 
  DB 128 
            
PM_ERROR2:  DB AT, 3,0,INK,red,BRIGHT,1,PAPER,0,"  Do not send private messages  "
  DB AT, 4,0,"     from the public screen!    ",AT,2,0
  BLOCK 32,$90                          
  DB AT,5,0                             
  BLOCK 32,$90                          
  DB 128                                

update_bar: DB AT,11,0,INVERSE,0,PAPER,black,BRIGHT,0,INK,yellow,"Installing new firmware:"                                        
  DB AT,13,0,BRIGHT,0,INK,white,$A0                                        
  BLOCK 30,$9B
  DB $A2,AT,14,0,BRIGHT,0,INK,white,$9D,INVERSE,0,"                              ",INVERSE,0,$9E
  DB AT,15,0,BRIGHT,0,INK,white,$A1
  BLOCK 30,$9c
  DB $A3,128

FAKECHAT: DB AT, 0,0,INK, white, "and how solve it in your case?  "
          DB         INK,yellow, "25-06-11 09:20 Outsoft-ZX:      "
          DB         INK, white, "what was repaired?              "
          DB         INK,yellow, "25-06-11 09:21 IDLab:           "
          DB         INK, white, "The OSC additions I am Making ne"
          DB         INK, white, "eds to add UDP protocol to the W"
          DB         INK, white, "iFi module, somehow that broke t"
          DB         INK, white, "he whole init sequence          "
          DB         INK,yellow, "25-06-11 09:22 IDLab:           "
          DB         INK, white, "But It's all better now :)      "
          DB         INK,yellow, "25-06-11 09:23 Outsoft-ZX:      "
          DB         INK, white, "ah...in case we need to repair u"
          DB         INK, white, "s too :-)                       "
          DB         INK,yellow, "25-06-11 16:39 Outsoft-ZX:      "
          DB         INK, white, "Hi Theo, all OK?                "
          DB         INK,yellow, "25-06-11 16:57 IDLab:           "
          DB         INK, white, "yes, am a happy camper, my code "
          DB         INK, white, "is coming along nicely          "
          DB         INK,yellow, "25-06-11 16:58 IDLab:           "
          DB         INK, white, "oh, that was for Theo XD        "
          DB 128 

FAKECHAT2: DB AT, 2,0,INK, white,"seems to work great!            "
          DB         INK,yellow, "25-06-11 18:37 @Eliza           "
          DB         INK, white, "what is the best game for the ZX"
          DB         INK, white, "Spectrum 48k?                   "
          DB         INK,yellow, "25-06-11 18:37 from Eliza       "
          DB         INK, white, "Oh honey, it's gotta be Elite! T"
          DB         INK, white, "hat game was out of this galaxy,"
          DB         INK, white, " space trader, action-packed and"
          DB         INK, white, " pure genius                    "
          DB         INK,yellow, "25-06-11 09:23 @Eliza           "
          DB         INK, white, "But what about Jetpack?         "
          DB         INK,yellow, "25-06-11 18:38 from Eliza       "
          DB         INK, white, "jetpack was a close call, darlin"
          DB         INK, white, "g! classic platformer, so addict"
          DB         INK, white, "ive, but elite had that somethin"
          DB         INK, white, "g special. still, jetpack       "
          DB         INK, white, "is a zx spectrum staple, sweet m"
          DB         INK, white, "emory!                          "
          DB 128 
FAKELIST: DB AT, 4,0,INK,white,  "  huijaa        IDLab           "  
          DB         INK,white,  "  JaredD        Jeroen          "  
          DB         INK,white,  "  Jeroen64      ",INK,green,"Joost           "
          DB         INK,white,  "  Jimmy Z       JK2247          "
          DB         INK,white,  "  k5DMG         Kiba            "
          DB         INK,green,  "  Lektroid      Ma130XE         "
          DB         INK,white,  "  Marco         MarCom          "
          DB         INK,white,  "                                "
          
          DB         INK,white,  "  Mcichel       ",INK,green,"MarNext         "
          DB         INK,white,  "  McFritsch     Mylzi           "
          DB         INK,white,  "  NML32         Nopkes          "
          DB         INK,white,  "  Outsoft-XL    OutSoft-64      "
          DB         INK,white,  "  Outsoft-ZX    Pantera         "
          DB         INK,green,  "  Pedro         ",INK,white,"Paul3D          "
          DB         INK,white,  "  Peri          Peter           "
          DB 128
text_update_done: DB AT,17,0,BRIGHT,1,INK,yellow,INVERSE,0,"Update done!",128            
                                                                     
black:   .equ %000000    
blue:    .equ %000001    
red:     .equ %000010    
magenta: .equ %000011    
green:   .equ %000100    
cyan:    .equ %000101    
yellow:  .equ %000110    
white:   .equ %000111    
                          
pBlack:  .equ black   << 3
pBlue:   .equ blue    << 3
pRed:    .equ red     << 3
pMagenta:.equ magenta << 3
pGreen:  .equ green   << 3
pCyan:   .equ cyan    << 3
pYellow: .equ yellow  << 3
pWhite:  .equ white   << 3
bright:  .equ %1000000   
                                        
custom_chars:                               ; these are only used in the start screen
  DB 0,0,0,255,255,0,0,0                    ; Stripe $90
  DB 3, 15, 12, 24, 24, 24, 24, 24          ; boogje links boven $91
  DB 192, 240, 48, 24, 24, 24, 24, 24       ; boogje rechts boven $92
  DB 24, 24, 24, 24, 24, 12, 15, 3          ; boogle links onder  $93
  DB 24, 24, 24, 24, 24, 48, 240, 192       ; boogje rechts onder $94
  DB 24, 24, 24, 24, 24, 24, 24, 24         ; recht opstaande streep $95
  DB 255, 255, 24, 24, 24, 24, 24, 24       ; T stuk $96
  DB 24, 24, 24, 31, 31, 24, 24, 24         ; T stuk rechtsaf $97
  DB 24, 24, 24, 248, 248, 24, 24, 24       ; T stuk Linksaf $98
  DB 255, 255, 0, 0, 0, 0, 0, 0             ; dikke lijn bovenin $99
  DB 0, 0, 0, 192, 240, 48, 24, 24          ; boogje mid rechts boven $9A
  DB 24, 24, 12, 15, 3, 0, 0, 0             ; boogje mid links onder $9B
  DB 0, 0, 0, 0, 0, 0, 255, 255             ; Dikke streep onder $9C
                                            ;
custom_chars2:                            
  DB 0,127,128,186,162,185,137,185          ; tiles for symbol shift key image $91
  DB 0,255,0,162,182,42,34,34               ; tiles for symbol shift key image $92
  DB 0,255,0,196,170,202,170,228            ; tiles for symbol shift key image $93
  DB 0,240,8,136,136,136,136,232            ; tiles for symbol shift key image $94
  DB 128,135,132,135,129,135,128,127        ; tiles for symbol shift key image $95
  DB 0,74,74,122,74,74,0,255                ; tiles for symbol shift key image $96
  DB 0,238,132,196,132,132,0,255            ; tiles for symbol shift key image $97
  DB 8,8,8,8,8,8,8,240                      ; tiles for symbol shift key image $98
  DB  56, 32, 32, 224, 224, 32, 32, 56      ; -[    $99
  DB  28, 4, 4, 7, 7, 4, 4, 28              ; ]-    $9a                                                                             
  DB 0, 0, 0, 0, 0, 0, 0, 255               ; up    $9b                                              
  DB 255,0,0,0,0,0,0,0                      ; down  $9c
  DB 1,1,1,1,1,1,1,1                        ; left  $9d
  DB 128, 128, 128, 128, 128, 128, 128, 128 ; right $9e
  DB 0, 126, 126, 126, 126, 126, 126, 0     ; fill  $9f
  DB 0,0,0,0,0,0,0,1                        ; corner pixel1 $a0
  DB 1, 0, 0, 0, 0, 0, 0, 0                 ; corner pixel2 $a1
  DB 0, 0, 0, 0, 0, 0, 0, 128               ; corner pixel3 $a2
  DB 128, 0, 0, 0, 0, 0, 0, 0               ; corner pixel2 $a3
  
                                        
sc_lines1: DB PAPER,black            
  DB AT, 14,6,INK,white,BRIGHT,1,"for the ZX Spectrum",13,13,"  Made by Bart & Theo in 2024"
  DB AT, 1,2,INK,yellow,BRIGHT,0,131,AT,1,9,131,BRIGHT,1,131,BRIGHT,0,131,AT,1,19,131,AT,1,25,131
  DB AT, 2,1,131,BRIGHT,1,131,BRIGHT,0,131,AT,2,10,131,AT,2,18,131,INK,white,131,INK,yellow,131,AT,2,24,131,BRIGHT,1,131,BRIGHT,0,131
  DB AT, 3,0,131,131,INK,white,131,INK,yellow,131,BRIGHT,0,131, AT,3,14,131,AT,3,19,131,AT,3,25,131,INK,white,131,131,INK,yellow,131
  DB AT, 4,1,131,BRIGHT,1,131,BRIGHT,0,131, AT,4,13,131,BRIGHT,1,131,BRIGHT,0,131,AT,4,27,INK,yellow,131,INK,white,BRIGHT,1,131,INK,yellow,BRIGHT,0,131
  DB AT, 5,2,131,AT,5,14,131,AT,5,28,131
  DB AT, 18,2,131,AT,18,10,131,AT,18,25,131
  DB AT, 19,1,BRIGHT,0,131,BRIGHT,1,131,BRIGHT,0,131,AT,19,9,131,BRIGHT,1,131,BRIGHT,0,131,AT,19,18,131,AT,19,24,BRIGHT,1,131,INK,white,131,INK,yellow,131
  DB AT, 20,2,BRIGHT,0,131,AT, 20,8,INK,yellow,131,BRIGHT,1,131,INK,white,131,INK,yellow,131,BRIGHT,0,131,AT,20,17,131,131,131,AT,20,25,BRIGHT,1,131
  DB AT, 21,4,BRIGHT,0,131,AT,21,9,131,BRIGHT,1,131,BRIGHT,0,131,AT,21,18,131,AT,0,10,131
  DB 128                                
                                        
sc_lines2: DB PAPER,black,INK,white,BRIGHT,0
  DB AT, 0,3,INK,yellow,131,BRIGHT,1,131,BRIGHT,0,131,AT,0,10,131
  DB AT, 1,4,131,128                                                       
                                        
sc_big_text: DB AT,8,0,INK,green       
  DB INK,red,BRIGHT,1,32,32,32,32,$91,$99,$99,$92,$95,$20,$20,$95,$91,$99,$99,$92,$99,$96,$99,$20,$91,$99,$99,$92,$95,13
  DB INK,red,BRIGHT,0,32,32,32,32,$95,32,32,32,$95,32,32,$95,$95,32,32,$95,32,$95,32,32,$95,32,32,32,$95,32,32,$95,13
  DB INK,yellow,32,32,32,32,$95,32,32,32,$97,$90,$90,$98,$97,$90,$90,$98,32,$95,32,32,$97,$90,$90,$9A,$9B,$90,$90,$98,13
  DB INK,green,32,32,32,32,$95,32,32,32,$95,32,32,$95,$95,32,32,$95,32,$95,32,32,$95,32,32,$95,32,32,32,$95,13
  DB INK,cyan,BRIGHT,1,32,32,32,32,$93,$9C,$9C,$94,$95,$20,$20,$95,$95,$20,$20,$95,$20,$95,32,32,$93,$9C,$9C,$94,32,32,32,$95
  DB 128                                

key2ascii: 
  DB ".",0,0,0,0,0,0,0,0          ;   0 -   8
  DB 0,"V",0,0,0,0,"v",0          ;   9 -  16
  DB 0,"C",0,47,0,"X","c","Z"     ;  17 -  24
  DB 0,0,"x","?","z",0,0,"#"      ;  25 -  32
  DB "?",":",0,0,$60,0,":",0      ;  33 -  40
  DB 0,"G",0,0,0,0,"g",0          ;  41 -  48
  DB 0,"F",0,"]",0,"D","f","S"    ;  49 -  56
  DB "A",0,"d","[","s","a",0,92   ;  57 -  64
  DB 0,$C3,$E2,0,0,0,0,0          ;  65 -  72
  DB 0,"T",0,0,0,0,"t",0          ;  73 -  80
  DB 0,"R",0,">",0,"E","r","W"    ;  81 -  88
  DB "Q",0,"e","<","w","q",0,0    ;  82 -  96
  DB 0,0,$C7,0,0,0,0,0            ;  97 - 104 
  DB 0,$08,0,0,0,0,"5",0          ; 105 - 112
  DB 0,"$",0,"%",0,"#","4","@"    ; 113 - 120
  DB "!",0,"3","$","2","1",0,"#"  ; 121 - 128
  DB 0,"@","!",0,0,0,0,0          ; 129 - 136
  DB 0,$0A,0,0,0,0,"6",0          ; 137 - 144
  DB 0,$0B,0,"&",0,$09,"7",0      ; 145 - 152
  DB $0C,0,"8","'","9","0",0,"("  ; 153 - 160
  DB 0,")","_",0,0,0,0,0          ; 161 - 168
  DB 0,"Y",0,0,0,0,"y",0          ; 169 - 176
  DB 0,"U",0,"[",0,"I","u","O"    ; 177 - 184
  DB "P",0,"i","]","o","p",0,$AC  ; 185 - 192
  DB 0,";",$22,0,0,0,0,0          ; 193 - 200
  DB 0,"H",0,0,0,0,"h",0          ; 201 - 208
  DB 0,"J",0,"|",0,"K","j","L"    ; 209 - 216
  DB $C3,0,"k","-","l",13,0,"+"   ; 217 - 224
  DB 0,"=",$C3,0,"B",0,0,0        ; 225 - 232
  DB 0,"B",0,0,0,0,"b",0          ; 233 - 240
  DB 0,"N",0,"*",0,"M","n",0      ; 241 - 248
  DB 0,0,"m",",",0,32,0           ; 249 - 255

;SYMSHFT_I = $AC                         
;SYMSHFT_A = $E2                         
;SYMSHFT_S = $C3                                                                                                     
;SYMSHFT_Q = $C7                                                                          




                                                                             
; Variables                             
LASTKEY:         DB 0
CHECK_UPDATE:    DB 1                          
LINEPOS:         DB 0                   
COLMPOS:         DB 0                   
ROWPOS:          DB 0                   
COLMPOSOLD:      DB 0                   
FROMBS:          DB 0                   
FROMENTER:       DB 0                   
SCREEN_ID:       DB 0                   
INKCOLOR:        DB 0                   
TEMPBYTE:        DB 0                   
FLASHCURSOR:     DB 0                   
TEMPI:           DB 0                   
TEMPL:           DB 0                   
DELAY:           DB 0                   
HAVE_PUB_BACKUP: DB 0                   
HAVE_PRV_BACKUP: DB 0                   
HOMECOLM:        DB 0                   
CURSPOSBACKUP:   DB 0                   
RXFULL:          DB 0                   
RXINDEX:         DB 0                   
CONFIGSTATUS:    DB "      ",128        
ESPVERSION:      DB "3.75  ",128        
SERVERNAME:      DB "www.chat64.nl",128 
                 DB "                                ",128
EMUMODE:         DB 0                   
TEMPCOLOR:       DB 0,0                 
                                        
text_pm_count:   DB " PM:"              
PMCOUNT:         DB "10 ", 128          
text_pm_count0:  DB 32,32,32,32,32,32,32,32,32,32,128
PMUSER:          DB "@Eliza ",128,128,128,128,128,128,128,128,128,128
INKEY:           DB 0               
ESCAPE:          DB 0              


; -------------------------------------------------------------------
; Notes to be uploaded to HL
; -------------------------------------------------------------------
C_0:    EQU $6868
Cs_0:   EQU $628d
D_0:    EQU $5d03
Ds_0:   EQU $57bf
E_0:    EQU $52d7
F_0:    EQU $4e2b
Fs_0:   EQU $49cc
G_0:    EQU $45a3
Gs_0:   EQU $41b6
A_0:    EQU $3e06
As_0:   EQU $3a87
B_0:    EQU $373e
C_1:    EQU $3425
Cs_1:   EQU $3134
D_1:    EQU $2e6f
Ds_1:   EQU $2bd3
E_1:    EQU $295c
F_1:    EQU $2708
Fs_1:   EQU $24d5
G_1:    EQU $22c2
Gs_1:   EQU $20cd
A_1:    EQU $1ef4
As_1:   EQU $1d36
B_1:    EQU $1b90
C_2:    EQU $1a02
Cs_2:   EQU $188b
D_2:    EQU $1728
Ds_2:   EQU $15da
E_2:    EQU $149e
F_2:    EQU $1374
Fs_2:   EQU $125b
G_2:    EQU $1152
Gs_2:   EQU $1058
A_2:    EQU $0f6b
As_2:   EQU $0e9d
B_2:    EQU $0db8
C_3:    EQU $0cf2
Cs_3:   EQU $0c36
D_3:    EQU $0b86
Ds_3:   EQU $0add
E_3:    EQU $0a40
F_3:    EQU $09ab
Fs_3:   EQU $091e
G_3:    EQU $089a
Gs_3:   EQU $081c
A_3:    EQU $07a6
As_3:   EQU $0736
B_3:    EQU $06cd
C_4:    EQU $066a
Cs_4:   EQU $060c
D_4:    EQU $05b3
Ds_4:   EQU $0560
E_4:    EQU $0511
F_4:    EQU $04c6
Fs_4:   EQU $0480
G_4:    EQU $043d
Gs_4:   EQU $03ff
A_4:    EQU $03c4
As_4:   EQU $038c
B_4:    EQU $0357
C_5:    EQU $0325
Cs_5:   EQU $02f7
D_5:    EQU $02ca
Ds_5:   EQU $02a0
E_5:    EQU $0279
F_5:    EQU $0254
Fs_5:   EQU $0231
G_5:    EQU $020f
Gs_5:   EQU $01f0
A_5:    EQU $01d3
As_5:   EQU $01b7
B_5:    EQU $019c
C_6:    EQU $0183
Cs_6:   EQU $016c
D_6:    EQU $0156
Ds_6:   EQU $0141
E_6:    EQU $012d
F_6:    EQU $011b
Fs_6:   EQU $0109
G_6:    EQU $00f8
Gs_6:   EQU $00e9
A_6:    EQU $00da
As_6:   EQU $00cc
B_6:    EQU $00bf
C_7:    EQU $00b2
Cs_7:   EQU $00a7
D_7:    EQU $009c
Ds_7:   EQU $0091
E_7:    EQU $0087
F_7:    EQU $007e
Fs_7:   EQU $0075
G_7:    EQU $006d
Gs_7:   EQU $0065
A_7:    EQU $005e
As_7:   EQU $0057
B_7:    EQU $0050
C_8:    EQU $004a
Cs_8:   EQU $0044
D_8:    EQU $003e
Ds_8:   EQU $0039
E_8:    EQU $0034
F_8:    EQU $0030
Fs_8:   EQU $002b
G_8:    EQU $0027
Gs_8:   EQU $0023
A_8:    EQU $0020
As_8:   EQU $001c
B_8:    EQU $0019

; -------------------------------------------------------------------
; Frequencies to be loaded in DE, 1 second ( / 2 = 0.5 ....)
; -------------------------------------------------------------------
C_0_f:  EQU $0010 / $20
Cs_0_f: EQU $0011 / $20
D_0_f:  EQU $0012 / $20
Ds_0_f: EQU $0013 / $20
E_0_f:  EQU $0014 / $20
F_0_f:  EQU $0015 / $20
Fs_0_f: EQU $0017 / $20
G_0_f:  EQU $0018 / $20
Gs_0_f: EQU $0019 / $20
A_0_f:  EQU $001b / $20
As_0_f: EQU $001d / $20
B_0_f:  EQU $001e / $20
C_1_f:  EQU $0020 / $20
Cs_1_f: EQU $0022 / $20
D_1_f:  EQU $0024 / $20
Ds_1_f: EQU $0026 / $20
E_1_f:  EQU $0029 / $20
F_1_f:  EQU $002b / $20
Fs_1_f: EQU $002e / $20
G_1_f:  EQU $0031 / $20
Gs_1_f: EQU $0033 / $20
A_1_f:  EQU $0037 / $20
As_1_f: EQU $003a / $20
B_1_f:  EQU $003d / $20
C_2_f:  EQU $0041 / $20
Cs_2_f: EQU $0045 / $20
D_2_f:  EQU $0049 / $20
Ds_2_f: EQU $004d / $20
E_2_f:  EQU $0052 / $20
F_2_f:  EQU $0057 / $20
Fs_2_f: EQU $005c / $20
G_2_f:  EQU $0062 / $20
Gs_2_f: EQU $0067 / $20
A_2_f:  EQU $006e / $20
As_2_f: EQU $0074 / $20
B_2_f:  EQU $007b / $20
C_3_f:  EQU $0082 / $20
Cs_3_f: EQU $008a / $20
D_3_f:  EQU $0092 / $20
Ds_3_f: EQU $009b / $20
E_3_f:  EQU $00a4 / $20
F_3_f:  EQU $00ae / $20
Fs_3_f: EQU $00b9 / $20
G_3_f:  EQU $00c4 / $20
Gs_3_f: EQU $00cf / $20
A_3_f:  EQU $00dc / $20
As_3_f: EQU $00e9 / $20
B_3_f:  EQU $00f6 / $20
C_4_f:  EQU $0105 / $20
Cs_4_f: EQU $0115 / $20
D_4_f:  EQU $0125 / $20
Ds_4_f: EQU $0137 / $20
E_4_f:  EQU $0149 / $20
F_4_f:  EQU $015d / $20
Fs_4_f: EQU $0172 / $20
G_4_f:  EQU $0188 / $20
Gs_4_f: EQU $019f / $20
A_4_f:  EQU $01b8 / $20
As_4_f: EQU $01d2 / $20
B_4_f:  EQU $01ed / $20
C_5_f:  EQU $020b / $20
Cs_5_f: EQU $022a / $20
D_5_f:  EQU $024b / $20
Ds_5_f: EQU $026e / $20
E_5_f:  EQU $0293 / $20
F_5_f:  EQU $02ba / $20
Fs_5_f: EQU $02e4 / $20
G_5_f:  EQU $0310 / $20
Gs_5_f: EQU $033e / $20
A_5_f:  EQU $0370 / $20
As_5_f: EQU $03a4 / $20
B_5_f:  EQU $03db / $20
C_6_f:  EQU $0417 / $20
Cs_6_f: EQU $0455 / $20
D_6_f:  EQU $0497 / $20
Ds_6_f: EQU $04dd / $20
E_6_f:  EQU $0527 / $20
F_6_f:  EQU $0575 / $20
Fs_6_f: EQU $05c8 / $20
G_6_f:  EQU $0620 / $20
Gs_6_f: EQU $067d / $20
A_6_f:  EQU $06e0 / $20
As_6_f: EQU $0749 / $20
B_6_f:  EQU $07b8 / $20
C_7_f:  EQU $082d / $20
Cs_7_f: EQU $08a9 / $20
D_7_f:  EQU $092d / $20
Ds_7_f: EQU $09b9 / $20
E_7_f:  EQU $0a4d / $20
F_7_f:  EQU $0aea / $20
Fs_7_f: EQU $0b90 / $20
G_7_f:  EQU $0c40 / $20
Gs_7_f: EQU $0cfa / $20
A_7_f:  EQU $0dc0 / $20
As_7_f: EQU $0e91 / $20
B_7_f:  EQU $0f6f / $20
C_8_f:  EQU $105a / $20
Cs_8_f: EQU $1153 / $20
D_8_f:  EQU $125b / $20
Ds_8_f: EQU $1372 / $20
E_8_f:  EQU $149a / $20
F_8_f:  EQU $15d4 / $20
Fs_8_f: EQU $1720 / $20
G_8_f:  EQU $1880 / $20
Gs_8_f: EQU $19f5 / $20
A_8_f:  EQU $1b80 / $20
As_8_f: EQU $1d23 / $20
B_8_f:  EQU $1ede / $20


Song_nm:  ; Song for new message
  dw D_4_f,D_5,  D_5_f,D_5,  D_4_f,D_4,  G_4_f,G_4,   D_4_f,D_5
  dw $0000

Song_error:
  dw G_4_f,G_2 ,  G_4_f,Fs_2,  G_3_f,E_2,   G_5_f,C_2
  dw $0000
        
Song_start:
  dw C_5_f,C_5
  dw C_6_f,C_5,  B_6_f,B_4,  A_6_f,A_4,  G_7_f,G_5,   D_7_f,D_5
  dw $0000

Song_update:
  dw C_5_f,C_5,  B_4_f,B_4,  A_4_f,A_4,  G_5_f,G_5,   D_5_f,D_5
  dw C_5_f,C_5,  B_4_f,B_4,  A_4_f,A_4,  G_5_f,G_5,   D_5_f,D_5
  dw C_5_f,C_5,  B_4_f,B_4,  A_4_f,A_4,  G_5_f,G_5,   D_5_f,D_5  
  dw G_5_f,G_5 ,G_5_f,D_5 ,G_5_f,G_5,   D_5_f,D_5
  dw $0000

   
ptrSound:
  dw Song_error

endofProgram: DB "EOCEOC"  // we need this line for the python script that converts the program to an array.

// Next, some big blocks of reserved space for backups and buffers
SCREEN_PRIV_BACKUP:

  org SCREEN_PRIV_BACKUP + SCREEN_SIZE
SCREEN_PUB_BACKUP:

  org SCREEN_PUB_BACKUP + SCREEN_SIZE
SPLITBUFFER:

  org SPLITBUFFER + 42
RXBUFFER:

  org RXBUFFER + 300
TXBUFFER: 
 

; Deployment: Binfile                   
                                        
  SAVEBIN "main.bin",init      ; this file will be converted into an array and included in the ESP Sketch         
  SAVESNA "load.sna",init      ; this is just for the emulator.. for testing         
