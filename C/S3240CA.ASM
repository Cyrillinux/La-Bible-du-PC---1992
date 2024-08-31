;**********************************************************************;
;*                         S 3 2 4 0 C A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction      : contient des routines pour travailler avec les  *;
;*         sprites dans le mode 320*400-256  de la carte VGA          *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le   :  8.09.1990                                     *;
;*    DerniŠre MAJ   : 14.02.1992                                     *;
;*--------------------------------------------------------------------*;
;*    ModŠle m‚moire : SMALL                                          *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM /mx S3240CA;    ou     TASM -mx S3240CA   *;
;*                     ... puis lier … S3240C.C                       *;
;**********************************************************************;

IGROUP group _text                   ;Regroupe les segments de programme
DGROUP group _bss,  _data              ;Regroupe les segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS'          ;Segment r‚serv‚ aux variables
_BSS   ends                                  ;statiques non initialis‚es

_DATA  segment word public 'DATA'        ;Segment des variables globales
                                          ;et statiques non initialis‚es

_DATA  ends

;== Constantes =========================================================

SC_INDEX       = 3c4h      ;Registre d'index du contr“leur du s‚quenceur
SC_MAP_MASK    = 2                          ;Num‚ro de registre Map Mask
SC_MEM_MODE    = 4                   ;Num‚ro du registre de mode m‚moire

GC_INDEX       = 3ceh          ;Registre d'index du contr“leur graphique
GC_READ_MAP    = 4                          ;Num‚ro du registre Read Map

PIXX           = 320                             ;R‚solution horizontale

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'                  ;Segment de programme
;-- D‚clarations publiques ---------------------------------------------

public     _copybuf2plane
public     _copyplane2buf

;-----------------------------------------------------------------------
;-- CopyBuf2Plane: copie contenu d'un buffer dans une zone rectangulaire
;--                d'un plan de bits
;-- D‚claration: CopyBuf2Plane( byte *bufptr,
;--                             byte verspage,
;--                             int  versx,
;--                             int  versy,
;--                             byte largeur,
;--                             byte hauteur,
;--                             bool bg );

_copybuf2plane proc near

sfr0      struc                             ;Structure d'accŠs … la pile
bp0        dw ?                                             ;M‚morise BP
ret_adr0   dw ?                          ;Adresse de retour … l'appelant
bufptr0    dw ?                                     ;Pointeur sur buffer
verspage   dw ?                                     ;Page de destination
versx      dw ?                                 ;Abscisse de destination
versy      dw ?                                 ;Ordonn‚e de destination
largeur0   dw ?                                                 ;Largeur
hauteur0   dw ?                                      ;Hauteur de la zone
bg         dw ?                                    ;Tient compte du fond
sfr0      ends                                      ;Fin de la structure

fr     equ [ bp - bp0 ]            ;adresse les ‚l‚ments de la structure
bfr    equ byte ptr [ bp - bp0 ]     ;adresse ‚l‚ments pile comme octets

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP
       push  di
       push  si

       ;-- Calcule le segment d'accŠs … la m‚moire d'‚cran -------------

       mov   ah,0A0h              ;ES au d‚but de la page de destination
       cmp   bfr.verspage,0                           ;Est-ce la page 0?
       je    cv0                                    ;Oui AL est tout bon

       mov   ah,0A8h                               ;Non, page 1 en A800h

cv0:   xor   al,al                            ;Octet faible toujours nul
       mov   es,ax

       ;-- Calcule l'offset de la position de destination dans la page -

       mov   ax,PIXX / 4                 ;DI sur position de destination
       mul   fr.versy
       mov   di,fr.versx
       mov   cx,di                                ;m‚morise l'abscisse X
       shr   di,1
       shr   di,1
       add   di,ax

       ;-- Pr‚pare l'adressage du plan de bits    ----------------------

       mov   ah,1                            ;Le num‚ro du plan est pris
       and   cl,3                                 ; comme masque binaire
       shl   ah,cl
       mov   dx,SC_INDEX                         ;Assure l'accŠs au plan
       mov   al,SC_MAP_MASK
       out   dx,ax

       ;-- Charge les compteurs pour la boucle de copie ----------------

       mov   dh,bfr.hauteur0                                ;DH = lignes
       mov   dl,bfr.largeur0                                ;DL = octets
       mov   bx,PIXX / 4                 ;BX = offset sur ligne suivante
       sub   bl,dl
       xor   ch,ch                  ;Octet fort du compteur toujours nul

       mov   si,fr.bufptr0             ;DS:SI doit pointer sur le buffer

       cmp   bfr.bg,0                                ;Fond … respecter ?
       jne   cv2                         ;Oui, utilise une autre routine

       ;-- Routine de copie pour un plan de bits, ne respecte ----------
                                                         ;-- pas le fond

cv1:   mov   cl,dl                                ;Nombre d'octets en CL

       rep   movsb                                      ;Copie une ligne
       add   di,bx                                ;DI sur ligne suivante
       dec   dh                                       ;Reste une ligne ?
       jne   cv1                                    ;Oui---> on continue

       jmp   short cvend                              ;Non, buffer copi‚

       ;-- Routine de copie pour plan de bits avec exploitation --------
                                                  ;-- du buffer transmis

