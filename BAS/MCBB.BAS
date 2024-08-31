'***********************************************************************
'*                              M C B B . B A S                        *
'----------------------------------------------------------------------*
'*   Fonction       : Permet de suivre le chaånage des blocs de        *
'*                    mÇmoire allouÇs par DOS                          *
'----------------------------------------------------------------------*
'*   Auteur         : Michael TISCHER                                  *
'*   DÇveloppÇ le   : 16.05.1991                                       *
'*   Derniäre MAJ   : 20.10.1991                                       *
'***********************************************************************

DECLARE SUB TraceMCB ()
DECLARE SUB FirstMCB (Adr AS ANY)
DECLARE SUB Dump (Adr AS ANY, Nbre%)
DECLARE FUNCTION HexByte$ (HByte%)
DECLARE FUNCTION GetDosVer% ()
DECLARE FUNCTION GetWord& (SegAdr AS LONG, OfsAdr AS LONG)
DECLARE FUNCTION Hexstring$ (HexVal&)

'$INCLUDE: 'qb.bi'                      'Intägre un  fichier d'inclusion

CONST TRUE = -1                          'DÇfinit des valeurs boolÇennes
CONST FALSE = NOT TRUE

TYPE AdrType                                       'Pointeur sur adresse
   OfsAdr AS LONG                                                'Offset
   SegAdr AS LONG                                               'Segment
END TYPE

CLS                                                      'Efface l'Çcran
PRINT "MCBB  -  (c) 1988, 92 by Michael Tischer": PRINT : PRINT
CALL TraceMCB                                'Parcourt la chaåne des MCB
END

'***********************************************************************
'* DUMP   : Affiche le dump hexadÇcimale et ASCII d'une zone de mÇmoire*
'* EntrÇe : SegAdr = Segment de la zone Ö soumettre au dump            *
'*          Nbre   = Nombre de lignes de 16 octets Ö afficher          *
'* Sortie : nÇant                                                      *
'***********************************************************************
'
SUB Dump (SegAdr AS LONG, Nbre AS INTEGER)

DIM HexStr AS STRING * 2       'mÇmorise un nombre hexa Ö deux positions
DIM Offset AS LONG                          'Offset dans zone de mÇmoire

HexStr = "zz"                                       'CrÇe la chaåne hexa
PRINT
PRINT "DUMP ≥ 0123456789ABCDEF       00 01 02 03 ";
PRINT "04 05 06 07 08 09 0A 0B 0C 0D 0E 0F"
PRINT "ƒƒƒƒƒ≈ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ";
PRINT "ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ"
Offset = 0                                'Commence par le premier octet
DEF SEG = SegAdr                                     'dÇfinir le segment
WHILE Nbre > 0                             'Parcourt la boucle Nbre fois
  PRINT Hexstring$(Offset); " ≥ ";
  FOR z = 0 TO 15                            'Traite 16 octets Ö la fois
    IF PEEK(Offset + z) >= 32 THEN          'Caractäre ASCII ordinaire ?
       PRINT CHR$(PEEK(Offset + z));                  'Oui ,on l'affiche
    ELSE
       PRINT " ";                             'Non, on affiche un espace
    END IF
  NEXT
  PRINT "       ";                  'Place le curseur sur la partie hexa
  FOR z = 0 TO 15                        'Traite 16 caractäres Ö la fois
    PRINT HexByte$(PEEK(Offset + z)); " ";           'Aff. octet en hexa
  NEXT
  PRINT                                                      'A la ligne
  Offset = Offset + 16                        'Offset sur ligne suivante
  Nbre = Nbre - 1              'DÇcrÇmente le nombre de lignes restantes
WEND
PRINT
END SUB

'***********************************************************************
'*  FirstMCB : Renvoie un pointeur sur le premier MCB                  *
'*  EntrÇe  : nÇant                                                    *
'*  Sortie  : Pointeur sur le premier MCB dans la variable MCBAdr      *
'***********************************************************************
'
SUB FirstMCB (MCBAdr AS AdrType)

DIM Register AS RegTypeX         'Registres pour gÇrer les interruptions

Register.ax = &H52 * 256     'Fonction: "Lire l'adresse du DOS-Info-Bloc
CALL INTERRUPTX(&H21, Register, Register)                     ' int. DOS
'-- (ES:BX-&H4)=ES-1:12 donne l'adresse du ptr sur le premier  MCB -----
DEF SEG = Register.es - 1                            'dÇfinit le segment
MCBAdr.OfsAdr = PEEK(Register.bx + 13) * 256& + PEEK(Register.bx + 12)
MCBAdr.SegAdr = PEEK(Register.bx + 15) * 256& + PEEK(Register.bx + 14)
END SUB

