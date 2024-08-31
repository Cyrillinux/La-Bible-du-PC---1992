;**********************************************************************;
;*                       V 8 0 6 0 P A . A S M                        *;
;*--------------------------------------------------------------------*;
;*    Fonction : contient diff‚rentes routines pour travailler dans   *;
;*               le mode graphique 800*600 de la carte Super-VGA      *;
;*               avec 16 couleurs                                     *;
;*--------------------------------------------------------------------*;
;*    Auteur       : MICHAEL TISCHER                                  *;
;*    D‚velopp‚ le : 14.01.1991                                       *;
;*    DerniŠre MAJ : 14.01.1991                                       *;
;*--------------------------------------------------------------------*;
;*    Assemblage   : MASM /mx V8060PA;     ou  TASM -mx V8060PA       *;
;*                   ... puis lier … V8060P.PAS                       *;
;**********************************************************************;

;== Constantes =========================================================

GC_INDEX       = 3ceh          ;Registre d'index du contr“leur graphique
GC_READ_MAP    = 4                          ;Num‚ro du registre Read-Map
GC_BIT_MASK    = 8               ;Num‚ro du registre de masquage binaire
GC_GRAPH_MODE  = 5                 ;Num‚ro du registre de mode graphique

;== Segment de donn‚es =================================================

DATA   segment word public       ;A initialiser au moment de l'ex‚cution
DATA   ends

;== Programme===========================================================

CODE   segment byte public                         ;Segment de programme

       assume cs:code, ds:data

;-- D‚clarations publiques ---------------------------------------------

public    init800600                        ;Initialise le mode 800 *600
public    setpix                                       ;Dessine un pixel
public    getpix                        ;D‚termine la couleur d'un pixel

;-- Donn‚es dans le segment de code -------------------------------

              ;-- Num‚ros de code donn‚s par diff‚rents cartes Super VGA
                                                    ;--  au mode 800*600

modenr     db 6Ah, 58h, 29h, 54h, 16h, 79h
modenrend  equ this byte

;-----------------------------------------------------------------------
;-- INIT800600 : initialise le mode 800*600 en 16 couleurs de la
;--              de la Super-VGA

;-- Appel depuis TP: function init800600 : boolean;
;-- Valeur de retour : TRUE = mode initialis‚ , FALSE = Erreur

init800600 proc near

                             ;-- Essaye tous les modes du tableau MODENR
                 ;--  jusqu'… ce que l'un d'exu soit accept‚ par le BIOS

       mov  si,offset modenr    ;Commence par le premier mode du tableau
it1:   xor  ah,ah                     ;Fonction 00h: Initialiser le mode
       mov  al,cs:[si]                        ;Charge le code du tableau
       int  10h                                      ;Initialise le mode
       mov  ah,0fh                           ;Fonction 0Fh: Lire le mode
       int  10h
       cmp  al,cs:[si]                           ;A-t-il ‚t‚ enclench‚ ?
       je   it2                                               ;Oui--> OK

              ;-- Mauvais code, lit le suivant dans le tableau----------

       inc  si                                      ;SI sur code suivant
       cmp  si,offset modenrend         ;A-t-on parcouru tt le tableau ?
       jne  it1                                      ;Non, on recommence

       mov  al,0                   ;Oui, cl“ture la fonction avec erreur
       ret                                        ;Retourne … l'appelant

it2:                                    ;-- Le mode a pu ˆtre initialis‚

       mov  al,1                                           ;Tout va bien
       ret                                        ;Retourne … l'appelant

