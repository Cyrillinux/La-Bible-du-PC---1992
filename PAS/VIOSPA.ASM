;**********************************************************************;
;*                            V I O S P A                             *;
;*--------------------------------------------------------------------*;
;*    Fonction       : Fournit une fonction … int‚grer dans un        *;
;*                     programme en Turbo Pascal                      *;
;*                     et qui permet de d‚terminer le type des cartes *;
;*                     vid‚o install‚es.                              *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D‚velopp‚ le   :  2/10/1988                                     *;
;*    DerniŠre MAJ.:  14/01/1991                                      *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : MASM VIOSPA;                                   *;
;*                     ... Int‚grer ensuite par {$L VIOSPA}           *;
;*                     dans un programme en Turbo Pascal              *;
;**********************************************************************;
 
;== Constantes pour la structure VIOS ==================================
 
                                  ;Constantes pour la carte vid‚o
NO_VIOS    = 0                    ;Pas de carte vid‚o
VGA        = 1                    ;Carte VGA
EGA        = 2                    ;Carte EGA
MDA        = 3                    ;Monochrome Display Adapter
HGC        = 4                    ;Hercules Graphics Card
CGA        = 5                    ;Color Graphics Adapter
 
                                  ;Constantes pour le moniteur
NO_MON     = 0                    ;Pas de moniteur
MONO       = 1                    ;Moniteur monochrome
COLOR      = 2                    ;Moniteur couleur
EGA_HIRES  = 3                    ;Moniteur haute r‚solution ou Multisyn
ANAL_MONO  = 4                    ;Moniteur analogique monochrome
ANAL_COLOR = 5                    ;Moniteur couleur analogique
 
;== Segment de donn‚es =================================================
 
DATA   segment word public        ;Segment de donn‚es Turbo

DATA   ends 
 
;== Segment de code ====================================================
 
CODE       segment byte public    ;Segment de code Turbo
 
           assume cs:CODE, ds:DATA 
 
public     getvios 
 
;-- Les variables globales initialis‚es doivent ˆtre plac‚es dans le ---
;-- segment de code.                                                 ---
 
vios_tab   equ this word 
 
      ;-- Table de conversion traitant le r‚sultat retourn‚ par
      ;-- l'option 00h de la fonction 1Ah du BIOS VGA

           db NO_VIOS, NO_MON     ;Pas de carte vid‚o
           db MDA    , MONO       ;Carte MDA sur moniteur monochrome
           db CGA    , COLOR      ;Carte CGA sur moniteur couleur
           db ?      , ?          ;Code 3 non utilis‚
           db EGA    , EGA_HIRES  ;Carte EGA sur moniteur haute r‚s.
           db EGA    , MONO       ;Carte EGA sur moniteur monochrome
           db ?      , ?          ;Code 6 non utilis‚
           db VGA    , ANAL_MONO  ;Carte VGA sur moniteur mono. analog.
           db VGA    , ANAL_COLOR ;Carte VGA sur moniteur coul. analog.

ega_dips   equ this byte

        ;-- Table de conversion pour traiter les micro-commutateurs
        ;-- DIP de la carte EGA

           db COLOR, EGA_HIRES, MONO
           db COLOR, EGA_HIRES, MONO

;-----------------------------------------------------------------------
;-- GETVIOS             : D‚termine le type des cartes vid‚o install‚es
;-- Appel depuis Pascal : GetVios(@Vidsys)
;-- D‚claration         : Proc‚dure GetVios (vp::ViosPtr): external;
;-- Valeur retourn‚e    : Aucune

 getvios  proc near 
 
sframe     struc                  ;Structure pour acc‚der … la pile
cga_possi  db ?                   ;Variable locale
ega_possi  db ?                   ;       "
mono_possi db ?                   ;       "
bptr       dw ?                   ;Re‡oit BP
ret_adr    dw ?                   ;Adresse de retour … l'appelant
vp         dd ?                   ;Pointeur sur la premiŠre structure VIOS
sframe     ends                   ;Fin de la structure
 
