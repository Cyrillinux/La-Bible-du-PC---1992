'******************************************************************'
'*                           R T C B                              *'
'*----------------------------------------------------------------*'
'*  Fonction       : fournit deux sous-programmes qui permettent  *'
'*                   de lire des donn‚es ou d'en ‚crire sur la    *'
'*                   RTC                                          *'
'*  Auteur         : MICHAEL TISCHER                              *'
'*  d‚velopp‚ le   : 24.7.87                                      *'
'*  derniŠre modif.: 17.2.92                                      *'
'******************************************************************'
'
DECLARE FUNCTION RTCRead% (Adresse%)
DECLARE FUNCTION RTCDT% (Adresse%)

CLS                                                   'Vider l'‚cran
PRINT "RTC (c) 1987, 92 by Michael Tischer": PRINT
PRINT "Informations tir‚es de l'horloge temps r‚el sur piles"
PRINT "====================================================="
PRINT

IF (RTCRead(&HE) AND 128) = 128 THEN         'Bit 7=1 --> piles vide
  PRINT "       ATTENTION ! Les piles de l'horloge sont vides"
ELSE
  PRINT "- L'horloge est exploit‚e en mode";
  PRINT (RTCRead(&HB) AND 2) * 6 + 12; "heures"

  PRINT "- Il est : ";
  PRINT USING "##:"; RTCDT(&H4);
  PRINT USING "##:"; RTCDT(&H2);
  PRINT USING "##"; RTCDT(&H0)

  PRINT "- Nous sommes le : ";
  PRINT USING "##"; RTCDT(&H7);
  PRINT USING ".##"; RTCDT(&H8) / 100;
  PRINT USING ".####"; (RTCDT(&H32) * 100 + RTCDT(&H9)) / 10000
  PRINT

END IF

'****************************************************************'
'* Lire contenu de l'une des cellules de m‚moire de la RTC      *'
'*--------------------------------------------------------------*'
'* Entr‚e : Adresse% = num‚ro de la cellule de m‚moire (0 … 63) *'
'* Sortie : contenu de cette cellule de m‚moire                 *'
'****************************************************************'
'
FUNCTION RTCDT% (Adresse%)

  Ret% = RTCRead(Adresse%)         'Lecture registre d'adresse RTC
  IF (RTCRead(&HB) AND 4) <> 4 THEN
    RTCDT% = (Ret% AND 15) + INT(Ret% / 16) * 10
  ELSE
    RTCDT% = Ret%
  END IF

END FUNCTION

'****************************************************************'
'* Ecrire une cellule de m‚moire dans RTC                       *'
'*--------------------------------------------------------------*'
'* Entr‚e : Adresse% = num‚ro de la cellule de m‚moire (0 … 63) *'
'* Sortie : aucune                                              *'
'****************************************************************'
'
FUNCTION RTCRead% (Adresse%)

  IF (Adresse% < 0) OR (Adresse% > 63) THEN
    RTCRead% = -1
  ELSE
    OUT &H70, Adresse%   'Envoyer nø cellule sur reg d'adresse RTC
    RTCRead% = INP(&H71)       'Lire le contenu du reg donn‚es RTC
  END IF

END FUNCTION

'****************************************************************'
'* Lire contenu d'une des cellules de date ou d'heure dans la   *'
'* RTC et convertir en d‚cimal                                  *'
'*--------------------------------------------------------------*'
'* Entr‚e : Adresse% = num‚ro de la cellule de m‚moire (0 … 63) *'
'*          Valeur% = nouvelle valeur de la cellule             *'
'* Sortie : aucune                                              *'
'****************************************************************'
'
SUB RTCWrite (Adresse%, Valeur%)

  OUT &H70, Adresse%
  OUT &H71, Valeur%

END SUB

