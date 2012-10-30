; Copyright (c) 2005 - 2006 Charles Rincheval - http://www.digitalspirit.org
; All rights reserved.
;
; This source code is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
; 
; It is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; 
; You should have received a copy of the GNU General Public License
; along with this source code; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA



	; +------------------------+
	; | Quelle bête utilisée ? |
	; +------------------------+
	LIST      p=10F206-
	#include <p10F206.inc>

	; +-----------+
	; | La config |
	; +-----------+
	__CONFIG   _MCLRE_OFF & _CP_ON & _WDT_ON & _IntRC_OSC


	; +--------+
	; | Define |
	; +--------+
;	#DEFINE	OUTPUT	GPIO, 2			; the Output(exit) of the data 
;	#DEFINE	RAM_START H '07' 

	#define	DBUG0		GPIO, 0
	#define	DBUG1		GPIO, 1

	#define	PIN_SERIAL	GPIO, 2
	#define	INPUT		GPIO, 3


	; +-------+
	; | Macro |
	; +-------+
TEMPO	MACRO
;		movlw	.15
		movlw	.14
		movwf	tempo
		decfsz	tempo, F
		goto	$ - 1
		ENDM

BIG_TEMPO	MACRO
		movlw	.254
		movwf	tempo
		decfsz	tempo, F
		goto	$ - 1
		ENDM


	; +-------------------+
	; | Zone de variables |
	; +-------------------+
  	CBLOCK  	0x08
		cmpt : 1		; Compteur de boucle
		bcl : 1			; Compteur de boucle
		bclp :1			; Compteur de boucle

		tmp : 1			; Variable tempo

		tempo : 1		; Macro

		value : 1		; Valeur courante reçue
	
		tab0 : 1		; Tableau de valeurs
		tab1 : 1
		tab2 : 1
		tab3 : 1
		tab4 : 1
		tab5 : 1
;		tab6 : 1
;		tab7 : 1

		tmpt0 : 1		; Pour le "swappage"
		tmpt2 : 1
 	ENDC

; Start
	org		0x00
	movwf	OSCCAL

	bcf		OSCCAL, FOSC4

	movlw	b'11000000'
	option

	bcf		CMCON0, CMPON

	clrwdt

	movlw	b'00001000'
	tris	GPIO

	bcf		PIN_SERIAL
	bcf		DBUG0
	bcf		DBUG1

	clrf	value
	call	init_tab

;	movlw	tab
;	movwf	FSR
;	movlw	0xFF
;	movwf	value
;	goto	_main_save

;paf
;	bcf		PIN_SERIAL
;	call	sync
;	bsf		PIN_SERIAL
;	goto	paf

; Boucle principale
main

;	movlw	0x80
;	movwf	tab0
;
;	movlw	0x81
;	movwf	tab1
;
;	movlw	0x82
;	movwf	tab2
;
;	movlw	0x83
;	movwf	tab3
;
;	movlw	0x84
;	movwf	tab4
;
;	movlw	0x85
;	movwf	tab5
;
;	movlw	0xFF
;	call	rs232Send
;
;	TEMPO
;
;	call	send_tab
;
;	goto	main


	movlw	tab0
	movwf	FSR

	movlw	.6
	movwf	bclp

_main_wait

	clrwdt

	; On attend une impulsion sur GPIO
	btfss	INPUT
	goto	_main_wait

	; On est prêt à en recevoir 6
_measure_bcl

	; Tant que l'impulsion est là, on compte
_measure_next
	incf	value

	btfsc	STATUS, Z
	goto	_main_0

	btfss	INPUT
	goto	_main_save
	goto	_measure_next

_main_0
	movlw	0xFE
	movwf	value

_main_save

	movf	value, W
	movwf	INDF

	; La valeur ne peut être égale à 0xFF
	movf	value, W
	comf	value, F
	btfsc	STATUS, Z
	decf	INDF

	incf	FSR
	
	clrf	value

	decfsz	bclp, F
	goto	_main_wait

; C'est fini, on envoie la trame !
_main_end
	movlw	0xFF
	call	rs232Send	; 0xFF en premier

	TEMPO

	call	swap_tab

	call	send_tab	; Suivi du tableau

	call	sync		; On synchronises

	goto	main


; On sort d'ici une fois synchronisé
sync
	; On attend un niveau haut ...
	; ... qui dur plus de 10ms
_sync_wait
	movlw	.255
	movwf	bcl
_sync_wait_bcl
	btfss	INPUT
	goto	_sync_wait
	decfsz	bcl, F
	goto	_sync_wait_bcl

	; Et maintenant, faut que ça repasse ...
	; ... à 0
_sync_wait_next
	btfsc	INPUT
	goto	_sync_wait_next
	retlw	.1


; Initialisation du tableau
init_tab
	movlw	tab0
	movwf	FSR

	movlw	.8
	movwf	bcl
	movlw	0x80
_init_tab_bcl
	movwf	INDF
	incf	FSR
	decfsz	bcl, F
	goto	_init_tab_bcl

	retlw	.1


; Echange les valeurs dans le tableau
swap_tab

;	tab0 -> tab2
;	tab2 -> tab3
;	tab3 ->	tab0

;	tab4 -> tab5 (Add)

	movf	tab0, W
	movwf	tmpt0

	movf	tab2, W
	movwf	tmpt2


	movf	tab0, W
	movwf	tab2

	movf	tab3, W
	movwf	tab0

	movf	tmpt2, W
	movwf	tab3

	movf	tab4, W		;ça sert à rien ça ??!!
	movwf	tab5

	retlw	.1


; On envoie le contenu du tableau
send_tab
	movlw	tab0
	movwf	FSR

	movlw	.4
	movwf	bcl
_send_tab_bcl
	movf	INDF, W
	call	rs232Send

	TEMPO
	TEMPO

	incf	FSR
	decfsz	bcl, F
	goto	_send_tab_bcl

	retlw	.1


; Envoie le contenu de W
rs232Send:

	movwf	tmp
	comf	tmp

	bsf		PIN_SERIAL		; Envoie du bit de start
	TEMPO

	movlw	.8
	movwf	cmpt
_rs232Send_bcl:

	rrf		tmp, f

	btfsc	STATUS, C
	bsf		PIN_SERIAL
	btfss	STATUS, C
	bcf		PIN_SERIAL
	TEMPO

	decfsz	cmpt, F
	goto	_rs232Send_bcl

	bcf		PIN_SERIAL

	retlw	.1



	END
