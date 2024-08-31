;**********************************************************************;
;*                         V 3 2 2 0 C A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction       : contient diverses routines pour travailler dans*;
;*                     le mode graphique 320*200 en 256 couleurs      *;
;*                     de la carte VGA                                *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   :  5.09.1990                                     *;
;*    DerniŠre MAJ   : 14.02.1992                                     *;
;*--------------------------------------------------------------------*;
;*    ModŠle m‚moire : SMALL                                          *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM /mx V3220CA;    ou     TASM -mx V3220CA   *;
;*                     ...puis lier … V3220C.C                        *;
;**********************************************************************;

IGROUP group _text                   ;Regroupe les segments de programme
DGROUP group _bss,  _data              ;Regroupe les segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS'        ;Segment des variables statiques
_BSS   ends                                            ;non initialis‚es

_DATA  segment word public 'DATA'                   ;Segment r‚serv‚ aux
                                        ;variables globales et statiques
                                                           ;initialis‚es

_DATA  ends

;== constantes =========================================================

SC_INDEX       = 3c4h      ;Registre d'index du contr“leur du s‚quenceur
SC_MAP_MASK    = 2                          ;Num‚ro du registre Map Mask
SC_MEM_MODE    = 4                   ;Num‚ro dy registre de mode m‚moire

GC_INDEX       = 3ceh          ;Registre d'index du contr“leur graphique
GC_READ_MAP    = 4                          ;Num‚ro du registre Read Map
GC_GRAPH_MODE  = 5                 ;Num‚ro du registre de mode graphique
GC_MISCELL     = 6                            ;Num‚ro du registre divers

CRTC_INDEX     = 3d4h            ;Registre d'index du contr“leur d'‚cran
CC_MAX_SCAN    = 9     ;Num‚ro du registre du maximum de lignes balay‚es
CC_START_HI    = 0Ch                        ;Num‚ro du registre Hi_Start
CC_UNDERLINE   = 14h                 ;Num‚ro du registre de soulignement
CC_MODE_CTRL   = 17h             ;Num‚ro du registre de contr“le de mode

DAC_WRITE_ADR  = 3C8h                                 ;Adresse DAC Write
DAC_READ_ADR   = 3C7h                                  ;Adresse DAC Read
DAC_DATA       = 3C9h                           ;Registre de donn‚es DAC

VERT_RETRACE   = 3DAh                       ;registre d'‚tat d'entr‚e #1

PIXX           = 320                             ;R‚solution horizontale

;== Donn‚es ============================================================

_DATA  segment word public 'DATA'

vio_seg    dw 0a000h           ;Segment m‚moire ‚cran avec page courante

_DATA  ends

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'                  ;Segment de programme

;-- D‚clarations publiques ---------------------------------------------

public    _init320200                        ;Initialise le mode 320*200
public    _setpix                                      ;Dessine un pixel
public    _getpix                       ;D‚termine la couleur d'un pixel
public    _showpage                              ;Affiche la page 0 ou 1
public    _setpage                   ;Fixe la page pour setpix ou getpix
public    _getfontptr               ;Retourne un pointeur sur le jeu 8*8

;-- INIT320200: initialise le mode graphique 320*200us -----------------
;-- D‚claration : void init320200( void );

_init320200 proc near

       ;-- On commence par d‚clencher le mode 13h pour que le BIOS -----
       ;-- effectue la plus grande partie de l'initialisation ----------
       ;-- Puis on modifie les registres qui n'ont pas encore le -------
       ;-- contenu souhait‚. -------------------------------------------

       mov   ax,0013h                               ;Appelle le mode 13h
       int   10h

       mov   dx,GC_INDEX                  ;D‚sactive par le bit num‚ro 4
       mov   al,GC_GRAPH_MODE        ;la s‚paration des adresses m‚moire
       out   dx,al                      ;dans le registre mode graphique
       inc   dx                                 ;du contr“leur graphique
       in    al,dx
       and   al,11101111b
       out   dx,al
       dec   dx

       mov   al,GC_MISCELL                 ;idem dans le registre divers
       out   dx,al                                  ;par le bit num‚ro 1
       inc   dx                                                        ;
       in    al,dx
       and   al,11111101b
       out   dx,al

       mov   dx,SC_INDEX            ;Modifie le registre de mode m‚moire
       mov   al,SC_MEM_MODE                   ;du contr“leur de s‚quence
       out   dx,al               ;de fa‡on … mettre fin … la r‚partition
       inc   dx                ;des adresses m‚moire sur plusieurs plans
       in    al,dx                   ;de bits et … fixer le plan courant
       and   al,11110111b           ;par le registre de masquage binaire
       or    al,4                                                      ;
       out   dx,al

       mov   ax,vio_seg                ;Remplit les quatre plans de bits
       mov   es,ax                   ;avec le code couleur 00h et efface
       xor   di,di                                              ;l'‚cran
       mov   ax,di
       mov   cx,8000h
       rep   stosw

       mov   dx,CRTC_INDEX                  ;Met fin au mode double -mot
       mov   al,CC_UNDERLINE         ; par le moyen du bit 6 du registre
       out   dx,al               ; de soulignement du contr“leur d'‚cran
       inc   dx
       in    al,dx
       and   al,10111111b
       out   dx,al
       dec   dx

       mov   al,CC_MODE_CTRL        ;Passe du mode mot au mode octet par
       out   dx,al            ;le moyen du bit 6 du registre de contr“le
       inc   dx                           ;de mode du contr“leur d'‚cran
       in    al,dx
       or    al,01000000b
       out   dx,al

       ret                                        ;retourne … l'appelant

