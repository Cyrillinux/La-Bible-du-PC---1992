;**********************************************************************;
;*                              V C O L                               *;
;*--------------------------------------------------------------------*;
;*    Fonction       : fournit quelques fonctions de base pour        *;
;*                     accŠs … la carte ‚cran couleur.                *;
;*                                                                    *;
;*--------------------------------------------------------------------*;
;*    Infos          : Toutes les fonctions considŠrent que l'‚cran   *;
;*                     comporte 80 colonnes num‚rot‚es de 0 … 79 et   *;
;*                     25 lignes num‚rot‚es de 0 … 24 en mode texte,  *;
;*                     640 lignes num‚rot‚es de 0 … 639 et 200 lignes *;
;*                     num‚rot‚es de 0 … 199 en mode graphique        *;
;*                     Le mode texte en 40 colonnes n'est pas support‚*;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   : 13.08.87                                       *;
;*    DerniŠre MAJ   : 21.04.89                                       *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM VCOL;                                     *;
;*                     LINK VCOL;                                     *;
;*--------------------------------------------------------------------*;
;*    Appel          : VCOL                                           *;
;**********************************************************************;

;== Constantes =========================================================

REG_CONTR   = 03D8h                  ; Adr. port du registre de commande
REG_COUL    = 03D9h    ; Adr. port de registre de s‚lection des couleurs
ADRESS_6845 = 03D4h                         ; Registre d'adresse du 6845
DATA_6845   = 03D5h                        ; Registre de donn‚es du 6845
VIO_SEG     = 0B800h                     ; Segment de la m‚moire d'‚cran
CUR_START   = 10         ; Nø registre CRTC: ligne sup‚rieure du curseur
CUR_END     = 11         ; Nø registre CRTC: ligne inf‚rieure du curseur
PAGECOUR_HI = 12                    ; Octet fort de l'adresse de la page
PAGECOUR_LO = 13                  ; Octet faible de l'adresse de la page
CURPOS_HI   = 14             ; Nø registre CRTC: octet fort pos. curseur
CURPOS_LO   = 15           ; Nø registre CRTC: octet faible pos. curseur

DELAY       = 20000        ; Compteur d'it‚rations pour boucle d'attente


;-- SETMODE: Macro pour r‚gler le registre de commande de l'‚cran ------

setmode   macro mode

      mov  dx,REG_CONTR     ; Adresse du registre de commande de l'‚cran
      mov  al,mode                    ; Nouveau mode dans le registre AL
      out  dx,al                  ; Envoyer mode au registre de commande

          endm

;-- WAITRET: Attend que l'‚cran soit dessin‚ ---------------------------

waitret   macro
local     wr1                                              ; Label local

      mov  dx,3DAh               ; Adresse du registre d'‚tat de l'‚cran
wr1:  in   al,dx                                       ; Lit son contenu
      test al,8                                     ; Retrace vertical ?
      je   wr1                                        ; NON --> attendre

          endm

;== Pile ===============================================================

stack segment para stack                 ; D‚finition du segment de pile

      dw 256 dup (?)                         ; La pile comporte 256 mots

stack ends                                      ; Fin du segment de pile

;== Donn‚es ============================================================

data      segment para 'DATA'         ; D‚finition du segment de donn‚es

;-- Donn‚es pour le programme de d‚monstration -------------------------

initm   db 13,10
        db "ÛÛÛÛÛÛÛ VCOL (c) 1987,1988 by Michael Tischer ÛÛÛÛÛÛÛ"
        db 13,10,13,10
        db "Ce programme de d‚monstration ne fonctionne qu'avec  ",13,10
        db "une carte graphique CGA. Si votre PC est ‚quip‚ d'un ",13,10
        db "autre type de carte, tapez S pour sortir du programme",13,10
        db "sinon tapez une autre touche pour lancer le "
        db "programme",13,10,"$"

str1    db 1,0

;-- Table des offsets des d‚buts de ligne ------------------------------

lignes  dw  0*160, 1*160, 2*160, 3*160, 4*160, 5*160, 6*160
        dw  7*160, 8*160, 9*160,10*160,11*160,12*160,13*160
        dw 14*160,15*160,16*160,17*160,18*160,19*160,20*160
        dw 21*160,22*160,23*160,24*160

grafit  db 38h, 28h, 2Dh, 0Ah, 7Fh, 06h            ; Valeurs de registre
        db 64h, 70h, 02h, 01h, 06h, 07h      ; pour les modes graphiques

textt   db 71h, 50h, 5Ah, 0Ah, 1Fh, 06h            ; Valeurs de registre
        db 19h, 1Ch, 02h, 07h, 06h, 07h             ; pour le mode texte

