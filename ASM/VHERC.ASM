;**********************************************************************;
;*                            V H E R C                               *;
;*--------------------------------------------------------------------*;
;*    Fonction       : fournit quelques fonctions de base pour        *;
;*                     l'accŠs … la HERCULES GRAPHICS CARD            *;
;*--------------------------------------------------------------------*;
;*    Infos          : Toutes les fonctions divisent l'‚cran en       *;
;*                     colonnes 0 … 79 et lignes 0 … 24               *;
;*                     en mode de texte et en colonnes 0 … 719 et     *;
;*                     lignes 0 … 347 en mode graphique               *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    d‚velopp‚ le   : 11/08/1987                                     *;
;*    DerniŠre modif.:  1/05/1989                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM VHERC;                                    *;
;*                     LINK VHERC;                                    *;
;*--------------------------------------------------------------------*;
;*    Appel          : VHERC                                          *;
;**********************************************************************;

;== Constantes =========================================================

REG_CONTR   = 03B8h                ;Adr. de port du registre de contr“le
ADRESS_6845 = 03B4h                          ;Registre d'adresse du 6845
DATA_6845   = 03B5h                         ;Registre de donn‚es du 6845
REG_CONFIG  = 03BFh                           ;Registre de configuration
VIO_SEG     = 0B000h                 ;Adresse de segment de la RAM vid‚o
CUR_START   = 10           ;Nø registre CRTC: ligne de d‚part du curseur
CUR_END     = 11              ;Nø registre CRTC: ligne de fin du curseur
CURPOS_HI   = 14              ;Nø registre CRTC: octet fort pos. curseur
CURPOS_LO   = 15            ;Nø registre CRTC: octet faible pos. curseur

DELAY       = 20000            ;Compteur de boucle pour boucle d'attente

;== Macros =============================================================

setmode   macro modus                        ;Fixer registre de contr“le

      mov  dx,REG_CONTR           ;Adresse du registre de commande ‚cran
      mov  al,modus                    ;Nouveau mode dans le registre AL
      out  dx,al                   ;Envoyer mode au registre de commande

      endm

setvc     macro                          ;Ecrit une valeur dans l'un des
                                                         ;registres CRTC
                                       ;Entr‚e : AL = num‚ro de registre
                                  ;         AH = valeur pour le registre

      mov  dx,ADRESS_6845                   ;Adresse du registre d'index
      out  dx,ax                  ;Sortir nø registre et nouvelle valeur

      endm

;== Pile ===============================================================

stack     segment para stack              ;D‚finition du segment de pile

      dw 256 dup (?)                   ;La pile a une taille de 256 mots

stack     ends                                   ;Fin du segment de pile

;== Donn‚es ============================================================

data      segment para 'DATA'          ;D‚finition du segment de donn‚es

;== Les donn‚es pour le programme de d‚monstration =====================

initm     db 13,10,"VHERC (c) 1987, 1988 by Michael Tischer",13,10,13,10
      db "Ce programme de d‚monstration ne tourne qu'avec une"
      db " carte graphique",13,10,"HERCULES (HGC). Si votre PC"
      db " possŠde un autre type de carte ‚cran,",13,10
      db "veuillez entrer maintenant <s> pour arrˆter le programme"
      db ".",13,10,"Sinon veuillez actionner n'importe quelle autre"
      db " touche pour lancer le programme...",13,10,"$"

str1  db 1,17,16,2,7,0
str2  db 2,16,17,1,7,0

domes     db "Vous allez assister maintenant … une petite d‚monstration"
      db " graphique, suivie",13,10,"d'une d‚mo de texte. Ces "
      db "deux d‚monstrations peuvent ˆtre interrompues.",13,10
      db "en actionnant une touche. Veuillez actionner une touche"
      db " pour lancer le programme...",13,10,"$"

