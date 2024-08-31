;**********************************************************************;
;*                         V 3 2 4 0 P A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction : contient diverses routines pour travailler dans le   *;
;*               mode graphique 320*400 de la carte VGA               *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   : 05.09.1990                                     *;
;*    DerniŠre MAJ   : 14.01.1991                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM /mx V3240PA;    ou     TASM -mx V3240PA   *;
;*                     ...puis inclure daans V3240P.PAS               *;
;**********************************************************************;

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

DAC_WRITE_ADR  = 3C8h                                 ;Adresse DAC Write
DAC_READ_ADR   = 3C7h                                  ;Adresse DAC Read
DAC_DATA       = 3C9h                          ;Registres de donn‚es DAC

VERT_RETRACE   = 3DAh                       ;Registre d'‚tat d'entr‚e #1

PIXX           = 320                             ;R‚solution horizontale

;== Segment de donn‚es =================================================

DATA   segment word public

vio_seg    dw (?)                      ;Segment de la m‚moire d'‚cran, …
                                              ;initialiser … l'ex‚cution

DATA   ends

;== Programme ==========================================================

CODE   segment byte public                         ;Segment de programme

       assume cs:code, ds:data

;-- D‚clarations publiques ---------------------------------------------

public    init320400                         ;Initialise le mode 320*400
public    setpix                                       ;Dessine un pixel
public    getpix                        ;D‚termine la couleur d'un pixel
public    showpage                               ;Affiche la page 0 ou 1
public    setpage                    ;Fixe la page pour setpix et getpix

;-----------------------------------------------------------------------
;-- INIT320400: initialise le mode graphique 320*400
;-- Appel depuis TP: init320400;

init320400 proc near

                 ;-- Commence par installer le mode 13h pour que le BIOS
                  ;-- effectue la plus grande partie de l'initialisation
                  ;-- Puis modifie les registres qui n'ont pas encore le
                                                    ;-- contenu souhait‚

       mov   ax,0013h                               ;Appelle le mode 13h
       int   10h

       mov   dx,GC_INDEX           ;D‚sactive la s‚paration des adresses
       mov   al,GC_GRAPH_MODE;m‚moire dans le registre de mode graphique
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
       mov   es,ax                                              ;l'‚cran
       xor   di,di
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
       dec   dx ;DX repointe sur le registre d'index du contr“leur ‚cran

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

       ret                                        ;Retourne … l'appelant

init320400 endp                                     ;Fin de la proc‚dure

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

frame      equ [ bp - bp0 ]        ;Adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                   ;par le registre BP

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

       pop   bp                                   ;D‚pile le registre BP

       ret   6                    ;retourne … l'appelant en retirant les
                                                   ;arguments de la pile

setpix     endp                                     ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- GETPIX: d‚termine la couleur d'un pixel
;-- Appel depuis TP: x := getpix( x , y : integer );

getpix     proc near

sframe1    struc                            ;Structure d'accŠs … la pile
bp1        dw ?                                             ;M‚morise BP
ret_adr1   dw ?                          ;Adresse de retour … l'appelant
y1         dw ?                                             ;Ordonn‚es Y
x1         dw ?                                              ;Abscisse X
sframe1    ends                                     ;Fin de la structure

frame  equ [ bp - bp1 ]            ;adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       mov   ax,PIXX / 4            ;Calcule l'offset en m‚moire d'‚cran
       mul   frame.y1                               ; et le charge en SI
       mov   si,frame.x1
       mov   cx,si
       shr   si,1
       shr   si,1
       add   si,ax

       and   cl,3                  ;Calcule en AH le masque binaire pour
       mov   ah,cl                                     ;adresser le plan
       mov   al,GC_READ_MAP                    ;Num‚ro du registre en AL
       mov   dx,GC_INDEX ;Charge adresse d'index du contr“leur graphique
       out   dx,ax                          ;Charge le registre Read Map

       mov   ax,vio_seg          ;ES doit pointer sur la m‚moire d'‚cran
       mov   es,ax
       mov   al,es:[si]                      ;Charge la couleur du pixel

       pop   bp                                  ;Reprend BP sur la pile

       ret   4                    ;Retourne … l'appelant en retirant les
                                                   ;arguments de la pile

getpix endp                                         ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- SETPAGE: S‚lectionne la page concern‚e par les appels aux fonctions
;--          setpix et getpix
;-- Appel depuis TP: setpage( page : byte );

setpage    proc near

       pop   ax                              ;D‚pile l'adresse de retour
       pop   cx                                          ; et l'argument

       push  ax                 ;ne remet que la seule adresse de retour

       mov   bl,0a0h                                                   ;
       or    cl,cl                                    ;Est-ce la page 0?
       je    sp1                               ;Oui, m‚morise le segment
       mov   bl,0a8h                                ;Non c'est la page 1

sp1:   mov   byte ptr vio_seg + 1,bl  ;M‚morise la nouvelle adr. de seg.

       ret  ;retourne … l'appelant, le paramŠtre a ‚t‚ retir‚ de la pile


setpage    endp                                     ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- SHOWPAGE: Affiche l'une des deux pages d'‚cran
;-- Appel depuis TP: showpage( page : byte );

showpage   proc near

       pop   bx                              ;D‚pile l'adresse de retour
       pop   ax                                   ; ainsi que l'argument

       push  bx                   ;Remet l'adresse de retour sur la pile

       or    al,al                                    ;Est-ce la page 0?
       je    sp2    ;Oui, son num‚ro est ‚gal … l'octet fort de l'offset

       mov   al,80h                      ;Non, page 1, avec offset 8000h

sp2:   mov   dx,CRTC_INDEX                ;Adresse le contr“leur d'‚cran
       mov   ah,al                ;Charge en AH l'octet fort de l'offset
       mov   al,CC_START_HI                    ;Num‚ro du registre en AL
       out   dx,ax                                   ;Effectue la sortie

                  ;-- Attend un d‚but de rafraŒchissement d'‚cran  -----

       mov   dx,VERT_RETRACE        ;Attend la fin du retour de balayage
sp3:   in    al,dx                                             ;vertical
       test  al,8
       jne   sp3

sp4:   in    al,dx                  ;puis le d‚but du retour du faisceau
       test  al,8
       je    sp4

       ret                     ;Retourne … l'appelant, l'argument a d‚j…
                                                  ;‚t‚ retir‚ de la pile

showpage   endp                                     ;Fin de la proc‚dure

;== Fin  ===============================================================

CODE   ends                                      ;Fin du segment de code
       end                                             ;Fin du programme

