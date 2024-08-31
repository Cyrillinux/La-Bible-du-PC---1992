/***********************************************************************
*                           S 3 2 4 0 C . C                            *
**--------------------------------------------------------------------**
*  Fonction         : Montre comment travailler avec des sprites       *
*                     dans le mode graphique VGA 320*400 en 256        *
*                     couleurs avec deux pages d'‚cran                 *
*                     Ce programme utilise les routines en assembleur  *
*                     des modules S3240CA.ASM et V3240CA.ASM.          *
**--------------------------------------------------------------------**
*  Auteur       : MICHAEL TISCHER                                      *
*  D‚velopp‚ le :  9.09.1990                                           *
*  DerniŠre MAJ : 14.02.1992                                           *
**--------------------------------------------------------------------**
*  ModŠle m‚moire   : SMALL                                            *
**--------------------------------------------------------------------**
*  (MICROSOFT C)                                                       *
*  Compilation       : CL /AS s3240c.c v3240ca s3240ca                 *
**--------------------------------------------------------------------**
*  (BORLAND TURBO C)                                                   *
*  Compilation       : Utiliser un fichier de projet avec le contenu   *
*                      suivant                                         *
*                      s3240c.c                                        *
*                      v3240ca.obj                                     *
*                      s3240ca.obj                                     *
**--------------------------------------------------------------------**
*  Appel           : s3240c                                            *
***********************************************************************/

#include <dos.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <conio.h>

/*-- D‚clarations d‚pendantes du compilateur -------------------------*/

#ifdef __TURBOC__
  #include <alloc.h>
#else
  #include <malloc.h>
  #define random(x) ( rand() % (x+1) )          /* Fonction al‚atoire */
#endif

/*-- D‚clarations de types -------------------------------------------*/

typedef unsigned char BYTE;
typedef BYTE BOOL;

typedef struct {    /* Buffer de pixels pour GetVideo() et PutVideo() */
        BYTE *bitptr[4],                /* Pointeur sur plans de bits */
             oparl[4],                    /* Nombre d'octets … copier */
             hauteur;                             /* Nombre de lignes */
                        /*-- Ici les octets des plans de bits --------*/
               } PIXBUF;
typedef PIXBUF *PIXPTR;           /* Pointeur sur un buffer de pixels */

typedef struct {                                 /* Image d'un sprite */
        BYTE   largeur,                             /* Largeur totale */
               hauteur;                /* Hauteur en lignes de pixels */
        PIXPTR pixbp;                  /* Pointeur sur bloc de pixels */
               } SPLOOK;

typedef struct {                        /* Descripteur de sprite (ID) */
        SPLOOK *splookp;                      /* Pointeur sur l'image */
        int    x[2], y[2];              /* Coordonn‚es en page 0 et 1 */
        PIXPTR fondptr[2];          /* Pointeur sur le buffer du fond */
               } SPID;

/*-- R‚f‚rences externes aux routines en assembleur ------------------*/

extern void init320400( void );
extern void setpix( int x, int y, unsigned char couleur);
extern BYTE getpix( int x, int y );
extern void setpage( BYTE page );
extern void showpage( BYTE page );
extern void far * getfontptr( void );

extern void copybuf2plane( BYTE *bufptr, BYTE page,
                           int ax, int ay, BYTE largeur,
                           BYTE hauteur, BOOL bg );
extern void copyplane2buf( BYTE *bufptr, BYTE page,
                           int dex, int dey, BYTE largeur,
                           BYTE hauteur );

/*-- Constantes ------------------------------------------------------*/

#define TRUE  ( 0 == 0 )
#define FALSE ( 0 == 1 )

#define MAXX 319                             /* Coordonn‚es maximales */
#define MAXY 399

#define OUT_LEFT   1 /* Indicateurs de colllisions  pour SpriteMove() */
#define OUT_TOP    2
#define OUT_RIGHT  4
#define OUT_BOTTOM 8
#define OUT_NO     0                              /* Pas de collision */

#define ALLOCBUF ((PIXPTR) 0)     /* GetVideo(): allocation de buffer */

