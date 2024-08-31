/***********************************************************************
*                              L O G O C . C                           *
**--------------------------------------------------------------------**
*  Fonction          : Montre comment d‚finir des jeux de caractŠres   *
*                      personnalis‚s avec une carte EGA ou VGA en      *
*                      donnant comme exemple une routine repr‚sentant  *
*                      un logo en mode texte                           *
**--------------------------------------------------------------------**
*  Auteur            : MICHAEL TISCHER                                 *
*  D‚velopp‚ le      : 06.08.1990                                      *
*  DerniŠre MAJ      : 14.01.1992                                      *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation       : CL /AS /Zp logoc.c logoca                       *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation       : cr‚er un projet avec le contenu suivant         *
*                      logoc.c                                         *
*                      logoca.obj                                      *
**--------------------------------------------------------------------**
*  Appel             : logoc                                           *
***********************************************************************/

#include <dos.h>                                 /* Fichier d'en-tˆte */
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <conio.h>

#ifdef __TURBOC__                            /* Travail avec Turbo C? */
  #define CLI()           disable()
  #define STI()           enable()
  #define outpw( p, w )   outport( p, w )
  #ifndef inp
    #define outp( p, b )  outportb( p, b )
    #define inp( p )      inportb( p )
  #endif
#else                                  /* Non c'est QuickC 2.0 ou MSC */
  #include <conio.h>
  #define MK_FP(seg,ofs)  ((void far *)\
                          (((unsigned long)(seg) << 16) | (ofs)))
  #define CLI()           _disable()
  #define STI()           _enable()
#endif

#define EGA       0                                /* Types de cartes */
#define VGA       1
#define NINI      2
#define MAX_CHAR  32         /* maximum de caractŠres red‚finissables */

#define EGAVGA_SEQUENCER 0x3C4    /* Port adresses/donn‚es s‚quenceur */
#define EGAVGA_MONCTR    0x3D4             /* Adr. contr“leur d'‚cran */
#define EGAVGA_GRAPHCTR  0x3CE     /*Port adresses/donn‚es ctrl graph */

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char     BYTE;

                                             /* Routine en assembleur */
extern void      defchar( BYTE ascii, BYTE table, BYTE height,
              BYTE nombre, void far * buf );

/***********************************************************************
*  SetCursor : Positionne le curseur clignotant                        *
**--------------------------------------------------------------------**
*  Entr‚e    : COLONNE = nouvelle colonne du curseur (0-79)            *
*              LIGNE   = nouvelle ligne du curseur (0-24)              *
*  Sortie    : n‚ant                                                   *
***********************************************************************/

void SetCursor( BYTE colonne, BYTE ligne )
{
  union REGS  regs;                       /* Registres d'interruption */

  regs.h.ah = 2;                 /* Num‚ro de la fonction "SetCursor" */
  regs.h.bh = 0;                                    /* Page d'‚cran 0 */
  regs.h.dh = ligne;                              /* Indique la ligne */
  regs.h.dl = colonne;                               /* et la colonne */
  int86(0x10, &regs, &regs);          /* Appelle l'interruption vid‚o */
}

/***********************************************************************
*  PrintfAt : Affiche une chaŒne en n'importe quel point de l'‚cran    *
**--------------------------------------------------------------------**
*  Entr‚es  : COLONNE = Position d'affichage                           *
*             LIGNE                                                    *
*             COULEUR  = attribut des caractŠres                       *
*             STRING = Pointe sur la chaŒne                            *
*  Sortie   : n‚ant                                                    *
*  Info     : Cette fonction en doit ˆtre appel‚e qu'aprŠs v‚rification*
*             pr‚alable de la pr‚sence d'une carte EGA ou VGA          *
***********************************************************************/

