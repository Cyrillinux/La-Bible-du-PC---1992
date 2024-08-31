;**********************************************************************;
;*                            H E U R E A T                           *;
;*--------------------------------------------------------------------*;
;*    Fonction : Ce programme est un driver d'horloge                 *;
;*               permettant … DOS d'acc‚der … l'horloge sur piles     *;
;*               pour toutes les fonctions de date et d'heure         *;
;*--------------------------------------------------------------------*;
;*    Auteur       : MICHAEL TISCHER                                  *;
;*    D‚velopp‚ le : 04.08.1987                                       *;
;*    DerniŠre MAJ : 03.03.1992                                       *;
;*--------------------------------------------------------------------*;
;*    Assemblage   : MASM HEUREAT;                                    *;
;*                   LINK HEUREAT;                                    *;
;*                   EXE2BIN HEUREAT HEEREAT.SYS    ou                *;
;*                                                                    *;
;*                   TASM HEUREAT                                     *;
;*                   LINK HEUREAT;                                    *;
;*                   EXE2BIN HEUREAT HEUREAT.SYS                      *;
;*--------------------------------------------------------------------*;
;*    Appel   : Copier le programme .SYS dans le r‚pertoire racine,   *;
;*              ajouter l'instruction DEVICE=HEUREAT.SYS dans le      *;
;*              fichier CONFIG.SYS puis relancer le systŠme.          *;
;**********************************************************************;

code     segment

     assume cs:code,ds:code,es:code,ss:code

     org 0                                     ;Programme sans PSP, donc
                                                   ;d‚bute  … l'offset 0

;== Constantes =========================================================

inst     equ 2               ;Offset champ d'instr. dans bloc de donn‚es
status   equ 3                 ;Offset champ d'‚tat dans bloc de donn‚es
adr_fin  equ 14       ;Offset adr. de fin du driver dans bloc de donn‚es
nombre   equ 18                      ;Offset nombre dans bloc de donn‚es
adr_b    equ 14           ;Offset adresse de buffer dans bloc de donn‚es

;== Donn‚es ============================================================

;-- En-tˆte du driver de p‚riph‚rique ----------------------------------

         dw -1,-1                           ;Lien avec le driver suivant
         dw 1000000000001000b                        ;Attribut du driver
         dw offset strat           ;Pointeur sur la routine de strat‚gie
         dw offset intr          ;Pointeur sur la routine d'interruption
         db "$CLOCK    "                       ;Nouveau driver d'horloge

db_ptr   dw (?),(?)                 ;Adresse du bloc de donn‚es transmis

tb_mois  db 31                       ;Table indiquant le nombre de jours
fevrier  db 28                                           ;de chaque mois
         db 31,30,31,30,31,31,30,31,30,31

;== Routines et fonctions du driver ====================================

strat    proc far                                  ;Routine de strat‚gie

     mov  cs:db_ptr,bx          ;Range l'adresse du bloc de donn‚es dans
     mov  cs:db_ptr+2,es                             ;la variable DB_PTR

     ret                                   ;Retour au programme appelant

strat    endp

;-----------------------------------------------------------------------

intr     proc far                                ;Routine d'interruption

     push ax                           ;Sauve  les registres sur la pile
     push bx
     push cx
     push dx
     push di
     push si
     push bp
     push ds
     push es
     pushf                       ; y compris le registre des indicateurs

     cld                      ;Fixe le sens d'incr‚mentation des chaŒnes

     push cs                     ;Fixe le registre de segment de donn‚es
     pop  ds                      ;Le code co‹ncide ici avec les donn‚es

     les  di,dword ptr db_ptr       ;Adresse du bloc de donn‚es en ES:DI
     mov  bl,es:[di+inst]                ;Va chercher code d'instruction
     cmp  bl,4                        ;Faut-il lire l'heure et la date ?
     je   lire_dh                                       ;OUI --> LIRE_DH
     cmp  bl,8                      ;Faut-il r‚gler la date et l'heure ?
     je   ecri_dh                                       ;OUI --> ECRI_DH
     or   bl,bl                         ;Faut-il initialiser le driver ?
     jne  fct_inc                             ;NON --> Fonction inconnue

     jmp  init                                     ;Initialise le driver

fct_inc: mov  ax,8003h                 ;Code pour "instruction inconnue"

     ;-- Ex‚cution de la fonction termin‚e -----------------------------

