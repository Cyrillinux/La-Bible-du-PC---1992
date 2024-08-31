;**********************************************************************;
;*                         V 3 2 2 0 P A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction : contient diverses routines pour travailler dans le   *;
;*               mode graphique 320*200 256 couleurs de la carte VGA  *;
;*--------------------------------------------------------------------*;
;*    Auteur       : MICHAEL TISCHER                                  *;
;*    D‚velopp‚ le :  5.09.1990                                       *;
;*    DerniŠre MAJ : 14.01.1991                                       *;
;*--------------------------------------------------------------------*;
;*    Assemblage : MASM /mx V3220PA;    ou TASM -mx V3220PA           *;
;*                 ... puis inclure dans V3220P.PAS                   *;
;**********************************************************************;

;== Constantes =========================================================

SC_INDEX       = 3c4h    ;Registre d'index du contr“leur du s‚quenceur .
SC_MAP_MASK    = 2                          ;Num‚ro du registre Map-Mask
SC_MEM_MODE    = 4                   ;Num‚ro du registre de mode m‚moire

GC_INDEX       = 3ceh          ;registre d'index du contr“leur graphique
GC_READ_MAP    = 4                          ;Num‚ro du registre Read Map
GC_GRAPH_MODE  = 5                 ;Num‚ro du registre de mode graphique
GC_MISCELL     = 6                            ;Num‚ro du registre divers
GC_BIT_MASK    = 8               ;Num‚ro du registre de masquage binaire

CRTC_INDEX     = 3d4h            ;registre d'index du contr“leur d'‚cran
CC_MAX_SCAN    = 9     ;Num‚ro du registre du maximum de lignes balay‚es
CC_START_HI    = 0Ch                        ;Num‚ro du registre Hi_Start
CC_UNDERLINE   = 14h                 ;Num‚ro du registre de soulignement
CC_MODE_CTRL   = 17h             ;Nummer du registre de contr“le de mode

DAC_WRITE_ADR  = 3C8h                                 ;Adresse DAC Write
DAC_READ_ADR   = 3C7h                                  ;Adresse DAC Read
DAC_DATA       = 3C9h                          ;Registres de donn‚es DAC

VERT_RETRACE   = 3DAh                       ;Registre d'‚tat d'entr‚e #1

PIXX           = 320                             ;R‚solution horizontale

;== Segment de donn‚es =================================================

DATA   segment word public

vio_seg    dw (?)                  ;Segment m‚moire d'‚cran avec la page
                                  ;courante, … initialiser … l'ex‚cution

DATA   ends

;== Programme ==========================================================

CODE   segment byte public                         ;Segment de programme

       assume cs:code, ds:data

;-- D‚clarations publiques ---------------------------------------------

public    init320200                         ;Initialise le mode 320*200
public    setpix                                       ;Dessine un pixel
public    getpix                        ;D‚termine la couleur d'un pixel
public    showpage                               ;Affiche la page 0 ou 1
public    setpage                    ;Fixe la page pour setpix et getpix

;-----------------------------------------------------------------------
;-- INIT320200: initialise le mode graphique 320*200
;-- Appel depuis TP: init320200;

init320200 proc near

               ;-- On commence par demander le mode 13h pour que le BIOS
               ;-- effectue la plus grande partie de l'initialisation  .
                  ;-- Puis on modifie les registres qui n'ont pas encore
                                                 ;-- le contenu souhait‚

       mov   ax,0013h                     ;Appelle le mode ordinaire 13h
       int   10h

       mov   dx,GC_INDEX           ;D‚sactive la s‚paration des adresses
       mov   al,GC_GRAPH_MODE   ;m‚moire dans le registre mode graphique
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

       mov   ax,0A000h                 ;Remplit les quatre plans de bits
       mov   vio_seg,ax              ;avec le code couleur 00h et efface
       mov   es,ax                                        ;ainsi l'‚cran
       xor   di,di
       mov   ax,di
       mov   cx,8000h
       rep   stosw

       mov   dx,CRTC_INDEX       ;Arrˆte le mode double-mot par le bit 6
       mov   al,CC_UNDERLINE             ;du registre de soulignement du
       out   dx,al                                   ;contr“leur d'‚cran
       inc   dx
       in    al,dx
       and   al,10111111b
       out   dx,al
       dec   dx

       mov   al,CC_MODE_CTRL       ;Par le bit 6 du registre de contr“le
       out   dx,al                        ;de mode du contr“leur d'‚cran
       inc   dx                         ;passe du mode mot au mode octet
       in    al,dx
       or    al,01000000b
       out   dx,al

       ret                                        ;retourne … l'appelant

init320200 endp                                     ;Fin de la proc‚dure


