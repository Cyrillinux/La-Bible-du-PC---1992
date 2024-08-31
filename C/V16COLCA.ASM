;**********************************************************************;
;*                       V 1 6 C O L C A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction       : contient diverses routines pour travailler     *;
;*                     dans les modes graphiques … 16 couleurs        *;
;*                     des cartes EGA et VGA                          *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   :  5.12.1990                                     *;
;*    DerniŠre MAJ   : 14.02.1992                                     *;
;*--------------------------------------------------------------------*;
;*    ModŠle m‚moire : SMALL                                          *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM /mx V16COLCA    ou     TASM -mx V16COLCA  *;
;**********************************************************************;

IGROUP group _text                  ; Regroupe les segments de programme
DGROUP group _bss, _data

       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS'     ; Segment pour toutes les variables
_BSS   ends                                 ; statiques non initialis‚es

_DATA  segment word public 'DATA'    ; Segment pour toutes les variables
                                    ; statiques et globales initialis‚es

_DATA  ends

;== Constantes =========================================================

SC_INDEX       = 3c4h    ; Registre d'index du contr“leur du s‚quenceur.
SC_MAP_MASK    = 2                         ; Num‚ro du registre Map-Mask
SC_MEM_MODE    = 4                  ; Num‚ro du registre de mode m‚moire

GC_INDEX       = 3ceh         ; registre d'index du contr“leur graphique
GC_FN_SELECT   = 3         ; Num‚ro du registre de s‚lection de fonction
GC_READ_MAP    = 4                         ; Num‚ro du registre Read Map
GC_GRAPH_MODE  = 5                ; Num‚ro du registre de mode graphique
GC_MISCELL     = 6                           ; Num‚ro du registre divers
GC_BIT_MASK    = 8              ; Num‚ro du registre de masquage binaire

CRTC_INDEX     = 3d4h           ; registre d'index du contr“leur d'‚cran
CC_MAX_SCAN    = 9               ; Num‚ro du registre de lignes balay‚es
CC_START_HI    = 0Ch                       ; Num‚ro du registre Hi_Start
CC_UNDERLINE   = 14h                ; Num‚ro du registre de soulignement
CC_MODE_CTRL   = 17h            ; Nummer du registre de contr“le de mode

DAC_WRITE_ADR  = 3C8h                                ; Adresse DAC Write
DAC_READ_ADR   = 3C7h                                 ; Adresse DAC-Read
DAC_DATA       = 3C9h                         ; Registres de donn‚es DAC

VERT_RETRACE   = 3DAh                   ; Registre d'‚tat des entr‚es #1

PIXX           = 640                            ; R‚solution horizontale

; == Donn‚es ===========================================================

_DATA  segment word public 'DATA'

vio_seg    dw 0A000h                       ; Segment vid‚o page courante
largeurl   dw 0                ; Largeur d'une ligne de pixels en octets
pageofs    dw 0                      ; Offset de la page dans le segment

_DATA  ends

; == Programme =========================================================

_TEXT  segment byte public 'CODE'                 ; Segment de programme

;-- D‚clarations publiques ---------------------------------------------

public    _init640350                ; initialise le mode 640*350 pixels
public    _init640480                ; initialise le mode 640*480 pixels
public    _init640200                ; initialise le mode 640*200 pixels
public    _init320200                ; initialise le mode 320*200 pixels
public    _setpix                                     ; Dessine un pixel
public    _getpix                            ; Lit la couleur d'un pixel
public    _showpage                             ; Affiche la page 0 ou 1
public    _setpage                  ; Fixe la page pour setpix et getpix
public    _getfontptr              ; retourne un pointeur sur le jeu 8*8

;-----------------------------------------------------------------------
;-- INIT640350  : Mode graphique EGA en 16 couleurs de 640*350 pixels
;-- D‚claration : void init640350( void );

_init640350 proc near

       mov   al,10h                                   ; Fixe le mode 10h
       mov   cx,28000/16                             ; Offset de la page

init16:
       mov   bx,640/8                              ; Largeur de la ligne

init:  mov   largeurl,bx                           ; M‚morise la largeur
       mov   pageofs,cx              ; M‚morise l'offset de la page pour
                                                  ; l'adresse de segment

       xor   ah,ah                  ; Appelle la fonction 00h pour fixer
       int   10h                                               ; le mode

       ret                                                ; Rend la main

_init640350 endp                                   ; Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- INIT640480: Initialise le mode graphique VGA 640*480 en 16 couleurs
;-- D‚claration : void init640480( void );

