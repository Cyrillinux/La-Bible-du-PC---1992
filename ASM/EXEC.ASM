;**********************************************************************;
;*                                E X E C                             *;
;*--------------------------------------------------------------------*;
;*    Fonction      :  Appelle un programme quelconque … l'aide de la *;
;*                     fonction EXEC du DOS. Ce programme d'exemple   *;
;*                     affiche le contenu du r‚pertoire racine du     *;
;*                     p‚riph‚rique actuel.                           *;
;*                                                                    *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    :  1.08.87                                      *;
;*    DerniŠre modif. : 19.03.92                                      *;
;*--------------------------------------------------------------------*;
;*    Pour assembler  : MASM EXEC                                     *;
;*                      LINK EXEC                                     *;
;*            ou                                                      *;
;*                      TASM EXEC                                     *;
;*                      TLINK EXEC                                    *;
;*--------------------------------------------------------------------*;
;*    Appel         : EXEC                                            *;
;**********************************************************************;

;== Donn‚es ============================================================

data      segment para 'DATA'          ;D‚finition du segment de donn‚es

prgname   db "c:\command.com",0              ;Nom du programme … appeler
prgpara   db "/c dir",0             ;Les paramŠtres sont transmis au Prg

          ;-- Les divers messages du programme -------------------------

startmes  db "ÛÛÛÛÛÛÛÛÛÛÛÛ EXEC - (c) 1987, 92 by Michael Tischer ÛÛÛÛÛ"
          db 13,10,"$"
mesok     db "OK",13,10,"$"
mesnotf   db "Erreur : COMMAND.COM non trouv‚!",13,10,"$"
meselse   db "Erreur : Code d'erreur DOS = "
mescode   db "   ",13,10,"$"

data      ends                                ;Fin du segment de donn‚es

;== Code ===============================================================

code      segment para 'CODE'             ;D‚finition du code de segment

          assume cs:code, ds:data, ss:stackseg

exec             proc far

          mov  ax,data              ;Charge adresse segment du DATA seg.
          mov  ds,ax                                ;dans le registre DS

          mov  ah,09h                      ;Afficher le message d'invite
          mov  dx,offset startmes
          int  21h

          call setfree                    ;Lib‚rer la m‚moire inutilis‚e

          mov  dx,offset prgname                ;Offset nom de programme
          mov  si,offset prgpara          ;Offset de ligne d'instruction
          call exeprg                              ;Appeler le programme

          mov  dx,offset mesok       ;Partir d'une ex‚cution non erron‚e
          jnc  ex_mes                ;Pas d'erreur ---> Afficher message

          mov  dx,offset mesnotf      ;Apparemment, programme non trouv‚
          cmp  al,2                                           ;Pas vrai?
          je   ex_mes                         ;Oui ---> Afficher message

          xor  ah,ah                           ;Hi-Byte du code d'erreur
          mov  si,offset mescode+2             ;Code d'erreur vers ASCII
          call toint

          mov  dx,offset meselse
ex_mes:   mov  ah,09h                           ;Afficher chaŒne via DOS
          int  21h

          mov  ax,4C00h                 ; FIN programme par fonction DOS
          int  21h                   ;en transmettant le code d'erreur 0


exec             endp

;-- SETFREE: Lib‚rer la place m‚moire inutilis‚e -----------------------
;-- Entr‚e  : ES = Adresse du PSP
;-- Sortie  : Aucune
;-- Registres : AX, BX, CL et FLAGS sont modifi‚s
;-- Infos   : Comme le segment de pile est toujours le dernier segment
;--           dans un fichier EXE, ES:0000 d‚signe le d‚but et SS:SP la
;--           fin du programme en m‚moire. C'est ainsi qu'on peut
;--           calculer la longueur du programme

setfree          proc near

          mov  bx,ss      ;Calculer d'abord la diff‚rence entre les deux
          mov  ax,es       ;adresses de segment. Cela donne le nombre de
          sub  bx,ax             ;paragraphes du PSP au d‚but de la pile

          mov  ax,sp       ;Comme le pointeur de pile se trouve … la fin
          add  ax,15            ;du segment de pile, son contenu indique
          mov  cl,4                              ;la longueur de la pile
          shr  ax,cl
          add  bx,ax                   ;Ajouter … la longueur ant‚rieure

          mov  ah,4ah             ;Transmettre la nouvelle taille au DOS
          int  21h

          ret                                       ;Retour … l'appelant

setfree          endp

