;**********************************************************************;
;*                         V 3 2 4 0 C A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction       : contient diverses routines pour travailler     *;
;*                     dans le mode graphique 320*400 en 256 couleurs *;
;*                     de la carte VGA                                *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   :  5.09.1990                                     *;
;*    DerniŠre MAJ   : 14.01.1991                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM /mx V3240CA;    ou   TASM -mx V3240CA     *;
;*                     ... puis lier … V3240C.C                       *;
;**********************************************************************;

IGROUP group _text                  ; Regroupe les segments de programme
DGROUP group const, _bss,  _data       ;Regroupe les segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

CONST  segment word public 'CONST'
CONST  ends

_BSS   segment word public 'BSS'        ;Segment des variables statiques
_BSS   ends                                            ;non initialis‚es

_DATA  segment word public 'DATA'        ;Segment des variables globales
                                          ;et statiques non initialis‚es


_DATA  ends

;== Constantes =========================================================


SC_INDEX       = 3c4h    ;Registre d'index du contr“leur du s‚quenceur .
SC_MAP_MASK    = 2                          ;Num‚ro du registre Map-Mask
SC_MEM_MODE    = 4                   ;Num‚ro du registre de mode m‚moire

GC_INDEX       = 3ceh          ;registre d'index du contr“leur graphique
GC_READ_MAP    = 4                          ;Num‚ro du registre Read Map
GC_GRAPH_MODE  = 5                 ;Num‚ro du registre de mode graphique
GC_MISCELL     = 6                            ;Num‚ro du registre divers

CRTC_INDEX     = 3d4h            ;registre d'index du contr“leur d'‚cran
CC_MAX_SCAN    = 9     ;Num‚ro du registre du maximum de lignes balay‚es
CC_START_HI    = 0Ch                        ;Num‚ro du registre Hi_Start
CC_UNDERLINE   = 14h                 ;Num‚ro du registre de soulignement
CC_MODE_CTRL   = 17h             ;Nummer du registre de contr“le de mode

VERT_RETRACE   = 3DAh                       ;Registre d'‚tat d'entr‚e #1

PIXX           = 320                             ;R‚solution horizontale

;== Donn‚es=============================================================

_DATA  segment word public 'DATA'

vio_seg    dw 0a000h                      ;Segment de la m‚moire d'‚cran
                                                  ;avec la page courante

_DATA  ends

;== Programme===========================================================

_TEXT  segment byte public 'CODE'                  ;Segment de programme

;-- Public-Deklarationen -----------------------------------------------

public    _init320400                        ;Initialise le mode 320*400
public    _setpix                                      ;Dessine un point
public    _getpix                       ;D‚termine la couleur d'un pixel
public    _showpage                              ;Affiche la page 0 ou 1
public    _setpage                   ;Fixe la page pour setpix et getpix
public    _getfontptr ;Retourne un pointeur sur le jeu de caractŠres 8*8

;-- INIT320400: initialise le mode 320*400 -----------------------------
;-- D‚claration : void init320400( void ); -----------------------------