;== Table avec les adresses d'offset des d‚buts de ligne ==============
lignes dw  7*160, 8*160, 9*160,10*160,11*160,12*160,13*160
       dw 14*160,15*160,16*160,17*160,18*160,19*160,20*160
       dw 21*160,22*160,23*160,24*160

graphit   db 35h, 2Dh, 2Eh, 07h, 5Bh, 02h  ;Valeurs de registres pour le
      db 57h, 57h, 02h, 03h, 00h, 00h                    ;mode graphique

textt db 61h, 50h, 52h, 0Fh, 19h, 06h      ;Valeurs de registres pour le
      db 19h, 19h, 02h, 0Dh, 0Bh, 0Ch                    ;mode graphique

data  ends                                    ;Fin du segment de donn‚es

;== Code =============================================================

code  segment para 'CODE'                 ;D‚finition du segment de CODE

      assume cs:code, ds:data, es:data, ss:stack

;== Il s'agit simplement du programme de d‚monstration ===============

demo  proc far

      mov  ax,data                        ;Rechercher adr. de segment du
      mov  ds,ax                  ;segment de donn‚es et charger dans DS
      mov  es,ax                                      ;‚galement dans ES

             ;-- Sortir message Init et attendre entr‚e ----------------

      mov  ah,9                   ;Num‚ro de fonction pour Sortir chaŒne
      mov  dx,offset initm                           ;Adresse du message
      int  21h                              ;Appeler interruption du DOS

      xor  ah,ah                    ;Num‚ro de fonction pour Lire touche
      int  16h                     ;Appeler interruption clavier du BIOS
      cmp  al,"s"                                           ;<s> entr‚ ?
      je   fin                     ;OUI --> Terminer programme … nouveau
      cmp  al,"s"                                             ;<s> entr‚
      jne  startdemo                                ;NON --> Lancer d‚mo

fin:  mov  ax,4C00h                 ;Nø fonction pour Terminer programme
      int  21h                             ;Appeler interruption DOS 21h

          ;-- Programme de d‚monstration de l'appel des fonctions ------

startdemo label near
      mov  ah,9                   ;Num‚ro de fonction pour Sortir chaŒne
      mov  dx,offset domes                           ;Adresse du message
      int  21h                              ;Appeler interruption du DOS

      xor  ah,ah                    ;Num‚ro de fonction pour Lire touche
      int  16h                     ;Appeler interruption clavier du BIOS

             ;-- Initialiser mode graphique ----------------------------

      mov  al,11b                 ;Graphisme possible et incruster pag 2
      call config                                            ;Configurer
      xor  bp,bp                                 ;Acc‚der … page ‚cran 0
      call graphi                              ;Passer en mode graphique
      xor  al,al
      call cgr                                   ;Vider page graphique 0

             ;-- Construire dessin sur l'‚cran -------------------------

      xor  bx,bx                           ;Commencer par coin sup‚rieur
      xor  dx,dx                                      ;gauche de l'‚cran
      mov  ax,347                                  ;Points verticalement
      mov  cx,719                                ;Points horizontalement
gr1:  push cx                             ;Ranger points horizontalement
      mov  cx,ax                         ;Points vertical. dans compteur
      push ax                          ;Ranger points vertical. sur pile
gr2:  call spix                                             ;Fixer point
      inc  dx                                         ;Incr‚menter ligne
      loop gr2                                             ;Tracer ligne
      pop  ax                       ;Retirer points vertical. de la pile
      sub  ax,3                        ;Ligne suivante 3 points de moins
      pop  cx                     ;Retirer points horizontal. de la pile
      push cx                             ;Ranger points horizontalement
      push ax                          ;Ranger points vertical. sur pile
gr3:  call spix                                             ;Fixer point
      inc  bx                                       ;Incr‚menter colonne
      loop gr3                                             ;Tracer ligne
      pop  ax                       ;Retirer points vertical. de la pile
      pop  cx                     ;Retirer points horizontal. de la pile
      sub  cx,6                        ;Ligne suivante 6 points de moins
      push cx                             ;Ranger points horizontalement
      mov  cx,ax                         ;Points vertical. dans compteur
      push ax                          ;Ranger points vertical. sur pile
