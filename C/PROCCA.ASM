;**********************************************************************;
;*                           P R O C C A                              *;
;*--------------------------------------------------------------------*;
;*    Fonction        : Fournit une fonction … int‚grer dans un       *;
;*                     programme C et servant … d‚terminer le type    *;
;*                     de processeur sur un PC                        *;
;*                                                                    *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    : 15.08.1988                                    *;
;*    DerniŠre modif. : 10.02.1992                                    *;
;*--------------------------------------------------------------------*;
;*    Pour assembler   : MASM PROCCA;  ou TASM PROCCA                 *;
;*                     ... puis linker avec un programme C            *;
;**********************************************************************;

IGROUP group _text               ;Regroupement des segments de programme
DGROUP group _bss,  _data          ;Regroupement des segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS' ;Ce segment re‡oit toutes les variables
_BSS   ends                                  ;statiques non initialis‚es

_DATA  segment word public 'DATA'      ;Toutes les variables globales et
                                    ;statiques initialis‚es sont plac‚es
                                                        ;dans ce segment

_DATA  ends

;== Constantes =========================================================

p_i486    equ   8                           ;Codes pour les divers types
p_i386    equ   7                                         ;de processeur
p_80286   equ   6
p_80186   equ   5
p_80188   equ   4
p_v30     equ   3
p_v20     equ   2
p_8086    equ   1
p_8088    equ   0

co_i387   equ   3                          ;Codes pour les coprocesseurs
co_80287  equ   2
co_8087   equ   1
co_aucun  equ   0

NOP_CODE  equ   90h                               ;Code machine pour NOP
DEC_DX_C  equ   4Ah                            ;Code machine pour DEC DX

;== Variables  globales ================================================

_DATA  segment word public 'DATA'

cpz       dw 0                                   ;Pour test coprocesseur

_DATA  ends

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'               ;Le segment de programme

public   _getproc   ;Fonction rendue accessible pour d'autres programmes
public   _getco

;-- GETPROC: D‚termine le type de processeur ‚quipant un PC ---
;-- Appel en C : int getproc( void );
;-- Sortie     : Num‚ro du type de processeur (voir les constantes)

_getproc  proc near

          pushf             ;Sauvegarder le contenu du registre de flags
          push  di

            ;== Tester si i486/i386/80286  =============================

          xor   ax,ax                                   ;R‚gler AX sur 0
          push  ax                                ;et placer sur la pile
          popf               ;Retirer de la pile comme registre de flags
          pushf                                    ;Replacer sur la pile
          pop  ax                                    ;et ramener dans AX
          and  ax,0f000h       ;Annuler tous bits sauf 4 bits sup‚rieurs
          cmp  ax,0f000h           ;Les bits 12 … 15 valent-ils tous 1 ?
          je   inferieur_286              ;OUI, modŠle ant‚rieur … 80286

                   ;-- Tester s'il s'agit d'un i486, i386 ou 80286  ----

          mov  dl,p_80286                   ;Il s'agit dans tous les cas
          mov  ax,07000h                     ;d'un des trois processeurs
          push ax                   ;Placer la valeur 07000h sur la pile
          popf                          ;Retirer comme registre de flags
          pushf                                 ;et replacer sur la pile
          pop  ax                           ;Ramener dans le registre AX
          and  ax,07000h    ;Masquer tous les bits sauf les bits 12 … 14
          je   pfin                 ;Les bits 12 … 14 valent-ils tous 0?
                                           ;OUI --> Il s'agit d'un 80286

          inc  dl                              ;Non, il s'agit d'un i386
                                    ;ou i486. Commencer d'abord par i386

     ;-- Comparer i386 et i486 avec un test de file d'attente -
     ;-- A cet effet, on place une instruction DX INC de sorte qu'elle
     ;-- apparaisse dans la queue dans le cas d'un i486 et non d'un i386.
     ;-- Dans le code programme, cette instruction est
     ;-- remplac‚e par une instruction STI. Si elle ne se trouve pas
     ;-- encore dans la queue (i386) il faut alors incr‚menter DX.
     ;-- Si elle est d‚j… dans la queue (486), cette instruction ne peut
     ;-- toutefois ˆtre plus modifi‚e.

          cli

db 066h,08Bh,0DCh          ;mov    ebx,esp           garde SP
db 066h,083h,0E4h,0FCh     ;and    esp,0FFFCh        aligne sur un long
db 066h,09Ch               ;pushfd                   sauve reg. flag
db 066h,058h               ;pop    eax               r‚cup dans AX
db 066h,08Bh,0C8h          ;mov    ecx,eax           et CX
db 066h,035h,000h,0h,4h,0h ;xor    eax,1 shl 18      bit align XOR
db 066h,050h               ;push   eax               sur la pile
db 066h,09Dh               ;popfd                    pour reg de flag
db 066h,09Ch               ;pushfd                   r‚enpile
db 066h,058h               ;pop    eax               r‚cup dans AX
db 066h,051h               ;push   ecx               ancien flag
db 066h,09Dh               ;popfd                    r‚cup‚r‚s
db 066h,033h,0C1h          ;xor    eax,ecx           test bit AL
db 066h,0C1h,0E8h,012h     ;shr    eax,18            d‚cal sur 0
db 066h,083h,0E0h,001h     ;and    eax,1h            masque les autres
db 066h,08Bh,0E3h          ;mov    esp,ebx           restaure sp
      
      
      sti                                             ;interrupt valides
      add  dl,al                                        ; si al=1 -> 486
      jmp  pfin                                            ; fin du test
      
             ;== Tester si 80186 ou 80188 ==============================

