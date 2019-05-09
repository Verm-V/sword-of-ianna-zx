I.MLDoffset2:		EQU 23808
I.sectorgrabar		EQU	23809
I.romsectorgrabar	EQU	23810
I.hlsectorgrabar	EQU	23811
I.SAVEPREFS 		EQU 23813
I.enviacomandosimple:	equ 23873
I.tienebus			EQU 24574
I.esuninves			EQU 24573

org 24576

CURRENT_SCREEN_MAP:	EQU $FE00
CURRENT_SCREEN_HARDNESS_MAP: EQU CURRENT_SCREEN_MAP + 160
CURRENT_SCREEN_OBJECTS: EQU CURRENT_SCREEN_MAP + 200

mainmenu_p6: EQU $1C63
intro_in_p6: EQU $1C6C
ending_in_p6: EQU $1C6F
;cambianivel_in_p6: EQU $1C72

start:
init_engine:
	call set_interrupt
;	call MUSIC_Init
IF IO_DRIVER=4
	; Load preferences
	call IO_LoadPrefs
ENDIF
game_loop:
	call cls
	; Load menu music
;	ld a, 12
;	call MUSIC_Load
	call setrambank6		; and place RAM bank 6
	call mainmenu_p6
	call set_interrupt
begin_level:
;	call MUSIC_Stop
	call cls
IF IO_DRIVER=4
	; Save preferences
	call IO_SavePrefs
ENDIF
	call setrambank6		; and place RAM bank 6

 	ld a, 1
	ld (show_passwd), a
;trainer: EQU $+1
;	jr saltarseeltrainer
;	call cambianivel_in_p6  		;fixme solo para probar los niveles
;saltarseeltrainer:
    ; Check if this is the first time the intro is run,
    ; and only run it if we are in level 1
    ld a, (current_level)
    and a
    jr nz, begin_level_nointro
    ld a, (intro_shown)
    and a
    jr nz, begin_level_nointro

;	call MUSIC_LoadIntro
;	call MUSIC_Init			; little trick: load but don't play

	call intro_in_p6		

;	call MUSIC_Stop
	call cls				

begin_level_nointro:
	call InitVariables
	call InitSprites
	call InitEntities
	call InitObjectTable
	call InitPlayer
	call LoadLevel
;	ld a, 1
;	ld (show_passwd), a
	;call LoadSprites					;<<<<<<<<<< eliminado porque ya no cargamos los sprites al inicio de nivel
	call SaveCheckpoint
internal_loop:		
	call game
;	call MUSIC_Stop

	ld a, (current_level)
	cp 8
	jr z, internal_loop_attract
	call draw_gameover_string
internal_loop_attract:
	ld a, (player_dead)
	;cp 2
	sub 2
	jr z, game_loop     ; back to main menu
	;cp 3
	dec a
	jr z, begin_level   ; new level
    ; cp 4
    dec a
    jp z, end_game      ; game completed!
	jr internal_loop
game:
	call InitTiles
	; Set visible page
;	di 
;	call switchscreen											
;	ei
	call RestoreCheckpoint										
	call load_player_weapon_sprite
	ld a, (current_levely)
	and a
	jr z, LoadScreen_addx
	ld c, a			; C has current_levely
	ld a, (level_width)
	ld b, a			; B has level_width
	xor a
LoadScreen_loop:
	add a, c
	djnz LoadScreen_loop	; so we multiply current_levely*level_width
LoadScreen_addx:
	ld hl, current_levelx
	add a, (hl)

	call LoadScreen
	ld ix, CURRENT_SCREEN_OBJECTS
	call LoadObjects
	ld hl, CURRENT_SCREEN_OBJECTS
	call load_script
	call LoadEnemySprite

;	ld a, (current_level)
;	call MUSIC_Load
	call load_scorearea
	call DrawScreen

	ld ix, (ENTITY_PLAYER_POINTER)
	ld a, (initial_coordx)
	ld b, a
	ld a, (initial_coordy)
	ld c, a
	call UpdateSprite
	call RedrawScreen
	ld a, (current_level)
	and a
	jr z, mainloop		; do not show password in level 1 (makes no sense)
	cp 8
	jr nc, mainloop		; in attract mode and secret level, do not show password
	ld a, (show_passwd)
	and a
	jr z, mainloop
	xor a
	ld (show_passwd), a
	call draw_password
mainloop:
	; DEBUG: while we press S, we will see the alternate screen
;	ld bc, KEY_S 
;	call GET_KEY_STATE
;	and a
;	jr nz, mainloop_go
;kkloop_showaltscreen:
;	di 
;	call switchscreen	; Now show shadow screen
;kkloop_showaltscreen_loop:
;	ld bc, KEY_S 
;	call GET_KEY_STATE
;	and a
;	jr z, kkloop_showaltscreen_loop
;	call switchscreen	; Show main screen (from bank 7)
;	ei
	ld a, (current_level)
	cp 8
	jr nz, mainloop_go		; only check this if we are in attract mode
	ld bc, KEY_SPACE
	call GET_KEY_STATE
;	and a
	jr nz, mainloop_go
	; Pressed SPACE while in attract mode, let's get out of here!
	ld a, 2
	ld (player_dead), a
mainloop_go:
	; Press H for pause menu
	ld bc, KEY_H
	call GET_KEY_STATE
;	and a
	jr nz, mainloop_nopause
	ld a, FX_PAUSE
	call FX_Play
	call pause_menu
	ld a, FX_PAUSE
	call FX_Play
mainloop_nopause:
;	ld bc, KEY_S
;	call GET_KEY_STATE
;	call z, action_checkpoint
	
	; Run scripts
	call RunScripts
