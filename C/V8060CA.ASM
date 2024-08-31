;**********************************************************************;
;*                       V 8 0 6 0 C A . A S M                        *;
;*--------------------------------------------------------------------*;
;*    Fonction       : contient diverses routines pour travailler     *;
;*                     dans le mode 800*600 des cartes Super-VGA-     *;
;*                     avec 16 couleurs                               *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    : 14.01.1991                                    *;
;*    DerniŠre MAJ    : 14.02.1992                                    *;
;*--------------------------------------------------------------------*;
;*    ModŠle m‚moire  : SMALL                                         *;
;*--------------------------------------------------------------------*;
;*    Assemblage   : MASM /mx V8060CA     ou   TASM -mx V8060CA       *;
;**********************************************************************;

IGROUP group _text                   ;Regroupe les segments de programme
DGROUP group _bss,  _data              ;Regroupe les segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS'        ;Segment des variables statiques
_BSS   ends                                           ; non initialis‚es

_DATA  segment word public 'DATA'        ;Segment des variables globales
                                             ; et statiques initialis‚es


_DATA  ends

;== Constantes =========================================================

GC_INDEX       = 3ceh          ;Registre d'index du contr“leur graphique
GC_READ_MAP    = 4                          ;Num‚ro du registre Read Map
GC_BIT_MASK    = 8               ;Num‚ro du registre de masquage binaire
GC_GRAPH_MODE  = 5                 ;Num‚ro du registre de mode graphique

;== Donn‚es=============================================================

_DATA  segment word public 'DATA'

        ;-- Num‚ro de code associ‚ au mode 800*600 de diff‚rentes ------
        ;-- cartes Super-VGA -------------------------------------------

modenr     db 6Ah, 58h, 29h, 54h, 16h, 79h
modenrend  equ this byte

_DATA  ends

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'                  ;Segment de programme

;-- D‚clarations publiques ---------------------------------------------

public    _init800600                        ;Initialise le mode 800*600
public    _setpix                                      ;Dessine un pixel
public    _getpix                             ;Lit la couleur d'un pixel
public    _getfontptr  ;Renvoie un pointeur sur le jeu de caractŠres 8*8

;-----------------------------------------------------------------------
;-- INIT800600: initialise le mode 800*600 Super-VGA en 16 couleurs

;-- D‚claration : int init800600( void );
;-- Valeur de retour : 1 = mode initialis‚ , 0 = Erreur

_init800600 proc near

       ;-- Essaye les modes du tableau MODENR jusqu'… ce que l'un d'eux-
       ;--   soit accept‚ par le BIOS ----------------------------------

       mov  si,offset modenr    ;Commence par le premier mode du tableau
it1:   xor  ah,ah                      ;Fonction 00h: initialise le mode
       mov  al,[si]                 ;Charge le num‚ro de code du tableau
       int  10h                                      ;Initialise le mode
       mov  ah,0fh                          ;Fonction 0Fh: teste le mode
       int  10h
       cmp  al,[si]                        ;Le mode s'est-il d‚clench‚ ?
       je   it2                                              ;Oui --> OK

       ;-- Mauvais num‚ro de code, choisit le suivant dans le tableau --

       inc  si                                   ;SI sur le code suivant
       cmp  si,offset modenrend         ;A-t-on parcouru tt le tableau ?
       jne  it1                                      ;Non, on recommence

       xor  ax,ax               ;Oui, cl“ture la fonction par une erreur
       ret                                        ;Retourne … l'appelant

it2:   ;-- Le mode a pu ˆtre initialis‚ --------------------------------

       mov  ax,1                                           ;tout est bon
       ret                                          ;Retour … l'appelant

_init800600 endp                                    ;Fin de la proc‚dure

;-- SETPIX: Dessine un pixel dans une couleur donn‚e --------------
;-- D‚claration : void setpix( int x, int y, unsigned char couleur );

_setpix    proc near

sframe    struc                             ;Structure d'accŠs … la pile
bp0        dw ?                                             ;M‚morise BP
ret_adr0   dw ?                          ;Adresse de retour … l'appelant
x0         dw ?                                              ;Abscisse X
y0         dw ?                                              ;Ordonn‚e Y
couleur    dw ?                                                 ;Couleur
sframe    ends                                      ;Fin de la structure

