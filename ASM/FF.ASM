;**********************************************************************;
;*                     F F . A S M    ( FileFind )                    *;
;*--------------------------------------------------------------------*;
;*    Fonction        : Recherche des fichiers sur                    *;
;*                      un lecteur donn‚                              *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    : 12.09.1990                                    *;
;*    DerniŠre modif. : 14.03.1992                                    *;
;*--------------------------------------------------------------------*;
;*    Pour assembler   : MASM FF;                                     *;
;*                     LINK FF;                                       *;
;*                     EXE2BIN FF FF.COM                  ou          *;
;*                                                                    *;
;*                     TASM FF                                        *;
;*                     TLINK FF /t                                    *;
;*--------------------------------------------------------------------*;
;*    Appel         : FF [Unit:]nom de fichier [+ ou - ou =Date]      *;
;**********************************************************************;

;== Constantes =========================================================

CMD_OFS      equ     81h    ;D‚but de la ligne d'instruction dans le PSP
CR           equ     13                                 ;Carriage Return
LF           equ     10                                        ;Linefeed
DELIMITER    equ     "."           ;S‚parateur pour les ‚l‚ments de date

             ;--Fonctions DOS ------------------------------------------

GET_LW_NR    equ     19h                   ;D‚terminer le lecteur actuel
WRT_CHAR     equ     02h                    ;Sortir caractŠre sur STDOUT
SEARCH_FIRST equ     4Eh                      ;Rechercher le 1er fichier
SEARCH_NEXT  equ     4Fh                  ;Rechercher le fichier suivant
SET_DTA      equ     1Ah                        ;Fixer nouvelle zone DTA
PRINT_STR    equ     09h                   ;Sortir chaŒne termin‚e par $

ATTR_DIR     equ     10h                  ;Rechercher un sous-r‚pertoire
ATTR_NRM     equ     00h                ;Rechercher des fichiers normaux

DATCOMP_NO   equ     0                       ;Pas de comparaison de date
DATCOMP_KL   equ     1                ;Comparaison de date avant le ....
DATCOMP_GL   equ     2                      ;Comparaison de date le ....
DATCOMP_GR   equ     3                 ;Comparaison de date aprŠs le ...

;== Structures =========================================================

PSP   struc                               ;Constitue la structure du PSP
        intcall  dw (?)                        ;Appel d'interruption 20h
        endadr   dw (?)                                  ;Adresse de fin
                 db (?)                                         ;R‚serv‚
        farcall  db  5 dup (?)          ;FAR-CALL sur l'interruption 21h
        int22h   dd (?)                           ;Copie de l'inter. 22h
        int23h   dd (?)                           ;Copie de l'inter. 23h
        int24h   dd (?)                           ;Copie de l'inter. 24h
                 db 22 dup (?)                                  ;R‚serv‚
        envseg   dw (?)           ;Adresse de segment de l'environnement
                 db 46 dup (?)                                  ;R‚serv‚

        ;-- Voici le premier FCB ---------------------------------------

        drvcode1 db (?)                          ;Num‚ro de p‚riph‚rique
        nomfich1 db  8 dup (?)                           ;Nom de fichier
        extfich1 db  3 dup (?)                     ;Extension de fichier
        numbloc1 dw (?)                           ;Num‚ro de bloc actuel
        lenfich1 dd (?)                             ;Longueur de fichier
        datmod1  dw (?)                ;Date de la derniŠre modification
        timemod1 dw (?)               ;Heure de la derniŠre modification
                 dw  4 dup (?)                                  ;R‚serv‚
        actset1  db (?)                    ;Num‚ro de descripteur actuel
        setfree1 dd (?)          ;Num‚ro de descripteur pour accŠs libre

        ;-- Voici le second FCB ----------------------------------------

        drvcode2 db (?)                          ;Num‚ro de p‚riph‚rique
        nomfich2 db  8 dup (?)                           ;Nom de fichier
        extfich2 db  3 dup (?)                     ;Extension de fichier
        numbloc2 dw (?)                           ;Num‚ro de bloc actuel
        lenfich2 dd (?)                             ;Longueur de fichier
        datmod2  dw (?)                ;Date de la derniŠre modification
        timemod2 dw (?)               ;Heure de la derniŠre modification
                 dw  4 dup (?)                                  ;R‚serv‚
        actset2  db (?)                    ;Num‚ro de descripteur actuel
        setfree2 dd (?)          ;Num‚ro de descripteur pour accŠs libre

        db 128 dup (?)                              ;Ligne d'instruction
