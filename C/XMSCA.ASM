;**********************************************************************;
;*                           X M S C A . A S M                        *;
;*--------------------------------------------------------------------*;
;*    Sujet          : Routine en assembleur destin‚e … ˆtre int‚gr‚e *;
;*                     au programme XMSC.C. Permet de disposer d'une  *;
;*                     routine d'appel du pilote XMS.                 *;
;*                     Cette impl‚mentation est destin‚e au modŠle de *;
;*                     m‚moire SMALL.                                 *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    d‚velopp‚ le   : 27.07.1990                                     *;
;*    derniŠre m. … j: 27.07.1990                                     *;
;*--------------------------------------------------------------------*;
;*    assembler      : MASM XMSCA;   ou     TASM XMSCA;               *;
;*                     ... ensuite lier au programme C compil‚        *;
;*                         XMSC.C                                     *;
;**********************************************************************;

;== D‚clarations des segments pour le programme en C ===================

IGROUP group _text                  ;Regroupement des segments programme
DGROUP group _bss,  _data          ;Regroupement des segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS' ;Ce segment contient ttes les variables
_BSS   ends                                  ;statiques non initialis‚es

_DATA  segment word public 'DATA'     ;Toutes les variables initialis‚es
                                  ;globales et statiques sont regroup‚es
                                                        ;dans ce segment

extrn _XMSPtr : dword                         ;R‚f‚rence au pointeur XMS

_DATA  ends

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'               ;Le segment de programme

public     _XMSCall

;-----------------------------------------------------------------------
;-- XMSCall : Routine g‚n‚rale d'appel d'une fonction XMS
;-- Appel C : void XMSCall( BYTE NumFonct, XMSRegs *Xr ) avec
;--           typedef struct { WORD AX, BX, DX, SI, Segment } XMSRegs;
;-- Retour  : aucun
;-- Info    : - Avant l'appel de cette proc‚dure, charger excusivement
;--             les registres effectivement n‚cessaires … l'appel de la
;--             fonction.
;--      - AprŠs l'appel de la fonction XMS, les contenus des registres
;--        du processeur sont copi‚s dans les composant correspondants
;--             de la structure renvoy‚e.
;--      - Le premier appel de cette proc‚dure doit ˆtre pr‚c‚d‚ d'un
;--             appel en bon ordre de la proc‚dure XMSInit.

_XMSCall   proc near

sframe     struc                       ;Structure pour acc‚der … la pile
bp0         dw ?                                              ;stocke BP
ret_adr     dw ?                      ;Adresse de retour pour l'appelant
NumFonc     dw ?                              ;Num‚ro de la fonction XMS
xrptr       dw ?                ;Pointeur sur la structure des registres
sframe     ends

frame  equ [ bp - bp0 ]            ;adresse les ‚l‚ments de la structure

      push   bp                                  ;Copions BP sur la pile
      mov    bp,sp                                  ;Passons SP aprŠs BP

      push   si                               ;Sauvegarde de SI et de DI
      push   di

      mov    cx,ds                                   ;Copions DS dans CX
      push   cx                              ;et sauvegarder sur la pile
      mov    di,frame.xrptr                ;Chargement du nø de fonction
      mov    ah,byte ptr frame.NumFonc  ;Chargement du ptr sur la struct
      mov    bx,[di+2]            ;Chargement des registres stock‚s dans
      mov    dx,[di+4]                   ;les composants de la structure
      mov    si,[di+6]
      mov    ds,[di+8]
      mov    es,cx                                    ;Charge ES avec DS
      call   es:[_XMSPtr]                          ;Appel du Handler XMS
      mov    cx,ds                                    ;Stocke DS dans CX
      pop    ds                                  ;R‚cup‚rons l'ancien DS
      mov    di,frame.xrptr     ;Chargement du pointeur sur la structure
      mov    [di],ax                     ;Entre les registres dans leurs
      mov    [di+02],bx                        ;composants respectifs de
      mov    [di+04],dx                                 ;de la structure
      mov    [di+06],si
      mov    [di+08],cx

      pop    di                                       ;R‚cupŠre SI et DI
      pop    si

      pop    bp                       ;R‚cupŠre BP qui ‚tait sur la pile
      ret                                      ;Retour au programme en C

_XMSCall   endp

;-----------------------------------------------------------------------

_text      ends                                  ;Fin du segment de code
           end                                         ;Fin du programme