;	ld a, (ndirtyrects)
;	cp 2
;	jr nc, noesperarscripts		;si es igual o  mayor que 2 no esperamos al halt
;	halt
;noesperarscripts:
	call buscheck
	call RedrawScreen_nohalt

	; Check gravities
	call CheckGravities
;	ld a, (ndirtyrects)
;	cp 2
;	jr nc, noesperargravities	;si es igual o  mayor que 2 no esperamos al halt
;	halt
;noesperargravities:
	call buscheck
	call RedrawScreen_nohalt

	ld a, (animate_tile)
	inc a
	ld (animate_tile), a
	and 1
	call z, AnimateSTiles
	
	call waitforVBlank

	ld a, (player_dead)
	and a
	ret nz		; if the player is dead, exit
	; tick global timer
	ld a, (global_timer)
	and a
	jr z, mainloop
	dec a
	ld (global_timer), a
	jr mainloop

end_game:
;	call MUSIC_Stop
	call cls
	call setrambank6		; and place RAM bank 6
;	call MUSIC_LoadEnd
;	call MUSIC_Init			; little trick: load but don't play
	call ending_in_p6
;	call cls				;no need to duplicate it
    jp game_loop

waitforVBlank:
	push af
	push bc
	push de
	push hl
	push ix
	push iy
waitforVBlank_loop:
	ld a, (frames_noredraw)
	cp 5			; wait until we have spent at least 5 frames without redrawing
	jr nc, vblank_done
waitforVBlank_score:
	ld a, (score_semaphore)
	and a
	jr nz, waitforvblank_halt_go	; if the score_semaphore is taken, do nothing!
	ld a, (inv_refresh)
	and a
	call nz, draw_score_inventory

	ld a, (inv_what_to_print)
	and a
	jr nz, waitforvblank_check1
waitforvblank_0:
	call draw_barbarian_state
	ld a, 1
	jr waitforvblank_halt
waitforvblank_check1:
	;cp 1
	dec a
	jr nz, waitforvblank_2
waitforvblank_1:
	ld ix, ENTITY_ENEMY1_POINTER
	ld a, 24
	call draw_enemy_state
	ld a, 2
	jr waitforvblank_halt
waitforvblank_2:
	ld ix, ENTITY_ENEMY2_POINTER
	ld a, 27
	call draw_enemy_state
	xor a
waitforvblank_halt:	
	ld (inv_what_to_print), a
waitforvblank_halt_go:	
;	halt
	call RedrawScreen				;<<<<<<<<<<<<<<<<<
	jr waitforVBlank_loop
vblank_done:
	xor a
	ld (frames_noredraw), a 		; 0 frames without a redraw
	pop iy
	pop ix
	pop hl
	pop de
	pop bc
	pop af
	ret

set_interrupt:
	ld a, 0xbf
	ld hl, 0x8000	
	ld de, ISR
	jp SetIM2
;	call SetIM2
;	ret


pause_menu_print_attr1:
	ld hl, pause_attr1
; B: X char
; C: Y char
; HL: pointer to attribute list
pause_menu_print_attr:
	ld a, 17
	ld b, 8
pause_menu_print_attr_loop:
	ld e, (hl)
;	push bc
	push hl
	push af
	call SetAttribute
	pop af
	pop hl
;	pop bc
	inc b
	inc hl
	dec a
	jr nz, pause_menu_print_attr_loop
	ret

pause_menu:
	; first, wait until the H key is released
	ld bc, KEY_H
	call GET_KEY_STATE
;	and a
	jr z, pause_menu
pause_menu_print:
	ld c, 8
	ld hl, pause_attr0
	call pause_menu_print_attr
;	ld c, 9
	inc c
;	ld hl, pause_attr1
	call pause_menu_print_attr1
;	ld c, 10
	inc c
;	ld hl, pause_attr1
	call pause_menu_print_attr1
;	ld c, 11
	inc c
;	ld hl, pause_attr1
	call pause_menu_print_attr1
;	ld c, 12
	inc c
	ld hl, pause_attr2
	call pause_menu_print_attr
;	ld c, 13
	inc c
	ld hl, pause_attr3
	call pause_menu_print_attr

	ld a, (language)
	and a
	jr nz, pause_menu_en
	ld iy, pause_string0
	jr pause_menu_print_go
pause_menu_en:
	ld iy, pause_string0_en
pause_menu_print_go:
	ld bc, 8*256 + 8
	ld a, 6
pause_menu_print_loop:
	push bc
	push iy
	push af
	call print_string2		
	pop af
	pop iy
	pop bc
	ld de, 18
	add iy, de
	inc c
	dec a
	jr nz, pause_menu_print_loop

pause_menu_inner_loop:
	ld a, (joystick_state)
	bit 4, a			; BIT 4 is FIRE
	jr nz, pause_menu_inner_use_object
	bit 2, a			; BIT 2 is left
	jr z, pause_menu_inner_check_right
	; pressed left. wait until it is depressed, change object left
pause_menu_inner_left_loop:
	call pause_menu_waitkey
	bit 2, a
	jr nz, pause_menu_inner_left_loop
	ld a, FX_INVENTORY_MOVE
	call FX_Play
	ld a, (inv_current_object)
	and a
	jr z, pause_menu_inner_done	; cannot reduce the current object
	dec a
	ld (inv_current_object),a
	jr pause_menu_inner_updateinv
pause_menu_inner_check_right:
	bit 3, a			; BIT 3 is right
	jr z, pause_menu_inner_check_down
pause_menu_inner_right_loop:
	call pause_menu_waitkey
	bit 3, a
	jr nz, pause_menu_inner_right_loop
	ld a, FX_INVENTORY_MOVE
	call FX_Play
	ld a, (inv_current_object)
	cp INVENTORY_SIZE - 1
	jr z, pause_menu_inner_done	; cannot increase the current object
	inc a
	ld (inv_current_object),a