PSP   ends

;-----------------------------------------------------------------------

DTA   struc           ;Structure de DTA lors de la recherche de fichiers
                 db 21 dup (?)                                  ;R‚serv‚
        attr     db (?)                      ;Attribut du fichier trouv‚
        timemod  dw (?)               ;Heure de la derniŠre modification
        datemod  dw (?)                ;Date de la derniŠre modification
        lenfich  dd (?)                             ;Longueur de fichier
        datn     db 13 dup (?)                           ;Nom de fichier
DTA   ends

;-----------------------------------------------------------------------

DATE  struc                             ;Re‡oit des informations de date
        jour    db (?)                              ;Jour du mois (1-31)
        mois    db (?)                                      ;Mois (1-12)
        an      dw (?)                        ;ann‚e y compris le siŠcle
DATE  ends

;== Ici commence le programme proprement dit ===========================

code      segment para 'CODE'             ;D‚finition du segment de code

          org 100h                                   ;Start derriŠre PSP

          assume cs:code, ds:code, es:code, ss:code

start:     jmp startff                ;Sauter vers le d‚but du programme

;== Donn‚es ============================================================

datcomp         db  DATCOMP_NO     ;Par d‚faut, pas de recherche de date
sdate     DATE < 0, 0, 0>                ;Date de la ligne d'instruction
tdate     DATE < 0, 0, 0>                    ;Date du fichier … examiner

nomrep          db  64, ":\"                          ;Nom du r‚pertoire
firstdir        db  79 dup (0)                                 ;en cours
nomrech         db  "*.*", 0              ;Nom des fichiers … rechercher
                db   9 dup (0)

jokname         db  "*.*", 0       ;Nom pour la recherche de r‚pertoires
found           dw  0                        ;Nombre de fichiers trouv‚s

mes             db  CR, LF, "FF: Pas de fichier(s) trouv‚(s)."
crlf            db  CR, LF, "$"

datbuffer       db "ddddd.dd.dddd  ",0      ;Buffer pour conversion date
datpend   equ this byte                                        ;en ASCII

errmes          db "FF  -  (c) 1990, 92 by MICHAEL TISCHER", 13,10,10
                db "Appel: FF [L:]nom_fichier [+ ou - ou =Date]",13,10
                db "$"

;== D‚but de programme effectif ========================================

startff:   ;-- Evaluer les arguments de la ligne d'instruction ---------

           cld                    ;En amont avec les instructions chaŒne
           mov   di,offset nomrech
           mov   si,CMD_OFS   ;SI sur le d‚but de la ligne d'instruction

arg1:      ;-- Evaluer ensuite la d‚signation de p‚riph‚rique ----------

           lodsb       ;Charger les caractŠres de la ligne d'instruction
           cmp   al,CR        ;Fin de la ligne d'instruction d‚couverte?
           je    arg6                    ;Oui ---> Terminer l'‚valuation
           cmp   al," "            ;Non, contient peut-ˆtre des espaces?
           jbe   arg1             ;Non, il doit s'agir de Tab, continuer

           ;-- Une lettre a ‚t‚ trouv‚e --------------------------------

           cmp   ds:[0].drvcode1,0         ;D‚signation de p‚riph‚rique?
           je    arg2    ;Non, sinon elle se trouverait d‚j… dans le FCB
           lodsb                                ;Charger le double-point
           lodsb                           ;Charger le caractŠre suivant
           cmp   al," "                            ;Espace ou inf‚rieur?
           jbe   arg3                     ;Oui, ---> Evaluation termin‚e

arg2:      ;-- Entrer les noms de fichier dans le buffer NOMRECH -------

           stosb                     ;Placer les caractŠres dans NOMRECH
           lodsb                           ;Charger le caractŠre suivant
           cmp   al," "                            ;Espace ou inf‚rieur?
           ja    arg2                            ;Non, lettre, continuer

arg3:      ;-- Evaluation du nom de fichier termin‚e -------------------

           cmp   al,CR                           ;Fin de ligne atteinte?
           je    arg6

           ;-- Tester et ‚valuer ‚ventuellement l'indication de date ---

