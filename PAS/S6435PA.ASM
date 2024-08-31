;**********************************************************************;
;*                         S 6 4 3 5 P A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction : contient des routines pour travailler avec des       *;
;*               sprites dans le mode  640*350 des cartes EGA et VGA  *;
;*--------------------------------------------------------------------*;
;*    Auteur       : MICHAEL TISCHER                                  *;
;*    D‚velopp‚ le :  8.12.1990                                       *;
;*    DerniŠre MAJ : 14.01.1991                                       *;
;*--------------------------------------------------------------------*;
;*    Assemblage : MASM /mx S6435PA;    ou   TASM -mx S6435PA         *;
;*                 ... puis lier … S6435P.PAS                         *;
;**********************************************************************;

;== Constantes =========================================================

SC_INDEX       = 3c4h      ;Registre d'index du contr“leur du s‚quenceur
SC_MAP_MASK    = 2                          ;Num‚ro du registre Map Mask
SC_MEM_MODE    = 4                   ;Num‚ro du registre de mode m‚moire

GC_INDEX       = 3ceh          ;Registre d'index du contr“leur graphique
GC_READ_MAP    = 4                          ;Num‚ro du registre Read Map
GC_BIT_MASK    = 8               ;Num‚ro du registre de masquage binaire

PIXX           = 640                             ;R‚solution horizontale

;== Segment de donn‚es =================================================

DATA   segment word public
DATA   ends

;== Programme===========================================================

CODE   segment byte public                         ;Segment de programme

       assume cs:code, ds:data

;-- D‚clarations publiques ---------------------------------------------

public     copybuf2video
public     mergeandcopybuf2video
public     copyvideo2buf

;-----------------------------------------------------------------------
;-- CopyBuf2Video: Recopie en m‚moire d'‚cran le contenu d'une zone
;--                rectangulaire pr‚alablement sauvegard‚e par
;--                CopyVideo2Buf
;-- Appel depuis TP: CopyBuf2Plane( bufptr   : pointer;
;--                               verspage : byte;
;--                               versx,
;--                               versy    : integer;
;--                               largeur,
;--                               hauteur    : byte );
;-- Info         : cf CopyVideo2Buf

copybuf2video proc near

sfr0     struc                              ;Structure d'accŠs … la pile
bp0      dw ?                                               ;M‚morise BP
stofs0   dw ?             ;Var loc: Offset de d‚but dans m‚moire d'‚cran
ret_adr0 dw ?                            ;Adresse de retour … l'appelant
hauteur0 dw ?                                        ;Hauteur de la zone
largeur0 dw ?                                                   ;Largeur
versy    dw ?                                   ;Ordonn‚e de destination
versx    dw ?                                   ;Abscisse de destination
verspage dw ?                                       ;Page de destination
bufptr0  dd ?                                       ;Pointeur sur buffer
sfr0     ends                                       ;Fin de la structure

fr     equ [ bp - bp0 ]               ;adr. les ‚l‚ments de la structure
bfr    equ byte ptr [ bp - bp0 ] ;adr. les ‚l‚ments de la pile en octets

       sub   sp,2                ;De la place pour les variables locales

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       push  ds

       cld                      ;Fixe le sens des op‚rations sur chaŒnes

              ;-- Calcule le segment d'accŠs … la m‚moire d'‚cran ------

       mov   ax,0A000h            ;ES au d‚but de la page de destination
       cmp   bfr.verspage,0                          ;Est-ce la page 0 ?
       je    cv0                                        ;Oui, AL est bon

       mov   ax,0A6D6h                           ;Non, , page 1 en A6D6h