'***********************************************************************
'*  GetDosVer : DÇtermine la version de DOS                            *
'*  EntrÇe   : nÇant                                                   *
'*  Sortie   : numÇro de version (30 pour DOS 3.0, 33 pour DOS 3.3 etc)*
'***********************************************************************
'
FUNCTION GetDosVer%

DIM Register AS RegType             'Registres pour gÇrer l'interruption

Register.ax = &H30 * 256       'AH = N¯ de fonc "dÇterminer version DOS"
CALL INTERRUPT(&H21, Register, Register)                      'int. &H21
GetDosVer = INT(Register.ax \ 256) + (Register.ax MOD 256) * 10
END FUNCTION

'***********************************************************************
'* Getword : Lit un mot dans une adr. mÇmoire sous forme d'entier long *
'* EntrÇe  : SegAdr = Segment du mot                                   *
'*           OfsAdr = Offset du mot                                    *
'* Sortie  : Contenu du mot sous forme d'entier long                   *
'***********************************************************************
'
FUNCTION GetWord& (SegAdr AS LONG, OfsAdr AS LONG)

DEF SEG = SegAdr                                        'Fixe le segment
GetWord& = PEEK(OfsAdr + 1) * 256& + PEEK(OfsAdr)        'Lit la mÇmoire
END FUNCTION

'***********************************************************************
'* Hexbyte : Convertit un octet en chaåne de caractäres hexadÇcimale   *
'* EntrÇe  : Hbyte = l'octet Ö convertir                               *
'* Sortie  : Chaåne de caractäres obtenue                              *
'* Info    : La fonction QBASIC appelÇe HEX$ ne retourne pas toujours  *
'*           des chaånes de deux caractäres comme on le souhaite ici   *
'***********************************************************************
'
FUNCTION HexByte$ (HByte AS INTEGER)

DIM HexSt AS STRING * 2                         'mÇmorise la chaåne hexa

MID$(HexSt, 1, 1) = HEX$(HByte \ 16)                    'Premier chiffre
MID$(HexSt, 2, 1) = HEX$(HByte MOD 16)                 'Deuxiäme chiffre
HexByte$ = HexSt                                  ' Transmet le rÇsultat
END FUNCTION

'***********************************************************************
'* HexString : Convertit un entier long en chaåne de car. hexa.        *
'* EntrÇe    : Valeur Ö convertir                                      *
'* Sortie    : Chaåne hexa obtenue                                     *
'* Info      : La fonction de QBASIC appelÇe HEX$ ne fournit pas       *
'*             toujours des chaånes de quatre position comme           *
'*             on le souhaite ici                                      *
'***********************************************************************
'
FUNCTION Hexstring$ (HexValVar AS LONG)

DIM Nibble AS INTEGER                        'Quartet infÇrieur d'un mot
DIM HexVal AS LONG            ' Il faut mÇmoriser l'argument car Q-Basic
					 'ne travaille pas par rÇfÇrence
DIM HStr AS STRING * 4                            'Chaåne hexa convertie

HexVal = HexValVar                ' MÇmorise l'argument pour le modifier
HStr = "xxxx"                                            'CrÇe la chaåne
FOR compteur = 0 TO 3                           'Parcourt les 4 chiffres
   Nibble = HexVal AND &HF           'Ne garde que les 4 bits infÇrieurs
   MID$(HStr, 4 - compteur, 1) = HEX$(Nibble)     'Conv. quartet en hexa
   HexVal = HexVal \ 16     'DÇcale HexVal de 4 positions vers la droite
NEXT
Hexstring$ = HStr                            'Transmet la chaåne trouvÇe
END FUNCTION

'***********************************************************************
'* TraceMCB : suit la liste des blocs MCB                              *
'* EntrÇe  : nÇant                                                     *
'* Sortie  : nÇant                                                     *
'***********************************************************************
'
SUB TraceMCB

CONST kom = "COMSPEC="               '"COMSPEC=" dÇclarÇ comme constante

DIM ActMCB  AS AdrType                                 'Pointeur sur MCB
DIM ID      AS STRING * 1     '"M" il existe un bloc suivant , "Z" = Fin
DIM PSP     AS LONG                              'Segment du PSP associÇ
DIM Distance AS LONG                         ' Nombre de paragraphes - 1
DIM MemPtr  AS LONG                                'Pointeur sur mÇmoire
DIM NrMCB   AS INTEGER                            'NumÇro du MCB courant
DIM z       AS INTEGER                               'Compteur de boucle
DIM Fin    AS INTEGER                                 'Condition d'arràt
DIM ActOfs  AS LONG