gr4:  call spix                                             ;Fixer point
      dec  dx                                         ;D‚cr‚menter ligne
      loop gr4                                             ;Tracer ligne
      pop  ax                       ;Retirer points vertical. de la pile
      sub  ax,3                        ;Ligne suivante 3 points de moins
      pop  cx                     ;Retirer points horizontal. de la pile
      push cx                             ;Ranger points horizontalement
      push ax                          ;Ranger points vertical. sur pile
gr5:  call spix                                             ;Fixer point
      dec  bx                                       ;Incr‚menter colonne
      loop gr5                                             ;Tracer ligne
      pop  ax                       ;Retirer points vertical. de la pile
      pop  cx                     ;Retirer points horizontal. de la pile
      sub  cx,6                        ;Ligne suivante 6 points de moins
      cmp  ax,5                            ;Ligne vertic. sup‚rieure … 5
      ja   gr1                                        ;OUI --> continuer

      xor  ah,ah                       ;Nø fonction pour Attendre touche
      int  16h                     ;Appeler interruption clavier du BIOS

              ;-- Initialiser mode de texte ----------------------------

      call text                                      ;Activer mode texte
      mov  cx,0d00h                               ;Activer curseur plein
      call cdef
      call cls                                            ;Vider l'‚cran

              ;-- Sortir chaŒnes dans la page ‚cran 0 ------------------

      xor  bx,bx                  ;Commencer dans coin sup. gauche ‚cran
      call calo                           ;Convertir en adresse d'offset
      mov  si,offset str1                  ;Adresse d'offset de chaŒne 1
      mov  cx,16*25                       ;ChaŒne longue de 5 caractŠres
demo1: call print                                         ;Sortir chaŒne
      loop demo1

             ;-- Sortir chaŒnes dans la page ‚cran 1 -------------------

      inc  bp                                      ;Traiter page ‚cran 1
      xor  bx,bx                  ;Commencer dans coin sup. gauche ‚cran
      call calo                           ;Convertir en adresse d'offset
      mov  si,offset str2                  ;Adresse d'offset de chaŒne 1
      mov  cx,16*25                       ;ChaŒne longue de 5 caractŠres
demo2: call print                                         ;Sortir chaŒne
      loop demo2

demo3:    setmode 10001000b                    ;Afficher page de texte 1

                 ;-- Petite pause --------------------------------------

      mov  cx,DELAY                          ;Charger compteur de boucle
pause: loop pause                                 ;Compter jusqu'… 65536

      setmode 00001000b                        ;Afficher page de texte 0

                 ;-- Petite pause --------------------------------------

        mov  cx,DELAY                        ;Charger compteur de boucle
pause1: loop pause1                               ;Compter jusqu'… 65536

      mov  ah,1                          ;Nø fonction pour Tester touche
      int  16h                     ;Appeler interruption clavier du BIOS
      je   demo3                      ;Pas de touche --> alors continuer

                  ;-- Pr‚parer fin du programme ------------------------

      xor  ah,ah                    ;Num‚ro de fonction pour Lire touche
      int  16h                     ;Appeler interruption clavier du BIOS

      mov  bp,0                                            ;Page ‚cran 1
      call cls                                            ;Vider l'‚cran
      mov  cx,0D0Ch                             ;R‚tablir curseur normal
      call cdef
      call cls                                            ;Vider l'‚cran
      jmp  fin                             ;Sauter … la fin du programme

demo       endp

;== Viennent maintenant les fonctions proprement dites =============

;-- CONFIG: configure la carte HERCULES ---------------------------
;-- Entr‚e   : AL : Bit 0 = 0 : Seul affichage texte possible
;--                         1 : Affichage graphique possible ‚galement
;--                 Bit 1 = 0 : RAM pour page ‚cran 2 d‚connect‚e
;--                         1 : RAM pour page ‚cran 2 connect‚e
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s