cv0:   mov   es,ax

         ;-- Calcule l'offset de la position de destination dans la page

       mov   ax,PIXX / 8                 ;AX sur position de destination
       mul   fr.versy
       mov   bx,fr.versx
       shr   bx,1
       shr   bx,1
       shr   bx,1
       add   bx,ax
       mov   fr.stofs0,bx          ;M‚morise le r‚sultat dans var locale

       lds   si,fr.bufptr0                   ;DS:SI pointe sur le buffer

       ;-- Initialise les compteurs pour la boucle de copie ------------

       mov   dl,bfr.largeur0                                ;DL = octets
       mov   bx,PIXX / 8                 ;BX = Offset sur ligne suivante
       sub   bl,dl
       xor   ch,ch                           ;Octet fort du compteur = 0

                                 ;-- Pr‚pare l'adressage du plan de bits

       mov   ah,1               ;Le num‚ro du plan est pris comme masque
       mov   al,SC_MAP_MASK          ;Charge en AL le num‚ro du registre

cv1:   mov   dx,SC_INDEX             ;Cl“ture la demande d'accŠs au plan
       out   dx,ax

           ;-- Routine de copie pour un plan de bits sans respect - ----
                                                             ;-- du fond

       mov   di,fr.stofs0                       ;DI sur offset de d‚part
       mov   dh,bfr.hauteur0                                ;DH = lignes
       mov   dl,bfr.largeur0                                ;DL = octets

cv2:   mov   cl,dl                                ;Nombre d'octets en CL

       rep movsb                                        ;Copie une ligne
       add   di,bx                                ;DI sur ligne suivante
       dec   dh                                  ;Reste-t-il une ligne ?
       jne   cv2                                    ;Oui---> on continue

       shl   ah,1                                 ;Passe au plan suivant
       test  ah,16                  ;Tous les plans ont-il ‚t‚ trait‚s ?
       je    cv1                                       ;Non, on continue

       mov   ax,(0Fh shl 8)+ SC_MAP_MASK          ;Autorise l'accŠs …  -
       mov   dx,SC_INDEX                                 ;tous les plans
       out   dx,ax

       pop   ds                                       ;R‚cupŠre DS et BP
       pop   bp

       add   sp,2                          ;Retire les variables locales
       ret   14                       ;Retourne … l'appelant en enlevant
                                             ; les paramŠtres de la pile
copybuf2video endp

;-----------------------------------------------------------------------
;-- MergeAndCopyBuf2Video: Combine le contenu d'un buffer de fond avec
;--                        celui d'un buffer sprite par l'interm‚diaire
;--                        d'un masque binaire et copie le r‚sultat dans
;--                        la m‚moire d'‚cran
;-- Appel depuis TP: MergeAndCopyBuf2Video( spribufptr,
;--                                         fondbufptr,
;--                                         andbufptr  : pointer;
;--                                         page       : byte;
;--                                         versx,
;--                                         versy      : integer;
;--                                         largeur,
;--                                         hauteur      : byte );
;-- Info         : cf CopyVideo2Buf

mergeandcopybuf2video proc near

sfr2    struc                               ;Structure d'accŠs … la pile
bp2        dw ?                                            ; m‚morise BP
andptr2    dd ?                       ;Var loc: Pointeur dans buffer AND
stofs2     dw ?              ;Var loc: Offset de d‚but en m‚mire d'‚cran
ret_adr2   dw ?                          ;Adresse de retour … l'appelant
hauteur2   dw ?                                      ;Hauteur de la zone
largeur2   dw ?                                                 ;Largeur
versy2     dw ?                                 ;Ordonn‚e de destination
versx2     dw ?                                 ;Abscisse de destination
verspage2  dw ?                                     ;Page de destination
andbufptr  dd ?                                 ;Pointeur sur buffer AND
fondbufptr dd ?                             ;Pointeur sur buffer de fond
spribufptr dd ?                           ;Pointeur sur buffer de sprite
sfr2    ends                                        ;Fin de la structure

fr     equ [ bp - bp2 ]               ;adr. les ‚l‚ments de la structure
bfr    equ byte ptr [ bp - bp2 ] ;adr. les ‚l‚ments de la pile en octets

       sub   sp,6                ;De la place pour les variables locales

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       push  ds

       cld                      ;Fixe le sens des op‚rations sur chaŒnes

                     ;-- Calcule le segment d'accŠs … la m‚moire d'‚cran

       mov   ax,0A000h            ;ES au d‚but de la page de destination
       cmp   bfr.verspage2,0                          ;Est-ce la page 0?
       je    cm0                                        ;Oui, AL est o.k

       mov   ax,0A6D6h                            ;Non , page 1 en A6D6h

