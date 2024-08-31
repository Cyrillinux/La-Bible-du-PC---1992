;**********************************************************************;
;*                             S O U R I S C A                        *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Gestionnaire d'‚v‚nements appel‚ par le driver *;
;*                     de la souris. A int‚grer dans un programme C   *;
;*                     compil‚ avec le modŠle de m‚moire SMALL.       *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   : 20/04/1989                                     *;
;*    DerniŠre modif.: 20/04/1989                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM SOURISCA;                                 *;
;*                     ... combiner avec le programme C SOURISC.C     *;
;**********************************************************************;

;== D‚clarations de segment pour le programme C ========================

IGROUP group _text               ;Regroupement des segments de programme
DGROUP group _bss,  _data          ;Regroupement des segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS'  ;Re‡oit toutes les variables statiques
_BSS   ends                                            ;non initialis‚es

_DATA  segment word public 'DATA'       ;Variables globales et statiques
                                          ;initialis‚es sont log‚es dans
                                                             ;ce segment
_DATA  ends

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'               ;Le segment de programme

public     _AssHand              ;Donne au programme C la possibilit‚ de
                                   ;d‚terminer l'adresse du gestionnaire
                                                          ;en assembleur

extrn     _MouEventHandler : near    ;Driver d'‚v‚nements en C … appeler

actif     db  0                 ;Indique si un appel est encore en cours
                                                            ;d'ex‚cution

;-----------------------------------------------------------------------
;-- _AssHand : le gestionnaire d'‚v‚nements, qui est d'abord appel‚ par
;--            le driver de la souris, et appelle … son tour la
;--            fonction C MouEventHandler()
;-- Appel en C : interdit !

_AssHand   proc far

;- Sauvegarder tout d'abord tous les registres du processeur sur la pile

           cmp  actif,0                      ;Appel non encore termin‚ ?
           jne  fin                    ;Non --> ne pas permettre l'appel

           mov  actif,1                      ;Ne plus autoriser d'appels

           push ax
           push bx
           push cx
           push dx
           push di
           push si
           push bp
           push es
           push ds

           ;-- Placer sur la pile les arguments pour l'appel de la -----
                                                      ;-- fonction FCT_C
                ;-- Appel : MouEventHandler( int EvFlags, int ButStatus,
                      ;--                          int x,       int y );

           mov  di,cx               ;Ranger ordonn‚e horizontale dans DI
           mov  cl,3    ;Compteur de d‚calages pour num‚ro de coordonn‚e
           shr  dx,cl             ;Diviser DX (ordonn‚e verticale) par 8
           push dx                                ;et placer sur la pile

           shr  di,cl           ;Diviser DI (ordonn‚e horizontale) par 8
           push di                                ;et placer sur la pile

           push bx            ;Etat des boutons de la souris sur la pile
           push ax                ;Placer flags d'‚v‚nements sur la pile

           mov  ax,DGROUP          ;Adresse de segment du DGROUP dans AX
           mov  ds,ax                      ;et de l… dans le registre DS

           call _MouEventHandler                 ;Appel de la fonction C

           add  sp,8                      ;Eliminer arguments de la pile

           ;-- Retirer de la pile les registres sauvegard‚s ------------

           pop  ds
           pop  es
           pop  bp
           pop  si
           pop  di
           pop  dx
           pop  cx
           pop  bx
           pop  ax

           mov  actif,0                        ;Appel … nouveau autoris‚

fin:      ret                             ;Retour au driver de la souris

_AssHand   endp

;-----------------------------------------------------------------------

_text      ends                                  ;Fin du segment de code
           end                                         ;Fin du programme