;-----------------------------------------------------------------------
;-- SETPIX: Dessine un pixel dans une couleur donn‚e
;-- Appel depuis TP: setpix( x , y : integer; couleur : byte );

setpix     proc near

sframe     struc                            ;Structure d'accŠs … la pile
bp0        dw ?                                             ;M‚morise BP
ret_adr0   dw ?                          ;Adresse de retour … l'appelant
couleur    dw ?                                                 ;Couleur
y0         dw ?                                              ;Ordonn‚e Y
x0         dw ?                                              ;Abscisse X
sframe     ends                                     ;Fin de la structure

frame  equ [ bp - bp0 ]            ;Adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       mov   ax,PIXX / 4            ;Calcule l'offset en m‚moire d'‚cran
       mul   frame.y0                                  ; et en charge DI
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

       mov   ax,vio_seg                ;ES pointe sur la m‚moire d'‚cran
       mov   es,ax
       mov   al,byte ptr frame.couleur       ;Charge la couleur du pixel
       stosb                           ;et la place dans le plan de bits

       pop   bp                         ;Reprend le registre sur la pile

       ret   6                                    ;Retourne … l'appelant
                                  ;en retirant les paramŠtres de la pile

setpix endp                                         ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- GETPIX: D‚termine la couleur d'un pixel
;-- Appel depuis TP: x := getpix( x , y : integer );

getpix proc near

sframe1    struc                            ;Structure d'accŠs … la pile
bp1        dw ?                                             ;M‚morise BP
ret_adr1   dw ?                          ;Adresse de retour … l'appelant
y1         dw ?                                              ;Ordonn‚e Y
x1         dw ?                                              ;Abscisse X
sframe1    ends                                     ;Fin de la structure

frame  equ [ bp - bp1 ]            ;Adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       mov   ax,PIXX / 4            ;Calcule l'offset en m‚moire d'‚cran
       mul   frame.y1                            ; et le transfŠre en SI
       mov   si,frame.x1
       mov   cx,si
       shr   si,1
       shr   si,1
       add   si,ax

       and   cl,3                  ;Calcule en AH le masque binaire pour
       mov   ah,cl                                    ; adresser le plan
       mov   al,GC_READ_MAP                    ;Num‚ro du registre en AL
       mov   dx,GC_INDEX ;Charge adresse d'index du contr“leur graphique
       out   dx,ax                          ;Charge le registre Read-Map

       mov   ax,vio_seg                ;ES pointe sur la m‚moire d'‚cran
       mov   es,ax
       mov   al,es:[si]                      ;Charge la couleur du pixel

       pop   bp                         ;Reprend le registre sur la pile

       ret   4                        ;Retourne … l'appelant en retirant
                                               ;les arguments de la pile

getpix endp                                         ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- SETPAGE: S‚lectionne la page concern‚e par les appels
;   aux fonctions setpix et getpix
;-- Appel depuis TP: setpage( page : byte );

setpage    proc near

       pop   bx                              ;D‚pile l'adresse de retour
       pop   cx                                          ; et l'argument

       push  cx                             ; puis les remet sur la pile
       push  bx

       mov   al,4                  ;Octet fort du segmt = page * 4 + A0h
       mul   cl
       or    al,0A0h

       mov   byte ptr vio_seg + 1,al;M‚morise la nouvelle adr de segment

       ret   2                                    ;Retourne … l'appelant
                                      ;en enlevant l'argument de la pile

setpage    endp                                     ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- SHOWPAGE: Affiche l'une des deux pages d'‚cran
;-- Appel depuis TP: showpage( page : byte );

showpage   proc near

       pop   bx                              ;D‚pile l'adresse de retour
       pop   cx                                          ; et l'argument

       push  cx                             ; puis les remet sur la pile
       push  bx

       mov   al,64                    ;Octet fort de l'offset= page * 64
       mul   cl
       mov   ah,al                         ;Octet fort de l'offset en AH

         ;-- Charge la nouvelle adresse de d‚but -----------------------

       mov   dx,CRTC_INDEX                ;Adresse du contr“leur d'‚cran
       mov   al,CC_START_HI          ;Charge en AL le num‚ro du registre
       out   dx,ax                                  ; effectue la sortie

                    ;-- Attend un d‚but de rafraŒchissement d'‚cran-----

       mov   dx,VERT_RETRACE                  ;Attend la fin du balayage
sp3:   in    al,dx                                             ;vertical
       test  al,8
       jne   sp3

sp4:   in    al,dx                  ;puis le d‚but du retour du faisceau
       test  al,8
       je    sp4

       ret   2                        ;Retourne … l'appelant en retirant
; l'argument de la pile


showpage   endp                                     ;Fin de la proc‚dure

;== Fin ===============================================================

CODE   ends                                      ;Fin du segment de code
       end                                             ;Fin du programme