void PrintfAt(BYTE colonne, BYTE ligne, BYTE couleur, char *string,... )
{
  va_list     parameter;        /* Liste de paramŠtres pour macro _VA */
  char        affichage[255],        /* buffer pour la chaŒne format‚e*/
              *affptr;
  BYTE far    *vptr;                 /* Pointe sur la m‚moire d'‚cran */

  va_start( parameter, string );         /* Conversion des paramŠtres */
  vsprintf( affichage, string, parameter );              /* Formatage */

  vptr = (BYTE far *) MK_FP( 0xB800, colonne * 2 + ligne * 160 );

  for( affptr = affichage; *affptr ; )          /* Parcourt la chaine */
  {
    *vptr++ = *(affptr++);      /* CaractŠres dans la m‚moire d'‚cran */
    *vptr++ = couleur;                    /* et de mˆme les attributs */
  }
}

/***********************************************************************
*  ClrScr : Efface l'‚cran                                             *
**--------------------------------------------------------------------**
*  Entr‚e : COULEUR  = attribut des caractŠres                         *
*  Sortie : n‚ant                                                      *
***********************************************************************/

void ClrScr( BYTE couleur )
{
  BYTE far  *vptr;                   /* Pointe sur la m‚moire d'‚cran */
  int       count = 2000;            /* Nombre de caractŠres … effacer*/

  vptr = (BYTE far *) MK_FP( 0xB800, 0 ); /* Ptr sur la m‚moire ‚cran */

  for( ; count--; )                    /* Parcourt la m‚moire d'‚cran */
  {
    *vptr++ = ' ';              /* Ecrit le caractŠre et son attribut */
    *vptr++ = couleur;                     /* dans la m‚moire d'‚cran */
  }
}

/***********************************************************************
*  SetCharWidth : Fixe la largeur des caractŠres pour cartes VGA       *
*                 … 8 ou 9 pixels                                      *
**--------------------------------------------------------------------**
*  Entr‚e       : Largeur = largeur du caractŠre (8 ou 9)              *
***********************************************************************/

void SetCharWidth( BYTE largeur )
{
  union REGS      Regs;        /* Registres pour g‚rer l'interruption */
  unsigned char   x;                           /* Variable de travail */

  Regs.x.bx = ( largeur == 8 ) ? 0x0001 : 0x0800;

  x = inp( 0x3CC ) & (255-12);     /* Passe de la r‚solution de 720 … */
  if( largeur == 9 )                      /* 640 pixels ou vice-versa */
    x |= 4;
  (void) outp( 0x3C2, x);

  CLI();                    /* Programme le s‚quenceur en cons‚quence */
  outpw( EGAVGA_SEQUENCER, 0x0100 );
  outpw( EGAVGA_SEQUENCER, 0x01 + ( Regs.h.bl << 8 ) );
  outpw( EGAVGA_SEQUENCER, 0x0300 );
  STI();

  Regs.x.ax = 0x1000;               /* Ajuste l'‚cran horizontalement */
  Regs.h.bl = 0x13;
  int86( 0x10, &Regs, &Regs );
}

/***********************************************************************
*  IsEgaVga : teste la pr‚sence d'une carte EGA ou VGA                 *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Sortie : l'une des constantes EGA_MONO, EGA_COLOR etc.              *
***********************************************************************/

BYTE IsEgaVga( void )
{
  union REGS      Regs;              /* Registres pour l'interruption */

  Regs.x.ax = 0x1a00;        /* La fonction 1Ah n'existe que pour VGA */
  int86( 0x10, &Regs, &Regs );
  if( Regs.h.al == 0x1a )        /* La fonction est-elle disponible ? */
    return VGA;
  else                                  /* Non, serait-ce  une EGA  ? */
  {
    Regs.h.ah = 0x12;                         /* Appelle l'option 10h */
    Regs.h.bl = 0x10;                           /* de la fonction 12h */
    int86( 0x10, &Regs, &Regs );                /* Interruption vid‚o */
    return ( Regs.h.bl != 0x10 ) ? EGA : NINI;
  }
}

