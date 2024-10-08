'***********************************************************************
'*                              M C B B . B A S                        *
'----------------------------------------------------------------------*
'*   Fonction       : Permet de suivre le cha�nage des blocs de        *
'*                    m�moire allou�s par DOS                          *
'----------------------------------------------------------------------*
'*   Auteur         : Michael TISCHER                                  *
'*   D�velopp� le   : 16.05.1991                                       *
'*   Derni�re MAJ   : 20.10.1991                                       *
'***********************************************************************

DECLARE SUB TraceMCB ()
DECLARE SUB FirstMCB (Adr AS ANY)
DECLARE SUB Dump (Adr AS ANY, Nbre%)
DECLARE FUNCTION HexByte$ (HByte%)
DECLARE FUNCTION GetDosVer% ()
DECLARE FUNCTION GetWord& (SegAdr AS LONG, OfsAdr AS LONG)
DECLARE FUNCTION Hexstring$ (HexVal&)

'$INCLUDE: 'qb.bi'                      'Int�gre un  fichier d'inclusion

CONST TRUE = -1                          'D�finit des valeurs bool�ennes
CONST FALSE = NOT TRUE

TYPE AdrType                                       'Pointeur sur adresse
   OfsAdr AS LONG                                                'Offset
   SegAdr AS LONG                                               'Segment
END TYPE

CLS                                                      'Efface l'�cran
PRINT "MCBB  -  (c) 1988, 92 by Michael Tischer": PRINT : PRINT
CALL TraceMCB                                'Parcourt la cha�ne des MCB
END

'***********************************************************************
'* DUMP   : Affiche le dump hexad�cimale et ASCII d'une zone de m�moire*
'* Entr�e : SegAdr = Segment de la zone � soumettre au dump            *
'*          Nbre   = Nombre de lignes de 16 octets � afficher          *
'* Sortie : n�ant                                                      *
'***********************************************************************
'
SUB Dump (SegAdr AS LONG, Nbre AS INTEGER)

DIM HexStr AS STRING * 2       'm�morise un nombre hexa � deux positions
DIM Offset AS LONG                          'Offset dans zone de m�moire

HexStr = "zz"                                       'Cr�e la cha�ne hexa
PRINT
PRINT "DUMP � 0123456789ABCDEF       00 01 02 03 ";
PRINT "04 05 06 07 08 09 0A 0B 0C 0D 0E 0F"
PRINT "������������������������������������������";
PRINT "�����������������������������������"
Offset = 0                                'Commence par le premier octet
DEF SEG = SegAdr                                     'd�finir le segment
WHILE Nbre > 0                             'Parcourt la boucle Nbre fois
  PRINT Hexstring$(Offset); " � ";
  FOR z = 0 TO 15                            'Traite 16 octets � la fois
    IF PEEK(Offset + z) >= 32 THEN          'Caract�re ASCII ordinaire ?
       PRINT CHR$(PEEK(Offset + z));                  'Oui ,on l'affiche
    ELSE
       PRINT " ";                             'Non, on affiche un espace
    END IF
  NEXT
  PRINT "       ";                  'Place le curseur sur la partie hexa
  FOR z = 0 TO 15                        'Traite 16 caract�res � la fois
    PRINT HexByte$(PEEK(Offset + z)); " ";           'Aff. octet en hexa
  NEXT
  PRINT                                                      'A la ligne
  Offset = Offset + 16                        'Offset sur ligne suivante
  Nbre = Nbre - 1              'D�cr�mente le nombre de lignes restantes
WEND
PRINT
END SUB

'***********************************************************************
'*  FirstMCB : Renvoie un pointeur sur le premier MCB                  *
'*  Entr�e  : n�ant                                                    *
'*  Sortie  : Pointeur sur le premier MCB dans la variable MCBAdr      *
'***********************************************************************
'
SUB FirstMCB (MCBAdr AS AdrType)

DIM Register AS RegTypeX         'Registres pour g�rer les interruptions

Register.ax = &H52 * 256     'Fonction: "Lire l'adresse du DOS-Info-Bloc
CALL INTERRUPTX(&H21, Register, Register)                     ' int. DOS
'-- (ES:BX-&H4)=ES-1:12 donne l'adresse du ptr sur le premier  MCB -----
DEF SEG = Register.es - 1                            'd�finit le segment
MCBAdr.OfsAdr = PEEK(Register.bx + 13) * 256& + PEEK(Register.bx + 12)
MCBAdr.SegAdr = PEEK(Register.bx + 15) * 256& + PEEK(Register.bx + 14)
END SUB