config    proc near

      mov  dx,REG_CONFIG           ;Adresse du registre de configuration
      out  dx,al                                  ;Fixer nouvelle valeur
      ret                                   ;Retour au programme d'appel

config    endp

;-- TEXT: Activer l'affichage de texte ---------------------------
;-- Entr‚e   : Aucune
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s

text      proc near

      mov  si,offset textt         ;Adresse offset de table de registres
      mov  bl,00100000b           ;Afficher page 0, mode texte, clignote
      jmp  short vcprog                   ;Reprogrammer contr“leur vid‚o

text      endp

;-- GRAPHSME: Activer l'affichage graphique --------------
;-- Entr‚e   : Aucune
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s

graphi    proc near

      mov  si,offset graphit       ;Adresse offset de table de registres
      mov  bl,00000010b                 ;Afficher page 0, mode graphique

graphi    endp

;-- VCPROG: programme le contr“leur vid‚o -------------------
;-- Entr‚e   : SI = Adresse d'une table de registres
;--            BL = Valeur pour registre de commande de l'‚cran
;-- Sortie   : Aucune
;-- Registres: AX, SI, BH, DX et FLAGS sont modifi‚s

vcprog    proc near

      setmode bl                            ;Bit 3 = 0 : Ecran d‚sactiv‚

      mov  cx,12                                ;12 registres sont fix‚s
      xor  bh,bh                            ;Commencer par le registre 0
vcp1: lodsb                          ;Lire valeur de registre dans table
      mov  ah,al                             ;Valeur de registre dans AH
      mov  al,bh                             ;Num‚ro de registre dans AL
      setvc                            ;Transmettre valeur au contr“leur
      inc  bh                                  ;Appeler registre suivant
      loop vcp1                                  ;Fixer autres registres

      or   bl,8                                ;Bit 3 = 1 : Ecran activ‚
      setmode bl                                     ;Fixer nouveau mode
      ret                                   ;Retour au programme d'appel

vcprog    endp

;-- CDEF: Fixe les lignes de d‚part et de fin du curseur --------
;-- Entr‚e   : CL = ligne de d‚part
;--            CH = ligne de fin
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s

cdef      proc near

      mov  al,CUR_START                      ;Registre : ligne de d‚part
      mov  ah,cl                                ;Ligne de d‚part dans AH
      setvc                             ;Communiquer au contr“leur vid‚o
      mov  al,CUR_END                           ;Registre : ligne de fin
      mov  ah,ch                                   ;Ligne de fin dans AH
      setvc                             ;Communiquer au contr“leur vid‚o
      ret

cdef      endp

;-- SETBLINK: fixe le curseur clignotant de l'‚cran -------------
;-- Entr‚e   : DI = Adresse d'offset du curseur
;-- Sortie   : Aucune
;-- Registres: BX, AX et DX sont modifi‚s

setclign  proc near

      mov  bx,di                              ;Transf‚rer offset dans BX
      mov  al,CURPOS_HI           ;Reg. : octet fort d'offset du curseur
      mov  ah,bh                                 ;Octet fort de l'offset
      setvc                             ;Communiquer au contr“leur vid‚o
      mov  al,CURPOS_LO           ;Reg. : octet faible offset du curseur
      mov  ah,bl                               ;Octet faible de l'offset
      setvc                                         ;Transmettre au CRTC
      ret

setclign  endp

;-- GETVC: lit un octet dans l'un des registres du contr“leur vid‚o ----
;-- Entr‚e   : AL = Num‚ro du registre
;-- Sortie   : AL = Contenu du registre
;-- Registres: DX et AL sont modifi‚s

getvc     proc near

      mov  dx,ADRESS_6845                   ;Adresse du registre d'index
      out  dx,al                             ;Envoyer num‚ro du registre
      jmp  $+2                             ;Petite pause d'entr‚e/sortie
      inc  dx                               ;Adresse du registre d'index
      in   al,dx                             ;Transf‚rer contenu dans AL
      ret                                   ;Retour au programme d'appel