cv2:   mov   cl,dl                                ;Nombre d'octets en CL

cv3:   lodsb                                  ;Charge un octet du buffer
       cmp   al,255                                     ;Octet de fond ?
       je    cv5                                  ;Oui ---> ne ps copier
       stosb                       ;Non, le transfŠre en m‚moire d'‚cran
       loop  cv3                                 ;Traite l'octet suivant

cv4:   ;- Avance le pointeur de la m‚moire d'‚cran sur la ligne suivante

       add   di,bx                                ;DI sur ligne suivante
       dec   dh                                  ;Reste-t-il une ligne ?
       jne   cv2                                   ;Oui ---> on continue
       jmp   short cvend                              ;Non, buffer copi‚

cv5:   ;-- Octet de fond … ne pas copier -------------------------------

       inc   di              ;Ne pas mettre cet octet en m‚moire d'‚cran
       loop  cv3                 ;Reste-t-il un octet dans cette ligne ?
       jmp   cv4                                ;Non ---> ligne suivante

cvend: pop   si                       ;Reprend les registres sur la pile
       pop   di
       pop   bp
       ret                                        ;Retourne … l'appelant

_copybuf2plane endp

;-----------------------------------------------------------------------
;-- CopyPlane2Buf: Copie une zone zone rectangulaire d'un plan de bits
;--                dans un buffer
;-- D‚claration : CopyPlane2Buf( byte *bufptr,
;--                                   byte depage,
;--                                   int  dex,
;--                                   int  dey,
;--                                   byte largeur,
;--                                   byte hauteur );

_copyplane2buf proc near

sfr1      struc                             ;Structure d'accŠs … la pile
bp1        dw ?                                             ;M‚morise BP
ret_adr1   dw ?                          ;Adresse de retour … l'appelant
bufptr1    dw ?                                  ;Pointeur sur le buffer
depage     dw ?                                          ;Page d'origine
dex        dw ?                                      ;Abscisse d'origine
dey        dw ?                                      ;Ordonn‚e d'origine
largeur1   dw ?                            ;Largeur de la zone en pixels
hauteur1   dw ?                            ;Hauteur de la zone en pixels
sfr1      ends                                      ;Fin de la structure

fr     equ [ bp - bp1 ]            ;adresse les ‚l‚ments de la structure
bfr    equ byte ptr [ bp - bp1 ]               ;adresse pile comme octet

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP
       push  di
       push  si
       push  ds                                           ;Sauvegarde DS
       push  ds                             ;DeuxiŠme exemplaire pour ES

       ;-- Calcule le segment d'accŠs … la m‚moire d'‚cran -------------

       mov   ah,0A0h                   ;ES au d‚but de la page d'origine
       cmp   bfr.depage,0                            ;Est-ce la page 0 ?
       je    cc0                                         ;Oui AL est bon

       mov   ah,0A8h                                ;Non page 1 en A800h

cc0:   xor   al,al                            ;Octet faible toujours nul
       mov   ds,ax

       ;-- Forme l'offset dans la page … lire --------------------------

       mov   ax,PIXX / 4                      ;SI sur position d'origine
       mul   fr.dey
       mov   si,fr.dex
       mov   cx,si                            ;M‚morise l'abscisse en CX
       shr   si,1
       shr   si,1
       add   si,ax

       ;-- Pr‚pare l'adressage du plan de bits -------------------------

       and   cl,3                  ;Calcule en AH le masque binaire pour
       mov   ah,cl                                    ; le plan concern‚
       mov   al,GC_READ_MAP                    ;Num‚ro du registre en AL
       mov   dx,GC_INDEX           ;Charge index du contr“leur graphique
       out   dx,ax                             ;Lit le registre Read Map

       ;-- Charge les compteurs pour la boucle de copie ----------------

       mov   dh,bfr.hauteur1                                ;DH = lignes
       mov   dl,bfr.largeur1                                ;DL = octets
       mov   bx,PIXX / 4                 ;BX = offset sur ligne suivante
       sub   bl,dl
       xor   ch,ch                    ;Octet fort du compteur toujours 0

       pop   es                        ;ES:DI doit pointer sur le buffer
       mov   di,fr.bufptr1

       ;-- Routine de copie pour un plan de bits sans tenir ------------
       ;-- compte du fond ----------------------------------------------

cc1:   mov   cl,dl                                ;Nombre d'octets en CL

       rep   movsb                                      ;Copie une ligne
       add   si,bx                                ;SI sur ligne suivante
       dec   dh                                  ;reste-t-il une ligne ?
       jne   cc1                                       ;Oui, on continue

       pop   ds                                             ;R‚cupŠre DS
       pop   si
       pop   di
       pop   bp

       ret                                        ;Retourne … l'appelant

_copyplane2buf endp

;== Fin ===============================================================

_text    ends                               ;Fin du segment de programme
         end                             ;Fin de la source en assembleur