pause_menu_inner_updateinv:
	call force_inv_redraw
pause_menu_inner_check_down:
	bit 1, a
	jr z, pause_menu_inner_done
	; pressed down. wait until it is depressed, change weapon if available
pause_menu_inner_down_loop:
	call pause_menu_waitkey
	bit 1, a
	jr nz, pause_menu_inner_down_loop
pause_menu_change_weapon:
	ld a, FX_INVENTORY_MOVE
	call FX_Play
	ld a, (player_current_weapon)
	inc a				
	and $3
	ld (player_current_weapon), a
	ld hl, player_available_weapons
	ld e, a
	ld d, 0
	add hl, de
	ld a, (hl)
	and a
	jr z, pause_menu_change_weapon	; weapon not available, check next
	call draw_weapon
	call RedrawScreen
	jr pause_menu_inner_done
pause_menu_inner_use_object:
	call pause_menu_waitkey
	bit 4, a			; BIT 4 is FIRE
 	jr nz, pause_menu_inner_use_object
	ld a, (inv_current_object)
	ld e, a
	ld d, 0
	ld hl, inventory
	add hl, de
	ld a, (hl)	; get object
	cp OBJECT_HEALTH	; the health potion. For now, it is the only one we can use as such
	jr nz, pause_menu_inner_done
	; set maximum health
	ld iy, ENTITY_PLAYER_POINTER
	call get_entity_max_energy	 ; get the maximum energy
	ld (ENTITY_PLAYER_POINTER+4), a				; and set it!
	ld a, FX_INVENTORY_SELECT
	call FX_Play
	ld a, OBJECT_HEALTH
	call remove_object_from_inventory
	jr pause_menu_inner_updateinv
pause_menu_inner_done:
	xor a			
	ld (joystick_state), a	; reset joystick state
pause_menu_check_for_exit:
	ld bc, KEY_H
	call GET_KEY_STATE
;	and a
	jr z, pause_menu_wait_for_exit_depressed
pause_menu_check_for_end:
	ld bc, KEY_X
	call GET_KEY_STATE
;	and a
	jp nz, pause_menu_inner_loop
pause_menu_wait_for_end_depressed:
	ld a, 2
	ld (player_dead), a
	ld bc, KEY_H
	call GET_KEY_STATE
;	and a
	jr z, pause_menu_wait_for_end_depressed
pause_menu_wait_for_exit_depressed:
	ld bc, KEY_H
	call GET_KEY_STATE
;	and a
	jr z, pause_menu_wait_for_exit_depressed
	; Load the new weapon animations, just in case
	call load_player_weapon_sprite
	; invalidate the whole area to force a full redraw
	ld bc, 0
	ld de, 32*256 + 20
	call InvalidateTiles
	jp RedrawAllSprites
;	call RedrawAllSprites
;	ret

pause_menu_waitkey:
	xor a
	ld (joystick_state), a
	halt
	ld a, (joystick_state)
	ret

; Run scripts for all entities
RunScripts:
	xor a
	ld (screen_changed), a
	ld ix, ENTITY_PLAYER_POINTER
	ld hl, barbaro_idle													
	ld (entity_sprite_base), hl
	ld a, (joystick_state)
	ld (entity_joystick), a
	ld iy, scratch_area_player
	call run_script
	ld ix, ENTITY_PLAYER_POINTER
	call script_player
	; If we changed screen, we should stop now!
	ld a, (screen_changed)
	and a
	ret nz

	call buscheck
	call RedrawScreen_nohalt			;<<<<<<<

	ld ix, ENTITY_ENEMY1_POINTER
	ld a, (ix+0)
	or (ix+1)
	jr z, runs_noenemy1
	xor a
	ld (entity_joystick), a
	ld hl, enemy_base_sprite
	ld (entity_sprite_base), hl
	ld iy, scratch_area_enemy1
	call run_script

	ld ix, ENTITY_ENEMY1_POINTER
	call action_joystick

;	call buscheck
;	call RedrawScreen_nohalt			;<<<<<<<

runs_noenemy1:
	ld ix, ENTITY_ENEMY2_POINTER
	ld a, (ix+0)
	or (ix+1)
	jr z, runs_noenemy2
	xor a
	ld (entity_joystick), a
	ld a, (ix+10)
	and $f0
	cp OBJECT_ENEMY_SECONDARY*16-OBJECT_ENEMY_SKELETON*16
	jr nz, runs_enemy2_nosecondary
	ld hl, enemy_base_sprite+3936
	jr runs_enemy2_go
runs_enemy2_nosecondary:
	ld hl, enemy_base_sprite
runs_enemy2_go:
	ld (entity_sprite_base), hl
	ld iy, scratch_area_enemy2
	call run_script

	ld ix, ENTITY_ENEMY2_POINTER
	call action_joystick

;	ld a, (frames_noredraw)		;comprobamos los frames 
;	cp 1						;si es 1 no hemos pintado el enemigo1 y podemos hacer un halt
;	jr nz , hacerpausaenemigo2	;si no es 1 hacemos una mini pausa para dejar pasar el haz y pintar el enemigo2 sin halt
;	halt						;si no hemos pintado el enemigo1 podemos hacer un halt
;	jr pausaenemigo2			;y redibujamos con una pausa de 1
;hacerpausaenemigo2
;	ld a, 130					;hacemos una pausa de 2600 T-States
;pausaenemigo2
;	nop
;	dec a
;	jr nz, pausaenemigo2
	
	call buscheck
	call RedrawScreen_nohalt			;<<<<<<< pintamos con "_nohalt" para mantener los frames a 5
;										;se mantiene velocidad y solo parpadea alguna vez en ataque