getvc     endp

;-- SCROLLUP: fait d‚filer une fenˆtre de N lignes vers le haut -----
;-- Entr‚e   : BL = ligne haut … gauche
;--            BH = colonne haut … gauche
;--            DL = ligne bas … droite
;--            DH = colonne bas … droite
;--            CL = nombre de lignes de d‚filement
;--          : BP = Num‚ro de la page ‚cran (0 ou 1)
;-- Sortie   : Aucune
;-- Registres: seuls les FLAGS sont modifi‚s
;-- Infos    : les lignes de l'‚cran lib‚r‚es sont vid‚es

scrollup  proc near

      cld                         ;Augmenter comptage pour instr. chaŒne

      push ax                        ;Sauver tous les registres modifi‚s
      push bx                                               ;sur la pile
      push di                                 ;Dans ce cas, l'ordre doit
      push si                                           ;ˆtre respect‚ !

      push bx                       ;Ces trois registres sont retir‚s de
      push cx                              ;la pile avant mˆme la fin de
      push dx                                                ;la routine
      sub  dl,bl                              ;Calculer nombre de lignes
      inc  dl
      sub  dl,cl                   ;Retrancher nombre de lignes de d‚fil
      sub  dh,bh                               ;Calculer nombre colonnes
      inc  dh
      call calo                       ;Convertir haut … gauche en offset
      mov  si,di                                 ;Ranger adresse dans SI
      add  bl,cl                    ;PremiŠre ligne dans fenˆtre d‚cal‚e
      call calo                      ;Convertir premiŠre ligne en offset
      xchg si,di                                      ;Echanger SI et DI
      push ds                                ;Sauver registre de segment
      push es                                               ;sur la pile
      mov  ax,VIO_SEG                ;Adresse de segment de la RAM vid‚o
      mov  ds,ax                                                ;dans DS
      mov  es,ax                                           ;et amener ES
sup1: mov  ax,di                                      ;Ranger DI dans AX
      mov  bx,si                                      ;Ranger SI dans BX
      mov  cl,dh                    ;Nombre de colonnes dans le compteur
      rep movsw                                       ;D‚caler une ligne
      mov  di,ax                                       ;Retirer DI de AX
      mov  si,bx                                       ;Retirer SI de BX
      add  di,160                  ;Fixer chaque fois sur ligne suivante
      add  si,160
      dec  dl                              ;Toutes les lignes trait‚es ?
      jne  sup1                        ;NON --> d‚caler encore une ligne
      pop  es                         ;Retirer … nouveau reg. de segment
      pop  ds                                                ;de la pile
      pop  dx                                   ;Retirer coin inf. droit
      pop  cx                                  ;Retirer nombre de lignes
      pop  bx                                  ;Retirer coin sup. gauche
      mov  bl,dl                               ;Ligne inf‚rieure dans BL
      sub  bl,cl                            ;Retrancher nombre de lignes
      inc  bl
      mov  ah,07h                              ;Couleur : noir sur blanc
      call clear                                  ;Vider lignes lib‚r‚es

      pop  si                                     ;CX et DX ont d‚j… ‚t‚
      pop  di                                                   ;ramen‚s
      pop  bx
      pop  ax

      ret                                   ;Retour au programme d'appel

scrollup  endp

;-- SCROLLDN: fait d‚filer une fenˆtre de N lignes vers le bas ------
;-- Entr‚e   : BL = ligne haut … gauche
;--            BH = colonne haut … gauche
;--            DL = ligne bas … droite
;--            DH = colonne bas … droite
;--            CL = nombre de lignes de d‚filement
;--          : BP = Num‚ro de la page ‚cran (0 ou 1)
;-- Sortie   : Aucune
;-- Registres: seuls les FLAGS sont modifi‚s
;-- Infos    : les lignes de l'‚cran lib‚r‚es sont vid‚es