attn    db 0                               ; TRUE (<>0) si l'utilisateur
                                               ; indique le paramŠtre /F

data      ends                               ; Fin du segment de donn‚es

;== Code ===============================================================

code  segment para 'CODE'                ; D‚finition du segment de code

      assume cs:code, ds:data, es:data, ss:stack


;-- Ceci est simplement le programme de d‚monstration-------------------


demo       proc far

      ;-- D‚tecte le paramŠtre /F dans la ligne de commande ------------

      mov  cl,ds:128              ; Lit nombre d'octets dans l. de comm.
      or   cl,cl                                     ; Aucun paramŠtre ?
      je   switch1               ; OUI --> Evite l'exploitation des para
      mov  bx,129                ; BX pointe sur le premier octet de com
      mov  ch,bh                            ; Octet fort du compteur … 0

switch:
      cmp  [bx],"F/"                         ; Le paramŠtre est-il ici ?
      je   switch1                                  ; OUI--> On a trouv‚
      cmp  [bx],"f/"                          ; Se pr‚sente-t-il ainsi ?
      je   switch1                                  ; OUI--> On a trouv‚
      inc  bl                       ; BX pointe sur le caractŠre suivant
      loop switch                           ; Passe au caractŠre suivant

switch1:
      mov  ax,data                           ; Lit le segment de donn‚es
      mov  ds,ax                                    ; et le charge en DS
      mov  es,ax                                              ; et en ES

      mov  attn,cl                              ; Fixe l'indicateur WAIT

      ;-- Affiche le message et attend une frappe     ------------------

      mov  ah,9                   ; Num de la fonction "Afficher chaŒne"
      mov  dx,offset initm                          ; Adresse du message
      int  21h                           ; Appelle l'interruption de DOS

      xor  ah,ah                   ; Num‚ro de la fonction "Lire touche"
      int  16h                          ; Appelle l'interruption clavier
      cmp  al,"s"                                    ; A-t-on tap‚ <s> ?
      je   fin                          ; OUI--> on termine le programme
      cmp  al,"S"                                    ; A-t-on tap‚ <S> ?
      jne  startdemo                       ; NON  --> on d‚marre la d‚mo

fin:  mov  ax,4C00h           ; Num‚ro de la fonction Terminer programme
      int  21h                       ; Appelle l'interruption 21h de DOS

      ;-- Programme de d‚monstration de l'appel des fonctions-----------

startdemo  label near

      call grafhi                     ; Active le mode graphique 320*200
      xor  al,al
      call cgr                                          ; Efface l'‚cran

      xor  bx,bx                                             ; Colonne 0
      xor  dx,dx                                               ; Ligne 0
      mov  ax,199                                    ; Nb points vertic.
      mov  cx,639                                     ; Nb points horiz.

gr1:  push cx                                  ; Empile nb points horiz.
      mov  cx,ax                       ; Nb points vertic. dans compteur
      push ax                                 ; Empile nb points vertic.
      mov  al,1

gr2:  call pixhi                                      ; Dessine un point
      inc  dx                                      ; Incr‚mente la ligne
      loop gr2                                        ; Trace une droite
      pop  ax                                ; Reprend nb points vertic.
      sub  ax,3                       ; Ligne suivante 3 points de moins
      pop  cx                           ; Reprend nb points horiz. holen
      push cx                                  ; Empile nb points horiz.
      push ax                                 ; Empile nb points vertic.
      mov  al,1

gr3:  call pixhi                                      ; Dessine un point
      inc  bx                                    ; Incr‚mente la colonne
      loop gr3                                        ; Trace une droite
      pop  ax                               ; Reprend nb points vertical
      pop  cx                             ; Reprend nb points horizontal
      sub  cx,6                       ; Ligne suivante 6 points de moins
      push cx                              ; Empile nb points horizontal
      mov  cx,ax                       ; Nb points vertic. dans compteur
      push ax                                ; Empile nb points vertical
      mov  al,1

gr4:  call pixhi                                      ; Dessine un point
      dec  dx                                      ; D‚cr‚mente la ligne
      loop gr4                                        ; Trace une droite
      pop  ax                               ; Reprend nb points vertical
      sub  ax,3                       ; Ligne suivante 3 points de moins
      pop  cx                             ; Reprend nb points horizontal
      push cx                            ; M‚morise nb points horizontal
      push ax                              ; M‚morise nb points vertical
      mov  al,1

gr5:  call pixhi                                      ; Dessine un point
      dec  bx                                    ; Incr‚mente la colonne
      loop gr5                                        ; Trace une droite
      pop  ax                               ; Reprend nb points vertical
      pop  cx                             ; Reprend nb points horizontal
      sub  cx,6                       ; Ligne suivante 6 points de moins
      cmp  ax,5                                ; Ligne verticale sup … 5
      ja   gr1                                     ; OUI --> on continue

      xor  ah,ah                 ; Num‚ro de la fonct. "Attendre frappe"
      int  16h                          ; Appelle l'interruption clavier

      call text                             ; Active le mode texte 80*25
      xor  bp,bp                             ; D'abord la page d'‚cran 0