arg4:      lodsb                           ;Charger le caractŠre suivant
           cmp   al," "                          ;Space et Tab autoris‚s
           je    arg4
           cmp   al,9
           je    arg4
           cmp   al,CR                           ;Fin de ligne atteinte?
           je    arg6

           cmp   al,"="                                      ;Mˆme date?
           jne   arg4a                           ;Non, continuer le test
           mov   al,DATCOMP_GL         ;Flag pour la comparaison de date
           jmp   short arg5

arg4a:     cmp   al,"-"                               ;Date avant le ...
           jne   arg4b                           ;Non, continuer le test
           mov   al,DATCOMP_KL         ;Flag pour la comparaison de date
           jmp   short arg5

arg4b:     cmp   al,"+"                               ;Date aprŠs le ...
           jne   argerr         ;Non, erreur dans la ligne d'instruction
           mov   al,DATCOMP_GR         ;Flag pour la comparaison de date

arg5:      mov   datcomp,al                  ;Apercevoir le flag de date
           mov   di,offset sdate         ;Pointeur sur structure de date
           call  getdat        ;Lire la date dans la ligne d'instruction
           jc    argerr               ;Erreur ---> Terminer le programme

arg6:      ;-- Evaluation ligne d'instruction termin‚e, tout va bien ---

           mov   al,ds:[0].drvcode1         ;Charger d‚signation p‚riph.
           or    al,al                                     ;Une trouv‚e?
           jne   arg7                 ;Oui, ---> actuelle non d‚termin‚e

           ;-- Pas de d‚signation de p‚riph. sp‚cifi‚e, s‚lect. actuelle

           mov   ah,GET_LW_NR       ;D‚terminer num‚ro de lecteur actuel
           int   21h                                              ;(0=A)
           inc   al                ;Augmenter nø lecteur parce que 1 = A

arg7:      add   nomrep,al                           ;D‚s. p‚r. en ASCII
           mov   dx,offset startdta              ;Adresse de premier DTA
           mov   bx,offset firstdir               ;Ici nom du r‚pertoire
           call  go                                 ;Lancer la recherche

           mov   ax,found         ;Charger le nombre de fichiers trouv‚s
           or    ax,ax                            ;Aucun fichier trouv‚?
           je    arg8                   ;Oui, sortir la chaŒne inchang‚e
           mov   si,offset mes+6                    ;Pointeur sur buffer
           call  toint

arg8:      mov   ah,09h                             ;Afficher le message
           mov   dx,offset mes
           int   21h

           mov   ax,4C00h                     ;Terminer le programme par
           int   21h                                    ;la fonction 4Ch

argerr:    ;-- Erreur lors de l'‚valuation de la ligne d'instruction ---

           mov   ah,09h                        ;Sortir la chaŒne erron‚e
           mov   dx,offset errmes
           int   21h

           mov   ax,4C01h   ;Terminer le programme avec le code d'erreur
           int   21h

;-- GO: GŠre la recherche des fichiers sp‚cifi‚s -----------------------
;-- Entr‚e  : BX = Ptr sur chaŒne recherch‚e pour ins‚rer nom r‚pertoire
;--                ou de fichier
;--           DX = Offset de DTA ant‚rieur
;-- Sortie  : Aucune
;-- Registres : AX, SI, CX et FLAGS modifi‚s

go               proc near

           push  dx            ;Sauvegarder le pointeur sur DTA en cours

           mov   si,offset nomrech   ;Copier le nom du fichier recherch‚
           call  strcopy                                 ;dans le buffer

           mov   cx,ATTR_NRM      ;Rechercher uniq. les fichiers normaux
           call  startsearch                     ;Commencer la recherche
           jc    go2           ;Aucun fichier trouv‚ -> Rech. r‚pertoire

           call  printname                               ;Fichier trouv‚

go1:       ;-- Continuer la recherche des fichiers restants ------------

           call  nextfile                 ;Rechercher le fichier suivant
           jc    go2                             ;Plus de fichier trouv‚
           call  printname                               ;Fichier trouv‚
           jmp   short go1

