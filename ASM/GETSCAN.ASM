;**********************************************************************;
;*                           G E T S C A N                            *;
;*--------------------------------------------------------------------*;
;*    Fonction : Affiche les scan codes du clavier avant qu'ils aient *;
;*               pu ˆtre filtr‚s et modifi‚s par un driver de clavier *;
;*--------------------------------------------------------------------*;
;*    Auteur                : MICHAEL TISCHER                         *;
;*    D‚velopp‚ le          : 08.12.1990                              *;
;*    DerniŠre modification : 02.01.1992                              *;
;*--------------------------------------------------------------------*;
;*    Assemblage   : MASM GETSCAN                                     *;
;*                   LINK GETSCAN                                     *;
;*                   EXE2BIN GETSCAN GETSCAN.COM                      *;
;*                                                                    *;
;*                     ou                                             *;
;*                                                                    *;
;*                   TASM GETSCAN                                     *;
;*                   TLINK /t GETSCAN                                 *;
;*--------------------------------------------------------------------*;
;*    Appel         : GETSCAN                                         *;
;**********************************************************************;

;== Constantes et structures ===========================================

INT_CTR   = 20h                       ;Port du contr“leur d'interruption
EOI       = 20h                                      ;Fin d'interruption
KB_PORT   = 60h                                         ;Port du clavier

;== D‚but du programme proprement dit     ==============================

code      segment para 'CODE'             ;D‚finition du segment de code

          org 100h

          assume cs:code, ds:code, es:code, ss:code

start:    jmp  getscan                ;Branchement au d‚but du programme

;== Donn‚es=============================================================

int9_ptr  equ this dword               ;Ancien vecteur d'interruption 9h
int9_ofs  dw 0                          ;Offset de l'ancien gestionnaire
int9_seg  dw 0                         ;Segment de l'ancien gestionnaire

allscan   db 0                      ;Faut-il affficher les codes Break ?

scanbuf   db 32 dup (0)                          ;Buffer pour scan codes
scanend   equ this byte

scannext  dw offset scanbuf       ;Suivant dans le buffer des scan codes
scanlast  dw offset scanbuf       ;Dernier dans le buffer des scan codes

copyr     db   "GETSCAN - (c) 1990, 92 by MICHAEL TISCHER",13,10,13,10
          db   "Appuyez sur une touche quelconque pour afficher "
          db   "son scan code   ",13,10
          db   "ou sur <Entr‚e> pour sortir du programme."
          db   13,10,13,10, "$"

hexdigits db   "0123456789ABCDEF"   ;Chiffres pour convertir un nb hexa.

scanmes   db   "Scancode: "                                     ;Message
scandeci   db   "000 ("
scanhex   db   "xx)", 13, 10, "$"

;== Programmcode =======================================================

getscan:  mov  ah,09h                              ;Message de copyright
          mov  dx,offset copyr
          int  21h

          ;-- Recherche le paramŠtre /R pour afficher tous les codes----

          cmp  word ptr ds:[130], "R" * 256 + "/"
          je   gsall
          cmp  word ptr ds:[130], "r" * 256 + "/"
          jne  gsnall

gsall:    mov  allscan,1                ;Affiche aussi les codes Release

gsnall:   ;-- Installe le nouveau gestionnaire d'interruption   --------

          mov  ax,3509h           ;Contenu du vecteur d'interruption 09h
          int  21h                                  ;Interruption de DOS
          mov  int9_seg,es              ;M‚morise le segment et l'offset
          mov  int9_ofs,bx                 ;du vecteur d'interruption 9h

          mov  dx,offset nouvi9    ;Offset de la nouvelle routine d'int.
          mov  ax,2509h                          ;D‚tourne le vecteur de
          int  21h                                   ;l'interruption 09h

gs1:      ;-- Boucle de lecture ----------------------------------------

          mov  ah,01h              ;Y a-t-il un  caractŠre qui soit prˆt
          int  16h                                                     ;
          je   gs2                                          ;Non --> GS2

          xor  ah,ah                              ;Oui, lit le caractŠre
          int  16h
          cmp  al,13                                  ;Est-ce <Entr‚e> ?
          je   gs4                         ;Oui--> Terminer le programme

