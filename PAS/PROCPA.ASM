;**********************************************************************;
;*                         P R O C P A . A S M                        *;
;*--------------------------------------------------------------------*;
;*    Fonction        : Fournit deux fonctions … int‚grer dans un     *;
;*                      programmem Pascal et servant … d‚terminer     *;
;*                      le type du processeur et du                   *;
;*                      coprocesseur.                                 *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    : 15.08.1988                                    *;
;*    DerniŠre modif. : 17.02.1992                                    *;
;*--------------------------------------------------------------------*;
;*    Pour assembler   : MASM PROCPA;  ou TASM PROCPA                 *;
;*                    ... puis int‚grer dans un programme Pascal avec *;
;*                        la directive $L du compilateur              *;
;**********************************************************************;

;== Constantes =========================================================

p_i486    equ   8                                ;Codes des divers types
p_i386    equ   7                                        ;de processeurs
p_80286   equ   6
p_80186   equ   5
p_80188   equ   4
p_v30     equ   3
p_v20     equ   2
p_8086    equ   1
p_8088    equ   0

co_i387   equ   3                               ;Codes des coprocesseurs
co_80287  equ   2
co_8087   equ   1
co_aucun  equ   0

NOP_CODE  equ   90h        ;Code de l'instruction de langage machine NOP
DEC_DX_C  equ   4Ah                                      ;Code de DEC DX

;== Segment de donn‚es =================================================

DATA      segment word public

cpz       dw  ?                            ;Pour le test du coprocesseur

DATA      ends

;== Programm ===========================================================

CODE      segment byte public                           ;Segment de code

          assume cs:code, ds:data

public    getproc                       ;Fonction rendue accessible pour
public    getco                                     ;d'autres programmes

;-- GETPROC: D‚termine le type du processeur ‚quipant le PC ---
;-- Appel de Pascal: fonction getproc : integer;
;-- Sortie : Num‚ro du type du processeur (se reporter aux constantes)

getproc   proc near

          pushf                  ;Sauver le contenu du registre de flags

            ;== Tester s'il s'agit d'un ant‚rieur ou post‚rieur … 80286 

          xor  ax,ax                                    ;R‚gler AX sur 0
          push ax                                 ;et placer sur la pile
          popf               ;Retirer de la pile comme registre de flags
          pushf                                    ;Replacer sur la pile
          pop  ax                                    ;et ramener dans AX
          and  ax,0f000h    ;Annuler tous les bits sauf les 4 sup‚rieurs
          cmp  ax,0f000h            ;Les bits 12 … 15 valent-ils tous 1?
          je   inferieur_286              ;Oui, modŠle ant‚rieur … 80286

                    ;-- Tester s'il s'agit d'un i486, i386 ou 80286 ----

          mov  dl,p_80286                ;Il s'agit dans tous les cas de
          mov  ax,07000h                     ;l'un des trois processeurs
          push ax                   ;Placer la valeur 07000h sur la pile
          popf                          ;Retirer comme registre de flags
          pushf                                 ;et replacer sur la pile
          pop  ax                           ;Ramener dans le registre AX
          and  ax,07000h    ;Masquer tous les bits sauf les bits 12 … 14
          je   pfin                 ;Les bits 12 … 14 valent-ils tous 0?
                                           ;OUI --> Il s'agit d'un 80286

          inc  dl                              ;Non, il s'agit d'un i386
                            ;ou i486. Avant tout, prendre en compte i386

                    ;-- Le test suivant entre i386 et i486 concerne ----
                       ;-- une extension du registre EFlags avec un i486
                                            ;-- … la position de bit 18.
              ;-- Ce flag n'existant pas dans un i386, il est impossible
                               ;-- de modifier son contenu par logiciel.

          cli                         ;Pas d'interruption pour l'instant

db 066h,08Bh,0DCh         ;mov    ebx,esp       Ranger SP actuel
db 066h,083h,0E4h,0FCh    ;and    esp,0FFFCh    Arrondir … DWORD
db 066h,09Ch              ;pushfd               Registre de flags sur la
db 066h,058h              ;pop    eax           pile aprŠs AX
db 066h,08Bh,0C8h         ;mov    ecx,eax       et ranger dans CX
db 066h,035h,000h,0h,4h,0h;xor    eax,1 shl 18  Transf‚rer le bit d'alignement
db 066h,050h              ;push   eax           et le placer dans Flag-
db 066h,09Dh              ;popfd                le registre de flags
db 066h,09Ch              ;pushfd               Remettre le flag sur la pile
db 066h,058h              ;pop    eax           puis replacer
db 066h,051h              ;push   ecx           l'ancien contenu du flag
db 066h,09Dh              ;popfd                aprŠs AX
db 066h,033h,0C1h         ;xor    eax,ecx       Tester bit AL
db 066h,0C1h,0E8h,012h    ;shr    eax,18        Bit AL aprŠs Bit 0
db 066h,083h,0E0h,001h    ;and    eax,1h        Remettre en place tous
db 066h,08Bh,0E3h         ;mov    esp,ebx       les SP restants.

          sti                             ;R‚autoriser les interruptions
          add  dl,al                                   ;AL vaut 1 si 486
          jmp  pfin                                 ;Le test est termin‚

             ;== Tester si 80186 ou 80188 ==============================