cm0:   mov   es,ax

         ;-- calcule l'offset de la position de destination dans la page

       mov   ax,PIXX / 8                 ;AX sur position de destination
       mul   fr.versy2
       mov   bx,fr.versx2
       shr   bx,1
       shr   bx,1
       shr   bx,1
       add   bx,ax
       mov   fr.stofs2,bx               ;M‚morise le r‚sultat en var loc

                 ;-- Initialise les compteurs pour la boucle d'it‚ration

       mov   dl,bfr.largeur2                                ;DL = octets
       mov   bx,PIXX / 8                 ;BX = offset sur ligne suivante
       sub   bl,dl
       xor   ch,ch                    ;Octet fort du compteur toujours 0

       mov   ax,word ptr fr.andbufptr+2                ;Copie en var loc
       mov   word ptr fr.andptr2+2,ax       ; le segment du pointeur AND

                 ;-- Pr‚pare l'adressage du plan de bits ---------------

       mov   ah,1                   ;Num‚ro du plan comme masque binaire

cm1:   mov   al,SC_MAP_MASK          ;Charge en AL le num‚ro du registre
       mov   dx,SC_INDEX                     ;Cl“ture la demande d'accŠs
       out   dx,ax

           ;-- Routine de copie pour un plan de bits sans tenir compte -
                                                             ;-- du fond

       mov   dx,word ptr fr.andbufptr                  ;Copie en var loc
       mov   word ptr fr.andptr2,dx            ;l'offset du pointeur AND
       mov   di,fr.stofs2                       ;DI sur offset de d‚part
       mov   dh,bfr.hauteur2                                ;DH = Lignes
       mov   dl,bfr.largeur2                                ;DL = octets

cm2:   mov   cl,dl                                ;Nombre d'octets en CL

cm3:   lds   si,fr.fondbufptr                  ;Charge pointeur de  fond
       lodsb                             ;Lit un octet du buffer du fond
       mov   word ptr fr.fondbufptr,si     ;M‚morise l'offset incr‚ment‚

       lds   si,fr.andptr2               ;Charge pointeur sur buffer AND
       and   al,[si]                 ;Combine le fond avec le masque AND
       inc   si                  ;Incr‚mente l'offset dans le buffer AND
       mov   word ptr fr.andptr2,si                    ;puis le m‚morise

       lds   si,fr.spribufptr;Charge le pointeur sur le buffer du sprite
       or    al,[si]               ;Combine un octet de ce buffer par OR
       inc   si            ;Incr‚mente l'offset dans le buffer du sprite
       mov   word ptr fr.spribufptr,si                 ;puis le m‚morise

       stosb                          ;D‚pose l'octet en m‚moire d'‚cran
       loop  cm3                                 ;Traite l'octet suivant

       add   di,bx                                ;DI sur ligne suivante
       dec   dh                                  ;Reste-t-il une ligne ?
       jne   cm2                                   ;Oui ---> on continue

       shl   ah,1                                 ;Passe au plan suivant
       test  ah,16                 ;Tous les plans ont-ils ‚t‚ trait‚s ?
       je    cm1                                       ;Non, on continue

       mov   ax,(0Fh shl 8)+ SC_MAP_MASK               ;Autorise l'accŠs
       mov   dx,SC_INDEX                               ;… tous les plans
       out   dx,ax

       pop   ds                                       ;R‚cupŠre DS et BP
       pop   bp

       add   sp,6                          ;Retire les variables locales
       ret   22                       ;Retourne … l'appelant en enlevant
                                              ;les paramŠtres de la pile
mergeandcopybuf2video endp

;-----------------------------------------------------------------------
;-- CopyVideo2Buf: Copie dans un buffer une zone rectangulaire de
;--                la m‚moire d'‚cran
;-- Appel depuis TP: CopyVideo2Buf( bufptr : pointer;
;--                               depage: byte;
;--                               dex,
;--                               dey    : integer;
;--                               largeur,
;--                               hauteur   : byte );
;-- Info         : Dans cette version de la routine la zone … copier
;--                doit commencer … une colonne de pixels divisible par
;--                huit, et s'‚tendre sur un nombre de pixels multiple
;--                de 8
;--                LARGEUR est ici le nombre d'octets par ligne dans
;--                un plan de bits !