runs_noenemy2:
	ld b, 5		; 5 objects
	ld ix, ENTITY_OBJECT1_POINTER
	ld iy, scratch_area_obj1
runs_object_loop:
	push iy
	push ix
	push bc
	ld a, (ix+0)
	or (ix+1)
	jr z, runs_noobj	; skip object if absent
	call run_script

runs_noobj:
	pop bc
	pop ix
	pop iy
	ld de, ENTITY_SIZE		; entity size
	add ix, de		; go to next object
	ld de, 8		; scratch area size
	add iy, de
	djnz runs_object_loop
	ret



; Check gravity for player and enemies
CheckGravities:
	ld ix, ENTITY_PLAYER_POINTER
	ld hl, barbaro_idle 
	ld (entity_sprite_base), hl
	ld a, 1
	ld (spritegravity), a
	call entity_gravity
	ld ix, ENTITY_ENEMY1_POINTER
	ld a, (ix+0)
	or (ix+1)
	jr z, chkg_noenemy1	
	ld hl, enemy_base_sprite
	ld (entity_sprite_base), hl
	ld a, 2
	ld (spritegravity), a
	call entity_gravity
chkg_noenemy1:
	ld ix, ENTITY_ENEMY2_POINTER
	ld a, (ix+0)
	or (ix+1)
	ret z
	ld hl, enemy_base_sprite
	ld (entity_sprite_base), hl
	ld a, 3
	ld (spritegravity), a
	jp entity_gravity
;	call entity_gravity
;	ret



; Flush changes to screen
RedrawScreen:
	halt
RedrawScreen_nohalt:
	call RedrawInvTiles
	call DrawSpriteList	; then the sprite list
;	di 
;	call switchscreen	; Now show shadow screen, where everything is ok
;	call setrambank7		; and place RAM bank 7     
;	ei
;	call TransferDirtyTiles	; Transfer dirty tiles to main screen
;	halt
ClearDirtyRedraw:
	xor a
	ld hl, spritecaida1
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), a
	
	ld hl, ndirtyrects
	ld a, (hl)
	and a
	ret z
	add a, a
	add a, a
	ld b, a
	xor a
	ld (hl),a
	
	ld hl, tiles_dirty		
bucle_borrado_dirty
	ld (hl), a
	inc l
	djnz bucle_borrado_dirty

	ret


; ISR routine
ISR:
	; simply get the joystick state
	ld a, (selected_joystick)
	ld hl, key_defs
	call get_joystick
	ld b, a
	ld a, (joystick_state)
	or b
	ld (joystick_state), a
	; increase the variable defining the number of frames without screen update
	ld a, (frames_noredraw)
	inc a
	ld (frames_noredraw), a
	; and play music, if needed
	ret
;	ld a, (music_playing)
;	and a
;	ret z		; if not playing music, do nothing
;	jp MUSIC_Play
;	call MUSIC_Play
;	ret

; Load sprites for level

; Array defining the sprites to load per level
; Low byte:  bit mask with: 0 DALGURAK KNIGHT ROCK TROLL MUMMY ORC SKELETON
; High byte: bit mask with: 0 0 0 0 DEMON MINOTAUR OGRE GOLEM 
;					 level1 level2 level3 level4 level5 level6 level7 level8 attract level9
;sprites_per_level: dw $0017, $011b, $023a, $0c27, $0129, $0c2b, $0001, $0968, $001f, $0208
;current_spraddr: dw 0

;FIRST_ENEMY_SPRITE: EQU $0000

;LoadSprites:
;	ld hl, FIRST_ENEMY_SPRITE
;	ld (current_spraddr), hl
;	ld a, (current_level)
;	add a, a
;	ld e, a
;	ld d, 0
;	ld hl, sprites_per_level
;	add hl, de
;	ld e, (hl)
;	inc hl
;	ld d, (hl)			; DE has the bitmask for the enemies in level
;	ld b, 7				; for now we have up to 7 small enemies
;	xor a				; A counts the sprites
;	ld hl, enemy_sprite_data
;	call LoadSprites_loop
;	ld e, d
;	ld b, 4				; 4 big sprites, low side
;	ld a, 7				; starting from sprite 7
;	ld hl, enemy_sprite_data+14
;	call LoadSprites_loop
;	ld e, d
;	ld b, 4				; 4 big sprites, high side
;	ld a, 11			; starting from sprite 11
;	ld hl, enemy_secondsprite_data
;	jp LoadSprites_loop
;	call LoadSprites_loop
;	ret

;LoadSprites_loop:
;	rr e				; rotate lower bit into accumulator
;	jr nc, LoadSprites_loop_cont
;	push de
;	push bc
;	push af
;	push hl
;	call IO_LoadSprite	; load sprite A. Returns loaded bytes into BC
;	pop hl
;	ld de, (current_spraddr)
;	ld (hl), e
;	inc hl
;	ld (hl), d			; save spraddr into the variable
;	dec hl
;	push hl
;	ld h, b
;	ld l, c
;	add hl, de
;	ld (current_spraddr), hl	; and save future address
;	pop hl
;	pop af
;	pop bc
;	pop de
;LoadSprites_loop_cont:
;	inc a
;	inc hl
;	inc hl
;	djnz LoadSprites_loop
;	ret

; Load level
; No parameters.
; The basic map structure is:
;	Byte 0-7: 	LEVELXXX, where XXX will be a level-specific key
;	Byte 8-9: 	offset_tileinfo
; 	Byte 10-11:	offset_stileinfo
;	Byte 12-13: offset_stilecolors
;	Byte 14-15:	offset_strings_english
;	Byte 16-17:	offset_strings
;	Byte 18:	level_nscreens
;	Byte 19: 	level_width
;	Byte 20:	level_height
;	Byte 21:	level_nscripts
;	Byte 22:	level_strings
;	Byte 23-24:	initial screen (x,y)
;	Byte 25-26:	initial coords in first screen (x,y)
;	Byte 27:	reserved
;	Byte 28-XXX:	addresses of compressed screens (level_width * level_height * 2 bytes). For now, maximum 64 screens per level (128 bytes)
;	XXX-YYY:	compressed screens
;	At the end:	compressed tileinfo, compressed stileinfo
	
