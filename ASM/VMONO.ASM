;**********************************************************************;
;*                            V M O N O                               *;
;*--------------------------------------------------------------------*;
;*    Fonction       : fournit quelques fonctions de base pour        *;
;*                     l'accŠs … l'‚cran monochrome.                  *;
;*                                                                    *;
;*--------------------------------------------------------------------*;
;*    Infos          : Toutes les fonctions divisent l'‚cran en       *;
;*                     colonnes 0 … 79 et lignes 0 … 24               *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    d‚velopp‚ le   : 11/08/1987                                     *;
;*    DerniŠre modif.: 01/04/1989                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM VMONO;                                    *;
;*                     LINK VMONO;                                    *;
;*--------------------------------------------------------------------*;
;*    Appel          : VMONO                                          *;
;**********************************************************************;

;== Constantes =========================================================

REG_CONTR   = 03B8h                ;Adr. de port du registre de contr“le
ADRESS_6845 = 03B4h                          ;Registre d'adresse du 6845
DATA_6845   = 03B5h                         ;Registre de donn‚es du 6845
VIO_SEG     = 0B000h                 ;Adresse de segment de la RAM vid‚o
CUR_START   = 10           ;Nø registre CRTC: ligne de d‚part du curseur
CUR_END     = 11              ;Nø registre CRTC: ligne de fin du curseur
CURPOS_HI   = 14              ;Nø registre CRTC: octet fort pos. curseur
CURPOS_LO   = 15            ;Nø registre CRTC: octet faible pos. curseur

DELAY       = 20000            ;Compteur de boucle pour boucle d'attente

;== Pile ===============================================================

stack     segment para stack              ;D‚finition du segment de pile

          dw 256 dup (?)               ;La pile a une taille de 256 mots

stack     ends                                   ;Fin du segment de pile

;== Donn‚es ============================================================

data      segment para 'DATA'          ;D‚finition du segment de donn‚es

;== Les donn‚es pour le programme de d‚monstration =====================

str1      db "a" ,0
str2      db " >>> BIBLE PC <<< ",0
str3      db "   Fenˆtre 1   ",0
str4      db "   Fenˆtre 2   ",0
str5      db "          Le programme s'arrˆte lorsqu'on appuie sur "
      db "une touche....             ",0
initm   db 13,10
        db "ÛÛÛÛÛÛÛ VMONO (c) 1987,1989 by Michael Tischer ÛÛÛÛÛÛ"
        db 13,10,13,10
        db "Ce programme de d‚monstration ne tourne qu'avec une ",13,10
        db "carte d'‚cran monochrome (MDA). Si votre PC dispose",13,10
        db "d'un autre type de carte d'‚cran, veuillez maintenant",13,10
        db "entrer <S> pour arrˆter le programme.",13,10
        db "Sinon veuillez frapper n'importe quelle autre touche",13,10
        db "pour lancer le programme ...",13,10,"$"

;== Table avec les adresses d'offset des d‚buts de ligne ===============

lignes    dw  0*160, 1*160, 2*160, 3*160, 4*160, 5*160, 6*160
          dw  7*160, 8*160, 9*160,10*160,11*160,12*160,13*160
          dw 14*160,15*160,16*160,17*160,18*160,19*160,20*160
          dw 21*160,22*160,23*160,24*160

data      ends                                ;Fin du segment de donn‚es

;== Code ===============================================================

code      segment para 'CODE'             ;D‚finition du segment de CODE

          assume cs:code, ds:data, es:data, ss:stack

;== Il s'agit simplement du programme de d‚monstration =================

demo      proc far

          mov  ax,data ;Rechercher adr. de segment du segment de donn‚es
          mov  ds,ax                                 ;et charger dans DS
          mov  es,ax                                  ;‚galement dans ES

;-- Sortir message Init et attendre entr‚e -----------------------------

          mov  ah,9               ;Num‚ro de fonction pour Sortir chaŒne
          mov  dx,offset initm                       ;Adresse du message
          int  21h                          ;Appeler interruption du DOS

          xor  ah,ah                ;Num‚ro de fonction pour Lire touche
          int  16h                 ;Appeler interruption clavier du BIOS
          cmp  al,"s"                                       ;<s> entr‚ ?
          je   fin                 ;OUI --> Terminer programme … nouveau
          cmp  al,"s"                                         ;<s> entr‚
          jne  startdemo                            ;NON --> Lancer d‚mo