demo1:
      mov  al,30h                                       ; Code Ascii "0"
      or   ax,bp                    ; Transforme num‚ro de page en ASCII
      mov  str1,al                                ; M‚morise dans chaŒne
      call setcol                                      ; Fixe la couleur
      call pge                            ; Active la page d'‚cran en BP
      call cls                                          ; Efface l'‚cran
      xor  bx,bx                                  ; Commence l'affichage
      call calo                                     ; au coin sup gauche
      mov  cx,2000                          ; Une page = 2000 caractŠres
      xor  ah,ah                         ; On commence avec la couleur 0
      mov  si,offset str1                        ; Offset de la chaŒne 1

demo2:
      inc  ah                                    ; Incr‚mente la couleur
      call print                                   ; Affiche la chaŒne 1
      loop demo2                      ; R‚pŠte jusqu'… ‚cran soit rempli

      xor  ah,ah                                     ; Attend une touche
      int  16h                          ; Appelle l'interruption clavier
      inc  bp                               ; Incr‚mente la page d'‚cran
      cmp  bp,4                     ; A-t-on trait‚ toutes les 4 pages ?
      jne  demo1                        ; NON --> on passe … la suivante

      xor  bp,bp                            ; Active … nouveau la page 0
      call pge
      jmp  fin                                           ; C'est termin‚

demo       endp

;== Voici les fonctions proprement dites ===============================

;-- TEXT     : Activer l'affichage de texte ----------------------------
;-- Entr‚e   : Aucune
;-- Sortie   : Aucune
;-- Registres: AX, SI, BH, DX et registre des indicateurs sont modifi‚s

text       proc near

      mov  si,offset textt            ; Offset de la table des registres
      mov  bl,00100001b                   ; Mode texte 80*25, clignotant
      jmp  short vcprog                ; Reprogramme le contr“leur vid‚o

text       endp

;-- GRAFHI   : Active le mode graphique 640*200 points -----------------
;-- Entr‚e   : Aucune
;-- Sortie   : Aucune
;-- Registres: AX, SI, BH, DX et registre des indicateurs sont modifi‚s

grafhi     proc near

      mov  bl,00010010b                  ; Mode graphique 640*200 points
      jmp  short graphiq               ; Reprogramme le contr“leur vid‚o

grafhi     endp

;-- GRAFLO   : Activer le mode graphique 320*200 points ----------------
;-- Entr‚e   : Aucune
;-- Sortie   : Aucune
;-- Registres: AX, SI, BH, DX et registre des indicateurs sont modifi‚s

graflo     proc near

      mov  bl,00100010b                  ; Mode graphique 320*200 points
graphiq:
      mov  si,offset grafit           ; Offset de la table des registres

graflo     endp

;-- VCPROG   : programme le contr“leur vid‚o ---------------------------
;-- Entr‚e   : SI = Adresse d'une table de registres
;--            BL = Valeur pour registre de commande de l'‚cran
;-- Sortie   : Aucune
;-- Registres: AX, SI, BH, DX et registre des indicateurs sont modifi‚s

vcprog     proc near

      setmode bl                           ; Bit 3 = 0 : Ecran d‚sactiv‚

      mov  cx,12                                 ; 12 registres  … fixer
      xor  bh,bh                            ; Commence par le registre 0

vcp1: lodsb                      ; Lit une valeur de registre dans table
      mov  ah,al                            ; Valeur de registre dans AH
      mov  al,bh                            ; Num‚ro du registre dans AL
      call setvc                      ; Transmet la valeur au contr“leur
      inc  bh                              ; Appelle le registre suivant
      loop vcp1                              ; Fixe les autres registres

      or   bl,8                               ; Bit 3 = 1 : Ecran activ‚
      setmode bl                                     ; Fixe nouveau mode
      ret                                 ; Retour au programme appelant

vcprog     endp

;-- SETCOL   : fixe la couleur du cadre et du fond de l'‚cran ----------
;-- Entr‚e   : AL = valeur de couleur
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s
;-- Infos    : En mode texte les 4 bits inf‚rieurs fixent la couleur du
;--            cadre. En mode graphique les 4 bits inf‚rieurs indiquent
;--            les couleurs de cadre et de fond, le bit 5 s‚lectionne
;--            la palette de couleurs

setcol     proc near

      mov  dx,REG_COUL        ; Adresse registre de s‚lection de couleur
      out  dx,al                          ; Sort la valeur de la couleur
      ret                                 ; Retour au programme appelant

