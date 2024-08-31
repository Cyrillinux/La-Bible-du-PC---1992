'**********************************************************************'
'*                             J O Y S T B                            *'
'*--------------------------------------------------------------------*'
'*   Fonction        : D‚montre l'utilisation des Joysticks           *'
'*                     … l'aide du BIOS                               *'
'*  Auteur           : MICHAEL TISCHER                                *'
'*  D‚velopp‚ le     : 25.02.1991                                     *'
'*  DerniŠre modif   : 26.02.1991                                     *'
'**********************************************************************'
DECLARE SUB GetJoyButton (j1b1%, j1b2%, j2b1%, j2b2%)
DECLARE SUB GetJoyPos (js1 AS ANY, js2 AS ANY)

REM $INCLUDE: 'qb.bi'

'--D‚claration de type --

TYPE JSPOS 'D‚crit la position d'un Joystick
  x AS INTEGER
  y AS INTEGER
END TYPE

DIM jsp(1 TO 2) AS JSPOS                  'Position actuelle du Joystick
DIM maxx AS INTEGER, maxy AS INTEGER      'Position maximale du Joystick
DIM minx AS INTEGER, miny AS INTEGER      'Position minimale du Joystick
DIM xold AS INTEGER, yold AS INTEGER        'Position ancienne … l'‚cran
DIM actstick AS INTEGER                       'Activer Joystick (1 ou 2)
DIM xfacteur AS SINGLE, yfacteur AS SINGLE   'facteurs de conversion X/Y
DIM j1but(1 TO 2) AS INTEGER                'Bouton 1 du Joystick 1 et 2
DIM j2but(1 TO 2) AS INTEGER                'Bouton 2 du Joystick 1 et 2

CLS
PRINT "Veuillez placer le joystick dans le coin sup‚rieur droit "
PRINT "et appuyez sur l'un des deux boutons."

DO                           'Attendre l'appui sur le bouton du Joystick
  CALL GetJoyButton(j1but(1), j2but(1), j1but(2), j2but(2))
LOOP WHILE (j1but(1) OR j2but(1) OR j1but(2) OR j2but(2)) = 0

IF j1but(1) OR j2but(1) <> 0 THEN                 'S‚lectionner Joystick
  actstick = 1
ELSE
  actstick = 2
END IF

CALL GetJoyPos(jsp(1), jsp(2))                            'Lire Position
maxx = jsp(actstick).x 'Position maximale
miny = jsp(actstick).y

DO                             'Attendre … nouveau l'appui sur un bouton
  CALL GetJoyButton(j1but(1), j2but(1), j1but(2), j2but(2))
LOOP UNTIL (j1but(actstick) = 0) AND (j2but(actstick) = 0)

'--Lire maintenant la position minimale ---

PRINT : PRINT
PRINT "Placez le Joystick dans le coin inf‚rieur gauche"
PRINT "et appuyez sur un bouton."

DO
  CALL GetJoyButton(j1but(1), j2but(1), j1but(2), j2but(2))
LOOP WHILE (j1but(actstick) = 0) AND (j2but(actstick) = 0)

CALL GetJoyPos(jsp(1), jsp(2))                'Lire la position actuelle
minx = jsp(actstick).x                   'et ranger la position minimale
maxy = jsp(actstick).y

facteurx = 80 / (maxx - minx + 1)   'Calculer les facteurs de conversion
facteury = 23 / (maxy - miny + 1)      'pour l'axe des X et pour l'axe Y

'-- D‚terminer le Joystick et afficher sa position --
'-- jusqu'… ce que les deux boutons soient appuy‚s --

CLS
LOCATE 2, 44
PRINT "JOYSTB  - (c) 1991 MICHAEL TISCHER";
LOCATE 25, 1
PRINT "Appuyez sur les deux boutons  ";
PRINT "pour quitter le programme"
xold = 1                                 'Pr‚d‚finir l'ancienne Position
yold = 1

DO
  '-- Lire la position --
  CALL GetJoyPos(jsp(1), jsp(2))
  LOCATE 1, 1
  PRINT "("; jsp(actstick).x; "/"; jsp(actstick).y; ")  ";
 
  '-- Calculer la nouvelle position X du Joystick ----
  x% = facteurx * (jsp(actstick).x - minx% + 1)
  IF x% < 1 THEN x% = 1
  IF x% > 80 THEN x% = 80
 
  '-- Calculer la nouvelle position Y du Joystick ----
  y% = facteury * (jsp(actstick).y - miny% + 1)
  IF y% < 1 THEN y% = 1
  IF y% > 23 THEN y% = 23
 
  '-- Afficher la nouvelle position si celle-ci a ‚t‚ modifi‚e ---
  IF (x% <> xold) OR (y% <> yold) THEN
    LOCATE yold + 1, xold
    PRINT " ";
    LOCATE y% + 1, x%
    PRINT "X";
    xold = x%
    yold = y%
  END IF
 
  CALL GetJoyButton(j1but(1), j2but(1), j1but(2), j2but(2))
LOOP UNTIL (j1but(actstick) = 1) AND (j2but(actstick) = 1)

CLS

'**********************************************************************'
'* GetJoyButton: Renvoie l'emplacement des boutons de joystick        *'
'*--------------------------------------------------------------------*'
'* Entr‚e : J1B1% = 1, si le bouton 1 du joystick 1 est appuy‚,       *'
'*                  sinon 0                                           *'
'*          J1B2% = comme J1B1%, mais pour le 2nd bouton du joystick 1*'
'*                                                                    *'
'*          J2B1% = comme J1B1%, mais pour le bouton 1 du joystick 2  *'
'*          J2B2% = comme J1B2%, mais pour le bouton 2 du joystick 2  *'
'**********************************************************************'
'
SUB GetJoyButton (j1b1%, j1b2%, j2b1%, j2b2%)
  DIM regs AS RegType 'Registres processeur pour appel d'interruption

  regs.ax = &H8400                                    'Fonction BIOS 84h
  regs.dx = &H0                                       'Sous-fonction 00h
  CALL INTERRUPT(&H15, regs, regs)
  j1b1% = (regs.ax AND 16) \ 16 XOR 1   'Bit 4 de AX = J1B1
  j1b2% = (regs.ax AND 32) \ 32 XOR 1   'Bit 5 de AX = J1B2
  j2b1% = (regs.ax AND 64) \ 64 XOR 1   'Bit 6 de AX = J2B1
  j2b2% = (regs.ax AND 128) \ 128 XOR 1 'Bit 7 de AX = J2B2
END SUB

'**********************************************************************'
'* GetJoyPos : Retourne la position des deux Joysticks                *'
'*--------------------------------------------------------------------*'
'* ParamŠtre en entr‚e: JS1 = Structure pour le 1er Joystick          *'
'*                      JS2 = Structure pour le second Joystick       *'
'**********************************************************************'
'
SUB GetJoyPos (js1 AS JSPOS, js2 AS JSPOS)
  DIM regs AS RegType               'Registres pour appel d'interruption

  regs.ax = &H8400                                         'Fonction 84h
  regs.dx = &H1                                       'Sous-fonction 01h
  CALL INTERRUPT(&H15, regs, regs)
  js1.x = regs.ax                                  'Position du joystick
  js1.y = regs.bx
  js2.x = regs.cx
  js2.y = regs.dx
END SUB

