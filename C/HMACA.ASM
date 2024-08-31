;**********************************************************************;
;*                           H M A C A . A S M                        *;
;*--------------------------------------------------------------------*;
;*    Sujet        : Routine en assembleur … int‚grer au programme C  *;
;*                     HMAC.C. Contient une routine d'interrogation   *;
;*                     de la m‚moire ‚tendue et de lib‚ration/blocage *;
;*                     du canal d'adresses A20.                       *;
;*                     Cette impl‚mentation est destin‚e au modŠle    *;
;*                     de m‚moire SMALL.                              *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    : 28.07.1990                                    *;
;*    DerniŠre m. … j : 28.07.1990                                    *;
;*--------------------------------------------------------------------*;
;*    assembler       : MASM HAMCA;   ou    TASM HMACA;               *;
;*                     ... et ensuite lier au programme C HMAC.C      *;
;*                         compil‚.                                   *;
;**********************************************************************;

;== Constantes =========================================================

KB_COMMAND equ 64h                               ;Port commandes clavier
KB_STATUS  equ 64h                                ;est aussi port d'‚tat
KB_DATA    equ 60h                              ;Port donn‚es du clavier
IB_FREE    equ 2                      ;Masque pour test d'Input Buf vide
WO_COMMAND equ 0D1h               ;Commande d'‚criture de la Output Port

GATE_ON    equ 11011111b                ;Code de canal adresse A20 libre
GATE_OFF   equ 11011101b               ;Code de canal adresse A20 bloqu‚

;== D‚clarations de segments pour le programme en C ====================

IGROUP group _text                       ;R‚sum‚ des segments programmes
DGROUP group _bss, _data                    ;R‚sum‚ des segments donn‚es
       assume CS:IGROUP, DS:DGROUP, ES:DGROUP, SS:DGROUP

_BSS   segment word public 'BSS' ;ce segment r‚cupŠre ttes les variables
_BSS   ends                                  ;statiques non initialis‚es

_DATA  segment word public 'DATA'     ;Toutes les variables initialis‚es
                                  ;globales et statiques sont regroup‚es
                                                        ;dans ce segment

_DATA  ends

;== Programme ==========================================================

_TEXT  segment byte public 'CODE'                  ;le segment programme

public     _HMAAvail
public     _GateA20
public     _IsA20On

;-----------------------------------------------------------------------
;-- HMAAvail : indiquera se le HMA existe
;-- Appel du C: BOOL HMAAvail( void )
;-- Valeur de retour : TRUE, si HMA disponible, sinon FALSE

_HMAAvail  proc near

      ;-- Tester d'abord si AT ou 386 ----------------------------------

      xor    ax,ax                   ;Ces instructions sont recommand‚es
      push   ax                      ;par Intel pour d‚tecter le type de
      popf                       ;processeur. Elles prouvent l'existence
      pushf                                      ;d'un 8088 ou d'un 8086
      pop    ax
      and    ax,0F000h
      cmp    ax,0F000h
      je     pashma                            ;PC normal PC ---> pashma

      ;-- AT ou 386, mais avec m‚moire ‚tendue? ------------------------

      mov    ah,88h                  ;Taille m‚moire ‚tendue par le BIOS
      int    15h                                                       ;
      cmp    ax,64                   ;Plus de 64 Ko en m‚moire ‚tendue ?
      jb     pashma                                     ;Non, aucune HMA

      mov    ax,0FFFFh                                    ;Oui, HMA prˆt
      ret                                        ;alors on retourne TRUE

pashma:
      xor    ax,ax                               ;Retourner 0 pour FALSE
      ret                                         ;retour au programme C

_HMAAvail  endp

;-----------------------------------------------------------------------
;-- GateA20 : Lib‚rer ou bloquer le canal d'adresses A20
;-- Appel par C: BOOL GateA20( BOOL libre )
;-- Valeur de retour: TRUE si l'op‚ration est r‚ussie, sinon FALSE

_GateA20   proc near

            ;-- Structure pour acc‚der facilement au paramŠtre ---------

sframe    struc                        ;Structure pour acc‚der … la pile
bp0        dw ?                                               ;stocke BP
ret_adr    dw ?                          ;Adresse de retour … l'appelant
libre      dw ?                               ;bloque ou libŠre le canal
sframe    ends                                      ;fin de la structure

frame equ [ bp - bp0 ]             ;adresse les ‚l‚ments de la structure

      ;-- Macro demandant l'‚tat du contr“leur du clavier --------------

kbc_ready  macro                              ;Contr“leur clavier prˆt ?
      local  notready

notready:
      in     al,KB_STATUS                         ;Interroge port d'‚tat
      test   al,IB_FREE                             ;Tampon Input vide ?
      loopne notready           ;Non, et CX encore diff‚rent de z‚ro -->

           endm

      ;-- Voici le d‚but du code de la proc‚dure -----------------------

      push   bp                                   ;Stocke BP sur la pile
      mov    bp,sp                                   ;Copier SP aprŠs BP

      mov    ah,11011101b                ;Cette valeur = "bloquer canal"
      cmp    frame.libre,0                               ;bloquer canal?
      je     g1                                    ;Oui, le code est OK.

      mov    ah,11011111b         ;Non, charger le code de "canal libre"

g1:   xor    cx,cx                               ;compteur pour Time Out
      cli                              ;aucune Interruption en ce moment
      kbc_ready                             ;attendre contr“leur clavier
      jne    gerr                               ;Time Out? oui ---> GERR

      mov    al,WO_COMMAND          ;Envoyer le code d'accŠs … Output-P.
      out    KB_COMMAND,al                        ;au port d'instruction

      kbc_ready                             ;attendre contr“leur clavier
      jne    gerr                               ;Time Out? oui ---> GERR

      mov    al,ah            ;Envoyer instruction de lib‚ration/blocage
      out    KB_DATA,al                              ;au port de donn‚es

      kbc_ready                             ;attendre contr“leur clavier
      sti                                          ;Interruption activ‚e
      jne    gerr                               ;Time Out? oui ---> GERR

      mov    ax,0FFFFh                    ;Pas de Time Out, tout va bien
      pop    bp                                     ;Lire BP sur la pile
      ret

gerr: xor    ax,ax                              ;aucune bascule possible
      pop    bp                                   ;Relire BP sur la pile
      ret

_GateA20   endp

;-----------------------------------------------------------------------
;-- IsA20On : Indique si le canal d'adresses A20 est lib‚r‚
;-- Appel par C: BOOL IsA20( void )
;-- Valeur de retour : TRUE, si canal libre sinon FALSE

ramptr     dd 000000000h       ;Pointeur dans la m‚moire conventionnelle
extptr     dd 0FFFF0010h               ;Pointeur dans la m‚moire ‚tendue

_IsA20On   proc near

      push   ds
      push   es

      lds    si,cs:ramptr    ;Si le canal est bloqu‚, les deux pointeurs
      les    di,cs:extptr               ;d‚signent une adresse identique

      mov    cx,64                                  ;Comparer 128 octets
      cld                 ;Si instruction de chaŒne compter vers le haut
      repe   cmpsw                    ;compare les deux blocs de m‚moire

      pop    es                                  ;R‚cupŠre les registres
      pop    ds
      jcxz   a20off                 ;CX = 0 --> Blocs m‚moire identiques

      mov    ax,0FFFFh                ;Bloc diff‚rent ---> A20 est actif
      ret

a20off:
      xor    ax,ax                  ;Blovc identique ---> A20 est bloqu‚
      ret

_IsA20On   endp

;-----------------------------------------------------------------------

_text      ends                                  ;fin du segment de code
           end                                         ;fin du programme