setcol     endp

;-- CDEF     : D‚limite la forme du curseur ----------------------------
;-- Entr‚e   : CL = ligne de trame de d‚part
;--            CH = ligne de trame de fin
;-- Sortie   : Aucune
;-- Registres: AX et DX sont modifi‚s

cdef       proc near

      mov  al,CUR_START                     ; Registre : ligne de d‚part
      mov  ah,cl                               ; Ligne de d‚part dans AH
      call setvc                   ; Communique avec le contr“leur vid‚o
      mov  al,CUR_END                          ; Registre : ligne de fin
      mov  ah,ch                                  ; Ligne de fin dans AH
      jmp  short setvc             ; Communique avec le contr“leur vid‚o

cdef       endp

;-- PGE      : fixe la page d'‚cran affich‚e ---------------------------
;-- Entr‚e   : BP = Num‚ro de la page d'‚cran (0 … 3)
;-- Sortie   : Aucune
;-- Registres: BX, AX, CX et DX sont modifi‚s
;-- Infos    : dans les modes graphiques, la premiŠre page d'‚cran
;--            porte le num‚ro 0, la seconde le num‚ro 2

pge        proc near

      mov  bx,bp                                  ; Page d'‚cran dans BX
      mov  cl,5                                     ; Multiplie par 2048
      ror  bx,cl
      mov  al,PAGECOUR_HI        ; Registre : Octet fort adresse de page
      mov  ah,bh                 ; Octet fort de la page d'‚cran dans AH
      call setvc                   ; Communique avec le contr“leur vid‚o
      mov  al,PAGECOUR_LO        ; Registre : Octet faible de page ‚cran
      mov  ah,bl                 ; Octet faible de la page ‚cran dans AH
      jmp  short setvc             ; Communique avec le contr“leur vid‚o

pge        endp

;-- SETCLIGN : Positionne le curseur clignotant de l'‚cran -------------
;-- Entr‚e   : DI = Offset du curseur
;-- Sortie   : Aucune
;-- Registres: BX, AX et DX sont modifi‚s

setclign   proc near

      mov  bx,di                              ; TransfŠre offset dans BX
      mov  al,14                      ; Registre 14 : MSB offset curseur
      mov  ah,bh                                ; Octet fort de l'offset
      call setvc                   ; Communique avec le contr“leur vid‚o
      mov  al,15                      ; Registre 15 : LSB offset curseur
      mov  ah,bl                              ; Octet faible de l'offset

      ;-- SETVC est appel‚e automatiquement ----------------------------

setclign   endp

;-- SETVC    : fixe un octet dans l'un des registres du contr“leur vid‚o
;-- Entr‚e   : AL = Num‚ro du registre
;--            AH = Nouveau contenu du registre
;-- Sortie   : Aucune
;-- Registres: DX et AL sont modifi‚s

setvc      proc near

      mov  dx,ADRESS_6845                  ; Adresse du registre d'index
      out  dx,al                          ; Envoye le num‚ro du registre
      jmp  short $+2                      ; Petite pause d'entr‚e-sortie
      inc  dx                              ; Adresse du registre d'index
      mov  al,ah                                       ; Contenu dans AL
      out  dx,al                               ; Fixe le nouveau contenu
      ret                                 ; Retour au programme appelant

setvc      endp

;-- GETVC    : lit un octet dans l'un des registres du contr“leur vid‚o
;-- Entr‚e   : AL = Num‚ro du registre
;-- Sortie   : AL = Contenu du registre
;-- Registres: DX et AL sont modifi‚s

getvc      proc near

      mov  dx,ADRESS_6845                  ; Adresse du registre d'index
      out  dx,al                          ; Envoye le num‚ro du registre
      inc  dx
      jmp  short $+2
      in   al,dx                          ; TransfŠre le contenu dans AL
      ret                                 ; Retour au programme appelant

getvc      endp

;-- SCROLLUP : fait d‚filer une fenˆtre de N lignes vers le haut -------
;-- Entr‚e   : BL = ligne supgauche
;--            BH = colonne sup gauche
;--            DL = ligne inf droite
;--            DH = colonne inf droite
;--            CL = Nombre de lignes de d‚filement
;--            BP = Num‚ro de la page d'‚cran (0 … 3)
;-- Sortie   : Aucune
;-- Registres: seuls le registre des indicateurs est modifi‚
;-- Infos    : les lignes de l'‚cran lib‚r‚es sont vierges