scrolldn  proc near

      cld                         ;Augmenter comptage pour instr. chaŒne

      push ax                        ;Sauver tous les registres modifi‚s
      push bx                                               ;sur la pile
      push di                                 ;Dans ce cas, l'ordre doit
      push si                                           ;ˆtre respect‚ !

      push bx                       ;Ces trois registres sont retir‚s de
      push cx                              ;la pile avant mˆme la fin de
      push dx                                                ;la routine

      sub  dh,bh                               ;Calculer nombre colonnes
      inc  dh
      mov  al,bl                     ;Ranger ligne haut … gauche dans AL
      mov  bl,dl                             ;Ligne i.d. dans ligne i.g.
      call calo                       ;Convertir haut … gauche en offset
      mov  si,di                                 ;Ranger adresse dans SI
      sub  bl,cl                  ;Retrancher nombre de l. de d‚filement
      call calo                       ;Convertir haut … gauche en offset
      xchg si,di                                      ;Echanger SI et DI
      sub  dl,al                              ;Calculer nombre de lignes
      inc  dl
      sub  dl,cl                  ;Retrancher nombre de lignes de d‚fil.
      push ds                                ;Sauver registre de segment
      push es                                               ;sur la pile
      mov  ax,VIO_SEG                ;Adresse de segment de la RAM vid‚o
      mov  ds,ax                                                ;dans DS
      mov  es,ax                                           ;et amener ES
sdn1: mov  ax,di                                      ;Ranger DI dans AX
      mov  bx,si                                      ;Ranger SI dans BX
      mov  cl,dh                    ;Nombre de colonnes dans le compteur
      rep movsw                                       ;D‚caler une ligne
      mov  di,ax                                       ;Retirer DI de AX
      mov  si,bx                                       ;Retirer SI de BX
      sub  di,160                  ;Fixer chaque fois sur ligne suivante
      sub  si,160
      dec  dl                              ;Toutes les lignes trait‚es ?
      jne  sdn1                        ;NON --> d‚caler encore une ligne
      pop  es                     ;Retirer … nouveau registre de segment
      pop  ds                                                ;de la pile
      pop  dx                                   ;Retirer coin inf. droit
      pop  cx                                  ;Retirer nombre de lignes
      pop  bx                                  ;Retirer coin sup. gauche
      mov  dl,bl                               ;Ligne sup‚rieure dans DL
      add  dl,cl                           ;Additionner nombre de lignes
      dec  dl
      mov  ah,07h                              ;Couleur : noir sur blanc
      call clear                                  ;Vider lignes lib‚r‚es

      pop  si                                     ;CX et DX ont d‚j… ‚t‚
      pop  di                                                   ;ramen‚s
      pop  bx
      pop  ax

      ret                                   ;Retour au programme d'appel

scrolldn  endp

;-- CLS: Vider l'‚cran tout entier -------------------------
;-- Entr‚e   : BP = Num‚ro de la page ‚cran (0 ou 1)
;-- Sortie   : Aucune
;-- Registres: seuls les FLAGS sont modifi‚s

cls       proc near

      mov  ah,07h                            ;Couleur est blanc sur noir
      xor  bx,bx                                ;haut … gauche est (0/0)
      mov  dx,4F18h                            ;bas … droite est (79/24)

             ;-- Le passage … Clear se fait automatiquement ------------

cls       endp

;-- CLEAR: remplit d'espaces une zone d'‚cran d‚termin‚e ------------
;-- Entr‚e   : AH = attribut/couleur
;--            BL = ligne haut … gauche
;--            BH = colonne haut … gauche
;--            DL = ligne bas … droite
;--            DH = colonne bas … droite
;--            BP = Num‚ro de la page ‚cran (0 ou 1)
;-- Sortie   : Aucune
;-- Registres: seuls les FLAGS sont modifi‚s