inferieur_286 label near

          mov  dl,p_80188                      ;Charger le code de 80188
          mov  al,0ffh        ;R‚gler tous les bits du registre AL sur 1
          mov  cl,021h          ;Nombre d'op‚rations de d‚calage dans CL
          shr  al,cl                  ;D‚caler AL CL fois vers la droite
          jne  t88_86          ;AL ne vaut pas 0, il s'agit forc‚ment du
                                                         ;80188 ou 80186
             ;== Tester si NEC V20 ou V30 ==============================

          mov  dl,p_v20                       ;Charger code pour NEC V20
          sti                 ;Les interruptions doivent ˆtre autoris‚es
          mov  si,0              ;Commencer par le premier octet dans ES
          mov  cx,0ffffh                        ;Lire un segment complet
          rep  lods byte ptr es:[si]       ;REP avec un segment Override
                                 ;Fonctionne seulement avec NEC V20, V30
          or   cx,cx              ;Le segment a-t-il ‚t‚ entiŠrement lu?
          je   t88_86                          ;OUI --> c'est V20 ou V30

          mov  dl,p_8088             ;NON --> c'est donc un 8088 ou 8086

                ;== Tester si ...88 ou ...86 ou. V20 ou V30 ============
            ;-- Ex‚cuter le test … l'aide de la queue (comme ci-dessus),
                            ;--  mais utiliser ici une queue plus petite

t88_86    label near

          push cs                                 ;Placer CS sur la pile
          pop  es                                   ;et ramener comme ES
          std               ;Vers le bas pour les instructions de chaŒne
          mov  di,offset q2_end          ;Placer DI … la fin de la queue
          mov  al,0fbh                    ;Code d'instruction pour "STI"
          mov  cx,3                ;Ex‚cuter l'instruction chaŒne 3 fois
          cli                               ;Interdire les interruptions
          rep  stosb                      ;R‚‚crire l'instruction INC DX
          cld       ;A nouveau vers le haut pour les instructions chaŒne
          nop      ;Instructions fictives pour remplir la file d'attente
          nop
          nop

          inc  dx                     ;Incr‚menter le code du processeur
          nop
q2_end:   sti                     ;Autoriser … nouveau les interruptions

          ;-------------------------------------------------------------

pfin     label near                             ;Les tests sont termin‚s

          popf        ;Retirer … nouveau le registre de flags de la pile
          xor  dh,dh       ;Octet de poids fort du code processeur sur 0
          mov  ax,dx     ;code processeur = valeur Return de la fonction

          ret                               ;Retour au programme d'appel


getproc   endp                                      ;Fin de la proc‚dure

;-- GETCO: D‚termine le type du coprocesseur … condition qu'il existe --
;-- Appel de Pascal: function getco : integer;
;-- Sortie     : Num‚ro du type du coprocesseur (voir les constantes)

getco     proc near

          mov   dx,co_aucun           ;Commencer … partir du CP manquant

          mov   byte ptr cs:wait1,NOP_CODE ;Remplacer commande WAIT 8087
          mov   byte ptr cs:wait2,NOP_CODE                      ;par NOP

wait1:    finit                                         ;Initialiser Cop
          mov   byte ptr cpz+1,0             ;Hi-Byte Control-Word sur 0
wait2:    fstcw cpz                            ;Sauvegarder Control-Word
          cmp   byte ptr cpz+1,3              ;Hi-Byte Control-Word = 3?
          jne   gcfin                      ;Non ---> Pas de coprocesseur

                    ;-- Il existe un coprocesseur. Tester 8087  --------

          inc   dx
          and   cpz,0FF7Fh           ;Masquer Interrupt-Enable-Mask-Flag
          fldcw cpz                        ;Charger dans le Control-Word
          fdisi                                         ;Placer flag IEM
          fstcw cpz                              ;Recharger Control-Word
          test  cpz,80h                         ;Le flag IEM est-il mis?
          jne   gcfin          ;OUI ---> c'est un 8087, Terminer le test

               ;-- Tester 80287/i387 -----------------------------------

          inc   dx
          finit                                         ;Initialiser Cop
          fld1                                 ;Nombre 1 sur la pile Cop
          fldz                                 ;Nombre 0 sur la pile Cop
          fdiv                          ;Diviser 1 par 0, R‚sultat en ST
          fld   st                              ;D‚placer ST sur la pile
          fchs                                ;Permuter le signe dans ST
          fcompp                         ;Comparer ST et ST(1) et poppen
          fstsw cpz      ;Transf‚rer le r‚sultat du Status-Word dans ...
          mov   ah,byte ptr cpz+1  ;registre flags par la m‚moire et ...
          sahf                                           ;le registre AX
          je    gcfin                             ;Zero-Flag = 1 : 80287

          inc   dx  ;Pas de 80287, il s'agit forc‚ment d'un i387 ou d'un
                                                ;coproc. int‚gr‚ du i486

gcfin:    mov   ax,dx                        ;R‚sultat de fonction en AX
          ret                               ;Retour au programme d'appel

getco     endp

;== Fin ===============================================================

CODE       ends                                  ;Fin du segment de code
           end                                         ;Fin du programme