scrollup   proc near

      cld                        ; Sens d'incr des chaŒnes de caractŠres
      push ax                        ; Sauve tous les registres modifi‚s
      push bx                                              ; sur la pile
      push di                                ; Dans ce cas, l'ordre doit
      push si                                          ; ˆtre respect‚ !

      push bx                      ; Ces trois registres sont retir‚s de
      push cx                             ; la pile avant mˆme la fin de
      push dx                                               ; la routine
      sub  dl,bl                          ; Calculer le nombre de lignes
      inc  dl
      sub  dl,cl                 ; Retranche nb. de lignes de d‚filement
      sub  dh,bh                            ; Calcule le nombre colonnes
      inc  dh
      call calo                    ; Convertit coin sup gauche en offset
      mov  si,di                               ; Range l'adresse dans SI
      add  bl,cl                        ; PremiŠre ligne dans la fenˆtre
      call calo                     ; Convertit premiŠre ligne en offset
      xchg si,di                                      ; Echange SI et DI
      cmp  attn,0                    ; Faut-il empˆcher le tremblement ?
      je   sup0                                           ; NON --> SUP0

      waitret                          ; OUI, attend le rafraŒchissement
      setmode 00100101b                              ; D‚sactive l'‚cran

sup0: push ds                               ; Sauve registres de segment
      push es                                              ; sur la pile
      mov  ax,VIO_SEG            ; Charge le segment de la m‚moire ‚cran
      mov  ds,ax                                                 ; en DS
      mov  es,ax                                                 ; et ES

sup1: mov  ax,di                                      ; Range DI dans AX
      mov  bx,si                                      ; Range SI dans BX
      mov  cl,dh                   ; Nombre de colonnes dans le compteur
      rep  movsw                                      ; D‚cale une ligne
      mov  di,ax                                       ; D‚duit DI de AX
      mov  si,bx                                       ; D‚duit SI de BX
      add  di,160                                       ; Ligne suivante
      add  si,160
      dec  dl                             ; Toutes les lignes trait‚es ?
      jne  sup1                        ; NON --> d‚cale encore une ligne

      pop  es                         ; Reprend les registres de segment
      pop  ds                                              ; sur la pile

      cmp  attn,0                    ; Faut-il empˆcher le tremblement ?
      je   sup2                                           ; NON --> SUP2

      setmode 00101101b                          ; OUI, r‚tablit l'‚cran

sup2: pop  dx                                 ; R‚cupŠre coin inf. droit
      pop  cx                                ; R‚cupŠre nombre de lignes
      pop  bx                                ; R‚cupŠre coin sup. gauche
      mov  bl,dl                              ; Ligne inf‚rieure dans BL
      sub  bl,cl                         ; Retranche le nombre de lignes
      inc  bl
      mov  ah,07h                             ; Couleur : noir sur blanc
      call clear                            ; Efface les lignes lib‚r‚es

      pop  si                                    ; CX et DX ont d‚j… ‚t‚
      pop  di                                                ; r‚cup‚r‚s
      pop  bx
      pop  ax

      ret                                 ; Retour au programme appelant

scrollup   endp

;-- SCROLLDN : fait d‚filer une fenˆtre de N lignes vers le bas --------
;-- Entr‚e   : BL = ligne sup gauche
;--            BH = colonne sup gauche
;--            DL = ligne inf droite
;--            DH = colonne inf droite
;--            CL = Nombre de lignes de d‚filement
;--          : BP = Num‚ro de la page ‚cran (0 … 3)
;-- Sortie   : Aucune
;-- Registres: seuls le registre des indicateurs est modifi‚
;-- Infos    : les lignes de l'‚cran lib‚r‚es sont vierges

scrolldn   proc near

      cld                        ; Sens d'incr des chaŒnes de caractŠres

      push ax                        ; Sauve tous les registres modifi‚s
      push bx                                              ; sur la pile
      push di                                 ; Dans ce cas l'ordre doit
      push si                                          ; ˆtre respect‚ !

      push bx                      ; Ces trois registres sont retir‚s de
      push cx                             ; la pile avant mˆme la fin de
      push dx                                               ; la routine

      sub  dh,bh                            ; Calcule le nombre colonnes
      inc  dh
      mov  al,bl                        ; Range ligne sup gauche dans AL
      mov  bl,dl                            ; Ligne i.d. dans ligne i.g.
      call calo                    ; Convertit coin sup gauche en offset
      mov  si,di                               ; Range l'adresse dans SI
      sub  bl,cl                   ; Retranche nb de ligne de d‚filement
      call calo                    ; Convertit coin sup gauche en offset
      xchg si,di                                      ; Echange SI et DI
      sub  dl,al                           ; Calcule le nombre de lignes
      inc  dl
      sub  dl,cl                  ; Retranche nb de lignes de d‚filement

      cmp  attn,0                    ; Faut-il empˆcher le tremblement ?
      je   sdn0                                           ; NON --> SDN0

      waitret                          ; OUI, attend le rafraŒchissement
      setmode 00100101b                              ; d‚sactive l'‚cran