;-- EXEPRG: Appeler un autre programme ---------------------------------
;-- Entr‚e  : DS:DX = Adresse du nom de programme
;--           DS:SI = Adresse de la ligne d'instruction
;-- Sortie  : Carry-Flag = 1 : Erreur (AX = code d'erreur)
;-- Registres : Seuls AX et FLAGS sont modifi‚s
;-- Infos     : Le nom de programme et la ligne d'instruction doivent
;--             figurer sous forme de chaŒnes ASCII termin‚es par le
;--             code ASCII 0

exeprg           proc near

          ;-- Transmettre la ligne d'instruction sp‚cifi‚e -------------
          ;-- dans un buffer en comptant les caractŠres ----------------

          push bx                        ;Sauvegarder tous les registres
          push cx                            ;d‚truits par l'appel d'une
          push dx                                     ;fonction EXEC DOS
          push di
          push si
          push bp
          push ds
          push es

          mov  di,offset comline+1        ;Car. dans ligne d'instruction
          push cs                                        ;CS sur la pile
          pop  es                           ;Retirer pour placer dans ES
          xor  bl,bl                  ;Fixer le compteur de carac. sur 0
copypara: lodsb                                       ;Lire un caractŠre
          or   al,al                           ;Est-ce le code NUL (Fin)
          je   fincopie                             ;OUI --> assez copi‚
          stosb                      ;Sauvegarder dans le nouveau buffer
          inc  bl                   ;Augmenter le compteur de caractŠres
          cmp  bl,126                                  ;Maximum atteint?
          jne  copypara                               ;NON --> continuer

fincopie: mov  cs:comline,bl        ;Sauvegarder le nombre de caractŠres
          mov  byte ptr es:[di],13         ;Terminer ligne d'instruction

          mov  cs:rangss,ss       ;SS et SP doivent ˆtre stock‚s dans le
          mov  cs:rangsp,sp                             ;segment de code

          mov  bx,offset parblock   ;ES:BX d‚signe le bloc de paramŠtres
          mov  ax,4B00h        ;Num‚ro de fonction pour la fonction EXEC
          int  21h                              ;Appeler fonction du DOS

          cli               ;D‚sactiver temporairement les interruptions
          mov  ss,cs:rangss       ;R‚tablir anciennes valeurs segment de
          mov  sp,cs:rangsp                 ;pile et du pointeur de pile
          sti                       ;Activer … nouveau les interruptions

          pop  es                            ;Retirer … nouveau tous les
          pop  ds                                  ;registres de la pile
          pop  bp
          pop  si
          pop  di
          pop  dx
          pop  cx
          pop  bx

          jc   exeend                               ;Erreur? OUI --> Fin
          mov  ah,4dh             ;Pas d'erreur, Ex‚cuter le code de fin
          int  21h                                         ;du programme

exeend:   ret                                       ;Retour … l'appelant

          ;-- Ces variables ne peuvent ˆtre appel‚s qu'… travers CS ----

rangss    dw (?)                 ;Re‡oit SS pendant l'appel du programme
rangsp    dw (?)                 ;Re‡oit SP pendant l'appel du programme

parblock  equ this word        ;Bloc de paramŠtres pour la fonction EXEC
          dw 0                                ;Mˆme bloc d'environnement
          dw offset comline ;Adresses d'offset et de segment de la ligne
          dw seg code                                         ;convertie
          dd 0                               ;Pas de donn‚es dans PSP #1
          dd 0                               ;Pas de donn‚es dans PSP #2

comline   db 128 dup (?)        ;Re‡oit la ligne d'instruction convertie

exeprg           endp

;-- TOINT: Convertit un nombre binaire en ASCII et le place ------------
;--  dans un buffer de l'appelant en le justifiant … droite
;-- Entr‚e : DS:SI = Ptr sur la position o— doit apparaŒtre le chiffre
;--                  de poids faible
;--          AX    = Nombre binaire … convertir
;-- Sortie : DS:SI = Pointeur sur le chiffre de poids fort
;-- Registres : AX, BX, DX, SI et FLAGS sont modifi‚s
;-- Infos : - Le buffer doit contenir de la place pour au moins cinq
;--           caractŠres.
;--         - Le nombre entr‚ dans le buffer est justifi‚ … droite.

toint            proc near

          ;-- Diviser toujours par 10 le nombre dans la boucle et ------
          ;-- convertir ainsi le LSB au format ASCII -------------------
          ;-- puis l'entrer dans le buffer -----------------------------

          mov  bx,10                        ;Le diviseur est toujours 10
          jmp  short ti2

ti1:      dec  si                              ;SI sur caractŠre suivant

ti2:      xor  dx,dx                             ;Le dividende est DX:AX
          div  bx                                  ;Diviser DX:AX par 10
          or   dl,'0'                      ;Convertir DL au format ASCII
          mov  [si],dl                            ;Placer dans le buffer
          or   ax,ax                                 ;Y a-t-il un reste?
          jne  ti1                              ;OUI --> Chiffre suivant

          ret                                       ;Retour … l'appelant

toint            endp

;== Stack ==============================================================

          ;--- Le segment de pile est … placer ici … la fin du fichier -
          ;--- pour qu'il se trouve derriŠre le segment de donn‚es -----
          ;--- et de code aprŠs chargement du programme ----------------

stackseg  segment para stack 'STACK'      ;D‚finition du segment de pile

          dw 256 dup (?)           ;La taille de la pile est de 256 mots

stackseg  ends                                   ;Fin du segment de pile

;== Fin ================================================================

code      ends                                   ;Fin du segment de code
          end  exec                        ;Commencer l'ex‚cution … EXEC
