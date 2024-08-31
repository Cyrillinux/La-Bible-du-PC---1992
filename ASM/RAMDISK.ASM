;**********************************************************************;
;*                            R A M D I S K                           *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Ce programme est un driver pour disque virtuel *;
;*                     de 160 Ko                                      *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   :  4.08.1987                                     *;
;*    DerniŠre MAJ   :  2.04.1992                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM RAMDISK;                                  *;
;*                     LINK RAMDISK;                                  *;
;*                     EXE2BIN RAMDISK RAMDISK.SYS    ou              *;
;*                                                                    *;
;*                     TASM RAMDISK                                   *;
;*                     LINK RAMDISK;                                  *;
;*                     EXE2BIN RAMDISK RAMDISK.SYS                    *;
;*--------------------------------------------------------------------*;
;*    Appel       : Copier le programme SYS dans le r‚pertoire racine,*;
;*                  ajouter l'instruction DEVICE=RAMDISK.SYS dans le  *;
;*                  fichier CONFIG.SYS puis relancer le systŠme.      *;
;**********************************************************************;

code     segment

     assume cs:code,ds:code,es:code,ss:code

     org 0                               ;Programme sans PSP donc d‚bute
                                                 ;… l'adresse d'offset 0

;== Constantes =========================================================

inst     equ 2              ;Offset champ d'instr. dans blocs de donn‚es
status   equ 3                 ;Offset champ d'‚tat dans bloc de donn‚es
nmb_per  equ 13                ;Offset nombre de p‚riph‚riques support‚s
changmt  equ 14                                 ;Offset support chang‚ ?
adr_fin  equ 14       ;Offset adr. de fin du driver dans bloc de donn‚es
adr_b    equ 14                 ;Offset adr. buffer dans bloc de donn‚es
nmb_ins  equ 16                    ;Sont support‚es les fonctions 0 … 16
nombre   equ 18                      ;Offset nombre dans bloc de donn‚es
bpb_adr  equ 18                        ;Offset adresse du BPB du support
secteur  equ 20                        ;Offset premier num‚ro de secteur
des_per  equ 22       ;Offset d‚signation p‚riph‚rique du disque virtuel

;== Donn‚es ============================================================

prem_o   equ this byte                          ;Premier octet du driver

;-- En-tˆte du driver de p‚riph‚rique ----------------------------------

         dw -1,-1                           ;Lien avec le driver suivant
         dw 0100100000000000b                        ;Attribut de driver
         dw offset strat           ;Pointeur sur la routine de strat‚gie
         dw offset intr          ;Pointeur sur la routine d'interruption
         db 1                             ;Un seul p‚riph‚rique support‚
         db 7 dup (0)                                ;Octets pour le nom

;-- Table de branchement pour les diff‚rentes fonctions ----------------

tab_fct  dw offset init                    ;Fonction  0 : Initialisation
         dw offset med_test               ;Fonction  1 : Test de support
         dw offset get_bpb         ;Fonction  2 : Cr‚ation d'un bloc BPB
         dw offset lire                   ;Fonction  3 : Lecture directe
         dw offset lire                           ;Fonction  4 : Lecture
         dw offset dummy   ;Fonction  5 : Lecture sans retrait du buffer
         dw offset dummy          ;Fonction  6 : Test de l'‚tat d'entr‚e
         dw offset dummy        ;Fonction  7 : Vidage du buffer d'entr‚e
         dw offset ecrire                        ;Fonction  8 : Ecriture
         dw offset ecrire          ;Fonction  9 : Ecrire et v‚rification
         dw offset dummy         ;Fonction 10 : Test de l'‚tat de sortie
         dw offset dummy       ;Fonction 11 : Vidage du buffer de sortie
         dw offset ecrire                ;Fonction 12 : Ecriture directe
         dw offset dummy      ;Fonction 13 : Ouverture (… partir de 3.0)
         dw offset dummy                        ;Fonction 14 : Fermeture
         dw offset no_rem              ;Fonction 15 : Support amovible ?
         dw offset ecrire       ;Fonction 16 : Sortie jusqu'… saturation