LEVEL_SCREEN_ADDRESSES: EQU $AC80

LoadLevel:
    ld a, (current_level)
	call IO_LoadLevel		;cambia la variable romatbank1 con el valor del nivel que toca

	di
	call setrambank1		; pone el slot apuntado por romatbank1 como rom
	; FIXME: should somehow check if the level structure is correct
	ld ix, $0000				;the level is on ROM so start at $0000
	ld a, (ix+8)
	ld l, a
	ld a, (ix+9)
	and $3f						;as we are using same level rom as 128k we need to rest $c000 to hl
	ld h, a	
	ld (level_tiles_addr), hl
	ld a, (ix+10)
	ld l, a
	ld a, (ix+11)
	and $3f						;as we are using same level rom as 128k we need to rest $c000 to hl
	ld h, a	
	ld (level_stiles_addr), hl
	ld a, (ix+12)
	ld l, a
	ld a, (ix+13)
	and $3f						;as we are using same level rom as 128k we need to rest $c000 to hl
	ld h, a
	ld (level_stilecolors_addr), hl
	ld a, (ix+14)
	ld l, a
	ld a, (ix+15)
	and $3f						;as we are using same level rom as 128k we need to rest $c000 to hl
	ld h, a		
	ld (level_string_en_addr), hl
	ld a, (ix+16)
	ld l, a
	ld a, (ix+17)
	and $3f						;as we are using same level rom as 128k we need to rest $c000 to hl
	ld h, a
	ld (level_string_addr), hl
	ld a, (ix+18)
	ld (level_nscreens), a
	ld a, (ix+19)
	ld (level_width), a
	ld a, (ix+20)
	ld (level_height), a	
	ld a, (ix+21)
	ld (level_nscripts), a
	ld a, (ix+22)
	ld (level_nstrings), a
	ld a, (ix+23)
	ld (current_levelx), a
	ld a, (ix+24)
	ld (current_levely), a
	ld a, (ix+25)
	ld (initial_coordx), a
	ld a, (ix+26)
	ld (initial_coordy), a
	and a
	; depack tiles and stiles 
	push ix			; save the level address 
	ld hl, (level_tiles_addr)
	ld de, TILEMAP		; level_tiles
	call depack
	ld hl, (level_stiles_addr)
	ld de, SUPERTILE_DEF		; level_supertiles
	call depack
	ld hl, (level_stilecolors_addr)
	ld de, SUPERTILE_COLORS		; level_supertilecolors
	call depack

	ld a, (language)
	and a
	jr nz, load_strings_en
	ld hl, (level_string_addr)
	jr load_strings_common
load_strings_en:
	ld hl, (level_string_en_addr)
load_strings_common:
	ld de, string_area		; level_strings + scripts
	call depack

	; finally, get the list of screens into RAM
	ld a, (level_nscreens)
	add a, a		; * 2
	ld c, a
	ld b, 0
	pop hl			; restore the level address
	ld de, 28
	add hl, de		; At the beginning+28, we have the first one
	ld de, LEVEL_SCREEN_ADDRESSES
	ldir			; and copy all the stuff
	ei
	ret	

; Load screen
; INPUT:
;	- A: screen to load

LoadScreen:
	add a, a		; to index the array
	ld c, a
	ld b, 0
	ld hl, LEVEL_SCREEN_ADDRESSES
	add hl, bc
	ld e, (hl)
	inc hl
	ld d, (hl)		; DE points to the screen address
	res 7, d
	res 6, d		; as we are using the same level address as the 128k version we need to sub $c000 to the address
	di
	call setrambank1		; and place RAM bank 1
	ei
	ex de, hl		; HL has the source
	ld de, CURRENT_SCREEN_MAP
	call depack

	; Find the number of animated tiles in the screen!!!
LoadScreen_FindAnimTiles:
	xor a
	ld (curscreen_numanimtiles), a
	ld hl, curscreen_animtiles	; area in memory with the animated tile positions
	ld de, CURRENT_SCREEN_MAP
	ld b, 10		; 10 in Y
load_findanim_loopy:	
	ld c, 16		; 16 in X	
load_findanim_loopx:
	ld a, (de)
	cp 240
	jr c, load_findanim_notfound
load_findanim_found:		; this is an animated tile
	ld a, 16
	sub c			; 16-C is the X position
	ld (hl), a
	inc hl
	ld a, 10
	sub b			; 10-B is the Y position
	ld (hl), a
	inc hl
	ld a, (curscreen_numanimtiles)
	inc a
	ld (curscreen_numanimtiles), a	; We have one more animated tile
load_findanim_notfound:
	inc de
	dec c
	jp nz, load_findanim_loopx
	djnz load_findanim_loopy
	ret


; Load enemy sprite
; INPUT: none

LoadEnemySprite:
	ld ix, ENTITY_ENEMY1_POINTER
	ld a, (ix+0)
	or (ix+1)
	jr nz, LoadEnemySprite_go
	ld ix, ENTITY_ENEMY2_POINTER
	ld a, (ix+0)
	and (ix+1)
	ret z		; no enemies in this screen