DosVer = GetDosVer                          'DÇtermine la version de DOS
NrMCB = 1                                   'Commence par le premier MCB
Fin = FALSE
CALL FirstMCB(ActMCB)                'Lit le pointeur sur le premier MCB
DO
  ActOfs = ActMCB.OfsAdr                                'Charge l'offset
  DEF SEG = ActMCB.SegAdr                   'Fixe le segment pour Peek()
  ID = CHR$(PEEK(ActOfs))                            'Lit le premier MCB
  PSP = GetWord&(ActMCB.SegAdr, ActOfs + &H1)
  Distance = GetWord&(ActMCB.SegAdr, ActOfs + &H3)

  IF ID = "Z" THEN                                       'Dernier MCB  ?
    Fin = TRUE                                    'Interrompre la boucle
  END IF
  PRINT "NumÇro du MCB    ="; NrMCB
  PRINT "Adresse du MCB   = "; Hexstring$(ActMCB.SegAdr); ":";
  PRINT Hexstring$(ActOfs)
  PRINT "Adresse mÇmoire  = "; Hexstring$(ActMCB.SegAdr + 1); ":";
  PRINT Hexstring$(ActOfs)
  PRINT "ID               = "; ID
  PRINT "Adresse du PSP   = "; Hexstring$(PSP); ":0000"
  PRINT "Taille           = "; Hexstring$(Distance); " paragraphes ( ";
  PRINT Distance * 16; " octets)"
  PRINT "Contenu          = ";

       '---- Est-ce un environnement  ? --------------------------------
  z = 0                                         'Commence la comparaison
  MemPtr = ActMCB.SegAdr + 1                       'Pointeur sur mÇmoire
  DEF SEG = MemPtr                          'Fixe le segment pour Peek()
  WHILE (z <= 7) AND MID$(kom, z + 1, 1) = CHR$(PEEK(ActMCB.OfsAdr + z))
    z = z + 1                                         'Caractäre suivant
  WEND
  IF z > 7 THEN                         'On a trouvÇ la chaåne COMSPEC =
    PRINT "Environnement "
    IF DosVer > 30 THEN              'Version 3.0 de DOS ou ultÇrieure ?
      PRINT "Nom du progr.    = ";       'Oui, donne le nom du programme
      z = 0                          'en commenáant par le premier octet
      DO
    z = z + 1                                       'Cherche chaåne vide
      LOOP UNTIL PEEK(ActOfs + z) = 0 AND PEEK(ActOfs + z + 1) = 0
      IF PEEK(ActOfs + z + 2) = 1 AND PEEK(ActOfs + z + 3) = 0 THEN
	  '--- Nom du programme dÇcouvert ------------------------------
    z = z + 4                            'z sur premier caractäre du nom
    DO                                     'Parcourt le nom du programme
      PRINT CHR$(PEEK(ActOfs + z));                'Affiche un caractäre
      z = z + 1                                       'Caractäre suivant
    LOOP UNTIL PEEK(ActOfs + z) = 0         'Jusqu'Ö la fin de la chaåne
    PRINT
      ELSE                                               'Rien de trouvÇ
    PRINT "inconnu"
      END IF
    END IF

   '---- Affiche les chaånes de l'environnement ------------------------

    PRINT "Chaånes de l                                  'environnement"
    z = 0              'Commence par le premier octet de la zone allouÇe
    WHILE PEEK(ActOfs + z) <> 0             'RÇpäte jusuqu'Ö Chaåne vide
      PRINT "      ";                                        'A la ligne
      DO                                             'Affiche une chaåne
    PRINT CHR$(PEEK(ActOfs + z));                  'Affiche un caractäre
    z = z + 1                                         'Caractäre suivant
      LOOP UNTIL PEEK(ActOfs + z) = 0             'Jusqu'Ö fin de chaåne
      z = z + 1                                         'Chaåne suivante
      PRINT                                            'termine la ligne
    WEND
  ELSE
  '---- S'agit-il d'un PSP ?    ----------------------------------------
  '---- (Introduit par la commande (INT 20) (Code &HCD &H20) )----------

    MemPtr = ActMCB.SegAdr + 1                     'Pointeur sur mÇmoire
    IF PEEK(ActOfs) = &HCD AND PEEK(ActOfs + 1) = &H20 THEN
      PRINT "PSP (suivi d'un programme)"              'C'est bien un PSP
    ELSE                    'La commande INT 20 n'a pas pu àtre dÇtectÇe
      PRINT "Programme non identifiable "
      CALL Dump(MemPtr, 5)    'Effectue un dump des 5*16 premiers octets
    END IF
  END IF

  PRINT "‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹ Appuyez sur une touche";
  PRINT " ‹‹‹‹‹‹‹‹‹‹"
  DO                                        'Attend une frappe de touche
  a$ = INKEY$
  LOOP UNTIL a$ <> ""
  IF NOT Fin THEN                                       'Il reste un MCB
    ActMCB.SegAdr = ActMCB.SegAdr + Distance + 1    'Ptr sur MCB suivant
    NrMCB = NrMCB + 1
  END IF
LOOP UNTIL Fin  'RÇpäte l'opÇration jusqu'Ö ce qu'il n'y ait plus de MCB
END SUB