fin:      mov  ax,4C00h           ;N de fonction pour Terminer programme
          int  21h                         ;Appeler interruption DOS 21h
;-- Programme de d‚monstration de l'appel des fonctions ----------------

startdemo label near
          mov  cx,0d00h                           ;Activer curseur plein
          call cdef
          call cls                                        ;Vider l'‚cran

;-- Remplir l'‚cran avec caract. du jeu de caractŠres ASCII.

          xor  di,di              ;Commencer dans coin sup. gauche ‚cran
          mov  si,offset str1              ;Adresse d'offset de chaŒne 1
          mov  cx,2000            ;2000 caractŠres rentrent dans l'‚cran
          mov  al,07h                    ;Ecriture blanche sur fond noir
demo1:    call print                                      ;Sortir chaŒne
          inc  str1                ;Incr. caract. Ascii dans chaŒne test
          jne  demo2                        ;Code NUL doit ˆtre interdit
          inc  str1
demo2:    loop demo1                                     ;R‚p‚ter sortie

;-- Construire fenˆtres 1 et 2 -----------------------------------------
          mov  bx,0508h                      ;Coin sup. gauche fenˆtre 1
          mov  dx,1316h                       ;Coin inf. droit fenˆtre 1
          mov  ah,07h                    ;Ecriture blanche sur fond noir
          call clear                                    ;Vider fenˆtre 1
          mov  bx,3C02h                      ;Coin sup. gauche fenˆtre 2
          mov  dx,4A10h                       ;Coin inf. droit fenˆtre 2
          call clear                                    ;Vider fenˆtre 2
          mov  bx,0508h                      ;Coin sup. gauche fenˆtre 1
          call calo                       ;Convertir en adresse d'offset
          mov  si,offset str3                 ;Adresse d'offset chaŒne 3
          mov  ah,70h                     ;Ecriture noire sur fond blanc
          call print                                    ;Sortir chaŒne 3
          mov  bx,3C02h                      ;Coin sup. gauche fenˆtre 2
          call calo                       ;Convertir en adresse d'offset
          mov  si,offset str4                 ;Adresse d'offset chaŒne 4
          call print                                    ;Sortir chaŒne 4
          xor  di,di                   ;Coin sup‚rieur gauche de l'‚cran
          mov  si,offset str5                 ;Adresse d'offset chaŒne 5
          call print                                    ;Sortir chaŒne 5

;-- Sortir logo du programme -------------------------------------------
          mov  bx,1E0Ch                            ;Colonne 30, ligne 12
          call calo                       ;Convertir en adresse d'offset
          mov  si,offset str2                 ;Adresse d'offset chaŒne 2
          mov  ah,0F0h                           ;Clignoter en inversion
          call print                                    ;Sortir chaŒne 2

;-- Remplir les fenˆtres de flŠches ------------------------------------
          xor  ch,ch                       ;Octet fort du compteur sur 0
fleche:   mov  bl,1                                          ;Une ‚toile
fleche0:  push bx                                 ;Ranger BX sur la pile
          mov  di,offset str3      ;Ecrire ligne de flŠche dans chaŒne 3
          mov  cl,15                ;15 caractŠres en tout sur une ligne
          sub  cl,bl                          ;Calculer nombre d'espaces
          shr  cl,1                  ;Diviser par 2 (Pour moiti‚ gauche)
          or   cl,cl                                     ;Pas d'espace ?
          je   fleche1                                  ;OUI --> FLECHE1
          mov  al," "
          rep  stosb                        ;Ecrire espace dans chaŒne 3
fleche1:  mov  cl,bl                  ;Nombre d'‚toiles dans le compteur
          mov  al,"*"
          rep  stosb                        ;Ecrire ‚toile dans chaŒne 3
          mov  cl,15                ;15 caractŠres en tout sur une ligne
          sub  cl,bl                          ;Calculer nombre d'espaces
          shr  cl,1                  ;Diviser par 2 (pour moiti‚ droite)
          or   cl,cl                                     ;Pas d'espace ?
          je   fleche2                                  ;OUI --> FLECHE2
          mov  al," "
          rep  stosb                        ;Ecrire espace dans chaŒne 3
