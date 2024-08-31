;**********************************************************************;
;*                             T Y P M C A                            *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Routine en assembleur … inclure dans un        *;
;*                     programme en C permettant de fixer la vitesse  *;
;*                     Typematic du clavier ‚tendu                    *;
;*--------------------------------------------------------------------*;
;*    Auteur                : MICHAEL TISCHER                         *;
;*    D‚velopp‚ le          : 27.08.1988                              *;
;*    DerniŠre modification : 27.08.1988                              *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM TYPMCA;    ou       TASM TYPMCA           *;
;*                     ... puis lier avec TYPMC.C                     *;
;**********************************************************************;

;== constantes =========================================================

KB_STATUS_P   equ 64h                            ;Port d'‚tat du clavier
KB_DATA_P     equ 60h                        ;Port de donn‚es du clavier

OB_FULL       equ 1                ;Bit 0 dans le port d'‚tat du clavier
                                  ;un caractŠre dans le buffer de sortie
IB_FULL       equ 2                ;Bit 1 dans le port d'‚tat du clavier
                                   ;un caractŠre dans le buffer d'entr‚e

ACK_SIGNAL    equ 0fah            ;Signal accus‚ de r‚ception du clavier
SET_TYPEM     equ 0f3h                               ;Code Set Typematic

MAX_TRY       equ 3                       ;Nombre de tentatives permises

;== D‚claration des segments pour le programme en C ====================

IGROUP group _text               ;Regroupement des segments de programme
DGROUP group _bss,  _data          ;Regroupement des segments de donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS'        ;Segement accueillant toutes les
_BSS   ends                        ;variables statiques non initialis‚es

_DATA  segment word public 'DATA'              ;Segement accueillant les
                                        ;variables globales et statiques
                                                           ;initialis‚es
_DATA  ends

;== Programme===========================================================

_TEXT  segment byte public 'CODE'                  ;Segment de programme

public     _set_typm

;-----------------------------------------------------------------------
;-- SET_TYPM: Transmet la vitesse Typematic au contr“leur du clavier ---
;
;-- Appel depuis C: bool set_typem( byte trate );
;-- Renvoie : TRUE, si la vitesse Typematic a pu ˆtre fix‚e
;--               FALSE si une erreur est survenue

_set_typm  proc near

sframe0    struc                       ;Structure pour acc‚der … la pile
bp0        dw ?                                             ;M‚morise BP
ret_adr0   dw ?                          ;Adresse de retour … l'appelant
trate0     dw ?                               ;Vitesse Typematic … fixer
sframe0    ends                                     ;Fin de la structure

frame      equ [ bp - bp0 ]        ;Adresse les ‚l‚ments de la structure

       push bp                                                ;Empile BP
       mov  bp,sp                                  ;TransfŠre SP dans BP

       xor  dx,dx                     ;Transmission a priori d‚fectueuse
       mov  ah,SET_TYPEM          ;Commande de fixation vitesse Typmatic
       cli                                     ;Inhibe les interruptions
       call send_kb                                  ;Vers le contr“leur
       jne  error                                ;Erreur ? Oui --> Error

       mov  ah,byte ptr frame.trate0           ;Lit la vitesse Typematic
       call send_kb                                  ;Vers le contr“leur
       jne  error                                  ;Erreur Oui --> Error

       inc  dl                               ;tout va bien ,renvoie TRUE

error: sti                                   ;R‚tablit les interruptions
       mov  ax,dx                      ;Charge la valeur de retour en AX
       pop  bp                                              ;Restaure BP
       ret                               ;Rend la main au programme en C

_set_typm  endp

;-----------------------------------------------------------------------
;-- SEND_KB: envoie un octet au contr“leur du clavier ------------------
;-- Entr‚e   : AH = octet … evoyer
;-- Sortie : Indicateur de z‚ro : 0=Erreur , 1=o.k.
;-- Registres : AX et le registres des indicateurs
;     sont modifi‚s
;-- Info     : Routine … usage interne, ne peut ˆtre appel‚e
;--            qu'… partir du pr‚sent module

send_kb   proc near

      push cx                                 ;Empile tous les registres
      push bx                                   ;modifi‚s par la routine

      mov  bl,MAX_TRY                     ;Nombre de tentatives tol‚r‚es

                ;-- Attend que le contr“leur puisse recevoir des donn‚es

skb_1:    xor  cx,cx                        ;65536 it‚rations au maximum
skb_2: in   al,KB_STATUS_P                ;Lit le contenu du port d'‚tat
       test al,IB_FULL        ; Reste-t-il un caractŠre dans le buffer ?
       loopne skb_2                                       ;Oui --> SKB_2

                                   ;-- Envoie un caractŠre au contr“leur

        mov  al,ah                         ;TransfŠre le caractŠre en AL
        out  KB_DATA_P,al                  ;puis dans le port de donn‚es
skb_3:    in   al,KB_STATUS_P             ;Lit le contenu du port d'‚tat
        test al,OB_FULL              ;R‚ponse dans le buffer de sortie ?
        loope skb_3                                      ;Non  --> SKB_3

                 ;-- Lit et exploite la r‚ponse du contr“leur ----------

        in   al,KB_DATA_P                        ;Lit le port de donn‚es
        cmp  al,ACK_SIGNAL                          ;CaractŠre accept‚ ?
        je   skb_end                                ;Oui--> tout va bien

          ;-- Le caractŠre n'a pas ‚t‚ accept‚   -----------------------

        dec  bl                        ;D‚cr‚mente le compteur d'erreurs
        jne  skb_2                               ;Peut-on recommencer  ?
                                                           ;Oui--> SKB_2

        or   bl,1                 ;Non , Mettre … 0 l'indicateur de z‚ro
                                                 ;pour signaler l'erreur

skb_end: pop  bx                       ;D‚pile les registres sauvegard‚s
         pop  cx                                                       ;
         ret                                      ;Retourne … l'appelant

send_kb   endp

;-----------------------------------------------------------------------

_text  ends                                      ;Fin du segment de code
       end                                             ;Fin du programme
