;**********************************************************************;
;*                             T S R C A                              *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Interface en assembleur permettant de rendre   *;
;*                     r‚sident un programme ‚crit en langage C       *;
;*--------------------------------------------------------------------*;
;*    Auteur        : MICHAEL TISCHER                                 *;
;*    D‚velopp‚ le  : 10.08.1988                                      *;
;*    DerniŠre MAJ  : 18.04.1992                                      *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM -mx TSRCA;    ou r TASM /mx TSRCA;        *;
;*                     ... puis lier au programme en C                *;
;**********************************************************************;

IGROUP group _text                   ;Regroupe les segments de programme
DGROUP group _bss,  _data              ;Regroupe les segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS'        ;Segment des variables statiques
_BSS   ends                                            ;non initialis‚es

_DATA  segment word public 'DATA'        ;Segment des variables globales
                                          ;et statiques non initialis‚es

extrn  __psp : word                    ;Segment du PSP du programme en C
_DATA  ends

;== Constantes =========================================================

TC_STACK   equ 512                                    ;Pile pour Turbo C
ARG_WORDS  equ 32                      ;Pile de mots copi‚s dans TsrCall

I2F_FCT_0  equ 0AAh                        ;Code pour INT 2F, Fonction 0
I2F_FCT_1  equ 0BBh                        ;Code pour INT 2F, Fonction 1
TIME_OUT   equ 9                             ;Time-Out en nombre de tops

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'                  ;Segment de programme

;-- R‚f‚rences aux fonctions externes en C------------------------------

extrn      _GetHeapEnd:near             ;Renvoie l'adresse de fin du tas

;-- D‚clarations publiques de fonctions internes -----------------------

public     _TsrInit           ;Permet l'appel … partir du programme en C
public     _TsrIsInst
public     _TsrUnInst
public     _TsrCanUnInst
public     _TsrCall
public     _TsrSetHotkey
public     _TsrSetPtr

;-- Variables pour les gestionnaires d'interruption---------------------
;-- (accessibles uniquement par le segment de code )--------------------

call_ptr   equ this dword
call_ofs   dw 0                                     ;Offset pour TSRCall
call_seg   dw 0                                  ;Segment non initialis‚

ret_ax     dw 0                   ;Sauvegarde du r‚sultat de la fonction
ret_dx     dw 0                                            ;pour TsrCall

;-- Variables n‚cessaires … l'activation du programme en C -------------

c_ss       dw 0                                    ;Segment de pile en C
c_sp       dw 0                                   ;Pointeur de pile en C
c_ds       dw 0                                 ;Segment de donn‚es en C
c_es       dw 0                                      ;Segment extra en C

c_dta_ofs  dw 0                     ;Adresse de la DTA du programme en C
c_dta_seg  dw 0

c_psp      dw 0                        ;Segment du PSP du programme en C
break_adr  dw 0                                 ;Adresse de Break du tas
fct_adr    dw 0                   ;Adresse de la fonction r‚sidente en C

;-- Variables pour tester la touche d'activation -----------------------

key_mask   dw 3           ;Masque de touche pour indicateur clavier BIOS
                               ;Par d‚faut : Shift gauche + Shift droite
sc_code    db 128                   ;Scan code de la touche d'activation
                                               ;Par d‚faut pas de touche
i2F_code   db 0                          ;Num‚ro de fonction pour INT 2F

;-- Variables pour l'activation du programme r‚sident ------------------

tsrnow     db 0                               ;En attente d'activation ?
tsractif   db 0                         ;Programme r‚sident d‚j… actif ?
in_bios    db 0             ;Indique une activit‚ du disque dans le BIOS

daptr      equ this dword        ;Pointeur sur l'indicateur Indos de DOS
daptr_ofs  dw 0                                                  ;Offset
daptr_seg  dw 0                                                 ;Segment

;-- Les variables suivantes m‚morisent les adresse des anciens     - ---
;-- gestionnaires d'interruption qui sont remplac‚s par les nouveaux ---

int8_ptr   equ this dword           ;Ancien vecteur de l'interruption 8h
int8_ofs   dw 0                         ;Offset de l'ancien gestionnaire
int8_seg   dw 0                        ;Segment de l'ancien gestionnaire

int9_ptr   equ this dword           ;Ancien vecteur de l'interruption 9h
int9_ofs   dw 0                         ;Offset de l'ancien gestionnaire
int9_seg   dw 0                        ;Segment de l'ancien gestionnaire

int13_ptr  equ this dword          ;Ancien vecteur de l'interruption 13h
int13_ofs  dw 0                         ;Offset de l'ancien gestionnaire
int13_seg  dw 0                        ;Segment de l'ancien gestionnaire

