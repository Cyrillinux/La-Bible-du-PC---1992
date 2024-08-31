;**********************************************************************;
;*                         S 3 2 4 0 P A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction : Contient les routines pour travailler avec le        *;
;*               sprites dans le mode 320*400-256 de la carte VGA     *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   : 08.09.1990                                     *;
;*    DerniŠre MAJ   : 14.01.1991                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM /mx S3240PA;    ou   TASM -mx S3240PA     *;
;*                     ... puis lier … S3240P.PAS                     *;
;**********************************************************************;


;== Constantes =========================================================

SC_INDEX       = 3c4h              ;Registre du contr“leur du s‚quenceur
SC_MAP_MASK    = 2                          ;Num‚ro du registre Map Mask
SC_MEM_MODE    = 4                   ;Num‚ro de registre de mode m‚moire

GC_INDEX       = 3ceh           ;Registre d'index du cntr“leur graphique
GC_READ_MAP    = 4                          ;Num‚ro du registre Read Map

PIXX           = 320                             ;R‚solution horizontale

;== Segment de donn‚es =================================================

DATA   segment word public

DATA   ends

;== Programme ==========================================================

CODE       segment byte public                     ;Segment de programme

       assume cs:code, ds:data

;-- D‚clarations publiques ----------------------------------------

public     copybuf2plane
public     copyplane2buf

;-----------------------------------------------------------------------
;-- CopyBuf2Plane: Copie le contenu d'un buffer dans une zone
;--                rectangulaire d'un plan de bits
;-- Appel depuis TP: CopyBuf2Plane( bufptr   : pointer;
;--                               verspage : byte;
;--                               versx,
;--                               versy    : integer;
;--                               largeur,
;--                               hauteur    : byte;
;--                               bg       : bool  );

copybuf2plane proc near

sfr0       struc                            ;Structure d'accŠs … la pile
bp0        dw ?                                             ;M‚morise BP
ret_adr0   dw ?                          ;Adresse de retour … l'appelant
bg         dw ?                                    ;Tient compte du fond
hauteur0   dw ?                                      ;Hauteur de la zone
largeur0   dw ?                                                 ;Largeur
versy      dw ?                                 ;Ordonn‚e de destination
versx      dw ?                                 ;Abscisse de destination
verspage   dw ?                                     ;Page de destination
bufptr0    dd ?                                     ;Pointeur sur buffer
sfr0    ends                                        ;Fin de la structure

fr     equ [ bp - bp0 ]            ;Adresse les ‚l‚ments de la structure
bfr    equ byte ptr [ bp - bp0 ]    ;Adresse un ‚l‚ment de la pile octet

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       push  ds
       cld                     ;Fixe le sens des traitements sur chaŒnes

              ;-- Calcule le segment d'accŠs … la m‚moire d'‚cran ------

       mov   ah,0A0h              ;ES au d‚but de la page de destination
       cmp   bfr.verspage,0                          ;Est-ce la page 0 ?
       je    cv0                                        ;Oui, AL est bon

       mov   ah,0A8h                              ;Non, page 1 en  A800h

cv0:   xor   al,al                            ;Octet faible toujours nul
       mov   es,ax

       ;-- Calcule l'offset de la position de destination dans la page -

       mov   ax,PIXX / 4                 ;DI sur position de destination
       mul   fr.versy
       mov   di,fr.versx
       mov   cx,di                               ; M‚morise l'abscisse X
       shr   di,1
       shr   di,1
       add   di,ax

                 ;-- Pr‚pare l'adressage du plan de bits ---------------

       mov   ah,1                            ;Le num‚ro du plan est pris
       and   cl,3                                  ;comme masque binaire
       shl   ah,cl
       mov   dx,SC_INDEX                         ;Assure l'accŠs au plan
       mov   al,SC_MAP_MASK                                  ; … traiter
       out   dx,ax

  ;-- Charge les compteurs pour la boucle de copie ---------------------

       mov   dh,bfr.hauteur0                                ;DH = Lignes
       mov   dl,bfr.largeur0                                ;DL = Octets
       mov   bx,PIXX / 4                 ;BX = offset sur ligne suivante
       sub   bl,dl
       xor   ch,ch                    ;Octet fort du compteur toujours 0

       lds   si,fr.bufptr0             ;DS:SI doit pointer sur le buffer

       cmp   bfr.bg,0                                ;Fond … respecter ?
       jne   cv2                         ;Oui, utilise une autre routine

              ;-- Routine de copie pour un plan de bits, ne respecte ---
                                                         ;-- pas le fond

cv1:   mov   cl,dl                                ;Nombre d'octets en CL

       rep movsb                                        ;Copie une ligne
       add   di,bx                                ;DI sur ligne suivante
       dec   dh                                        ;Reste une ligne?
       jne   cv1                                    ;Oui---> on continue

       jmp   short cvend                              ;Non, buffer copi‚

                        ;-- Routine de copie pour plan de bits avec    -
                                     ;-- exploitation du buffer transmis

