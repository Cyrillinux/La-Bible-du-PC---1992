'***********************************************************************
'*                             TOUCHEB                                 *
'----------------------------------------------------------------------*
'*  Fonction : Impl‚mente une fonction qui permet de lire un cractŠre  *
'*             en affichant l'‚tat des touches de bascule INSERT, CAPS * 
'*             NUM                                                     *
'*---------------------------------------------------------------------*
'* Auteur                 : MICHAEL TISCHER                            *
'* D‚velopp‚ le           : 09.06.1991                                 *
'* DerniŠre moddification : 01.01.1992                                 *
'***********************************************************************
'
DECLARE SUB Printinvers (Texte AS STRING)
DECLARE SUB WriteChar (Caractere AS INTEGER, Couleur AS INTEGER)
DECLARE FUNCTION GetPage% ()
DECLARE SUB Inikey ()
DECLARE FUNCTION NegFlag%(Flag%,FlagReg%,Colonne%,Ligne%,Text AS STRING)
DECLARE FUNCTION GetKey% ()

'$INCLUDE: 'QB.BI'     'Fichier contenant les d‚clarations des registres
																		    
CONST TRUE = -1                                  'Valeur bool‚enne vraie
CONST FALSE = NOT TRUE
																		    
CONST FL = 1                          'Ligne d'affichage des indicateurs  
CONST FC = 65                       'Colonne d'affichage des indicateurs       n
																		    
'-- Bits de la variable d'‚tat du clavier dans le BIOS -----------------
CONST SCRL = 16                                         'Bit Scroll-Lock
CONST NUML = 32                                            'Bit Num-Lock
CONST CAPL = 64                                           'Bit Caps-Lock
CONST INS = 128                                              'Bit Insert
																		    
'-- Code retourn‚ par GETKEY pour quelques touches ---------------------
																		    
CONST BEL = 7                                     'Code du signal sonore
CONST BS = 8                                'Code de la touche Backspace
CONST TB = 9                            'Code de la touche de tabulation
CONST LF = 10                               'Code de la touche Line-Feed
CONST CR = 13                                  'Code de la touche Entr‚e
CONST ESC = 27                          'Code de la touche d'‚chappement
CONST F1 = 315                                      'Touches de fonction
CONST F2 = 316
CONST F3 = 317
CONST F4 = 318
CONST F5 = 319
CONST F6 = 320
CONST F7 = 321
CONST F8 = 322
CONST F9 = 323
CONST F10 = 324
CONST CUP = 328                                    'Touches de direction
CONST CLEFT = 331                                         'Code A gauche
CONST CRIGHT = 333                                        'Code A droite
CONST CDOWN = 329                                      'Code Vers le bas
																		    
'-- Variables globales -------------------------------------------------

DIM SHARED Insert AS INTEGER                   'Etat de la touche Insert
DIM SHARED Caps   AS INTEGER                'Etat de la touche Caps-Lock
DIM SHARED Num    AS INTEGER                 'Etat de la touche Num-Lock
																		    
'-- Programme principal ------------------------------------------------

DIM Touche AS INTEGER                           'code ASCII d'une touche
																	     
Inikey                            'Initialise les indicateurs du clavier
CLS                                                      'Efface l'‚cran
PRINT "TOUCHEB  (C) 1987, 91 by MICHAEL TISCHER"
PRINT
PRINT "Tapez quelques caractŠres en activant ou d‚sactivant";
PRINT "les touches INSERT, CAPS ou NUM"
PRINT "L'‚tat de ces touches va ˆtre affich‚ ";
PRINT " … tout moment "
PRINT "dans le coin sup‚rieur droit de l'‚cran"
PRINT "La frappe de  <Entr‚e> ou <F1> termine ";
PRINT "le programme ..."
PRINT : PRINT "Votre saisie : ";
DO                                                     'Boucle de saisie
  Touche = GetKey                                        'Lit une touche
  IF Touche < 256 THEN                     'Pas de code clavier ‚tendu ?
    PRINT (CHR$(Touche));                          'Affiche le caractŠre
  END IF