int28_ptr  equ this dword          ;Ancien vecteur de l'interruption 28h
int28_ofs  dw 0                         ;Offset de l'ancien gestionnaire
int28_seg  dw 0                        ;Segment de l'ancien gestionnaire

int2F_ptr  equ this dword          ;Ancien vecteur de l'interruption 2Fh
int2F_ofs  dw 0                         ;Offset de l'ancien gestionnaire
int2F_seg  dw 0                        ;Segment de l'ancien gestionnaire

;-- Variables pour garder des informations du programme interrompu -----

u_dta_ofs  dw 0                        ;Adresse DTA du prog interrompu .
u_dta_seg  dw 0

u_psp      dw 0                       ;Segment du PSP du prog interrompu

uprg_ss    dw 0                             ;SS et SP du prog interrompu
uprg_sp    dw 0

;-----------------------------------------------------------------------
;-- TSRINIT: Termine le programme en C et active
; les nouveaux gestionnaires d'interruption
;-- Appel depuis C: void TsrInit(  bool TC,
;--                              void (fct *)(void),
;--                              unsigned heap_byte );

_TsrInit  proc    near

sframe0    struc                       ;Structure pour acc‚der … la pile
bp0         dw ?                                            ;M‚morise BP
ret_adr0    dw ?                                      ;Adresse de retour
tc0         dw ?                    ;Compilateur (1 = TURBO-C, 0 = MSC )
fctptr0     dw ?                   ;pointeur sur fonction r‚sidente en C
heap0       dw ?                                      ;Octets sur le tas
sframe0    ends                                     ;Fin de la structure

frame      equ [ bp - bp0 ]

           push bp                            ;Sauvegarde BP sur la pile
           mov  bp,sp                                ;TransfŠre SP en BP

           ;-- Sauvegarde les registres de segment de C ----------------

           mov  c_ss,ss                 ;M‚morise les registres dans les
           mov  c_sp,sp                   ;Variables pr‚vues … cet effet
           mov  c_es,es
           mov  c_ds,ds

           ;-- m‚morise les paramŠtres transmis    ---------------------

           mov  ax,frame.fctptr0    ;Lit le ptr sur fonction r‚sidente C
           mov  fct_adr,ax                               ;et le m‚morise

           ;-- Adresse de la DTA du programme en C ---------------------

           mov  ah,2fh      ;Nø de la fonction: Lire l'adresse de la DTA
           int  21h                     ;D‚clenche l'interruption de DOS
           mov  c_dta_ofs,bx             ;M‚morise l'adresse … l'endroit
           mov  c_dta_seg,es                                     ; pr‚vu

           ;-- Lit l'adresse de l'indicateur INDOS----------------------

           mov  ah,34h         ;Nø fonc. : Lire adresse indicateur INDOS
           int  21h                     ;D‚clenche l'interruption de DOS
           mov  daptr_ofs,bx       ;M‚morise l'adresse … l'endroit pr‚vu
           mov  daptr_seg,es

           ;-- Lit les adresses des interruptions … d‚tourner ----------

           mov  ax,3508h            ;Lit le vecteur de l'interruption 8h
           int  21h                       ;Appelle l'interruption de DOS
           mov  int8_ofs,bx          ;M‚morise l'adresse du gestionnaire
           mov  int8_seg,es      ;dans les variables pr‚vues … cet effet

           mov  ax,3509h            ;Lit le vecteur de l'interruption 9h
           int  21h                       ;Appelle l'interruption de DOS
           mov  int9_ofs,bx          ;M‚morise l'adresse du gestionnaire
           mov  int9_seg,es      ;dans les variables pr‚vues … cet effet

           mov  ax,3513h           ;Lit le vecteur de l'interruption 13h
           int  21h                       ;Appelle l'interruption de DOS
           mov  int13_ofs,bx         ;M‚morise l'adresse du gestionnaire
           mov  int13_seg,es     ;dans les variables pr‚vues … cet effet

           mov  ax,3528h           ;Lit le vecteur de l'interruption 28h
           int  21h                       ;Appelle l'interruption de DOS
           mov  int28_ofs,bx         ;M‚morise l'adresse du gestionnaire
           mov  int28_seg,es     ;dans les variables pr‚vues … cet effet

           mov  ax,352Fh           ;Lit le vecteur de l'interruption 2Fh
           int  21h                       ;Appelle l'interruption de DOS
           mov  int2F_ofs,bx         ;M‚morise l'adresse du gestionnaire
           mov  int2F_seg,es     ;dans les variables pr‚vues … cet effet

           ;-- Installe les nouveaux gestionnaires d'interruption-------

           push ds                       ;M‚morise le segment de donn‚es
           mov  ax,cs                     ;TransfŠre CS en AX puis en DS
           mov  ds,ax

           mov  ax,2508h          ;Nø fonction : Fixer l'interruption 8h
           mov  dx,offset int08         ;DS:DX = adresse du gestionnaire
           int  21h                       ;Appelle l'interruption de DOS

           mov  ax,2509h            ;Nø fonction : Fixer interruption 9h
           mov  dx,offset int09         ;DS:DX = adresse du gestionnaire
           int  21h                       ;Appelle l'interruption de DOS

           mov  ax,2513h         ;Nø fonction : Fixer l'interruption 13h
           mov  dx,offset int13         ;DS:DX = adresse du gestionnaire
           int  21h                       ;Appelle l'interruption de DOS

           mov  ax,2528h         ;Nø fonction : Fixer l'interruption 28h
           mov  dx,offset int28          ;DS:DX =adresse du gestionnaire
           int  21h                       ;Appelle l'interruption de DOS

           mov  ax,252Fh         ;Nø fonction : Fixer l'interruption 2Fh
           mov  dx,offset int2F           ;DS:DX=adresse du gestionnaire
           int  21h                       ;Appelle l'interruption de DOS

           pop  ds                               ;reprend DS sur la pile

           ;-- Calcule le nombre de paragraphes qui doivent rester -----
           ;-- en m‚moire ----------------------------------------------

           call _GetHeapEnd          ;fonction C dans le module r‚sident
           add  ax,frame.heap0      ;Ajoute la m‚moire du tas n‚cessaire

           ;-- Dans le cas de TURBO-C la pile se trouve derriŠre le tas-
           ;-- commence … la fin du segment il faut donc la rajouter ---
           ;-- au tas --------------------------------------------------

           cmp  byte ptr frame.tc0,0             ;Utilise-t-on TURBO-C ?
           je   msc2                                           ;NON, MSC

           add  ax,TC_STACK-1       ;Calcule nouveau ptr de pile pour TC
           mov  c_sp,ax                                  ;et le m‚morise
           inc  ax                                ;fixe adresse de break

           ;-- Calcule le nombre de pargraphes qui doivent rester ------
           ;-- en m‚moire ----------------------------------------------

