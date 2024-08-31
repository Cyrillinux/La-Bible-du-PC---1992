;**********************************************************************;
;*                           M A C R O K E Y                          *;
;*--------------------------------------------------------------------*;
;*    Fonction     : Montre comment on d‚finit des touches de         *;
;*                   macro commande en reprogrammant le gestionnaire  *;
;*                   de l'interruption 16h du BIOS                    *;
;*--------------------------------------------------------------------*;
;*    Auteur                : MICHAEL TISCHER                         *;
;*    D‚velopp‚ le          : 03.01.1992                              *;
;*    DerniŠre modification : 03.01.1992                              *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM MACROKEY                                  *;
;*                     LINK MACKROKEY                                 *;
;*                     EXE2BIN MACROKEY MACROKEY.COM                  *;
;*                                                                    *;
;*                     ou                                             *;
;*                                                                    *;
;*                     TASM MACROKEY                                  *;
;*                     TLINK /t MACROKEY                              *;
;*--------------------------------------------------------------------*;
;*    Appel          : MACROKEY                                       *;
;**********************************************************************;

;== D‚but du programme

code  segment para 'CODE'                 ;D‚finition du segment de code

      org 100h

      assume cs:code, ds:code, es:code, ss:code

start: jmp  mkinit                  ;Appel des routines d'initialisation

;== Donn‚es (restant en m‚moire ) ======================================

ancint    equ this dword              ;Ancien vecteur d'interruption 16h
intancofs dw (?)                   ;Offset du vecteur d'interruption 16h
intancseg dw (?)                  ;Segment du vecteur d'interruption 16h

mkey      dw 3100h                        ;Touche d'activation : ALT + N
mstart    db "Micro Application"                      ;Texte de la macro
mend      equ this byte

mofs      dw 0FFFFh                             ;Pointe sur le caractŠre
                                           ;suivant du texte de la macro
                                                      ;Texte de la macro

;== Ceci est la nouvelle interruption        16h (reste en m‚moire  ) =

nouvi16    proc far

      assume cs:code, ds:nothing, es:nothing, ss:nothing

      sti                          ;Autorise … nouveau les interruptions
      jmp  short ni1

      db "MT"                               ;Identification du programme

ni1:          ;-- teste d'abord si le nouveau gestionnaire est comp‚tent
                                            ;-- pour la fonction appel‚e

      or   ah,ah                                   ;Fonction 00h ou 10h?
      je   fct0
      cmp  ah,10h
      je   fct0

      cmp  ah,01h                                  ;fonction 01h ou 11h?
      je   fct1
      cmp  ah,11h
      je   fct1

      jmp  cs:[ancint]                  ;non, faire ex‚cuter la fonction
                                              ;par l'ancien gestionnaire

fct0:     ;-- fonction 00h/10h -----------------------------------------

      cmp  mofs,offset mend           ;Macro d‚j… en cours d'ex‚cution ?
      jae  check0                                  ;non, teste la touche

       ;-- La macro est d‚j… en ex‚cution, passe au caractŠre suivant --

fct0p: push bx                                       ;BX va ˆtre modifi‚
       mov  bx,mofs                               ;Position du caractŠre
       mov  al,cs:[bx]                             ;Charge le code ASCII
       xor  ah,ah                                     ;0 comme Scan-Code
       inc  mofs                   ;MOFS pointe sur le caractŠre suivant
       pop  bx                                              ;R‚tablit BX

niret0:   iret                                      ;Retour … l'appelant

check0:                ;-- teste si la touche d'activation a ‚t‚ press‚e

      pushf                               ;Appelle l'ancien gestionnaire
      call cs:[ancint]
      cmp  ax,mkey               ;A-t-on frapp‚ la touche d'activation ?
      jne  niret0                              ;Non, retour … l'appelant

        ;-- La touche d'activation a ‚t‚ d‚tect‚e  ---------------------

      mov  mofs,offset mstart            ;Pointeur sur le d‚but du texte
      jmp  fct0p                           ;Renvoie le premier caractŠre

fct1:     ;-- fonction 01h/11h -----------------------------------------

      cmp  mofs,offset mend                            ;Macro termin‚e ?
      jae  check1                                     ;Non, teste touche

       ;-- La macro est d‚j… en ex‚cution, passe au caractŠre suivant --

fct1p: push bx                                       ;BX va ˆtre modifi‚
      mov  bx,mofs                                ;Position du caractŠre
      mov  al,cs:[bx]                              ;Charge le code ASCII
      xor  ah,ah                                      ;0 comme Scan-Code
      pop  bx                                               ;R‚tablit BX
      cmp  ah,1              ;Indicateur de z‚ro=0: caractŠre disponible

