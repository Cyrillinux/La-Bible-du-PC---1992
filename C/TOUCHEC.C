/**********************************************************************/
/*                         T O U C H E C                              */
/*--------------------------------------------------------------------*/
/*  Fonction: Impl‚mente une fonction qui permet de lire un caractŠre */
/*            au clavier en affichant l'‚tat des touches de bascule   */
/*            INSERT, CAPS et NUM                                     */
/*--------------------------------------------------------------------*/
/*    Auteur                : MICHAEL TISCHER                         */
/*    D‚velopp‚ le          : 13.08.1987                              */
/*    DerniŠre modification : 01.01.1992                              */
/*--------------------------------------------------------------------*/
/*    ModŠle de m‚moire : SMALL                                       */
/**********************************************************************/

/*== Fichiers d'inclusion ============================================*/

#include <dos.h>
#include <bios.h>
#include <stdio.h>

/*== Typedefs ========================================================*/

typedef unsigned char BYTE;               /* bricolage d'un type BYTE */

/*== Macros ==========================================================*/

#ifdef __TURBOC__                         /* D‚finitions pour TURBO C */

   #define GetKbKey()        ( bioskey( 0 ) )
   #define GetKbReady()      ( bioskey( 1 ) != 0 )
   #define GetKbEtat()     ( bioskey( 2 ) )

#else                   /* D‚finitions pour le compilateur Microsoft C*/

   #define GetKbKey()        ( _bios_keybrd( _KEYBRD_READ ) )
   #define GetKbReady()      ( _bios_keybrd( _KEYBRD_READY ) != 0 )
   #define GetKbEtat()     ( _bios_keybrd( _KEYBRD_SHIFTSTATUS ) )

#endif

/*== Constantes ======================================================*/

/*-- Disposition des bits dans la variable d'‚tat du clavier du BIOS -*/

#define SCRL  16                                   /* Bit Scroll-Lock */
#define NUML  32                                      /* Bit Num-Lock */
#define CAPL  64                                     /* Bit Caps-Lock */
#define INS  128                                        /* Bit Insert */

#define TRUE  ( 0 == 0 )                 /* Constantes pour faciliter */
#define FALSE ( 0 == 1 )                         /* la compr‚hension  */

#define FL      0                /* Ligne d'affichage des indicateurs */
#define FC      65            /* Colonne d'affichage des indicateurs  */
#define CoulIndic 0x70           /* Couleur indicateur = noir / blanc */

/*-- Code retourn‚ par GETKEY pour quelques touches ------------------*/
#define BEL     7                            /* Code du signal sonore */
#define BS      8                      /* Code de la touche Backspace */
#define TAB     9                  /* Code de la touche de tabulation */
#define LF      10                      /* Code de la touche LineFeed */
#define CR      13                        /* Code de la touche Entr‚e */
#define ESC     27                 /* Code de la touche d'‚chappement */
#define F1      315                            /* Touches de fonction */
#define F2      316
#define F3      317
#define F4      318
#define F5      319
#define F6      320
#define F7      321
#define F8      322
#define F9      323
#define F10     324
#define CUP     328                           /* Touches de direction */
#define CLEFT   331
#define CRIGHT  333
#define CDOWN   328

/*== Variables globales ==============================================*/

BYTE Insert,                              /* Etat de la touche INSERT */
     Num,                                    /* Etat de la touche NUM */
     Caps;                                  /* Etat de la touche CAPS */

/**********************************************************************/
/* GETPAGE : Lit la page d'‚cran courante                             */
/* Entr‚es : n‚ant                                                    */
/* Sortie  : n‚ant                                                    */
/**********************************************************************/

BYTE GetPage( void )
{
 union REGS Registre;      /* Variables registres pour l'interruption */

 Registre.h.ah = 15;                         /* Num‚ro de la fonction */
 int86(0x10, &Registre, &Registre); /* D‚clenche l'interruption 10(h) */
 return(Registre.h.bh);         /* Num‚ro de la page d'‚cran courante */
}

/**********************************************************************/
/* SETPOS : Fixe la position du curseur dans la page d'‚cran courante */
/* Entr‚es : COLONNE= nouvelle colonne                                */
/*           LIGNE  = nouvelle ligne                                  */
/* Sortie  : n‚ant                                                    */
/* Info    : La position du curseur clignotant ne se modifie          */
/*           que si la page d'‚cran indiqu‚e est la page courante     */
/**********************************************************************/