msc2:      mov  dx,ax        ;Cherche l'adresse de Break et la met en DX
           add  dx,15          ;Evite la perte due … la division entiŠre
           mov  cl,4               ;D‚cale de 4 positions vers la droite
           shr  dx,cl                                ; = division par 16
           mov  ax,ds                                ;TransfŠre DS en AX
           mov  bx,__psp                          ;Lit le segment du PSP
           mov  c_psp,bx                                ; et le m‚morise
           sub  ax,bx                               ;Retranche DS de PSP
           add  dx,ax         ; et additionne le r‚s au nombre de parag.
           mov  ax,3100h                              ;Nø fonction : TSR
           int  21h                     ;D‚clenche l'interruption de DOS
                                                  ; termine le programme

_TsrInit  endp

          assume CS:IGROUP, DS:nothing, ES:nothing, SS:nothing

;-----------------------------------------------------------------------
;-- TSRSETHOTKEY: Fixe la touche d'activation du programme
;-- Apepl depuis C: void TsrSetHotKey( unsigned KeyMask,
;--                                  byte     ScanCode );
;-- Info            : cette proc‚dure est FAR pour qu'elle puisse ˆtre
;--       apel‚e dans un programme r‚sident d‚j… install‚
;--

_TsrSetHotkey  proc far

sframe1    struc                       ;Structure pour acc‚der … la pile
bp1         dw ?                                            ;M‚morise BP
ret_adr1    dd ?                                      ;Adresse de retour
keymask1    dw ?                     ;Masque pour la touche d'activation
sc_code1    dw ?                    ;Scan code de la touche d'activation
sframe1    ends                                     ;Fin de la structure

frame      equ [ bp - bp1 ]

           push bp                            ;Sauvegarde BP sur la pile
           mov  bp,sp                                ;TransfŠre SP en BP

           ;-- M‚morise les paramŠtres transmis    ---------------------

           mov  ax,frame.keymask1   ;Lit/m‚m. masque touche d'activation
           mov  key_mask,ax
           mov  al,byte ptr frame.sc_code1      ;Lit scan code de touche
           mov  sc_code,al                               ;et le m‚morise

           pop  bp                              ;R‚cupŠre BP sur la pile
           ret                                                   ;Retour
_TsrSetHotkey  endp

