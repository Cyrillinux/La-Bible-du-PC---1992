;**********************************************************************;
;*                         L O G O C A . A S M                        *;
;*--------------------------------------------------------------------*;
;*    Fonction       : d�finit un jeu de caract�res personnalis�s     *;
;*                      pour les cartes EGA et VGA                    *;
;*--------------------------------------------------------------------*;
;*    Auteur         : MICHAEL TISCHER                                *;
;*    D�velopp� le   :  7.08.1990                                     *;
;*    Derni�re MAJ   : 14.02.1992                                     *;
;*--------------------------------------------------------------------*;
;*    Assemblage     : TASM -mx logoca     ou MASM -mx logoca;        *;
;**********************************************************************;

      DOSSEG                               ; Ordre des segments habituel
      .MODEL SMALL, C                      ; Pr�pare l'inclusion du code
                                   ; dans un programme C en mod�le SMALL

      PUBLIC defchar

;== Code ===============================================================

      .CODE

;-- DEFCHAR : fixe les motifs des caract�res pour cartes EGA et VGA
;--
;-- D�claration en C : void defchar( BYTE ascii, BYTE table, BYTE height
;--                                  BYTE nombre, void far * buf );
;-- Entr�es          : ASCII  = Num�ro du 1er caract�re � d�finir
;--                    TABL   = Num�ro de la table des caract�res
;--                    HEIGHT = Hauteur des caract�res (lignes de trame)
;--                    NOMBRE = Nombre de caract�res
;--                    BUF    = Pointeur Far sur le buffer
;-- Sortie           : n�ant

defchar   proc ascii:byte,  tabl:byte, height:byte, \
               nombre:byte, buf:dword

      mov  ax,1100h            ; Appelle l'option 00h de la fonction 11h
      mov  bh,height                  ; Charge les param�tres appropri�s
      mov  bl,tabl                                  ; dans les registres
      mov  dl,ascii
      xor  dh,dh
      mov  cl,nombre
      mov  ch,dh

      push bp                  ; M�morise BP pour l'adressage de la pile
      les  bp,buf
      int  10h                       ; Appelle l'interruption vid�o BIOS
      pop  bp                                     ; R�cup�re l'ancien BP

      ret                                        ; Retourne � l'appelant

defchar   endp

;== Fin ================================================================
          end
