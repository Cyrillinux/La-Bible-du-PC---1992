'**********************************************************************'
'*                           C O N F I G                              *'
'*--------------------------------------------------------------------*'
'*    Fonction       : affiche sur l'‚cran la configuration du PC     *'
'*--------------------------------------------------------------------*'
'*    Auteur         : MICHAEL TISCHER                                *'
'*    D‚velopp‚ le   : 07/07/1987                                     *'
'*    DerniŠre modif.: 18/10/1992                                     *'
'**********************************************************************'

DECLARE SUB PrintConfig ()
DECLARE FUNCTION GetWord& (Register AS INTEGER)

'$INCLUDE: 'QB.BI'               ' Inclure la d‚claration des registres

CONST TRUE = -1
CONST FALSE = NOT TRUE

CALL PrintConfig                             ' Affiche la configuration
END

'**********************************************************************'
'* GetWord: R‚cupŠre et valide les valeurs r‚cup‚r‚e dans les         *'
'*          pour la division entiŠre et le modulo                     *'
'* Entr‚e : Valeur … convertir                                        *'
'* Sortie : Valeur convertie                                          *'
'**********************************************************************'
'
'
FUNCTION GetWord& (Register AS INTEGER)

IF Register <= 0 THEN                            ' Bit 16 pos‚ ? (signe)
  GetWord = 65536 + Register                        ' Compl‚ment positif
ELSE
  GetWord = Register
END IF
END FUNCTION

'**********************************************************************'
'* PrintConfig: Affichage de la configuration d'un PC                 *'
'* Entr‚e : Aucune                                                    *'
'* Sortie : Aucune                                                    *'
'* Infos  : la configuration est sortie en tenant compte du type de   *'
'*          PC                                                        *'
'**********************************************************************'
'
SUB PrintConfig

DIM AT AS INTEGER                                ' Ce PC est-il un AT? '
DIM Word AS LONG
DIM Register AS RegType       ' Registres processeur pour interruption '

CLS                                                    ' Vider l'‚cran '
DEF SEG = &HF000
IF PEEK(&HFFFE) = &HFC THEN
  AT = TRUE                                     ' Tester si AT ou bien '
ELSE
  AT = FALSE                                               ' PC ou  XT '
END IF

PRINT "CONFIGB  -  (c) 1987, 1992 by Michael Tischer"
PRINT
PRINT "Configuration de votre PC"
PRINT "----------------------------------------------------"
PRINT "Type de PC               : ";
SELECT CASE PEEK(&HFFFE)
  CASE &HFF                                         ' &FF, c'est un PC '
    PRINT "PC"
  CASE &HFE                                         ' &FE, c'est un XT '
    PRINT "XT"
  CASE &HFC                                         ' &FC, c'est un AT '
    PRINT "AT ou sup‚rieur"
END SELECT
CALL Interrupt(&H12, Register, Register)  ' Taille RAM donn‚e par BIOS '
PRINT "M‚moire RAM              :"; Register.ax; "Ko"
IF AT THEN                                      ' Ce PC est-il un AT ? '
  Register.ax = &H8800      ' fonction pour lire taille m‚moire suppl. '
  CALL Interrupt(&H15, Register, Register) 'Interrup. cassette du BIOS '
  PRINT "RAM suppl‚mentaire       :"; Regs.ax; "Ko au dessus 1 Mo"
END IF
CALL Interrupt(&H11, Register, Register) ' Interruption de config BIOS '
PRINT "Mode vid‚o initial       : ";
SELECT CASE (Register.ax MOD 256) AND 48    ' D‚terminer le mode vid‚o '
  CASE 0
    PRINT "Ind‚fini"
  CASE 16
    PRINT "40*25 caractŠres carte couleur"
  CASE 32
    PRINT "80*25 caractŠres carte couleur"
  CASE 48
    PRINT "80*25 caractŠres carte monochrome"
END SELECT
Word = GetWord(Register.ax)
PRINT "Lecteurs de disquette    :"; (((Word MOD 256) \ 64) AND 3) + 1
PRINT "Interfaces s‚rie         :"; ((Word \ 256) \ 2) AND 3
PRINT "Interfaces parallŠle     :"; (Word \ 256) \ 64
END SUB

