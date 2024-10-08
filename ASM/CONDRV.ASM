;**********************************************************************;
;*                              C O N D R V                           *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Ce programme constitue un driver de console    *;
;*                     (clavier et �cran) standard. Il pourra vous    *;
;*                     servir de base pour r�aliser un driver du style*;
;*                     de ANSI.SYS.                                   *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D�velopp� le   :  4.08.87                                       *;
;*    Derni�re MAJ   :  2.04.92                                       *;
;*--------------------------------------------------------------------*;
;*    Assemblage avec : MASM CONDRV;                                  *;
;*                      LINK CONDRV;                                  *;
;*                      EXE2BIN CONDRV CONDRV.SYS  ou                 *;
;*                                                                    *;
;*                      TASM CONDRV                                   *;
;*                      LINK CONDRV;                                  *;
;*                      EXE2BIN CONDRV CONDRV.SYS                     *;
;*--------------------------------------------------------------------*;
;*    Appel  : Copier le programme CONDRV.SYS dans le r�pertoire      *;
;*             racine, ajouter l'instruction DEVICE=CONDRV.SYS dans le*;
;*             fichier CONFIG.SYS et relancer le syst�me.             *;
;**********************************************************************;

code     segment

     assume cs:code,ds:code,es:code,ss:code

     org 0                               ;Programme sans PSP donc d�bute
                                                           ;� l'offset 0

;== Constantes =========================================================

inst     equ 2               ;Offset champ d'instr. dans bloc de donn�es
status   equ 3                 ;Offset champ d'�tat dans bloc de donn�es
adr_fin  equ 14       ;Offset adr. de fin du driver dans bloc de donn�es
nombre   equ 18                   ;Offset nombre dans le bloc de donn�es
adr_b    equ 14           ;Offset adresse de buffer dans bloc de donn�es

TA_CLA   equ 20                             ;Taille du buffer du clavier
nmb_ins  equ 16                    ;Sont support�es les fonctions 0 � 16

;== Donn�es ============================================================
;-- En-t�te du driver de p�riph�rique ----------------------------------

         dw -1,-1                           ;Lien avec le driver suivant
         dw 1010100000000011b                        ;Attribut du driver
         dw offset strat           ;Pointeur sur la routine de strat�gie
         dw offset intr          ;Pointeur sur la routine d'interruption
         db "CONDRV  "                        ;Nouveau driver de console

;-- Table de branchement pour les diff�rentes fonctions ----------------

tab_fct  dw offset init                    ;Fonction  0 : Initialisation
         dw offset dummy                  ;Fonction  1 : Test de support
         dw offset dummy           ;Fonction  2 : Cr�ation d'un bloc BPB
         dw offset no_sup                 ;Fonction  3 : Lecture directe
         dw offset lire                           ;Fonction  4 : Lecture
         dw offset lire_b  ;Fonction  5 : Lecture sans retrait du buffer
         dw offset dummy          ;Fonction  6 : Test de l'�tat d'entr�e
         dw offset del_b_en     ;Fonction  7 : Vidage du buffer d'entr�e
         dw offset ecrire                        ;Fonction  8 : Ecriture
         dw offset ecrire      ;Fonction  9 : Ecriture avec v�rification
         dw offset dummy         ;Fonction 10 : Test de l'�tat de sortie
         dw offset dummy       ;Fonction 11 : Vidage du buffer de sortie
         dw offset no_sup                ;Fonction 12 : Ecriture directe
         dw offset dummy      ;Fonction 13 : Ouverture (� partir de 3.0)
         dw offset dummy                        ;Fonction 14 : Fermeture
         dw offset dummy                 ;Fonction 15 : Support amovible
         dw offset ecrire       ;Fonction 16 : Sortie jusqu'� saturation

db_ptr   dw (?),(?)                 ;Adresse du bloc de donn�es transmis

d_cla    dw 0            ;Pointeur sur prochain car. dans buffer clavier
f_cla    dw 0             ;Pointeur sur dernier car. dans buffer clavier
bu_cla   db TA_CLA dup (?)                       ;Buffer clavier interne

;== Routines et fonctions du driver ====================================