intr_end label near
     or   ax,0100h                              ;Fixe … 1 le bit Termin‚
     mov  es:[di+status],ax     ;Sauvegarde le tout dans le champ d'‚tat

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

     ret                                   ;Retour au programme appelant

intr     endp

;-----------------------------------------------------------------------

lire_dh label near               ;Lite la date et l'heure dans l'horloge

     mov  byte ptr es:[di+nombre],6                   ;6 octets transmis
     les  di,es:[di+adr_b]               ;ES:DI d‚signe le buffer de DOS

     mov  ah,4                        ;Num‚ro de la fonction "lire date"
     int  1Ah                    ;Appelle l'interruption horloge du BIOS
     call date_ofs        ;Convertit la date en offset aprŠs le 1.1.1980
     stosw                                       ;Sauvegarde dans buffer

     mov  ah,2                     ;Num‚ro de la fonction "lire l'heure"
     int  1Ah                    ;Appelle l'interruption horloge du BIOS
     mov  bl,ch                                ;Range les heures dans BL
     call bcd_bin                                  ;Convertit en minutes
     stosb                                       ;Sauvegarde dans buffer
     mov  cl,bl                                             ;Heure en CL
     call bcd_bin                                     ;Convertit l'heure
     stosb                                       ;Sauvegarde dans buffer
     xor  al,al                                   ;0 centiŠme de seconde
     stosb                                      ;Sauvegarde  dans buffer
     mov  cl,dh                                          ;Secondes en CL
     call bcd_bin                                  ;Convertit les heures
     stosb                                       ;Sauvegarde dans buffer

     xor  ax,ax                                       ;Tout est en ordre
     jmp  short intr_end                   ;Retour au programme appelant

;-----------------------------------------------------------------------

ecri_dh  label near             ;Ecrit la date et l'heure dans l'horloge

     mov  byte ptr es:[di+nombre],6                   ;6 octets transmis
     les  di,es:[di+adr_b]               ;ES:DI d‚signe le buffer de DOS

     mov  ax,es:[di]               ;Cherche le nombre de jours depuis le
     push ax                               ;1.1.1980, m‚morise ce nombre
     call ofs_date                              ;et le convertit en date
     mov  ch,19h                              ;L'ann‚e commence par 19..
     mov  ah,5                    ;Num‚ro de la fonction "fixer la date"
     int  1AH                    ;Appelle l'interruption horloge du BIOS
     mov  al,es:[di+2]               ;Cherche les minutes dans le buffer
     call bin_bcd                                  ;Les convertit en BCD
     mov  cl,al                                    ;et les place dans CL
     mov  al,es:[di+5]              ;Cherche les secondes dans le buffer
     call bin_bcd                                  ;Les convertit en BCD
     mov  dh,al                                     ;et les placer en DH
     mov  al,es:[di+3]                ;Cherche les heures dans le buffer
     call bin_bcd                                  ;Les convertit en BCD
     mov  ch,al                                    ;et les place dans CH
     xor  dl,dl                                       ;Pas d'heure d'‚t‚
     mov  ah,3                    ;Num‚ro de la fonction "Fixer l'heure"
     int  1AH                    ;Appelle l'interruption horloge du BIOS

     ;-- Calcule le jour de la semaine ---------------------------------
     xor  dx,dx                               ;Mot fort pour la division
     pop  ax                       ;Retire de la pile le nombre de jours
     or   ax,ax                                    ;Ce nombre est-il 0 ?
     je   nodiv                                 ;OUI --> pas de division
     xor  dx,dx                               ;Mot fort pour la division
     mov  cx,7                              ;Sept jours dans une semaine
     div  cx                                            ;Divise AX par 7
nodiv:
     add  dl,3                        ;Le 1.1.80 ‚tait un Mardi (Jour 3)
     cmp  dl,8                          ;Sommes-nous Dimanche ou Lundi ?
     jb   nosomo                   ;NON --> aucune correction n‚cessaire
     sub  dl,cl                                       ;Corrige la valeur
nosomo:
     mov  al,6                      ;Octet 6 du RTC = jour de la semaine
     out  70h,al  ;Envoie l'adresse au registre d'adresse du circuit RTC
     mov  al,dl                      ;Charge le jour de la semaine en AL
     out  71h,al            ;Envoie le jour de la semaine au registre de
                                                 ;donn‚es du circuit RTC

     xor  ax,ax                                       ;Tout est en ordre
     jmp  intr_end                         ;Retour au programme appelant