init800600 endp                                     ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- SETPIX: Dessine un pixel dans une certaine couleur
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

              ;-- Calcule l'offset en m‚moire d'‚cran et le d‚calage ---

       mov   ax,frame.y0                            ;Charge l'ordonn‚e Y
       mov   dx,800 / 8            ;Multiplie par la largeur de la ligne
       mul   dx
       mov   bx,frame.x0                            ;Charge l'abscisse X
       mov   cl,bl                      ;M‚morise l'octet faible pour le
                                                    ; calcul du d‚calage

       shr   bx,1                          ;Divise l'abscisse X par huit
       shr   bx,1
       shr   bx,1
       add   bx,ax          ;Y ajoute l'offset issu de la multiplication

       and   cl,7               ;Calcule le masque binaire … partir de X
       xor   cl,7
       mov   ah,1
       shl   ah,cl

       mov   dx,GC_INDEX                 ;AccŠde au contr“leur graphique
       mov   al,GC_BIT_MASK            ;Charge le masque binaire dans le
       out   dx,ax          ; registre de masquage et effectue la sortie

       mov   ax,(02h shl 8) + GC_GRAPH_MODE  ;Installe le mode Write 2 &
       out   dx,ax                                              ; Read 0

       mov   ax,0A000h                          ;Charge en ES le segment
       mov   es,ax                                ;de la m‚moire d'‚cran

       mov   al,es:[bx]                        ;Charge le registre latch
       mov   al,byte ptr frame.couleur         ;Fixe la couleur du pixel
       mov   es:[bx],al                  ;R‚‚crit dans le registre latch

       ;-- Remet les valeurs par d‚faut dans les registres du contr“leur
                                      ;-- graphique qui ont ‚t‚ modifi‚s

       mov   ax,(0FFh shl 8 ) + GC_BIT_MASK
       out   dx,ax

       mov   ax,(00h shl 8) + GC_GRAPH_MODE
       out   dx,ax

       pop   bp
       ret   6                        ;Retourne … l'appelant en retirant
                                              ; les arguments de la pile

setpix endp                                         ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- GETPIX: D‚termine la couleur d'un pixel
;-- Appel depuis TP: x := getpix( x , y : integer );

getpix     proc near

sframe1    struc                            ;Structure d'accŠs … la pile
bp1        dw ?                                             ;M‚morise BP
ret_adr1   dw ?                          ;Adresse de retour … l'appelant
y1         dw ?                                              ;Ordonn‚e Y
x1         dw ?                                              ;Abscisse X
sframe1    ends                                     ;Fin de la structure

frame  equ [ bp - bp1 ]            ;Adresse les ‚l‚ments de la structure

       push  bp                      ;Pr‚apre l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

                 ;-- Calcule l'offset en m‚moire d'‚cran et le d‚calage-

       mov   ax,frame.y1                            ;Charge l'ordonn‚e Y
       mov   dx,800 / 8            ;Multiplie par la largeur de la ligne
       mul   dx
       mov   si,frame.x1                            ;Charge l'abscisse X
       mov   cx,si                         ;La m‚morise pour le d‚calage

       shr   si,1                          ;Divise l'abscisse X par huit
       shr   si,1
       shr   si,1
       add   si,ax          ;Y ajoute l'offset issu de la multiplication

       and   cl,7               ;Calcule le masque binaire … partir de X
       xor   cl,7
       mov   ch,1
       shl   ch,cl

       mov   ax,0A000h                          ;Charge en ES le segment
       mov   es,ax                                ;de la m‚moire d'‚cran

       mov   dx,GC_INDEX                 ;AccŠde au contr“leur graphique
       mov   ax,(3 shl 8)+ GC_READ_MAP                      ;Lit d'abord
       xor   bl,bl                                            ;le plan 3

gp1:   out   dx,ax                       ;Indique le plan de bits … lire
       mov   bh,es:[si]              ;Charge la valeur du registre latch
       and   bh,ch                       ;Ne garde que le pixel souhait‚
       neg   bh                      ;Fixe le bit 7 en fonction du pixel
       rol   bx,1                        ;Effectue une rotation du bit 7
                                             ; de BH vers le bit 1 en BL

       dec   ah                          ;Traite le plan de bits suivant
       jge   gp1                      ;sup ou ‚gal … 0 ?---> on continue

       mov   al,bl                           ;Renvoie le r‚sultat par AL

       pop   bp
       ret   4                        ;Retourne … l'appelant en retirant
                                              ; les arguments de la pile

getpix endp                                         ;Fin de la proc‚dure

;== Fin  ===============================================================

CODE   ends                                      ;Fin du segment de code
       end                                             ;Fin du programme