LOOP UNTIL (Touche = CR) OR (Touche = F1)  'r‚p‚ter jusqu'… <F1> ou <CR>
END

'***********************************************************************
'* GetKey  : Lit un caractŠre et affiche l'‚tat de s indicateurs       *
'* Entr‚e : n‚ant                                                      *
'* Sortie : Code de la touche frapp‚e                                  *
'*                   < 256 : touche ordinaire                          *
'*                  >= 256 : touche … code ‚tendu                      *
'***********************************************************************
'
FUNCTION GetKey%

DIM Reg AS RegType          'registres du processeur pour l'interruption

DO
  Reg.ax = &H200         'Num‚ro de la fonction "Lire l'‚tat du clavier"
  CALL INTERRUPT(&H16, Reg, Reg)          'D‚clenche l'interruption BIOS

  '-- Ajuste les indicateurs en fonction du nouvel ‚tat ----------------
Insert = NegFlag(Insert, ((Reg.ax MOD 256) AND INS), FC+9, FL, "INSERT")
Caps = NegFlag(Caps, ((Reg.ax MOD 256) AND CAPL), FC + 3, FL, " CAPS ")
Num = NegFlag(Num, ((Reg.ax MOD 256) AND NUML), FC, FL, "NUM")

  Reg.ax = &H100               'Num‚ro de la fonction "CaractŠre prˆt ?"
  CALL INTERRUPT(&H16, Reg, Reg)       'D‚clenche l'interruption du BIOS
  IF (Reg.flags AND 64) = 0 THEN                           'Touche prˆte
    Reg.ax = &H0                 'Num‚ro de la fonction "Lire la touche"
    CALL INTERRUPT(&H16, Reg, Reg)     'D‚clenche l'interruption du BIOS
    IF (Reg.ax MOD 256) = 0 THEN                'Est-ce un code ‚tendu ?
      GetKey = (Reg.ax \ 256) OR &H100                              'oui
    ELSE                                                            'non
      GetKey = (Reg.ax MOD 256)
    END IF
    EXIT DO                                            'Quitte la boucle
  END IF
LOOP                          'R‚p‚tition jusqu'… r‚ception d'une frappe
END FUNCTION

'***********************************************************************
'*  GetPage : Lit la page d'‚cran courante                             *
'*  Entr‚e  : n‚ant                                                    *
'*  Sortie  : Page d'‚cran courante                                    *
'***********************************************************************
'
FUNCTION GetPage%
																		    
DIM Registre AS RegType     'registres du processeur pour l'interruption
																		    
Registre.ax = &H1500                         'AH = Num‚ro de la fonction
CALL INTERRUPT(&H10, Registre, Registre) 'D‚clenche interruption du BIOS
GetPage = Registre.bx \ 256                 'Registre.BH indique la page

END FUNCTION

'***********************************************************************
'*  IniKey  : Initialise les indicateurs des touches                   *
'*  Entr‚e : n‚ant                                                     *
'*  Sortie : n‚ant                                                     *
'*  Info   : Les indicateurs sont invers‚s par rapport … eur ‚tat      *
'*           actuel pour que ce dernier puisse ˆtre affich‚ au         *
'*           prochain appel de GETKEY                                  *
'***********************************************************************
'
SUB Inikey
																	     
SHARED Insert AS INTEGER                       'Etat de la touche Insert
SHARED Caps   AS INTEGER                    'Etat de la touche Caps-Lock
SHARED Num    AS INTEGER                     'Etat de la touche Num-Lock

DIM Registre AS RegType     'Registres du processeur pour l'interruption
																		    
Registre.ax = &H200      'Num‚ro de la fonction "Lire l'‚tat du clavier"
CALL INTERRUPT(&H16, Registre, Registre) 'D‚clenche interruption du BIOS
																		    