db_ptr   dw (?),(?)                 ;Adresse du bloc de donn‚es transmis
rd_seg   dw (?)              ;RD_SEG:0000 est le d‚but du disque virtuel

bpb_ptr  dw offset bpb,(?)                      ;Re‡oit l'adresse du BPB

boot_sec db 3 dup (0)            ;Ici figure normalement une instruction
                           ;de saut … la routine de lancement du systŠme
         db "MITI 1.0"                ;Constructeur et num‚ro de version
bpb      dw 512                                  ;512 octets par secteur
         db 1                                     ;1 secteur par cluster
         dw 1                          ;1 secteur r‚serv‚ (Secteur boot)
         db 1                   ;1 Table d'allocation des fichiers (FAT)
         dw 64                   ;64 entr‚es maxi dans r‚pertoire racine
         dw 320                          ;320 secteurs au total = 160 Ko
         db 0FEh              ;Descripteur de support (Media Descriptor)
                                  ;(1 face avec 40 pistes de 8 secteurs)
         dw 1                              ;Chaque FAT occupe un secteur

     ;-- Pas de routine de boot car le systŠme ne peut -----------------
     ;-- ‚videmment pas ˆtre charg‚ … partir d'un disque virtuel -------

vol_name db "RAMDISK    "                              ;Le nom du volume
         db 8                            ;Attribut, nom du volume d‚fini

;== Routines et fonctions du driver ====================================

strat    proc far                                  ;Routine de strat‚gie

     mov  cs:db_ptr,bx               ;Range l'adresse du bloc de donn‚es
     mov  cs:db_ptr+2,es                        ;dans la variable DB_PTR

     ret                                   ;Retour au programme appelant

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
     pushf                  ;Range ‚galement le registre des indicateurs

     push cs                     ;Fixe le registre de segment de donn‚es
     pop  ds                      ;Le code co‹ncide ici avec les donn‚es

     les  di,dword ptr db_ptr     ;Adresse du bloc de donn‚es dans ES:DI
     mov  bl,es:[di+inst]             ;Va chercher le code d'instruction
     cmp  bl,nmb_ins                      ;Code d'instruction autoris‚ ?
     jle  bc_ok                                           ;OUI --> bc_ok

     mov  ax,8003h                     ;Code pour "instruction inconnue"
     jmp  short intr_end

     ;-- Code d'instruction correct --> ex‚cute l'instruction ----------

bc_ok:
     shl  bl,1                ;Calcule pointeur sur table de branchement
     xor  bh,bh                                               ;Annule BH
     call [tab_fct+bx]                              ;Appelle la fonction

     ;-- Ex‚cution de la fonction achev‚e ------------------------------

intr_end label near
     push cs                     ;Fixe le registre de segment de donn‚es
     pop  ds                      ;Le code co‹ncide ici avec les donn‚es

     les  di,dword ptr db_ptr     ;Adresse du bloc de donn‚es dans ES:DI
     or   ax,0100h                               ;Met … 1 le but Termin‚
     mov  es:[di+status],ax          ;Sauve le tout dans le champ d'‚tat

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

init     proc near                             ;Routine d'initialisation

     ;-- Le code qui suit sera effac‚ par le disque --------------------
     ;-- virtuel aprŠs l'installation ----------------------------------

     ;-- D‚termine la d‚signation de p‚riph‚rique du disque virtuel ----

     mov  ah,30h           ;Lit la version du DOS … l'aide de fct. 30(h)
     int  21h                            ;de l'interruption du DOS 21(h)
     cmp  al,3                                     ;Au moins version 3 ?
     jb   prinm                                           ;OUI --> PRINM

     mov  al,es:[di+des_per]         ;Lit la d‚signation de p‚riph‚rique
     add  al,"A"                                   ;Conversion en lettre
     mov  mi_per,al              ;Sauvegarde dans message d'installation