go2:       ;-- Consulter encore une fois le r‚pertoire en cours, -------
           ;-- mais en recherchant ‚galement les sous-r‚pertoires ------

           pop   dx                        ;Replacer le pointeur sur DTA
           push  dx                        ;et sauvegarder imm‚diatement
           mov   si,offset jokname         ;*.* Ajouter aux noms de r‚p.
           call  strcopy

           mov   cx,ATTR_DIR                ;Rechercher sous-r‚pertoires
           call  startsearch      ;Rechercher le premier sous-r‚pertoire
           jc    go_end           ;Aucun trouv‚ ---> Terminer la routine

           mov   si,dx                  ;Trouv‚ mais c'est un r‚pertoire
           test  [si].attr,ATTR_DIR
           jne   go4                                   ;Oui ---> Evaluer

go3:       ;-- Pas de r‚pertoire, continuer la recherche ---------------

           call  nextfile                 ;Rechercher le fichier suivant
           jc    go_end           ;Aucun trouv‚ ---> Terminer la routine
           mov   si,dx                  ;Trouv‚ mais c'est un r‚pertoire
           test  [si].attr,ATTR_DIR
           je    go3                                      ; Jump if zero

go4:       ;-- Sous-r‚pertoire trouv‚ ----------------------------------

           cmp   [si].datn,"."                              ;"." ou ".."
           je    go3                                ;Oui, ne pas traiter

           push  di                         ;Sauver DX et BX sur la pile
           push  bx
           mov   si,dx         ;Placer SI sur le nom de fichier dans DTA
           add   si,offset datn       ;y placer sur le nom de r‚pertoire
           mov   di,bx               ;DI sur nom de r‚pertoire ant‚rieur

go5:       ;-- Inclure le nom de r‚pertoire au nom ant‚rieur -----------

           lodsb       ;Charger le caractŠre depuis le nom de r‚pertoire
           stosb                            ;et inclure au nom ant‚rieur
           or    al,al                            ;Dernier octet trait‚?
           jne   go5                                 ;Non ---> Continuer

           mov   bx,di            ;Ranger nouvelle fin de buffer dans BX
           stosb                             ;Ecrire encore un octet NUL
           mov   byte ptr [bx-1],"\"   ;Le faire pr‚c‚der d'un Backslash
           call  go                                      ;Appel r‚cursif

           pop   bx                      ;Relire BX et DI depuis la pile
           pop   di
           mov   byte ptr [bx],0            ;Dissocier dern. nom de r‚p.
                                                   ;de l'appel pr‚c‚dent

           mov   ah,SET_DTA         ;Replacer DTA sur l'ancienne adresse
           int   21h                                              ;en DX

           jmp   short go3

go_end:    pop   dx               ;Replacer le pointeur sur l'ancien DTA
           ret                                      ;Retour … l'appelant

go               endp

;-- STARTSEARCH: Lancer la recherche d'un fichier ----------------------
;-- Entr‚e  : CX = Attribut du fichier recherch‚
;--           DX = Offset de DTA ant‚rieur
;-- Sortie  : DX = Nouvelle adresse de DTA
;--           Carry-Flag: 0 = o.k., 1 = Pas de fichier trouv‚
;-- Registres : AX, DX, BP et FLAGS sont modifi‚s
;-- Infos     : Nom du fichier … rech. … extrait du buffer nomrep
;--

startsearch      proc near

           push  cx                               ;Sauver CX sur la pile

           ;-- Placer d'abord nouveau DTA derriŠre le DTA en cours -----

           add   dx,2ch           ;La longueur d'un DTA est de 42 octets
           mov   ah,SET_DTA                           ;Fixer nouveau DTA
           int   21h

           ;-- Rech. 1er fichier dot‚ d'un nom dans le buffer nomrep ---

           mov   bp,dx                                   ;Sauvegarder DX
           mov   ah,SEARCH_FIRST             ;Rechercher premier fichier
           mov   dx,offset nomrep        ;DS:DX = Ptr sur nom de fichier
           int   21h

           mov   dx,bp                                       ;Retirer DX
           pop   cx                               ;Retirer CX de la pile
           ret                                      ;Retour … l'appelant

startsearch      endp

;-- NEXTFILE: Recherche le fichier suivant -----------------------------
;-- Entr‚e  : Aucune
;-- Sortie  : Carry-Flag: 0 = o.k., 1 = Pas de fichier trouv‚
;-- Registres : AY et FLAGS sont modifi‚s

nextfile         proc near

           mov   bp,dx
           mov   ah,SEARCH_NEXT           ;Rechercher le fichier suivant
           mov   dx,offset nomrep          ;Chemin dans le buffer nomrep
           int   21h
           mov   dx,bp
           ret                                      ;Retour … l'appelant

