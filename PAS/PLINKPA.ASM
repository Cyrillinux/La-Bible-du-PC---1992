;**********************************************************************;
;*                         P L I N K P A . A S M                      *;
;*--------------------------------------------------------------------*;
;*    Fonction        : Compl‚ment en assembleur du programme Pascal  *;
;*                      PLINKP - Contient en plus des gestionnaires   *;
;*                      d'interruption des routines d'accŠs rapide    *;
;*                      aux ports                                     *;
;*--------------------------------------------------------------------*;
;*    Auteur        : MICHAEL TISCHER                                 *;
;*    D‚velopp‚ le  : 10.10.1991                                      *;
;*    DerniŠre MAJ  : 11.10.1991                                      *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : TASM PLINKPA                                   *;
;*                     ... puis lier … PLINKP                         *;
;**********************************************************************;

;== Constantes =========================================================

KB_PORT   = 60h                                         ;Port du clavier
INT_CTR   = 20h                       ;Port du contr“leur d'interruption
EOI       = 20h                             ;Commande fin d'interruption
ESCAPE    = 1                             ;Scan-Code de la touche Escape

;== Segment de donn‚es =================================================

DATA   segment word public                        ;Segment de donn‚es TP

extrn    InPort                         ;Port d'entr‚e comme variable TP
extrn    OutPort                       ;Port de sortie comme variable TP

DATA   ends                                   ;Fin du segment de donn‚es

;== Programme ==========================================================

CODE       segment byte public                       ;Segment de code TP

           assume cs:CODE, ds:DATA, es:nothing, ss:nothing

;-- D‚clarations publiques de fonctions internes ----------------------

public     intr_install         ;Permet l'appel … partir du programme TP
public     intr_remove
public     escapedirect
public     getb
public     putb

