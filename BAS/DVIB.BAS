'***********************************************************************
'*                                DVIB                                 *
'-----------------------------------------------------------------------
'*  Fonction     : montre comment accŠder directement … la m‚moire ‚cran
'-----------------------------------------------------------------------
'*  Auteur       : MICHAEL TISCHER                                     *
'*  D‚velopp‚ le : 06.05.1991                                          *
'*  DerniŠre MAJ : 06.05.1991                                          *
'***********************************************************************
DECLARE SUB InitDPrint ()
DECLARE SUB Demo ()
DECLARE SUB DPrint (Colonne%, Ligne%, Couleur%, StrOut AS STRING)


CONST NORMAL = &H7          'D‚finit les attributs d'un ‚cran monochrome
CONST CLAIR = &HF
CONST INVERSE = &H70
CONST SOULIGNE = &H1
CONST CLIGNOTANT = &H80

CONST NOIR = &H0               'D‚finit les couleurs d'une carte couleur
CONST BLEU = &H1
CONST VERT = &H2
CONST CYAN = &H3
CONST ROUGE = &H4
CONST MAGENTA = &H5
CONST BRUN = &H6
CONST GRISCLAIR = &H7
CONST GRISFONCE = &H8
CONST BLEUCLAIR = &H9
CONST VERTCLAIR = &HA
CONST CYANCLAIR = &HB
CONST ROUGECLAIR = &HC
CONST MAGENTACLAIR = &HD
CONST JAUNE = &HE
CONST BLANC = &HF

DIM SHARED VSeg AS LONG                   'Segment de la m‚moire d'‚cran

CALL InitDPrint                         'Initialise la sortie par DPrint
CALL Demo                                       'D‚monstration de DPrint
END

'***********************************************************************
'* Demo    : D‚monstration de DPrint                                   *
'* Entr‚e  : n‚ant                                                     *
'* Sortie  : n‚ant                                                     *
'***********************************************************************
SUB Demo

DIM Colonne AS INTEGER                              'Colonne d'affichage
DIM Ligne AS INTEGER                                  'Ligne d'affichage
DIM Couleur AS INTEGER                          'Attribut de l'affichage

RANDOMIZE TIMER            'Initialise le g‚n‚rateur de nombre al‚atoire
IF VSeg = &HB800 THEN            'A-t-on branch‚ un adaptateur couleur ?
  CLS   'Efface l'‚cran
  CALL DPrint(22, 0, BLANC, "DVIB - (c) 1988, 1992 by Michael Tischer ")
  DO
    Colonne = INT(76 * RND)                           'Colonne au hasard
    Ligne = INT(22 * RND) + 1                           'Ligne au hasard
    Couleur = INT(14 * RND) + 1                       'Couleur au hasard
    CALL DPrint(Colonne, Ligne, Couleur, "ÛÛÛ")         'Affiche un pav‚
  LOOP UNTIL INKEY$ <> ""  'r‚pŠte l'op‚ration jusqu'… frappe une touche
ELSE                                      'On a un adaptateur monochrome
  CLS                                                    'Efface l'‚cran
  CALL DPrint(22, 0, INVERSE, "DVIB - (c) 1988, 92 by Michael Tischer ")
  DO
    Colonne = INT(76 * RND)                           'Colonne au hasard
    Ligne = INT(22 * RND) + 1                           'Ligne au hasard
    SELECT CASE INT(4 * RND)                         'Attribut au hasard
       CASE 0
	 Couleur = NORMAL
       CASE 1
	 Couleur = CLAIR
       CASE 2
	 Couleur = INVERSE
       CASE 3
	 Couleur = CLIGNOTANT OR INVERSE                  'plus visible
    END SELECT
    CALL DPrint(Colonne, Ligne, Couleur, "ÛÛ")         'Affiche un pav‚
  LOOP UNTIL INKEY$ <> ""  ' r‚pŠte op‚ration jusqu'… frappe une touche
END IF
END SUB

'***********************************************************************
'* DPrint  : Ecrit une chaŒne directement dans la m‚moire d'‚cran      *
'* Entr‚e  :  - Colonne : colonne d'affichage                          *
'*            - Ligne  : ligne d'affichage                             *
'*            - Couleur  : Couleur(Attribut) des caractŠres            *
'*            - SrtOut : ChaŒne … afficher                             *
'* Sortie  : n‚ant                                                     *
'***********************************************************************
SUB DPrint (Colonne%, Ligne%, Couleur%, StrOut AS STRING)

DIM Offset AS INTEGER             'Offset o— il faut ‚crire le caractŠre
DIM Compteur AS INTEGER                           'Compteur d'it‚rations

DEF SEG = &H40                 'Segment de la zone des variables du BIOS
Offset = PEEK(&H4E) + PEEK(&H4F) * 256      'Adresse de d‚but de la page
Offset = Offset + Ligne% * 160 + Colonne% * 2    'Offset du premier car.
DEF SEG = VSeg                            'Segment de la m‚moire d'‚cran
FOR Compteur = 1 TO LEN(StrOut)                      'parcourt la chaŒne
  POKE Offset, ASC(MID$(StrOut, Compteur, 1))    'ASCII en m‚moire ‚cran
  POKE Offset + 1, Couleur%                       ' ainsi que la couleur
  Offset = Offset + 2                      'Offset du prochain caractŠre
NEXT
END SUB

'***********************************************************************
'* InitDPrint : Lit le segment pour DPrint                             *
'* Entr‚e    : n‚ant                                                   *
'* Sortie    : Met le segment de la m‚moire d'‚cran dans la variable   *
'*             globale VSeg                                            *
'***********************************************************************
SUB InitDPrint

DEF SEG = &H40                            'Segment des variables du BIOS
IF PEEK(&H63) + PEEK(&H64) * 256 = &H3B4 THEN     'Adaptateur monochrome
  VSeg = &HB000                'La m‚moire d'‚cran commence en 8000:0000
ELSE                                                 'Adaptateur couleur
  VSeg = &HB800                'La m‚moire d'‚cran commence en B800:0000
END IF
END SUB