inferieur_286 label near

          mov  dl,p_80188                      ;Charger le code du 80188
          mov  al,0ffh        ;R‚gler tous les bits du registre AL sur 1
          mov  cl,021h          ;Nombre d'op‚rations de d‚calage dans CL
          shr  al,cl                  ;D‚caler AL CL fois vers la droite
          jne  t88_86          ;AL ne vaut pas 0, il s'agit forc‚ment du
                                                         ;80188 ou 80186

             ;== Tester si NEC V20 ou V30 ==============================

          mov  dl,p_v20                    ;Charger le code pour NEC V20
          sti                 ;Les interruptions doivent ˆtre autoris‚es
          push si                      ;Ranger le contenu du registre SI
          mov  si,0              ;Commencer par le premier octet dans ES
          mov  cx,0ffffh                        ;Lire un segment complet
          rep  lods byte ptr es:[si]       ;REP avec un Segment Override
                                 ;fonctionne seulement avec NEC V20, V30
          pop  si                       ;Retirer … nouveau SI de la pile
          or   cx,cx             ;Le segment a-t-il ‚t‚ entiŠrement lu ?
          je   t88_86                          ;OUI --> c'est V20 ou V30

          mov  dl,p_8088             ;NON --> c'est donc un 8088 ou 8086

                ;==  Tester si ...88 ou ...86 ou V20 ou V30 ============

       ;-- Ex‚cuter le test … l'aide de la queue (comme ci-dessus), mais
                                  ;-- utiliser ici une queue plus petite

t88_86    label near

          push cs                                 ;Ranger CS sur la pile
          pop  es                                    ;et ramener dans ES
          std      ;Pour les instructions de chaŒne, compter vers le bas
          mov  di,offset q2_end          ;Placer DI … la fin de la queue
          mov  al,0fbh                    ;Code d'instruction pour "STI"
          mov  cx,3                ;Ex‚cuter 3 fois l'instruction chaŒne
          cli                               ;Interdire les interruptions
          rep  stosb                      ;R‚‚crire l'instruction DX INC
          cld    ;A nouveau vers le haut pour les instructions de chaŒne
          nop             ;Instructions fictives pour compl‚ter la queue
          nop
          nop

          inc  dx                        ;Incr‚menter le code processeur
          nop
q2_end:   sti                     ;Autoriser … nouveau les interruptions

          ;-------------------------------------------------------------

pfin     label near                             ;Les tests sont termin‚s

          pop  di
          popf                  ;Retirer le registre de flags de la pile
          xor  dh,dh       ;Octet de poids fort du code processeur sur 0
          mov  ax,dx          ;Le code processeur =valeur de la fonction
          ret                               ;Retour au programme d'appel

_getproc  endp                                      ;Fin de la proc‚dure

;-- GETCO : d‚termine la pr‚sence d'un coprocesseur --------------------
;-- Appel en C : int getco( void ); ------------------------------------
;-- sortie : nø dans la liste des coprocesseurs ------------------------

_getco    proc near

          mov    dx,co_aucun                        ;pas de coprocesseur

          mov    byte ptr cs:wait1,NOP_CODE                ;WAIT (80x87)
          mov    byte ptr cs:wait2,NOP_CODE            ;remplac‚ par NOP

wait1:    finit                                       ;initialise coproc
          mov    byte ptr cpz+1,0                    ;msb mot de control
wait2:    fstcw  cpz                               ;r‚cup mot de control
          cmp    byte ptr cpz+1,3                ;coprocesseur pr‚sent ?
          jne    gfin                                     ;pas de coproc

;-- Coprocesseur d‚tect‚. Test 8087 ------------------------------------

          inc    dx
          and    cpz,0FF7Fh             ;masque d'interruption valid‚es
          fldcw  cpz                            ;dans le mot de control
          fdisi                                               ;flag IEM
          fstcw  cpz                            ;dans le mot de control
          test   cpz,080h                           ;Flag IEM pr‚sent ?
          jne    gfin                                      ; oui = 8087

;-- Test pour 80287/i387/i487 -----------------------------------------

          inc    dx
          finit                                       ;initialise 80x87
          fld1                                                ;empile 1
          fldz                                                ;empile 0
          fdiv                                   ;1 / 0, erreur dans ST
          fld    st                                          ;ST empil‚
          fchs                                                  ;ST=-ST
          fcompp                          ;compare et d‚pile ST et ST(1)
          fstsw  cpz                            ;sauve r‚sultat dans cpz
          mov    ah,byte ptr cpz+1
          sahf                              ;et dans le registre de flag
          je     gfin                           ;flag de z‚ro =1 : 80287

          inc    dx                        ;sinon i387, i486DX ou i487SX
gfin:     mov    ax,dx                                         ;r‚sultat
          ret

_getco    endp

;== Fin ================================================================

_text     ends                              ;Fin du segment de programme
          end                               ;Fin du source en Assembleur