IF (Registre.ax AND INS) THEN                  'Fixe l'indicateur INSERT
   Insert = FALSE
ELSE
   Insert = TRUE
END IF

IF (Registre.ax AND CAPL) THEN              'Fixe l'indicateur Caps-Lock
   Caps = FALSE
ELSE
   Caps = TRUE
END IF

IF (Registre.ax AND NUML) THEN               'Fixe l'indicateur Num-Lock
   Num = FALSE
ELSE
   Num = TRUE
END IF

END SUB

'***********************************************************************
'*  NegFlag : Inverse un indicateur si n‚cessaire et affiche le texte  *
'*            associ‚                                                  *
'*  Entr‚es:                                                           *
'*  Sortie: nouvel ‚tat indicateur (True = actif, False = d‚sactiv‚ )  *
'***********************************************************************
'
FUNCTION NegFlag% (Flag%, FlagReg%, Colonne%, Ligne%, Texte AS STRING)
																		    
DIM LigneCour AS INTEGER       'M‚morise la position courante du curseur
DIM ColCour AS INTEGER

'-- Teste si l'‚tat s'est modifi‚  -------------------------------------

IF Flag% AND (FlagReg% = 0) OR (NOT Flag%) AND (FlagReg% <> 0) THEN
  LigneCour = CSRLIN                             'Oui: m‚morise la ligne
  ColCour = POS(0)                                        'et la colonne
  LOCATE Ligne%, Colonne%               'Position du nom de l'indicateur
  IF FlagReg% = 0 THEN                          'Si indicateur d‚sactiv‚
    NegFlag = FALSE                             'r‚sultat de la fonction
    PRINT SPACE$(LEN(Texte))                          'Efface indication
  ELSE                                                 'Indicateur actif
    NegFlag% = TRUE                             'R‚sultat de la fonction
    Printinvers (Texte)                  'Affiche le nom de l'indicateur
  END IF
  LOCATE LigneCour, ColCour       'Remet le curseur … son ancienne place
ELSE                                             ' l'‚tat n'a pas chang‚
  NegFlag% = Flag%                                     'Il reste le mˆme
END IF

END FUNCTION

'***********************************************************************
'* PrintInvers : Affiche un chaŒne de caractŠres en inverse vid‚o      *
'*               … la position et sur la page courantes                *
'* Entr‚es :                                                           *
'* Sortie     : n‚ant                                                  *
'***********************************************************************
'
SUB Printinvers (Texte AS STRING)
																		    
CONST INVERS = &H70                              'Attribut vid‚o inverse
DIM Compteur AS INTEGER                           'Compteur d'it‚rations
																		    
FOR Compteur = 1 TO LEN(Texte)        'Pour tous les caractŠres du texte
   CALL WriteChar(ASC(MID$(Texte, Compteur, 1)), INVERS)
   LOCATE CSRLIN, POS(0) + 1                          'Avance le curseur
NEXT

END SUB

'***********************************************************************
'*  WriteChar : Affiche un caractŠre avec un attribut donn‚            *
'*              … la position et sur la page courantes                 *
'*  Entr‚e    :                                                        *
'*  Sortie    : n‚ant                                                  *
'***********************************************************************
'
SUB WriteChar (Caractere AS INTEGER, Couleur AS INTEGER)
																		    
DIM Registre AS RegType     'Registres du processeur pour l'interruption
																		    
Registre.ax = &H9 * 256 + Caractere  'AH = fonction "Afficher caractŠre"
											   'AL = Code ASCII du caractŠre
Registre.bx = GetPage * 256 + Couleur    'BH = Page ‚cran ; BL = Couleur
Registre.cx = 1                                       'Un seul caractŠre
CALL INTERRUPT(&H10, Registre, Registre) 'D‚clenche interruption du BIOS

END SUB

