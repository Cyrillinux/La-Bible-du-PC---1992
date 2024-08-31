;**********************************************************************;
;*                            C E B H A N D                           *;
;*--------------------------------------------------------------------*;
;*    Fonction  : Constitue l'outil de base d'un programme            *;
;*                Assembleur dans lequel il s'agit de d‚tourner les   *;
;*                interruptions Ctrl Break et Critical-Error du DOS.  *;
;*--------------------------------------------------------------------*;
;*    Auteur          : MICHAEL TISCHER                               *;
;*    D‚velopp‚ le    :  5.09.1988                                    *;
;*    DerniŠre modif. : 19.03.1992                                    *;
;*--------------------------------------------------------------------*;
;*    Pour assembler  : MASM CEBHAND;                                 *;
;*                      LINK CEBHAND;                                 *;
;*              ou                                                    *;
;*                      TASM CEBHAND                                  *;
;*                      TLINK CEBHAND                                 *;
;*--------------------------------------------------------------------*;
;*    Appel         : CEBHAND                                         *;
;*                    (Laisser ouvert le lecteur de disquettes A      *;
;*                     pour qu'une Critical-Error ait lieu.)          *;
;**********************************************************************;

;== Constantes =========================================================


;== Stack ==============================================================

stackseg  segment para stack 'STACK'      ;D‚finition du segment de pile

          dw 256 dup (?)           ;La taille de la pile est de 256 mots

stackseg  ends                                   ;Fin du segment de pile

;== Donn‚es ============================================================

data      segment para 'DATA'          ;D‚finition du segment de donn‚es

cr_err    db  0                   ;vaut 1 si r‚gl‚ sur 1 lors de l'accŠs
                                   ;P‚riph‚riques (Disquette, Disque dur
                                     ;ou imprimante) une erreur critique
                                                           ;est apparue.
cr_typ    db  0                    ;Num‚ro d'erreur de l'erreur critique

cr_mes    db  "Erreur critique! (A)nnuler ou (R)eprise: $"
next_line db  13,10,"$"
end_mes   db  "Programme termin‚ correctement.$"
brk_mes   db  "Programme interrompu.$"
nom_fich  db  "A:TEST.DAT",0                        ;Nom du fichier test

data      ends                                ;Fin du segment de donn‚es

;== Code ===============================================================

code      segment para 'CODE'             ;D‚finition du segment de code

          assume cs:code, ds:data, ss:stackseg

start            proc far

          ;-- Installer les deux handlers d'interruption ---------------

          push cs                                        ;CS sur la pile
          pop  ds                           ;Retirer pour placer dans DS
          mov  ax,2523h             ;nø fonc.: R‚gler Handler Ctrl-Break
          mov  dx,offset cbreak      ;DS:DX : maintenant l'adresse du H.
          int  21h                           ;Appeler l'interruption DOS

          mov  al,24h                         ;R‚gler l'interruption 24h
          mov  dx,offset cerror  ;DS:DX contient l'adresse du nouveau H.
          int  21h                           ;Appeler l'interruption DOS

          mov  ax,data     ;Charge adresse segment du segment de donn‚es
          mov  ds,ax                                ;dans le registre DS

          ;-- Ici vous pouvez ins‚rer votre programme ici --------------
          ;-------------------------------------------------------------

          ;-- En guise de d‚monstration, on essaye d'ouvrir un fichier -
          ;-- sur le lecteur de disquettes ouvert ----------------------

ouvrir_fich:
          mov  ah,3dh                           ;Nøfonc.: Ouvrir fichier
          mov  al,0                           ;Mode fich.: Lecture seule
          mov  dx,offset nom_fich     ;DS:DX = Adresse du nom de fichier
          int  21h                         ;Appeler interruption DOS 21h
          jnc  fin                            ;Pas d'erreur? NON --> FIN

          cmp  cr_err,0                                 ;Critical Error?
          je   fin                                          ;NON --> FIN

          call crit_err                 ;Une erreur critique est apparue
          jmp  ouvrir_fich       ;CRIT_ERR ne revient que si l'op‚ration
                                                      ;doit ˆtre r‚p‚t‚e
                                          ;(il est impossible d'ignorer)

          ;-- Les Handlers ne doivent pas ˆtre r‚install‚s avant -------
          ;-- la fin du programme car c'est DOS qui s'en charge --------

fin:      mov  ah,9                         ;Nøfonc.: Afficher la chaŒne
          mov  dx,offset end_mes             ;DS:DX = Adresse du message
          int  21h                             ;Appeler interruption DOS

          mov  ax,4C00h      ;Nøfonc.: Terminer le programme (ERRCODE=0)
          int  21h                             ;Appeler interruption DOS
                                               ;et terminer le programme

start            endp

;-- CRIT_ERR: Appel‚ dans le programme aprŠs d‚couverte ----------------
;--           d'une erreur critique ------------------------------------

crit_err         proc near

          ;-- Afficher le message et r‚clamer l'entr‚e de l'utilisateur-

ask:      mov  ah,9                           ;Nøfonc.: Sortir la chaŒne
          mov  dx,offset cr_mes              ;DS:DX = Adresse du message
          int  21h                           ;Appeler l'interruption DOS

          mov  ah,1                      ;Nøfonc.: Entrer les caractŠres
          int  21h                           ;Appeler l'interruption DOS
          push ax                                   ;Apercevoir l'entr‚e

          mov  ah,9                           ;Nøfonc.: Sortir la chaŒne
          mov  dx,offset next_line           ;DS:DX = Adresse du message
          int  21h                           ;Appeler l'interruption DOS

          ;-- Evaluer l'entr‚e de l'utilisateur ------------------------

          pop  ax                                       ;Relire l'entr‚e
          cmp  al,"A"                                          ;Annuler?
          je   end_up                            ;zur "Aufr„um"-Prozedur
          cmp  al,"a"                                          ;Annuler?
          je   end_up                            ;zur "Aufr„um"-Prozedur
          cmp  al,"r"                                          ;R‚p‚ter?
          je   crend                   ;Oui, vers la fin de la proc‚dure
          cmp  al,"R"                                          ;R‚p‚ter?
          jne  ask                                ;NON, nouvelle requˆte

crend:    ret                                       ;Retour … l'appelant

crit_err  endp

;-- END_UP: Ex‚cute une "fin correcte"  --------------------------------

end_up           proc near

          ;-- Tous les fichiers ouverts peuvent ˆtre ferm‚s ici et -----
          ;-- la m‚moire systŠme allou‚e par le programme lib‚r‚e ------

          mov  ah,9                           ;Nøfonc.: Sortir la chaŒne
          mov  dx,offset brk_mes            ;DS:DX = Adresse der Meldung
          int  21h                           ;Appeler l'interruption DOS

          mov  ax,4C00h     ;Terminer normalement le programme … travers
          int  21h                                      ;la fonction 4Ch

end_up           endp

;-- CBREAK: Le nouveau handler Ctrl-Break ------------------------------

cbreak           proc far

          ;-- Tous les registres modifi‚s dans cette routine -----------
          ;-- doivent ˆtre sauvegard‚s sur la pile ---------------------
          ;-- (except‚ le registre Flag). ------------------------------

          push ds

          mov  ax,data     ;Charge adresse segment du segment de donn‚es
          mov  ds,ax                                ;dans le registre DS



          ;-- Ici, on peut par exemple ouvrir une fenˆtre ‚cran --------
          ;-- o— on demande … l'utilisateur s'il souhaite --------------
          ;-- terminer r‚ellement le programme. ------------------------

          jmp  go_on                       ;Ne pas terminer le programme



          ;-- Si l'utilisateur a d‚cid‚ de terminer le programme -------
          ;-- on peut inclure ici une routine permettant ---------------
          ;-- de terminer le programme. --------------------------------

          jmp   end_up                     ;Pr‚parer la fin de programme



          ;-- Le programme n'est pas interrompu mais il est plut“t  ----
          ;-- trait‚ tout … fait normalement ---------------------------

go_on:    pop   ds                    ;Retirer les registres sauvegard‚s
          iret                          ;Retour au DOS o— traitement de 
                           ; la fonction interrompue reprend normalement
cbreak           endp

;-- CERROR: Le nouveau handler Critical-Error --------------------------

cerror           proc far

          ;-- Tout registre SS, SP, DX, ES, DX, CX et BX modifi‚ -------
          ;-- dans cette routine doit ˆtre sauvegard‚ sur la pile. -----

          sti                     ;Autoriser … nouveau les interruptions
          push ds

          mov  ax,data     ;Charge adresse segment du segment de donn‚es
          mov  ds,ax                                ;dans le registre DS

          mov  cr_err,1                      ;Afficher l'erreur critique
          mov  ax,di                            ;Num‚ro d'erreur dans AX
          mov  cr_typ,al                  ;Apercevoir le num‚ro d'erreur
          mov  al,3            ;Terminer l'appel de fonction avec erreur

          pop  ds                                             ;Relire DS
          iret

cerror    endp

;-----------------------------------------------------------------------

code      ends                                   ;Fin du segment de code
          end  start                 ;Commencer l'ex‚cution du programme
                                                ;avec la proc‚dure START
