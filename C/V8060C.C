/***********************************************************************
*                          V 8 0 6 0 C . C                             *
**--------------------------------------------------------------------**
*  Fonction          : Montre comment exploiter le mode 800*600 16     *
*                      couleurs de la carte Super VGA. Ce programme    *
*                      accŠde aux routines en assembleur du module     *
*                      V8060CA.ASM                                     *
**--------------------------------------------------------------------**
*  Auteur        : MICHAEL TISCHER                                     *
*  D‚velopp‚ le  : 14.01.1991                                          *
*  DerniŠre MAJ  : 14.02.1992                                          *
**--------------------------------------------------------------------**
*  ModŠle m‚moire   : SMALL                                            *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation       : CL /AS v8060c.c v8060ca                         *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation       : Utiliser un projet avec le contenu suivant      *
*                       v8060c.c                                       *
*                       v8060ca.obj                                    *
**--------------------------------------------------------------------**
*  Appel           : v8060c                                            *
***********************************************************************/

#include <dos.h>
#include <stdarg.h>
#include <stdlib.h>
#include <io.h>
#include <stdio.h>
#include <conio.h>

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char BYTE;

/*-- R‚f‚rences externes aux routines en assembleur ------------------*/

extern int  init800600( void );
extern void setpix( int x, int y, unsigned char couleur);
extern BYTE getpix( int x, int y );
extern void far * getfontptr( void );

/*-- D‚clarations d‚pendantes du compilateur -------------------------*/

#ifndef __TURBOC__
  #define random(x) ( rand() % (x+1) )          /* Fonction al‚atoire */
#endif

/*-- Constantes ------------------------------------------------------*/

#define MAXX       799                       /* Coordonn‚es maximales */
#define MAXY       599
#define NBLINE     2500                           /* Nombre de lignes */
#define XDISTANCE  40       /* Distance entre le rectangle et le bord */
#define YDISTANCE  30
#define X1         ( 2 * XDISTANCE )      /* Coordonn‚es du rectangle */
#define Y1         ( 2 * YDISTANCE )
#define X2         ( MAXX-XDISTANCE )
#define Y2         ( MAXY-YDISTANCE )
#define XRAND      random( X2 - X1 - 1 ) + X1 + 1      /* Coordonn‚es */
#define YRAND      random( Y2 - Y1 - 1 ) + Y1 + 1       /* al‚atoires */

/***********************************************************************
*  IsVga: Teste la pr‚sence d'une carte VGA.                           *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Sortie : 0 si pas de carte VGA, sinon -1                            *
***********************************************************************/

BYTE IsVga( void )
{
 union REGS  Regs;             /* Registres pour g‚rer l'interruption */

 Regs.x.ax = 0x1a00;            /* La fonction 1AH n'existe qu'en VGA */
 int86( 0x10, &Regs, &Regs );
 return ( Regs.h.al == 0x1a );               /* Est-elle disponible ? */
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
 typedef BYTE   CARDEF[256][8];     /* Structure du jeu de caractŠres */
 typedef CARDEF far *CARPTR;       /* Pointe sur un jeu de caractŠres */

 BYTE     i, k,                              /* Compteur d'it‚rations */
          masque;        /* Masque binaire pour dessiner le caractŠre */

 static   CARPTR fptr = (CARPTR) 0;       /* Jeu de caractŠres en ROM */

 if( fptr == (CARPTR) 0 )      /* A-t-on d‚j… d‚termin‚ ce pointeur ? */
   fptr = getfontptr();      /* Non, d‚termine avec fonct. assembleur */

  /*- Dessine le caractŠre pixel par pixel ---------------------------*/

 if( cf == 255 )                           /* CaractŠre transparent ? */
   for( i = 0; i < 8; ++i )    /* Oui, dessine que pixels du 1er plan */
   {
     masque = (*fptr)[caractere][i];         /* Motif bin. pour ligne */
     for( k = 0; k < 8; ++k, masque <<= 1 )  /* Parcourt les colonnes */
       if( masque & 128 )                       /* Pixel … dessiner ? */
         setpix( x+k, y+i, cc );                               /* Oui */
   }
 else                                     /* Non dessine chaque pixel */
   for ( i = 0; i < 8; ++i )                   /* Parcourt les lignes */
   {
     masque = (*fptr)[caractere][i];         /* Motif bin. pour ligne */
     for( k = 0; k < 8; ++k, masque <<= 1 )  /* Parcourt les colonnes */
       setpix( x+k, y+i, (BYTE) (( masque & 128 ) ? cc : cf) );
   }
}

/***********************************************************************
*  Line: Trace un segment dans la fenˆtre graphique en appliquant      *
*        l'algorithme de Bresenham                                     *
**--------------------------------------------------------------------**
*  Entr‚es : X1, Y1 = Coordonn‚es de l'origine                         *
*            X2, Y2 = Coordonn‚es de l'extr‚mit‚ terminale             *
*            COULEUR = couleur du segment                              *
***********************************************************************/

/*-- Fonction accessoire pour ‚changer deux variables entiŠres -------*/

void SwapInt( int *i1, int *i2 )
{
 int dummy;

 dummy = *i2;  *i2   = *i1;  *i1   = dummy;
}

/*-- Proc‚dure principale --------------------------------------------*/