sdn0: push ds                           ; Sauve les registres de segment
      push es                                              ; sur la pile
      mov  ax,VIO_SEG            ; Charge le segment de la m‚moire ‚cran
      mov  ds,ax                                                 ; en DS
      mov  es,ax                                              ; et en ES

sdn1: mov  ax,di                                      ; Range DI dans AX
      mov  bx,si                                      ; Range SI dans BX
      mov  cl,dh                   ; Nombre de colonnes dans le compteur
      rep  movsw                                      ; D‚cale une ligne
      mov  di,ax                                       ; D‚duit DI de AX
      mov  si,bx                                       ; D‚duit SI de BX
      sub  di,160                                       ; Ligne suivante
      sub  si,160
      dec  dl                             ; Toutes les lignes trait‚es ?
      jne  sdn1                        ; NON --> d‚cale encore une ligne
      pop  es                        ; R‚cupŠre les registres de segment
      pop  ds                                              ; sur la pile

      cmp  attn,0                    ; Faut-il empˆcher le tremblement ?
      je   sdn2                                           ; NON --> SDN2

      setmode 00101101b                  ; OUI, remet l'‚cran en service

sdn2: pop  dx                                 ; R‚cupŠre coin inf. droit
      pop  cx                                ; R‚cupŠre nombre de lignes
      pop  bx                                ; R‚cupŠre coin sup. gauche
      mov  dl,bl                              ; Ligne sup‚rieure dans DL
      add  dl,cl                        ; Additionne le nombre de lignes
      dec  dl
      mov  ah,07h                             ; Couleur : noir sur blanc
      call clear                            ; Efface les lignes lib‚r‚es

      pop  si                                    ; CX et DX ont d‚j… ‚t‚
      pop  di                                                ; r‚cup‚r‚s
      pop  bx
      pop  ax

      ret                                 ; Retour au programme appelant

scrolldn   endp

;-- CLS      : Efface l'‚cran dans son int‚gralit‚ ---------------------
;-- Entr‚e   : BP = Num‚ro de la page d'‚cran (0 ou 1)
;-- Sortie   : Aucune
;-- Registres: seuls le registre des indicateurs est modifi‚s

cls        proc near

      mov  ah,07h                             ; Couleur : blanc sur noir
      xor  bx,bx                               ; Coin sup gauche = (0/0)
      mov  dx,4F18h                           ; Coin inf droit = (79/24)

      ;-- Ex‚cute Clear ------------------------------------------------

cls        endp

;-- CLEAR    : remplit d'espaces une zone d'‚cran d‚termin‚e -----------
;-- Entr‚e   : AH = attribut/couleur
;--            BL = ligne sup gauche
;--            BH = colonne sup gauche
;--            DL = ligne inf droite
;--            DH = colonne inf droite
;--            BP = Num‚ro de la page d'‚cran (0 … 3)
;-- Sortie   : Aucune
;-- Registres: seul le registre des indicateurs sont modifi‚s

clear      proc near

      cld                        ; Sens d'incr des chaŒnes de caractŠres
      push cx                     ; Sauve sur la pile tous les registres
      push dx                         ; qui seront modifi‚s par la suite
      push si
      push di
      push es
      sub  dl,bl                           ; Calcule le nombre de lignes
      inc  dl
      sub  dh,bh                         ; Calcule le nombre de colonnes
      inc  dh
      call calo                        ; Offset du coin sup‚rieur gauche
      mov  cx,VIO_SEG                    ; Segment de la m‚moire d'‚cran
      mov  es,cx                                               ; dans ES
      xor  ch,ch                            ; Octet fort du compteur … 0
      mov  al," "                                               ; Espace
      cmp  attn,0                    ; Faut-il empˆcher le tremblement ?
      je   clear1                                       ; NON --> CLEAR1

      push dx                                     ; Sauve DX sur la pile
      waitret                               ; Attend le rafraŒchissement
      setmode 00100101b                              ; D‚sactive l'‚cran
      pop  dx                                  ; R‚cupŠre DX sur la pile


clear1:
      mov  si,di                                      ; Range DI dans SI
      mov  cl,dh                   ; Nombre de colonnes dans le compteur
      rep stosw                                           ; Sauve espace
      mov  di,si                                       ; D‚duit DI de SI
      add  di,160                                       ; Ligne suivante
      dec  dl                             ; Toutes les lignes trait‚es ?
      jne  clear1                      ; NON --> efface encore une ligne

      cmp  attn,0                    ; Faut-il empˆcher le tremblement ?
      je   clear2                                       ; NON --> CLEAR2

      setmode 00101101b                       ; Remet en service l'‚cran