;-----------------------------------------------------------------------
;-- TSRISINST: Teste si le programme est d‚j… install‚ -----------------
;-- Appel depuis C : bool TsrIsInst( byte i2f_fctnr);
;-- Valeur de retour : TRUE, si le programme est d‚j… install‚ ,
;--               sinon FALSE

_TsrIsInst proc    near

sframe2    struc                       ;Structure pour acc‚der … la pile
bp2         dw ?                                            ;M‚morise BP
ret_adr2    dw ?                                      ;Adresse de retour
i2F_code2   dw ?                         ;Num‚ro de fonction pour INT 2F
sframe2    ends                                     ;Fin de la structure

frame      equ [ bp - bp2 ]

           push bp                            ;Sauvegarde BP sur la pile
           mov  bp,sp                                ;TransfŠre SP en BP

           mov  ah,byte ptr frame.i2F_code2  ;Nø de fonction pour INT 2F
           mov  i2F_code,ah                              ; … sauvegarder
           mov  al,I2F_FCT_0                                ;Nø d'option
           mov  bx,ax                       ;Prend note des deux num‚ros
           int  2Fh
           xchg bh,bl                                   ;Les intervertit
           cmp  ax,bx                        ;et compare … val de retour
           mov  ax,0                 ;A priori pas encore d'installation
           jne  isi_end                     ;non ‚gal --> pas d'install.

           ;-- Segment de l'exemplaire d‚j… install‚ -------------------

           mov  ah,i2f_code                    ;Non, segment par INT 2Fh
           mov  al,I2F_FCT_1                        ;Charge l'option 01h
           int  2Fh
           mov  call_seg,ax                        ;M‚morise le r‚sultat
           mov  ax,-1                                  ;Installation oui

isi_end:   pop  bp                              ;R‚cupŠre BP sur la pile
           ret                                                   ;retour

_TsrIsInst endp                                     ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- TSRCANUNIST : Teste si l'exemplaire install‚ du programme r‚sident--
;--               peut ˆtre d‚sinstall‚
;-- Apppel depuis C Bool TsrCanUnInst( void );
;-- Sortie     : TRUE, si d‚sinstallation possible, sinon FALSE
;-- Info       : Le programme ne peut ˆtre d‚sinstall‚ que si
;--              aucun de ses vecteurs d'interruption
;--              n'a ‚t‚ d‚tourn‚ entretemps par un autre programme

tsrlist    db  08h,09h,13h,28h,2Fh,00h   ;Liste interruptions d‚tourn‚es
                                           ;00h marqueur de fin de liste
_TsrCanUninst proc  near

           push di                                             ;Sauve DI
           mov  dx,call_seg  ;Charge le segment de d'exemplaire install‚
           mov  di,offset tsrlist-1                        ;DI sur liste

tcu_1:     inc  di                      ;DI sur num‚ro d'interr. suivant
           mov  al,cs:[di]                         ;Num‚ro suivant en AL
           or   al,al                                 ;Fin de la liste ?
           je   tcu_ok                              ;Oui, ts vecteurs ok

           mov  ah,35h                ;Nø de la fonction "Get Interrupt"
           int  21h                       ;Appelle l'interruption de DOS
           mov  cx,es                                ;TransfŠre ES en CX
           cmp  dx,cx                                    ;Mˆme segment ?
           je   tcu_1              ;Oui, pas de d‚sinstallation possible

           xor  ax,ax               ;Non pas de d‚sinstallation possible
           pop di
           ret

tcu_ok:    mov  ax,-1

           pop  di                                          ;restaure DI
           ret

_TsrCanUninst endp