'***********************************************************************
'*  GetDosVer : D�termine la version de DOS                            *
'*  Entr�e   : n�ant                                                   *
'*  Sortie   : num�ro de version (30 pour DOS 3.0, 33 pour DOS 3.3 etc)*
'***********************************************************************
'
FUNCTION GetDosVer%

DIM Register AS RegType             'Registres pour g�rer l'interruption

Register.ax = &H30 * 256       'AH = N� de fonc "d�terminer version DOS"
CALL INTERRUPT(&H21, Register, Register)                      'int. &H21
GetDosVer = INT(Register.ax \ 256) + (Register.ax MOD 256) * 10
END FUNCTION

'***********************************************************************
'* Getword : Lit un mot dans une adr. m�moire sous forme d'entier long *
'* Entr�e  : SegAdr = Segment du mot                                   *
'*           OfsAdr = Offset du mot                                    *
'* Sortie  : Contenu du mot sous forme d'entier long                   *
'***********************************************************************
'
FUNCTION GetWord& (SegAdr AS LONG, OfsAdr AS LONG)

DEF SEG = SegAdr                                        'Fixe le segment
GetWord& = PEEK(OfsAdr + 1) * 256& + PEEK(OfsAdr)        'Lit la m�moire
END FUNCTION

'***********************************************************************
'* Hexbyte : Convertit un octet en cha�ne de caract�res hexad�cimale   *
'* Entr�e  : Hbyte = l'octet � convertir                               *
'* Sortie  : Cha�ne de caract�res obtenue                              *
'* Info    : La fonction QBASIC appel�e HEX$ ne retourne pas toujours  *
'*           des cha�nes de deux caract�res comme on le souhaite ici   *
'***********************************************************************
'
FUNCTION HexByte$ (HByte AS INTEGER)

DIM HexSt AS STRING * 2                         'm�morise la cha�ne hexa

MID$(HexSt, 1, 1) = HEX$(HByte \ 16)                    'Premier chiffre
MID$(HexSt, 2, 1) = HEX$(HByte MOD 16)                 'Deuxi�me chiffre
HexByte$ = HexSt                                  ' Transmet le r�sultat
END FUNCTION

'***********************************************************************
'* HexString : Convertit un entier long en cha�ne de car. hexa.        *
'* Entr�e    : Valeur � convertir                                      *
'* Sortie    : Cha�ne hexa obtenue                                     *
'* Info      : La fonction de QBASIC appel�e HEX$ ne fournit pas       *
'*             toujours des cha�nes de quatre position comme           *
'*             on le souhaite ici                                      *
'***********************************************************************
'
FUNCTION Hexstring$ (HexValVar AS LONG)

DIM Nibble AS INTEGER                        'Quartet inf�rieur d'un mot
DIM HexVal AS LONG            ' Il faut m�moriser l'argument car Q-Basic
					 'ne travaille pas par r�f�rence
DIM HStr AS STRING * 4                            'Cha�ne hexa convertie

HexVal = HexValVar                ' M�morise l'argument pour le modifier
HStr = "xxxx"                                            'Cr�e la cha�ne
FOR compteur = 0 TO 3                           'Parcourt les 4 chiffres
   Nibble = HexVal AND &HF           'Ne garde que les 4 bits inf�rieurs
   MID$(HStr, 4 - compteur, 1) = HEX$(Nibble)     'Conv. quartet en hexa
   HexVal = HexVal \ 16     'D�cale HexVal de 4 positions vers la droite
NEXT
Hexstring$ = HStr                            'Transmet la cha�ne trouv�e
END FUNCTION

'***********************************************************************
'* TraceMCB : suit la liste des blocs MCB                              *
'* Entr�e  : n�ant                                                     *
'* Sortie  : n�ant                                                     *
'***********************************************************************
'
SUB TraceMCB

CONST kom = "COMSPEC="               '"COMSPEC=" d�clar� comme constante

DIM ActMCB  AS AdrType                                 'Pointeur sur MCB
DIM ID      AS STRING * 1     '"M" il existe un bloc suivant , "Z" = Fin
DIM PSP     AS LONG                              'Segment du PSP associ�
DIM Distance AS LONG                         ' Nombre de paragraphes - 1
DIM MemPtr  AS LONG                                'Pointeur sur m�moire
DIM NrMCB   AS INTEGER                            'Num�ro du MCB courant
DIM z       AS INTEGER                               'Compteur de boucle
DIM Fin    AS INTEGER                                 'Condition d'arr�t
DIM ActOfs  AS LONG

