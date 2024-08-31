'***********************************************************************
'*                              FIXPARTB                               *
'*---------------------------------------------------------------------*
'*   Objet          : Afficher les partitions d'un disque dur          *
'*---------------------------------------------------------------------*
'*   Auteur                : Michael Tischer                           *
'*   Dvelopp le          : 21.05.1991                                *
'*   Dernire Modification : 12.01.1992                                *
'*---------------------------------------------------------------------*
'*   Appel          : FIXPARTB [numro de lecteur]                     *
'*                    Lecetur par dfaut : 0 ("C")                     *
'***********************************************************************
'
DECLARE SUB GetSecCyl (SecCyl AS LONG, Sect AS INTEGER, Cyl AS INTEGER)
DECLARE FUNCTION ReadPartSec% (LW%, Tete%, SecCyl%, PartEntree() AS ANY)
DECLARE SUB Showpartition (LW AS INTEGER)
DECLARE FUNCTION MLNG& (Nombre AS INTEGER)
			      
'$INCLUDE: 'QB.BI'      'Inclure fichier Include pr appels interruptions
			      
CONST TRUE = -1                                          'Dfinir "VRAI"
CONST FALSE = NOT TRUE
			      
TYPE SecPos                             'dcrit la position d'un secteur
      Tete AS INTEGER                          'tte de lecture/criture
      SecCyl AS LONG                      'Numro de Secteur et Cylindre
END TYPE
			      
TYPE PartEntry                        'Entre n de la table de partition
      Status AS INTEGER                            'Etat de la partition
      StartSec AS SecPos                                'Premier secteur
      PartType AS INTEGER                             'Type de partition
      EndSec AS SecPos                                  'Dernier secteur
      SecOfs AS LONG                           'Dcalage du Boot secteur
      NbreSec AS LONG                                'Nombre de secteurs
END TYPE
			      
DIM Lecteur AS INTEGER      'Variable de conversion des arguments passs
			      
CLS
PRINT "ÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛÛ FIXPARTB - (C)";
PRINT " 1991, 92 by Michael Tischer ÛÛÛÛÛÛ"
Lecteur = 0                               'Premier disque dur par dfaut
IF COMMAND$ <> "" THEN                        'L'autre lecteur est donn
  Lecteur = VAL(COMMAND$)                            'ASCII vers dcimal
END IF
CALL Showpartition(Lecteur)             'Affiche secteur de la partition
END

'***********************************************************************
'* GetSecCyl : renvoie les numros de secteur et de cylindre obtenus … *
'*             partir du codage utlis par le BIOS                     *
'* Entrees   : Variable de secteur en codage BIOS                      *
'* Sortie    : Variables secteur et cylindre par rfrence de variable *
'***********************************************************************
SUB GetSecCyl (SecCyl AS LONG, Sect AS INTEGER, Cyl AS INTEGER)
			      
 Sect = SecCyl AND 63                                'Masque bits 6 et 7
 Cyl = SecCyl \ 256 + ((SecCyl MOD 256) AND 192) * 4
END SUB

'***********************************************************************
'*  MLNG    : Convertit un entier en son quivalent long               *
'*  Entree  : Un entier                                                *
'*  Sortie  : Le "long" correspondant au contenu du registre           *
'***********************************************************************
FUNCTION MLNG& (Nombre AS INTEGER)

IF Nombre >= 0 THEN                             'Le bit 16 n'est pas mis
   MLNG = Nombre            'Entier correspondant au contenu du registre
ELSE                                                  'Le bit 16 est mis
   MLNG = 65536 + Nombre    'ce nombre correspond au contenu du registre
END IF

END FUNCTION

'***********************************************************************
'* ReadPartSec : Lit le secteur de partition d'un disque dur           *
'* Entrees     : LW          = Code BIOS du lecteur                    *
'*               Tete        = Numro de la tte de lecture/criture   *
'*               SecCyl      = Numro secteur et cylindre format BIOS  *
'* Sorties     : PartEntry() = Les 4 tables de part. du sect. de part. *
'***********************************************************************
'
FUNCTION ReadPartSec% (LW%, Tete%, SecCyl%, PartEntr() AS PartEntry)

DIM Register AS RegTypeX  'Registre processeur pour appel d'interruption
DIM PartSecteur AS STRING * 512          'stocke le secteur de partition
DIM IdCode AS LONG         'stocke le code d'identification de partition
DIM i AS INTEGER                        'compteur d'itrations de boucle
DIM j AS INTEGER                        'compteur d'itrations de boucle
			      
Register.ax = &H201       'N๘ de fonct. pour "READ" dans premier secteur
Register.cx = SecCyl%      'Secteur et Cylindre de la partition courante
Register.dx = Tete% * 256 + LW%                'N๘ de tte et de lecteur
Register.es = VARSEG(PartSecteur)  'adresse Seg. du secteur de partition
Register.bx = VARPTR(PartSecteur) 'adresse Offset du seteur de partition
CALL INTERRUPTX(&H13, Register, Register)    'Appel d'int. de disque dur
DEF SEG = VARSEG(PartSecteur)     'Dfinit adresse seg. instruciton PEEK
Pointer = VARPTR(PartSecteur) + &H1BD      'Ptr sur 1ere entre de part.
offset = 0                  'Dcalage de la premire entre de partition
FOR i = 1 TO 4                  'Lire les quatre entres de la partition
  PartEntr(i).Status = PEEK(Pointer + offset + 1)
  PartEntr(i).StartSec.Tete = PEEK(Pointer + offset + 2)
  PartEntr(i).StartSec.SecCyl = PEEK(Pointer + offset + 4) * 256& + PEEK(Pointer + offset + 3)
  PartEntr(i).PartType = PEEK(Pointer + offset + 5)
  PartEntr(i).EndSec.Tete = PEEK(Pointer + offset + 6)
  PartEntr(i).EndSec.SecCyl = PEEK(Pointer + offset + 8) * 256& + PEEK(Pointer + offset + 7)
  PartEntr(i).SecOfs = 0
  FOR j = 0 TO 3
     PartEntr(i).SecOfs = PartEntr(i).SecOfs * 256& + PEEK(Pointer + offset + 12 - j)
  NEXT
  PartEntr(i).NbreSec = 0
  FOR j = 0 TO 3
     PartEntr(i).NbreSec = PartEntr(i).NbreSec * 256& + PEEK(Pointer + offset + 16 - j)
  NEXT
  offset = offset + 16     'Cale Offset sur entre suivante de partition
NEXT
IdCode = PEEK(Pointer + offset + 2) * 256& + PEEK(Pointer + offset + 1)
IF (Register.flags AND 1) = 0 THEN
  ReadPartSec = TRUE
END IF

END FUNCTION

'***********************************************************************
'* ShowPartition : Affiche le partitionnement du disque dur            *
'* Entree        : Numro du disque dur demand                        *
'* Sortie        : aucune                                              *
'***********************************************************************
SUB Showpartition (LW AS INTEGER)
			      
DIM Tete AS INTEGER                       'Tete de la partition courante
DIM SecCyl AS INTEGER      'Secteur et cylindre de la partition courante
DIM Entry AS INTEGER                    'Compteur d'itrations de boucle
DIM Sect AS INTEGER                                   'Numro de secteur
DIM Cyl AS INTEGER                       'Numro de cylindre de l'entre
DIM PartEntree(4) AS PartEntry                 'courante de la partition
DIM Register AS RegTypeX    'Registre processeur pour appel interception
			      
PRINT ;
LW = LW + &H80                'Prpare le numro du lecteur pour le BIOS
IF ReadPartSec(LW, 0, 1, PartEntree()) THEN 'Lit le secteur de partition
  Register.ax = &H800        'AH = n๘ fonction, demande identif. lecteur
  Register.dx = LW                                           'N๘ lecteur
  CALL INTERRUPTX(&H13, Register, Register)     'Appelle int. disque dur
  CALL GetSecCyl(MLNG(Register.cx), Sect, Cyl)   'N๘ secteur et cylindre
  PRINT "ษอออออออออออออออออออออออออออออออออออออออออออ";
  PRINT "อออออออออออออออออออออออออออออออออออป"
  PRINT USING "บ Lecteur # : ## ttes avec "; LW - &H80; Register.dx \ 256 + 1;
  PRINT USING " chacune #### cylindres de "; Cyl;
  PRINT USING "### secteurs            บ"; Sect
  PRINT "บ Table de partitions dans secteur de partition     ";
  PRINT "                           บ"
  PRINT "ฬออัออออัออออออออออออออออออออัออออออออออออออั";
  PRINT "ออออออออออออออัอออออออออัอออออออออน"
  PRINT "บ  ณ    ณ                    ณ    Dbut     ณ";
  PRINT "     Fin      ณDistance ณ         บ"
  PRINT "บN๘ณBootณ Type               ณTte ";
  PRINT "Cyl. Sec.ณTete Cyl. Sec.ณBootSect.ณ  Nombre บ"
  PRINT "ฬออุออออุออออออออออออออออออออุออออออออออออออุ";
  PRINT "ออออออออออออออุอออออออออุอออออออออน"
  FOR Entry = 1 TO 4                               'Les entres dfilent
    PRINT USING "บ##ณ"; Entry;
    IF PartEntree(Entry).Status = &H80 THEN
      PRINT "Oui ณ";
    ELSE
      PRINT "Non ณ";
    END IF
    SELECT CASE PartEntree(Entry).PartType
       CASE 0
    PRINT "libre               ";
       CASE 1
    PRINT "DOS, 12-Bit-FAT     ";
       CASE 2 OR 3
    PRINT "Xenix               ";
       CASE 4
    PRINT "DOS, 16-Bit-FAT     ";
       CASE 5
    PRINT "DOS, extended Part. ";
       CASE 6
    PRINT "DOS 4.0 > 32 MB     ";
       CASE &HDB
    PRINT "concurrent DOS,     ";
       CASE ELSE
    PRINT USING "inconnu      (###)  "; PartEntree(Entry).PartType
     END SELECT
     CALL GetSecCyl(PartEntree(Entry).StartSec.SecCyl, Sect, Cyl)
     PRINT USING "ณ###  ###  "; PartEntree(Entry).StartSec.Tete; Cyl;
     PRINT USING "### ณ"; Sect;
     CALL GetSecCyl(PartEntree(Entry).EndSec.SecCyl, Sect, Cyl)
     PRINT USING "###  ###  ### ณ"; PartEntree(Entry).EndSec.Tete; Cyl; Sect;
			      
     PRINT USING " ####### ณ"; PartEntree(Entry).SecOfs;
     PRINT USING " ####### บ"; PartEntree(Entry).NbreSec
   NEXT
   PRINT "ศออฯออออฯออออออออออออออออออออฯออออออออออออ";
   PRINT "ออฯออออออออออออออฯอออออออออฯอออออออออผ"
ELSE
  PRINT "Erreur d'accs au secteur de boot"
END IF

END SUB