;-----------------------------------------------------------------------
;-- TSRUNINST: D‚sinstalle le programme r‚sident et libŠre la m‚moire  -
;--            allou‚e
;-- Appel depuis C: void TsrUnInst( void );
; Info           : Cette routine ne doit ˆtre appel‚e que si
;--                    TSRCANUNINST() a renvoy‚ la valeur TRUE
;--
_TsrUninst    proc    near

           push ds
           mov  es,call_seg      ;Segment du programme r‚sident install‚

           ;-- R‚tablit les anciens gestionnaires d'interruption -------

           cli                                ;Inhibe toute interruption
           mov  ax,2508h         ;Nø fonction : Fixer gestionnaire INT 8
           mov  ds,es:int8_seg                      ;R‚tablit le segment
           mov  dx,es:int8_ofs    ; et l'offset de l'ancien gestionnaire
           int  21h

           mov  ax,2509h         ;Nø fonction : Fixer gestionnaire INT 9
           mov  ds,es:int9_seg                      ;Restaure le segment
           mov  dx,es:int9_ofs    ; et l'offset de l'ancien gestionnaire
           int  21h

           mov  ax,2513h        ;Nø fonction : Fixer gestionnaire INT 13
           mov  ds,es:int13_seg                     ;Restaure le segment
           mov  dx,es:int13_ofs   ; et l'offset de l'ancien gestionnaire
           int  21h

           mov  ax,2528h        ;Nø fonction : Fixer gestionnaire INT 28
           mov  ds,es:int28_seg                     ;Restaure le segment
           mov  dx,es:int28_ofs   ; et l'offset de l'ancien gestionnaire
           int  21h

           mov  ax,252Fh        ;Nø fonction : Fixer gestionnaire INT 2F
           mov  ds,es:int2F_seg                     ;Restaure le segment
           mov  dx,es:int2F_ofs   ; et l'offset de l'ancien gestionnaire
           int  21h
           sti                     ;Autorise … nouveau les interruptions

           ;-- LibŠre la m‚moire  --------------------------------------

           mov  es,es:c_psp        ;CX=segment PSP du programme r‚sident
           mov  cx,es
           mov  es,es:[ 02ch ]                 ;PSP=seg de l'environment
           mov  ah,49h         ;Nø de la fonction: Lib‚rer de la m‚moire
           int  21h                       ;Appelle l'interruption de DOS

           mov  es,cx                                ;Reprend ES dans CX
           mov  ah,49h         ;Nø de la fonction: LibŠrer de la m‚moire
           int  21h                       ;Appelle l'interruption de DOS

           pop  ds                        ;r‚cupŠre DS et BP sur la pile
           ret                                    ;retourne … l'appelant

_TsrUninst endp                                        ;Fin de proc‚dure

;-----------------------------------------------------------------------
;-- TSRSETPTR: M‚morise l'adresse de la routine qui devra ˆtre        --
;--            d‚clench‚e lors d'un appel ult‚rieur … TSRCALL et
;--            renvoie un pointeur sur TSRCALL
;-- Appel depuis C: void (*)(void) TsrSetPtr( void far * Fct );

_TsrSetPtr  proc    near

sframe3    struc                       ;Structure pour acc‚der … la pile
bp3         dw ?                                            ;M‚morise BP
ret_adr3    dw ?                                      ;Adresse de retour
fctptr3     dd ?                      ;Pointeur sur la routine … appeler
sframe3    ends                                     ;Fin de la structure

frame      equ [ bp - bp3 ]

           push bp                            ;Sauvegarde BP sur la pile
           mov  bp,sp                                ;TransfŠre SP en BP

           mov  ax,word ptr frame.fctptr3         ;Charge l'offset en AX
           mov  call_ofs,ax                             ; puis le stocke

           mov  ax,offset _TsrCall ;Renvoie un pointeur Near sur TSRCALL
           pop  bp                              ;R‚cupŠre BP sur la pile

           ret                                    ;Retourne … l'appelant

_TsrSetPtr endp                                     ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- TSRCALL: Appelle une  routine de l'exemplaire du programme r‚sident-
;--          pr‚alablement install‚
;-- Appel depuis C: void TsrCall( void )
;-- Attention   Les arguments de la pile de l'appelant sont copi‚s
;       sur la pile du programme … appeler et la pile
;       est chang‚e de fa‡on que l'on ait toujours DS=SS