fleche2:  mov  bx,0509h                ;Sous premiŠre ligne de fenˆtre 1
          call calo                       ;Convertir en adresse d'offset
          mov  si,offset str3                 ;Adresse d'offset chaŒne 3
          mov  ah,07h                    ;Ecriture blanche sur fond noir
          call print                                    ;Sortir chaŒne 3
          mov  bx,3C10h              ;Dans ligne inf‚rieure de fenˆtre 2
          call calo                       ;Convertir en adresse d'offset
          call print                                    ;Sortir chaŒne 3

;-- Faire une petite pause ---------------------------------------------
          mov  cx,DELAY                 ;Charger dans compteur de boucle
attendre: loop attendre                        ;Compteur de boucle sur 0

;-- Scrolling de fenˆtre 1 d'une ligne vers le bas ---------------------
          mov  bx,0509h                      ;Coin sup. gauche fenˆtre 1
          mov  dx,1316h                       ;Coin inf. droit fenˆtre 1
          mov  cl,1                                           ;Une ligne
          call scrolldn                       ;de d‚filement vers le bas

;-- Scrolling de fenˆtre 2 d'une ligne vers le haut --------------------
          mov  bx,3C03h                      ;Coin sup. gauche fenˆtre 2
          mov  dx,4A10h                       ;Coin inf. droit fenˆtre 2
          call scrollup                         ;D‚filement vers le haut

;-- Une touche a-t-elle ‚t‚ actionn‚e ? (terminer le programme)

          mov  ah,1                      ;Nø fonction pour Tester touche
          int  16h                 ;Appeler interruption clavier du BIOS
          jne  end_it             ;Touche actionn‚e --> Pr‚parer fin prg

;-- NON, sortir ligne de flŠches suivante ------------------------------
          pop  bx                                 ;Retirer BX de la pile
          add  bl,2               ;2 ‚toiles de plus dans ligne suivante
          cmp  bl,17                                       ;17 atteint ?
          jne  fleche0                          ;NON --> flŠche suivante
          jmp  fleche                            ;OUI --> nouvelle ligne

;-- Pr‚parer fin du programme ------------------------------------------
end_it:   xor  ah,ah                ;Num‚ro de fonction pour Lire touche
          int  16h                 ;Appeler interruption clavier du BIOS

          mov  cx,0D0Ch                         ;R‚tablir curseur normal
          call cdef
          call cls                                        ;Vider l'‚cran
          jmp  fin                         ;Sauter … la fin du programme

demo      endp

;== Viennent maintenant les fonctions proprement dites =================

;-- SOUT: D‚sactive l'affichage ‚cran ----------------------------------
;-- Entr‚e   : Aucune
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s

sout      proc near

          mov  dx,REG_CONTR  ;Adresse du registre de commande de l'‚cran
          in   al,dx                                 ;En lire le contenu
          and  al,11110111b                 ;Bit 3 = 0 : Ecran d‚sactiv‚
          out  dx,al            ;Fixer nouvelle valeur (Ecran d‚sactiv‚)

          ret                               ;Retour au programme d'appel

sout      endp

;-- SON: Active l'affichage ‚cran --------------------------------------
;-- Entr‚e   : Aucune
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s

son       proc near

          mov  dx,REG_CONTR     ;Adresse du registre de commande d'‚cran
          in   al,dx                                 ;En lire le contenu
          or   al,8                            ;Bit 3 = 1 : Ecran activ‚
          out  dx,al               ;Fixer nouvelle valeur (Ecran activ‚)
          ret                               ;Retour au programme d'appel

son       endp

;-- CDEF: Fixe les lignes de d‚part et de fin du curseur ---------------
;-- Entr‚e   : CL = ligne de d‚part
;--            CH = ligne de fin
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s

cdef      proc near

          mov  al,CUR_START                  ;Registre : ligne de d‚part
          mov  ah,cl                            ;Ligne de d‚part dans AH
          call setvc                    ;Communiquer au contr“leur vid‚o
          mov  al,CUR_END                       ;Registre : ligne de fin
          mov  ah,ch                               ;Ligne de fin dans AH
          jmp  short setvc              ;Communiquer au contr“leur vid‚o
cdef      endp

;-- SETBLINK: fixe le curseur clignotant de l'‚cran --------------------
;-- Entr‚e   : DI = Adresse d'offset du curseur(en unit‚s de caractŠres)
;-- Sortie   : Aucune
;-- Registres: BX, AX et DX sont modifi‚s