_init320200 endp                                    ;Fin de la proc‚dure

;-- SETPIX: Dessine un pixel dans une couleur donn‚e  ------------------
;-- D‚claration : void setpix( int x, int y, unsigned char couleur );

_setpix    proc near

sframe     struc                            ;Structure d'accŠs … la pile
bp0         dw ?                                            ;M‚morise BP
ret_adr0    dw ?                         ;Adresse de retour … l'appelant
x0          dw ?                                             ;Abscisse X
y0          dw ?                                             ;Ordonn‚e Y
couleur     dw ?                                                ;Couleur
sframe     ends                                     ;Fin de la structure

frame  equ [ bp - bp0 ]            ;adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       push  di                               ;Sauvegarde DI sur la pile

       mov   ax,PIXX / 4       ;Calcule l'offset dans la m‚moire d'‚cran
       mul   frame.y0                                ;et le charge en DI
       mov   cx,frame.x0
       mov   bx,cx
       shr   bx,1
       shr   bx,1
       add   ax,bx
       mov   di,ax

       and   cl,3                  ;Calcule en AH le masque binaire pour
       mov   ah,1                                     ; adresser le plan
       shl   ah,cl
       mov   al,SC_MAP_MASK                    ;Num‚ro du registre en AL
       mov   dx,SC_INDEX         ;Charge l'adresse d'index du s‚quenceur
       out   dx,ax               ;Charge le registre de masquage binaire

       mov   ax,vio_seg                ;ES pointe sur la m‚moire d'‚cran
       mov   es,ax
       mov   al,byte ptr frame.couleur       ;Charge la couleur du pixel
       stosb                          ; et la place dans le plan de bits

       pop   di                         ;Reprend le registre sur la pile
       pop   bp

       ret                                        ;Retourne … l'appelant

_setpix    endp                                     ;Fin de la proc‚dure

;-- GETPIX: D‚termine la couleur d'un pixel   --------------------------
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
       mov   bp,sp                                   ;par le registre BP

       push  si                               ;Sauvegarde SI sur la pile

       mov   ax,PIXX / 4            ;calcule l'offset en m‚moire d'‚cran
       mul   frame.y1                               ; et le charge en SI
       mov   si,frame.x1
       mov   cx,si
       shr   si,1
       shr   si,1
       add   si,ax

       and   cl,3                  ;calcule en AH le masque binaire pour
       mov   ah,cl                                     ;adresser le plan
       mov   al,GC_READ_MAP                    ;Num‚ro du registre en AL
       mov   dx,GC_INDEX      ;Charge adresse index contr“leur graphique
       out   dx,ax                          ;Charge le registre Read Map

       mov   ax,vio_seg                ;ES pointe sur la m‚moire d'‚cran
       mov   es,ax
       mov   al,es:[si]                      ;Charge la couleur du pixel

       pop   si                         ;reprend le registre sur la pile
       pop   bp

       ret                                        ;retourne … l'appelant

_getpix    endp                                     ;Fin de la proc‚dure

;-- SETPAGE: S‚lectionne la page concern‚e par les appels aux       ----
;--          fonctions setpix et getpix
;-- D‚claration : void setpage( unsigend char page );

_setpage   proc near

       pop   bx                              ;D‚pile l'adresse de retour
       pop   cx                                          ; et l'argument

       push  cx                             ; puis les remet sur la pile
       push  bx

       mov   al,4                ;Octet fort du segment = page * 4 + A0h
       mul   cl
       or    al,0A0h

       mov   byte ptr vio_seg + 1,al  ;M‚morise nouvelle adresse segment

       ret                                        ;retourne … l'appelant

_setpage   endp                                     ;Fin de la proc‚dure

;-- SHOWPAGE: Affiche l'une des deux pages d'‚cran------
;-- D‚claration : void showpage( unsigend char page );

_showpage  proc near

       pop   bx                              ;D‚pile l'adresse de retour
       pop   cx                                          ; et l'argument

       push  cx                              ;puis les remet sur la pile
       push  bx

       mov   al,64                   ;Octet fort de l'offset = page * 64
       mul   cl
       mov   ah,al                         ;Octet fort de l'offset en AH

       ;-- Charge la nouvelle adresse de d‚but--------------------------

       mov   dx,CRTC_INDEX                ;Adresse du contr“leur d'‚cran
       mov   al,CC_START_HI                    ;Num‚ro du registre en AL
       out   dx,ax                                   ;Effectue la sortie

       ;-- Attend un d‚but de rafraŒchissement d'‚cran -----------------
       mov   dx,VERT_RETRACE                  ;Attend la fin du balayage
sp3:   in    al,dx                                             ;vertical
       test  al,8
       jne   sp3

sp4:   in    al,dx                  ;puis le d‚but du retour du faisceau
       test  al,8
       je    sp4

       ret                                        ;Retourne … l'appelant

_showpage  endp                                     ;Fin de la proc‚dure

;-- GETFONTPTR: Renvoie un pointeur FAR sur le jeu de caractŠres 8*8
;-- D‚claration : void far * getfontptr( void )

_getfontptr proc near

       push  bp                                           ;Sauvegarde BP

       mov   ax,1130h                              ;Charge les registres
       mov   bh,3
       int   10h                   ; puis d‚clenche l'interruption vid‚o

       mov   dx,es                             ;TransfŠre ES:BP en DX:AX
       mov   ax,bp

       pop   bp                                  ;reprend BP sur la pile
       ret                                        ;Retourne … l'appelant

_getfontptr endp                                    ;Fin de la proc‚dure

;== Fin ================================================================

_text    ends                               ;Fin du segment de programme
         end                             ;Fin de la source en assembleur