DosVer = GetDosVer                          'D�termine la version de DOS
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
  PRINT "Num�ro du MCB    ="; NrMCB
  PRINT "Adresse du MCB   = "; Hexstring$(ActMCB.SegAdr); ":";
  PRINT Hexstring$(ActOfs)
  PRINT "Adresse m�moire  = "; Hexstring$(ActMCB.SegAdr + 1); ":";
  PRINT Hexstring$(ActOfs)
  PRINT "ID               = "; ID
  PRINT "Adresse du PSP   = "; Hexstring$(PSP); ":0000"
  PRINT "Taille           = "; Hexstring$(Distance); " paragraphes ( ";
  PRINT Distance * 16; " octets)"
  PRINT "Contenu          = ";

       '---- Est-ce un environnement  ? --------------------------------
  z = 0                                         'Commence la comparaison
  MemPtr = ActMCB.SegAdr + 1                       'Pointeur sur m�moire
  DEF SEG = MemPtr                          'Fixe le segment pour Peek()
  WHILE (z <= 7) AND MID$(kom, z + 1, 1) = CHR$(PEEK(ActMCB.OfsAdr + z))
    z = z + 1                                         'Caract�re suivant
  WEND
  IF z > 7 THEN                         'On a trouv� la cha�ne COMSPEC =
    PRINT "Environnement "
    IF DosVer > 30 THEN              'Version 3.0 de DOS ou ult�rieure ?
      PRINT "Nom du progr.    = ";       'Oui, donne le nom du programme
      z = 0                          'en commen�ant par le premier octet
      DO
    z = z + 1                                       'Cherche cha�ne vide
      LOOP UNTIL PEEK(ActOfs + z) = 0 AND PEEK(ActOfs + z + 1) = 0
      IF PEEK(ActOfs + z + 2) = 1 AND PEEK(ActOfs + z + 3) = 0 THEN
	  '--- Nom du programme d�couvert ------------------------------
    z = z + 4                            'z sur premier caract�re du nom
    DO                                     'Parcourt le nom du programme
      PRINT CHR$(PEEK(ActOfs + z));                'Affiche un caract�re
      z = z + 1                                       'Caract�re suivant
    LOOP UNTIL PEEK(ActOfs + z) = 0         'Jusqu'� la fin de la cha�ne
    PRINT
      ELSE                                               'Rien de trouv�
    PRINT "inconnu"
      END IF
    END IF

   '---- Affiche les cha�nes de l'environnement ------------------------

    PRINT "Cha�nes de l                                  'environnement"
    z = 0              'Commence par le premier octet de la zone allou�e
    WHILE PEEK(ActOfs + z) <> 0             'R�p�te jusuqu'� Cha�ne vide
      PRINT "      ";                                        'A la ligne
      DO                                             'Affiche une cha�ne
    PRINT CHR$(PEEK(ActOfs + z));                  'Affiche un caract�re
    z = z + 1                                         'Caract�re suivant
      LOOP UNTIL PEEK(ActOfs + z) = 0             'Jusqu'� fin de cha�ne
      z = z + 1                                         'Cha�ne suivante
      PRINT                                            'termine la ligne
    WEND
  ELSE
  '---- S'agit-il d'un PSP ?    ----------------------------------------
  '---- (Introduit par la commande (INT 20) (Code &HCD &H20) )----------

    MemPtr = ActMCB.SegAdr + 1                     'Pointeur sur m�moire
    IF PEEK(ActOfs) = &HCD AND PEEK(ActOfs + 1) = &H20 THEN
      PRINT "PSP (suivi d'un programme)"              'C'est bien un PSP
    ELSE                    'La commande INT 20 n'a pas pu �tre d�tect�e
      PRINT "Programme non identifiable "
      CALL Dump(MemPtr, 5)    'Effectue un dump des 5*16 premiers octets
    END IF
  END IF

  PRINT "������������������������������������ Appuyez sur une touche";
  PRINT " ����������"
  DO                                        'Attend une frappe de touche
  a$ = INKEY$
  LOOP UNTIL a$ <> ""
  IF NOT Fin THEN                                       'Il reste un MCB
    ActMCB.SegAdr = ActMCB.SegAdr + Distance + 1    'Ptr sur MCB suivant
    NrMCB = NrMCB + 1
  END IF
LOOP UNTIL Fin  'R�p�te l'op�ration jusqu'� ce qu'il n'y ait plus de MCB
END SUB

