/***********************************************************************
*                          V 1 6 C O L C . C                           *
**--------------------------------------------------------------------**
*  Fonction         : Montre comment programmer les modes graphiques   *
*                     … 16 couleurs des cartes EGA et VGA              *
*                     Ce programme utilise les routines en assembleur  *
*                     du module V16COLCA.ASM .                         *
**--------------------------------------------------------------------**
*  Auteur           : MICHAEL TISCHER                                  *
*  D‚velopp‚ le     : 20.12.1990                                       *
*  DerniŠre MAJ       14.02.1992                                       *
**--------------------------------------------------------------------**
*  ModŠle m‚moire   : SMALL                                            *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation      : CL /AS v16colc.c v16colca                        *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation     : Utiliser un fichier de projet avec le contenu     *
*                    suivant:                                          *
*                       v16colc.c                                      *
*                       v16colca.obj                                   *
**--------------------------------------------------------------------**
*  Appel           : v16colc                                           *
**--------------------------------------------------------------------**
*  Info             : Le message "Unreachable code ... " ‚mis par      *
*                     Turbo C ne signifie pas qu'il y a une erreur     *
***********************************************************************/

#include <dos.h>
#include <stdarg.h>
#include <stdlib.h>
#include <io.h>
#include <stdio.h>
#include <conio.h>

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char BYTE;

/*-- R‚f‚rences externes aux routines en assembleur -----------------*/

extern void init320200( void );
extern void init640480( void );
extern void init640350( void );
extern void init640200( void );
extern void setpix( int x, int y, unsigned char couleur);
extern BYTE getpix( int x, int y );
extern void setpage( int page );
extern void showpage( int page );
extern void far *getfontptr( void );

/*-- Constantes ------------------------------------------------------*/

#define A320200  1                  /* R‚solutions et modes possibles */
#define A640200  2
#define A640350  3
#define A640480  4

#define MODE     A640350                   /* Mettez ici la constante */
                                        /* exprimant le mode souhait‚ */

#define EGA      0                                 /* Types de cartes */
#define VGA      1
#define NINI     2

/*- Variables globales -----------------------------------------------*/

int  MaxX,                                   /* Coordonn‚es maximales */
     MaxY;
BYTE Pages;                                /* Nombre de pages d'‚cran */

/***********************************************************************
*  IsEgaVga : Teste la pr‚sence d'une carte EGA ou VGA.                *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Sortie : EGA, VGA ou NINI                                           *
***********************************************************************/

BYTE IsEgaVga( void )
{
 union REGS Regs;           /* Registres pour g‚rer les interruptions */

 Regs.x.ax = 0x1a00;            /* La fonction 1Ah n'existe qu'en VGA */
 int86( 0x10, &Regs, &Regs );
 if ( Regs.h.al == 0x1a )        /* La fonction est-elle disponible ? */
  return VGA;
 else
  {
   Regs.h.ah = 0x12;                          /* Appelle l'option 10h */
   Regs.h.bl = 0x10;                            /* de la fonction 12h */
   int86(0x10, &Regs, &Regs );      /* D‚clenche l'interruption vid‚o */
   return (BYTE) (( Regs.h.bl != 0x10 ) ? EGA : NINI);
  }
}

/***********************************************************************
*  PrintChar : Ecrit un caractŠre en dehors de la zone visible         *
*              de la m‚moire d'‚cran                                   *
**--------------------------------------------------------------------**
*  Entr‚e  :   caractere = caractŠre … afficher                        *
*              x, y    = Coordonn‚es du coin sup‚rieur gauche          *
*              cc      = Couleur du caractŠre                          *
*              cf      = Couleur du fond                               *
*  Info    : Le caractŠre est dessin‚ dans une matrice de 8*8 pixels - *
*            sur la base du jeu de caractŠres 8*8 en ROM               *
***********************************************************************/