frame      equ [ bp - cga_possi ] ;Adresse les ‚l‚ments de la structure
 
           push bp                ;Sauvegarde BP sur la pile
           sub  sp,3              ;Place pour les variables locales
           mov  bp,sp             ;TransfŠre SP en BP
 
           mov  frame.cga_possi,1 ;Peut ˆtre CGA
           mov  frame.ega_possi,1 ;Peut ˆtre EGA
           mov  frame.mono_possi,1;Peut ˆtre MDA ou HGC
 
           mov  di,word ptr frame.vp     ;Recherche offset de structure
           mov  word ptr [di],NO_VIOS    ;Aucun systŠme vid‚o
           mov  word ptr [di+2],NO_VIOS  ;trouv‚ pour le moment

           call test_vga          ;Teste si carte VGA
           cmp  frame.ega_possi,0 ;Carte EGA encore possible ?
           je  gv1                ;NON --> passe au test CGA
 
           call test_ega          ;Teste si carte EGA
gv1:       cmp  frame.cga_possi,0 ;Carte CGA encore possible ?
           je   gv2               ;NON --> passe au test MDA et HGC
 
           call test_cga          ;Teste si carte CGA
gv2:       cmp  frame.mono_possi,0;Carte MDA ou HGC encore possible ?
           je   gv3               ;NON --> Tests termin‚s
 
           call test_mono         ;Teste si carte MDA et HGC
 
           ;-- D‚termine la carte vid‚o active -------------------------

gv3:       cmp  byte ptr [di],VGA ;Carte VGA identifi‚e ?
           je   gvi_end           ;OUI, carte active d‚j… identifi‚e
           cmp  byte ptr [di+2],VGA ;Carte VGA comme systŠme secondaire?
           je   gvi_end           ;OUI, carte active d‚j… identifi‚e
 
           mov  ah,0Fh            ;D‚termine le mode vid‚o courant par 
           int  10h               ;l'interruption vid‚o
 
           and  al,7              ;Seuls modes 0 … 7 sont int‚ressants
           cmp  al,7              ;Carte monochrome active ?
           jne  gv4               ;Non, en mode CGA ou EGA
 
           ;-- La carte MDA, HGC ou EGA (mono) est active -------------
 
           cmp  byte ptr [di+1],MONO ;Mono dans la premiŠre structure ?
           je   gvi_end           ;OUI, ordre correct
           jmp  short echange     ;NON, intervertir l'ordre

           ;-- Une carte CGA ou EGA est active ------------------------
 
gv4:       cmp  byte ptr [di+1],MONO ;Mono dans la premiŠre structure ?
           jne  gvi_end           ;NON, ordre correct
 
echange:   mov  ax,[di]        ;Recherche le contenu premiŠre structure
           xchg ax,[di+2]         ;Echange avec seconde structure
           mov  [di],ax 
 
gvi_end:   add  sp,3       ;Elimine les variables locales de la pile
           pop  bp         ;Retire BP de la pile
           ret  4          ;Retourne … TURBO en supprimant les variables
                           ;sur la pile
getvios    endp

;-----------------------------------------------------------------------
;-- TEST_VGA: d‚termine si une carte VGA est install‚e
 
test_vga   proc near 
 
           mov  ax,1a00h        ;Appelle l'option 00h de la fonction 1Ah
           int  10h             ;du BIOS
           cmp  al,1ah          ;Fonction support‚e?
           jne  tvga_end        ;NON --> Termine la routine

           ;-- La fonction est support‚e, BL contient maintenant le code
           ;-- du systŠme vid‚o actif, BH celui du systŠme non actif
 
           mov  cx,bx             ;Range le r‚sultat dans CX
           xor  bh,bh             ;Annule BH 
           or   ch,ch             ;Un seul systŠme vid‚o ?
           je   tvga_1      ;OUI --> S‚lectionne code du premier systŠme

           ;-- Convertit le code du second systŠme ---------------------

           mov  bl,ch             ;Code du second systŠme en BL
           add  bl,bl             ;Calculer l'offset dans la table
           mov  ax,vios_tab[bx]   ;Rechercher le code dans la table
           mov  [di+2],ax     ;et stocke dans structure du prog appelant
           mov  bl,cl         ;Remet dans BL codes du premier systŠme

           ;-- Convertit le code du premier systŠme --------------------
 