gs2:      mov  di,scannext             ;Pointe sur le prochain scan code
          cmp  di,scanlast                                  ;Buffer vide
          je   gs1                                      ;Oui, recommence
         ;== Transforme le scan code en ASCII et l'affiche =============

          mov  word ptr scandeci,   32 shl 8 + 32
          mov  byte ptr scandeci+2, 32

          mov  si,offset scandeci+2
                        ;SI pointe sur le dernier chiffre dans le buffer
          mov  al,[di]                        ;Charge le scan code en AL
          mov  bl,10                        ;Le diviseur est toujours 10

gs3:      xor  ah,ah               ;Annule octet poids fort du dividende
          div  bl                                      ;Divise AX par 10
          or   ah,'0'                      ;Convertit AH au format ASCII
          mov  [si],ah                               ;Stocke dans buffer
          dec  si                                     ;CaractŠre suivant
          or   al,al                                ;y a-t-il un reste ?
          jne  gs3                             ;Oui --> prochain chiffre

          ;-- Affiche aussi le code en hexad‚cimal ---------------------

          mov  bx,offset hexdigits   ;BX pointe sur table chiffres hexa.
          mov  al,[di]                ;Isole la partie inf. du scan code
          and  al,15
          xlat                     ;Recherche le chiffre hexa dans table
          mov  ah,al                ;TransfŠre le chiffre inf‚rieur dans
                                                      ;l'octet sup‚rieur
          mov  al,[di]               ;Isole la partie haute du scan code
          mov  cl,4
          shr  al,cl
          xlat                     ;Recherche le chiffre hexa dans table

          mov  word ptr scanhex,ax ;Met les deux chiffres dans le buffer

                    ;-- Avance le pointeur dans le buffer des scan codes

          inc  di
          cmp  di,offset scanend                            ;Trop loin ?
          jne  gsnowrap                       ;Non ---> note la position

          mov  di,offset scanbuf               ;Oui, recommence au d‚but

gsnowrap: mov  scannext,di          ;M‚morise pos. du prochain caractŠre

          ;-- Affichage ------------------------------------------------

          mov  ah,09h                                 ;Affiche la chaŒne
          mov  dx,offset scanmes
          int  21h

          jmp  gs1                                           ;Recommence

gs4:      ;-- Pr‚pare la fin du programme ------------------------------

          lds  dx,int9_ptr             ;R‚tablit l'ancien gestionnaire -
          mov  ax,2509h                   ; de l'interruption du clavier
          int  21h

          mov  ax,4C00h                        ;tout va bien, on termine
          int  21h

;== Gestionnaire de l'interruption 09h (Clavier) =======================

nouvi9     proc far

          assume cs:code, ds:nothing, es:nothing, ss:nothing

          push ax                                             ;Empile AX
          in   al,KB_PORT             ;Lit le scan code sur port clavier

          cmp  al,128                          ;Est-ce un code Release ?
          jb   i9note                            ;Non ---> en prend note

          cmp  allscan,0                         ;Oui, en tenir compte ?
          je   i9end                                    ;Non ---> retour

i9note:  ;-- m‚morise le scan code dans le buffer des scan codes--------

          push di                       ;DI va ˆtre modifi‚, on le sauve
          mov  di,scanlast      ;DI pointe sur prochaine position buffer
          mov  cs:[di],al                       ;Y m‚morise le scan code
          inc  di                    ;DI pointe sur la position suivante
          cmp  di,offset scanend                             ;Trop loin?
          jne  i9nowrap                       ;Non ---> note la position

          mov  di,offset scanbuf                   ;Oui reprend au d‚but

i9nowrap: mov  scanlast,di      ;M‚morise position du prochain caractŠre
          pop  di                                           ;restaure DI
i9end:    pop  ax         ;Transmet le scan code … l'ancien gestionnaire
          jmp  [int9_ptr]                                    ;du clavier

nouvi9     endp


;== Fin ================================================================

code      ends                                   ;Fin du segment de code
          end  start