_TsrCall   proc near

           push di                           ;Prend note de DS, SI et DI
           push si
           push ds

           mov  ah,2fh    ;Nø de la fonction: "Lire l'adresse de la DTA"
           int  21h                       ;Appelle l'interruption de DOS
           mov  u_dta_ofs,bx          ;Sauvegarde l'adresse de la DTA du
           mov  u_dta_seg,es                       ;programme interrompu

           mov  es,call_seg                  ;Charge en ES le segment du
                                           ;programme r‚sident install‚"
           mov  ah,50h        ;Nø de la fonction: Fixer l'adresse du PSP
           mov  bx,es:c_psp                       ;Lit le segment du PSP
           int  21h                       ;Appelle l'interruption de DOS

           mov  ah,1ah     ;Nø de la fonction: Fixer l'adresse de la DTA
           mov  dx,es:c_dta_ofs               ;Offset de la nouvelle DTA
           mov  ds,es:c_dta_seg              ;Segment de la nouvelle DTA
           int  21h                       ;Appelle l'interruption de DOS


           ;-- Copie les arguments sur la pile du programme ------------
           ;-- r‚sident install‚ ---------------------------------------

           push ss                     ;DS:SI pointent sur les arguments
           pop  ds                                 ; de la pile courante
           mov  si,sp
           add  si,8                    ;Par dessus RET et PUSH DS,DI,SI

           mov  cx,ARG_WORDS*2
           mov  di,es:c_sp             ;ES:DI=pile du programme install‚
           sub  di,cx
           mov  es,es:c_ss
           rep  movsb                               ;Copie les arguments

           ;-- Fixe registres de segment du programme r‚sident install‚-

           mov  es,call_seg      ;Segment du programme r‚sident install‚
                                                                  ;en ES

           cli                                 ;Inhibe les interruptions
           mov  uprg_ss,ss                    ;M‚morise le segment et le
           mov  uprg_sp,sp                   ; pointeur de pile courants

           mov  ss,es:c_ss               ;Active la pile de l'exemplaire
           mov  sp,es:c_sp               ;install‚ du programme r‚sident
           sub  sp,ARG_WORDS*2           ;Passe par dessus les arguments
           sti                     ;Autorise … nouveau les interruptions

           mov  ds,es:c_ds    ;Fixe registre de segment pour programme C
           mov  es,es:c_es                                             ;

           call [call_ptr]          ;M‚morise le r‚sultat de la fonction
           mov  ret_ax,ax                       ;transmise par TSRSETPTR
           mov  ret_dx,dx

           cli                              ;Interdit toute interruption
           mov  ss,uprg_ss                 ;Repasse sur la pile initiale
           mov  sp,uprg_sp                                             ;
           sti                               ;R‚tablit les interruptions

           ;-- Effectue changement de contexte vers programme actuel ---

           mov  ah,1ah     ;Nø de la fonction: Fixer l'adresse de la DTA
           mov  dx,u_dta_ofs    ;Charge l'offset et le segment de la DTA
           mov  ds,u_dta_seg                   ; du programme interrompu
           int  21h                     ;D‚clenche l'interruption de DOS

           mov  es,call_seg                ;Reprend ES et DS sur la pile
           pop  ds                                                     ;

           mov  ah,50h        ;Nø de la fonction: Fixer l'adresse du PSP
           mov  bx,cs                                ;transfŠre CS en BX
           sub  bx,10h                        ;Calcule le segment du PSP
           int  21h                     ;D‚clenche l'interruption de DOS

           mov  ax,ret_ax             ;RamŠne le r‚sultat de la fonction
           mov  dx,ret_dx

           pop  si                               ;R‚cupŠre les registres
           pop  di
           ret                                    ;Retourne … l'appelant

_TsrCall   endp                                     ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- DOSACTIF: D‚termine par l'indicateur INDOS si DOS peut ˆtre
;--           interrompu .
;-- Entr‚e:  n‚ant
;-- Sortie:  Indicateur de z‚ro=1: DOS peut ˆtre interrompu

dosactif   proc near

           push ds                          ;Stocke BX et DS sur la pile
           push bx
           lds  bx,daptr          ;DS:BX pointent sur l'indicateur INDOS
           cmp  byte ptr [bx],0                ;Fonction de DOS active ?
           pop  bx                        ;R‚cupŠre BX et DS sur la pile
           pop  ds

           ret                                    ;Retourne … l'appelant

dosactif   endp

;-----------------------------------------------------------------------
;--         Voici les nouveaux gestionnaires d'interruption         ----
;-----------------------------------------------------------------------

;-- Nouveau gestionnaire de l'interruption 8h (Timer)-------------------

int08      proc far

           cmp  tsrnow,0          ;Faut-il activer le programme r‚sident
           je   i8_end               ;Non, passe … l'ancien gestionnaire

           dec  tsrnow        ;Oui, d‚cr‚mente l'indicateur d'activation

           ;-- TSR doit ˆtre activ‚ mais est-ce possible ? -------------

           cmp  in_bios, 0         ;Interruption disque du BIOS active ?
           jne  i8_end                ;OUI --> pas d'activation possible

           call dosactif                  ;DOS peut-il ˆtre interrompu ?
           je   i8_tsr               ;Oui, appelle le programme r‚sident

i8_end:    jmp  [int8_ptr]             ;retourne … l'ancien gestionnaire

           ;-- Active le programme r‚sident ----------------------------

i8_tsr:    mov  tsrnow,0            ;Le TSR n'attend plus son activation
           mov  tsractif,1   ;le programme r‚sident est maintenant actif
           pushf                ;Simule l'appel de l'ancien gestionnaire
           call [int8_ptr]                                  ; par INT 8h
           call start_tsr                   ;Lance le programme r‚sident
           iret                        ;retourne au programme interrompu

int08      endp

;-- Nouveau gestionnaire de l'interruption 09h (clavier)----------------