nextfile         endp

;-- STRCOPY : Copie une chaŒne ASCII termin‚e par ----------------------
;--           un octet NUL
;-- Entr‚e  : SI = Offset de la chaŒne source
;--           BX = Offset de la chaŒne cible
;--           DS = Segment de la chaŒne source
;--           ES = Segment de la chaŒne cible
;-- Sortie  : Aucune
;-- Registres : AL, DI, SI et FLAGS sont modifi‚s

strcopy          proc near

           mov     di,bx                  ;Placer DI sur la chaŒne cible

sc1:       ;-- Boucle de recopie ---------------------------------------

           lodsb              ;Charger caractŠre depuis la chaŒne source
           stosb                            ;Placer dans la chaŒne cible
           or    al,al                               ;Dernier caractŠre?
           jne   sc1                       ;Non ---> Recommencer le tout

           ret                                      ;Retour … l'appelant

strcopy          endp

;-- PRINTNAME: Sortir le nom d'un fichier trouv‚ -----------------------
;-- Entr‚e  :  DX = Pointeur sur DTA actuel muni d'un nom
;--            BX = Offset de la chaŒne cible
;--            DS = Segment de la chaŒne source
;--            ES = Segment de la chaŒne cible
;-- Sortie  :  Aucune
;-- Registres : AL, DI, SI et FLAGS sont modifi‚s
;-- Infos     : Le nom du fichier n'est imprim‚ que s'il ne s'agit pas
;--            d'un sous-r‚pertoire et si un test de date d‚termin‚
;--            a permis d'‚tablir la relation souhait‚e.

printname        proc near

           mov   bp,dx               ;Sauvegarder pointeur sur DTA en BP
           cmp   [bp].datn,"."                              ;"." ou ".."
           je    prnend                              ;Oui, pas de sortie

           ;-- Lancer la comparaison de date si souhait‚e --------------

           cmp   datcomp,DATCOMP_NO                       ;Test de date?
           je    pn1                     ;Non, Sortir directement le nom

           mov   ax,[bp].datemod          ;Oui, lire date et d‚compacter
           mov   si,offset tdate
           call  entpackdat

           mov   di,offset sdate                       ;Comparer la date
           call  cmpdat
           cmp   al,datcomp                         ;Relation souhait‚e?
           jne   prnend                              ;Non, ne pas sortir

           call  printdat                             ;Date o.k., sortir

           ;-- Sortir ensuite les noms de r‚pertoires ------------------

pn1:       mov   dx,offset nomrep        ;Pointeur sur nom de r‚pertoire
           xor   al,al          ;Lire le dernier caractŠre du r‚pertoire
           xchg  al,[bx]                                ;et r‚gler sur 0
           mov   di,ax                           ;Ranger le car. dans DI
           call  printasciiz                   ;Sortir nom de r‚pertoire

           xchg  ax,di              ;Recharger AX avec l'ancienne valeur
           mov   [bx],al         ;Remettre l'ancien caractŠre … sa place

           ;-- Ins‚rer les noms de fichiers ----------------------------

           mov   dx,bp                     ;Replacer le pointeur sur DTA
           add   dx,offset datn       ;Adresser le nom de fichier en DTA
           call  printasciiz                                  ;et sortir

           mov   ah,PRINT_STR             ;Sortir saut de ligne … l'aide
           mov   dx,offset crlf                                  ;du DOS
           int   21h

           inc   found                          ;Un autre fichier trouv‚
           mov   dx,bp                               ;Relire l'ancien DX

prnend:    ret                                      ;Retour … l'appelant

printname        endp

;-- PRINTASCIIZ : Affiche une chaŒne ASCII termin‚e par un octet NUL ---
;--               sur STDOUT
;-- Entr‚e  : DX = Pointeur sur le d‚but de chaŒne
;--           DS = Segment de la chaŒne
;-- Sortie  : Aucune
;-- Registres : AX, DX, SI et FLAGS sont modifi‚s

printasciiz      proc near

           mov   si,dx                         ;Charger chaŒne depuis DX
           mov   ah,WRT_CHAR                 ;Nø fonct. pour sortie car.
           lodsb                              ;Charger premier caractŠre

