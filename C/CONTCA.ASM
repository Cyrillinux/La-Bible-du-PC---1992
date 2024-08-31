;**********************************************************************;
;*                         C O N T C A . A S M                        *;
;*--------------------------------------------------------------------*;
;*   Fournit une fonction … inclure dans le programme CONTC.C         *;
;*   qui renvoie un pointeur sur le jeu de caractŠres 8*14            *;
;*   d'une carte EGA ou VGA                                           *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   : 23.08.1990                                     *;
;*    DerniŠre MAJ   : 14.02.1992                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM /mx CONTCA                                *;
;*            ou     : TASM -mx LAUFTCA                               *;
;*           ... puis lier avec CONTC.C                               *;
;**********************************************************************;

IGROUP group _text                  ; Regroupe les segments de programme
DGROUP group _bss,  _data             ; Regroupe les segments de donn‚es

       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS'     ; Segment pour toutes les variables
_BSS   ends                                 ; statiques non initialis‚es

_DATA  segment word public 'DATA'       ; Segment des variables globales
                                             ; et statiques initialis‚es

_DATA  ends

;== Programme =========================================================;

_TEXT  segment byte public 'CODE'                 ; Segment de programme

       public   _getfontptr                        ; Fonction accessible

;-- GETFONTPTR: Renvoie un pointeur FAR sur le jeu de caractŠres 8*14---
;-- D‚claration : void far * getfontptr( void ) ------------------------

_getfontptr     proc near

          push  bp                                       ; Sauvegarde BP

          mov   ax,1130h                    ; Charge les registres avant
          mov   bh,2
          int   10h                     ; d'appeler l'interruption vid‚o

          mov   dx,es                         ; TransfŠre ES:BP en DX:AX
          mov   ax,bp

          pop   bp                              ; Reprend BP sur la pile

          ret                                    ; Retourne … l'appelant

_getfontptr     endp                               ; Fin de la proc‚dure

;== Fin ===============================================================

_text  ends                                ; Fin du segment de programme
       end                              ; Fin de la source en assembleur