int09      proc far

           push ax
           in   al,60h                           ;Lit le port du clavier

           cmp  tsractif,0    ;Le programme r‚sident est-il d‚j… actif ?
           jne  i9_end   ;OUI: appelle l'ancien gestionnaire puis retour

           cmp  tsrnow,0  ;Le programme est-il en attente d'activation ?
           jne  i9_end   ;OUI: appelle l'ancien gestionnaire puis retour

           ;-- Teste la touche d'activation   --------------------------

           cmp  sc_code,128                     ;Y a-t-il un scan code ?
           je   i9_ks         ;Non, ne teste que les touches de commande

           cmp  al,128                     ;Oui est-ce un code release ?
           jae i9_end                             ;Oui, pas d'activation

           cmp  sc_code,al          ;Code make … comparer avec le modŠle
           jne  i9_end                  ;Pas d'activation si pas le mˆme

i9_ks:     ;-- Teste l'‚tat des touches de commande --------------------

           push ds
           mov  ax,040h                 ;DS sur le segment des variables
           mov  ds,ax                                          ; du BIOS
           mov  ax,word ptr ds:[17h]  ;lit indic. d'‚tat clavier en BIOS
           and  ax,key_mask              ;bits de la touche d'activation
           cmp  ax,key_mask            ;bits de la touche d'activation ?
           pop  ds
           jne  i9_end    ;Touche d'activation d‚tect‚e ? NON --> retour

           cmp  in_bios, 0       ;Interruption disque du BIOS en cours ?
           jne  i9_e1                 ;OUI --> pas d'activation possible

           call dosactif            ;Est-il possible d'interrompre DOS ?
           je   i9_tsr                 ;Oui, lance le programme r‚sident

i9_e1:     mov  tsrnow,TIME_OUT             ;TSR en attente d'activation

i9_end:    pop   ax                                          ;Reprend AX
           jmp   [int9_ptr]        ;Se branche sur l'ancien gestionnaire

i9_tsr:    mov   tsractif,1       ;Le TSR va ˆtre actif (dans un moment)
           mov   tsrnow,0                     ;Pas de d‚lai de lancement
           pushf
           call  [int9_ptr]               ;Appelle l'ancien gestionnaire
           pop   ax                                         ;R‚cupŠre AX
           call  start_tsr                  ;Lance le programme r‚sident
           iret                        ;retourne au programme interrompu

int09      endp

;-- Nouveau gestionnaire de l'interruption 13 h (disque(tte)) ----------

int13      proc far

           inc  in_bios          ;Incr‚mente l'indicateur disque du BIOS
           pushf                ;Simule l'appel de l'ancien gestionnaire
           call [int13_ptr]                                ; par INT 13h
           dec  in_bios           ;Restaure l'indicateur disque du BIOS-

           sti                     ;Autorise … nouveau les interruptions
           ret  2                    ;Retourne … l'appelant, mais enlŠve
                   ;en mˆme temps le registre des indicateurs de la pile
int13      endp

;-- Nouveau gestionnaire de l'interruption 28h (DOS idle) --------------

int28      proc far

           cmp  tsrnow,0   ;Programme r‚sident en attente d'activation ?
           je   i28_end                      ;Non, retourne … l'appelant

           cmp  in_bios, 0   ;Oui, mais a-t-on une interruption disque ?
           je   i28_tsr                      ;Oui, donc pas d'activation

i28_end:   jmp  [int28_ptr]            ;retourne … l'ancien gestionnaire

           ;-- Lance le programme r‚sident -----------------------------

i28_tsr:   mov  tsrnow,0                   ;Le TSR n'est plus en attente
           mov  tsractif,1          ;Le TSR va ˆtre actif dans un moment
           pushf                ;Simule l'appel de l'ancien gestionnaire
           call [int28_ptr]                  ;d'interruption par INT 28h
           call start_tsr                   ;Lance le programme r‚sident
           iret                                   ;Retourne … l'appelant

int28      endp

;-- Nouveau gestionnaire de l'interruption 2Fh (multiplexeur) ----------

int2F      proc far

           cmp  ah,i2F_code  ;Appel de ce pr‚sent programme r‚sident ? ?
           jne  i2F_end           ;Non, retourne … l'ancien gestionnaire


           cmp  al,I2F_FCT_0          ;Oui, est-ce la sous-fonction 00h?
           je   i2F_0                          ;Oui, passe … l'ex‚cution

           cmp  al,I2F_FCT_1     ;peut-ˆtre est-ce la sous-fonction 01h?
           je   i2F_1                          ;Oui, passe … l'ex‚cution

           iret                                     ;Non, ignore l'appel

i2F_end:   ;-- Le TSR n'est pas concern‚, fait suivre l'appel ----------

           jmp  [int2F_ptr]                  ;vers l'ancien gestionnaire