pa1:       ;-- Boucle de sortie ----------------------------------------

           mov   dl,al              ;CaractŠre pour fonction DOS vers DL
           int   21h                                          ;et sortir

           lodsb                                ;Charger le car. suivant
           or    al,al                       ;Fin de la chaŒne atteinte?
           jne   pa1                                   ;Non, sortir car.

           ret                                      ;Retour … l'appelant

printasciiz      endp

;-- TOINT: Convertit un nombre binaire en ASCII et le place ------------
;--        dans un buffer de l'appelant
;-- Entr‚e  : DS:SI = Adresse du d‚but de buffer
;--           AX    = Le nombre binaire … convertir
;-- Sortie  : DS:SI = Adresse du premier chiffre
;-- Registres : AX, SI et FLAGS sont modifi‚s
;-- Infos     : - Le buffer doit contenir de la place pour cinq car.
;--             - Le nombre entr‚ dans le buffer est justifi‚ … droite.

toint            proc near

          push   dx                       ;Sauver les registres modifi‚s
          push   bx                                         ;sur la pile

          ;-- Compl‚ter le buffer par des espaces ----------------------

          mov    word ptr [si],   32 shl 8 + 32
          mov    word ptr [si+2], 32 shl 8 + 32
          mov    byte ptr [si+4], 32

          ;-- Dans une boucle, diviser toujours un nombre par 10 -------
          ;-- et convertir la position de poids faible au format ASCII -
          ;-- puis reporter dans le buffer -----------------------------

          add    si,5                    ;Placer SI sur la fin du buffer
          mov    bx,10                      ;Le diviseur est toujours 10

ti1:      dec    si                            ;SI sur le car. pr‚c‚dent
          xor    dx,dx                           ;Le dividende est DX:AX
          div    bx                                ;Diviser DX:AX par 10
          or     dl,'0'                  ;Transformer DL au format ASCII
          mov    [si],dl                          ;Placer dans le buffer
          or     ax,ax                               ;Y a-t-il un reste?
          jne    ti1                            ;OUI --> chiffre suivant

          pop    bx                               ;Retirer les registres
          pop    dx

          ret                                       ;Retour … l'appelant

toint            endp

;-- GETINT: lit un nombre d‚cimal positif dans la ligne d'instruction et
;--         le convertit au format binaire
;-- Entr‚e  : SI = Ptr sur le caractŠre suivant … lire dans le buffer
;--                de la ligne d'instruction
;-- Sortie  : Carry = 0: Nombre correct, 1 = Erreur
;--            SI   = Pointeur derriŠre le dernier caractŠre lu
;--            AX   = Nombre (seulement si Carry = 0)
;-- Registres : AX, CX, SI et FLAGS sont modifi‚s

getint           proc near

          push   bx                       ;Sauver les registres modifi‚s
          push   dx
          push   di

          mov    di,10                       ;Le facteur est toujours 10
          xor    bx,bx                      ;BX re‡oit le nombre binaire
          mov    ah,bh                         ;Hi-Byte de AH toujours 0

          ;-- Commencer … travailler depuis le d‚but du nombre ---------

gi1:      lodsb                                 ;Charger le car. suivant
          cmp    al,'0'                             ;Test sur le chiffre
          jb     gi2
          cmp    al,'9'
          jbe    gi5                             ;Chiffre trouv‚ --> GI5
gi2:      cmp    al,' '         ;Pas de chiffre, donc SPACE seulement et
          je     gi1                                       ;TAB autoris‚
          cmp    al,9
          je     gi1

      ;-- Lire le nombre chiffre par chiffre et convertir en binaire ---

gi4:      lodsb                               ;Lire le caractŠre suivant
          cmp    al,'0'                              ;Est-ce un chiffre?
          jb     gi7               ;NON --> Traiter le caractŠre suivant
          cmp    al,'9'
          ja     gi7               ;NON --> Traiter le caractŠre suivant

           ;-- OUI, c'est un chiffre -----------------------------------

gi5:      xchg   ax,bx         ;Lire le caractŠre en BX, le nombre en AX
          mul    di                                ;Multiplier AX par 10
          or     dx,dx                       ;Produit sup‚rieur … 65536?
          jne    gierr                        ;OUI --> Nombre trop grand
          and    bl,0Fh           ;Il ne reste que les 4 bits inf‚rieurs
          add    ax,bx                             ;Y ajouter le chiffre
          xchg   ax,bx                                ;Permuter AX et BX
          jmp    gi4                          ;Lire le caractŠre suivant