clear     proc near

      cld                         ;Augmenter comptage pour instr. chaŒne
      push cx                        ;Tous les registres modifi‚s par la
      push dx                     ;suite doivent ˆtre sauv‚s sur la pile
      push si
      push di
      push es
      sub  dl,bl                              ;Calculer nombre de lignes
      inc  dl
      sub  dh,bh                               ;Calculer nombre colonnes
      inc  dh
      call calo                    ;Adresse d'offset du coin sup. gauche
      mov  cx,VIO_SEG                ;Adresse de segment de la RAM vid‚o
      mov  es,cx                                                ;dans ES
      xor  ch,ch                           ;Octet fort du compteur sur 0
      mov  al," "                                                ;Espace
clear1: mov  si,di                                    ;Ranger DI dans SI
      mov  cl,dh                    ;Nombre de colonnes dans le compteur
      rep stosw                                           ;Sauver espace
      mov  di,si                                       ;Retirer DI de SI
      add  di,160                             ;Fixer dans ligne suivante
      dec  dl                              ;Toutes les lignes trait‚es ?
      jne  clear1                        ;NON --> vider encore une ligne

      pop  es                          ;Retirer de la pile les registres
      pop  di                                               ;sauvegard‚s
      pop  si
      pop  dx
      pop  cx
      ret                                   ;Retour au programme d'appel

clear     endp

;-- PRINT: sort une chaŒne sur l'‚cran -----------------------
;-- Entr‚e   : AH = Attribut/couleur
;--            DI = Adresse d'offset du premier caractŠre
;--            SI = Adresse d'offset de la chaŒne par rapport … DS
;--            BP = Num‚ro de la page ‚cran (0 ou 1)
;-- Sortie   : DI d‚signe position aprŠs dernier caractŠre sorti
;-- Registres: AL, DI et FLAGS sont modifi‚s
;-- Infos    : La chaŒne doit ˆtre termin‚e par le caractŠre NUL.
;--            Les autres caractŠres de commande ne sont pas identifi‚s.

print     proc near

      cld                         ;Augmenter comptage pour instr. chaŒne
      push si                           ;Sauver SI, DX et ES sur la pile
      push es
      push dx
      mov  dx,VIO_SEG              ;Adresse de segment RAM vid‚o d'abord
      mov  es,dx                                   ;dans DX puis dans ES
      jmp  print1                   ;Lire premier caractŠre de la chaŒne

print0: stosw                 ;Sauver attribut et couleur dans RAM vid‚o
print1: lodsb                       ;Lire caractŠre suivant de la chaŒne
        or   al,al                                           ;Est-ce NUL
        jne  print0                                      ;NON --> Sortir

printe:   pop  dx                       ;Retirer SI, DX et ES de la pile
      pop  es
      pop  si
      ret                                   ;Retour au programme d'appel

print     endp

;-- CALO: convertit ligne et colonne en adresse d'offset ---------
;-- Entr‚e   : BL = ligne
;--            BH = colonne
;--            BP = Num‚ro de la page ‚cran (0 ou 1)
;-- Sortie   : DI = l'adresse d'offset
;-- Registres: DI et FLAGS sont modifi‚s

calo      proc near

      push ax                                     ;Sauver AX sur la pile
      push bx                                     ;Sauver BX sur la pile

      shl  bx,1                                 ;Colonne et ligne fois 2
      mov  al,bh                                        ;Colonne dans AL
      xor  bh,bh                                             ;Octet fort
      mov  di,[lignes+bx]                ;Lire adresse d'offset de ligne
      xor  ah,ah                         ;Octet fort pour offset colonne
      add  di,ax                    ;Additionner offset ligne et colonne
      or   bp,bp                                         ;Page ‚cran 0 ?
      je   caloe                               ;OUI --> adresse correcte

      add  di,8000h                 ;Additionner 32 Ko pour page ‚cran 1

caloe: pop  bx                                    ;Retirer BX de la pile
       pop  ax                                    ;Retirer AX de la pile
       ret                                  ;Retour au programme d'appel

