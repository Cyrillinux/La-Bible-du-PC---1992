;**********************************************************************;
;*                         S 3 2 2 0 P A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction : contient les routines pour travailler avec les       *;
;*               sprites dans les mode 320*200-256 de la carte VGA    *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    DÇveloppÇ le   : 08.09.1990                                     *;
;*    Derniäre MAJ   : 14.01.1991                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM /mx S3220PA;    ou     TASM -mx S3220PA   *;
;*                     puis lier Ö   S3220P.PAS                       *;
;**********************************************************************;


;== Constantes =========================================================

SC_INDEX       = 3c4h   ;Registre d'index du contrpoleur du sÇquenceur .
SC_MAP_MASK    = 2                          ;NumÇro du registre Map Mask
SC_MEM_MODE    = 4                   ;NumÇro du registre de mode mÇmoire

GC_INDEX       = 3ceh        ;Registre d'index du contrìleur graphique .
GC_GRAPH_MODE  = 5                 ;NumÇro de registre de mode graphique

VERT_RETRACE   = 3DAh                       ;Registre d'Çtat d'entrÇe #1
PIXX           = 320                             ;RÇsolution horizontale

;== Segment de donnÇes =================================================

DATA   segment word public

DATA   ends

;== Programme ==========================================================

CODE       segment byte public                     ;Segment de programme

       assume cs:code, ds:data

;-- DÇclarations publiques ---------------------------------------------

public     blockmove

;-----------------------------------------------------------------------
;-- BLOCKMOVE: DÇplace un groupe de pixels dans la mÇmoire d'Çcran
;-- Appel depuis TP: blockmove( depage : byte; dex, dey : integer;
;--                           verspage : byte; versx, versy : integer;
;--                           largeur, hauteur: byte; bmskp : pointer );

blockmove  proc near

sframe4    struc                            ;Structure d'accäs Ö la pile
bp4        dw ?                                             ;MÇmorise BP
additif    dw ?                                         ;variable locale
restz      dw ?
movec      dw ?
ret_adr4   dw ?                          ;Adresse de retour Ö l'appelant
bmskp      dd ?             ;Pointe sur le buffer avec le masque binaire
hauteur    dw ?                                                 ;Hauteur
largeur    dw ?                                                 ;Largeur
versy      dw ?                                 ;OrdonnÇe de destination
versx      dw ?                                 ;Abscisse de destination
verspage   dw ?                                     ;Page de destination
dey        dw ?                                      ;OrdonnÇe d'origine
dex        dw ?                                      ;Abscisse d'origine
depage     dw ?                                          ;Page d'origine
sframe4    ends                                     ;Fin de la structure

frame  equ [ bp - bp4 ]            ;adresse les ÇlÇments de la structure

       sub   sp,6                   ;6 octets pour les variables locales

       push  bp                      ;PrÇpare l'adressage des paramätres
       mov   bp,sp                                  ; par le registre BP

       push  ds
       cld                      ;Fixe le sens des traitements de chaånes

       mov   dx,GC_INDEX                   ;Lit le mode Write courant et
       mov   al,GC_GRAPH_MODE                     ; fixe le mode Write 1
       out   dx,al
       inc   dx
       in    al,dx
       push  ax                                  ;Empile le mode courant
       and   al,not 3
       or    al,1
       out   dx,al

       mov   al,4       ;DS va pointer sur le dÇbut de la page d'origine
       mov   cl,byte ptr frame.depage
       mul   cl
       or    al,0A0h
       xchg  ah,al
       mov   ds,ax

       mov   al,4  ;ES va pointer sur le dÇbut de la page de destination
       mov   cl,byte ptr frame.verspage
       mul   cl
       or    al,0A0h
       xchg  ah,al
       mov   es,ax

       mov   ax,PIXX / 4        ;SI va pointer sur la position d'origine
       mul   frame.dey
       mov   si,frame.dex
       shr   si,1
       shr   si,1
       add   si,ax

       mov   ax,PIXX / 4   ;DI va pointer sur la position de destination
       mul   frame.versy
       mov   di,frame.versx
       shr   di,1
       shr   di,1
       add   di,ax

       mov   dh,byte ptr frame.hauteur                      ;DH = Lignes
       mov   dl,byte ptr frame.largeur                      ;DL = octets
       shr   dl,1
       shr   dl,1

       mov   bx,PIXX / 4                     ;BX = offset ligne suivante
       sub   bl,dl
       xor   ch,ch                  ;Octet haut du compteur toujours nul
       cmp   word ptr frame.bmskp+2,0         ;Pas de fond Ö respecter ?
       jne   mt2                          ;Si, utilise une autre routine

       push  dx                                    ;Sauve DX sur la pile
       mov   dx,SC_INDEX        ;Assure l'accäs Ö tous les plans de bits
       mov   ah,0Fh
       mov   al,SC_MAP_MASK
       out   dx,ax
       pop   dx                                              ;Reprend DX

                ;-- Routine de copie pour tous les quatre plans de bits,
                                            ;--  ne respecte pas le fond