LoadEnemySprite_go:
	ld a, (ix+10)
	and $f0
	rrca
	rrca
	rrca		; this is enemy type * 2
	rrca
	ld c, a
	ld a, (current_enemy_sprite)
	cp c
	ret z		; if the current enemy sprite is already loaded, do not do anything else
	ld a, c
	ld (current_enemy_sprite), a
	
	ld de, enemy_base_sprite
	call IO_LoadSprite

	; now check if the enemy has a second sprite
	ld ix, ENTITY_ENEMY1_POINTER
	ld a, (ix+10)
	and $f0
	cp OBJECT_ENEMY_GOLEM*16-OBJECT_ENEMY_SKELETON*16
	jr z, LoadEnemySprite_secondsprite
	cp OBJECT_ENEMY_OGRE*16-OBJECT_ENEMY_SKELETON*16
	jr z, LoadEnemySprite_secondsprite
	cp OBJECT_ENEMY_MINOTAUR*16-OBJECT_ENEMY_SKELETON*16
	jr z, LoadEnemySprite_secondsprite
	cp OBJECT_ENEMY_DEMON*16-OBJECT_ENEMY_SKELETON*16
	jr z, LoadEnemySprite_secondsprite
	ret
LoadEnemySprite_secondsprite:
	rrca
	rrca
	rrca		; this is enemy type * 2
	rrca
	add a, 4		; OBJECT_ENEMY_GOLEM is OBJECT_ENEMY_SKELETON+7

	ld de, enemy_base_sprite + 3936
	jp IO_LoadSprite
	
; Go to new screen
; INPUT:
;	- A: new screen, in the format expected by LoadScreen
screen_changed: db 0
ChangeScreen:
	push af
	call RedrawInvTiles		;por si hay cambios de color en la pantalla o si estamos cayendo a otra pantalla ....
	call ClearDirtyRedraw	;para borrar la lista de Tiles Invalidadas
	pop af
	call LoadScreen
	call ReInitSprites	
	call ReInitEntities
	ld ix, CURRENT_SCREEN_OBJECTS
	call LoadObjects
	ld hl, CURRENT_SCREEN_OBJECTS
	call load_script
	call LoadEnemySprite
	call draw_score_status

	; invalidate the whole area to force a full redraw
	; And copy the actual tiles
	ld bc, 0
	ld de, 32*256 + 20
	call InvalidateTiles
	call RedrawScreen_nohalt

	ld a, 4
	ld (frames_noredraw), a ; 4 frames without a redraw, this means redraw on the next frame!
	ld (screen_changed), a	; any value != 0 means we changed screen
	ret

; Save checkpoint
SaveCheckpoint:
	; We are saving stuff in RAM7, $FE00 to $FFFF
	; We have to save
	; 1- The sprite and entity data areas ($BEC0 to $BF9F, 224 bytes)
;	halt
	di 
	ld hl, SPDATA
	ld de, $5b00
	ld bc, 224
	ldir			; and copy 
	; 2- Current status (up to 32 bytes, currently 27)
	ld hl, global_timer
	ld de, $5be0
	ld bc, player_current_weapon-global_timer+1
	ldir			; and copy
	; 3- And the object data (256 bytes in $ff00-$ffff, but in RAM 0)
	ld hl, $FF00
	ld de, $5c00
	ld bc, $ff
	ldir
	ei
	ret

; Restore checkpoint
RestoreCheckpoint:
	; Restoring stuff from RAM7, $FE00 to $FFFF
	; 1- The sprite and entity data areas ($BEC0 to $BF9F, 224 bytes)
;	halt
	di 
	ld hl, $5b00
	ld de, SPDATA
	ld bc, 224
	ldir			; and copy 
	; 2- Current status (up to 32 bytes, currently 27)
	ld hl, $5be0
	ld de, global_timer
	ld bc, player_current_weapon-global_timer+1
	ldir			; and copy
	; 3- And the object data (256 bytes in $ff00-$ffff, but in RAM 0)
	ld hl, $5c00
	ld de, $ff00
	ld bc, $ff
	ldir
	ei					; and enable interrupts
	call ReInitSprites	
	jp ReInitEntities


; Load player weapon sprite
;weapon_spr_addr: dw $C560, $CB07, $D0E4, $D6CF
weapon_spr_addr: dw $0560, $0B07, $10E4, $16CF			;NEW ADDRESS AS NOW LOAD FROM ROM PAGE

load_player_weapon_sprite:								;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
	; Step 1: decompress
	call setrambank6
	ld a, (player_current_weapon)
	add a, a
	ld e, a
	ld d, 0
	ld hl, weapon_spr_addr
	add hl, de
	ld e, (hl)
	inc hl
	ld d, (hl)		; DE = sprite address
	ex de, hl
	ld de, barbaro_idle_espada.sev		; descomprimimos directamente en memoria
	jp depack							; decompress	para saltarse el buffer
	;ret

; TEMP
key_defs: dw KEY_Q, KEY_A, KEY_O, KEY_P, KEY_SPACE, KEY_CAPS
; Global variables
;                     skeleton orc mummy troll rock knight dalgurak golem ogre minotaur demon
enemy_sprite_data: dw        0,  0,    0,    0,   0,     0,       0,    0,   0,       0,    0
;enemy_sprite_data: dw enemy_skeleton, enemy_orc, enemy_mummy, enemy_troll, enemy_rollingstone
;						   golem ogre minotaur demon
enemy_secondsprite_data: dw    0,   0,       0,    0
;enemy_secondsprite_data: dw enemy_skeleton, enemy_skeleton, enemy_skeleton, enemy_skeleton

language: db 0	; 0: Spanish, 1: English
show_passwd: db 0

; Barbarian constants
barbarian_level_exp:  db 16, 64, 96, 128, 160, 192, 240, 255
barbarian_max_energy: db  6, 10, 18, 32,  48,  64,  80,  99 