i2F_0:     ;-- Sous-fonction 00: test d'installation -------------------

           xchg ah,al     ;Echange num‚ros de fonction et sous-fonction.
           iret                                   ;Retourne … l'appelant

i2F_1:     ;-- Sous-fonction 01: retourne le segment -------------------

           mov  ax,cs                                     ;Segment en AX
           iret                                   ;Retourne … l'appelant

int2F      endp

;-- START_TSR: Active le programme r‚sident ----------------------------

start_tsr  proc near

           ;-- Changement de contexte vers le programme en C------------

           cli                                 ;Inhibe les interruptions
           mov  uprg_ss,ss         ;Prend note du segment et du pointeur
           mov  uprg_sp,sp                                     ; de pile

           mov  ss,c_ss                ;Active la pile du programme en C
           mov  sp,c_sp
           sti                               ;R‚tablit les interruptions

           push ax               ;Sauvegarde les registres du processeur
           push bx                                     ;sur la pile de C
           push cx
           push dx
           push bp
           push si
           push di
           push ds
           push es

     ;-- Sauvegarde 64 mots de la pile de DOS --------------------------

           mov  cx,64                                ;Compteur de boucle
           mov  ds,uprg_ss    ;DS:SI pointe sur la fin de la pile de DOS
           mov  si,uprg_sp

tsrs1:     push word ptr [si]        ;TransfŠre un mot de la pile de DOS
           inc  si                  ;sur la pile de C et fait pointer SI
           inc  si                                   ;sur le mot suivant
           loop tsrs1                           ;Traite tous les 64 mots

           mov  ah,51h         ;Nø de la fonction: Lire l'adresse du PSP
           int  21h                       ;Appelle l'interruption de DOS
           mov  u_psp,bx                     ;M‚morise le segment du PSP

           mov  ah,2fh            ;Nø de la fonction: Lire l'adresse DTA
           int  21h                       ;Appelle l'interruption de DOS
           mov  u_dta_ofs,bx                  ;Sauve l'adresse de la DTA
           mov  u_dta_seg,es                   ; du programme interrompu

           mov  ah,50h      ;Nø de la fonction: "Fixer l'adresse du PSP"
           mov  bx,c_psp                ;Sauvegard. PSP des Prog Turbo C
           int  21h                       ;Appelle l'interruption de DOS

           mov  ah,1ah           ;Nø de la fonction: Fixer l'adresse DTA
           mov  dx,c_dta_ofs                                ;Lit l'offet
           mov  ds,c_dta_seg           ;et le segment de la nouvelle DTA
           int  21h                       ;Appelle l'interruption de DOS

           mov  ds,c_ds                   ;fixe les registres de segment
           mov  es,c_es                            ; pour le programme C

           call [fct_adr]     ;Appelle fonction de lancement programme C

           ;-- Changement de contexte vers le programme interrompu -----

           mov  ah,1ah  ;Nø de la fonction: "Fixer l'adresse de la DTA "
           mov  dx,u_dta_ofs    ;Charge l'offset et le segment de la DTA
           mov  ds,u_dta_seg                    ;du programme interrompu
           int  21h                       ;Appelle l'interruption de DOS

           mov  ah,50h       ;Nø de la fonction: "Fixe l'adresse du PSP"
           mov  bx,u_psp                   ;Seg du PSP du prog interr. .
           int  21h                       ;Appelle l'interruption de DOS

           ;-- restaure la pile de DOS----------------------------------

           mov  cx,64                                          ;Compteur
           mov  ds,uprg_ss          ;DS:SI=adresse de fin de pile de DOS
           mov  si,uprg_sp                                             ;
           add  si,128                    ;SI au d‚but de la pile de DOS
tsrs2:     dec  si                                 ;SI sur mot pr‚c‚dent
           dec  si
           pop  word ptr [si]            ;mot de pile C vers pile de DOS
           loop tsrs2                                  ;Extraire 64 mots

           pop  es                         ;Reprend les registres sauv‚s
           pop  ds                                        ;sur la pile C
           pop  di
           pop  si
           pop  bp
           pop  dx
           pop  cx
           pop  bx
           pop  ax

           cli                                 ;Inhibe les interruptions
           mov  ss,uprg_ss           ;Restaure me pointeur et le segment
           mov  sp,uprg_sp              ;de pile du programme interrompu

           mov  tsractif,0       ;Le programme r‚sident n'est plus actif
           sti                     ;Autorise … nouveau les interruptions

           ret                                    ;Retourne … l'appelant

start_tsr  endp

;-----------------------------------------------------------------------

_text      ends                                  ;Fin du segment de code
           end                                         ;Fin du programme