setclign  proc near

          mov  bx,di                          ;Transf‚rer offset dans BX
          mov  al,CURPOS_HI     ;Registre : octet fort offset du curseur
          mov  ah,bh                             ;Octet fort de l'offset
          call setvc                    ;Communiquer au contr“leur vid‚o
          mov  al,CURPOS_LO   ;Registre : octet faible offset du curseur
          mov  ah,bl                           ;Octet faible de l'offset

;-- Le passage … SETVC se fait automatiquement -------------------------
setclign  endp

;-- SETVC: fixe un octet dans l'un des registres du contr“leur vid‚o ---
;-- Entr‚e   : AL = Num‚ro du registre
;--            AH = Nouveau contenu du registre
;-- Sortie   : Aucune
;-- Registres: DX et AL sont modifi‚s

setvc     proc near

          mov  dx,ADRESS_6845               ;Adresse du registre d'index
          out  dx,al                         ;Envoyer num‚ro du registre
          jmp  short $+2                               ;Petite pause I/O
          inc  dx                           ;Adresse du registre d'index
          mov  al,ah                                    ;Contenu dans AL
          out  dx,al                              ;Fixer nouveau contenu
          ret                               ;Retour au programme d'appel

setvc     endp

;-- GETVC: lit un octet dans l'un des registres du contr“leur vid‚o ----
;-- Entr‚e   : AL = Num‚ro du registre
;-- Sortie   : AL = Contenu du registre
;-- Registres: DX et AL sont modifi‚s

getvc     proc near

          mov  dx,ADRESS_6845               ;Adresse du registre d'index
          out  dx,al                         ;Envoyer num‚ro du registre
          jmp  short $+2                   ;Petite pause d'entr‚e/sortie
          inc  dx                           ;Adresse du registre d'index
          in   al,dx                         ;Transf‚rer contenu dans AL
          ret                               ;Retour au programme d'appel

getvc     endp

;-- SCROLLUP: fait d‚filer une fenˆtre de N lignes vers le haut --------
;-- Entr‚e   : BL = ligne haut … gauche
;--            BH = colonne haut … gauche
;--            DL = ligne bas … droite
;--            DH = colonne bas … droite
;--            CL = nombre de lignes de d‚filement
;-- Sortie   : Aucune
;-- Registres: seuls les FLAGS sont modifi‚s
;-- Infos    : les lignes de l'‚cran lib‚r‚es sont vid‚es

scrollup  proc near

          cld                  ;Augmenter comptage pour instr. de chaŒne

          push ax                    ;Sauver tous les registres modifi‚s
          push bx                                           ;sur la pile
          push di                              ;Dans ce cas l'ordre doit
          push si                                       ;ˆtre respect‚ !
          push bx                   ;Ces trois registres sont retir‚s de
          push cx                          ;la pile avant mˆme la fin de
          push dx                                            ;la routine
          sub  dl,bl                          ;Calculer nombre de lignes
          inc  dl
          sub  dl,cl          ;Retrancher nombre de lignes de d‚filement
          sub  dh,bh                           ;Calculer nombre colonnes
          inc  dh
          call calo                   ;Convertir haut … gauche en offset
          mov  si,di                             ;Ranger adresse dans SI
          add  bl,cl                ;PremiŠre ligne dans fenˆtre d‚cal‚e
          call calo                  ;Convertir premiŠre ligne en offset
          xchg si,di                                  ;Echanger SI et DI
          push ds                       ;Registre de segment sur la pile
          push es                                                ;sauver
          mov  ax,VIO_SEG            ;Adresse de segment de la RAM vid‚o
          mov  ds,ax                                            ;dans DS
          mov  es,ax                                       ;et amener ES