void SetPos(BYTE Colonne, BYTE Ligne)
{
 union REGS Registre;      /* Variables registres pour l'interruption */

 Registre.h.ah = 2;                          /* Num‚ro de la fonction */
 Registre.h.bh = GetPage();                           /* page d'‚cran */
 Registre.h.dh = Ligne;                              /* Ligne d'‚cran */
 Registre.h.dl = Colonne;                          /* Colonne d'‚cran */
 int86(0x10, &Registre, &Registre);    /* Appel de l'interruption 10h */
}

/**********************************************************************/
/* GETPOS : Lit la position du curseur dans la page d'‚cran courante  */
/* Entr‚es : n‚ant                                                    */
/* Sortie  : Colonne = Pointeur sur la variable colonne courante      */
/*             Ligne = Pointeur sur la variable ligne courante        */
/**********************************************************************/

void GetPos(BYTE * Colonne, BYTE * Ligne)
{
 union REGS Registre;       /* Variables registres pour l'interruption*/

 Registre.h.ah = 3;                          /* Num‚ro de la fonction */
 Registre.h.bh = GetPage();                           /* Page d'‚cran */
 int86(0x10, &Registre, &Registre);     /* Appelle l'interruption 10h */
 *Colonne = Registre.h.dl;        /* Lit les r‚sultats de la fonction */
 *Ligne = Registre.h.dh;                        /* dans les registres */
}

/**********************************************************************/
/* WRITECHAR : Affiche un caractŠre avec un attribut donn‚ … la       */
/*             position et dans la page courantes                     */
/* Entr‚es : - CARACTERE = Code ASCII du caractŠre … afficher         */
/*           - Couleur   = Attribut du caractŠre                      */
/* Sortie : n‚ant                                                     */
/**********************************************************************/

void WriteChar(char Caractere, BYTE Couleur)
{
 union REGS Registre;      /* Variables registres pour l'interruption */

 Registre.h.ah = 9;                          /* Num‚ro de la fonction */
 Registre.h.al = Caractere;                   /* CaractŠre … afficher */
 Registre.h.bh = GetPage();                           /* Page d'‚cran */
 Registre.h.bl = Couleur;          /* Couleur du caractŠre … afficher */
 Registre.x.cx = 1;                              /* Un seul caractŠre */
 int86(0x10, &Registre, &Registre);   /* D‚clenche l'interruption 10h */
}

/**********************************************************************/
/* WRITETEXT: affiche une chaŒne de caractŠre avec un attribut        */
/*            constant … partir d'une position donn‚e sur la page     */
/*            d'‚cran courante                                        */
/* Entr‚es : - COLONNE= colonne d'affichage                           */
/*           - LIGNE  = ligne d'affichage                             */
/*           - TEXTE  = pointeur sur la chaŒne … afficher             */
/*           - Couleur  = Attribut des caractŠres                     */
/* Sortie  : n‚ant                                                    */
/* Info    : Texte est un pointeur r‚f‚ren‡ant un vecteur de          */
/*           caractŠres qui contient le texte … afficher avec un '\0' */
/*           terminal                                                 */
/**********************************************************************/

void WriteTexte(BYTE Colonne, BYTE Ligne, char *Texte, BYTE Couleur)
{
 union REGS InRegistre,    /* Variables registres pour l'interruption */
	    OutRegistre;

 SetPos(Colonne, Ligne);               /* Fixe la position du curseur */
 InRegistre.h.ah = 14;                       /* Num‚ro de la fonction */
 InRegistre.h.bh = GetPage();                         /* Page d'‚cran */
 while (*Texte)                              /* Afficher jusqu'… '\0' */
  {
   WriteChar(' ', Couleur);                  /* Attribut du caractŠre */
   InRegistre.h.al = *Texte++;                /* CaractŠre … afficher */
   int86(0x10, &InRegistre, &OutRegistre); /* D‚clencher interruption */
  }
}

/**********************************************************************/
/* CLS : Efface la page d'‚cran courante                              */
/* Entr‚e : n‚ant                                                     */
/* Sortie : n‚ant                                                     */
/**********************************************************************/

void Cls( void )
{
 union REGS Registre;      /* Variables registres pour l'interruption */

 Registre.h.ah = 6;                /* Num‚ro de la fonction Scroll-UP */
 Registre.h.al = 0;                                 /* 0 pour effacer */
 Registre.h.bh = 7;                              /* noir / fond blanc */
 Registre.x.cx = 0;                          /* Coin sup‚rieur gauche */
 Registre.h.dh = 24;                           /* Coordonn‚es du coin */
 Registre.h.dl = 79;                               /* inf‚rieur droit */
 int86(0x10,&Registre,&Registre);/* D‚clenche interruption BIOS vid‚o */
}

