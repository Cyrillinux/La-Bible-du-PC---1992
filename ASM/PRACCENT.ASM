;**********************************************************************;
;*                          P R A C C E N T                           *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Redirige l'interruption imprimante du BIOS sur *;
;*                     une routine utilisateur permettant ainsi, par  *;
;*                     exemple, la conversion d'ASCII-IBM en EPSON.   *;
;*                     Tous les deux appels, le programme est …       *;
;*                     nouveau d‚sactiv‚ et ‚limin‚ de la m‚moire.    *;
;*                                                                    *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    d‚velopp‚ le   : 02/08/1987                                     *;
;*    DerniŠre modif.: 01/12/1991                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM PRACCENT;                                 *;
;*                     LINK PRACCENT;                                 *;
;*                     EXE2BIN PRACCENT PRACCENT.COM;                 *;
;*--------------------------------------------------------------------*;
;*    Appel          : PRACCENT                                       *;
;**********************************************************************;

;== Ici commence le programme v‚ritable ================================

code      segment para 'CODE'             ;D‚finition du segment de CODE

          org 100h

          assume cs:code, ds:code, es:code, ss:code

start:    jmp praccentini              ;La premiŠre instruction ex‚cut‚e

;== Donn‚es (restent en m‚moire) =======================================

ancint    equ this dword              ;Ancien vecteur d'interruption 17h
ofsancint dw (?)            ;Adresse d'offset vecteur d'interruption 17h
segancint dw (?)               ;Adresse de segment vecteur d'interr. 17h
;-- La table suivante pr‚sente chaque fois le nouveau ------------------
;-- code suivi de l'ancien ---------------------------------------------

codetab   db   64,133                            ; '…'   ----------> '@'
          db  125,138                            ; 'Š'   ----------> '}'
          db  123,130                            ; '‚'   ----------> '{'
          db   91,248                            ; 'ø'   ----------> '['
          db  124,151                            ; '—'   ----------> '|'
          db   92,135                            ; '‡'   ----------> '\'
          db   93,21                             ; ''   ----------> ']'
          db  0                                         ;Fin de la table

;== Voici la nouvelle interruption imprimante (reste en m‚moire) =======

newpri    proc far

          jmp  short newpri_1

          db "PR"                           ;Identification du programme

newpri_1: or   ah,ah                  ;Imprimer caractŠre (Fonction 0) ?
          jne  aint               ;NON --> Appeler ancienne interruption

          pushf                      ;Tous les registres modifi‚s par la
          push bx                        ;suite doivent ˆtre sauvegard‚s
          push si
          push ds

          push cs                                 ;Ranger CS sur la pile
          pop  ds                            ;Retirer de la pile pour DS

;-- Le code doit-il ˆtre converti ? ------------------------------------

          cld                  ;Augmenter comptage pour instr. de chaŒne
          mov  si,offset codetab           ;Adresse de la table de codes
          mov  bl,al                                ;Ranger code dans BL
testcode: lodsw               ;Charger ancien (AH) et nouveau (AL) codes
          or   al,al                            ;Fin de table atteinte ?
          je   notfound                         ;OUI --> code non trouv‚
          cmp  ah,bl                         ;Est-ce le code … convertir
          jne  testcode           ;NON --> poursuivre examen de la table
          jmp  short convertir              ;C'‚tait un code … convertir

notfound: mov  al,bl                        ;Ramener ancien code dans AL
convertir: xor  ah,ah              ;Fixer … nouveau num‚ro de fonction 0
          pop  ds                         ;Retirer registres sauvegard‚s
          pop  si
          pop  bx
          popf

aint:     jmp  cs:[ancint]           ;Vers l'ancienne routine imprimante

newpri    endp

instend   equ this byte                ;Jusqu'… cette cellule de m‚moire
                                              ;tout doit rester r‚sident

;== Donn‚es (peuvent ˆtre effac‚es par le DOS) =========================

installm  db 13,10,"PRACCENT (c) 1987 by Michael Tischer",13,10,13,10
          db "PRACCENT a ‚t‚ install‚ et peut … nouveau ˆtre",13,10
          db "d‚sactiv‚ par un second appel",13,10,"$"

elimine   db "PRACCENT a ‚t‚ d‚sactiv‚$",13,10

;== Programme (peut ˆtre effac‚ par le DOS) ============================
;-- Routine de lancement et initialisation -----------------------------

praccentini   label near

          mov  ax,3517h         ;Lire contenu vecteur d'interruption 17h
          int  21h                                 ;Appeler fonction DOS
          cmp  word ptr es:[bx+2],"RP"     ;Tester si programme PRACCENT
          jne  install             ;Pas de PRACCENT install‚ --> INSTALL

;-- PRACCENT est d‚sactiv‚ ---------------------------------------------

          mov  dx,es:ofsancint   ;Adresse d'offset de l'interruption 17h
          mov  ax,es:segancint ;Adresse de segment de l'interruption 17h
          mov  ds,ax                                            ;dans DS
          mov  ax,2517h     ;Replacer contenu vecteur d'interruption 17h
          int  21h                                 ;sur ancienne routine

          mov  bx,es             ;Ranger adresse de segment du programme
          mov  es,es:[2Ch]  ;Retirer du PSP adr. seg. de l'environnement
          mov  ah,49h                         ;Lib‚rer … nouveau m‚moire
          int  21h                                 ;d'ancien environnent

          mov  es,bx                       ;Lib‚rer … nouveau la m‚moire
          mov  ah,49h                              ;de l'ancien PRACCENT
          int  21h                     ;… travers la fonction 49h du DOS

          push cs                                 ;Sauver CS sur la pile
          pop  ds                                       ;Ramener dans DS

          mov  dx,offset elimine            ;Message : programme ‚limin‚
          mov  ah,9               ;Num‚ro de fonction pour Ecrire chaŒne
          int  21h                                 ;Appeler fonction DOS

          mov  ax,4C00h                 ;Terminer programme correctement
          int  21h                ;Appeler fonction pour terminer progr.

;-- Installation de PRACCENT -------------------------------------------

install   label near

          mov  ax,3517h      ;Lire contenu du vecteur d'interruption 17h
          int  21h                                 ;Appeler fonction DOS
          mov  segancint,es      ;Ranger adresses de segment et d'offset
          mov  ofsancint,bx           ;Ranger vecteur d'interruption 17h

          mov  dx,offset newpri    ;Adresse offset new routine d'interr.
          mov  ax,2517h           ;Contenu du vecteur d'interruption 17h
          int  21h                              ;sur routine utilisateur

          mov  dx,offset installm          ;Message : programme install‚
          mov  ah,9               ;Num‚ro de fonction pour Sortir chaŒne
          int  21h                                 ;Appeler fonction DOS

             ;-- Seuls le PSP, la nouvelle routine d'interruption et les
             ;-- donn‚es correspondantes doivent rester r‚sidentes.     

          mov  dx,offset instend ;Calculer nombre de paragraphes (unit‚s
          mov  cl,4       ;de 16 octets) dont doit disposer le programme
          shr  dx,cl
          inc  dx
          mov  ax,3100h      ;Terminer programme par code de fin 0 (o.k)
          int  21h                                 ;mais rester r‚sident

;== Fin ================================================================

code      ends                                   ;Fin du segment de CODE
          end  start