sup1:     mov  ax,di                                  ;Ranger DI dans AX
          mov  bx,si                                  ;Ranger SI dans BX
          mov  cl,dh                ;Nombre de colonnes dans le compteur
          rep movsw                                   ;D‚caler une ligne
          mov  di,ax                                   ;Retirer DI de AX
          mov  si,bx                                   ;Retirer SI de BX
          add  di,160              ;Fixer chaque fois sur ligne suivante
          add  si,160
          dec  dl                          ;Toutes les lignes trait‚es ?
          jne  sup1                    ;NON --> d‚caler encore une ligne
          pop  es                ;Retirer … nouveau registres de segment
          pop  ds                                            ;de la pile
          pop  dx                               ;Retirer coin inf. droit
          pop  cx                              ;Retirer nombre de lignes
          pop  bx                              ;Retirer coin sup. gauche
          mov  bl,dl                           ;Ligne inf‚rieure dans BL
          sub  bl,cl                        ;Retrancher nombre de lignes
          inc  bl
          mov  ah,07h                          ;Couleur : noir sur blanc
          call clear                              ;Vider lignes lib‚r‚es

          pop  si                                 ;CX et DX ont d‚j… ‚t‚
          pop  di                                               ;ramen‚s
          pop  bx
          pop  ax

          ret                               ;Retour au programme d'appel

scrollup  endp

;-- SCROLLDN: fait d‚filer une fenˆtre de N lignes vers le bas ---------
;-- Entr‚e   : BL = ligne haut … gauche
;--            BH = colonne haut … gauche
;--            DL = ligne bas … droite
;--            DH = colonne bas … droite
;--            CL = nombre de lignes de d‚filement
;-- Sortie   : Aucune
;-- Registres: seuls les FLAGS sont modifi‚s
;-- Infos    : les lignes de l'‚cran lib‚r‚es sont vid‚es

scrolldn  proc near

          cld                     ;Augmenter comptage pour instr. chaŒne

          push ax                    ;Sauver tous les registres modifi‚s
          push bx                                           ;sur la pile
          push di                              ;Dans ce cas l'ordre doit
          push si                                       ;ˆtre respect‚ !

          push bx                   ;Ces trois registres sont retir‚s de
          push cx                          ;la pile avant mˆme la fin de
          push dx                                            ;la routine

          sub  dh,bh                           ;Calculer nombre colonnes
          inc  dh
          mov  al,bl                 ;Ranger ligne haut … gauche dans AL
          mov  bl,dl                         ;Ligne i.d. dans ligne i.g.
          call calo                   ;Convertir haut … gauche en offset
          mov  si,di                             ;Ranger adresse dans SI
          sub  bl,cl              ;Retrancher nombre de l. de d‚filement
          call calo                   ;Convertir haut … gauche en offset
          xchg si,di                                  ;Echanger SI et DI
          sub  dl,al                          ;Calculer nombre de lignes
          inc  dl
          sub  dl,cl          ;Retrancher nombre de lignes de d‚filement
          push ds                           ;Sauver registres de segment
          push es                                           ;sur la pile
          mov  ax,VIO_SEG            ;Adresse de segment de la RAM vid‚o
          mov  ds,ax                                            ;dans DS
          mov  es,ax                                       ;et amener ES
sdn1:     mov  ax,di                                  ;Ranger DI dans AX
          mov  bx,si                                  ;Ranger SI dans BX
          mov  cl,dh                ;Nombre de colonnes dans le compteur
          rep movsw                                   ;D‚caler une ligne
          mov  di,ax                                   ;Retirer DI de AX
          mov  si,bx                                   ;Retirer SI de BX
          sub  di,160              ;Fixer chaque fois sur ligne suivante
          sub  si,160
          dec  dl                          ;Toutes les lignes trait‚es ?
          jne  sdn1                    ;NON --> d‚caler encore une ligne
          pop  es                ;Retirer … nouveau registres de segment
          pop  ds                                            ;de la pile
          pop  dx                               ;Retirer coin inf. droit
          pop  cx                              ;Retirer nombre de lignes
          pop  bx                              ;Retirer coin sup. gauche
          mov  dl,bl                           ;Ligne sup‚rieure dans DL
          add  dl,cl                          ;Additionner nombre lignes
          dec  dl
          mov  ah,07h                          ;Couleur : noir sur blanc
          call clear                              ;Vider lignes lib‚r‚es
          pop  si                                 ;CX et DX ont d‚j… ‚t‚
          pop  di                                               ;ramen‚s
          pop  bx
          pop  ax

          ret                               ;Retour au programme d'appel

scrolldn  endp

;-- CLS: Vider l'‚cran tout entier -------------------------------------
;-- Entr‚e   : Aucune
;-- Sortie   : Aucune
;-- Registres: seuls les FLAGS sont modifi‚s

cls       proc near

          mov  ah,07h                        ;Couleur est blanc sur noir
          xor  bx,bx                            ;Haut … gauche est (0/0)
          mov  dx,4F18h                        ;Bas … droite est (79/24)