;-- OFS_DATE: Convertit en date le nombre de jours depuis le 1.1.1980 --
;-- Entr‚e  : AX = Nombre de jours depuis le 1.1.1980
;-- Sorties  : CL = Ann‚e, DH = Mois et DL = Jour
;-- Registres : AX, BX, CX, DX, SI et les indicateurs sont modifi‚s
;-- Infos    : La conversion de l'offset se fait en acc‚dant au tableau
;--            TB_MOIS

ofs_date proc near

     mov  cl,80                                 ;Partir de l'ann‚e 1980,
     mov  dh,01                                      ;du mois de janvier
an:  mov  bx,365                 ;Nombre de jours dans une ann‚e normale
     test cl,3                            ;Est-ce une ann‚e bissextile ?
     jne  an1                                               ;NON --> an1
     inc  bl                  ;L'ann‚e bissextile compte un jour de plus
an1: cmp  ax,bx                              ;Encore une ann‚e ‚coul‚e ?
     jb   mo                                    ;NON --> calcule le mois
     inc  cl                                   ;OUI --> augmente l'ann‚e
     sub  ax,bx             ;Retranche le nombre de jours de cette ann‚e
     jmp  short an                             ;Calcule l'ann‚e suivante

mo:      mov  bl,28             ;Jours de f‚vrier pour une ann‚e normale
     test cl,11b                          ;Est-ce une ann‚e bissextile ?
     jne  pasbis2                                       ;NON --> PASBIS2
     inc  bl              ;Dans une ann‚e bissextile, f‚vrier a 29 jours
pasbis2:
     mov  fevrier,bl                ;Sauve le nombre de jours en f‚vrier

     mov  si,offset tb_mois                ;Adresse de la table des mois
     xor  bh,bh                    ;Tous les mois ont moins de 256 jours
mo1: mov  bl,[si]           ;Va chercher le nombre de jours dans le mois
     cmp  ax,bx                                 ;Encore un mois ‚coul‚ ?
     jb   jou                                   ;NON --> calcule le jour
     sub  ax,bx                     ;OUI --> retranche les jours du mois
     inc  dh                                           ;Augmente le mois
     inc  si                 ;SI pointe sur le prochain mois de la table
     jmp  short mo1                             ;Calcule le mois suivant

jou: inc  al                                 ;Le reste + 1 donne le jour
     call bin_bcd                              ;Convertit le jour en BCD
     mov  dl,al                               ;TransfŠre le jour dans DL
     mov  al,dh                               ;TransfŠre le mois dans AL
     call bin_bcd                                      ;Convertit en BCD
     mov  dh,al                                            ;RamŠne en DH
     mov  al,cl                                 ;TransfŠre l'ann‚e en AL
     call bin_bcd                                      ;Convertit en BCD
     mov  cl,al                                            ;RamŠne en CL

     ret                                   ;Retour au programme appelant

ofs_date endp

;-- BIN_BCD: Convertit un nombre binaire en BCD ------------------------
;-- Entr‚e  : AL = valeur binaire
;-- Sortir  : AL = valeur BCD correspondante
;-- Registres : AX, CX et les indicateurs sont modifi‚s

bin_bcd  proc near

     xor  ah,ah                        ;Pr‚pare une division sur 16 bits
     mov  ch,10                     ;Nous travaillons en systŠme d‚cimal
     div  ch                                           ;Divise AX par 10
     shl  al,1           ;D‚cale le quotient de 4 chiffres sur la gauche
     shl  al,1
     shl  al,1
     shl  al,1
     or   al,ah                                         ;Masque le reste
     ret                                   ;Retour au programme appelant

bin_bcd  endp

;-- DATE_OFS: Convertit une date en nombre de jours depuis le 1.1.1980 -
;-- Entr‚e  : CL = Ann‚e, DH = Mois et DL = Jour
;-- Sorties  : AX = Nombre de jours depuis le 1.1.1980
;-- Registres : AX, BX, CX, DX, SI et FLAGS sont modifi‚s
;-- Infos : La conversion de la date se fait avec TB_MOIS