mt1:   mov   cl,dl                                ;Nombre d'octets en CL

       rep movsb                                        ;Copie une ligne
       add   di,bx                                ;DI sur ligne suivante
       add   si,bx                                        ; ainsi que SI
       dec   dh                                       ;Reste une ligne ?
       jne   mt1                                    ;Oui---> on continue
       jmp short mtend                           ;Non, prÇpare la sortie

                ;-- Routine de copie pour plans de bits individuels avec
                ;-- exploitation du tableau de masques binaires transmis

mt2:   mov   byte ptr frame.restz,dh ;MÇmorise d'abord les variables qui
       mov   byte ptr frame.movec,dl         ;sont stockÇes dans la pile
       mov   frame.additif,bx           ;sous forme de variables locales

       mov   al,SC_MAP_MASK      ;Adresse le registre MAP MASK permanent
       mov   dx,SC_INDEX
       out   dx,al
       inc   dx                    ;DX pointe sur le registre de donnÇes

       push  ds
       lds   bx,frame.bmskp  ;BX pointe sur le tableau de masque binaire
       mov   al,[bx]                            ;Charge le premier octet
       xor   ah,ah                          ;Commence avec un octet pair
       pop   ds

mt3:   mov   cl,byte ptr frame.movec              ;Nombre d'octets en CL

mt4:   out   dx,al                               ;Fixe le masque binaire
       movsb                                             ;Copie 4 octets

       inc   ah                      ;IncrÇmente le compteur pair/impair
       test  ah,1                                      ;Valeur impaire ?
       jne   mt5                                ;Oui, dÇplace le quartet

               ;-- Octet pair, passe Ö l'octet suivant du buffer -------

       inc   bx              ;BX sur le prochain octet de masque binaire
       push  ds
       mov   ds,word ptr frame.bmskp+2
       mov   al,[bx]                             ;Charge l'octet suivant
       pop   ds
       loop  mt4                      ;Passe aux quatre latches suivants
       jmp   short mt6

mt5:   shr   al,1                      ;Transfäre dans le quartet faible
       shr   al,1                   ;le masque binaire de l'octet impair
       shr   al,1
       shr   al,1
       loop  mt4                     ;Passe aux quatres latches suivants

mt6:   add   di,frame.additif                     ;DI sur ligne suivante
       add   si,frame.additif                              ;ainsi que SI
       dec   byte ptr frame.restz                     ;Reste une ligne ?
       jne   mt3                                   ;Oui ---> on continue

mtend: mov   dx,GC_INDEX                   ;RÇtablit l'ancien mode Write
       pop   ax
       mov   ah,al
       mov   al,GC_GRAPH_MODE
       out   dx,ax

       pop   ds
       pop   bp

       add   sp,6              ;SP passe par desus les variables locales
       ret   20             ;Au retour efface les paramätres sur la pile
                                                                       ;
blockmove  endp

;== Fin ===============================================================

CODE   ends                                      ;Fin du segment de code
       end                                             ;Fin du programme