;-- Variables pour les gestionnaires d'interruption---------------------
;-- (accessibles uniquement par le segment de code -------------

key_ptr    dd 0                         ;Pointeur sur la var pour ESCAPE
tout_ptr   dd 0                       ;Pointeur sur compteur de Time Out
escdirect  db 0                         ;Pas de Time Out en cas d'Escape

;-- Les variables suivantes m‚morisent les anciennes adresses des  ---
;-- interruptions avant la mise en service des nouvelles           ---

int9_ptr   equ this dword              ;ancien vecteur d'interruption 9h
int9_ofs   dw 0                                                  ;Offset
int9_seg   dw 0                                                 ;Segment

int1C_ptr  equ this dword             ;Ancien vecteur d'unterruption 1Ch
int1C_ofs  dw 0                                                  ;Offset
int1C_seg  dw 0                                                 ;Segment

;----------------------------------------------------------------------
;-- GETB : lit un octet sur le port d'entr‚e
;-- Appel depuis TP: getb : BYTE;

getb      proc near

      mov  dx,InPort                              ;Adresse du port en DX
      in   al,dx                                            ;Lit le port
      and  al,0F8h                                  ;EnlŠve les bits 0-2

      ret                                     ;Renvoie le r‚sultat en AL

getb      endp

;----------------------------------------------------------------------
;-- PUTB : ‚met un octet sur le port de sortie
;-- Appel depuis TP : putb( Wert : BYTE );

putb       proc near

valeur equ byte ptr [bp+4]                    ;Variable transmise par TP

       push bp                           ;Permet d'acc‚der aux arguments
       mov  bp, sp

       mov al, valeur                           ; Charge la valeur en AL
       mov  dx, OutPort        ;Charge en DX l'adresse du port de sortie
       out  dx, al                          ;Ecit la valeur dans le port

       pop  bp                                              ;restaure BP
       ret  2                           ;Nettoie la pile et rend la main

putb       endp

;-----------------------------------------------------------------------
;-- INTR_INSTALL: Installe les gestionnaires d'interruption
;-- Appel depuis TP : intr_install( escape_flag, timeout_count : ptr );

intr_install  proc near

sframe0    struc                       ;Structure pour acc‚der … la pile
bp0        dw ?                                             ;m‚morise BP
ret_adr0   dw ?                                       ;Adresse de retour
toptr      dd ?                 ;Pointeur FAR sur le compteur de Timeout
escptr     dd ?                    ;Pointeur FAR sur l'indicateur ESCAPE
sframe0    ends                                     ;Fin de la structure

frame  equ [ bp - bp0 ]

       push bp                                  ;m‚morise BP sur la pile
       mov  bp,sp                                    ;TransfŠre SP en BP
       push es                                     ;Sauve ES sur la pile

           ;-- Cherche les arguments sur la pile et les traite ---------

       les  si,frame.escptr      ;Charge un pointeur sur l'indic. ESCAPE
       mov  word ptr key_ptr,si      ;et le transfŠre dans les variables
       mov  word ptr key_ptr+2,es                    ;du segment de code

       les  si,frame.toptr;Charge un pointeur sur le compteur de Timeout
       mov  word ptr tout_ptr,si     ;et le transfŠre dans les variables
       mov  word ptr tout_ptr+2,es                   ;du segment de code

                     ;-- Lit les adresses des gestionnaires … d‚tourner-

       mov  ax,3509h         ;LIT l'adresse du vecteur d'interruption 9h
       int  21h                                                        ;
       mov  int9_ofs,bx                                  ;et la m‚morise
       mov  int9_seg,es                                                ;

       mov  ax,351Ch        ;Lit l'adresse du vecteur d'interruption 1Ch
       int  21h                                                        ;
       mov  int1C_ofs,bx                                 ;et la m‚morise
       mov  int1C_seg,es                                               ;

           ;-- Installe les nouveaux gestionnaires d'interruption ------

       push ds                             ;Stocke le segment de donn‚es
       mov  ax,cs                                    ;Rend DS ‚gal …  CS
       mov  ds,ax

       mov  ax,2509h ;Fonction: "Fixer le driver pour l'interruption 9h"
       mov  dx,offset int09   ;DS:DX recueille l'adresse du gestionnaire
       int  21h                         ;d‚clenche l'interruption de DOS

       mov  ax,251Ch ;Fonction:"Fixer le driver pour l'interruption 1Ch"
       mov  dx,offset int1C   ;DS:DX recueille l'adresse du gestionnaire
       int  21h                         ;d‚clenche l'interruption de DOS

       pop  ds                                   ;Reprend DS sur la pile
       pop  es
       pop  bp                                              ;R‚cupŠre BP
       ret  8                              ;et rend la main … l'appelant

intr_install endp

;-----------------------------------------------------------------------
;-- INTR_REMOVE: D‚sactive les gestionnaires d'interruption
;-- Appel depuis TP: intr_remove;

intr_remove proc near

       cli                                     ;Inhibe les interruptions
       push ds                                            ;Sauvegarde DS

       mov  ax,2509h      ;Fonction: "Fixer le gestionnaire pour INT 9 "
       mov  ds,int9_seg                ;Segment de l'ancien gestionnaire
       mov  dx,int9_ofs                 ;Offset de l'ancien gestionnaire
       int  21h                          ;R‚tablit l'ancien gestionnaire

       mov  ax,251Ch      ;Fonction: "Fixer le gestionnaire pour INT 1C"
       mov  ds,int1C_seg               ;Segment de l'ancien gestionnaire
       mov  dx,int1C_ofs                ;Offset de l'ancien gestionnaire
       int  21h                          ;R‚tablit l'ancien gestionnaire

       pop  ds                                               ;Reprend DS
       sti                        ;Autorise … nouveau les interrruptions

       ret                                        ;retourn‚ … l'appelant

intr_remove endp                                    ;Fin de la proc‚dure

;-----------------------------------------------------------------------
;-- EscapeDirect: D‚termine si en cas d'Escape il faut d‚clencher
;--               un Time Out
;-- Appel depuis TP: procedure EscapeDirect( Declenche : boolean );

EscapeDirect proc near

sframe1    struc                            ;Structure d'accŠs … la pile
bp1        dw ?                                             ;M‚morise BP
ret_adr1   dw ?                                       ;Adresse de retour
escflag    dw ?                                           ;TRUE ou FALSE
sframe1    ends                                     ;Fin de la structure

frame  equ [ bp - bp1 ]

       push bp                                                ;Empile BP
       mov  bp,sp                                 ;et tranfsŠre SP en BP

       mov  al,byte ptr frame.escflag               ;Charge l'indicateur
       mov  escdirect,al              ;et le d‚pose dans une variable CS

       pop  bp
       ret  2                 ;Retourne … l'appelant , enlŠve l'argument
                                                            ; de la pile

EscapeDirect endp

;-----------------------------------------------------------------------
;--         Voici les nouveaux gestionnaires d'interruption           --
;-----------------------------------------------------------------------

       assume CS:CODE, DS:nothing, ES:nothing, SS:nothing

;-- nouveau gestionnaire de l'interruption 09h -------------------------

int09      proc far

       push ax                                ;Sauvegarde AX sur la pile
       in   al,KB_PORT          ;Lit le scan code sur le port du clavier

       cmp  al,128                                       ;Code release ?
       jae  i9_end                                   ;Oui, ne pas tester

       cmp  al,ESCAPE                               ;Non, est-ce ESCAPE?
       jne  i9_end                   ;Non, passe … l'ancien gestionnaire

           ;-- La touche ESCAPE a ‚t‚ actionn‚e-------------------------

       push ds                                     ;Met de c“t‚ DS et SI
       push si
       lds  si,key_ptr        ;Charge un pointeur sur la variable Escape
       mov  word ptr [si],1                    ;Met … 1 l'indic.  ESCAPE
       cmp  escdirect,0             ;Faut-il effacer l'indic. Time Out ?
       je   i9_1                                          ;Non ---> I9_1

       lds  si,tout_ptr  ;Oui, charge un ptr sur le compteur de Time Out
       mov  word ptr [si],0                         ;Met le compteur … 0

i9_1:  pop  si                                        ;Restaure DS et SI
       pop  ds

       mov  al,EOI                     ;Indique la fin de l'interruption
       out  INT_CTR,al

       pop  ax                                               ;Reprend AX
       iret                         ;et retourne au programme interrompu

i9_end: pop  ax                                             ;R‚cupŠre AX
       jmp  cs:[int9_ptr]          ;Se branche sur l'ancien gestionnaire

int09      endp

;-- Nouveau gestionnaire de l'interruption 1Ch -------------------------

int1C      proc far

       push ds                                        ;M‚morise DS et SI
       push si
       lds  si,tout_ptr  ;Charge un pointeur sur le compteur de Time Out
       cmp  word ptr [si],0                               ;Compteur … 0?
       je   no_dekr                        ;OUI ---> ne plus d‚cr‚menter

       dec  word ptr [si]                              ;Non, d‚cr‚menter

no_dekr: pop  si                                      ;Restaure DS et SI
         pop  ds

        jmp  cs:[int1C_ptr]               ;Passe … l'ancien gestionnaire

int1C      endp

;-----------------------------------------------------------------------

CODE   ends                                      ;Fin du segment de code
       end                                             ;Fin du programme