/***********************************************************************
*  BuildLogo : Dessine un logo compos‚ de diff‚rents caractŠres        *
*              qui sont peu utilis‚s fran‡ais                          *
*                                                                      *
**--------------------------------------------------------------------**
*  Entr‚e    : COLONNE    = Colonne o— d‚bute le logo (1-80)           *
*              LIGNE      = Ligne o— d‚bute le logo (1-25)             *
*              PROFONDEUR = Nombre de lignes de trame du logo          *
*              COULEUR    = Couleur d'affichage du logo                *
*              BUFP       = pointeur sur une tableau de pointeurs qui  *
*                           r‚f‚rencent des chaŒnes de caractŠres      *
*                           repr‚sentant le motif du logo              *
*  Info      : - La fonction test montre comment r‚aliser le buffer …  *
*                transmettre                                           *
*              - Le logo est centr‚ dans son bloc de caractŠres        *
***********************************************************************/

void BuildLogo( BYTE colonne, BYTE ligne, BYTE profondeur,
                BYTE couleur, char **bufp )
{
  static BYTE     UseChars[MAX_CHAR] =        /* caractŠres red‚finis */
          {
            128, 129, 132, 134, 141, 142, 143, 144, 146, 149,
            152, 153, 154, 155, 156, 157, 158, 159, 160, 161,
            162, 163, 164, 165, 166, 167, 168, 171, 172, 173,
            174, 175
            };

 BYTE       cvideo;                            /* Type de carte vid‚o */
 BYTE       chardef[16],              /* Motif binaire d'un caractŠre */
            charhauteur,   /* Nombre de lignes de trame par caractŠre */
            i, j, k, l,              /* Variables pour les it‚rations */
            masque,                 /* Masque pour une ligne de trame */
            largeur,                          /* Largeur de la chaŒne */
            index,       /* Indice pour parcourir le tableau UseChars */
            dx,        /* Largeur du bloc du Logo (colonnes de texte) */
            dy,       /* Profondeur du bloc du logo (lignes de texte) */
            colonnec,                             /* colonne courante */
        lignec,                                     /* ligne courante */
            gauche,                         /* Marge gauche en pixels */
            droite,                         /* Marge droite en pixels */
            haut,                              /* Marge sup en pixels */
            bas;                               /* Marge inf en pixels */

  cvideo = IsEgaVga();                        /* Quelle carte vid‚o ? */
  switch( cvideo )
  {
    case NINI :
      printf( "Erreur : Pas de carte EGA ou VGA install‚e !\n" );
      return;

    case EGA  :
      charhauteur = 14;      /* EGA: 14 lignes de trame par caractŠre */
      break;

    case VGA  :
      SetCharWidth( 8 );                /* 8 pixels de largeur en VGA */
      charhauteur = 16;           /* 16 lignes de trame par caractŠre */
      break;
  }

  largeur = strlen( *bufp );                       /* largeur du logo */
  dx = ( largeur + 7 ) / 8;                   /* Nombre de caractŠres */
  dy = ( profondeur + charhauteur - 1 ) / charhauteur;
  if( dx*dy > MAX_CHAR )
    printf( "Erreur : Logo trop grand dans BuildLogo !\n" );
  else
  {
    haut   = ( dy*charhauteur-profondeur ) / 2;             /* Marges */
    bas    = profondeur + haut - 1;
    gauche = ( dx*8-largeur ) / 2;
    droite = largeur + gauche - 1;

    for( index = 0, i = 0; i < dy; ++ i)
    {                                        /* Parcourt lignes texte */
      for(j = 0; j < dx; ++j, ++index )    /* Parcourt colonnes texte */
      {
        PrintfAt( colonne+j, ligne+i, couleur,  /* Affiche caractŠres */
                  "%c", UseChars[ index ] );

 /*-- Calcule le nouveau motif pour le caractŠre ---------------------*/

        for( k = 0; k < charhauteur; ++ k )  /* Parcourt lignes trame */
        {
      masque = 0;                        /* Pour l'instant masque nul */
          for( l = 0; l <= 7; ++l )            /* 8 pixels de largeur */
      {
            masque <<= 1;          /* D‚cale le masque vers la gauche */
            lignec = i * charhauteur + k;
            colonnec = j * 8 + l;

            if( lignec>=haut     && lignec<=bas  &&  /* Pixel au-del… */
                colonnec>=gauche && colonnec<=droite)/* de la marge ? */
              if( *(*(bufp+lignec-haut)+colonnec-gauche) != ' ' )
                masque |= 1;              /* Dessine un point du logo */
          }
          chardef[ k ] = masque;   /* motif dans le buffer caractŠres */
        }
    defchar( UseChars[ index ], 0, charhauteur, 1, chardef );
      }
    }
  }
}