selected_joystick: db 0
randData: dw 123
current_level: db 0

current_enemy_sprite: db 255
joystick_state: db 0
; Current level information
level_nscreens: db 0
level_nscripts: db 0
level_nstrings: db 0
level_width: db 0
level_height: db 0
level_tiles_addr: dw 0
level_stiles_addr: dw 0
level_stilecolors_addr: dw 0
level_string_en_addr: dw 0
level_string_addr: dw 0
curscreen_numanimtiles: db 0
frames_noredraw: db 0
animate_tile: db 0
entity_sprite_base:	dw 0
entity_current:		dw 0
global_timer: db 0
initial_coordx: db 0
initial_coordy: db 0
entity_joystick:	db 0
; Inventory handling variables
inv_current_object: db 0
inv_first_obj:      db 0
inv_refresh:	    db 0	; refresh inventory?
INVENTORY_SIZE	EQU 6
inventory:	    ds INVENTORY_SIZE		; FIXME we are assuming a maximum of 6 objects in the inventory
inv_what_to_print:  db 0	; 0: barbarian, 1: enemy 1, 2: enemy 2
score_semaphore:    db 0
currentx: db 0
current_levelx: db 0
current_levely: db 0
; Barbarian state
player_dead: db 0
player_available_weapons: db 0,0,0,0
player_level: db 0
player_experience:    db  0
player_current_weapon: db WEAPON_SWORD

WEAPON_SWORD: 	EQU 0
WEAPON_ECLIPSE: EQU 1
WEAPON_AXE: 	EQU 2
WEAPON_BLADE: 	EQU 3

; Additional routines:
 INCLUDE "objects48k.asm"
 INCLUDE "scripts48k.asm"	 ; Script code
;				 level1, level2, level3, level4, level5, level6, level7, level8, attrac, secret, nomus   	gameover      main menu
;music_levels: dw music1, music5, music3, music4, music5, music6, music7, music8, music0, music4, music0,  music_gameover, music_menu


;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
;variables added from different rutines than now run on ROM

intromusicpage	db 0
intro_var: db 0
number_screens: db 0
menu_string_list: dw 0
menu_screen_list: dw 0
menu_attr_list: dw 0
menu_cls_loop: db 0

screen_to_show:   db 0
timer: db 0
menu_option: db 0

menu_loops: db 0

password_string: db "          ",0
password_value:  db 0, 0, 0, 0, 0	; current_level	| player_available_weapons, player_level, player_exp, player_current_weapon, cksum

menu_running: db 0
menu_counter: db 0

changed_settings: db 0
intro_shown: db 0
cls_loop: db 0

attribute_cycle: db 2

start_delta: db 0
current_delta: db 0
current_y: db 0

credit_timer: db 0
credit_current: db 0

current_string_list: dw 0		;string_list_es

joystick_status: db 0
save_level: db 0

current_redefine_strings: dw 0		;redefine_es

forbidden_keys: dw KEY_H, 0, 0, 0, 0, 0, 0
n_forbidden_keys: dw 1 	; 1 key (for now)

rombank:	db 1
romatbank1:	db 0
;romatbank4: db 18

score_password_string: db "PASSWORD:1234567890",0
score_password_value: db 0,0,0,0,0

draw_blank: db 0
draw_char: db 0

spritecaida1: db 0
spritecaida2: db 0
spritecaida3: db 0
spritegravity: db 0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


; Random routine from http://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Random
;-----> Generate a random number
; ouput a=answer 0<=a<=255
; all registers are preserved except: af

random:
        push    hl
        push    de
        ld      hl,(randData)
        ld      a,r
        ld      d,a
        ld      e,(hl)
        add     hl,de
        add     a,l
        xor     h
        ld      (randData),hl
        pop     de
        pop     hl
        ret


; Initialize variables:
InitVariables:
	ld a, 255
	ld (current_enemy_sprite), a
	xor a
	ld hl, joystick_state
	ld (hl), a
	ld de, level_nscreens
	ld bc, player_dead-joystick_state
	ldir
	ld a, 1
	ld (player_available_weapons), a
;	ld a, 15
;	ld (player_experience), a ; FIXME this is a cheat
	ret

; Multiply two 8-bit values into a 16-bit value
; INPUT: H - value 1
;		 E - value 2
; OUTPUT: HL: result
Mul8x8:                           ; this routine performs the operation HL=H*E
  ld d,0                         ; clearing D and L
  ld l,d
  ld b,8                         ; we have 8 bits
Mul8bLoop:
  add hl,hl                      ; advancing a bit
  jp nc,Mul8bSkip                ; if zero, we skip the addition (jp is used for speed)
  add hl,de                      ; adding to the product if necessary
Mul8bSkip:
  djnz Mul8bLoop
  ret


; Divide a 16-bit value by an 8-bit one
; INPUT: HL / C
; OUTPUT: HL: result

Div16_8:
  push de
  ld a,c                         ; checking the divisor; returning if it is zero
  or a                           ; from this time on the carry is cleared
  ret z
  ld de,-1                       ; DE is used to accumulate the result
  ld b,0                         ; clearing B, so BC holds the divisor
Div16_8_Loop:                    ; subtracting BC from HL until the first overflow
  sbc hl,bc                      ; since the carry is zero, SBC works as if it was a SUB
  inc de                         ; note that this instruction does not alter the flags
  jr nc,Div16_8_Loop             ; no carry means that there was no overflow
  ex de, hl                      ; HL gets the result
  pop de
  ret


cls:
	xor a
	ld (cls_loop), a
	
	ld b, 30
cls_outerloop:
	ld hl, 16384+6144
	ld e, a
	ld d, 0
	add hl, de		; HL points to the first row 
	ld de, 30
	ld c, 24
	halt