tvga_1:    add  bl,bl             ;Calculer l'offset dans la table
           mov  ax,vios_tab[bx]   ;Recherche le code dans la table
           mov  [di],ax          ;stocke dans la struct du prog appelant

           mov  frame.cga_possi,0 ;Le test CGA n'a plus lieu d'ˆtre
           mov  frame.ega_possi,0 ;Le test EGA non plus
           mov  frame.mono_possi,0 ;Reste … examiner MONO
           mov  bx,di             ;Adresse de la structure active
           cmp  byte ptr [bx],MDA ;SystŠme monochrome identifi‚ ?
           je   do_tmono          ;OUI --> Effectue le test MDA/HGC
 
           add  bx,2              ;Adresse de la structure inactive
           cmp  byte ptr [bx],MDA ;SystŠme monochrome identifi‚ ?
           jne  tvga_end          ;NON termine la routine
 
do_tmono:  mov  word ptr [bx],0   ;Simule la non-identification du sys.

           mov  frame.mono_possi,1;Ex‚cute le test monochrome
 
tvga_end:  ret                    ;Retour au programme appelant
 
test_vga   endp 
 
;-----------------------------------------------------------------------
;-- TEST_EGA: D‚termine si une carte EGA est install‚e
 
test_ega   proc near 
 
           mov  ah,12h            ;Fonction 12h
           mov  bl,10h            ;Option 10h
           int  10h               ;Appelle le BIOS EGA
           cmp  bl,10h            ;Fonction support‚e ?
           je   tega_end          ;NON --> Termine la routine
 
           ;-- La fonction est support‚e , CL contient maintenant   ----
           ;-- la position des micro-commutateurs DIP de la carte EGA --

           mov  bl,cl             ;Commutateurs DIP en BL
           shr  bl,1              ;D‚cale d'une position vers la droite
           xor  bh,bh             ;Octet fort pour index … 0
           mov  ah,ega_dips[bx]   ;Recherche l'‚l‚ment de la table
           mov  al,EGA            ;C'est une carte EGA
           call trouve            ;Inscrit les donn‚es dans le vecteur
 
           cmp  ah,MONO           ;Connexion sur ‚cran monochrome ?
           je   is_mono           ;OUI --> ni MDA ou HGC
 
           mov  frame.cga_possi,0 ;Carte CGA impossible
           jmp  short tega_end    ;Termine la  routine
 
is_mono:   mov  frame.mono_possi,0;Comme la carte EGA est sur moniteur
                                  ;monochrome, ni MDA ni HGC ne peuvent
                                  ;ˆtre install‚es
 
tega_end:  ret                    ;Retour au programme appelant
 
test_ega   endp 
 
;-----------------------------------------------------------------------
;-- TEST_CGA: D‚termine si une carte CGA est install‚e
 
test_cga   proc near 
 
           mov  dx,3D4h           ;Adr port reg d'adresse CRTC pour CGA
           call test_6845         ;Teste si 6845 CRTC install‚
           jc   tega_end          ;NON --> Termine le test
 
           mov  al,CGA            ;OUI, une carte CGA est install‚e
           mov  ah,COLOR          ;Toujours un moniteur couleur avec CGA
           jmp  trouve            ;Inscrit les donn‚es dans le vecteur
 
test_cga   endp 
 