gi6:      clc                               ;Lire correctement le nombre
          mov    ax,bx                           ;Placer le nombre en AX
          jmp    short giend                        ;Retour … l'appelant

gi7:      dec    si                      ;Un caractŠre lu trop loin mais
          jmp    gi6                                         ;nombre o.k

gierr:    stc                                         ;Afficher l'erreur

giend:    pop    di                                ;Relire les registres
          pop    dx                                            ;modifi‚s
          pop    bx
          ret                                       ;Retour … l'appelant

getint           endp

;-- GETDAT: Lit une date au format "Jour.Mois.Ann‚e" dans la   ---------
;--         ligne d'instruction, la convertit en binaire et la place
;--         dans la structure sp‚cifi‚e
;-- Entr‚e  : SI = Ptr sur le caractŠre suivant … lire dans le buffer
;--                de la ligne d'instruction
;--           DI = Pointeur sur la structure de donn‚es devant recevoir
;--                la date convertie
;-- Sortie  : Carry = 0: Nombre o.k., 1 = Erreur
;--           SI    = Pointeur derriŠre le dernier caractŠre lu
;-- Registres : AX, CX, SI et FLAGS sont modifi‚s

getdat           proc near

          call   getint                                    ;Lire le jour
          jc     gderr                  ;Erreur? ---> Annuler la routine

          or     ax,ax                   ;Jour o.k., mais aussi valable?
          je     gderr                     ;Null non autoris‚ --> Erreur
          cmp    ax,31                                ;31 est le maximum
          ja     gderr                          ;D‚passement ---> Erreur

          mov    [di].jour,al   ;Jour o.k., range et continue ‚valuation

          lodsb                                ;Un point doit apparaŒtre
          cmp    al,DELIMITER
          jne    gderr                ;mais n'est pas apparu ---> Erreur

          ;-- Le jour ‚tait correct, ‚valuer maintenant le mois --------

          call   getint                                    ;Lire le mois
          jc     gderr                  ;Erreur? ---> Annuler la routine

          or     ax,ax                   ;Mois o.k., mais aussi valable?
          je     gderr                     ;Null est autoris‚ --> Erreur
          cmp    ax,12                                ;12 est le maximum
          ja     gderr                          ;D‚passement ---> Erreur

          mov    [di].mois,al                                  ;Mois o.k

          lodsb                       ;Un poit doit apparaŒtre ‚galement
          cmp    al,DELIMITER
          jne    gderr                ;mais n'est pas apparu ---> Erreur

          ;-- Le mois ‚tait correct, ‚valuer maintenant l'ann‚e --------

          call   getint                                    ;Lire l'ann‚e
          jc     gderr                  ;Erreur? ---> Annuler la routine

          cmp    ax,100                      ;Sans indication de siŠcle?
          ja     gd1                                  ;Non, --> Evaluer#

          add    ax,1900     ;Oui, prendre ‚galement le siŠcle en compte

gd1:      cmp    ax,1980                           ;Avant 1980 non admis
          jb     gderr                                ;Avant ---> Erreur

          mov    [di].an,ax           ;L'ann‚e est correct, tout va bien
          clc
          ret

gderr:    stc                             ;Impossible de traiter la date
          ret                                       ;Retour … l'appelant

getdat           endp

;-- ENTPACKDAT: D‚compacte une date stock‚e au format DOS et la --------
;--             la reporte dans une structure de type DATE
;-- Entr‚e  : AX = La date … d‚compacter au format DOS
;--           SI = Pointeur sur le bloc de date devant recevoir
;--                les informations
;-- Sortie  : Aucune
;-- Registres : AX, CX et FLAGS sont modifi‚s

entpackdat       proc near

          push   bx                               ;Sauver BX sur la pile
          mov    bl,al                    ;Lire Lo-Byte de la date en BX
          and    bl,31                  ;Dissocier les 3 bits sup‚rieurs
          mov    [si].jour,bl                    ;Ranger le jour du mois

          mov    bx,ax                ;Lire la totalit‚ de la date en BX
          mov    cl,5                  ;D‚caler de 5 bits vers la droite
          shr    bx,cl
          and    bl,15                  ;Dissocier les 4 bits sup‚rieurs
          mov    [si].mois,bl                            ;Ranger le mois

          shr    ah,1             ;Hi-Byte d'une position vers la droite
          mov    al,ah                ;ann‚e par rapport … 1980 dans LSB
          xor    ah,ah                                    ;Hi-Byte sur 0
          add    ax,1980                   ;Construire une ann‚e absolue
          mov    [si].an,ax                    ;Placer dans la structure

          pop    bx                                           ;Relire BX
          ret                                       ;Retour … l'appelant