_init320400 proc near


       ;-- Commence par installer le mode 13h pour que le BIOS ---------
       ;-- effectue la plus grande partie de l'initialisation ----------
       ;-- Puis modifie les registres qui n'ont pas encore le ----------
       ;-- contenu souhait‚ --------------------------------------------

       mov   ax,0013h                             ;D‚clenche le mode 13h
       int   10h


       mov   dx,GC_INDEX           ;D‚sactive la s‚paration des adresses
       mov   al,GC_GRAPH_MODE      ;m‚moire dans registre mode graphique
       out   dx,al                              ;du contr“leur graphique
       inc   dx                           ;en manipulant le bit num‚ro 4
       in    al,dx
       and   al,11101111b
       out   dx,al
       dec   dx

       mov   al,GC_MISCELL                 ;idem dans le registre divers
       out   dx,al                        ;en manipulant le bit num‚ro 1
       inc   dx                                                        ;
       in    al,dx
       and   al,11111101b
       out   dx,al

       mov   dx,SC_INDEX            ;Modifie le registre de mode m‚moire
       mov   al,SC_MEM_MODE            ;dans le contr“leur du s‚quenceur
       out   dx,al               ;de fa‡on … mettre fin … la r‚partition
       inc   dx                ;des adresses sur plusieurs plans de bits
       in    al,dx           ;et … fixer le plan courant par le registre
       and   al,11110111b                           ;de masquage binaire
       or    al,4                                                      ;
       out   dx,al

       mov   ax,vio_seg                   ;Remplit les quatre plans bits
       mov   es,ax                             ;avec le code couleur 00h
       xor   di,di                                    ;et efface l'‚cran
       mov   ax,di


       mov   cx,8000h
       rep   stosw

       mov   dx,CRTC_INDEX ;Met fin au d‚doublement des lignes de pixels
       mov   al,CC_MAX_SCAN          ;en manipulant le bit 7 du registre

       out   dx,al          ;du maximum de lignes balay‚es du contr“leur
       inc   dx        ;fixe en mˆme temps … 1 la hauteur des caractŠres
       in    al,dx                                     ;par les bits 0-4
       and   al,01110000b                                              ;
       out   dx,al
       dec   dx             ;DX = registre d'index du contr“leur d'‚cran

       mov   al,CC_UNDERLINE                  ;Arrˆte le mode double mot
       out   dx,al                               ;en manipulant le bit 6
       inc   dx                             ;du registre de soulignement
       in    al,dx
       and   al,10111111b
       out   dx,al
       dec   dx

       mov   al,CC_MODE_CTRL            ;Passe du mode mot au mode octet
       out   dx,al                ;par manipulation du bit 6 du registre
       inc   dx                                     ;de contr“le de mode
       in    al,dx
       or    al,01000000b
       out   dx,al

       ret                                         ;Rtourne … l'appelant

_init320400 endp                                    ;Fin de la proc‚dure

;-- SETPIX: Dessine un pixel dans une couleur donn‚e  ------------------
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

       push  di                               ;Sauvegarde DI sur la pile

       mov   ax,PIXX / 4            ;Calcule l'offset en m‚moire d'‚cran
       mul   frame.y0                               ; et le charge en DI
       mov   cx,frame.x0
       mov   bx,cx
       shr   bx,1
       shr   bx,1
       add   ax,bx
       mov   di,ax

       and   cl,3                       ;Calcule en AH le masque binaire
       mov   ah,1                                ; pour adresser le plan
       shl   ah,cl
       mov   al,SC_MAP_MASK                    ;Num‚ro du registre en AL
       mov   dx,SC_INDEX         ;Charge l'adresse d'index du s‚quenceur
       out   dx,ax               ;Charge le registre de masquage binaire

       mov   ax,vio_seg          ;ES doit pointer sur la m‚moire d'‚cran
       mov   es,ax
       mov   al,byte ptr frame.couleur       ;Charge la couleur du pixel
       stosb                          ; et la place dans le plan de bits
       pop di                                    ; D‚pile le registre DI
       pop   bp                                           ; ainsi que BP

       ret                                        ;Retourne … l'appelant

_setpix    endp                                     ;Fin de la proc‚dure

;-- GETPIX: d‚termine la couleur d'un pixel   --------------------------
;-- D‚claration : unsigned char getpix( int x, int y ); ----------------

_getpix    proc near

sframe1   struc                             ;Structure d'accŠs … la pile
bp1        dw ?                                             ;M‚morise BP
ret_adr1   dw ?                          ;Adresse de retour … l'appelant
x1         dw ?                                              ;Abscisse X
y1         dw ?                                              ;Ordonn‚e Y
sframe1   ends                                      ;Fin de la structure