;-----------------------------------------------------------------------
;-- TEST_MONO: Teste la pr‚sence d'une carte MDA ou HGC
 
test_mono  proc near 
 
           mov  dx,3B4h           ;Adr. port du reg. adr. CRTC pour MONO
           call test_6845         ;Teste si 6845 CRTC install‚
           jc   tega_end          ;NON --> Termine le test
 
           ;-- Une carte d'‚cran monochrome est install‚e --------------
           ;-- Le test suivant fait la distinction entre MDA et HGC ----

           mov  dl,0BAh           ;Port d'‚tat MONO en 3BAh
           in   al,dx             ;Teste le port d'‚tat
           and  al,80h            ;Ne garde que le bit 7
           mov  ah,al             ;et le ranger en AH
 
           ;-- Si le contenu du bit 7 du port d'‚tat est modifi‚ au ----
           ;-- cours de l'un des tests suivants, c'est qu'il s'agit ----
           ;-- d'une carte HGC                                      ----

           mov  cx,8000h          ;32768 it‚rations au maximum
test_hgc:  in   al,dx             ;Teste le port d'‚tat
           and  al,80h            ;Ne garde que le bit 7
           cmp  al,ah             ;Son contenu a-t-il ‚t‚ modifi‚ ?
           jne  is_hgc            ;Bit 7 = 1 --> c'est une carte HGC
           loop test_hgc          ;Poursuit la boucle
 
           mov  al,MDA            ;Le bit 7 n'est pas … 1 --> carte MDA
           jmp  set_mono          ;Fixe les paramŠtres
 
is_hgc:    mov  al,HGC            ;Le bit 7 est … 1 -->  une carte HGC
set_mono:  mov  ah,MONO           ;MDA et HGC seulement sur ‚cran MONO
           jmp  trouve            ;Fixe les paramŠtres
 
test_mono  endp 
 
;-----------------------------------------------------------------------
;-- TEST_6845: retourne un indicateur de retenue … 1 si aucun 6845 ne --
;--            figure … l'adresse de port en DX                       --

test_6845  proc near

           mov  al,0Ah            ;Appelle le registre 10
           out  dx,al        ;Num‚ro de reg. dans le reg. d'adresse CRTC
           inc  dx           ;DX maintenant sur registre de donn‚es CRTC
 
           in   al,dx             ;Recherche le contenu du registre 10
           mov  ah,al             ;et le range en AH
 
           mov  al,4Fh            ;Ecrit dans le registre 10
           out  dx,al             ;une valeur quelconque
 
           mov  cx,100            ;Petite boucle d'attente pour que le
wait:      loop wait              ;6845 puisse r‚agir
 
           in   al,dx             ;Relit le contenu du registre 10
           xchg al,ah             ;Intervertit AH et AL
           out  dx,al             ;Restaure l'ancienne valeur
 
           cmp  ah,4Fh            ;La valeur ‚crite a-t-elle ‚t‚ lue ?
           je   t6845_end         ;OUI --> Termine le test
 
           stc                    ;NON --> Met … 1 indicateur de retenue

t6845_end: ret                    ;Retour au programme appelant
 
test_6845  endp 
 
;-----------------------------------------------------------------------
;-- TROUVE : enregistre dans le vecteur vid‚o le type de carte vid‚o ---
;--          (en AL) et le type dumoniteur (en AH)                   ---

trouve     proc near

           mov bx,di              ;Adresse de la structure active
           cmp word ptr [bx],0    ;A-t-on d‚j… identifi‚ un sys. vid‚o ?
           je  set_data           ;NON --> Donn‚es dans la struct active

           add bx,2             ;OUI, adresse de la structure d‚sactiv‚e

set_data:  mov [bx],ax            ;Place les donn‚es dans la structure
           ret                    ;Retour au programme appelant
 
trouve   endp 
 
;-----------------------------------------------------------------------
 
code       ends                   ;Fin du segment de code
           end                    ;Fin du programme
