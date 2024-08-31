/***********************************************************************
*                           S 3 2 2 0 C . C                            *
**--------------------------------------------------------------------**
*Fonction          : montre comment travailler avec des sprites dans   *
*                    le mode graphique VGA 320*200 en 256 couleurs avec*
*                    quatre pages d'‚cran                              *
*                                                                      *
* Le programme utilise les routines en assembleur des modules          *
*             S3220CA.ASM et  V3220CA.ASM .                            *
**--------------------------------------------------------------------**
*  Auteur       : MICHAEL TISCHER                                      *
*  D‚velopp‚ le :  9.09.1990                                           *
*  DerniŠre MAJ : 14.02.1992                                           *
**--------------------------------------------------------------------**
*  ModŠle m‚moire   : SMALL                                            *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation      : CL /AS s3220c.c v3220ca s3220ca                  *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation      : Utiliser un fichier de projet avec le contenu    *
*                     suivant                                          *
*                      s3220c.c                                        *
*                      v3220ca.obj                                     *
*                      s3220ca.obj                                     *
**--------------------------------------------------------------------**
*  Appel           : s3220c                                            *
***********************************************************************/

#include <dos.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <conio.h>

/*-- D‚clarations d‚pendantes du compilateur--------------------------*/

#ifdef __TURBOC__
  #include <alloc.h>
#else
  #include <malloc.h>
  #define random(x) ( rand() % (x+1) )          /* Fonction al‚atoire */
#endif

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char BYTE;

typedef struct {                                 /* Image d'un sprite */
                BYTE largeur,                       /* Largeur totale */
                     hauteur,          /* Hauteur en lignes de pixels */
                     page,                    /* Page de m‚morisation */
                     *bmskp,        /* Pointeur sur le masque binaire */
                     msklen;                 /* Longueur d'une entr‚e */
                int  ligne;            /* Ligne de pixels o— commence */
               } SPLOOK;                    /* le sprite dans sa page */

typedef struct {                        /* Descripteur de sprite (ID) */
                BYTE   fondpage;                      /* Page de fond */
                int    x[2], y[2],     /* Coordonn‚es en pages 0 et 1 */
                       fondx, fondy;           /* Buffer pour le fond */
                SPLOOK *splookp;              /* Pointeur sur l'image */
               } SPID;

/*-- R‚f‚rences externes aux routines en assembleur ------------------*/

extern void init320200( void );
extern void setpix( int x, int y, unsigned char couleur);
extern BYTE getpix( int x, int y );
extern void setpage( BYTE page );
extern void showpage( BYTE page );
extern void far * getfontptr( void );
extern void waitvsync( void );
extern void blockmove( BYTE depage, int dex, int dey,
                       BYTE apage, int ax, int ay,
                       BYTE largeur, BYTE hauteur, BYTE *bmskp );

/*-- Constantes ------------------------------------------------------*/

#define NOBITMASK (BYTE *) 0

#define MAXX 319                             /* Coordonn‚es maximales */
#define MAXY 199

#define OUT_LEFT   1     /* Marquage des collisions dans SpriteMove() */
#define OUT_TOP    2
#define OUT_RIGHT  4
#define OUT_BOTTOM 8
#define OUT_NO     0


/***********************************************************************
*  IsVga: Teste la pr‚sence d'une carte VGA.                           *
**--------------------------------------------------------------------**
*  Entr‚e : n‚ant                                                      *
*  Sortie  : 0  si pas de carte VGA, sinon # 0                         *
***********************************************************************/