cv2:   mov   cl,dl                                ;Nombre d'octets en CL

cv3:   lodsb                                  ;Charge un octet du buffer
       cmp   al,255                                     ;Octet de fond ?
       je    cv5                                 ;Oui ---> ne pas copier
       stosb                       ;Non, le transfŠre en m‚moire d'‚cran
       loop  cv3                                 ;Traite l'octet suivant

cv4:  ;-- Avance le pointeur de la m‚moire d'‚cran sur la ligne suivante

       add   di,bx                                ;DI sur ligne suivante
       dec   dh                                        ;Reste une ligne?
       jne   cv2                                    ;Oui---> on continue
       jmp   short cvend                              ;Non, buffer copi‚

cv5:        ;-- Octet de fond … ne pas copier      ---------------------

       inc   di              ;Ne pas mettre cet octet en m‚moire d'‚cran
      loop  cv3                  ;Reste-t-il un octet dans cette ligne ?
       jmp   cv4                                ;Non ---> Ligne suivante

cvend: pop   ds
       pop   bp

       ret   16                        ;Retire les paramŠtres de la pile
                                                       ; et rend la main
copybuf2plane endp

;-----------------------------------------------------------------------
;-- CopyPlane2Buf: Copie une zone rectangulaire d'un plan de bits dans
;--                un buffer
;-- Appel depuis TP: CopyPlane2Buf( bufptr : pointer;
;--                               depage: byte;
;--                               dex,
;--                               dey    : integer;
;--                               largeur,
;--                               hauteur   : byte );

copyplane2buf proc near

sfr1     struc                              ;Structure d'accŠs … la pile
bp1       dw ?                                              ;M‚morise BP
ret_adr1  dw ?                           ;ADresse de retour … l'appelant
hauteur1  dw ?                             ;Hauteur de la zone en pixels
largeur1  dw ?                             ;Largeur de la zone en pixels
dey       dw ?                                       ;Ordonn‚e d'origine
dex       dw ?                                       ;Abscisse d'origine
depage    dw ?                                           ;Page d'origine
bufptr1   dd ?                                      ;Pointeur sur buffer
sfr1   ends                                         ;Fin de la structure

fr     equ [ bp - bp1 ]            ;Adresse les ‚l‚ments de la structure
bfr    equ byte ptr [ bp - bp1 ]       ;Adr ‚l‚ments de pile comme octet

       push  bp                      ;Pr‚pare l'adressage des paramŠtres
       mov   bp,sp                                  ; par le registre BP

       push  ds

               ;-- Calcule le segment d'accŠs … la m‚moire d'‚cran -----

       mov   ah,0A0h                   ;ES au d‚but de la page d'origine
       cmp   bfr.depage,0                            ;Est-ce la page 0 ?
       je    cc0                                         ;Oui AL est bon

       mov   ah,0A8h                            ;Non, la page 1 en A800h

cc0:   xor   al,al                            ;Octet faible toujours nul
       mov   ds,ax

                ;-- Forme l'offset dans la page … lire -----------------

       mov   ax,PIXX / 4                   ;SI sur la position d'origine
       mul   fr.dey
       mov   si,fr.dex
       mov   cx,si                  ;M‚morise ‚galement l'abscisse en CX
       shr   si,1
       shr   si,1
       add   si,ax

                     ;-- Fixe le plan de bits … adresser ---------------

       and   cl,3                      ;Calcule en AH les masque binaire
       mov   ah,cl                                ;pour le plan concern‚
       mov   al,GC_READ_MAP       ;TransfŠre en AL le num‚ro du registre
       mov   dx,GC_INDEX ;Charge l'adresse index du contr“leur graphique
       out   dx,ax                          ;Charge le registre Read Map

             ;-- Charge les compteurs pour la boucle de copie-----------

       mov   dh,bfr.hauteur1                                ;DH = Lignes
       mov   dl,bfr.largeur1                                ;DL = octets
       mov   bx,PIXX / 4                 ;BX = offset sur ligne suivante
       sub   bl,dl
       xor   ch,ch                    ;Octet haut du compteur toujours 0

       les   di,fr.bufptr1             ;ES:DI doit pointer sur le buffer

                        ;-- Routine de copie pour un plan de bits - ----
                                           ;-- sans tenir compte du fond
cc1:   mov   cl,dl                                ;Nombre d'octets en CL

       rep movsb                                        ;Copie une ligne
       add   si,bx                                ;SI sur ligne suivante
       dec   dh                                       ;Reste une ligne ?
       jne   cc1                                        ;Oui on continue

       pop   ds
       pop   bp

           ret   14

copyplane2buf endp

;== Fin ===============================================================

CODE   ends                                      ;Fin du segment de code
       end                                             ;Fin du programme