clear2:
      pop  es                       ; R‚cupŠre sur la pile les registres
      pop  di                                              ; sauvegard‚s
      pop  si
      pop  dx
      pop  cx
      ret                                 ; Retour au programme appelant

clear      endp

;-- PRINT    : Affiche une chaŒne sur l'‚cran --------------------------
;-- Entr‚e   : AH = Attribut/couleur
;--            DI = Offset du premier caractŠre
;--            SI = Offset de la chaŒne par rapport … DS
;--            BP = Num‚ro de la page d'‚cran (0 … 3)
;-- Sortie   : DI d‚signe le position aprŠs le dernier caractŠre affich‚
;-- Registres: AL, DI et le registres des indicateurs sont modifi‚s
;-- Infos    : La chaŒne doit se terminer par le caractŠre NUL.
;--            Les autres caractŠres de contr“le ne sont pas reconnus.

print      proc near

      cld                        ; Sens d'incr des chaŒnes de caractŠres
      push si                           ; Sauve SI, DX et ES sur la pile
      push es
      push cx
      push dx
      mov  dx,VIO_SEG            ; Charge le segment de la m‚moire ‚cran

      mov  cl,attn                               ; Lit l'indicateur WAIT
      mov  es,dx                                      ; en DX puis en ES

      jmp  short print3                     ; Lit et traite un caractŠre

print1     label near

      or   cl,cl                     ; Faut-il empˆcher le tremblement ?
      je   print2                                       ; NON --> PRINT2

      push ax                      ; M‚morise le caractŠre et sa couleur
      mov  dx,3DAh               ; Adresse du registre d'‚tat de l'‚cran
hr1:  in   al,dx                                        ; Lit le contenu

      test al,1                          ; RafraŒchissement horizontal ?
      jne  hr1                                        ; NON --> attendre
      cli                                     ; Inhibe les interruptions
hr2:  in   al,dx                                        ; Lit le contenu
      test al,1                          ; RafraŒchissement horizontal ?
      je   hr2                                        ; OUI --> attendre
      pop  ax                            ; r‚cupŠre caractŠre et couleur
      sti                                   ; r‚tablit les interruptions

print2:
      stosw                      ; Attribut et couleur dans la m‚m ‚cran
print3:
      lodsb                       ; Passe au caract. suivant dans chaŒne
      or   al,al                             ; est-ce le caractŠre NUL ?
      jne  print1                                     ; NON --> afficher

printe:
      pop  dx                               ; r‚cupŠre SI, CX, DX et  ES
      pop  cx                                              ; sur la pile
      pop  es
      pop  si
      ret                                    ; Rend la main … l'appelant

print      endp


;-- CALO     : convertit ligne et colonne en adresse d'offset ----------
;-- Entr‚e   : BL = ligne
;--            BH = colonne
;--            BP = Num‚ro de la page d'‚cran (0 … 3)
;-- Sortie   : DI = l'adresse d'offset
;-- Registres: DI et le registre des indicateurs sont modifi‚s

calo       proc near

      push ax                                     ; Sauve AX sur la pile
      push bx                                     ; Sauve BX sur la pile

      shl  bx,1                                ; Colonne et ligne fois 2
      mov  al,bh                                       ; Colonne dans AL
      xor  bh,bh                                            ; Octet fort
      mov  di,[lignes+bx]                         ; Lire offset de ligne
      xor  ah,ah                        ; Octet fort pour offset colonne
      add  di,ax                   ; Additionne offsets ligne et colonne
      mov  bx,bp                                  ; Page d'‚cran dans BX
      mov  cl,4                                     ; Multiplie par 4096
      ror  bx,cl
      add  di,bx                 ; Additionne d‚but de page ‚cran offset
      pop  bx                                     ; Retire BX de la pile
      pop  ax                                     ; Retire AX de la pile
      ret                                 ; Retour au programme appelant

calo       endp

;-- CGR      : Efface int‚gralement l'‚cran graphique ------------------
;-- Entr‚e   : AL = 00(h) : Effacer tous les points
;--                 FF(h) : Dessiner tous les points
;-- Sortie   : Aucune
;-- Registres: AH, BX, CX, DI et registre des indicateurs sont modifi‚s
;-- Infos    : Cette fonction efface l'‚cran graphique dans les deux
;--            modes graphiques

cgr       proc near

      push es                                     ; Sauve ES sur la pile
      cbw                                                ; Etend AL … AH
      xor  di,di                                ; Offset m‚moire d'‚cran
      mov  bx,VIO_SEG                          ; Segment m‚moire d'‚cran
      mov  es,bx                                       ; Segment dans ES
      mov  cx,2000h                     ; Une page repr‚sente 8K de mots
      rep  stosw                                       ; Remplit la page
      pop  es                                 ; R‚cupŠr eES sur  la pile
      ret                                 ; Retour au programme appelant

