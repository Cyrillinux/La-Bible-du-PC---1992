'***********************************************************************
'*                                 D I R B                             *
'-----------------------------------------------------------------------
'*  Fonction  :  Affiche tous les fichiers d'un r‚pertoire quelconque  *
'*               y compris les sous-r‚pertoires et noms de volumes     *
'*               sur l'‚cran                                           *
'-----------------------------------------------------------------------
'*  Auteur         : Michael Tischer                                   *
'*  D‚velopp‚ le   :  8.07.1987                                        *
'*  DerniŠre modif.: 15.03.1992                                        *
'***********************************************************************

DECLARE FUNCTION MakeWord! (Nombre AS INTEGER)
DECLARE FUNCTION Dat$ (Valeur AS INTEGER)
DECLARE SUB SetDTA (Segment AS LONG, Offset AS LONG)
DECLARE SUB ConfigEcran ()
DECLARE FUNCTION Mois$ (Mon AS INTEGER)
DECLARE FUNCTION FindNext% ()
DECLARE FUNCTION FindFirst% (NomFichier AS STRING, Attr AS INTEGER)
DECLARE SUB PrintData (DirBuf AS ANY)
DECLARE SUB Dir (Pfad AS STRING, Attr AS INTEGER)

'$INCLUDE: 'QB.BI'           'FichierInclude pour appels d'interruptions

'-- Stucture d'entr‚e de r‚pertoire comme dans fonctions DOS &H4E et ---
'-- retourner &H4F------------------------------------------------------

TYPE DirStruct
   Reserve AS STRING * 21
   Attrib AS STRING * 1
   Time AS INTEGER
   Date AS INTEGER
   Size AS LONG
   DatName AS STRING * 13
END TYPE

'-- Constantes --------------------------------------------------------

CONST TRUE = -1                          'D‚clarer les valeurs de v‚rit‚
CONST FALSE = NOT TRUE

CONST FCARRY = 1                                             'Carry-Flag
CONST EIntr = 14           'Autant d'entr‚es sont visibles simultan‚ment
CONST BildTop = (20 - EIntr) \ 2        'Ligne sup. de fenˆtre de sortie

CONST FAReadOnly = &H1                            ' Attributs de fichier
CONST FAHidden = &H2
CONST FASysFile = &H4
CONST FAVolumeID = &H8
CONST FADirectory = &H10
CONST FAArchive = &H20
CONST FAAnyFile = &H3F

'-- Programme principal -----

IF COMMAND$ = "" THEN                     'Aucun nom de fichier pr‚cis‚?
  CALL Dir("*.*", FAAnyFile)       'Non, aff. ts fic. dans r‚p. en cours
ELSE
  CALL Dir(COMMAND$, FAAnyFile)     'Oui, afficher les fichiers d‚sign‚s
END IF

'***********************************************************************
'* ConfigEcran : Configure l'‚cran pour la sortie                      *
'*               d'un r‚pertoire                                       *
'* Entr‚e          : Aucune                                            *
'* Sortie          : Aucune                                            *
'***********************************************************************
'
SUB ConfigEcran

CONST Lr = "              "           'D‚cale marge gauche vers position
DIM Compteur AS INTEGER                              'Compteur de boucle

CLS                                                     'Effacer l'‚cran
VIEW PRINT (BildTop + 1) TO (BildTop + 5 + EIntr)

PRINT Lr + "ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍÍÍÍÍÍÍÑÍÍÍÍÍ»"
PRINT Lr + "º  Nom         ³  Taille ³    Date     ³   Heure   ³RHSVDº"
PRINT Lr + "ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄ¶"

FOR Compteur = 1 TO EIntr
PRINT Lr + "º              ³         ³             ³           ³     º"
NEXT

PRINT Lr + "ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍÍÍÍÍÍÍÏÍÍÍÍÍ¼"
VIEW PRINT (BildTop + 4) TO (BildTop + 3 + EIntr)

END SUB

'***********************************************************************
'* Dat$   : Convertit valeur dans chaŒne de car. dont le format        *
'*          correspond … celui utilis‚ pour sorties de date/heure      *
'* Entr‚e : Valeur … convertir                                         *
'* Sortie : ChaŒne de car. correspondant … la valeur                   *
'* Infos  : STR$ ou RPINT USING ne retournent pas de z‚ros de fin      *
'***********************************************************************
'
FUNCTION Dat$ (Valeur AS INTEGER)

DIM Memoire AS STRING                'Sauvegarde la valeur interm‚diaire

Memoire = LTRIM$(STR$(Valeur))
WHILE LEN(Memoire) < 2          'La m‚moire contient moins de 2 chiffres
  Memoire = "0" + Memoire
WEND

Dat$ = Memoire

END FUNCTION

