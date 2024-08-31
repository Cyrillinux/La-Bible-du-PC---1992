;**********************************************************************;
;*                        D U M P A . A S M                           *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Un filtre qui lit des caractŠres sur l'entr‚e  *;
;*                     standard pour les ressortir sur la sortie      *;
;*                     standard sous forme de dump hexa et ASCII      *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    :  1.08.87                                      *;
;*    DerniŠre modif. : 20.03.92                                      *;
;*--------------------------------------------------------------------*;
;*    Pour assembler  : MASM DUMPA;                                   *;
;*                      LINK DUMPA;                                   *;
;*                      EXE2BIN DUMPA DUMPA.COM  ou                   *;
;*                                                                    *;
;*                      TASM DUMPA                                    *;
;*                      TLINK /t DUMPA                                *;
;*--------------------------------------------------------------------*;
;*    Appel         : DUMPA [<Entr‚e] [>Sortie]                       *;
;**********************************************************************;

;==  Constantes ========================================================

      NUL    equ 0                             ;Code ASCII caractŠre NUL
      BEL    equ 7                                  ;Code ASCII sonnerie
      BS     equ 8                                 ;Code ASCII Backspace
      TAB    equ 9                                ;Code ASCII Tabulateur
      LF     equ 10                                ;Code ASCII Line Feed
      CR     equ 13                          ;Code ASCII Carriage Return
      EOF    equ 26                           ;Code ASCII Fin de fichier
      ESC    equ 27                                   ;Code ASCII Escape

;== Ici commence v‚ritablement le programme ============================

code      segment para 'CODE'             ;D‚finition du segment de code

          org 100h

          assume cs:code, ds:code, es:code, ss:code

;-- Routine initiale ---------------------------------------------------

dump      label near
          ;-- Lire 9 octets sur le p‚riph‚rique d'entr‚e standard ------

          xor  bx,bx                  ;Entr‚e standard porte le handle 0
          mov  cx,9                                ;Charger 9 caractŠres
          mov  dx,offset neufoctets                   ;Adresse du buffer
          mov  ah,3Fh              ;Code de fonction pour lecture Handle
          int  21h                                 ;Appeler fonction DOS
          or   ax,ax                   ;Des caractŠres ont-ils ‚t‚ lus ?
          jne  dodump                             ;OUI --> Traiter ligne
          jmp  findump                                 ;NON --> FIN DUMP

dodump:   mov  dx,ax                    ;Ranger nombre de caractŠres lus

          ;-- Remplir d'espaces buffer de sortie -----------------------

          mov  cx,15                                ;15 mots (30 octets)
          mov  ax,2020h                 ;Code ASCII du " " dans AH et AL
          mov  di,offset dumpBuf  ;Augmenter adresse du buffer de sortie
          cld                              ;pour instructions de chaŒnes
          rep  stosw                           ;Remplir buffer d'espaces

          ;-- Mettre en place buffer de sortie -------------------------

          mov  cx,dx            ;Aller chercher nombre de caractŠres lus
          mov  di,offset dumpBuf+31     ;Pos. codes ASCII dans le buffer
          mov  bx,offset neufoctets     ;Pointeur sur le buffer d'entr‚e
          mov  si,offset dumpBuf         ;Pos. codes hexa dans le buffer

octetin:  mov  ah,[bx]                                    ;Lire un octet
          push si                                 ;Ranger SI sur la pile
          mov  si,offset sptab              ;Adr. table de car. sp‚ciaux
          mov  dx,offset sptext-6           ;Adr. texte de car. sp‚ciaux
sptest:   add  dx,6           ;Prochaine entr‚e dans les textes sp‚ciaux
          lodsb            ;Charger code de table de caractŠres sp‚ciaux
          cmp  al,255                        ;Fin de la table atteinte ?
          je   nosp                       ;OUI --> Pas caractŠre sp‚cial
          cmp  ah,al                      ;Les codes correspondent-ils ?
          jne  sptest       ;NON --> Tester prochain ‚l‚ment de la table

          ;-- Le code ‚tait un caractŠre sp‚cial -----------------------
          push cx                                       ;Ranger compteur
          mov  si,dx                                  ;Copier DX dans SI
          lodsb           ;Lire nombre de caractŠres du code de commande
          mov  cl,al            ;Transf‚rer nombre de caractŠres dans CL
          rep  movsb                     ;Copier d‚signation dans buffer
          pop  cx                                      ;Retirer compteur
          pop  si                                 ;Ramener SI de la pile
          mov  al,ah                           ;Copier caractŠre dans AL
          jmp  short hex                             ;Calculer code hexa

nosp:     pop  si                                 ;Retirer SI de la pile
          mov  al,ah                           ;Copier caractŠre dans AL
          stosb                                   ;Sauver dans le buffer

hex:      mov  al,ah                          ;Code du caractŠre dans AL
          and  ah,1111b                  ;Masquer 4 bits du haut dans AH
          shr  al,1                        ;D‚caler AL de 4 bits en tout
          shr  al,1                                       ;sur la droite
          shr  al,1
          shr  al,1
          or   ax,3030h               ;Convertir AH et AL en codes ASCII
          cmp  al,"9"                   ;AL repr‚sente-t-il une lettre ?
          jbe  nobal                          ;NON --> Pas de correction
          add  al,"A"-"1"-9                                 ;Corriger AL
nobal:    cmp  ah,"9"                   ;AH repr‚sente-t-il une lettre ?
          jbe  hexout                         ;NON --> Pas de correction
          add  ah,"A"-"1"-9                                 ;Corriger AH
hexout:   mov  [si],ax                  ;Placer code hexa dans le buffer
          add  si,3                          ;D‚signer position suivante

          inc  bx                     ;Fixer pointeur sur prochain octet
          loop octetin                            ;Traiter octet suivant

          mov  al,219                           ;Fixer caractŠre sp‚cial
          stosb

          mov  ax,LF shl 8 + CR            ;CR et LF terminent le buffer
          stosw                                      ;Ecrire dans buffer

          ;-- Envoyer Dump sur p‚riph‚rique de sortie standard ---------

          mov  bx,1                   ;Sortie standard porte le handle 1
          mov  cx,di                      ;Calculer nombre de caractŠres
          sub  cx,offset dumpBuf                             ;transf‚r‚s
          mov  dx,offset dumpBuf                      ;Adresse du buffer
          mov  ah,40h               ;Code de fonction pour Ecrire handle
          int  21h                                 ;Appeler fonction DOS
          jmp  dump                              ;Lire 9 octets suivants

findump  label near

          mov  ax,4C00h         ;Num‚ro fonction pour terminer programme
          int  21h                  ;Terminer programme avec code de fin

;== Donn‚es ============================================================

neufoctets  db 9 dup (?)                   ;Les 9 octets lus chaque fois
dumpBuf     db 30 dup (?), 219                      ;Le buffer de sortie
            db 49 dup (?)

sptab       db NUL,BEL,BS,TAB          ;Table des caractŠres de commande
            db LF,CR,EOF,ESC
            db 255

sptext      equ this byte                ;Textes des caractŠres sp‚ciaux
            db 5,"<NUL>"                                            ;NUL
            db 5,"<BEL>"                                       ;Sonnerie
            db 4,"<BS> "                                      ;Backspace
            db 5,"<TAB>"                                     ;Tabulateur
            db 4,"<LF> "                                      ;Line Feed
            db 4,"<CR> "                                ;Carriage Return
            db 5,"<EOF>"                                 ;Fin du fichier
            db 5,"<ESC>"                                         ;Escape

;== Fin ===============================================================

code      ends                                   ;Fin du segment de CODE
          end  dump