calo      endp

;-- CGR: Vider int‚gralement ‚cran graphique -------------------
;-- Entr‚e   : BP = Num‚ro de la page ‚cran (0 ou 1)
;--            AL = 00(h) : Effacer tous les points
;--                 FF(h) : Fixer tous les points
;-- Sortie   : Aucune
;-- Registres: AH, BX, CX, DI et FLAGS sont modifi‚s

cgr   proc near
      push es                                     ;Sauver ES sur la pile
      cbw                                               ;Etendre AL … AH
      xor  di,di                        ;Adresse d'offset dans RAM vid‚o
      mov  bx,VIO_SEG                   ;Adresse de segment page ‚cran 0
      or   bp,bp                                         ;Vider page 1 ?
      je   cgr1                                    ;NON --> vider page 0

      add  bx,0800h                     ;Adresse de segment Page ‚cran 1

cgr1: mov  es,bx                    ;Adr de segment dans reg. de segment
      mov  cx,4000h                   ;Une page repr‚sente 16 Ko de mots
      rep stosw                                            ;Remplir page
      pop  es                                     ;Retirer ES de la pile
      ret                                   ;Retour au programme d'appel

cgr   endp

;-- SPIX: fixe un point sur l'‚cran graphique ----------------------
;-- Entr‚e   : BP = Num‚ro de la page ‚cran (0 ou 1)
;--            BX = Colonne (0 … 719)
;--            DX = Ligne (0 … 347)
;-- Sortie   : Aucune
;-- Registres: AX, DI et FLAGS sont modifi‚s

spix  proc near

      push es                                     ;Sauver ES sur la pile
      push bx                                     ;Sauver BX sur la pile
      push cx                                     ;Sauver CX sur la pile
      push dx                                     ;Sauver DX sur la pile

      xor  di,di                        ;Adresse d'offset dans RAM vid‚o
      mov  cx,VIO_SEG                   ;Adresse de segment page ‚cran 0
      or   bp,bp                                     ;Acc‚der … page 1 ?
      je   spix1                               ;NON --> acc‚der … page 0

      add  cx,0800h                     ;Adresse de segment Page ‚cran 1

spix1: mov  es,cx                  ;Adr. de segment dans reg. de segment
      mov  ax,dx                                   ;Amener ligne dans AX
      shr  ax,1                      ;D‚caler ligne 2 fois sur la droite
      shr  ax,1                          ;ce qui revient … diviser par 4
      mov  cl,90                                      ;Le facteur est 90
      mul  cl                                   ;Multiplier ligne par 90
      and  dx,11b                ;Masquer tous les bits sauf bits 0 et 1
      mov  cl,3                                             ;3 d‚calages
      ror  dx,cl                     ;Rotation par la droite (* 2000(h))
      mov  di,bx                                        ;Colonne dans DI
      mov  cl,3                                             ;3 d‚calages
      shr  di,cl                                          ;Diviser par 8
      add  di,ax                                    ;+ 90 * int(Ligne/4)
      add  di,dx                              ;+ 2000(h) * (Ligne mod 4)
      mov  cl,7                                     ;7 d‚calages maximum
      and  bx,7                                           ;Colonne mod 8
      sub  cl,bl                                      ;7 - Colonne mod 8
      mov  ah,1                          ;D‚terminer valeur bit du point
      shl  ah,cl
      mov  al,es:[di]                                     ;Lire 8 points
      or   al,ah                                            ;Fixer point
      mov  es:[di],al                                 ;R‚‚crire 8 points

      pop  dx                                     ;Retirer DX de la pile
      pop  cx                                     ;Retirer CX de la pile
      pop  bx                                     ;Retirer BX de la pile
      pop  es                                     ;Retirer ES de la pile
      ret                                   ;Retour au programme d'appel

spix      endp

;== Fin =====================================================

code  ends                                       ;Fin du segment de CODE
      end  demo                   ;Commencer ex‚cution du prog. par DEMO