'***********************************************************************
'* Dir     : Contr“le la lecture et la sortie du r‚pertoire            *
'* Entr‚e : Aucune                                                     *
'* Sortie : Aucune                                                     *
'***********************************************************************
'
SUB Dir (Chemin AS STRING, Attr AS INTEGER)

DIM NbEntrees AS INTEGER                'Nombre total d'entr‚es trouv‚es
DIM NbImage   AS INTEGER                  'Nombre d'entr‚es dans l'image
DIM DirBuf    AS DirStruct           'Re‡oit des informations de fichier

CALL SetDTA(VARSEG(DirBuf), VARPTR(DirBuf))        'DirBuf = nouveau DTA
CLS                                                     'Effacer l'‚cran
CALL ConfigEcran        'Construire l'‚cran pour la sortie de r‚pertoire

NbImage = -1        'Aucune entr‚e n'est encore affich‚e dans la fenˆtre
NbEntrees = 0                       'Aucune entr‚e na ‚t‚ encore trouv‚e
IF FindFirst(Chemin, Attr) THEN       'Rech. 1Šre entr‚e (Attribut egal)
  DO                                        'Afficher toutes les entr‚es
    NbEntrees = NbEntrees + 1                  'Une autre entr‚e trouv‚e
    NbImage = NbImage + 1                     'Une autre entr‚e affich‚e
    IF NbImage = EIntr THEN                            'Fenˆtre pleine ?
   '-- Oui, attendre appui sur touche puis aff. nouvelle page de tableau
      VIEW PRINT (BildTop + 5 + EIntr) TO (BildTop + 6 + EIntr)
      PRINT "                 Veuillez appuyer sur une touche "
      SLEEP                             'Attendre l'appui sur une touche
      VIEW PRINT (BildTop + 4) TO (BildTop + 3 + EIntr)
      NbImage = 0             'Afficher d'autres entr‚es dans la fenˆtre
    END IF
    CALL PrintData(DirBuf)             'Afficher les donn‚es de l'entr‚e
  LOOP UNTIL NOT FindNext                     'Y a-t-il une autre entr‚e
END IF

VIEW PRINT (BildTop + 5 + EIntr) TO (BildTop + 6 + EIntr)
CLS

SELECT CASE NbEntrees
  CASE 0
    PRINT "Aucun fichier trouv‚"
  CASE 1
    PRINT "Un fichier trouv‚"
  CASE ELSE
    PRINT STR$(NbEntrees); " Fichiers trouv‚s"
END SELECT
VIEW PRINT 1 TO 25

END SUB

'***********************************************************************
'* FindFirst : Lire la premiŠre entr‚e de r‚pertoire                   *
'* Entr‚e  : Le nom de fichier, Les attributs de fichier               *
'* Sortie  : TRUE, si l'entr‚e a ‚t‚ trouv‚e sinon FALSE               *
'* Infos   : L'entr‚e est lue dans les variables DirBuf                *
'***********************************************************************
'
FUNCTION FindFirst% (NomFichier AS STRING, Attr AS INTEGER)

DIM Fichier AS STRING * 65         'M‚m. tampon pour nom fichier (s. Text)
DIM Regs AS RegTypeX                            'Registres du processeur

Fichier = NomFichier                      'Transmettre le nom de fichier
Fichier = Fichier + CHR$(0)        'Terminer le nom de fichier par <NUL>
Regs.ax = &H4E00          'AH = Num‚ro de fonction pour Search for first
Regs.cx = Attr                                     'Attributs recherch‚s
Regs.ds = VARSEG(Fichier)          'Adresse de segment du nom de fichier
Regs.dx = VARPTR(Fichier)            'Adresse d'offset du nom de fichier

CALL INTERRUPTX(&H21, Regs, Regs)            'Appeler l'interruption DOS
IF (Regs.flags AND FCARRY) = 0 THEN                   'Tester Flag Carry
  FindFirst = TRUE                            'Non r‚gl‚: Fichier trouv‚
ELSE                                          'R‚gl‚: Fichier non trouv‚
  FindFirst = FALSE
END IF

END FUNCTION

'***********************************************************************
'* FindNext : Lit l'entr‚e de r‚pertoire suivante                      *
'* Entr‚e : Aucune                                                     *
'* Sortie : TRUE, si l'entr‚e a ‚t‚ trouv‚e sinon FALSE                *
'* Infos    : La fonction ne peut ˆtre appel‚e que si l'appel de       *
'*           GetFirst a abouti, l'entr‚e est lue                       *
'*           dans les variables DirBuf                                 *
'***********************************************************************
'
FUNCTION FindNext%

DIM Regs AS RegType               'Reg. proc. pour appels d'interruption

Regs.ax = &H4F00              'AH = 4F: Num‚ro de fonction pour for next
CALL INTERRUPT(&H21, Regs, Regs)             'Appeler l'interruption DOS

IF (Regs.flags AND FCARRY) = 0 THEN                   'Tester Flag Carry
  FindNext = TRUE                             'Non r‚gl‚: Fichier trouv‚
