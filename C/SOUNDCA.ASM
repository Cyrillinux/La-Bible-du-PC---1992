;**********************************************************************;
;*                            S O U N D C A                           *;
;*--------------------------------------------------------------------*;
;*    Fonction       : fournit une fonction … int‚grer en C pour      *;
;*                     jouer les notes des octaves 3, 4 et 5.         *;
;*                                                                    *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    d‚velopp‚ le   : 15.08.1987                                     *;
;*    DerniŠre modif.: 16.02.1991                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM -mx SOUNDCA;                              *;
;*                     ... puis lier … SOUNDC                         *;
;**********************************************************************;

IGROUP group _text               ;Regroupement des segments de programme
DGROUP group const,_bss,  _data    ;Regroupement des segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

       public _Sound                         ;Fonction rendue accessible
                                                  ;aux autres programmes

CONST  segment word public 'CONST'  ;Ce segment re‡oit toutes constantes
CONST  ends                             ;qui peuvent seulement ˆtre lues

_BSS   segment word public 'BSS' ;Ce segment re‡oit toutes les variables
_BSS   ends                                  ;statiques non initialis‚es

_DATA  segment word public 'DATA'      ;Toutes les variables globales et
                                     ;statiques initialis‚es sont log‚es
                                                        ;dans ce segment

time_anc  dw (?),(?)        ;Adresse ancienne interruption temporisateur
compteur_s db (?)                          ;Dur‚e restante d'une note en
                                                    ;1/18Šmes de seconde

fin_s    db (?)                        ;Indique si note a d‚j… ‚t‚ jou‚e
notes     dw 9121,8609,8126,7670       ;Valeurs de notes pour l'octave 3
          dw 7239,6833,6449,6087
          dw 5746,5423,5119,4831
          dw 4560,4304,4063,3834       ;Valeurs de notes pour l'octave 4
          dw 3619,3416,3224,3043
          dw 2873,2711,2559,2415
          dw 2280,2152,2031,1917       ;Valeurs de notes pour l'octave 5
          dw 1809,1715,1612,1521
          dw 1436,1355,1292,1207

_DATA  ends

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'               ;Le segment de programme

;-- SOUND: Jouer une note ----------------------------------------------
;-- Appel en C  : Sound((int) Note, (int) Dur‚e);
;-- Sortie      : Aucune
;-- Infos       : La note est le num‚ro de la note par rapport au Do
;--               de la troisiŠme octave
;--               Dur‚e est dur‚e de note en 1/18Šmes de seconde

_Sound    proc near

          push bp                                 ;Ranger BP sur la pile
          mov  bp,sp                              ;Transf‚rer SP dans BP

        ;-- D‚tourner interruption temporisateur sur routine utilisateur
          mov  word ptr cs:setds+1,ds ;Sauver DS pour interrupt. tempor.
          mov  ax,351ch    ;Lire adresse de l'interruption temporisateur
          int  21h                          ;Appeler interruption du DOS
          mov  time_anc,bx  ;Adresse d'offset de l'ancienne interruption
          mov  time_anc+2,es               ;et ranger adresse de segment
          mov  word ptr cs:stjump+1,bx ;Pour nouvelle interrupt. tempor.
          mov  word ptr cs:stjump+3,es                      ;Sauvegarder
          mov  bx,ds                                  ;Ranger DS dans BX
          push cs                                  ;Amener pile sur pile
          pop  ds                                    ;et retirer pour DS
          mov  dx,offset sound_ti;Adresse offset nouvelle routine tempo.
          mov  ax,251ch            ;Fixer nouvelle routine temporisateur
          int  21h                          ;Appeler interruption du DOS
          mov  ds,bx                                       ;Restaurer DS

          mov  al,182                      ;Pr‚parer g‚n‚ration d'un son
          out  43h,al          ;Envoyer valeur au Timer Command Register

          mov  bx,[bp+4]                                      ;Lire note
          xor  bh,bh                  ;BH pour adressage table notes = 0
          shl  bx,1                 ;Doubler nø note (car table de mots)
          mov  ax,[notes+bx]                        ;Lire valeur de note
          out  42h,al          ;Octet faible dans Timer Counter Register
          mov  al,ah                      ;Transf‚rer octet fort dans AL
          out  42h,al              ;et aussi dans Timer Counter Register
          in   al,61h              ;Lire bit de contr“le du haut-parleur
          or   al,11b        ;Deux bits inf‚rieurs activent haut-parleur
          mov  fin_s,1                      ;Note doit encore ˆtre jou‚e
          mov  dl,[bp+6]                             ;Lire dur‚e de note
          mov  compteur_s,dl                             ;et sauvegarder
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

          mov  sp,bp                         ;Restaurer pointeur de pile
          pop  bp                                 ;Retirer BP de la pile
          ret                               ;Retour au programme d'appel

_Sound    endp

;-- Nouvelle interruption temporisateur --------------------------------

sound_ti  proc far                      ;Est appel‚e 18 fois par seconde

          push ax                           ;Ranger AX et DS sur la pile
          push ds
setds:    mov  ax,0000h         ;C'est ici que doit ˆtre inscrit le DS C
          mov  ds,ax
          dec  compteur_s                          ;D‚cr‚menter compteur
          jne  fin_st                        ;Si pas encore 0, alors fin
          mov  fin_s,0                   ;Signaler dur‚e de note ‚coul‚e
fin_st:  pop  ds                              ;Fixer … nouveau ancien DS
          pop  ax                           ;Retirer aussi AX de la pile

stjump:   db   0EAh,0,0,0,0 ;FAR JUMP vers l'ancienne interruption tempor.

sound_ti  endp

;== Fin ================================================================

_text    ends                     ;Fin du segment de programme
         end                      ;Fin du source assembleur