;-- Le passage … Clear se fait automatiquement -------------------------

cls       endp

;-- CLEAR: remplit d'espaces une zone d'‚cran d‚termin‚e ---------------
;-- Entr‚e   : AH = attribut/couleur
;--            BL = ligne haut … gauche
;--            BH = colonne haut … gauche
;--            DL = ligne bas … droite
;--            DH = colonne bas … droite
;-- Sortie   : Aucune
;-- Registres: seuls les FLAGS sont modifi‚s

clear     proc near
          cld                  ;Augmenter comptage pour instr. de chaŒne
          push cx                 ;Sauver sur la pile tous les registres
          push dx                      ;qui seront modifi‚s par la suite
          push si
          push di
          push es
          sub  dl,bl                          ;Calculer nombre de lignes
          inc  dl
          sub  dh,bh                           ;Calculer nombre colonnes
          inc  dh
          call calo                 ;Adresse d'offset du coin sup gauche
          mov  cx,VIO_SEG            ;Adresse de segment de la RAM vid‚o
          mov  es,cx                                            ;dans ES
          xor  ch,ch                       ;Octet fort du compteur sur 0
          mov  al," "                                            ;Espace
clear1:   mov  si,di                                  ;Ranger DI dans SI
          mov  cl,dh                ;Nombre de colonnes dans le compteur
          rep stosw                                       ;Sauver espace
          mov  di,si                                   ;Retirer DI de SI
          add  di,160                         ;Fixer dans ligne suivante
          dec  dl                          ;Toutes les lignes trait‚es ?
          jne  clear1                    ;NON --> vider encore une ligne
          pop  es                      ;Retirer de la pile les registres
          pop  di                                           ;sauvegard‚s
          pop  si
          pop  dx
          pop  cx
          ret                               ;Retour au programme d'appel

clear     endp

;-- PRINT: sort une chaŒne sur l'‚cran ---------------------------------
;-- Entr‚e   : AH = Attribut/couleur
;--            DI = Adresse d'offset du premier caractŠre
;--            SI = Adresse d'offset de la chaŒne par rapport … DS
;-- Sortie   : DI d‚signe position aprŠs dernier caractŠre sorti
;-- Registres: AL, DI et FLAGS sont modifi‚s
;-- Infos    : La chaŒne doit ˆtre termin‚e par le caractŠre NUL.
;--            Les autres caractŠres de commande ne sont pas identifi‚s.

print     proc near

          cld                     ;Augmenter comptage pour instr. chaŒne
          push si                       ;Sauver SI, DX et ES sur la pile
          push es
          push dx
          mov  dx,VIO_SEG          ;Adr. de seg. de la RAM vid‚o d'abord
          mov  es,dx                               ;dans DX puis dans ES
          jmp  print1               ;Lire premier caractŠre de la chaŒne

print0:   stosw                      ;Attribut et couleur dans RAM vid‚o
print1:   lodsb                     ;Lire caractŠre suivant de la chaŒne
          or   al,al                                         ;Est-ce NUL
          jne  print0                                    ;NON --> Sortir

printe:   pop  dx                       ;Retirer SI, DX et ES de la pile
          pop  es
          pop  si
          ret                               ;Retour au programme d'appel

print     endp

;-- CALO: convertit ligne et colonne en adresse d'offset ---------------
;-- Entr‚e   : BL = ligne
;--            BH = colonne
;-- Sortie   : DI = l'adresse d'offset
;-- Registres: DI et FLAGS sont modifi‚s

calo      proc near

          push ax                                 ;Sauver AX sur la pile
          push bx                                 ;Sauver BX sur la pile

          shl  bx,1                             ;Colonne et ligne fois 2
          mov  al,bh                                    ;Colonne dans AL
          xor  bh,bh                                         ;Octet fort
          mov  di,[lignes+bx]            ;Lire adresse d'offset de ligne
          xor  ah,ah                     ;Octet fort pour offset colonne
          add  di,ax                ;Additionner offset ligne et colonne

          pop  bx                                 ;Retirer BX de la pile
          pop  ax                                 ;Retirer AX de la pile
          ret                               ;Retour au programme d'appel

calo      endp

;== Fin ===============================================================

code      ends                                   ;Fin du segment de CODE
          end  demo           ;Commencer ex‚cution du programme par DEMO