prinm:
     mov  dx,offset initm             ;Adresse du message d'installation
     mov  ah,9                   ;Affiche num‚ro de fonction pour chaŒne
     int  21h                             ;Appelle l'interruption du DOS

     ;-- Calcule l'adresse du premier octet … la suite du disque -------
     ;-- virtuel et la fixe comme adresse de fin du driver -------------

     mov  word ptr es:[di+adr_fin],offset ramdisk+8000h
     mov  ax,cs                  ;Le disque virtuel a une taille de 32Ko
     add  ax,2000h                                        ;plus 2 * 64Ko
     mov  es:[di+adr_fin+2],ax
     mov  byte ptr es:[di+nmb_per],1            ;1 p‚riph‚rique support‚
     mov  word ptr es:[di+bpb_adr],offset bpb_ptr   ;Adresse du pointeur
     mov  es:[di+bpb_adr+2],ds                                      ;BPB

     mov  ax,cs                      ;Segment du d‚but du disque virtuel
     mov  bpb_ptr+2,ds              ;Segment du BPB dans le pointeur BPB
     mov  dx,offset ramdisk                        ;Calcul avec offset 0
     mov  cl,4                              ;Divise l'offset par 16 pour
     shr  dx,cl                      ;la convertir en adresse de segment
     add  ax,dx                         ;Additionne les deux adresses et
     mov  rd_seg,ax                                           ;les range

     ;-- Met en place le secteur de boot -------------------------------

     mov  es,ax                 ;TransfŠrer l'adresse de segment dans ES
     xor  di,di ;Le secteur de boot commence au 1er octet disque virtuel
     mov  si,offset boot_sec    ;Adresse du secteur boot dans la m‚moire
     mov  cx,15                ;Seuls les 15 premiers mots sont utilis‚s
     rep  movsw         ;Copie le secteur de boot dans le disque virtuel

     ;-- Met en place la table d'allocation des fichiers ---------------

     mov  di,512        ;La FAT commence … l'octet 512 du disque virtuel
     mov  al,0FEh               ;Ecrit le descripteur de support dans le
     stosb                                      ;premier octet de la FAT
     mov  ax,0FFFFH            ;Sauvegarde dans la FAT les octets 2 et 3
     stosw                                                    ;de la FAT
     mov  cx,236               ;Les 236 mots restants occup‚s par la FAT
     inc  ax                                                 ;Met AX … 0
     rep  stosw               ;Met toutes les entr‚es de la FAT … l'‚tat
                                                             ;non occup‚

     ;-- Met en place le r‚pertoire racine avec le nom de volume -------

     mov  di,1024         ;Le r‚pertoire racine commence au 3Šme secteur
     mov  si,offset vol_name   ;Adresse du nom de volume dans la m‚moire
     mov  cx,6                ;Le nom de volume a une longueur de 6 mots
     rep  movsw           ;Copie le nom de volume dans le disque virtuel

     mov  cx,1017               ;Remplit de z‚ros le reste du r‚pertoire
     xor  ax,ax                          ;dans les secteurs 2, 3, 4 et 5
     rep  stosw

     xor  ax,ax                                       ;Tout est en ordre
     ret                                   ;Retour au programme appelant

init     endp
;-----------------------------------------------------------------------

dummy    proc near                           ;Cette routine ne fait rien

     xor  ax,ax                                    ;Annule le bit Occup‚
     ret                                   ;Retour au programme appelant

dummy    endp

;-----------------------------------------------------------------------

med_test proc near                 ;Le support du disque virtuel ne peut
                                                            ;ˆtre chang‚

     mov  byte ptr es:[di+changmt],1
     xor  ax,ax                                    ;Annule le bit occup‚
     ret                                   ;Retour au programme appelant

med_test endp

;-----------------------------------------------------------------------

get_bpb  proc near                      ;Transmet … DOS l'adresse du BPB

     mov  word ptr es:[di+bpb_adr],offset bpb
     mov  word ptr es:[di+bpb_adr+2],ds

     xor  ax,ax                                    ;Annule le bit occup‚
     ret                                   ;Retour au programme appelant

get_bpb  endp

;-----------------------------------------------------------------------

no_rem   proc near                 ;Un disque virtuel n'est pas amovible

     mov  ax,20                                   ;Met … 1 le bit occup‚
     ret                                   ;Retour au programme appelant