date_ofs proc near

     call bcd_bin                          ;Convertit l'ann‚e en binaire
     mov  bl,al                          ;et transfŠre le r‚sultat en BL
     mov  cl,dh                               ;TransfŠre le mois dans CL
     call bcd_bin                          ;Convertit le mois en binaire
     mov  dh,al                                      ;et le ramŠne en DH
     mov  cl,dl                               ;TransfŠre le jour dans CL
     call bcd_bin                          ;Convertit le jour en binaire
     mov  dl,al                                    ;et la ramŠne dans DL

     xor  ax,ax                                                  ;0 jour
     mov  ch,bl                                        ;M‚morise l'ann‚e
     dec  bl                               ;Revient une ann‚e en arriŠre
annee:
     cmp  bl,80                         ;D‚compt‚ jusqu'… l'ann‚e 1980 ?
     jb   mois                                ;OUI --> convertit le mois
     test bl,11b                          ;Est-ce une ann‚e bissextile ?
     jne  pasbis                                         ;NON --> PASBIS
     inc  ax                ;Une ann‚e bissextile compte un jour de plus
pasbis:
     add  ax,365                            ;Ajoute les jours de l'ann‚e
     dec  bl                               ;Revient une ann‚e en arriŠre
     jmp  short annee                         ;Traite l'ann‚e pr‚c‚dente

mois:
     mov  bl,28                 ;Jours de f‚vrier dans une ann‚e normale
     test ch,11b                          ;Est-ce une ann‚e bissextile ?
     jne  pasbis1                                       ;NON --> PASBIS1
     inc  bl              ;Dans une ann‚e bissextile, f‚vrier a 29 jours
pasbis1:
     mov  fevrier,bl                  ;Sauvegarde dans la table des mois
     xor  ch,ch                    ;Tous les mois ont moins de 256 jours
     mov  bx,offset tb_mois                ;Adresse de la table des mois
mois1:
     dec  dh                                  ;Diminue le nombre de mois
     je   jour                  ;Tous les mois ont ‚t‚ calcul‚s --> JOUR
     mov  cl,[bx]           ;Va chercher le nombre de jours dans le mois
     add  ax,cx                     ;Additionne au nombre total de jours
     inc  bx                 ;BX pointe sur le prochain mois de la table
     jmp  short mois1                           ;Calcule le mois suivant

jour:
     add  ax,dx                                   ;Ajoute le jour actuel
     dec  ax                             ;Retranche un jour (1.1.80 = 0)
     ret                                   ;Retour au programme appelant

date_ofs  endp

;-- BCD_BIN: Convertit un nombre BCD en nombre binaire -----------------
;-- Entr‚e  : CL = valeur BCD
;-- Sortie  : AL = valeur binaire correspondante
;-- Registres : AX, CX et les indicateurs sont modifi‚s

bcd_bin  proc near    ;Convertt une valeur BCD dans CL en son ‚quivalent
                                   ;binaire et renvoie le r‚sultat en AL

     mov  al,cl                             ;TransfŠre la valeur dans AL
     shr  al,1         ;Effectue un d‚calage de 4 chiffres sur la droite
     shr  al,1
     shr  al,1
     shr  al,1
     xor  ah,ah                                              ;Mat AH … 0
     mov  ch,10                     ;Nous travaillons en systŠme d‚cimal
     mul  ch                                        ;Multiplie AX par 10
     mov  ch,cl                                    ;TransfŠre CL dans CH
     and  ch,1111b                        ;Met … 0 le quartet fort de CH
     add  al,ch                                     ;Additionne AL et CH
     ret                                   ;Retour au programme appelant

bcd_bin  endp

;-----------------------------------------------------------------------

init     proc near                             ;Routine d'initialisation

     ;-- Le code suivant peut ˆtre effac‚ par DOS aprŠs ----------------
     ;-- installation de l'horloge -------------------------------------

     mov  word ptr es:[di+adr_fin],offset init    ;Fixe l'adresse de fin
     mov  es:[di+adr_fin+2],cs                                ;du driver

     mov  ah,9                        ;Affiche le message d'installation
     mov  dx,offset initm                              ;Adresse du texte
     int  21h                             ;Appelle l'interruption du DOS

     xor  ax,ax                                       ;Tout est en ordre
     jmp  intr_end                         ;Retour au programme appelant

initm    db 13,10,"**** HEUREAT install‚. (c) 1987, 92 by"
         db " Michael TISCHER",13,10,"$"

init     endp

;-----------------------------------------------------------------------

code     ends
         end