void Line( int x1, int y1, int x2, int y2, BYTE couleur )
{
 int d, dx, dy,
     aincr, bincr,
     xincr, yincr,
     x, y;

 if( abs(x2-x1) < abs(y2-y1) )     /* Sens du parcours : axe X ou Y ? */
 {                                                           /* Par Y */
   if( y1 > y2 )                             /* y1 plus grand que y2? */
   {
     SwapInt( &x1, &x2 );                    /* Oui ‚change X1 et X2, */
     SwapInt( &y1, &y2 );                                 /* Y1 et Y2 */
   }

   xincr = ( x2 > x1 ) ?  1 : -1;           /* Fixe le pas horizontal */

   dy    = y2 - y1;
   dx    = abs( x2-x1 );
   d     = 2 * dx - dy;
   aincr = 2 * (dx - dy);
   bincr = 2 * dx;
   x     = x1;
   y     = y1;

   setpix( x, y, couleur );               /* dessine le premier pixel */
   for(y=y1+1; y<= y2; ++y )                  /* Parcourt l'axe des Y */
   {
     if( d >= 0 )
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
   if( x1 > x2 )                             /* x1 plus grand que x2? */
   {
     SwapInt( &x1, &x2 );                    /* Oui, ‚change X1 et X2 */
     SwapInt( &y1, &y2 );                                 /* Y1 et Y2 */
   }

   yincr = ( y2 > y1 ) ? 1 : -1;              /* Fixe le pas vertical */

   dx    = x2 - x1;
   dy    = abs( y2-y1 );
   d     = 2 * dy - dx;
   aincr = 2 * (dy - dx);
   bincr = 2 * dy;
   x     = x1;
   y     = y1;

   setpix( x, y, couleur );               /* Dessine le premier pixel */
   for( x=x1+1; x<=x2; ++x )                  /* Parcourt l'axe des X */
   {
     if( d >= 0 )
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
 va_list  parameter;     /* Liste de paramŠtres pour les macros VA_...*/
 char     affichage[255],           /* Buffer pour la chaŒne format‚e */
          *cp;

 va_start( parameter, string );           /* Convertit les paramŠtres */
 vsprintf( affichage, string, parameter );                 /* Formate */
 for( cp = affichage; *cp; ++cp, x+= 8 )         /* Affiche la chaŒne */
   PrintChar( *cp, x, y, cc, cf );          /* format‚e par PrintChar */
}

/**********************************************************************
*  DrawAxis: Draws axes from the left and top borders on the screen.  *
**-------------------------------------------------------------------**
*  Input   : STEPX = Increment for X-axis                             *
*            STEPY = Increment for Y-axis                             *
*            FG    = Foreground color                                 *
*            BK    = Background color (255 = transparent)             *
**********************************************************************/

void DrawAxis( int stepx, int stepy, BYTE fg, BYTE bk )
{
 int  x, y;                                     /* boucle coordonn‚es */

 Line( 0, 0, MAXX, 0, fg );                          /* Dessine axe X */
 Line( 0, 0, 0, MAXY, fg );                          /* Dessine axe Y */

 for( x = stepx; x < MAXX; x += stepx )              /* Echelle axe X */
 {
   Line( x, 0, x, 5, fg );
   GrafPrintf( x < 100 ? x - 8 : x - 12, 8, fg, bk, "%d", x );
 }

 for( y = stepy; y < MAXY; y += stepy )              /* Echelle axe Y */
 {
   Line( 0, y, 5, y, fg );
   GrafPrintf( 8, y-4, fg, bk, "%3d", y );
 }
}


/***********************************************************************
*  Demo: D‚montre l'usage des diff‚rentes fonctions de ce module       *
***********************************************************************/

void Demo( void )
{
 int  i;                                     /* Compteur d'it‚rations */

 DrawAxis( 30, 20, 15, 255 );                     /* Dessine des axes */

 GrafPrintf( X1, MAXY-10, 15, 255,
             "V8060C.C  -  (c) by MICHAEL TISCHER" );

 Line( X1, Y1, X1, Y2, 15 );                  /* Encadre le rectangle */
 Line( X1, Y2, X2, Y2, 15 );
 Line( X2, Y2, X2, Y1, 15 );
 Line( X2, Y1, X1, Y1, 15 );

   /*-- Dessine des segments al‚atoires dans le rectangle ------------*/

 for( i = NBLINE; i > 0 ; --i )
   Line( XRAND, YRAND, XRAND, YRAND, (BYTE) (i % 16) );
}

/*--------------------------------------------------------------------*/
/*--                    PROGRAMME PRINCIPAL                         --*/
/*--------------------------------------------------------------------*/

void main( void )
{
 union REGS  regs;

 printf( "V8060C.C  - (c) 1991, 92 by MICHAEL TISCHER\n\n" );
 if( IsVga() )                      /* Dispose-t-on d'une carte VGA ? */
 {                   /* Oui, mais le mode 800*600 est-il accessible ? */
   if( init800600() )
   {                                                   /* €a marche ! */
     Demo();                                       /* Ex‚cute la d‚mo */
     getch();                          /* Attend une frappe de touche */
     regs.x.ax = 0x0003;                    /* R‚tablit le mode texte */
     int86( 0x10, &regs, &regs );
   }
   else
   {
     printf( "Attention! Le mode 800*600 n'a pas pu ˆtre initialis‚\n");
     exit( 1 );
   }
 }
 else
 {                                           /* Non, pas de carte VGA */
   printf( "Attention! Ce programme n‚cessite une carte VGA !");
   exit(1);                                   /* Termine le programme */
 }
}