frame  equ [ bp - bp0 ]            ;adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       ;-- Calcule l'offset dans la m‚moire d'‚cran et le d‚calage -----

       mov   ax,frame.y0                           ;Charge l'ordonn‚e  Y
       mov   dx,800/8              ;Multiplie par la largeur d'une ligne
       mul   dx
       mov   bx,frame.x0                            ;Charge l'abscisse X
       mov   cl,bl               ;M‚morise l'octet faible pour le calcul
                                                           ; du d‚calage

       shr   bx,1                          ;Divise l'abscisse X par huit
       shr   bx,1
       shr   bx,1
       add   bx,ax          ;Y ajoute l'offset issu de la multiplication

       and   cl,7               ;Calcule le masque binaire … partir de X
       xor   cl,7
       mov   ah,1
       shl   ah,cl

       mov   dx,GC_INDEX                 ;AccŠde au contr“leur graphique
       mov   al,GC_BIT_MASK          ;Masque bin. dans registre masquage
       out   dx,ax                                  ; Effectue la sortie

       mov   ax,(02h shl 8) + GC_GRAPH_MODE ;D‚clenche le mode Write 2 &
       out   dx,ax                                               ;Read 0

       mov   ax,0A000h   ;Charge en RES le segment de la m‚moire d'‚cran
       mov   es,ax

       mov   al,es:[bx]                        ;Charge le registre latch
       mov   al,byte ptr frame.couleur                  ;Fixe la couleur
       mov   es:[bx],al                       ;R‚‚crit le registre latch

       ;-- Remet les valeurs par d‚faut dans les diff‚rents registres --
       ;-- du contr“leur graphique , qui ont ‚t‚ modifi‚s --------------

       mov   ax,(0FFh shl 8 ) + GC_BIT_MASK
       out   dx,ax

       mov   ax,(00h shl 8) + GC_GRAPH_MODE
       out   dx,ax

       pop   bp
       ret                                        ;Retourne … l'appelant

_setpix    endp                                     ;Fin de la proc‚dure

;-- GETPIX: D‚termine la couleur d'un pixel ----------------------------
;-- D‚claration : unsigned char getpix( int x, int y );

_getpix    proc near

sframe1   struc                             ;Structure d'accŠs … la pile
bp1        dw ?                                             ;M‚morise BP
ret_adr1   dw ?                          ;Adresse de retour … l'appelant
x1         dw ?                                              ;Abscisse X
y1         dw ?                                              ;Ordonn‚e Y
sframe1   ends                                      ;Fin de la structure

frame  equ [ bp - bp1 ]            ;adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       push  si

       ;-- Calcule d'abord l'offset en m‚moire d'‚cran et le d‚calage --

       mov   ax,frame.y1                            ;Charge l'ordonn‚e Y
       mov   dx,800 / 8            ;Multiplie par la largeur d'une ligne
       mul   dx
       mov   si,frame.x1                            ;Charge l'abscisse X
       mov   cx,si                         ;La m‚morise pour le d‚calage

       shr   si,1                            ;Divise l'abscisse par huit
       shr   si,1
       shr   si,1
       add   si,ax          ;Y ajoute l'offset issu de la multiplication

       and   cl,7               ;Calcule le masque binaire … partir de X
       xor   cl,7
       mov   ch,1
       shl   ch,cl

       mov   ax,0A000h                          ;Charge en ES le segment
       mov   es,ax                               ; de la m‚moire d'‚cran

       mov   dx,GC_INDEX                 ;AccŠde au contr“leur graphique
       mov   ax,(3 shl 8)+ GC_READ_MAP                      ;Lit d'abord
       xor   bl,bl                                           ; le plan 3

gp1:   out   dx,ax                        ;Indique le plan de bit … lire
       mov   bh,es:[si]              ;Charge la valeur du registre latch
       and   bh,ch                       ;Ne garde que le pixel souhait‚
       neg   bh                      ;Fixe le bit 7 en fonction du pixel
       rol   bx,1              ;Rotation bit 7 de BH vers bit 1 dans BL.

       dec   ah                          ;Traite le plan de bits suivant
       jge   gp1                     ;sup ou ‚gal … 0 ? ---> on continue

       mov   al,bl                        ;R‚sultat de la fonction en AL

       pop   si
       pop   bp
       ret                                        ;Retourne … l'appelant

_getpix    endp                                     ;Fin de la proc‚dure

;-- GETFONTPTR: Renvoie un pointeur FAR sur le jeu de caractŠres 8*8 ---
;-- D‚claration : void far * getfontptr( void )

_getfontptr proc near

      push  bp                                                ;Empile BP

      mov   ax,1130h           ;Charge les registres pour l'interruption
      mov   bh,3
      int   10h                  ;D‚clenche l'interruption vid‚o du BIOS

      mov   dx,es                   ;Retourne le pointeur ES:BP en DX:AX
      mov   ax,bp

      pop   bp                                   ;Reprend BP sur la pile
      ret                                         ;Retourne … l'appelant

_getfontptr endp                                    ;Fin de la proc‚dure

;== Fin ================================================================

_text    ends                               ;Fin du segment de programme
         end                             ;Fin de la source en assembleur