niret1:   ret 2                                ;Retour … l'appelant avec
                                                  ; nettoyage de la pile

check1: ;-- teste si la touche d'activation a ‚t‚ press‚e---------------

      pushf                               ;Appelle l'ancien gestionnaire
      call cs:[ancint]
      je   niret1               ;Pas de touche dans le buffer du clavier

      cmp  ax,mkey               ;A-t-on frapp‚ la touche d'activation ?
      je   check1a                                                  ;Oui

      cmp  ax,0          ;Indicateur de z‚ro = 0 : caractŠre  disponible
      ret 2 ;Retour … l'appelant;les indicateurs sont retir‚s de la pile

check1a:  ;-- Touche d'activation d‚tect‚e, ex‚cute la macro------------

      xor  ah,ah                          ;Retire la touche d'activation
      pushf
      call cs:[ancint]

      mov  mofs,offset mstart              ;Pointe sur le d‚but du texte
      jmp  fct1p                           ;renvoie le premier caractŠre

nouvi16    endp

;== Fin de la partie r‚sidente ===============

instend   equ this byte

;== Donn‚es (susceptibles d'ˆtre ‚cras‚es par DOS ) ====================

installm  db "MACROKEY  -  (c) 1992 by Michael Tischer", 13, 10, 13, 10
          db "Programme install‚ ", 13, 10
          db "Peut ˆtre d‚sactiv‚ par un nouvel appel"
          db 13, 10, "$"

retire  db "MACROKEY a ‚t‚ d‚sinstall‚.", 13, 10, "$"

;== Programme (susceptible d'ˆtre ‚cras‚ par DOS )======================

mkinit    label near                                     ;Initialisation

      assume cs:code, ds:code, es:code, ss:code

          ;-- teste d'abord si le programme a d‚j… ‚t‚ install‚     ----

      mov  ax,3516h        ;Lit le contenu du vecteur d'interruption 16h
      int  21h                               ;Appelle la fonction de DOS
      cmp  word ptr es:[bx+3],"TM"                   ;Teste si  MACROKEY
      jne  mkinstall                                ;a d‚j… ‚t‚ install‚

          ;-- Le programme a d‚j… ‚t‚ install‚ - Il faut le d‚sinstaller
                                         ;-- et le retirer de la m‚moire

      mov  dx,es:intancofs             ;Offset de l'interruption     16h
      mov  ax,es:intancseg                ;Segment de l'interruption 16h
      mov  ds,ax                                           ;charg‚ en DS
      mov  ax,2516h                   ;Remet la vieille routine  dans le
      int  21h                            ;vecteur de l'interruption 16h

          ;-- LibŠre la m‚moire de l'ancien MACROKEY       -------------

      mov  bx,es                       ;M‚morise le segment du programme
      mov  es,es:[2Ch]         ;Lit le segment environnement dans le PSP
      mov  ah,49h           ;LibŠre la m‚moire de l'ancien environnement
      int  21h

      mov  es,bx                               ;Exploite la fonction 49h
      mov  ah,49h                               ;pour lib‚rer la m‚moire
      int  21h                                     ;de l'ancien MACROKEY

      push cs                                                 ;Empile CS
      pop  ds                                    ;et le reprend comme DS

      mov  ah,09h                        ;Message: Programme d‚sinstall‚
      mov  dx,offset retire
      int  21h

      mov  ax,4C00h                                 ;Terminaison normale
      int  21h

mkinstall:  ;-- Installe le programme ----------------------------------

      mov  intancseg,es               ;M‚morise le segment et l'offset -
      mov  intancofs,bx                   ;du vecteur d'interruption 16h

      mov  dx,offset nouvi16               ;Offset nouvelle interruption
      mov  ax,2516h                              ;D‚tourne le vecteur de
      int  21h                                       ;l'interruption 16h

      mov  dx,offset installm              ;Message : Programme install‚
      mov  ah,09h                   ;Num‚ro fonction affichage la chaŒne
      int  21h                               ;Appelle la fonction de DOS

                 ;-- Seuls restent r‚sidents le PSP, la nouvelle routine
                           ;-- d'interruptioon et les donn‚es associ‚es.

      mov  dx,offset instend              ;Calcule le nombre paragraphes
      add  dx,15                                            ;n‚cessaires
      mov  cl,4                                                        ;
      shr  dx,cl
      mov  ax,3100h                 ;Termine le programme avec le code 0
      int  21h                                  ;en le laissant r‚sident

;== Fin ================================================================

code  ends                                       ;Fin du segment de CODE
      end  start

