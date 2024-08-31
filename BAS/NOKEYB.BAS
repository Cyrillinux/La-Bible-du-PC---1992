'***********************************************************************
'*                              N O K E Y B                            *
'*---------------------------------------------------------------------*
'*    Montre comment effacer le buffer du clavier pour prot‚ger        *
'*    l'utilisateur contre des saisies r‚siduelles lorsqu'il doit      *
'*    r‚pondre … des questions importantes (par ex "Voulez-vous        *
'*    supprimer tel fichier ?")                                        *
'*---------------------------------------------------------------------*
'* Auteur                : MICHAEL TISCHER                             *
'* D‚velopp‚ le          : 01.01.1992                                  *
'* DerniŠre modification : 01.01.1992                                  *
'***********************************************************************
'
DECLARE SUB ClearKbBuffer ()
'-- Programme principal ------------------------------------------------

DIM i AS INTEGER                                  'Compteur d'it‚rations

CLS
PRINT ("NOKEYB  -  (c) 1992 by Michael Tischer")
PRINT
PRINT ("A 0 les caractŠres du buffer vont ˆtre effac‚s.")
PRINT

FOR i = 10 TO 0 STEP -1                'le temps de taper des caractŠres
  PRINT i; "     "
  SLEEP 1
NEXT

ClearKbBuffer                                 'Vide le buffer du clavier

'--- Affiche les caractŠres qui restent dans le buffer------------------

ccount = 0                                      'Pas encore de caractŠre
PRINT
PRINT
PRINT ("CaractŠres dans le buffer:")

DO                                                      'En reste-t-il ?
  a$ = INKEY$
  IF a$ <> "" THEN
    FOR i = 1 TO LEN(a$)
      PRINT "   "; ASC(MID$(a$, i, 1)),         'Affiche d'abord le code
      IF ASC(MID$(a$, i, 1)) > 32 THEN              'CaractŠre sp‚cial ?
        PRINT "("; MID$(a$, i, 1); ")";       'Non, affiche le caractŠre
      END IF
      PRINT
      ccount = ccount + 1
    NEXT
  END IF
LOOP WHILE a$ <> ""

IF ccount = 0 THEN                                   'Pas de caractŠre ?
  PRINT ("(Aucun)")                                                 'Non
END IF
PRINT

END

'***********************************************************************
'* ClearKbBuffer : Efface le contenu du buffer du clavier              *
'* Entr‚e: n‚ant                                                       *
'* Sortie: n‚ant                                                       *
'***********************************************************************
'
SUB ClearKbBuffer

DO           'Retire les caractŠres du buffer jusqu'… ce qu'il soit vide
LOOP WHILE INKEY$ <> ""

END SUB