void PrintChar( char caractere, int x, int y, BYTE cc, BYTE cf )
{
 typedef BYTE CARDEF[256][8];       /* Structure du jeu de caractŠres */
 typedef CARDEF far *CARPTR;       /* Pointe sur un jeu de caractŠres */

 BYTE         i, k,                          /* Compteur d'it‚rations */
       masque;           /* Masque binaire pour dessiner le caractŠre */

 static CARPTR fptr = (CARPTR) 0;         /* Jeu de caractŠres en ROM */

 if ( fptr == (CARPTR) 0 )     /* A-t-on d‚j… d‚termin‚ ce pointeur ? */
  fptr = getfontptr();    /* d‚termine avec la fonction en assembleur */

  /*- Dessine le caractŠre pixel par pixel ---------------------------*/

 if ( cf == 255 )                          /* CaractŠre transparent ? */
  for ( i = 0; i < 8; ++i ) /* dessine que les pixels du premier plan */
   {
    masque = (*fptr)[caractere][i];         /* Lit le motif bin/ligne */
    for ( k = 0; k < 8; ++k, masque <<= 1 )  /* Parcourt les colonnes */
     if ( masque & 128 )                        /* Pixel … dessiner ? */
      setpix( x+k, y+i, cc );                                  /* Oui */
   }
 else                                     /* Non dessine chaque pixel */
  for ( i = 0; i < 8; ++i )                    /* Parcourt les lignes */
  {
   masque = (*fptr)[caractere][i];          /* Lit le motif bin/ligne */
   for ( k = 0; k < 8; ++k, masque <<= 1 )   /* Parcourt les colonnes */
    setpix( x+k, y+i, (BYTE) (( masque & 128 ) ? cc : cf) );
  }
}

/***********************************************************************
*  Line: Trace un segment dans la fenˆtre graphique en appliquant      *
*        l'algorithme de Bresenham                                     *
**--------------------------------------------------------------------**
*  Entr‚es : X1, Y1 = Coordonn‚es de l'origine                         *
*            X2, Y2 = Coordonn‚es de l'extr‚mit‚ terminale             *
*            COULEUR = couleur dusegment                               *
***********************************************************************/

/*-- Fonction accessoire pour ‚changer deux variables entiŠres -------*/

void SwapInt( int *i1, int *i2 )
{
 int dummy;

 dummy = *i2;
 *i2   = *i1;
 *i1   = dummy;
}

/*-- Proc‚dure principale --------------------------------------------*/

void Line( int x1, int y1, int x2, int y2, BYTE couleur )
{
 int d, dx, dy,
     aincr, bincr,
     xincr, yincr,
     x, y;

 if ( abs(x2-x1) < abs(y2-y1) )            /* Parcours : axe X ou Y ? */
  {                                                          /* Par Y */
   if ( y1 > y2 )                            /* y1 plus grand que y2? */
    {
     SwapInt( &x1, &x2 );                    /* Oui ‚change X1 et X2, */
     SwapInt( &y1, &y2 );                                 /* Y1 et Y2 */
    }

   xincr = ( x2 > x1 ) ?  1 : -1;           /* Fixe le pas horizontal */

   dy = y2 - y1;
   dx = abs( x2-x1 );
   d  = 2 * dx - dy;
   aincr = 2 * (dx - dy);
   bincr = 2 * dx;
   x = x1;
   y = y1;

   setpix( x, y, couleur );               /* dessine le premier pixel */
   for (y=y1+1; y<= y2; ++y )                 /* Parcourt l'axe des Y */
    {
     if ( d >= 0 )
      {
       x += xincr;
       d += aincr;
      }
     else
      d += bincr;
     setpix( x, y, couleur );
    }
  }
 else                                                        /* par X */
  {
   if ( x1 > x2 )                            /* x1 plus grand que x2? */
    {
     SwapInt( &x1, &x2 );                     /* Oui, ‚change X1 et X2*/
     SwapInt( &y1, &y2 );                                 /* Y1 et Y2 */
    }

   yincr = ( y2 > y1 ) ? 1 : -1;              /* Fixe le pas vertical */

   dx = x2 - x1;
   dy = abs( y2-y1 );
   d  = 2 * dy - dx;
   aincr = 2 * (dy - dx);
   bincr = 2 * dy;
   x = x1;
   y = y1;

/*   SetPixel*/
   setpix( x, y, couleur );               /* Dessine le premier pixel */
   for (x=x1+1; x<=x2; ++x )                  /* Parcourt l'axe des X */
    {
     if ( d >= 0 )
      {
       y += yincr;
       d += aincr;
      }
     else
      d += bincr;
     setpix( x, y, couleur );
    }
  }
}

