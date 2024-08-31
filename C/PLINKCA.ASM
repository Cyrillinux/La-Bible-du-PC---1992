;**********************************************************************;
;*                        P L I N K C A . A S M                       *;
;*--------------------------------------------------------------------*;
;*    Fonction        : Compl‚ment en assembleur du programme en C    *;
;*                      PLINKC. Contient les gestionnaires d'interrup *;
;*                      de ce programme                               *;
;*--------------------------------------------------------------------*;
;*    Auteur        : MICHAEL TISCHER                                 *;
;*    D‚velopp‚ le  : 10.10.1991                                      *;
;*    DerniŠre MAJ  : 11.10.1991                                      *;
;*--------------------------------------------------------------------*;
;*    ModŠle m‚moire : SMALL                                          *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM PLINKCA;  ou TASM PLINKCA                 *;
;*                     ... puis lier … PLINKC                         *;
;**********************************************************************;

IGROUP group _text                   ;Regroupe les segments de programme
DGROUP group _bss,  _data              ;Regroupe les segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS';Segment r‚serv‚ aux variables statiques
_BSS   ends                                            ;non initialis‚es

_DATA  segment word public 'DATA';Segment r‚serv‚ aux variables globales
                                              ;et statiques initialis‚es

_DATA  ends

;== Constantes =========================================================

KB_PORT   = 60h                                         ;Port du clavier
INT_CTR   = 20h                       ;Port du contr“leur d'interruption
EOI       = 20h                             ;Commande fin d'interruption
ESCAPE    = 1                             ;Scan code de la touche Escape

;== Programme===========================================================

_TEXT  segment byte public 'CODE'                       ;Segment de code

;-- D‚clarations publiques de fonctions internes -----------------------

public     _IntrInstall    ;Permet des appels … partir du programme en C
public     _IntrRemove
public     _EscapeDirect

;-- Variables pour les gestionnaires d'interruption---------------------
;-- (accessibles uniquelent par le segment de code )----------

key_ptr    dd 0                    ;Pointeur sur la variable pour ESCAPE
tout_ptr   dd 0                       ;Pointeur sur compteur de Time Out
escdirect  db 0                         ;Pas de Time Out en cas d'Escape

;-- Les variables suivantes m‚morisent les anciennes adresses des - ---
;-- gestionnaires d'interruption remplac‚s par les nouveaux    ---

int9_ptr   equ this dword              ;Ancien vecteur d'interruption 9h
int9_ofs   dw 0                                                  ;Offset
int9_seg   dw 0                                                 ;Segment

int1C_ptr  equ this dword             ;ancien vecteur d'interruption 1Ch
int1C_ofs  dw 0                                                  ;Offset
int1C_seg  dw 0                                                 ;Segment

;-----------------------------------------------------------------------
;-- IntrInstall : Installe les gestionnaires d'interruption         ----
;-- Appel depuis C: void IntrInstall( int far * escape_flag,
;--                                 word far * timeout_count );

_IntrInstall  proc near

sframe0    struc                            ;Structure d'accŠs … la pile
bp0        dw ?                                             ;M‚morise BP
ret_adr0   dw ?                                       ;ADresse de retour
escptr     dd ?                         ;Pointeur FAR sur l'indic ESCAPE
toptr      dd ?                ;Pointeur FAR sur le compteur de Time Out
sframe0    ends                                     ;Fin de la structure

frame  equ [ bp - bp0 ]

       push bp                                                ;Empile BP
       mov  bp,sp                                   ;TransfŠre SP  en BP

       push si

                ;-- Prend les arguments sur la pile et les traite-------

       les  si,frame.escptr       ;Charge un pointeur sur l'indic ESCAPE
       mov  word ptr key_ptr,si      ;et le transfŠre en segment de code
       mov  word ptr key_ptr+2,es                                      ;

       les  si,frame.toptr    ;Charge un ptr sur le compteur de Time Out
       mov  word ptr tout_ptr,si     ;et le transfŠre en segment de code
       mov  word ptr tout_ptr+2,es                                     ;

           ;-- Lit les adresses des gestionnaires … d‚tournerer holen --

       mov  ax,3509h                   ;Lit le vecteur d'interruption 9h
       int  21h                                                        ;
       mov  int9_ofs,bx           ;et m‚morise l'adresse du gestionnaire
       mov  int9_seg,es                                                ;

       mov  ax,351Ch                  ;Lit le vecteur d'interruption 1Ch
       int  21h                                                        ;
       mov  int1C_ofs,bx          ;et m‚morise l'adresse du gestionnaire
       mov  int1C_seg,es                                               ;

                  ;-- Installe les nouveaux gestionnaires d'interruption

       push ds                           ;M‚morise le segment de donn‚es
       mov  ax,cs                                     ;Rend DS ‚gal … CS
       mov  ds,ax

       mov  ax,2509h      ;Fonction: "Fixer le gestionnaire pour INT 9h"
       mov  dx,offset int09   ;DS:DX recueille l'adresse du gestionnaire
       int  21h                         ;D‚clenche l'interruption de DOS

       mov  ax,251Ch         ;Fonction: "Fixer le gestionnaire pour 1Ch"
       mov  dx,offset int1C   ;DS:DX recueille l'adresse du gestionnaire
       int  21h                         ;D‚clenche l'interruption de DOS

       pop  ds                                   ;Reprend DS sur la pile

       pop  si
       pop  bp
       ret                                        ;Retourne … l'appelant