ELSE                                          'R‚gl‚: Fichier non trouv‚
  FindNext = FALSE
END IF

END FUNCTION

'***********************************************************************
'* Makeword : Transforme un Integer en Long car en BASIC               *
'*            les op‚rations de d‚placement de bits r‚alis‚es par des  *
'*            divisions en nombres entiers s'effectuent incorrectement *
'*            avec un nombre n‚gatif.                                  *
'* Entr‚e  : Le nombre Integer                                         *
'* Sortie  : Le nombre Long correspondant au modŠle de bits            *
'***********************************************************************
'
FUNCTION MakeWord! (Nombre AS INTEGER)

IF Nombre < 0 THEN
  MakeWord = 65536! + Nombre
ELSE
  MakeWord = Nombre
END IF

END FUNCTION

'***********************************************************************
'* Mois   : Affiche un mois sous forme d'une chaŒne                    *
'* Entr‚e : Le num‚ro du mois                                          *
'* Sortie : Le nom du mois sous forme d'une chaŒne                     *
'***********************************************************************
'
FUNCTION Mois$ (Mon AS INTEGER)

SELECT CASE Mon
  CASE 1
    Mois$ = "Jan"
  CASE 2
    Mois$ = "Fev"
  CASE 3
    Mois$ = "Mar"
  CASE 4
    Mois$ = "Avr"
  CASE 5
    Mois$ = "Mai"
  CASE 6
    Mois$ = "Jun"
  CASE 7
    Mois$ = "Jul"
  CASE 8
    Mois$ = "Aug"
  CASE 9
    Mois$ = "Sep"
  CASE 10
    Mois$ = "Oct"
  CASE 11
    Mois$ = "Nov"
  CASE 12
    Mois$ = "Dec"
END SELECT

END FUNCTION

'***********************************************************************
'* PrintData : Afficher des informations … propos d'une entr‚e         *
'* Entr‚e   : Le DirBufType avec des informations de fichier           *
'* Sortie   : Aucune                                                   *
'***********************************************************************
'
SUB PrintData (DirBuf AS DirStruct)

DIM Compteur AS INTEGER                              'Compteur de boucle

PRINT                       'Afficher une nouvelle ligne dans le tableau
LOCATE BildTop + EIntr + 3, 15      'derniŠre ligne de fenˆtre de sortie
PRINT "º";

Compteur = 1
WHILE MID$(DirBuf.DatName, Compteur, 1) <> CHR$(0)        'Jusqu'… <NUL>
  PRINT MID$(DirBuf.DatName, Compteur, 1);         'Afficher car. du nom
  Compteur = Compteur + 1                             'CaractŠre suivant
WEND

'-- Calculer et afficher la taille du fichier --------------------------

LOCATE BildTop + EIntr + 3, 30                   'Positionner le curseur
PRINT USING "³ ####### "; DirBuf.Size;

'-- Afficher la date et l'heure ----------------------------------------
LOCATE BildTop + EIntr + 3, 40
PRINT "³ "; Dat$(MakeWord(DirBuf.Date) AND 31); " ";               'jour
PRINT Mois((MakeWord(DirBuf.Date) \ 32) AND 15);                   'mois
PRINT USING " ####"; (MakeWord(DirBuf.Date) \ 512) + 1980;        'ann‚e

LOCATE BildTop + EIntr + 3, 53
PRINT " ³ "; Dat$(MakeWord(DirBuf.Time) \ 2048); " Heure";        'heure
PRINT " "; Dat$((MakeWord(DirBuf.Time) \ 32) AND 63);            'minute

'-- Afficher les attributs de fichier ----------------------------------

LOCATE BildTop + EIntr + 3, 66
PRINT "³";

Compteur = 1
WHILE (Compteur < 32)
  IF (ASC(DirBuf.Attrib) AND Compteur) <> 0 THEN           'Read- Only ?
    PRINT "X";
  ELSE
    PRINT " ";
  END IF
  Compteur = Compteur * 2
WEND
PRINT "º";                                         'Cadre droit du champ

END SUB

'***********************************************************************
'* SetDTA  : Fixe l'adresse de DTA                                     *
'* Entr‚e : Adresses de segment et d'offset du buffer pour le DTA      *
'* Sortie : Aucune                                                     *
'***********************************************************************
'
SUB SetDTA (Segment AS LONG, Offset AS LONG)

DIM Regs AS RegTypeX                            'Registres du processeur

Regs.ax = &H1A00           'AH = &H1A Fixer le num‚ro de fonction de DTA
Regs.ds = Segment                'Adresse de segment dans le registre DS
Regs.dx = Offset                   'Adresse d'offset dans le registre DX
CALL INTERRUPTX(&H21, Regs, Regs)            'Appeler l'interruption DOS

END SUB