/***********************************************************************
*  GrafPrintf: Affiche une chaŒne format‚e sur l'‚cran graphique       *
**--------------------------------------------------------------------**
*  Entr‚es : X, Y   = Coordonn‚es de d‚part (0 - ...)                  *
*            CC     = Couleur des caractŠres                           *
*            CF     = Couleur du fond  (255 = transparent)             *
*            STRING = ChaŒne avec indications de formatage             *
*            ...    = Expressions comme pour printf                    *
***********************************************************************/

void GrafPrintf( int x, int y, BYTE cc, BYTE cf, char * string, ... )
{
 va_list parameter;      /* Liste de paramŠtres pour les macros VA_...*/
 char affichage[255],               /* Buffer pour la chaŒne format‚e */
      *cp;

 va_start( parameter, string );           /* Convertit les paramŠtres */
 vsprintf( affichage, string, parameter );               /* Formate   */
 for ( cp = affichage; *cp; ++cp, x+= 8 )  /* Affiche la chaŒne       */
   PrintChar( *cp, x, y, cc, cf );          /* format‚e par PrintChar */
}

/***********************************************************************
*  ColorBox: Dessine un rectangle et le remplit avec un motif compos‚  *
*            de lignes                                                 *
**--------------------------------------------------------------------**
*  Entr‚es : X1, Y1 = Coordonn‚es du coin sup gauche de la fenˆtre     *
*            X2, Y2 = Coordonn‚es du coin inf droit de la fenˆtre      *
*            COULMAX= code couleur maximal                             *
*  Info    : Les couleurs des lignes sont r‚p‚t‚es dans un cycle de 0  *
*            … COULMAX                                                 *
***********************************************************************/

void ColorBox( int x1, int y1, int x2, int y2, int coulmax )
{
 int x, y,                                   /* Variables d'it‚ration */
     sx, sy;                 /* Point de d‚part de la derniŠre boucle */

 Line( x1, y1, x1, y2, 15 );                  /* Encadre le rectangle */
 Line( x1, y2, x2, y2, 15 );
 Line( x2, y2, x2, y1, 15 );
 Line( x2, y1, x1, y1, 15 );

 for ( y = y2-1; y > y1; --y ) /* du coin inf gauche au bord droit    */
  Line( x1+1, y2-1, x2-1, y, (BYTE) (y % coulmax) );

 for ( y = y2-1; y > y1; --y )  /* du coin inf droit au bord gauche   */
  Line( x2-1, y2-1, x1+1, y, (BYTE) (y % coulmax) );

  /*-- Du milieu du rectangle au bord sup‚rieur ----------------------*/

 for ( x=x1+1, sx=x1+(x2-x1)/2, sy=y1+(y2-y1)/ 2; x < x2; ++x )
  Line( sx, sy, x, y1+1, (BYTE) (x % coulmax) );
}

/***********************************************************************
*  DrawAxis: Dessine des axes … gauche et en haut de l'‚cran           *
**--------------------------------------------------------------------**
*  Entr‚es: XSTEP = Pas selon l'axe X                                  *
*            YSTEP = Pas selon l'axe Y                                 *
*            CC    = Couleur des caractŠres                            *
*            CF    = Couleur de fond  (255 = transparent)              *
***********************************************************************/