strat    proc far                                  ;Routine de strat�gie

     mov  cs:db_ptr,bx               ;Range l'adresse du bloc de donn�es
     mov  cs:db_ptr+2,es                        ;dans la variable DB_PTR
     ret                                 ;Retourne au programme appelant

strat    endp

;-----------------------------------------------------------------------

intr     proc far                                ;Routine d'interruption

     push ax                            ;Sauve les registres sur la pile
     push bx
     push cx
     push dx
     push di
     push si
     push bp
     push ds
     push es
     pushf                  ;Range �galement le registre des indicateurs

     push cs                     ;Fixe le registre de segment de donn�es
     pop  ds                      ;Le code co�ncide ici avec les donn�es

     les  di,dword ptr db_ptr     ;Adresse du bloc de donn�es dans ES:DI
     mov  bl,es:[di+inst]            ;Va chercher  le code d'instruction
     cmp  bl,nmb_ins            ;Le code d'instruction est-il autoris� ?
     jle  bc_ok                                           ;OUI --> bc_ok

     mov  ax,8003h                          ;Code "instruction inconnue"
     jmp  short intr_end                ;Retourne  au programme appelant

     ;-- Le code d'instruction �tait correct --> ex�cute l'instruction -

bc_ok:
     shl  bl,1          ;Calcule le pointeur sur la table de branchement
     xor  bh,bh                                               ;Annule BH
     call [tab_fct+bx]                              ;Appelle la fonction
     les  di,dword ptr db_ptr     ;Adresse du bloc de donn�es dans ES:DI

     ;-- Ex�cution de la fonction termin�e -----------------------------

intr_end label near

     or   ax,0100h                               ;Met � 1 le bit Termin�
     mov  es:[di+status],ax     ;Sauvegarde le tout dans le champ d'�tat

     popf                          ;Restaure le registre des indicateurs
     pop  es                              ;Restaure les autres registres
     pop  ds
     pop  bp
     pop  si
     pop  di
     pop  dx
     pop  cx
     pop  bx
     pop  ax

     ret                                ;Retourne  au programme appelant

intr     endp

;-----------------------------------------------------------------------

dummy    proc near                           ;Cette routine ne fait rien

     xor  ax,ax                                    ;Annule le bit Occup�
     ret                                 ;Retourne au programme appelant

dummy    endp

;-----------------------------------------------------------------------

no_sup   proc near            ;Cette routine est appel�e pour toutes les
                                  ;fonctions qui sont en fait interdites

     mov  ax,8003h                        ;Erreur : instruction inconnue
     ret                                   ;Retour au programme appelant

no_sup   endp

;-----------------------------------------------------------------------

store_c  proc near               ;Sauvegarde un caract�re dans le buffer
                                                        ;clavier interne
                                                ;Entr�e : AL = caract�re
                                    ;         BX = position du caract�re

     mov  [bx+bu_cla],al      ;Place le caract�re dans le buffer interne
     inc  bl                            ;Augmente le pointeur sur la fin
     cmp  bl,TA_CLA                            ;Fin du buffer atteinte ?
     jne  store_e                                       ;NON --> STORE_E

     xor  bl,bl                         ;Nouvelle fin =  d�but du buffer

store_e:
     ret                                   ;Retour au programme appelant

store_c  endp

;-----------------------------------------------------------------------

lire    proc near              ;Charge un nombre d�termin� de caract�res
                                              ;du clavier dans un buffer

     mov  cx,es:[di+nombre]                    ;Lit nombre de caract�res
     jcxz lire_e                                     ;Teste si �gal �  0
     les  di,es:[di+adr_b]      ;Adresse du buffer de caract�re en ES:DI
     cld                                ;Si STOSB,  comptage incr�mental
     mov  si,d_cla         ;Pointe sur prochain car. dans buffer clavier
     mov  bx,f_cla          ;Pointe sur dernier car. dans buffer clavier

lire_1:
     cmp  si,bx             ;Encore des caract�res dans buffer clavier ?
     jne  lire_3                                         ;OUI --> LIRE_3