frame  equ [ bp - bp1 ]            ;Adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       push  si                               ;Sauvegarde SI sur la pile

       mov   ax,PIXX / 4              ;Calcule l'offset en m‚moire et le
       mul   frame.y1                                     ; charge en SI
       mov   si,frame.x1
       mov   cx,si
       shr   si,1
       shr   si,1
       add   si,ax

       and   cl,3                  ;Calcule en AH le masque binaire pour
       mov   ah,cl                                     ;adresser le plan
       mov   al,GC_READ_MAP                    ;Num‚ro du registre en AL
       mov   dx,GC_INDEX        ;Adresse d'index du contr“leur graphique
       out   dx,ax                          ;Charge le registre Read Map

       mov   ax,vio_seg          ;ES doit pointer sur la m‚moire d'‚cran
       mov   es,ax
       mov   al,es:[si]                      ;Charge la couleur du pixel
       pop   si                       ;Reprend les registres sur la pile
       pop   bp

       ret                                        ;Retourne … l'appelant

_getpix    endp                                     ;Fin de la proc‚dure

;-- SETPAGE: S‚lectionne la page concern‚e par les appels aux fonctions-
;--          setpix et getpix
;-- D‚claration : void setpage( unsigend char page );

_setpage   proc near

       pop   bx                              ;D‚pile l'adresse de retour
       pop   ax                                          ; et l'argument

       push  ax                            ; puis le replace sur la pile
       push  bx

       mov   bl,0a0h                                                   ;
       or    al,al                                    ;Est-ce la page 0?
       je    sp1                               ;Oui, m‚morise le segment
       mov   bl,0a8h                                ;Non c'est la page 1

sp1:   mov   byte ptr vio_seg + 1,bl           ;Nouvelle adresse segment

       ret                                        ;retourne … l'appelant

_setpage   endp                                     ;Fin de la proc‚dure

;-- SHOWPAGE: Affiche l'une des deux pages d'‚cran ---------------------
;-- D‚claration : void showpage( unsigend char page ); -----------------

_showpage  proc near

       pop   bx                              ;D‚pile l'adresse de retour
       pop   ax                                          ; et l'argument

       push  ax                            ;Puis les replace sur la pile
       push  bx

       or    al,al                                    ;Est-ce la page 0?
       je    sp2    ;Oui, son num‚ro est ‚gal … l'octet fort de l'offset

       mov   al,80h                      ;Non, page 1, avec offset 8000h

sp2:   mov   dx,CRTC_INDEX                ;Adresse le contr“leur d'‚cran
       mov   ah,al                ;Charge en AH l'octet fort de l'offset
       mov   al,CC_START_HI                    ;Num‚ro du registre en AL
       out   dx,ax                                   ;Effectue la sortie

       ;-- Attend un d‚but de rafraŒchissement d'‚cran  ----------------

       mov   dx,VERT_RETRACE        ;Attend la fin du retour de balayage
sp3:   in    al,dx                                             ;vertical
       test  al,8
       jne   sp3

sp4:   in    al,dx                  ;puis le d‚but du retour du faisceau
       test  al,8
       je    sp4

       ret                                        ;Retourne … l'appelant

_showpage  endp                                     ;Fin de la proc‚dure

;-- GETFONTPTR: Renvoie un pointeur FAR sur le jeu de caractŠres 8*8 ---
;-- D‚claration : void far * getfontptr( void )

_getfontptr proc near

       push  bp                                                ;Sauve BP

       mov   ax,1130h                         ;Charge les registres puis
       mov   bh,3
       int   10h                        ; d‚clenche l'interruption vid‚o

       mov   dx,es                           ;TransfŠre ES:BP dans DX:AX
       mov   ax,bp

       pop   bp                                  ;Reprend BP sur la pile
       ret                                        ;Retourne … l'appelant

_getfontptr endp                                    ;Fin de la proc‚dure

;== Fin ================================================================

_text    ends                               ;Fin du segment de programme
         end                             ;Fin de la source en assembleur
