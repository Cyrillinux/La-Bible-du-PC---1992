'***********************************************************************
'*                          C E T E N D B                              *
'*---------------------------------------------------------------------*
'*  Montre comment lire les touches additionnelles d'un clavier ‚tendu *
'*---------------------------------------------------------------------*
'* Auteur                : MICHAEL TISCHER                             *
'* D‚velopp‚ le          : 01.01.1992                                  *
'* DerniŠre modification : 01.01.1992                                  *
'***********************************************************************
'
'$INCLUDE: 'QB.BI'      'Fichier contenant les d‚clarations de registres
																									    
DECLARE FUNCTION MakeWord! (Nombre AS INTEGER)
DECLARE FUNCTION HexByte$ (valeur AS INTEGER)
DECLARE FUNCTION GetCEKey% ()
DECLARE FUNCTION TestCE% ()

CONST TRUE = -1                    'D‚finition des constantes bool‚ennes
CONST FALSE = NOT TRUE

'-- Programme principal ------------------------------------------------

DIM touche AS INTEGER
DIM ENTREE AS STRING

CLS
ENTREE = CHR$(13)
PRINT "CLETENDB  -  (c) 1992 by Michael Tischer"; ENTREE
IF TestCE THEN
  PRINT "Les extensions du BIOS pour claviers ‚tendu";
  PRINT " ont ‚t‚ d‚cel‚es! " + ENTREE + ENTREE
  PRINT "Actionnez les touches ou les combinaisons de"
  PRINT "touches dont vous voulez connaŒtre les codes." + ENTREE
  PRINT "Pour sortir du programme, tapez <Esc> " + ENTREE

  DO                                                   'Boucle de saisie
    touche = GetCEKey                                     'Lit la touche
    PRINT "Scan : "; HexByte(MakeWord(touche) / 256); "  ";
    PRINT "ASCII: "; HexByte(touche AND 255);
    IF ((touche AND 255) = &HE0) AND ((touche / 256) <> 0) THEN
      PRINT "  <----Touche ‚tendue"
    ELSE
      PRINT
    END IF
  LOOP UNTIL (touche = &H11B)                    ' R‚pŠte jusqu'… ESCAPE
  PRINT ENTREE
ELSE
  PRINT "Il n'y a pas d'extension du BIOS pour clavier ‚tendue !"
END IF
END

'***********************************************************************
'* GetCEKey  : Lit une touche avec la fonction ‚tendue &h10            *
'* Entr‚e : n‚ant                                                      *
'* Sortie : code de la touche frapp‚e                                  *
'***********************************************************************
'
FUNCTION GetCEKey%

DIM reg AS RegType          'Registres du processeur pour l'interruption
reg.ax = &H1000         'Fonction de lecture ‚tendue pour clavier ‚tendu
CALL INTERRUPT(&H16, reg, reg)         'D‚clenche l'interruption du BIOS
GetCEKey% = reg.ax                        'Retourne le code de la touche

END FUNCTION

'***********************************************************************
'* HexByte : Convertit un octet en nombre hexad‚cimal … deux chiffres  *
'* Entr‚e : VALEUR = octet … convertir                                 *
'* Sortie : nombre hexad‚cimal sous forme de chaŒne                    *
'***********************************************************************
'
FUNCTION HexByte$ (valeur AS INTEGER)

IF valeur < 16 THEN                                   'un seul chiffre ?
  HexByte$ = "0" + HEX$(valeur)          'Oui, un 0 en premiŠre position
ELSE                                            'Non, on a deux chiffres
  HexByte$ = HEX$(valeur)
END IF

END FUNCTION

'***********************************************************************
'* Makeword : convertit un nombre entier en entier long                *
'*            En basic, les d‚calages de bits qui r‚alisent les        *
'*            divisions entiŠres donnent des r‚sultats erron‚s pour    *
'*            les nombres n‚gatifs                                     *
'* Entr‚e   : nombre entier … convertir                                *
'* Sortie   : nombre entier long                                       *
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
'* TestCE : Teste si les fonctions ‚tendues du BIOS                    *
'* pour lire un clavier ‚tendu sont disponibles                        *
'* Entr‚e : n‚ant                                                      *
'* Sortie : TRUE, si les fonctions sont disponibles , sinon FALSE      *
'***********************************************************************
'
FUNCTION TestCE%

DIM reg AS RegType          'Registres du processeur pour l'interruption

reg.ax = &H1200             'Fonction d'‚tat ‚tendue pour clavier ‚tendu
CALL INTERRUPT(&H16, reg, reg)         'D‚clenche l'interruption du BIOS
TestCE% = (reg.ax <> &H1200)             'AX = &h1200 : Fonction absente

END FUNCTION