_IntrInstall  endp

;-----------------------------------------------------------------------
;-- IntrRemove : D‚sactive le gestionnaire d'interruption
;-- Appel depuis C: void IntrRemove( void );

_IntrRemove  proc near

       cli                                     ;Inhibe les interruptions
       push ds                                           ;Met de c“t‚ DS

       mov  ax,2509h         ;Fonction"Fixer le gestionnaire pour INT 9"
       mov  ds,int9_seg                ;Segment de l'ancien gestionnaire
       mov  dx,int9_ofs                 ;Offset de l'ancien gestionnaire
       int  21h                          ;R‚tablit l'ancien gestionnaire

       mov  ax,251Ch          ;Fonction:"Fixer le gestionnaire pour 1Ch"
       mov  ds,int1C_seg               ;Segment de l'ancien gestionnaire
       mov  dx,int1C_ofs                ;Offset de l'ancien gestionnaire
       int  21h                          ;Ratablit l'ancien gestionnaire

       pop  ds                                   ;Reprend DS sur la pile
       sti                         ;Autorise … nouveau les interruptions

       ret                                        ;Retourne … l'appelant

_IntrRemove  endp                                   ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- EscapeDirect: D‚termine si en cas d'Escape il faut d‚clencher  ----
;--               un Time Out
;-- Appel depuis C: void EscapeDirect( int Declenche );

_EscapeDirect proc near

sframe1    struc                       ;Structure pour acc‚der … la pile
bp1        dw ?                                             ;m‚morise BP
ret_adr1   dw ?                                       ;ADresse de retour
escflag    dw ?                                           ;TRUE ou FALSE
sframe1    ends                                     ;Fin de la structure

frame  equ [ bp - bp1 ]

       push bp                                                ;Empile BP
       mov  bp,sp                                    ;TransfŠre SP en BP

       mov  al,byte ptr frame.escflag               ;Charge l'indicateur
       mov  escdirect,al                 ;et le transfŠre en variable CS

       pop  bp
       ret                                        ;Retourne … l'appelant

_EscapeDirect endp

;-----------------------------------------------------------------------
;-- Voici les nouveaux gestionnaires d'interruption------------------
;-----------------------------------------------------------------------

       assume CS:IGROUP, DS:nothing, ES:nothing, SS:nothing

;-- Nouveau gestionnaire de l'interruption 9h ------------------------

int09  proc far

       push ax                                            ;Sauvegarde AX
       in   al,KB_PORT          ;Lit le scan code sur le port du clavier

       cmp  al,128                                        ;Code release?
       jae  i9_end                                   ;Oui, ne pas tester

       cmp  al,ESCAPE                               ;Non, est-ce ESCAPE?
       jne  i9_end                   ;Non, passe … l'ancien gestionnaire

   ;-- La touche ESCAPE a ‚t‚ actionn‚e --------------------------------

       push ds                                        ;M‚morise DS et SI
       push si
       lds  si,key_ptr        ;Charge un pointeur sur la variable ESCAPE
       mov  word ptr [si],1                 ;Met … 1 l'indicateur ESCAPE
       cmp  escdirect,0              ;Effacer l'indicateur de Time-Out ?
       je   i9_1                                          ;Non ---> I9_1

       lds  si,tout_ptr  ;Oui, charge un ptr sur le compteur de Time Out
       mov  word ptr [si],0                         ;Met le compteur … 0

i9_1:  pop  si                                        ;Restaure DS et SI
       pop  ds

       mov  al,EOI                    ;Indique la fin  de l'interruption
       out  INT_CTR,al

       pop  ax                                              ;R‚cupŠre AX
       iret                            ;Retourne au programme interrompu

i9_end: pop  ax                                             ;R‚cupŠre AX
       jmp  cs:[int9_ptr]          ;Se branche sur l'ancien gestionnaire

int09      endp

;-- Nouveau gestionnaire de l'interruption 1Ch -------------------------

int1C      proc far

       push ds                                        ;m‚morise DS et SI
       push si
       lds  si,tout_ptr  ;Charge un pointeur sur le compteur de Time Out
       cmp  word ptr [si],0                          ;Compteur d‚j… … 0?
       je   no_dekr                        ;OUI ---> ne plus d‚cr‚menter

       dec  word ptr [si]                              ;Non, d‚cr‚menter

no_dekr: pop  si                                      ;Restaure DS et SI
       pop  ds

       jmp  cs:[int1C_ptr]                ;Passe … l'ancien gestionnaire

int1C      endp

;-----------------------------------------------------------------------

_text      ends                                  ;Fin du segment de code
           end                                         ;Fin du programme