cgr       endp

;-- PIXLO    : Dessine un point en mode graphique 320*200 points -------
;-- Entr‚e   : BP = Num‚ro de la page d'‚cran (0 ou 1)
;--            BX = Colonne (0 … 319)
;--            DX = Ligne (0 … 199)
;--            AL = Couleur du point (0 … 3)
;-- Sortie   : Aucune
;-- Registres: AX, DI et le registre des indicateurs sont modifi‚s

pixlo      proc near

      push ax                                     ; Sauve AX sur la pile
      push bx                                     ; Range BX sur la pile
      push cx                                     ; Range CX sur la pile
      mov  cl,7
      mov  ah,bl                             ; TransfŠre colonne dans AH
      and  ah,11b                                        ; Colonne mod 4
      shl  ah,1                                            ; Colonne * 2
      sub  cl,ah                               ; 7 - 2 * (Colonne mod 4)
      mov  ah,11                                        ; Masque de bits
      shl  ax,cl                      ; D‚cale vers la position du point
      not  ah                                 ; Inverse AH pour masquage
      shr  bx,1                     ; D‚cale BX deux fois vers la droite
      shr  bx,1                                     ; pour diviser par 4
      jmp  short spix                                 ; Dessine le point

pixlo      endp

;-- PIXHI    : Dessine un point en mode graphique 640*200 points -------
;-- Entr‚e   : BP = Num‚ro de la page d'‚cran (0 ou 1)
;--            BX = Colonne (0 … 639)
;--            DX = Ligne (0 … 199)
;--            AL = Couleur du point (0 ou 1)
;-- Sortie   : Aucune
;-- Registres: AX, DI et le registre des indicateurs sont modifi‚s

pixhi      proc near

      push ax                                     ; Sauve AX sur la pile
      push bx                                             ; idem pour BX
      push cx                                                    ; et CX

      mov  cl,7
      mov  ah,bl                          ; TransfŠre la colonne dans AH
      and  ah,111b                                       ; Colonne mod 8
      sub  cl,ah                                     ; 7 - Colonne mod 8
      mov  ah,1                                         ; Masque de bits
      shl  ax,cl                      ; D‚cale vers la position du point
      not  ah                              ; Inverse AH pour le masquage
      mov  cl,3                                            ; 3 d‚calages
      shr  bx,cl                                       ; Divise BX par 8

      ;-- Dessine le point ---------------------------------------------

pixhi      endp

;-- SPIX     : Dessine un point sur l'‚cran graphique ------------------
;-- Entr‚e   : BX = Offset de colonne
;--            DX = Ligne (0 … 199)
;--            AH = Valeur pour masquer anciens bits
;--            AL = Nouvelle valeur de bit
;-- Sortie   : Aucune
;-- Registres: AX, DI et le registre des indicateurs sont modifi‚s

spix       proc near

      push es                                     ; Sauve ES sur la pile
      push dx                                     ; Sauve DX sur la pile
      push ax                                     ; Sauve AX sur la pile

      xor  di,di                                ; Offset m‚moire d'‚cran
      mov  cx,VIO_SEG                          ; Segment m‚moire d'‚cran
      mov  es,cx                                             ; Charge ES
      mov  ax,dx                                   ; AmŠne ligne dans AX
      shr  ax,1                                     ; Divise ligne par 2
      mov  cl,80                                     ; Le facteur est 90
      mul  cl                                   ; Multiplie ligne par 80
      and  dx,1                                            ; Ligne mod 2
      mov  cl,3                                            ; 3 d‚calages
      ror  dx,cl                   ; Rotation vers la droite (* 2000(h))
      mov  di,ax                                     ; 80 * int(Ligne/2)
      add  di,dx                             ; + 2000(h) * (Ligne mod 4)
      add  di,bx                          ; Additionne offset de colonne
      pop  ax                                     ; Retire AX de la pile
      mov  bl,es:[di]                                     ; Lit le point
      and  bl,ah                                       ; Masque les bits
      or   bl,al                                       ; InsŠre le point
      mov  es:[di],bl                                 ; R‚‚crit le point

      pop  dx                                     ; Retire DX de la pile
      pop  es                                     ; Retire ES de la pile
      pop  cx                                     ; Retire CX de la pile
      pop  bx                                     ; Retire BX de la pile
      pop  ax                                     ; Retire AX de la pile

      ret                                 ; Retour au programme appelant

spix       endp

_main   proc near
        jmp demo
_main   endp

;======== Fin ==========================================================
code  ends                                      ; Fin du segment de CODE
      end  demo                         ; D‚but d'ex‚cution du programme
