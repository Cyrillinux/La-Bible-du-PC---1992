;**********************************************************************;
;*                       E X E _ R A M . A S M                        *;
;*--------------------------------------------------------------------*;
;*    Fonction        : Outil de d‚veloppement de programmes EXE en   *;
;*                     Assembleur avec le Turbo Assembleur TASM ou    *;
;*                     le Macro Assembler MASM de Microsoft           *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le   :  7.06.1987                                     *;
;*    DerniŠre modif. : 10.10.1991                                    *;
;*--------------------------------------------------------------------*;
;*    D‚veloppement    : MASM: masm exe_ram;                          *;
;*                             link exe_ram;                          *;
;*                                                                    *;
;*                     TASM:   tasm exe_ram                           *;
;*                             tlink exe_ram                          *;
;**********************************************************************;

;== Pile ==============================================================

stackseg  segment para STACK 'STACK'      ;D‚finition du segment de pile

          dw 256 dup (?)                      ;La pile comprend 256 mots

stackseg  ends                                   ;Fin du segment de pile

;== Donn‚es ============================================================

data      segment para 'DATA'          ;D‚finition du segment de donn‚es

                 ;-- Ici vous pouvez mettre en place toutes les donn‚es,
                                          ;-- le buffer et les variables

                                                                    ;...
                                                                    ;...
                                                                    ;...

data      ends                                ;Fin du segment de donn‚es

;== Code ===============================================================

code      segment para 'CODE'             ;D‚finition du segment de code

          assume cs:code, ds:data, ss:stackseg

                          ;CS concerne le segment de code, DS le segment
                                   ;de donn‚es et SS le segment de pile.
                                                   ;ES peut ˆtre utilis‚
                                                             ;librement.

prog      proc far              ;Cette proc‚dure repr‚sente le programme
                       ;principal … proprement parler. Elle est ex‚cut‚e
                                       ;aprŠs le lancement du programme.

                    ;-- A ce niveau, CS et SS sont d‚j… initialis‚s. ---
         ;-- Il ne reste plus qu'… initialiser DS … la main, parce qu'il
                                       ;-- d‚signe le PSP tout comme ES.

          mov  ax,data       ;Charger l'adresse de segment du segment de
          mov  ds,ax                        ;donn‚es dans le registre DS

          call setfree                ;Lib‚rer la m‚moire non n‚cessaire

         ;-- Ici vous pouvezÿinclure le code programme du programme-----
                                                           ;-- principal

                                                                    ;...
                                                                    ;...
                                                                    ;...

        ;--- Terminer le programme … l'aide de la fonction 4Ch ---------

          mov  ax,4C00h  ;Charger le num‚ro de fonction, code d'erreur 0
          int  21h                                           ;Appels DOS

      ;--- Ici l'ex‚cution du programme n'a plus aucun sens parce que --
                       ;--- l'appel DOS pr‚c‚dent a mis fin au programme

prog      endp                                 ;Fin de la proc‚dure PROG

;-- Sous-routines ------------------------------------------------------
;-- Cette place est r‚serv‚e aux sous-routines du programme

a_proc    proc near
                                                                    ;...
                                                                    ;...
                                                                    ;...
          ret

a_proc    endp

b_proc    proc near

                                                                    ;...
                                                                    ;...
                                                                    ;...
          ret

b_proc    endp

;-- SETFREE: Lib‚rer la place m‚moire non occup‚e ----------------
;-- Entr‚e  : ES = Adresse du PSP
;-- Sortie  : Aucune
;-- Register : AX, BX, CL et les FLAGS sont modifi‚s
;-- Infos   : Comme le segment de pile est toujours le dernier segment
;             d'un  fichier EXE, ES:0000 d‚signe le d‚but du programme
;             dans la m‚moire et SS:SP la fin. Cela permet donc de
;             calculer la longueur du programme
setfree   proc near

          mov  bx,ss      ;Calculer l'intervalle entre le PSP et la pile
          mov  ax,es                                     ;en paragraphes
          sub  bx,ax

          mov  ax,sp                      ;Calculer l'‚tat de la pile en
          add  ax,15                                     ;en paragraphes
          mov  cl,4
          shr  ax,cl                       ;Contenu, longueur de la pile

          add  bx,ax                           ;Ajouter les deux valeurs

          mov  ah,4ah                   ;Seule cette m‚moire doit rester
          int  21h                                             ;r‚serv‚e

          ret                               ;Retour au programme d'appel

setfree   endp

;== Fin ===============================================================

code      ends                                   ;Fin du segment de code
          end  prog                       ;Commencer l'ex‚cution avec la
                                                         ;proc‚dure PROG