/***********************************************************************
*  IsVga: Teste la pr‚sence d'une carte VGA                            *
**--------------------------------------------------------------------**
*  Entr‚e  : n‚ant                                                     *
*  Sortie  : 0, si aucune carte VGA n'est branch‚e, sinon  # 0         *
***********************************************************************/

BYTE IsVga( void )
{
 union REGS Regs;              /* Registres pour g‚rer l'interruption */

 Regs.x.ax = 0x1a00;            /* La fonction 1Ah n'existe qu'en VGA */
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
 typedef BYTE CARDEF[256][8];       /* Structure du jeu de caractŠres */
 typedef CARDEF far *CARPTR;       /* Pointe sur un jeu de caractŠres */

 BYTE     i, k,                              /* Compteur d'it‚rations */
          masque;        /* Masque binaire pour dessiner le caractŠre */

 static CARPTR fptr = (CARPTR) 0;         /* Jeu de caractŠres en ROM */

 if( fptr == (CARPTR) 0 )      /* A-t-on d‚j… d‚termin‚ ce pointeur ? */
   fptr = getfontptr();    /* Non, d‚termine avec fonction assembleur */

  /*- Dessine le caractŠre pixel par pixel ---------------------------*/

 if( cf == 255 )                           /* CaractŠre transparent ? */
   for( i = 0; i < 8; ++i ) /* Oui, ne dessine que pixels du 1er plan */
   {
     masque = (*fptr)[caractere][i];  /* Lit motif bin pour une ligne */
     for ( k = 0; k < 8; ++k, masque <<= 1 ) /* Parcourt les colonnes */
      if ( masque & 128 )                       /* Pixel … dessiner ? */
       setpix( x+k, y+i, cc );                                 /* Oui */
   }
 else                                     /* Non dessine chaque pixel */
   for ( i = 0; i < 8; ++i )                   /* Parcourt les lignes */
   {
     masque = (*fptr)[caractere][i];      /* Motif bin pour une ligne */
     for ( k = 0; k < 8; ++k, masque <<= 1 ) /* Parcourt les colonnes */
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
 int   dummy;

 dummy = *i2; *i2   = *i1; *i1   = dummy;
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
   if ( y1 > y2 )                            /* y1 plus grand que y2? */
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
 va_list parameter;     /* Liste de paramŠtres pour les macros VA_... */
 char    affichage[255],            /* Buffer pour la chaŒne format‚e */
         *cp;

 va_start( parameter, string );           /* Convertit les paramŠtres */
 vsprintf( affichage, string, parameter );                 /* Formate */
 for( cp = affichage; *cp; ++cp, x+= 8 )         /* Affiche la chaŒne */
   PrintChar( *cp, x, y, cc, cf );          /* format‚e par PrintChar */
}

/***********************************************************************
*  GetVideo: Charge le contenu d'une zone rectangulaire de la m‚moire  *
*            d'‚cran dans un buffer                                    *
**--------------------------------------------------------------------**
*  Entr‚e : PAGE   = Page d'‚cran (0 ou 1)                             *
*           X1, Y1 = Coordonn‚es de d‚part                             *
*           LARGEUR = Largeur de la zone recatngulaire en pixels       *
*           HAUTEUR  = Hauteur de la zone rectangulaire en pixels      *
*           BUFPTR = Pointeur sur un buffer de pixels qui va    -      *
*                     m‚moriser les informations                       *
*  Sortie  : Pointeur sur le buffer cr‚‚ qui contient la zone indiqu‚e *
*                                                                      *
*  Info    : Si on donne au paramŠtre BUFPTR la valeur ALLOCBUF        *
*            un nouveau buffer de pixels est allou‚ sur le tas et      *
*            retourn‚. Ce buffer peut ˆtre transmis lors d'un nouvel   *
*            appel si l'ancien contenu est effa‡able et si la taille   *
*            de la zone n'a pas chang‚                                 *
***********************************************************************/

PIXPTR GetVideo( BYTE page, int x1, int y1, BYTE largeur, BYTE hauteur,
                 PIXPTR bufptr )
{
 BYTE i,                                     /* Compteur d'it‚rations */
      plancour,                               /* Plan de bits courant */
      sb,                    /* Plan de bits des coordonn‚es de d‚but */
      eb,                      /* Plan de bits des coordonn‚es de fin */
      b,                      /* Nombre d'octets dans un plan de bits */
      am;     /* Nombre d'octets au milieu des deux groupes de quatre */
 BYTE *rptr; /* Pointeur sur la pos. d'un plan de bits dans le buffer */

 if( bufptr == ALLOCBUF )                 /* Pas de buffer transmis ? */
   bufptr = malloc( sizeof( PIXBUF ) + largeur*hauteur );   /* alloue */

  /*-- calcule le nombre d'octets par plan de bits -------------------*/

 am = (BYTE) (((x1+largeur-1) & ~3 )     /* Nombre d'octets au milieu */
               - ( (x1+4) & ~3) ) >> 2;
 sb = (BYTE) (x1 % 4);                        /* Plan de bit de d‚but */
 eb = (BYTE) ((x1+largeur-1) % 4);              /* Plan de bit de fin */

 rptr = (BYTE *) bufptr + sizeof( PIXBUF );

 /*-- Parcourt les quatre plans de bits ------------------------------*/

 for( i=0; i<4; ++i )
 {
   plancour = (sb+i) % 4;
   b = am;                      /* Nombre de base des octets … copier */
   if( plancour >= sb )         /* dans le bloc des quatre du d‚but ? */
     ++b;                /* Oui, ajoute un octet dans ce plan de bits */
   if( plancour <= eb )        /* dans le bloc des quatre de la fin ? */
     ++b;                 /* Oui ajoute un octet dans ce plan de bits */
   bufptr->bitptr[i] = rptr;        /* M‚morise pointeur sur le d‚but */
   bufptr->oparl[i] = b;                /* M‚moise le nombre d'octets */
   copyplane2buf( rptr, page, x1+i,               /* Lit le contenu - */
          y1, b, hauteur );                              /* des plans */
   rptr += (b * hauteur);                   /* Positionne le pointeur */
 };                                       /* sur le plan suivant dans */
                                                         /* le buffer */
 bufptr->hauteur = hauteur;                    /* M‚morise la hauteur */

 return bufptr;     /* Renvoie … l'appelant le pointeur sur le buffer */
}

/***********************************************************************
*  PutVideo: R‚‚crit dans la m‚moire d'‚cran                           *
*            le  contenu d'une zone d'‚cran rectangulaire pr‚alablement*
*            sauvegard‚e par GetVideo()                                *
**--------------------------------------------------------------------**
*  Entr‚e : BUFPTR  = Pointeur renvoy‚ par GetVideo et r‚f‚ren‡ant     *
*                     un buffer de pixels                              *
*            PAGE   = Page d'‚cran   (0 ou 1)                          *
*            X1, Y1 = Coordonn‚es de d‚but                             *
*            BG     = Indique si les pixels du fond (code couleur 255) *
*                     doivent ˆtre ‚crits dans la m‚moire d'‚cran      *
*  Info    : Le buffer de pixels n'est pas effac‚ par cette proc‚dure  *
*            cette tƒche ‚tant remplie par FreePixBuf()                *
***********************************************************************/

void PutVideo( PIXPTR bufptr, BYTE page, int x1, int y1, BOOL bg )
{
 BYTE  plancour,                              /* Plan de bits courant */
       hauteur;

 hauteur = bufptr->hauteur;                     /* Hauteur de la zone */
 for( plancour=0; plancour<4; ++plancour )     /* Parcourt 4 bitplans */
   copybuf2plane( bufptr->bitptr[plancour], page, x1+plancour,
                  y1, bufptr->oparl[plancour], hauteur, bg );
}

/***********************************************************************
*  FreePixBuf: Efface un buffer de pixels allou‚ sur le tas par        *
*              GetVideo()                                              *
**--------------------------------------------------------------------**
*  Entr‚e : BUFPTR = Pointeur renvoy‚ par Getvideo et r‚f‚ren‡ant      *
*                     un buffer de pixels                              *
*            LARGEUR = Largeur de la zone rectangulaire en pixels      *
*            HAUTEUR = Hauteur de la zone rectangulaire en pixels      *
***********************************************************************/

void FreePixBuf( PIXPTR bufptr )
{
 free( bufptr );
}

/***********************************************************************
*  CreateSprite: Cr‚e un sprite … l'aide d'un motif de pixels          *
*                pr‚alablement compil‚                                 *
**--------------------------------------------------------------------**
*  Entr‚e : SPLOOKP = pointeur sur la structure de donn‚es produite    *
*                     par CompileSpriteI()                             *
*  Sortie : Pointeur sur la structure du sprite cr‚‚e                  *
*  Info   : La m‚morisation du fond du sprite n‚cessite deux zones     *
*           contigu‰s de la taille du sprite                           *
***********************************************************************/

SPID *CreateSprite( SPLOOK *splookp )
{
 SPID   *spidp;                  /* Pointe sur la structure du sprite */

 spidp = (SPID *) malloc( sizeof(SPID) );   /* m‚moire pour structure */
 spidp->splookp = splookp;                   /* Y reporte les donn‚es */

/*- Cr‚e deux buffers de fond dans lesquels GetVideo va sauvegarder  -*/
                                 /*- des zones de la m‚moire d'‚cran -*/

 spidp->fondptr[0] = GetVideo( 0, 0, 0, splookp->largeur,
                             splookp->hauteur, ALLOCBUF );
 spidp->fondptr[1] = GetVideo( 0, 0, 0, splookp->largeur,
                             splookp->hauteur, ALLOCBUF );
 return spidp;      /* Renvoie un pointeur sur la structure du sprite */
}

/***********************************************************************
*  CompileSprite: Cr‚e le motif binaire d'un sprite … l'aide d'une     *
*                 d‚finition connue au moment de l'ex‚cution           *
**--------------------------------------------------------------------**
*  Entr‚e : BUFP     = Pointeur sur un tableau de pointeurs r‚f‚ren‡ant*
*                      des chaŒnes de caractŠres qui repr‚sentent      *
*                      le motif du sprite                              *
*            HAUTEUR = Hauteur du sprite et nombre de chaŒnes de       *
*                      caractŠres                                      *
*            PAGE    = Page graphique pour construire le sprite        *
*            CLR     = CaractŠre ASCII associ‚ … la plus               *
*                      petite couleur                                  *
*            COULEURPP= Premier code de couleur pour CLR               *
*  Info    : Les sprites sont dessin‚s … partir du bord gauche         *
*            de la ligne indiqu‚e                                      *
***********************************************************************/

SPLOOK *CompileSprite( char **bufp, BYTE hauteur, BYTE page,
                       char fb, BYTE couleurpp )
{
 BYTE   largeur,           /* Longueur des chaŒnes = largeur du motif */
        c,                                   /* M‚morise un caractŠre */
        i, k;                               /* Compteurs d'it‚rations */
 SPLOOK *splookp;   /* Ptr sur la structure de l'image du sprite cr‚‚e*/
 PIXPTR pbptr;           /* M‚morise temporairement le fond du sprite */

 /*-- Cr‚e la structure de l'image du sprite et la remplit -----------*/

 splookp          = (SPLOOK *) malloc( sizeof(SPLOOK) );
 largeur          = (BYTE) strlen( *bufp );
 splookp->largeur = largeur;
 splookp->hauteur = hauteur;

    /*-- Construit le sprite dans la page indiqu‚e … partir de (0,0)--*/

 setpage( page );                           /* Fixe la page de dessin */
 showpage( page );
 pbptr = GetVideo( page, 0, 0, largeur, hauteur, ALLOCBUF );  /* fond */

 for( i = 0; i < hauteur; ++i )                /* Parcourt les lignes */
   for( k = 0; k < largeur; ++k )            /* Parcourt les colonnes */
   {
     c = *(*(bufp+i)+k);
     setpix( k, i, (BYTE) (c == ' ' ? 255 : couleurpp+(c-fb)));
   }

 /*-- Lit le sprite dans le buffer et restaure le fond    ------------*/

 splookp->pixbp = GetVideo( page, 0, 0, largeur, hauteur, ALLOCBUF );
 PutVideo( pbptr, page, 0, 0, FALSE );
 FreePixBuf( pbptr );                             /* LibŠre le buffer */

 return splookp;      /* Renvoie un pointeur sur le buffer de l'image */
}

/***********************************************************************
*  PrintSprite : AFfiche un sprite dans une page donn‚e                *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*            PAGE = Page concern‚e                                     *
*                    (0 ou 1)                                          *
***********************************************************************/

void PrintSprite( register SPID *spidp, BYTE page )
{
 PutVideo( spidp->splookp->pixbp,
            page, spidp->x[page], spidp->y[page], TRUE );
}

/***********************************************************************
*  GetSpriteBg: Lit le fond du sprite et le m‚morise … l'emplacement   *
*               pr‚vu                                                  *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*           PAGE  = Page d'o— est tir‚ le fond                         *
*                   (0 ou 1)                                           *
***********************************************************************/

void GetSpriteBg( register SPID *spidp, BYTE page )
{
 GetVideo(
           page, spidp->x[page],
           spidp->y[page],
           spidp->splookp->largeur,
           spidp->splookp->hauteur,
           spidp->fondptr[page]
         );
}

/***********************************************************************
*  RestoreSpriteBg: R‚tablit dans la page d'origine le fond d'un sprite*
*                   sauvegard‚ au pr‚alable                            *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*           PAGE  = Page o— doit ˆtre recopi‚ le fond (0 ou 1)         *
***********************************************************************/

void RestoreSpriteBg( register SPID *spidp, BYTE page )
{
 PutVideo(
           spidp->fondptr[page],
           page,
           spidp->x[page],
           spidp->y[page],
           FALSE
         );
}

/***********************************************************************
*  MoveSprite: D‚place un sprite                                       *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP  = Pointeur sur la structure du sprite               *
*           PAGE   = Page o— doit ˆtre recopi‚ le fond (0 ou 1)        *
*           DELTAX = D‚placement dans les directions X et Y            *
*           DELTAY                                                     *
*  Sortie  : Indicateur de collision, cf constantes OUT_...            *
***********************************************************************/

BYTE MoveSprite( SPID *spidp, BYTE page, int deltax, int deltay )
{
 int    nouvx, nouvy;              /* Nouvelles coordonn‚es du sprite */
 BYTE   out;         /* Indique une collision avec le bord de l'‚cran */

    /*-- D‚cale l'abscisse X et teste s'il y a collision avec le bord */
 if( ( nouvx = spidp->x[page] + deltax ) < 0 )
 {
   nouvx = 0 - deltax - spidp->x[page];
   out = OUT_LEFT;
 }
 else
   if( nouvx > MAXX - spidp->splookp->largeur )
   {
     nouvx = (2 * ( MAXX + 1 ) ) - nouvx - 2 * spidp->splookp->largeur;
     out = OUT_RIGHT;
   }
   else
     out = OUT_NO;

/*-- D‚cale l'ordonn‚e Y et teste s'il y a collision avec le bord ----*/

 if( ( nouvy = spidp->y[page] + deltay ) < 0 )           /* Bord sup ?*/
 {                                    /* Oui deltay doit ˆtre n‚gatif */
   nouvy = 0 - deltay - spidp->y[page];
   out |= OUT_TOP;
 }
 else
  if( nouvy + spidp->splookp->hauteur > MAXY+1  )        /* Bord inf ?*/
  {                                  /* Oui, deltay doit ˆtre positif */
    nouvy = (2 * (MAXY+1) ) - nouvy - 2 * spidp->splookp->hauteur;
    out |= OUT_BOTTOM;
  }

/*-- Fixe nouvelle pos que si elle est diff‚rente de l'ancienne */

 if ( nouvx != spidp->x[page]  ||  nouvy != spidp->y[page] )
 {                                               /* Nouvelle position */
   RestoreSpriteBg( spidp, page );                /* R‚tablit le fond */
   spidp->x[page] = nouvx;                  /* M‚morise les nouvelles */
   spidp->y[page] = nouvy;                           /*   coordonn‚es */
   GetSpriteBg( spidp, page );                 /* Lit le nouveau fond */
   PrintSprite( spidp, page );   /* Dessine sprite dans page indiqu‚e */
 }
 return out;
}

/***********************************************************************
*  SetSprite: Place le sprite … une position donn‚e                    *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP  = Pointeur sur la structure du sprite               *
*           x0, y0 = Coordonn‚es du sprite en page 0                   *
*           x1, y1 = Coordonn‚es du sprite en page 1                   *
*  Info    : Cette fonction doit ˆtre d‚clench‚e avant le premier      *
*            appel … MoveSprite()                                      *
***********************************************************************/

void SetSprite( SPID *spidp, int x0, int y0, int x1, int y1 )
{
 spidp->x[0] = x0;      /* M‚morise les coordonn‚es dans la structure */
 spidp->x[1] = x1;
 spidp->y[0] = y0;
 spidp->y[1] = y1;

 GetSpriteBg( spidp, 0 );                 /* Lit le fond du sprite en */
 GetSpriteBg( spidp, 1 );                             /* pages 0 et 1 */
 PrintSprite( spidp, 0 );              /* Dessine le sprite en page 0 */
 PrintSprite( spidp, 1 );                                     /* et 1 */
}

/***********************************************************************
*  RemoveSprite: Retire un sprite de l'emplacement qu'il occupe        *
*                et le rend invisible                                  *
**--------------------------------------------------------------------**
*  Entr‚e : SPIDP = Pointeur sur la structure du sprite                *
*  Info   : A l'issue de cette fonction, il faut appeler SetSprite()   *
*           avant de d‚placer le sprite par MoveSprite()               *
***********************************************************************/

void RemoveSprite( SPID *spidp )
{
 RestoreSpriteBg( spidp, 0 );           /* R‚tablit le fond du sprite */
 RestoreSpriteBg( spidp, 1 );                      /* en pages 0 et 1 */
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
 #define LARGEUR  38   /* Nombre de caractŠres de l'avis de copyright */
 #define HAUTEUR  6                  /* Nombre de lignes du mˆme avis */
 #define SX       (MAXX-(LARGEUR*8)) / 2      /* Abscisse de d‚part X */
 #define SY       (MAXY-(HAUTEUR*8)) / 2      /* Ordonn‚e de d‚part Y */

 struct {                                 /* d‚crit les sprites g‚r‚s */
      SPID *spidp;                   /* Pointeur sur l'identificateur */
      int  deltax[2],     /* D‚placement horizontal pour pages 0 et 1 */
           deltay[2];       /* D‚placement vertical pour pages 0 et 1 */
    } sprites[ NBSPR ];
 BYTE   page,                            /* Page pr‚sentement trait‚e */
        out;                    /* M‚morise l'indicateur de collision */
 int    x, y, i,                            /* Compteurs d'it‚rations */
        dx, dy;                                       /* D‚placements */
 char   lc;
 SPLOOK *vaisseauupp, *vaisseaudnp;      /* Pointeurs sur les sprites */

 srand( *(int far *) 0x0040006cl );
                    /* Initialise le g‚n‚rateur de nombres al‚atoires */

      /*-- Construit les motifs binaires des sprites  ----------------*/

 vaisseauupp = CompileSprite( VaisseauMontant,   20, 0, 'A', 1 );
 vaisseaudnp = CompileSprite( VaisseauDescendant, 20, 20, 'A', 1 );

        /*-- Remplit de caractŠres les deux pages graphiques----------*/

 for( page = 0; page < 2; ++ page )
 {
   setpage( page );
   for( lc = 0, y = 0; y < (MAXY+1)-8; y += 12 )
     for( x = 0; x < (MAXX+1)-8; x += 8 )
       GrafPrintf( x, y, lc % 255, 255, "%c", lc++ & 127 );

   /*-- Affiche l'avis de copyright ----------------------------------*/

   Line( SX-1, SY-1, SX+LARGEUR*8, SY-1, 15 );
   Line( SX+LARGEUR*8, SY-1, SX+LARGEUR*8, SY+HAUTEUR*8,15 );
   Line( SX+LARGEUR*8, SY+HAUTEUR*8, SX-1, SY+HAUTEUR*8, 15 );
   Line( SX-1, SY+HAUTEUR*8, SX-1, SY-1, 15 );
   GrafPrintf( SX, SY,    15, 4,
               "                                      "  );
   GrafPrintf( SX, SY+8,  15, 4,
               "  S3240C (c) 1990, 92 Michael Tischer " );
   GrafPrintf( SX, SY+16, 15, 4,
               "                                      "  );
   GrafPrintf( SX, SY+24, 15, 4,
               "   D‚monstration de sprites en mode   " );
   GrafPrintf( SX, SY+32, 15, 4,
               "      VGA 320x400 256 couleurs        "  );
   GrafPrintf( SX, SY+40, 15, 4,
               "                                      "  );
  }

 /*-- Fabrique les diff‚rents sprites    -----------------------------*/

 for( i = 0; i < NBSPR  ; ++ i)
 {
   sprites[ i ].spidp = CreateSprite( vaisseauupp );
   do                                 /* S‚lectionne les d‚placements */
   {
     dx = 0;
     dy = random(8) - 4;
   }
   while( dx==0  &&  dy==0 );

   sprites[ i ].deltax[0] = sprites[ i ].deltax[1] = dx * 2;
   sprites[ i ].deltay[0] = sprites[ i ].deltay[1] = dy * 2;

   x = ( 320 / NBSPR  * i ) + (320 / NBSPR  - 40) / 2 ;
   y = random( (MAXY+1) - 40 );
   SetSprite(
              sprites[ i ].spidp,
              x,
              y,
              x - dx,
              y - dy
            );
 }

/*-- D‚place sprites et les fait rebondir aux extr‚mit‚s de l'‚cran */

 page = 1;                                      /* Commence en page 1 */
 while( !kbhit() )       /* Une frappe de touche interrompt la boucle */
 {
   showpage( (BYTE) (1 - page) );             /* Affiche l'autre page */

   for( i = 0; i < NBSPR; ++ i)                /* Affiche les sprites */
   {                   /* D‚place les sprites et teste les collisions */
     out = MoveSprite( sprites[i].spidp, page, sprites[i].deltax[page],
                       sprites[i].deltay[page] );
     if ( out & OUT_TOP  ||  out & OUT_BOTTOM )          /* Contact ? */
     {                /* Oui inverse le d‚placement et change l'image */
       sprites[i].deltay[page] = 0 - sprites[i].deltay[page];
       sprites[i].spidp->splookp = ( out & OUT_TOP ) ? vaisseaudnp
                                                     : vaisseauupp;
     }
     if ( out & OUT_LEFT  ||  out & OUT_RIGHT )
       sprites[i].deltax[page] = 0 - sprites[i].deltax[page];
   }
   page = (page+1) & 1;               /* Passe de 1 … 0 et vice-versa */
 }
}

/*--------------------------------------------------------------------*/
/*-- PROGRAMME PRINCIPAL                                            --*/
/*--------------------------------------------------------------------*/

void main( void )
{
 union REGS regs;

 if ( IsVga() )                              /* A-t-on une carte VGA? */
  {                                                /* Oui c'est parti */
   init320400();                      /* Initialise le mode graphique */
   Demo();
   getch();                            /* Attend une frappe de touche */
   regs.x.ax = 0x0003;                      /* R‚tablit le mode texte */
   int86( 0x10, &regs, &regs );
  }
 else
  printf( "S3240C.C - (c) 1990, 92 by MICHAEL TISCHER\n\nATTENTION "\
          "Ce programme n‚cessite une carte VGA");

}