void DrawAxis( int stepx, int stepy, BYTE cc, BYTE cf )
{
 int x, y;                                   /* Variables d'it‚ration */

 Line( 0, 0, MaxX, 0, cc );                          /* Trace l'axe X */
 Line( 0, 0, 0, MaxY, cc );                          /* Trace l'axe Y */

 for ( x = stepx; x < MaxX; x += stepx )            /* Gradue l'axe X */
  {
   Line( x, 0, x, 5, cc );
   GrafPrintf( x < 100 ? x - 8 : x - 12, 8, cc, cf, "%d", x );
  }

 for ( y = stepy; y < MaxY; y += stepy )            /* Gradue l'axe Y */
  {
   Line( 0, y, 5, y, cc );
   GrafPrintf( 8, y-4, cc, cf, "%3d", y );
  }
}

/***********************************************************************
*  Demo: D‚montre l'usage des diff‚rentes fonctions de ce module       *
***********************************************************************/

void Demo( void )
{
 #define PAUSE 100000          /* D‚finit la pause, d‚pend du systŠme */

 int x;                                      /* Compteur d'it‚rations */
 BYTE page;                                      /* Compteur de pages */
 long delay;                                    /* Compteur de pauses */

 for ( page = 1; page <= Pages; ++page )
  {
   setpage( page-1 );                              /* Traite une page */
   showpage( page-1 );
   ColorBox( 50+page*2, 40, MaxX-50+page*2, MaxY-40, 16 );
   DrawAxis( 30, 20, 15, 255 );                     /* Trace les axes */
   GrafPrintf( 46, MaxY-10, 15, 255,
               "V16COLC  -  (c) by MICHAEL TISCHER" );
  }

    /*-- AFfiche les pages graphiques en alternance ------------------*/

 for ( x = 0; x < 50; ++x )                          /* 50 passages   */
  {
   showpage( x % Pages );                         /* Affiche une page */
   for ( delay = 1; delay < PAUSE; ++delay )                /* Pause  */
    ;
  }
}

/*--------------------------------------------------------------------*/
/*--                     PROGRAMME PRINCIPAL                        --*/
/*--------------------------------------------------------------------*/

void main( void )
{
 union REGS regs;

 printf( "V16COLC.C  - (c) 1990, 92 by MICHAEL TISCHER\n\n" );
 if ( MODE == A640480 )                                 /* Mode VGA ? */
  {                                                           /* Oui  */
   if ( IsEgaVga() != VGA )                   /* A-t-on une carte VGA */
    {                                                          /* Non */
     printf( "Attention ! Pour travailler dans le mode graphique "\
      "de 640*480 pixels " \
      "\nil faut une carte VGA !\n" );
     exit(1);                                              /* Termin‚ */
    }
   else              /* Oui initialise le mode et fixe les paramŠtres */
    {
     MaxX = 639;
     MaxY = 479;
     Pages = 1;
     init640480();
    }
  }
 else                                        /* doit ˆtre un mode EGA */
  {
   if ( IsEgaVga() == NINI )                       /* Ni EGA ni VGA ? */
    {                                                          /* Non */
     printf( "Attention: Pour faire tourner ce programme il faut "\
       "au moins une \ncarte EGA !\n" );
     exit(1);                                             /* Termin‚  */
    }
   else              /* Oui initialise le mode et fixe les paramŠtres */
    switch( MODE )
     {
      case A320200 : {                              /* 320*200 pixels */
                      MaxX = 319;
                      MaxY = 199;
                      Pages = 8;
                      init320200();
                      break;
                     }
      case A640200 : {                              /* 640*200 pixels */
                      MaxX = 639;
                      MaxY = 199;
                      Pages = 4;
                      init640200();
                      break;
                     }
      case A640350 : {                              /* 640*350 pixels */
                      MaxX = 639;
                      MaxY = 349;
                      Pages = 2;
                      init640350();
                     }
     }
  }

 Demo();
 getch();                              /* Attend une frappe de touche */
 regs.x.ax = 0x0003;                         /* Revient au mode texte */
 int86( 0x10, &regs, &regs );
}
