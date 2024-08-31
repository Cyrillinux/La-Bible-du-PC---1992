'***********************************************************************
'*                               L E D B                               *
'*---------------------------------------------------------------------*
'*   Fonction  : Fixe les bits de l'indicateur d'‚tat du clavier       *
'*               du BIOS en allumant ou ‚teignant les diodes           *
'*               ‚lectroluminescentes                                  *
'*---------------------------------------------------------------------*
'*   Auteur                : MICHAEL TISCHER                           *
'*   D‚velopp‚ le          : 08.06.1991                                *
'*   DerniŠre modification : 03.01.1992                                *
'***********************************************************************
'
DECLARE SUB SetFlag (Flag AS INTEGER)
DECLARE SUB Delay (Pause AS INTEGER)
DECLARE SUB ClrFlag (Flag AS INTEGER)
										
'$INCLUDE: 'QB.BI'           'Fichier d'inclusion pour les interruptions

CONST SCRL = 16                                         'Bit Scroll-Lock
CONST NUML = 32                                            'Bit Num-Lock
CONST CAPL = 64                                           'Bit Caps-Lock
										
DIM Compteur AS INTEGER                           'Compteur d'it‚rations
										
CLS                                                      'Efface l'‚cran
PRINT " LEDB  -  (c) 1988, 1992 by Michael Tischer"
PRINT
PRINT " Observez les LEDs de votre clavier "
										
FOR Compteur = 1 TO 10                                    '10 it‚rations
  SetFlag (CAPL)                                            'Allume CAPS
  Delay (100)                                             'Attend 100 ms
  ClrFlag (CAPL)                                            'Eteint CAPS
  SetFlag (NUML)                                             'Allume NUM
  Delay (100)                                             'Attend 100 ms
  ClrFlag (NUML)                                            'Eteint NUML
  SetFlag (SCRL)                                     'Allume Scroll-Lock
  Delay (100)                                             'Attend 100 ms
  ClrFlag (SCRL)                                     'Eteint Scroll-Lock
NEXT

FOR Compteur = 1 TO 10                                    '10 it‚rations
  SetFlag (CAPL OR SCRL OR NUML)           'Allume les trois indicateurs
  Delay (500)  'Attend 200 ms
  ClrFlag (CAPL OR SCRL OR NUML)           'Eteint les trois indicateurs
  Delay (500) 'Attend 200 ms
NEXT
END

'***********************************************************************
'*  ClrFLAG : Met … 0 un bit de l'indicateur d'‚tat du clavier         *
'*  Entr‚e  : Bit … mettre … 0 (cf Constantes)                         *
'*  Sortie  : n‚ant                                                    *
'***********************************************************************
'
SUB ClrFlag (Flag AS INTEGER)
										
DIM Register AS RegType                        'Registres du processseur
										
DEF SEG = &H40        'Segment de l'indicateur d'‚tat du clavier du BIOS
POKE &H17, (PEEK(&H17) AND (NOT Flag))                         'Mise … 0
Register.ax = 1 * 256       'AH = Num. fonction : CaracrŠre disponible ?
CALL INTERRUPT(&H16, Register, Register)       'D‚clenche l'interruption

END SUB

'***********************************************************************
'* Delay   : Arrˆte l'ex‚cution du programme pendant une certain temps *
'*           donn‚ en millisecondes                                    *
'* Entr‚e  : Pause = temps d'arrˆt en ms                               *
'* Sortie  : n‚ant                                                     *
'***********************************************************************
'
SUB Delay (Pause AS INTEGER)
										
DIM Register AS RegType     'Registres du processeur pour l'interruption
DIM Time AS LONG                                'M‚morise le temps final
										
Register.ax = 0                'Num‚ro de la fonction : lecture du timer
CALL INTERRUPT(&H1A, Register, Register) 'D‚clenche interruption du BIOS
Time = Register.dx + (Register.cx * 32768)       'Calcule le temps final
Time = Time + (Pause * 18 + ((Pause * 2) / 10)) / 1000
DO
  CALL INTERRUPT(&H1A, Register, Register)  'Appel interruption du timer
LOOP WHILE (Register.dx + (Register.cx * 32768)) <= Time
				       'Jusqu'… ce que Time soit atteint
END SUB

'***********************************************************************
'*  SETFLAG : Met … 1 un bit de l'indicateur d'‚tat du clavier         *
'*  Entr‚e  : Bit … mettre … 1 (cf constantes)                         *
'*  Sortie  : n‚ant                                                    *
'***********************************************************************
'
SUB SetFlag (Flag AS INTEGER)
										
DIM Register AS RegType     'Registres du processeur pour l'interruption

DEF SEG = &H40        'Segment de l'indicateur d'‚tat du clavier du BIOS
POKE &H17, (PEEK(&H17) OR Flag)                                'Mise … 1
Register.ax = 1 * 256       'AH = num. fonction : CaractŠre disponible ?
CALL INTERRUPT(&H16, Register, Register) 'D‚clenche interruption du BIOS

END SUB