BYTE IsVga( void )
{
 union REGS Regs;              /* Registres pour g‚rer l'interruption */

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
   fptr = getfontptr();  /*Non, d‚termine avec la fonction assembleur */

  /*- Dessine le caractŠre pixel par pixel ---------------------------*/

 if( cf == 255 )                           /* CaractŠre transparent ? */
   for ( i = 0; i < 8; ++i ) /* Ne dessine que les pixels du 1er plan */
   {
     masque = (*fptr)[caractere][i];  /* Motif binaire pour une ligne */
     for( k = 0; k < 8; ++k, masque <<= 1 )  /* Parcourt les colonnes */
       if( masque & 128 )                       /* Pixel … dessiner ? */
         setpix( x+k, y+i, cc );                               /* Oui */
   }
 else                                     /* Non dessine chaque pixel */
   for ( i = 0; i < 8; ++i )                   /* Parcourt les lignes */
   {
     masque = (*fptr)[caractere][i];  /* Motif binaire pour une ligne */
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
*            COULEUR = couleur dusegment                               *
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
   for( y=y1+1; y<= y2; ++y )                 /* Parcourt l'axe des Y */
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
   for(x=x1+1; x<=x2; ++x )                   /* Parcourt l'axe des X */
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

/***********************************************************************
*  CreateSprite: Cr‚e un sprite … l'aide d'un motif de pixels          *
*                pr‚alablement compil‚                                 *
*                                                                      *
**--------------------------------------------------------------------**
*  Entr‚e : SPLOOKP = Pointeur sur la structure de donn‚es produite    *
*                     par CompileSprite                                *
*            FONDPAGE = Page d'‚cran qui doit m‚moriser le fond        *
*                       du sprite                                      *
*            FONDX,   = Coordonn‚es dans la page de fond o— doit ˆtre  *
*            FONDY       ˆtre m‚moris‚ le fond du sprite               *
*  Sortie  : Pointeur sur la structure du sprite cr‚‚e                 *
*  Info    : La m‚morisation du fond du sprite n‚cessite deux zones    *
*            contigues de la taille du sprite                          *
***********************************************************************/

SPID *CreateSprite(SPLOOK *splookp, BYTE fondpage, int fondx, int fondy)
{
 SPID *spidp;                    /* Pointe sur la structure du sprite */

 spidp = (SPID *) malloc( sizeof(SPID) );   /* M‚moire pour structure */
 spidp->splookp  = splookp;                  /* Y reporte les donn‚es */
 spidp->fondpage = fondpage;
 spidp->fondx    = fondx;
 spidp->fondy    = fondy;

 return spidp;               /* Retourne un pointeur sur la structure */
}

/***********************************************************************
*  CompileSprite: Cr‚e le motif binaire d'un sprite                    *
*                 … l'aide d'une d‚finition connue au moment de        *
*                 l'ex‚cution                                          *
**--------------------------------------------------------------------**
*  Entr‚es : BUFP = Pointeur sur un tableau de pointeurs r‚f‚ren‡ant   *
*            des chaŒnes de caractŠres qui repr‚sentent le motif du    *
*            sprite                                                    *
*            HAUTEUR = Hauteur du sprite et nombre de chaŒnes de       *
*                        caractŠres                                    *
*            PAGE    = Page graphique pour dessiner le sprite          *
*            Y       = Ligne de pixels o— commence le dessin           *
*            CLR     = CaractŠre ASCII associ‚ … la plus petite couleur*
*            COULEURPP = Premier code de couleur pour CLR              *
*  Info    : Les sprites sont dessin‚s … partir du bord gauche de la   *
*            ligne indiqu‚e                                            *
***********************************************************************/

SPLOOK *CompileSprite( char **bufp, BYTE shauteur, BYTE gpage, BYTE y,
                       char clr, BYTE couleurpp )
{
 BYTE   largeur,         /* Longueur des chaŒnes = largeur des motifs */
        c,                                   /* M‚morise un caractŠre */
        i, k, l,                            /* Compteurs d'it‚rations */
        pixc,     /* Compteurs pixels pour compilation masque binaire */
        pixm,
        *lspb;           /* Pointeur courant dans le buffer du sprite */
 int    distance,                      /* Distance entre deux sprites */
        lx, ly;                              /* Coordonn‚es courantes */
 SPLOOK *splookp;        /* Pointeur sur la structure du sprite cr‚‚e */

         /*-- Cr‚e une structure d'image de sprite et la remplit -----*/

 splookp          = (SPLOOK *) malloc( sizeof(SPLOOK) );
 largeur          = strlen( *bufp );
 distance         = splookp->largeur = ( ( largeur + 3 + 3 ) / 4 ) * 4;
 splookp->bmskp   = (BYTE *) malloc( (distance*shauteur+7)/8*4 );
 splookp->hauteur = shauteur;
 splookp->ligne   = y;
 splookp->page    = gpage;
 splookp->msklen  = ( distance * shauteur + 7 ) / 8;

/*-- Remplit le fond du sprite dans sa page d'origine
      avec les codes pour le fond de caractŠres transparent------*/

 setpage( gpage );                          /* Fixe la page de dessin */
 for( ly = y + shauteur-1, lx = 4 * distance - 1; ly >= (int) y; --ly)
   Line( 0, ly, lx, ly, 255 );

       /*-- Dessine quatre fois le sprite dans sa page d'origine -----*/

 for( l = 0, lx = 0; l < 4; ++l, lx+=distance+1 )
   for( i = 0; i < shauteur; ++i )
     for( k = 0; k < largeur; ++k )
       setpix( lx+k, y+i, ( c = *(*(bufp+i)+k) ) == ' '
                   ? 255
                   : couleurpp+(c-clr));

/*-- Parcourt les quatre sprites cr‚‚s et g‚nŠre des masques binaires */
      /*-- pour copier les sprites dans les plans de bits            -*/

 for( l = pixm = pixc = 0, lx = 0; l < 4; ++l, lx+=distance )
 {
   lspb = splookp->bmskp + splookp->msklen * l;
   for( i = 0; i < shauteur; ++i )
     for( k = 0; k < distance; ++k )
     {
       pixm >>= 1;           /* D‚cale masque pixels d'1 bit a droite */
       if( getpix( lx+k, y+i ) != 255 )            /* Pixel de fond ? */
         pixm |= 128;                    /* Non fixe un bit du masque */
       if( ++pixc == 8 )           /* A-t-on d‚j… trait‚ huit pixels? */
       { /* Oui m‚morise le masque binaire dans le buffer des sprites */
         *lspb++ = pixm;
         pixc = pixm = 0;      /* compteur de pixels et le masque … 0 */
       }
     }
   if( pixc )                     /* Dernier quartet dans le buffer ? */
   {                                                           /* Non */
     *lspb = pixm >> 4;  /* quartet haut dans quartet bas et m‚morise */
     pixc = pixm = 0;          /* compteur de pixels et le masque … 0 */
   }
 }
 return splookp;    /* Retourne un pointeur sur le buffer des sprites */
}

/***********************************************************************
*  PrintSprite : Affiche un sprite dans une page donn‚e                *
**--------------------------------------------------------------------**
*  Entr‚es : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE = Page concern‚e                                     *
*                    (0 ou 1)                                          *
***********************************************************************/

void PrintSprite( register SPID *spidp, BYTE page )
{
 BYTE   largeur;                          /* Largeur totale du sprite */
 int    x;                       /* Abscisse X du sprite dans sa page */
 SPLOOK *splookp;                   /* Pointeur sur l'image du sprite */

 largeur = (splookp = spidp->splookp)->largeur;
 x       = spidp->x[page];
 blockmove(
           splookp->page,
           largeur * (x % 4),
           splookp->ligne,
           page,
           x & ~3,
           spidp->y[page],
           largeur,
           splookp->hauteur,
           splookp->bmskp + (x % 4) * splookp->msklen
          );
}

/***********************************************************************
*  GetSpriteBg: Lit le fond du sprite et le m‚morise … l'emplacement   *
*               pr‚vu                                                  *
**--------------------------------------------------------------------**
*  Entr‚e  : SPIDP = Pointe sur la structure du sprite                 *
*            PAGE = Page d'o— est tir‚ le fond                         *
*                    (0 ou 1)                                          *
***********************************************************************/

void GetSpriteBg( register SPID *spidp, BYTE page )
{
 SPLOOK *splookp;                   /* Pointeur sur l'image du sprite */

 splookp = spidp->splookp;
 blockmove(
           page,
           spidp->x[page],
           spidp->y[page],
           spidp->fondpage,
           spidp->fondx + ( splookp->largeur * page ),
           spidp->fondy,
           splookp->largeur,
           splookp->hauteur,
           NOBITMASK
          );
}

/***********************************************************************
*  RestoreSpriteBg: R‚tablit dans la page d'origine le fond d'un sprite*
*                   sauvegard‚ au pr‚alable                            *
**--------------------------------------------------------------------**
*  Entr‚e  : SPIDP = Pointeur sur la structure du sprite               *
*            PAGE = Page o— doit ˆtre recopi‚ le fond                  *
*                    (0 ou 1)                                          *
***********************************************************************/

void RestoreSpriteBg( register SPID *spidp, BYTE page )
{
 SPLOOK *splookp;                   /* Pointeur sur l'image du sprite */

 splookp = spidp->splookp;
 blockmove(
           spidp->fondpage,
           spidp->fondx + ( splookp->largeur * page ),
           spidp->fondy,
           page,
           spidp->x[page], spidp->y[page],
           splookp->largeur,
           splookp->hauteur,
           NOBITMASK
          );
}

/***********************************************************************
*  MoveSprite: D‚place un sprite                                       *
**--------------------------------------------------------------------**
*  Entr‚e  : SPIDP  = Pointeur sur la structure du sprite              *
*            PAGE  = Page o— doit ˆtre r‚tabli le fond (0 ou 1)        *
*            DELTAX = Pas de d‚placement dans les directions X et Y    *
*            DELTAY                                                    *
*  Sortie  : Marquage de collision, cf   constantes OUT_...            *
***********************************************************************/

BYTE MoveSprite( SPID *spidp, BYTE page, int deltax, int deltay )
{
 int  nouvx, nouvy;                /* Nouvelles coordonn‚es du sprite */
 BYTE out;                      /* Indique une collision avec le bord */

/*-- D‚cale l'abscisse X et teste s'il y a collision avec le bord-----*/

 if( ( nouvx = spidp->x[page] + deltax ) < 0 )
 {
   nouvx = 0 - deltax - spidp->x[page];
   out = OUT_LEFT;
 }
 else
   if( nouvx > 319 - spidp->splookp->largeur )
   {
     nouvx = 640-nouvx-2*(spidp->splookp->largeur);
     out = OUT_RIGHT;
   }
   else
     out = OUT_NO;

/*-- D‚cale l'ordonn‚e Y et teste s'il y a collision avec le bord----*/

 if( ( nouvy = spidp->y[page] + deltay ) < 0 )    /* bord sup‚rieur ? */
 {                                          /* Oui, doit ˆtre n‚gatif */
   nouvy = 0 - deltay - spidp->y[page];
   out |= OUT_TOP;
 }
 else
   if( nouvy + spidp->splookp->hauteur > 199+1  )       /* Bord inf ? */
   {                                 /* Oui, deltay doit ˆtre positif */
     nouvy = 400-nouvy-2*(spidp->splookp->hauteur);
     out |= OUT_BOTTOM;
   }

/*-- Fixe une nouvelle pos que si diff‚rente de l'ancienne ---*/

 if( nouvx != spidp->x[page]  ||  nouvy != spidp->y[page] )
 {                                               /* Nouvelle position */
   RestoreSpriteBg( spidp, page );                /* R‚tablit le fond */
   spidp->x[page] = nouvx;         /* Prend les nouvelles coordonn‚es */
   spidp->y[page] = nouvy;
   GetSpriteBg( spidp, page );                 /* Lit le nouveau fond */
   PrintSprite( spidp, page );   /* Dessine sprite dans page indiqu‚e */
 }
 return out;
}

/***********************************************************************
*  SetSprite: Place le sprite … une position donn‚e                    *
**--------------------------------------------------------------------**
*  Entr‚e  : SPIDP = Pointeur sur la structure du sprite               *
*            x0, y0 = Coordonn‚es du sprite en page 0                  *
*            x1, y1 = Coordonn‚es du sprite en page 1                  *
*  Info    : Cette fonction doit ˆtre d‚clench‚e avant le premier      *
*            appel … MoveSprite                                        *
***********************************************************************/

void SetSprite( SPID *spidp, int x0, int y0, int x1, int y1 )
{
 spidp->x[0] = x0;      /* M‚morise les coordonn‚es dans la structure */
 spidp->x[1] = x1;
 spidp->y[0] = y0;
 spidp->y[1] = y1;

 GetSpriteBg( spidp, 0 );            /* Lit le fond du sprite en page */
 GetSpriteBg( spidp, 1 );                                   /* 0 et 1 */
 PrintSprite( spidp, 0 );              /* Dessine le sprite en page 0 */
 PrintSprite( spidp, 1 );                                     /* et 1 */
}

/***********************************************************************
*  RemoveSprite: Retire un sprite de l'emplacement qu'il occupe        *
*                et le rend invisible                                  *
**--------------------------------------------------------------------**
*  Entr‚e  : SPIDP = Pointeur sur la structure du sprite               *
*  Info    : A l'issue de cette fonction il faut appeler la fonction   *
*            SetSprite() avant de d‚placer le sprite                   *
*            par MoveSprite()                                          *
***********************************************************************/

void RemoveSprite( SPID *spidp )
{
 RestoreSpriteBg( spidp, 0 );        /* R‚tablit le fond du sprite en */
 RestoreSpriteBg( spidp, 1 );                         /* pages 0 et 1 */
}

/***********************************************************************
*  Demo: D‚montre l'usage des diff‚rentes fonctions de ce module       *
***********************************************************************/

void Demo( void )
{
 static char *VaisseauMontant[20] =
                { "               AA               ",
                  "              AAAA              ",
                  "              AAAA              ",
                  "               AA               ",
                  "             GGBBGG             ",
                  "            GBBCCBBG            ",
                  "           GBBBCCBBBG           ",
                  "          GBBBBBBBBBBG          ",
                  "          GBBBBBBBBBBG          ",
                  " G       GBBBBBBBBBBBBG       G ",
                  "GCG     GGDBBBBBBBBBBDGG     GCG",
                  "GCG   GGBBBDBBB  BBBDBBBGG   GCG",
                  "GCBGGGBBBBBDBB    BBDBBBBBGGGBCG",
                  "GCBBBBBBBBBBDB    BDBBBBBBBBBBCG",
                  "BBBBBBBBBBBBDB BB BDBBBBBBBBBBBB",
                  "GGCBBBBBBBDBBBBBBBBBBDBBBBBBBCG ",
                  "  GGCCBBBDDDDDDDDDDDDDDBBBCCG   ",
                  "    GGBBDDDDDGGGGGDDDDDDBBG     ",
                  "      GDDDDGGG    GGGDDDDG      ",
                  "       DDDD          DDDD       "  };


 static char *VaisseauDescendant[20] =
                {
                  "       DDDD          DDDD       ",
                  "      GDDDDGGG    GGGDDDDG      ",
                  "    GGBBDDDDDGGGGGDDDDDDBBG     ",
                  "  GGCCBBBDDDDDDDDDDDDDDBBBCCG   ",
                  "GGCBBBBBBBDBBBBBBBBBBDBBBBBBBCG ",
                  "BBBBBBBBBBBBDB BB BDBBBBBBBBBBBB",
                  "GCBBBBBBBBBBDB    BDBBBBBBBBBBCG",
                  "GCBGGGBBBBBDBB    BBDBBBBBGGGBCG",
                  "GCG   GGBBBDBBB  BBBDBBBGG   GCG",
                  "GCG     GGDBBBBBBBBBBDGG     GCG",
                  " G       GBBBBBBBBBBBBG       G ",
                  "          GBBBBBBBBBBG          ",
                  "          GBBBBBBBBBBG          ",
                  "           GBBBCCBBBG           ",
                  "            GBBCCBBG            ",
                  "             GGBBGG             ",
                  "               AA               ",
                  "              AAAA              ",
                  "              AAAA              ",
                  "               AA               " };

 #define NBSPR    6                              /* Nombre de sprites */
 #define LARGEUR  38     /* Largeur notice de Copyright en caractŠres */
 #define HAUTEUR  6                              /* Hauteur en lignes */
 #define SX       (MAXX-(LARGEUR*8)) / 2               /* Coordonn‚es */
 #define SY       (MAXY-(HAUTEUR*8)) / 2                 /* de d‚part */

 struct {                                 /* D‚crit les sprites g‚r‚s */
          SPID *spidp;               /* Pointeur sur l'identificateur */
          int  deltax[2],      /* D‚placement horizontal pages 0 et 1 */
               deltay[2];   /* D‚placement vertical pour pages 0 et 1 */
        } sprites[ NBSPR ];
 BYTE   page,                            /* Page pr‚sentement trait‚e */
        out;                    /* M‚morise l'indicateur de collision */
 int    x, y, i,                            /* Compteurs d'it‚rations */
        dx, dy;                             /* valeurs de d‚placement */
 char   lc;
 SPLOOK *Vaisseauupp, *Vaisseaudnp;         /* Pointe sur les sprites */

 srand( *(long far *) 0x0040006c ); /* Initialise g‚n nbrs al‚atoires */

/*-- Remplit les deux premiŠres pages graphiques avec des caractŠres -*/

 for( page = 0; page < 2; ++ page )
 {
   setpage( page );
   for( lc = 0, y = 0; y < 200-8; y += 12 )
     for( x = 0; x < 320-8; x += 8 )
       GrafPrintf( x, y, lc % 255, 255, "%c", lc++ & 127 );

          /*-- Affiche le copyright-----------------------------------*/

   Line( SX-1, SY-1, SX+LARGEUR*8, SY-1, 15 );
   Line( SX+LARGEUR*8, SY-1, SX+LARGEUR*8, SY+HAUTEUR*8,15 );
   Line( SX+LARGEUR*8, SY+HAUTEUR*8, SX-1, SY+HAUTEUR*8, 15 );
   Line( SX-1, SY+HAUTEUR*8, SX-1, SY-1, 15 );
   GrafPrintf( SX, SY,    15, 4,
               "                                      " );
   GrafPrintf( SX, SY+8,  15, 4,
               " S3220C (c) 1990, 92  Michael Tischer " );
   GrafPrintf( SX, SY+16, 15, 4,
               "                                      " );
   GrafPrintf( SX, SY+24, 15, 4,
               "   D‚monstration de sprites en mode   " );
   GrafPrintf( SX, SY+32, 15, 4,
               "        VGA 320x200 256 couleurs      " );
   GrafPrintf( SX, SY+40, 15, 4,
               "                                      " );
  }

       /*-- Construit les motifs binaires des sprites ----------------*/

 Vaisseauupp = CompileSprite( VaisseauMontant,    20, 2,  0, 'A', 1 );
 Vaisseaudnp = CompileSprite( VaisseauDescendant, 20, 2, 40, 'A', 1 );

 /*-- Fabrique les diff‚rents sprites    -----------------------------*/

 for( i = 0; i < NBSPR ; ++ i)
 {
   sprites[ i ].spidp = CreateSprite( Vaisseauupp, 3, ( i % 3 ) * 100,
                                      (i / 3) * 30 );
   do                                 /* s‚lectionne les d‚placements */
   {
     dx = 0;
     dy = random(8) - 4;
   }
   while ( dx==0  &&  dy==0 );

   sprites[ i ].deltax[0] = sprites[ i ].deltax[1] = dx * 2;
   sprites[ i ].deltay[0] = sprites[ i ].deltay[1] = dy * 2;

   x = ( 320 / NBSPR * i ) + (320 / NBSPR - 40) / 2 ;
   y = random( 200 - 40 );
   SetSprite( sprites[ i ].spidp, x, y, x - dx, y - dy );
  }

/*-- D‚place sprites et fait rebondir aux extr‚mit‚s de l'‚cran ---*/

 page = 1;                                      /* Commence en page 1 */
 while( !kbhit() )       /* Une frappe de touche interrompt la boucle */
 {
   showpage( 1 - page );                      /* Affiche l'autre page */

   for( i = 0; i < NBSPR; ++ i)               /* Parcourt les sprites */
   {                   /* d‚place les sprites et teste les collisions */
     out = MoveSprite( sprites[i].spidp, page, sprites[i].deltax[page],
                       sprites[i].deltay[page] );
     if( out & OUT_TOP  ||  out & OUT_BOTTOM )           /* Contact ? */
     {           /* Oui change la direction du d‚placement et l'image */
       sprites[i].deltay[page] = 0 - sprites[i].deltay[page];
       sprites[i].spidp->splookp = ( out & OUT_TOP ) ? Vaisseaudnp
                                                     : Vaisseauupp;
     }
     if( out & OUT_LEFT  ||  out & OUT_RIGHT )
       sprites[i].deltax[page] = 0 - sprites[i].deltax[page];
   }
   page = (page+1) & 1;               /* Passe de 1 … 0 et vice-versa */
  }
}

/*--------------------------------------------------------------------*/
/*-- Programme principal                                            --*/
/*--------------------------------------------------------------------*/

void main( void )
{
  union REGS  regs;

 if( IsVga() )                              /* A-t-on une carte VGA ? */
 {                                                /* Oui, c'est parti */
   init320200();                      /* Initialise le mode graphique */
   Demo();
   getch();                            /* Attend une frappe de touche */
   regs.x.ax = 0x0003;                       /* Revient au mode texte */
   int86( 0x10, &regs, &regs );
 }
 else
   printf( "S3220C.C - (c) 1990,92 by MICHAEL TISCHER\n\nATTENTION "\
           "Ce programme exige une carte VGA\n\n" );
}