/**********************************************************************/
/* NEGFLAG : Inverse un indicateur si n‚cessaire et affiche le texte  */
/*          associ‚                                                   */
/* Entr‚es : FLAG    = Dernier ‚tat de l'indicateur                   */
/*           FLAGREG = Etat actuel de l'indicateur (0 = inactif)      */
/*           COLONNE = Colonne d'affichage du nom de l'indicateur     */
/*           LIGNE   = Ligne d'affichage du nom de l'indicateur       */
/*           TEXTE   = Nom de l'indicateur                            */
/* Sortie : nouvel ‚tat de l'indicateur(TRUE = actif,FALSE = inactif) */
/**********************************************************************/

BYTE NegFlag(BYTE Flag, unsigned int FlagReg,
	     BYTE Colonne, BYTE Ligne, char * Texte)
{
 BYTE LigneCour,                                    /* Ligne courante */
      ColCour;

 if (!(Flag == (FlagReg != 0)))               /* Indicateur modifi‚ ? */
  {                                                            /* Oui */
   GetPos(&ColCour, &LigneCour);/* Lit la position courante du curseur*/
   WriteTexte(Colonne, Ligne, Texte, (BYTE) ((Flag) ? 0 : CoulIndic));
   SetPos(ColCour, LigneCour);             /* Repositionne le curseur */
   return(Flag ^1);                /* Change le bit 0 de l'indicateur */
  }
 else return(Flag);                        /* sinon tout reste pareil */
}

/**********************************************************************/
/* GETKEY : Lit un caractŠre et affiche l'‚tat des indicateurs        */
/* Entr‚e : n‚ant                                                     */
/* Sortie : Code de la touche frapp‚e                                 */
/*               < 256 : touche ordinaire                             */
/*              >= 256 : touche … code ‚tendu                         */
/**********************************************************************/

unsigned int GetKey( void )
{
 int Touche,                                      /* Touche retourn‚e */
     Etat;                                         /* Etat du clavier */

 do
  {
   Etat = GetKbEtat();                       /* Lit l'‚tat du clavier */
   Insert = NegFlag(Insert, Etat & INS, FC+9, FL, "INSERT");
   Caps = NegFlag(Caps, Etat & CAPL, FC+3, FL, " CAPS ");
   Num = NegFlag(Num, Etat & NUML, FC, FL, "NUM");
  }
 while ( !GetKbReady() );/* Recommence jusqu'… d‚tection d'une frappe */

 Touche = GetKbKey();                                /* Lit la touche */
 return ((Touche & 255) == 0) ? (Touche >> 8) + 256 : Touche & 255;
}

/**********************************************************************/
/* INIKEY : Initialise les indicateurs des touches                    */
/* Entr‚e : n‚ant                                                     */
/* Sortie : n‚ant                                                     */
/* Info   : Les indicateurs sont invers‚s par rapport … leur ‚tat     */
/*          actuel pour que ce dernier puisse ˆtre affich‚ au         */
/*          prochain appel de GETKEY                                  */
/**********************************************************************/

void IniKey( void )
{
 int Etat;                                         /* Etat du clavier */

 Etat = GetKbEtat();                         /* Lit l'‚tat du clavier */
 Insert = (Etat & INS) ? FALSE : TRUE;        /* Inverse les contenus */
 Caps = (Etat & CAPL)? FALSE : TRUE;                     /* courants  */
 Num = (Etat & NUML) ? FALSE : TRUE;
 }

/**********************************************************************/
/**                         PROGRAMME PRINCIPAL                      **/
/**********************************************************************/

void main( void )
{
 unsigned int Touche;

 Cls();                                             /* Efface l'‚cran */
 SetPos(0,0);                             /* Curseur en haut … gauche */
 printf("TOUCHEC  -  (c) 1987, 92 by Michael Tischer\n\n");
printf("Tapez quelques caractŠres en activant ou d‚sactivant\n");
printf("les touches INSERT, CAPS ou NUM.\n");
printf("L'‚tat de ces touches va ˆtre affich‚ … tout moment\n");
printf("dans le coin sup‚rieur droit de l'‚cran.\n");
printf("La frappe de <Entr‚e> ou <F1> termine le programme...\n\n");
printf("Votre saisie : ");

 IniKey();                   /* Initialise les indicateurs du clavier */
 do
  {
   if ((Touche = GetKey()) < 256)                   /* Lit une touche */
    printf("%c", (char) Touche);  /* Affiche la touche (si ordinaire) */
  }
 while (!(Touche == CR || Touche == F1));       /* R‚pŠte l'op‚ration */
						  /* jusqu'… F1 ou CR */
 printf("\n");
}