entpackdat endp

;-- CMPDAT: Compare deux indications de date ---------------------------
;-- Entr‚e  : SI = Pointeur sur le premier bloc de date
;--           DI = Pointeur sur le second bloc de date
;-- Sortie  : Aucune
;-- Registres : AX et FLAGS sont modifi‚s

cmpdat           proc near

          ;-- Comparer d'abord les ann‚es ------------------------------

          mov    ax,[si].an                             ;Charger ann‚e 1
          cmp    ax,[di].an                    ;et comparer avec ann‚e 2
          jb     avant                    ;Date 1 avant date 2 --> AVANT
          ja     apres                    ;Date 1 aprŠs Date 2 --> APRES

          ;-- Les ann‚es sont identiques, comparer maintenant les mois -

          mov    al,[si].mois                            ;Charger mois 1
          cmp    al,[di].mois                   ;et comparer avec mois 2
          jb     avant                    ;Date 1 avant Date 2 --> AVANT
          ja     apres                    ;Date 1 aprŠs Date 2 --> APRES

          ;-- Les mois ‚tant identiques, comparer le jour du mois ------

          mov    al,[si].jour                            ;Charger jour 1
          cmp    al,[di].jour                   ;et comparer avec jour 2
          jb     avant                    ;Date 1 avant Date 2 --> AVANT
          ja     apres                    ;Date 1 aprŠs Date 2 --> APRES

          mov    al,DATCOMP_GL         ;Les deux donn‚es sont identiques
          ret                                       ;Retour … l'appelant

avant:    mov    al,DATCOMP_KL                      ;Date 1 avant Date 2
          ret                                       ;Retour … l'appelant

apres:    mov    al,DATCOMP_GR                      ;Date 1 aprŠs Date 2
          ret                                       ;Retour … l'appelant

cmpdat           endp

;-- PRINTDAT: Affiche une date issue d'une structure de date sur l'‚cran
;-- Entr‚e  : SI = Pointeur sur structure de date
;-- Sortie  : Aucune
;-- Registres : AX, DX, SI et FLAGS sont modifi‚s

printdat         proc near

          push   si                     ;Sauver SI, BX et DX sur la pile
          push   bx
          push   dx

          mov    bx,si               ;Placer BX sur la structure de date
          mov    si,offset datpend-8   ;SI … l'endroit r‚serv‚ … l'ann‚e
          mov    ax,[bx].an                             ;Charger l'ann‚e
          call   toint                            ;et convertir en ASCII
          mov    byte ptr [si-1],DELIMITER      ;Un point devant l'ann‚e

          sub    si,6                    ;SI … l'endroit r‚serv‚ au mois
          mov    al,[bx].mois                     ;Charger le mois en AX
          xor    ah,ah
          call   toint                            ;et convertir en ASCII
          cmp    [bx].mois,10                 ;Faire pr‚c‚der d'un z‚ro?
          jae    pd1                              ;Non, donc transmettre

          dec    si
          mov    byte ptr [si],"0"

pd1:      mov    byte ptr [si-1],DELIMITER      ;Un point devant le mois
          sub    si,6                    ;SI … l'endroit r‚serv‚ au jour
          mov    al,[bx].jour                     ;Charger le jour en AX
          xor    ah,ah
          call   toint                            ;et convertir en ASCII

          cmp    [bx].jour,10         ;Espace devant le premier chiffre?
          jae    pd2                          ;Oui, transmettre tel quel

          dec    si                      ;Non, SI sur le premier chiffre
          mov    byte ptr [si]," "                 ;et ins‚rer un espace

pd2:      mov    dx,si                                      ;D‚but en DX
          call   printasciiz                     ;Sortir la chaŒne ASCII

pd3:      pop    dx                     ;Retirer DX, BX et SI de la pile
          pop    bx
          pop    si

          ret

printdat         endp

;-- A partir d'ici les DTA seront conserv‚s pendant les appels r‚cursifs

startdta   equ this byte

;== Fin ================================================================

code       ends                                  ;Fin du segment de code
           end   start