lire_2:
     xor  ah,ah                    ;Num�ro de la fonction de Lecture = 0
     int  16h                    ;Appelle l'interruption clavier du BIOS
     call store_c           ;Sauve les caract�res dans le buffer interne
     cmp  al,0                                     ;Teste si code �tendu
     jne  lire_3                                         ;non --> LIRE_3

     mov  al,ah                                       ;Code �tendu en AH
     call store_c                               ;Le sauvegarde �galement

lire_3:
     mov  al,[si+bu_cla]                ;Lit caract�re du buffer clavier
     stosb                 ;Transfert dans buffer de la fonction d'appel
     inc  si                ;Augmente le pointeur sur prochain caract�re
     cmp  si,TA_CLA                            ;Fin du buffer atteinte ?
     jne  lire_4                                         ;NON --> LIRE_4

     xor  si,si                    ;Le prochain caract�re est le premier
                                       ;caract�re dans le buffer clavier

lire_4:
     loop lire_1              ;R�p�te jusqu'� ce que tous caract�res lus
     mov  d_cla,si      ;Sauve la position du prochain caract�re dans le
                                                         ;buffer clavier
     mov  byte ptr f_cla,bl     ;Sauve pos. du dernier caract�re dans le
                                                         ;buffer clavier

lire_e:
     xor  ax,ax                                       ;Tout est en ordre
     ret                                   ;Retour au programme appelant

lire    endp

;-----------------------------------------------------------------------

lire_b  proc near                  ;Lit le prochain caract�re au clavier
                                          ;mais le laisse dans le buffer

     mov  ah,1                ;Num�ro de fonction pour interruption BIOS
     int  16h                    ;Appelle l'interruption clavier du BIOS
     je   lire_b1                          ;Pas de caract�re --> LIRE_B1

     mov  es:[di+13],al       ;Inscrit caract�re dans le bloc de donn�es
     xor ax,ax                                        ;Tout est en ordre
     ret                                   ;Retour au programme appelant

lire_b1 label near

     mov  ax,0100h             ;Met � 1 le bit occup� (pas de caract�re)
     ret                                   ;Retour au programme appelant

lire_b  endp

;-----------------------------------------------------------------------
del_b_en proc near                              ;Vide le buffer d'entr�e

     mov  ah,1               ;Fonction : encore caract�res dans buffer ?
     int  16h                    ;Appelle l'interruption clavier du BIOS
     je   del_e                ;Plus de caract�re dans le buffer --> FIN

     xor  ah,ah                  ;Fonction : retirer caract�re du buffer
     int  16h                    ;Appelle l'interruption clavier du BIOS
     jmp  short del_b_en                ;Teste si restent des caract�res

del_e:
     xor ax,ax                                        ;Tout est en ordre
     ret                                   ;Retour au programme appelant

del_b_en endp

;-----------------------------------------------------------------------

ecrire proc near              ;Affiche un nombre de caract�res d�termin�
                                                            ;sur l'�cran

     mov  cx,es:[di+nombre]                    ;Lit nombre de caract�res
     jcxz f_ecri                                      ;Teste si �gal � 0
     lds  si,es:[di+adr_b]    ;Adresse du buffer de caract�re dans DS:SI
     cld                                  ;Comptage incr�mental si LODSB

     mov  ah,3                                ;Lit page d'�cran courante
     int  16h                        ;Appelle interruption vid�o du BIOS

     mov  ah,14            ;Num�ro de fonction pour interruption du BIOS

ecri_1:
     lodsb                        ;Place le caract�re � afficher dans AL
     int  10h                      ;Appelle l'interruption vid�o du BIOS
     loop ecri_1           ;R�p�te jusqu'� ce que tous caract�res sortis

f_ecri:
     xor ax,ax                                        ;Tout est en ordre
     ret                                   ;Retour au programme appelant

ecrire endp

;-----------------------------------------------------------------------
init     proc near                             ;Routine d'initialisation

     mov  word ptr es:[di+adr_fin],offset init    ;Fixe l'adresse de fin
     mov  es:[di+adr_fin+2],cs                                ;du driver

     xor  ax,ax                                       ;Tout est en ordre
     ret                                ;Retourne  au programme appelant

init     endp

;=======================================================================

code     ends
         end