_init640480 proc near

       mov   al,12h                              ; Installe le mode 12hn

       ;-- L'offset de la page n'est pas int‚ressant car une seule page-
       ;-- est repr‚sentable -------------------------------------------
       jmp   init16

_init640480 endp                                   ; Fin de la proc‚dure

;-- INIT640200: initialise le mode graphique EGA 640*200 en 16 couleurs
;-- D‚claration: void init640200 (void);

_init640200 proc near

       mov   al,0Eh                               ; Installe le mode 0Eh
       mov   bx,640/8                               ; Largeur des lignes
       mov   cx,(64000/4)/16                         ; Offset de la page
       jmp   init16

_init640200 endp                                   ; Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- INIT320200: initialise le mode graphique EGA 320*200 en 16 couleurs
;-- D‚claration : void init320200( void );

_init320200 proc near

       mov   al,0Dh                               ; Installe le mode 0Dh
       mov   bx,320/8                               ; Largeur des lignes
       mov   cx,(32000/4)/16                         ; Offset de la page
       jmp   init

_init320200 endp                                   ; Fin de la proc‚dure

;-- SETPIX: Dessine un pixel dans une couleur donn‚e  ------------------
;-- D‚claration : void setpix( int x, int y, unsigned char farbe );

_setpix    proc near

sframe    struc                            ; Structure d'accŠs … la pile
bp0        dw ?                                            ; M‚morise BP
ret_adr0   dw ?                         ; Adresse de retour … l'appelant
x0         dw ?                                             ; Abscisse X
y0         dw ?                                             ; Ordonn‚e Y
couleur    dw ?                                                ; Couleur
sframe    ends                                     ; Fin de la structure

frame  equ [ bp - bp0 ]           ; Adresse les ‚l‚ments de la structure

       push  bp                     ; Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                              ; par BP

       ;--Cacule d'abord l'offset en m‚moire d'‚cran et le d‚calage ----

       mov   ax,frame.y0                           ; Charge l'ordonn‚e Y
       mov   dx,largeurl             ; Multiplie par la largeur de ligne
       mul   dx
       mov   bx,frame.x0                           ; Charge l'abscisse X
       mov   cl,bl                       ; Octet faible pour le d‚calage

       shr   bx,1                            ; Divise l'abscisse X par 8
       shr   bx,1
       shr   bx,1
       add   bx,ax                      ; + offset de la multiplication.

       and   cl,7                 ; Calcule masque binaire … partir de X
       xor   cl,7
       mov   ah,1
       shl   ah,cl

       mov   dx,GC_INDEX                ; AccŠde au contr“leur graphique
       mov   al,GC_BIT_MASK       ; Charge masque bin dans reg de masque
       out   dx,ax

       mov   ax,(02h shl 8)+GC_GRAPH_MODE
                                   ; D‚clenche le mode Write 2 & le mode
       out   dx,ax                                              ; Read 0

       mov   ax,vio_seg               ; ES=segment de la m‚moire d'‚cran
       mov   es,ax                                        ; avec la page
       mov   al,es:[bx]                       ; Charge le registre latch
       mov   al,byte ptr frame.couleur
                                              ; Fixe la couleur du point
       mov   es:[bx],al                 ; R‚‚crit dans le registre latch

       ;-- R‚tablit les valeurs par d‚faut dans les registres du -------
       ;-- contr“leur graphique qui ont ‚t‚ modifi‚s -------------------

       mov   ax,(0FFh shl 8 ) + GC_BIT_MASK
       out   dx,ax

       mov   ax,(00h shl 8) + GC_GRAPH_MODE
       out   dx,ax

       pop   bp
       ret                                ; Retour au programme appelant

_setpix    endp                                    ; Fin de la proc‚dure

;-- GETPIX: D‚termine la couleur d'un pixel   --------------------------
;-- D‚claration : unsigned char getpix( int x, int y );

_getpix    proc near

sframe1   struc                            ; Structure d'accŠs … la pile
bp1        dw ?                                            ; M‚morise BP
ret_adr1   dw ?                         ; Adresse de retour … l'appelant
x1         dw ?                                             ; Abscisse X
y1         dw ?                                             ; Ordonn‚e Y
sframe1   ends                                     ; Fin de la structure