cls_inerloop:
	xor a
	ld (hl), a
	inc hl
	ld (hl), 2
	inc hl
	ld (hl), 2
	add hl, de
	dec c
	jr nz, cls_inerloop
	ld a, (cls_loop)
	inc a
	ld (cls_loop), a
	dec b
	jr nz, cls_outerloop
	; last line, the last column is red, now clean 
cls_end:
    ld hl, 16384
    ld de, 16385
;	xor a
    ld (hl), l
    ld bc, 6911
    ldir
	ret

;Divide 8-bit values
;In: Divide E by divider D
;Out: A = result, D = rest
;
Div8:
    xor a
    ld b,8
Div8_Loop:
    rl e
    rla
    sub d
    jr nc,Div8_NoAdd
    add a,d
Div8_NoAdd:
    djnz Div8_Loop
    ld d,a
    ld a,e
    rla
    cpl
    ret


END_PAGE2:			;no debe pasar de $77CF	ya que en $7800 se cargan los strings del nivel <<<<<<<<<<<<<<<<<<
org $77D0			;hemos alineado la Tabla de direcciones aqui por lo que END_PAGE2 como maximo ahora es $77CF
	
TileScAddress:	; Screen address for each tile start, considering it starts on $4000
	dw 16384 ; Y = 0
	dw 16416 ; Y = 1
	dw 16448 ; Y = 2
	dw 16480 ; Y = 3
	dw 16512 ; Y = 4
	dw 16544 ; Y = 5
	dw 16576 ; Y = 6
	dw 16608 ; Y = 7
	dw 18432 ; Y = 8
	dw 18464 ; Y = 9
	dw 18496 ; Y = 10
	dw 18528 ; Y = 11
	dw 18560 ; Y = 12
	dw 18592 ; Y = 13
	dw 18624 ; Y = 14
	dw 18656 ; Y = 15
	dw 20480 ; Y = 16
	dw 20512 ; Y = 17
	dw 20544 ; Y = 18
	dw 20576 ; Y = 19
	dw 20608 ; Y = 20
	dw 20640 ; Y = 21
	dw 20672 ; Y = 22
	dw 20704 ; Y = 23


org $8000
IM2table: ds 257	 			; IM2 table (reserved)
 INCLUDE "depack.asm"
 INCLUDE "entities48k.asm"
 INCLUDE "tiles48k.asm"	 ; Tile code
 INCLUDE "drawsprite48k.asm" ; Sprite code
 INCLUDE "score48k.asm"	 ; code to manage the score area
 INCLUDE "music48k.asm"
 INCLUDE "im248k.asm"
 INCLUDE "rambank48k.asm"
 INCLUDE "input48k.asm"
 INCLUDE "io-48k.asm"


buscheck:
	ld a, (ndirtyrects)			;comprobamos si hay dirtys que borrar
	or a
	ret z						;si no hay ninguno regresamos

	ld a, (I.tienebus)		;comprobamos si tenemos floating bus
	or a
	jr nz, buscheckinves		;si es un Inves saltamos a hacer halt+pausa ya que no soporta floating bus

	ld bc, $92ff		;10
buscheck1:
	nop					;4		ajuste nos faltan 4t-states
	ld a, c				;4
	in a, ($FF)			;11		vamos comprobando cada 33 t-states para ir alternando posiciones
	cp b				;4		hasta encontrar un bipmap con $92
	jp nz, buscheck1	;10		
	ld a, 10			;7
buscheck2:
	and c				;4		 
	dec a				;4
	jp nz, buscheck2	;10		18x10 =180
	nop					;4		ajuste 
	nop					;4		ajuste
	ld a, c				;4		
	in a, ($FF)			;11		comprobamos a los 224T-states el mimsmo bipmap de la siguiente linea
	cp b				;4		si el caracter tambien es $92 continuamos
	jp nz, 	buscheck1	;10		si no lo es volvemos a empezar
	ld a, 9				;7
buscheck3:
	and $ff				;7
	dec a				;4
	jp nz, buscheck3	;10		21x9 =189
	ld a, c				;4		
	in a, ($FF)			;11		comprobamos a los 225T-states en la siguiente linea el color
	cp $01				;7		si el color es $01 estamos donde queremos
	jp nz, 	buscheck1	;10		si no volvemos a empezar

	ret					;al llegar aqui estamos en la linea del marcador
;						;y podemos empezar a borrar los dirty
buscheckinves:
	halt				;sincronizamos con inicio pantalla
	ld bc, $04C0		;hacemos una pausa para alcanzar la linea 18 en un inves
buscheckinves1			;para situarnos en el 3er tercio de pantalla
	dec bc				;y empezar a borrar
	ld a, b
	or c
	jr nz, buscheckinves1
	;aqui tenemos que comprobar si es un inves y salir si lo es
	;pero si no lo es a�adir otra pausa para llegar al 3er tercio ya que lo clonicos empiezan a pintar la pantalla por el borde

	ld a, (I.esuninves)		;comprobamos si es un inves
	or a
	ret nz					;cualquier valor distinto de cero es un inves y regresamos
	
	ld bc, $0190			;pero si no es un inve tenemos que a�adir otra pausa para llegar a la linea 18
buscheckclonico1			;para situarnos en el 3er tercio de pantalla
	dec bc					;y empezar a borrar
	ld a, b
	or c
	jr nz, buscheckclonico1


	ret


END_CODE_PAGE3:		;no debe pasar de $AC7F			<<<<<<<<<<<<<<<<<<
org $ac80			;por protecion si nos pasamos de aqui saltara un error al compilar

org $BD00
 INCLUDE "rotatetable48k.asm"	; sprite rotation tables

END_PAGE3:
 INCLUDE "sprite48k.asm"
END_PAGE4:
