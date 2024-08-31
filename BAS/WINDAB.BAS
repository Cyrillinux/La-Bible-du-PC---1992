'***********************************************************************
'*                            W I N D A B . B A S                      *
'----------------------------------------------------------------------*
'* Fonction       : Confirmer si Windows est actif et dans             *
'*                 quel mode                                           *
'----------------------------------------------------------------------*
'* Auteur        : Michael TISCHER                                     *
'* D‚velopp‚ le  : 22.08.1991                                          *
'* DerniŠre MAJ. : 22.03.1992                                          *
'***********************************************************************

DECLARE FUNCTION Windows% (HVersion AS INTEGER, NVersion AS INTEGER)

'$INCLUDE: 'Qb.bi'                   'Fichier Include pour appels d'int.

CONST MULTIPLEX = &H2F                'Num‚ro d'int. de l'int. Multiplex
CONST NOWIN = &H0                                     'Windows non actif
CONST WIN386X = &H1                         'Windows/386 V2.x fonctionne
CONST WINREAL = &H81                    'Windows fonctionne en mode r‚el
CONST WINSTANDARD = &H82            'Windows fonctionne en mode standard
CONST WINENHANCED = &H83              'Windows fonctionne en mode ‚tendu

DIM WindowsActif AS INTEGER                                'Mode Windows
DIM HVer AS INTEGER                       'Version principale de Windows
DIM NVer AS INTEGER                       'Version secondaire de Windows

PRINT "ÛÛÛÛÛÛÛÛÛÛÛÛÛ WINDAB  -  (c) 1991, 92 by Michael TISCHER ÛÛÛÛ"
PRINT                                          'Ins‚rer une ligne vierge
WindowsActif = Windows(HVer, NVer)      'D‚terminer mode/version Windows
SELECT CASE WindowsActif
  CASE NOWIN
    PRINT "Windows non actif"
  CASE WIN2X
    PRINT "Windows /386 V 2.x actif"
  CASE WINREAL
    PRINT "Windows en mode r‚el"
  CASE WINSTANDARD
    PRINT "Windows actif en mode standard "
  CASE WINENHANCED
    PRINT "Windows V "; LTRIM$(STR$(HVer)); ".";
    PRINT LTRIM$(STR$(NVer)); " actif en mode Etendu"
END SELECT

'***********************************************************************
'* Windows : Confirme si Windows est actif                             *
'* Entr‚e  : HVERSION = Integer pour recevoir version principale       *
'*           NVERSION = Integer pour recevoir version secondaire       *
'* Sortie  : Statut Windows, constante parmi NOWIN, WIN386X, WINREAL,  *
'*           WINSTANDARD ou WINENAHNCED                                *
'* Info    : Le num‚ro de version ne peut ˆtre lu et retourn‚ que dans *
'*           le mode ‚tendu de Windows 3.0                             *
'***********************************************************************
'
FUNCTION Windows% (HVersion AS INTEGER, NVersion AS INTEGER)
DIM Regs AS RegTypeX                 ' Registres proc. pour appel d'int.
DIM Res AS INTEGER                       'M‚moire tampon pour la version

HVersion = 0                          'Initialise les num‚ros de version
NVersion = 0

Regs.ax = &H1600             'Nøfonc. Test d'installation du mode ‚tendu
CALL INTERRUPTX(MULTIPLEX, Regs, Regs)
Res = Regs.ax                                            'Ranger Regs.AX

SELECT CASE Res MOD 256                   'Evaluer octet de poids faible

  CASE &H1, &HFF                                     'Windows /386 actif
    HVersion = 2                                     'Version principale
    NVersion = 0                            'Version secondaire inconnue
    Windows = WIN386X

  CASE &H0, &H80            'Windows inactif ou en mode r‚el ou standard
    Regs.ax = &H4680                'Identifier le mode r‚el ou standard
    CALL INTERRUPTX(MULTIPLEX, Regs, Regs)
    IF (Regs.ax MOD 256) = &H80 THEN                    'Windows actif ?
      Windows = NOWIN                                            ' Non !
    ELSE                    'Windows fonctionne en mode r‚el ou standard
      Regs.ax = &H1605           'Simuler l'installation du DOS Extender
      Regs.bx = &H0
      Regs.si = &H0
      Regs.cx = &H0
      Regs.es = &H0
      Regs.ds = &H0
      Regs.dx = &H1
      CALL INTERRUPTX(MULTIPLEX, Regs, Regs)
      IF Regs.cx = &H0 THEN                      'Windows en mode r‚el ?
    Windows = WINREAL                                               'Oui
      ELSE                     'Non, Windows fonctionne en mode standard
    Windows = WINSTANDARD
      END IF
    END IF
  CASE ELSE    'Windows en mode ‚tendu, AX contient le num‚ro de version
    HVersion = Res AND &HF              ' LSB pour la version principale
    NVersion = Res \ 256                ' MSB pour la version secondaire
    Windows = WINENHANCED
END SELECT

END FUNCTION

