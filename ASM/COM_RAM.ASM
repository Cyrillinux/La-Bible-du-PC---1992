;**********************************************************************;
;*                       C O M _ R A M . A S M                        *;
;*--------------------------------------------------------------------*;
;*    Fonction        : Outil de d‚veloppement de programmes COM en   *;
;*                      Assembleur avec le Turbo Assembleur TASM ou   *;
;*                      le Macro Assembler MASM de Microsoft          *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    : 07.06.1987                                    *;
;*    DerniŠre modif. : 10.10.1991                                    *;
;*--------------------------------------------------------------------*;
;*    D‚veloppement    : MASM:   masm com_ram;                        *;
;*                              link com_ram;                         *;
;*                              exe2bin com_ram.exe com_ram.com       *;
;*                                                                    *;
;*                       TASM:  tasm com_ram                          *;
;*                              tlink /t com_ram                      *;
;**********************************************************************;

com       segment para 'CODE'               ;D‚finition d'un segment COM
                                    ;(le nom peut ˆtre choisi librement)

          org 100h                    ;Le code commence … l'adresse 100h
                                           ;obligatoirement aprŠs le PSP

          assume cs:com, ds:com, es:com, ss:com

                                      ;Pendant l'ex‚cution du programme,
                                ;tous les registres de segment d‚signent
                                                         ;le segment COM

start:    jmp  init               ;Ici commence l'ex‚cution du programme
                                  ;Saut vers la routine d'initialisation

;== Donn‚es ============================================================

          ;-- Ici, vous pouvez mettre en place toutes les donn‚es, le --
                                          ;-- le buffer et les variables

                                                                    ;...
                                                                    ;...
                                                                    ;...

;== Programme principal ================================================

prog      proc near             ;Cette proc‚dure repr‚sente le programme
                       ;principal … proprement parler. Elle est ex‚cut‚e
                                       ;aprŠs le lancement du programme.

                 ;-- Ici, vous pouvez inclure le code programme du------
                                                 ;-- programme principal

                                                                    ;...
                                                                    ;...
                                                                    ;...

    ;--- Terminer le programme … l'aide de la fonction DOS 4Ch ---------

          mov  ax,4C00h  ;Charger le num‚ro de fonction, code d'erreur 0
          int  21h                                           ;Appels DOS

      ;--- Ici l'ex‚cution du programme n'a plus aucun sens parce que --
                       ;--- l'appel DOS pr‚c‚dent a mis fin au programme

prog      endp                               ;Fin du programme principal

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

;-- Initialisation ----------------------------------------------------
;-- Ici, toute la m‚moire est lib‚r‚e aprŠs le label FIN
;-- et la pile r‚organis‚e.

init:     mov  ah,4Ah         ;Nø fonc. pour "Changer la taille m‚moire"
          mov  bx,offset fin      ;Arrondir la longueur du programme aux
          add  bx,15               ;paragraphes suivants dans la m‚moire
          mov  cl,4                         ;Calculer l'adresse d'offset
          shr  bx,cl                                     ;en paragraphes
          inc  bx
          int  21h                 ;Appeler la fonction par l'inter. DOS

          mov  sp,offset fin                        ;R‚organiser la pile
          jmp  prog                  ;Sauter vers le programme principal

init_fin label near

;== Pile ==============================================================

          dw (256-((init_fin-init) shr 1)) dup (?)

                                   ;La pile comprend 256 mots et termine
                                 ;le code de la routine INIT qui devient
                                                      ;inutile aprŠs son
                                                              ;ex‚cution

fin      equ this byte            ;Fin de la m‚moire occup‚e, aucun code
                                               ;ne doit plus faire suite

;== Fin ===============================================================

com       ends                                       ;Fin du segment COM
          end  start             ;Fin du programme Assembleur. Commencer
                                   ;l'ex‚cution avec l'instruction START
