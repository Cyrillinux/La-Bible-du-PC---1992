;**********************************************************************;
;*                            S O U N D                               *;
;*--------------------------------------------------------------------*;
;*    Fonction       : sort la gamme chromatique de l'octave 3 …      *;
;*                     l'octave 5 … l'aide d'une routine universelle  *;
;*                     de g‚n‚ration de sons.                         *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    d‚velopp‚ le   : 06.08.1987                                     *;
;*    DerniŠre modif.: 16.02.1992                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM SOUNDA;                                   *;
;*                     LINK SOUNDA;                                   *;
;*                     EXE2BIN SOUNDA SOUNDA.COM       ou             *;
;*                     TASM SOUNDA                                    *;
;*                     TLINK /t SOUNDA                               *;
;*--------------------------------------------------------------------*;
;*    Appel          : SOUND                                          *;
;**********************************************************************;

code      segment para 'CODE'             ;D‚finition du segment de CODE

          org 100h                       ;Il commence … l'adresse 100(h)
                                          ;directement … la suite du PSP

          assume cs:code, ds:code, es:code, ss:code

;== Programme ==========================================================

sound     proc near

          ;-- Sortir message -------------------------------------------

          mov  ah,9               ;Num‚ro de fonction pour Sortir chaŒne
          mov  dx,offset initm              ;Adresse d'offset du message
          int  21h                          ;Appeler interruption du DOS

          ;-- Jouer gammes chromatiques --------------------------------
          xor  bl,bl         ;Commencer par le Do de la troisiŠme octave
          mov  dl,9                 ;Jouer une demie seconde chaque fois
nextune:  call play_tune                                     ;Jouer note
          inc  bl                                         ;Note suivante
          cmp  bl,36           ;Toutes notes trois octaves d‚j… jou‚es ?
          jne  nextune                      ;NON --> Jouer note suivante

          ;-- Sortir message de fin ------------------------------------

          mov  ah,9               ;Num‚ro de fonction pour Sortir chaŒne
          mov  dx,offset endmes             ;Adresse d'offset du message
          int  21h                          ;Appeler interruption du DOS

          mov  ax,4C00h              ;Terminer programme par appel d'une
          int  21h                         ;fonction DOS en renvoyant le
                                                        ;code d'erreur 0

sound     endp
;== Donn‚es du programme principal =====================================

initm     db 13,10,"SOUND (c) 1987 by Michael Tischer",13,10,13,10
          db "Si le haut-parleur de votre PC fonctionne correctement, "
          db "vous allez entendre",13,10,"maintenant la gamme chro"
          db "matique des octaves 3 … 5.",13,10,"$"

endmes    db 13,10,"Fin",13,10,"$"

;-- PLAY_TUNE: Jouer une note ------------------------------------------
;-- Entr‚e   : BL = Num‚ro de note par rapport au Do troisiŠme octave
;--            DL = Dur‚e de note en 1/18Šmes de seconde
;-- Sortie   : Aucune
;-- Registres: AX, CX, ES et FLAGS sont modifi‚s
;-- Infos    : Le contr“le n'est rendu … la routine d'appel qu'une
;--            fois la dur‚e de note ‚coul‚e

play_tune proc near
          push dx                           ;Ranger DX et BX sur la pile
          push bx

        ;-- D‚tourner interruption temporisateur sur routine utilisateur
          push dx                           ;Ranger DX et BX sur la pile
          push bx
          mov  ax,351ch    ;Lire adresse de l'interruption temporisateur
          int  21h                          ;Appeler interruption du DOS
          mov  time_anc,bx  ;Adresse d'offset de l'ancienne interruption
          mov  time_anc+2,es               ;et ranger adresse de segment

          mov  dx,offset sound_ti;Adresse offset nouvelle routine tempo.
          mov  ax,251ch            ;Fixer nouvelle routine temporisateur
          int  21h                          ;Appeler interruption du DOS
          pop  bx                           ;Retirer BX et DX de la pile
          pop  dx

          mov  al,182                      ;Pr‚parer g‚n‚ration d'un son
          out  43h,al          ;Envoyer valeur au Timer Command Register
          xor  bh,bh                  ;BH pour adressage table notes = 0
          shl  bx,1                 ;Doubler nø note (car table de mots)
          mov  ax,[notes+bx]                        ;Lire valeur de note
          out  42h,al          ;Octet faible dans Timer Counter Register
          mov  al,ah                      ;Transf‚rer octet fort dans AL
          out  42h,al              ;et aussi dans Timer Counter Register
          in   al,61h              ;Lire bit de contr“le du haut-parleur
          or   al,11b        ;Deux bits inf‚rieurs activent haut-parleur
          mov  fin_s,1                      ;Note doit encore ˆtre jou‚e
          mov  compteur_s,dl                       ;Sauver dur‚e de note
          out  61h,al                              ;Activer haut-parleur

play:     cmp  fin_s,0                                  ;Note termin‚e ?
          jne  play                             ;NON --> Attendre encore

          in   al,61h              ;Lire bit de contr“le du haut-parleur
          and  al,11111100b                ;Annuler deux bits inf‚rieurs
          out  61h,al                           ;D‚sactiver haut-parleur

          ;-- Activer … nouveau ancienne interruption temporisateur ----

          mov cx,ds                                           ;Ranger DS
          mov ax,251ch      ;Nø fonct. pour Fixer vecteur d'interruption
          lds dx,dword ptr time_anc ;Charger ancienne adresse dans DS:DX
          int 21h                           ;Appeler interruption du DOS
          mov ds,cx                                          ;Ramener DS

          pop  bx                           ;Retirer BX et DX de la pile
          pop  dx
          ret                               ;Retour au programme d'appel

play_tune endp

;-- Nouvelle interruption temporisateur --------------------------------

sound_ti  proc far                      ;Est appel‚e 18 fois par seconde

          dec  cs:compteur_s                       ;D‚cr‚menter compteur
          jne  fin_st                        ;Si pas encore 0, alors fin
          mov  cs:fin_s,0                ;Signaler dur‚e de note ‚coul‚e
fin_st:   jmp  dword ptr cs:[time_anc] ;Vers ancienne interruption tempo

sound_ti  endp

;== Voici les variables dont ont besoin les quatre routines ============

time_anc  dw (?),(?)         ;Adresse de l'ancienne interruption tempor.
compteur_s db (?)                          ;Dur‚e restante d'une note en
                                                    ;1/18Šmes de seconde
fin_s    db (?)                        ;Indique si note a d‚j… ‚t‚ jou‚e
notes    dw 9121,8609,8126,7670        ;Valeurs de notes pour l'octave 3
          dw 7239,6833,6449,6087
          dw 5746,5423,5119,4831
          dw 4560,4304,4063,3834       ;Valeurs de notes pour l'octave 4
          dw 3619,3416,3224,3043
          dw 2873,2711,2559,2415
          dw 2280,2152,2031,1917       ;Valeurs de notes pour l'octave 5
          dw 1809,1715,1612,1521
          dw 1436,1355,1292,1207

;== Fin ================================================================

code      ends                                   ;Fin du segment de CODE
          end  sound                        ;Fin du programme assembleur
