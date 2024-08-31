;**********************************************************************;
;*                          E X E S Y S . A S M                       *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Propose un squelette de driver qui peut ˆtre   *;
;*                     lanc‚ … partir de la ligne de commande         *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   : 01.11.1991                                     *;
;*    DerniŠre MAJ   : 02.03.1992                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM EXESYS;                                   *;
;*                     LINK EXESYS;                                   *;
;*                   ou                                               *;
;*                     TASM EXESYS                                    *;
;*                     TLINK EXESYS                                   *;
;**********************************************************************;

code     segment

     assume cs:code,ds:code

     org 0                                   ;Programme sans PSP, d‚bute
                                                          ; … l'offset 0

;== Constantes =========================================================

befehl   equ 2    ;Offset du champ d'instruction dans le bloc de donn‚es
status   equ 3           ;Offset du champ d'‚tat dans le bloc de donn‚es
end_adr  equ 14  ;Offset de l'adr. de fin du driver dans bloc de donn‚es

;== Donn‚es ============================================================

;-- En-tˆte du driver  -------------------------------------------------

     dw -1,-1                               ;Lien avec le driver suivant
     dw 1010000000000000b                            ;Attribut du driver
     dw offset strat               ;Pointeur sur la routine de strategie
     dw offset intr              ;Pointeur sir la routine d'interruption
     db "$$EXESYS"                                        ;Nom du driver

db_ptr   dw (?),(?)                 ;Adresse du bloc de donn‚es transmis

;=======================================================================
;==                        Routines du programme EXE                  ==
;=======================================================================

exestart proc far

     push cs                                                    ;DS = CS
     pop  ds

     mov  ah,09h                                     ;Affiche un message
     mov  dx,offset exemes
     int  21h

     mov  ax,4C00h                   ;Terminaison normale d'un programme
     int  21h

exestart endp

exemes   db "EXESYS - (c) 1991, 92 by Michael TISCHER", 13,10,10
         db "Appel comme un programme EXE !", 13, 10, "$"


;=======================================================================
;==                  Routines et fonctions du driver                  ==
;=======================================================================
strat    proc far                                  ;Routine de strat‚gie

     mov  cs:db_ptr,bx                  ;M‚morise en DB_PTR l'adresse du
     mov  cs:db_ptr+2,es                               ; bloc de donn‚es

     ret                                          ;Retourne … l'appelant

strat    endp

;-----------------------------------------------------------------------

intr     proc far                                ;Routine d'interruption

     push ax                       ;Sauvegarde les registres sur la pile
     push bx
     push cx
     push dx
     push di
     push si
     push bp
     push ds
     push es
     pushf                       ;y compris le registres des indicateurs

     push cs                     ;Fixe le registre du segment de donn‚es
     pop  ds                          ;Le code co‹ncide avec les donn‚es

     les  di,dword ptr db_ptr       ;Adresse du bloc de donn‚es en ES:DI
     mov  ax,8003h                                      ;Erreur a priori
     cmp  byte ptr es:[di+befehl],00h   ;Seule fonction init est permise
     jne  short intr_end                    ;Erreur, retour … l'appelant

     call init                         ;Ne peut ˆtre que la fonction 00h

     ;-- Ex‚cution de la fonction termin‚e -----------------------------

intr_end label near

     or   ax,0100h                               ;Met … 1 le bit Termin‚
     mov  es:[di+status],ax          ;Sauve le tout dans le champ d'‚tat

     popf                          ;R‚cupŠre le registre des indicateurs
     pop  es                             ;ainsi que les autres registres
     pop  ds
     pop  bp
     pop  si
     pop  di
     pop  dx
     pop  cx
     pop  bx
     pop  ax

     ret                                          ;Retourne … l'appelant

intr     endp

;-----------------------------------------------------------------------
;-- Lorsque l'appel est adress‚ au driver, la m‚moire est lib‚r‚e
;-- … partir d'ici

init     proc near                             ;Routine d'initialisation

     mov  word ptr es:[di+end_adr],offset init           ;Fixe l'adresse
     mov  es:[di+end_adr+2],cs                        ; de fin du driver

     mov  ah,09h                                     ;Affiche un message
     mov  dx,offset ddmes
     int  21h

     xor  ax,ax                                            ;tout va bien
     ret                                          ;retourne … l'appelant

init     endp

;-- Donn‚es qui ne sont plus n‚cessaires aprŠs l'initialisation -----

ddmes    db "EXESYS - (c) 1991, 92 by Michael TISCHER", 13,10,10
         db "Appel au driver ", 13, 10, "$"

;=======================================================================

code     ends
         end exestart