no_rem   endp
;-----------------------------------------------------------------------

ecrire   proc near

     xor  bp,bp                     ;Transmission DOS --> disque virtuel
     jmp  short move                                  ;Copie les donn‚es

ecrire   endp

;-----------------------------------------------------------------------

lire    proc near

     mov  bp,1                      ;Transmission disque virtuel --> DOS

lire    endp

;-- MOVE : transfer un nbr de secteurs entre disque virtuel et DOS -----
;-- Entr‚e    : BP = 0 : transfert DOS/disque virtuel (‚criture)
;--                  1 : transfert du disque virtuel … DOS (lecture)
;-- Sortie    : aucune
;-- Registres : AX, BX, CX, DX, SI, DI, ES, DS et INDICATEURS
;-- Infos     : Les informations n‚cessaires (Nombre, premier secteur)
;--             sont fournies par le bloc de donn‚es transmis par DOS

move     proc near

     mov  bx,es:[di+nombre]                  ;Lite le nombre de secteurs
     mov  dx,es:[di+secteur]                  ;Num‚ro du premier secteur
     les  di,es:[di+adr_b]                 ;Adresse du buffer dans ES:DI

move_1:
     or   bx,bx                            ;Encore des secteurs … lire ?
     je   move_e                                ;Plus de secteur --> FIN
     mov  ax,dx                                 ;Num‚ro de secteur en AX
     mov  cl,5                 ;Calcule le nombre de paragraphes (unit‚s
     shl  ax,cl                       ;de segment) en multipliant par 32
     add  ax,cs:rd_seg  ;et additionne … d‚but de segment disque virtuel
     mov  ds,ax                                         ;TransfŠre en DS
     xor  si,si                                ;L'adresse d'offset est 0
     mov  ax,bx                         ;Nombre de secteurs … lire en AX
     cmp  ax,128               ;Reste-t-il plus de 128 secteurs … lire ?
     jbe  move_2                         ;NON --> lire tous les secteurs
     mov  ax,128                      ;OUI --> lire 128 secteurs (64 Ko)
move_2:
     sub  bx,ax                      ;Retranche le nombre de secteur lus
     add  dx,ax                   ;Additionne au prochain secteur … lire
     mov  ch,al                    ;Nombre de secteurs … lire * 256 mots
     xor  cl,cl              ;Met … 0 l'octet faible du compteur de mots
     or   bp,bp                                          ;Faut-il lire ?
     jne  move_3                                         ;NON --> MOVE_3
     mov  ax,es                                          ;Range ES en AX
     push ds                                                  ;Empile DS
     pop  es                                      ; et le r‚cupŠre en ES
     mov  ds,ax                      ;ce qui revient … ‚changer ES et DS
     xchg si,di                                    ;et ‚changer SI et DI
move_3:
     rep  movsw                 ;Copie les donn‚es dans le buffer de DOS
     or   bp,bp                                          ;Faut-il lire ?
     jne  move_1           ;NON --> copier ‚ventuellement d'autres sect.
     mov  ax,es                                          ;Range ES en AX
     push ds                                                  ;Empile DS
     pop  es                                      ; et le r‚cupŠre en ES
     mov  ds,ax                      ;ce qui revient … ‚changer ES et DS
     xchg si,di                          ;et ‚changer … nouveau SI et DI
     jmp  short move_1           ;Copie ‚ventuellement d'autres secteurs

move_e:
     xor  ax,ax                                       ;Tout est en ordre
     ret                                   ;Retour au programme appelant

move     endp

;-- C'est ici que commence le disque virtuel … proprement parler -------

    if ($-prem_o) mod 16                           ;Doit commencer … une
      org ($-prem_o) + 16 - (($-prem_o) mod 16)      ;adresse de m‚moire
    endif                                              ;divisible par 16

ramdisk  equ this byte

initm    db "**** DISQUE VIRTUEL de 160 Ko comme lecteur "
mi_per   db "?"
         db ": install‚.",13,10,"(c) 1987, 92 MICHAEL TISCHER$",13,10,10

;-----------------------------------------------------------------------

code     ends
         end