frame  equ [ bp - bp1 ]           ; adresse les ‚l‚ments de la structure

       push  bp                     ; Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                              ; par BP

       push  si

       ;--Calcule d'abord l'offset en m‚moire d'‚cran et le d‚calage ---

       mov   ax,frame.y1                           ; Charge l'ordonn‚e Y
       mov   dx,largeurl             ; Multiplie par la largeur de ligne
       mul   dx
       mov   si,frame.x1                           ; Charge l'abscisse X
       mov   cx,si                              ; et pr‚pare le d‚calage

       shr   si,1                                    ; Divise X par huit
       shr   si,1
       shr   si,1
       add   si,ax          ; +offset en provenance de la multiplication

       and   cl,7              ; Calcule le masque binaire … partir de X
       xor   cl,7
       mov   ch,1
       shl   ch,cl

       mov   ax,vio_seg          ; Charge en ES le segment de la m‚moire
       mov   es,ax                                ; d'‚cran avec la page

       mov   dx,GC_INDEX                ; AccŠde au contr“leur graphique
       mov   ax,(3 shl 8)+ GC_READ_MAP
                                                ; Lit d'abord le plan #3
       xor   bl,bl

gp1:   out   dx,ax                              ; Indique le plan … lire
       mov   bh,es:[si]               ; Lit le contenu du registre latch
       and   bh,ch                   ; Ne conserve que le pixel concern‚
       neg   bh                                 ; Fixe le bit 7 du pixel
       rol   bx,1                 ; Effectue une rotation du bit 7 de BH
                                                   ; dans le bit 1 de BL

       dec   ah                  ; Pr‚pare le traitement du plan suivant
       jge   gp1                    ; sup ou ‚gal … 0 ? ---> on continue

       mov   al,bl                       ; R‚sultat de la fonction en AL

       pop   si
       pop   bp
       ret                                       ; Retourne … l'appelant

_getpix    endp                                    ; Fin de la proc‚dure

;-- SETPAGE: S‚lectionne la page concern‚e par les appels aux fonctions-
;--          setpix et  getpix
;-- D‚claration : void setpage( int page );

_setpage   proc near

       pop   cx                             ; D‚pile l'adresse de retour
       pop   ax                                          ; et l'argument

       push  ax                            ; puis remet tout sur la pile
       push  cx
       mul   pageofs                   ; Multiplie le num‚ro de page par
                                                   ; l'offset de la page

       add   ax,0A000h                       ; Ajoute le segment de base
       mov   vio_seg,ax        ; M‚morise la nouvelle adresse de segment

       ret                      ; Retourne … l'appelant l'argument ayant
                                            ; d‚j… ‚t‚ retir‚ de la pile

_setpage   endp                                    ; Fin de la proc‚dure

;-- SHOWPAGE: Affiche l'une des pages d'‚cran disponibles------
;-- D‚claration : void showpage( int page );

_showpage  proc near

       pop   cx                             ; D‚pile l'adresse de retour
       pop   ax                                   ; ainsi que l'argument

       push  ax                                 ; Remet tout sur la pile
       push  cx

       mul   pageofs                ; Multiplie le num‚ro de la page par
                                                   ; l'offset de la page
       mov   cl,4                                    ; et le tout par 16
       shl   ax,cl

       mov   bl,al                             ; M‚morise l'octet faible

       mov   dx,CRTC_INDEX               ; Adresse le contr“leur d'‚cran
       mov   al,CC_START_HI                  ; Emet d'abord l'octet fort
       out   dx,ax
       inc   al                                    ; puis l'octet faible
       mov   ah,bl
       out   dx,ax

       ;--Attend le d‚but d'un rafraŒchissement d'‚cran ----------------

       mov   dx,VERT_RETRACE         ; Attend d'abord la fin du balayage
sp3:   in    al,dx                                            ; vertical
       test  al,8
       jne   sp3

sp4:   in    al,dx                 ; puis le d‚but du retour du faisceau
       test  al,8
       je    sp4

       ret                                       ; Retourne … l'appelant

_showpage  endp                                    ; Fin de la proc‚dure

;-- GETFONTPTR: Retourne un pointeur FAR sur le jeu 8*8 ----------------
;-- D‚claration : void far * getfontptr( void ) ------------------------

_getfontptr proc near

      push  bp                                           ; Sauvegarde BP

      mov   ax,1130h          ; Charge les registres pour l'interruption
      mov   bh,3
      int   10h                         ; D‚clenche l'interruption vid‚o

      mov   dx,es                             ; TransfŠre ES:BP en DX:AX
      mov   ax,bp

      pop   bp                                  ; Reprend BP sur la pile
      ret                                        ; Retourne … l'appelant

_getfontptr endp                                   ; Fin de la proc‚dure

; == Fin ===============================================================
_text    ends                              ; Fin du segment de programme
         end                            ; Fin de la source en assembleur