/***********************************************************************
*  ResetLogo : recharge le jeu de caractŠres d'origine                 *
**--------------------------------------------------------------------**
*  Entr‚e    : n‚ant                                                   *
***********************************************************************/

void ResetLogo( void )
{
  union REGS    Regs;          /* Registres pour g‚rer l'interruption */

  switch( IsEgaVga() )
  {
    case EGA :
      Regs.x.ax = 0x1101;             /* Charge … nouveau le jeu 8*14 */
      Regs.h.bl = 0;
      int86( 0x10, &Regs, &Regs );
      break;

    case VGA :
      SetCharWidth( 9 );    /* Repr‚sente les caractŠres sur 9 pixels */
      Regs.x.ax = 0x1104;                     /* recharge le jeu 8*16 */
      Regs.h.bl = 0;
      int86( 0x10, &Regs, &Regs );
   }
}

/***********************************************************************
*  Test   : exemple de fonctionnement de la proc‚dure BuildLogo        *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
***********************************************************************/

void Test( void )
{
  static char *MyLogo[32] =
              { "                  **                  ",
                "                 ****                 ",
                "                 ****                 ",
                "                  **                  ",
                "                                      ",
                "                                      ",
                "                                      ",
                "                 ****                 ",
                "                 ****                 ",
                "**************************************",
                "**************************************",
                "***              ****              ***",
                "**               ****               **",
                "*                ****                *",
                "                 ****                 ",
                "                 ****                 ",
                "      ********   ****   ********      ",
                "      ****  **** **** ****  ****      ",
                "      ****     ********     ****      ",
                "      ****      ******      ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      ",
                "      ****       ****       ****      " };

  int         i, j;
  BYTE        couleur;

  static BYTE NouvDef[MAX_CHAR] =             /* CaractŠres red‚finis */
            {
            128, 129, 132, 134, 141, 142, 143, 144, 146, 149,
            152, 153, 154, 155, 156, 157, 158, 159, 160, 161,
            162, 163, 164, 165, 166, 167, 168, 171, 172, 173,
            174, 175
            };

  ClrScr( 0 );
  for( i = 0; i < 256; ++i ) /* Affiche le jeu complet des caractŠres */
  {
    for( j = 0; j < MAX_CHAR; ++ j )        /* nouvelle d‚finition .? */
      if( NouvDef[ j ] == i )     /* Le caractŠre en fait-il partie ? */
        break;                            /* Oui, sortir de la boucle */
    couleur = ( j < MAX_CHAR ) ? 15 : 14;

    PrintfAt( (i % 13) * 6 + 1, i / 13, couleur, "%3d:%c", i, i );
  }

  PrintfAt( 18, 22, 14, "LOGOC  -  (c) 1990, 92 by MICHAEL TISCHER" );
  BuildLogo( 60, 21, 30, 0x3F, MyLogo );          /* dessine le logo  */
  getch();
  ResetLogo();                                      /* Efface le logo */
  ClrScr( 15 );
  SetCursor( 0, 0 );
}

/***********************************************************************
*                               PROGRAMME PRINCIPAL                    *
***********************************************************************/

void main( void )
{
  Test();
}

