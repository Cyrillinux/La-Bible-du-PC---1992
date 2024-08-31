;**********************************************************************;
;*                             T Y P M P A                            *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Routine en assembleur … inclure dans un        *;
;*                     programme en Turbo Pascal permettant de fixer  *;
;*                     la vitesse Typematic du clavier ‚tendu         *;
;*--------------------------------------------------------------------*;
;*    Auteur                : MICHAEL TISCHER                         *;
;*    D‚velopp‚ le          : 27.08.1988                              *;
;*    DerniŠre modification : 01.03.1992                              *;
;*--------------------------------------------------------------------*;
;*    Assemblage   : MASM TYPMPA;                                     *;
;*                   LINK TYPMPA                                      *;
;*                   EXE2BIN TYPMPA TYPMPA.BIN                        *;
;* ...transformer en instructions INLINE et inclure dans              *;
;*                    le programme TYPMP.PAS                          *;
;**********************************************************************;

;== Constantes =========================================================

KB_STATUS_P   equ 64h                            ;Port d'‚tat du clavier
KB_DATA_P     equ 60h                        ;Port de donn‚es du clavier

OB_FULL       equ 1                ;Bit 0 dans le port d'‚tat du clavier
                                  ;un caractŠre dans le buffer de sortie
IB_FULL       equ 2                ;Bit 1 dans le port d'‚tat du clavier
                                   ;un caractŠre dans le buffer d'entr‚e

ACK_SIGNAL    equ 0fah          ;Signal d'accus‚ de r‚ception du clavier
SET_TYPEM     equ 0f3h                           ;Commande Set Typematic

MAX_TRY       equ 3                       ;Nombre de tentatives permises


;== Programmcode =======================================================

code      segment para 'CODE'             ;D‚finition du segment de code

          org  100h

          assume cs:code, ds:code, ss:code, es:code

;-----------------------------------------------------------------------
;-- SET_TYPM: Transmet la vitesse Typematic au contr“leur du clavier ---
;--
;-- Info    : On suppose que le modŠle est du type FAR CALL

set_typm   proc near

sframe0    struc                       ;Structure pour acc‚der … la pile
bp0        dw ?                                             ;M‚morise BP
ret_adr0   dd ?                          ;Adresse de retour … l'appelant
                                                         ;(Adresse FAR )
trate0     dw ?                               ;Vitesse Typematic … fixer
sframe0    ends                                     ;Fin de la structure

frame      equ [ bp - bp0 ]        ;Adresse les ‚l‚ments de la structure

           ;-- Les deux instuctions suivantes sont d‚j… effectu‚es------
           ;-- par TURBO                                        --------

                                      ;push bp                ;Empile BP
                           ;mov  bp,sp             ;TransfŠre SP dans BP

           xor  dl,dl                 ;Transmission a priori d‚fectueuse
           mov  ah,SET_TYPEM      ;Commande de fixation vitesse Typmatic
           cli                                 ;Inhibe les interruptions
           call send_kb                              ;Vers le contr“leur
           jne  error                              ;Erreur? Oui--> Error

           mov  ah,byte ptr frame.trate0       ;Lit la vitesse Typematic
           call send_kb                              ;Vers le contr“leur
           jne  error                              ;Erreur? Oui -> Error

           inc  dl                           ;tout va bien, renvoie TRUE

error:     sti                               ;R‚tablit les interruptions
           mov  [bp-1],dl           ;Mat la valeur de retour sur la pile
                             ;pop  bp               ;Restaure BP (TURBO)
           jmp  fin                    ;Rend la main au programme Pascal

set_typm   endp

;-----------------------------------------------------------------------
;-- SEND_KB: Envoie un octet au contr“leur du clavier  -----------------
;-- Entr‚e   : AH = octet … envoyer
;-- Sortie   : Indicateur de z‚ro: 0=Erreur, 1=o.k.
;-- Registres: AX le registre des indicateurs sont modifi‚s
;-- Info     : Routine … usage interne, ne doit petre appel‚e qu'…
;--            partir du pr‚sent module

send_kb   proc near

          push cx                             ;Empile tous les registres
          push bx                               ;modifi‚s par la routine

          mov  bl,MAX_TRY                 ;Nombre de tentatives tol‚r‚es

          ;-- Attend que le contr“leur puisse recevoir des donn‚es -----

skb_1:    xor  cx,cx                        ;65536 it‚rations au maximum
skb_2:    in   al,KB_STATUS_P             ;Lit le contenu du port d'‚tat
          test al,IB_FULL         ;Reste-t-il un caractŠre dans buffer ?
          loopne skb_2                                     ;Oui--> SKB_2

          ;-- Envoie un caractŠre au contr“leur ------------------------

          mov  al,ah                       ;TransfŠre le caractŠre en AL
          out  KB_DATA_P,al               ; puis dans le port de donn‚es
skb_3:    in   al,KB_STATUS_P             ;Lit le contenu du port d'‚tat
          test al,OB_FULL            ;R‚ponse dans le buffer de sortie ?
          loope skb_3                                    ;Non  --> SKB_3

          ;-- Lit et exploite la r‚ponse du contr“leur    --------------

          in   al,KB_DATA_P                      ;Lit le port de donn‚es
          cmp  al,ACK_SIGNAL                        ;CaractŠre accept‚ ?
          je   skb_end                              ;Oui -> tout va bien

          ;-- Le caractŠre n'a pas ‚t‚ accept‚   -----------------------

          dec  bl                      ;D‚cr‚mente le compteur d'erreurs
          jne  skb_2                              ;Peut-on recommencer ?
                                                           ;Oui--> SKB_2

          or   bl,1                ;Non, mettre … 0 l'indicateur de z‚ro
                                                 ;pour signaler l'erreur

skb_end:  pop  bx                      ;D‚pile les registres sauvegard‚s
          pop  cx                                                      ;
          ret                                     ;Retourne … l'appelant

send_kb   endp

;-----------------------------------------------------------------------

fin      label near

;== Fin ================================================================

code      ends                                   ;Fin du segment de code
          end  set_typm