copyvideo2buf proc near

sfr1    struc                               ;Structure d'accŠs … la pile
bp1        dw ?                                             ;M‚morise BP
stofs1     dw ?             ;Var loc: Offset de d‚but en m‚moire d'‚cran
ret_adr1   dw ?                          ;Adresse de retour … l'appelant
hauteur1   dw ?                            ;Hauteur de la zone en pixels
largeur1   dw ?                            ;Largeur de la zone en pixels
dey        dw ?                                      ;Ordonn‚e d'origine
dex        dw ?                                      ;Abscisse d'origine
depage     dw ?                                          ;Page d'origine
bufptr1    dd ?                                     ;Pointeur sur buffer
sfr1    ends                                        ;Fin de la structure

fr     equ [ bp - bp1 ]               ;adr. les ‚l‚ments de la structure
bfr    equ byte ptr [ bp - bp1 ]    ;adr. un ‚l‚ment de pile comme octet

       sub   sp,2                ;De la place pour les variables locales

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       push  ds
       cld                         ;Fixe le sens de parcours des chaŒnes

             ;-- Calcule le segment d'accŠs … la m‚moire d'‚cran  ------

       mov   ax,0A000h                 ;ES au d‚but de la page d'origine
       cmp   bfr.depage,0                            ;Est-ce la page 0 ?
       je    cc0                                        ;Oui, AL est bon

       mov   ax,0A6D6h                           ;Non , page 1 en  A6D6h

cc0:   mov   ds,ax

            ;-- Forme l'offset dans la page … lire     -----------------

       mov   ax,PIXX / 8                      ;AX sur position d'origine
       mul   fr.dey
       mov   bx,fr.dex
       shr   bx,1
       shr   bx,1
       shr   bx,1
       add   bx,ax
       mov   fr.stofs1,bx             ;m‚morise le r‚sultat dans var loc

       les   di,fr.bufptr1                   ;ES:DI pointe sur le buffer

              ;-- Initialise les compteurs pour la boucle de copie -----

       mov   dl,bfr.largeur1                                ;DL = octets
       mov   bx,PIXX / 8                ;BX =  Offset sur ligne suivante
       sub   bl,dl
       xor   ch,ch                         ;Octet fort du compteur tjs 0

                  ;-- Pr‚pare l'adressage du plan de bits --------------

       xor   ah,ah                               ;Commence par le plan 0
       mov   al,GC_READ_MAP          ;Charge le num‚ro du registre en AL

cc1:   mov   dx,GC_INDEX ;Charge adresse d'index du contr“leur graphique
       out   dx,ax                          ;Charge le registre Read Map

           ;-- Routine de copie d'un plan de bits, ne tient pas compte--
                                                             ;-- du fond

       mov   dh,bfr.hauteur1                                ;DH = lignes
       mov   dl,bfr.largeur1                                ;DL = octets
       mov   si,fr.stofs1                        ;Offset de d‚part en SI

cc2:   mov   cl,dl                                ;Nombre d'octets en CL
       rep movsb                                        ;Copie une ligne
       add   si,bx                                ;SI sur ligne suivante
       dec   dh                                  ;Reste-t-il une ligne ?
       jne   cc2                                        ;Oui on poursuit

       inc   ah                                   ;Passe au plan suivant
       cmp   ah,4                          ;A-t-on trait‚ ts les plans ?
       jne   cc1                          ;Non, c'est le tour du suivant

       pop   ds                                       ;R‚cupŠre DS et BP
       pop   bp

       add   sp,2                          ;Retire les variables locales
       ret   14                                   ;Retourne … l'appelant
                                    ;et enlŠve les paramŠtres de la pile
copyvideo2buf endp

;== Fin ===============================================================

CODE   ends                                      ;Fin du segment de code
       end                                             ;Fin du programme
